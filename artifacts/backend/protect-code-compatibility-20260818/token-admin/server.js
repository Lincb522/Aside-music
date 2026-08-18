const express = require('express')
const crypto = require('crypto')
const fs = require('fs')
const path = require('path')
const { createCloudSnapshotStore } = require('./cloud-snapshot-store')
const { installAIRemoteConfigRoutes } = (() => {
  try { return require('./ai-remote-config') }
  catch (_) { return require('../../Server/token-admin/ai-remote-config') }
})()
const { installTokenSongContent } = require('./song-content-integration')
const { createTokenSongContentAdapters } = require('./song-content-adapters')

const http = require('http')
const https = require('https')
const app = express()
let songContentService = null
app.use(express.json({ limit: '32mb' }))

const DATA_FILE = path.join(__dirname, 'data.json')
const USAGE_FILE = path.join(__dirname, 'usage-stats.json')
const PUBLIC_DIR = path.join(__dirname, 'public')
const STORAGE_DIR = path.join(__dirname, 'storage')
const IPA_DIR = path.join(STORAGE_DIR, 'ipas')
const PLAY_USAGE_KEY_FILE = path.join(__dirname, '.play-usage-key')
const PORT = 3388
const startedAt = new Date().toISOString()

fs.mkdirSync(PUBLIC_DIR, { recursive: true })
fs.mkdirSync(IPA_DIR, { recursive: true })

const cloudSnapshotStore = createCloudSnapshotStore({
  directory: __dirname,
  cacheEntries: 8
})
let pendingCloudCompactionCount = 0

// --------------- Rate-limit in-memory store ---------------
const rateBuckets = new Map()

function checkRateLimit(tokenId, limit) {
  if (!limit || limit <= 0) return true
  const now = Date.now()
  const windowMs = 60_000
  let bucket = rateBuckets.get(tokenId)
  if (!bucket) {
    bucket = []
    rateBuckets.set(tokenId, bucket)
  }
  while (bucket.length && bucket[0] <= now - windowMs) bucket.shift()
  if (bucket.length >= limit) return false
  bucket.push(now)
  return true
}

setInterval(() => {
  const cutoff = Date.now() - 120_000
  for (const [id, bucket] of rateBuckets) {
    while (bucket.length && bucket[0] <= cutoff) bucket.shift()
    if (!bucket.length) rateBuckets.delete(id)
  }
}, 60_000)

// --------------- Data helpers ---------------
let cachedData = null
let usageSaveTimer = null
let usageWriteInFlight = false
let usageDirty = false
const ADMIN_SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000
const adminSessions = new Map()

function normalizeAdminActorId(value) {
  const normalized = String(value || '').trim().slice(0, 160)
  if (!normalized) return 'token-admin'
  return /^[A-Za-z0-9._:-]+$/.test(normalized) ? normalized : `admin-${crypto.randomUUID()}`
}

function createAdminSession(actorId) {
  const token = crypto.randomBytes(32).toString('base64url')
  const expiresAt = Date.now() + ADMIN_SESSION_TTL_MS
  adminSessions.set(token, { actorId, expiresAt })
  return { token, expiresAt }
}

function resolveAdminSession(token, adminPassword) {
  if (token === adminPassword) return { actorId: 'token-admin', legacy: true }
  const session = adminSessions.get(String(token || ''))
  if (!session) return null
  if (session.expiresAt <= Date.now()) {
    adminSessions.delete(String(token || ''))
    return null
  }
  return session
}

setInterval(() => {
  const now = Date.now()
  for (const [token, session] of adminSessions) {
    if (session.expiresAt <= now) adminSessions.delete(token)
  }
}, 60 * 60 * 1000).unref()

function applyUsageSnapshot(data) {
  if (!fs.existsSync(USAGE_FILE) || !Array.isArray(data.tokens)) return data
  try {
    const snapshot = JSON.parse(fs.readFileSync(USAGE_FILE, 'utf-8'))
    if (snapshot.platformPlayUsage && typeof snapshot.platformPlayUsage === 'object') {
      data.platformPlayUsage = snapshot.platformPlayUsage
    }
    const usageById = new Map((snapshot.tokens || []).map(item => [item.id, item]))
    for (const token of data.tokens) {
      const usage = usageById.get(token.id)
      if (!usage) continue
      if (usage.lastUsed && (!token.lastUsed || usage.lastUsed > token.lastUsed)) token.lastUsed = usage.lastUsed
      token.requestCount = Math.max(token.requestCount || 0, usage.requestCount || 0)
      if (usage.playRequestCount !== undefined) {
        token.playRequestCount = Math.max(token.playRequestCount || 0, usage.playRequestCount || 0)
      }
      if (usage.playTrafficBytes !== undefined) {
        token.playTrafficBytes = Math.max(token.playTrafficBytes || 0, usage.playTrafficBytes || 0)
      }
      token.totalDownloads = Math.max(token.totalDownloads || 0, usage.totalDownloads || 0)
      token.dailyStats = { ...(token.dailyStats || {}), ...(usage.dailyStats || {}) }
      if (usage.dailyPlayStats !== undefined) {
        token.dailyPlayStats = { ...(token.dailyPlayStats || {}), ...(usage.dailyPlayStats || {}) }
      }
      if (usage.dailyPlayTraffic !== undefined) {
        token.dailyPlayTraffic = { ...(token.dailyPlayTraffic || {}), ...(usage.dailyPlayTraffic || {}) }
      }
      token.dailyDownloads = { ...(token.dailyDownloads || {}), ...(usage.dailyDownloads || {}) }
      if (Array.isArray(usage.devices)) token.devices = usage.devices
    }
  } catch (error) {
    console.error('[usage-stats] 恢复失败:', error.message)
  }
  return data
}

function buildUsageSnapshot(data) {
  return {
    updatedAt: new Date().toISOString(),
    platformPlayUsage: data.platformPlayUsage || {},
    tokens: (data.tokens || []).map(token => ({
      id: token.id,
      lastUsed: token.lastUsed || null,
      requestCount: token.requestCount || 0,
      playRequestCount: token.playRequestCount || 0,
      playTrafficBytes: token.playTrafficBytes || 0,
      dailyStats: token.dailyStats || {},
      dailyPlayStats: token.dailyPlayStats || {},
      dailyPlayTraffic: token.dailyPlayTraffic || {},
      totalDownloads: token.totalDownloads || 0,
      dailyDownloads: token.dailyDownloads || {},
      devices: token.devices || []
    }))
  }
}

function flushUsageData() {
  usageSaveTimer = null
  if (!cachedData || !usageDirty || usageWriteInFlight) return
  usageDirty = false
  usageWriteInFlight = true
  const tmp = USAGE_FILE + '.tmp'
  const payload = JSON.stringify(buildUsageSnapshot(cachedData))
  fs.writeFile(tmp, payload, error => {
    if (error) {
      usageWriteInFlight = false
      usageDirty = true
      console.error('[usage-stats] 写入失败:', error.message)
      scheduleUsageSave(cachedData, 10_000)
      return
    }
    fs.rename(tmp, USAGE_FILE, renameError => {
      usageWriteInFlight = false
      if (renameError) {
        usageDirty = true
        console.error('[usage-stats] 提交失败:', renameError.message)
      }
      if (usageDirty) scheduleUsageSave(cachedData, 1_000)
    })
  })
}

function scheduleUsageSave(data, delay = 5_000) {
  cachedData = data
  usageDirty = true
  if (usageSaveTimer || usageWriteInFlight) return
  usageSaveTimer = setTimeout(flushUsageData, delay)
  usageSaveTimer.unref?.()
}

function flushUsageDataSync() {
  if (!cachedData || !usageDirty) return
  const tmp = USAGE_FILE + '.tmp'
  fs.writeFileSync(tmp, JSON.stringify(buildUsageSnapshot(cachedData)))
  fs.renameSync(tmp, USAGE_FILE)
  usageDirty = false
}

function loadData() {
  if (cachedData) return cachedData
  if (!fs.existsSync(DATA_FILE)) {
    const initial = {
      adminPassword: crypto.randomBytes(8).toString('hex'),
      globalEnabled: false,
      rateLimitEnabled: true,
      defaultRateLimit: 60,
      downloadLimitEnabled: false,
      defaultDownloadLimit: 0,
      deviceBindEnabled: false,
      maxDevicesPerToken: 3,
      selfRegisterRequireProtectCode: true,
      qqRiskControlEnabled: true,
      kcmPoolEnabled: false,
      activeKcmPoolAccountId: null,
      ipaReleases: [],
      appChangelogs: [],
      protectCodes: [],
      bindings: [],
      tokens: []
    }
    fs.writeFileSync(DATA_FILE, JSON.stringify(initial, null, 2))
    console.log('初始管理密码:', initial.adminPassword)
    cachedData = initial
    return initial
  }
  const data = applyUsageSnapshot(JSON.parse(fs.readFileSync(DATA_FILE, 'utf-8')))
  if (data.defaultRateLimit === undefined) data.defaultRateLimit = 60
  if (data.rateLimitEnabled === undefined) data.rateLimitEnabled = true
  if (data.downloadLimitEnabled === undefined) data.downloadLimitEnabled = false
  if (data.defaultDownloadLimit === undefined) data.defaultDownloadLimit = 0
  if (data.deviceBindEnabled === undefined) data.deviceBindEnabled = false
  if (data.maxDevicesPerToken === undefined) data.maxDevicesPerToken = 3
  if (data.selfRegisterEnabled === undefined) data.selfRegisterEnabled = true
  if (data.selfRegisterExpiresIn === undefined) data.selfRegisterExpiresIn = 30
  if (data.selfRegisterRateLimit === undefined) data.selfRegisterRateLimit = 60
  if (data.selfRegisterDownloadLimit === undefined) data.selfRegisterDownloadLimit = 0
  if (data.selfRegisterMaxDevices === undefined) data.selfRegisterMaxDevices = 3
  if (data.selfRegisterDailyLimit === undefined) data.selfRegisterDailyLimit = 50
  if (data.selfRegisterRequireProtectCode === undefined) data.selfRegisterRequireProtectCode = true
  if (data.qqRiskControlEnabled === undefined) data.qqRiskControlEnabled = true
  if (data.kcmPoolEnabled === undefined) data.kcmPoolEnabled = false
  if (data.activeKcmPoolAccountId === undefined) data.activeKcmPoolAccountId = null
  if (!Array.isArray(data.ipaReleases)) data.ipaReleases = []
  if (!Array.isArray(data.appChangelogs)) data.appChangelogs = []
  if (!Array.isArray(data.protectCodes)) data.protectCodes = []
  if (!Array.isArray(data.bindings)) data.bindings = []
  normalizeProtectCodeData(data)
  const cloudPreparation = cloudSnapshotStore.prepareData(data)
  pendingCloudCompactionCount += cloudPreparation.migrated
  cachedData = data
  return data
}

const PROTECT_CODE_PURPOSES = new Set(['ipa', 'tf'])

function normalizeProtectCodePurpose(value, fallback = 'tf') {
  const normalized = String(value || '').trim().toLowerCase()
  return PROTECT_CODE_PURPOSES.has(normalized) ? normalized : fallback
}

function inferLegacyProtectCodePurpose(bindings, code) {
  const observed = new Set()
  for (const binding of (bindings || [])) {
    if (String(binding.code || '').trim().toUpperCase() !== code) continue
    if (binding.source === 'self-register') observed.add('ipa')
    if (String(binding.source || '').startsWith('tf-') || binding.source === 'tf-auto') observed.add('tf')
  }
  return observed.size === 1 ? [...observed][0] : 'tf'
}

function normalizeProtectCodeData(data) {
  if (!Array.isArray(data.protectCodes)) data.protectCodes = []
  if (!Array.isArray(data.bindings)) data.bindings = []
  const purposeByCode = new Map()
  for (const item of data.protectCodes) {
    if (!item || typeof item !== 'object') continue
    item.code = String(item.code || '').trim().toUpperCase()
    item.purpose = PROTECT_CODE_PURPOSES.has(String(item.purpose || '').trim().toLowerCase())
      ? String(item.purpose).trim().toLowerCase()
      : inferLegacyProtectCodePurpose(data.bindings, item.code)
    item.currentUses = Math.max(0, parseInt(item.currentUses, 10) || 0)
    item.maxUses = Math.max(item.currentUses, parseInt(item.maxUses, 10) || 0)
    if (item.code) purposeByCode.set(item.code, item.purpose)
  }
  for (const binding of data.bindings) {
    if (!binding || typeof binding !== 'object' || !binding.code) continue
    const code = String(binding.code).trim().toUpperCase()
    binding.codePurpose = normalizeProtectCodePurpose(
      binding.codePurpose,
      purposeByCode.get(code) || (binding.source === 'self-register' ? 'ipa' : 'tf')
    )
  }
}

function protectCodesForPurpose(data, purpose) {
  normalizeProtectCodeData(data)
  const normalizedPurpose = normalizeProtectCodePurpose(purpose)
  return data.protectCodes.filter(item => item.purpose === normalizedPurpose)
}

function findProtectCode(data, code, purpose) {
  const normalizedCode = String(code || '').trim().toUpperCase()
  const requestedPurpose = normalizeProtectCodePurpose(purpose)
  // TestFlight 码具备更高权限：可以用于 TestFlight，也可以向下兼容 IPA 自签。
  // IPA 自签码只能用于 IPA，不能用于 TestFlight。
  const acceptedPurposes = requestedPurpose === 'ipa' ? new Set(['ipa', 'tf']) : new Set(['tf'])
  normalizeProtectCodeData(data)
  return data.protectCodes.find(item => item.code === normalizedCode && acceptedPurposes.has(item.purpose)) || null
}

function generateProtectCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  let result = ''
  for (let i = 0; i < 6; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  return result
}

function saveData(data) {
  cloudSnapshotStore.prepareData(data)
  cachedData = data
  // 原子写入：先写临时文件再 rename，避免大文件写入过程中被读到半截（防止 data.json 损坏）
  const tmp = DATA_FILE + '.tmp'
  fs.writeFileSync(tmp, JSON.stringify(data, null, 2))
  fs.renameSync(tmp, DATA_FILE)
}

process.once('SIGINT', () => {
  try { flushUsageDataSync() } catch (error) { console.error('[usage-stats] 退出保存失败:', error.message) }
  try { cloudSnapshotStore.close() } catch (error) { console.error('[cloud-storage] 退出关闭失败:', error.message) }
  try { songContentService?.close() } catch (error) { console.error('[song-content] 退出关闭失败:', error.message) }
  process.exit(0)
})

process.once('SIGTERM', () => {
  try { flushUsageDataSync() } catch (error) { console.error('[usage-stats] 退出保存失败:', error.message) }
  try { cloudSnapshotStore.close() } catch (error) { console.error('[cloud-storage] 退出关闭失败:', error.message) }
  try { songContentService?.close() } catch (error) { console.error('[song-content] 退出关闭失败:', error.message) }
  process.exit(0)
})

// --------------- 绑定记录 (保护码 -> 邮箱/用户名/Token) ---------------
function recordBinding(data, { code = null, codePurpose = null, email, name, tokenKey = null, tokenId = null, testerId = null, groupId = null, accountId = null, source = null }) {
  if (!Array.isArray(data.bindings)) data.bindings = []
  const emailLc = (email || '').toLowerCase()
  let b = data.bindings.find(x => (tokenId && x.tokenId === tokenId) || (tokenKey && x.tokenKey === tokenKey) || (emailLc && x.email === emailLc))
  if (b) {
    if (code) b.code = code
    if (codePurpose) b.codePurpose = normalizeProtectCodePurpose(codePurpose)
    if (name) b.name = name
    if (tokenKey) b.tokenKey = tokenKey
    if (tokenId) b.tokenId = tokenId
    if (testerId) b.testerId = testerId
    if (groupId) b.groupId = groupId
    if (accountId) b.accountId = accountId
    if (source) b.source = source
    b.updatedAt = new Date().toISOString()
    return b
  }
  b = {
    id: crypto.randomUUID(),
    code: code || null,
    codePurpose: code ? normalizeProtectCodePurpose(codePurpose, source === 'self-register' ? 'ipa' : 'tf') : null,
    email: emailLc,
    name: name || '',
    tokenKey: tokenKey || null,
    tokenId: tokenId || null,
    testerId: testerId || null,
    groupId: groupId || null,
    accountId: accountId || null,
    source: source || null,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  }
  data.bindings.push(b)
  return b
}

function backfillBindings(data) {
  if (!Array.isArray(data.bindings)) data.bindings = []
  const bindSources = ['self-register', 'tf-public-join', 'tf-public-trial', 'tf-auto']
  let added = 0
  for (const t of (data.tokens || [])) {
    if (!bindSources.includes(t.source)) continue
    const exists = data.bindings.find(b => (t.id && b.tokenId === t.id) || (t.key && b.tokenKey === t.key))
    if (exists) continue
    data.bindings.push({
      id: crypto.randomUUID(),
      code: null,
      email: (t.email || '').toLowerCase(),
      name: t.name || t.registeredName || '',
      tokenKey: t.key || null,
      tokenId: t.id || null,
      testerId: null,
      groupId: null,
      source: t.source || null,
      createdAt: t.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      backfilled: true
    })
    added++
  }
  return added
}

function postJson(url, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const u = new URL(url)
    const payload = JSON.stringify(body || {})
    const r = http.request({
      hostname: u.hostname,
      port: u.port || 80,
      path: u.pathname + u.search,
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload), ...headers },
      timeout: 8000
    }, (rr) => { let s = ''; rr.on('data', x => s += x); rr.on('end', () => resolve({ status: rr.statusCode, body: s })) })
    r.on('error', reject)
    r.on('timeout', () => { r.destroy(); reject(new Error('timeout')) })
    r.write(payload); r.end()
  })
}

function migrateToken(t) {
  if (t.expiresAt === undefined) t.expiresAt = null
  if (t.rateLimit === undefined) t.rateLimit = 60
  if (t.dailyStats === undefined) t.dailyStats = {}
  if (t.requestCount === undefined) t.requestCount = 0
  if (t.playUsageVersion !== 1) {
    t.playRequestCount = Math.max(t.playRequestCount || 0, t.requestCount || 0)
    t.dailyPlayStats = { ...(t.dailyStats || {}), ...(t.dailyPlayStats || {}) }
    t.playUsageVersion = 1
  }
  if (t.playRequestCount === undefined) t.playRequestCount = 0
  if (t.playTrafficBytes === undefined) t.playTrafficBytes = 0
  if (t.dailyPlayStats === undefined) t.dailyPlayStats = { ...(t.dailyStats || {}) }
  if (t.dailyPlayTraffic === undefined) t.dailyPlayTraffic = {}
  if (t.lastUsed === undefined) t.lastUsed = null
  if (t.downloadLimit === undefined) t.downloadLimit = 0
  if (t.dailyDownloads === undefined) t.dailyDownloads = {}
  if (t.totalDownloads === undefined) t.totalDownloads = 0
  if (t.devices === undefined) t.devices = []
  if (t.maxDevices === undefined) t.maxDevices = 3
  cloudSnapshotStore.attachToken(t)
  if (!Array.isArray(t.kcmAccounts)) t.kcmAccounts = []
  if (t.activeKcmAccountId === undefined) t.activeKcmAccountId = null
  if (t.email === undefined) t.email = null
  if (t.registeredName === undefined) t.registeredName = null
  if (t.source === undefined) t.source = 'admin'
  return t
}

const KCM_MEMBERSHIP_LEVELS = new Set(['none', 'trial', 'full'])

function kcmVaultKey(data) {
  const secret = process.env.KCM_ACCOUNT_ENCRYPTION_KEY || data.adminPassword
  return crypto.createHash('sha256').update(String(secret)).digest()
}

function encryptKcmCookie(data, cookie) {
  const iv = crypto.randomBytes(12)
  const cipher = crypto.createCipheriv('aes-256-gcm', kcmVaultKey(data), iv)
  const encrypted = Buffer.concat([cipher.update(cookie, 'utf8'), cipher.final()])
  return {
    version: 1,
    iv: iv.toString('base64'),
    tag: cipher.getAuthTag().toString('base64'),
    ciphertext: encrypted.toString('base64')
  }
}

function decryptKcmCookie(data, payload) {
  if (!payload || payload.version !== 1) return null
  try {
    const decipher = crypto.createDecipheriv(
      'aes-256-gcm',
      kcmVaultKey(data),
      Buffer.from(payload.iv, 'base64')
    )
    decipher.setAuthTag(Buffer.from(payload.tag, 'base64'))
    return Buffer.concat([
      decipher.update(Buffer.from(payload.ciphertext, 'base64')),
      decipher.final()
    ]).toString('utf8')
  } catch {
    return null
  }
}

function normalizeKcmCookie(value) {
  if (typeof value !== 'string') return null
  const pairs = value
    .split(';')
    .map(item => item.trim())
    .filter(item => item.length > 0 && item.length <= 8192 && item.includes('='))
  if (!pairs.length) return null

  const values = new Map()
  for (const pair of pairs) {
    const separator = pair.indexOf('=')
    const name = pair.slice(0, separator).trim()
    const cookieValue = pair.slice(separator + 1).trim()
    if (!/^[A-Za-z0-9_\-]+$/.test(name) || !cookieValue) continue
    values.set(name, cookieValue)
  }
  const token = [...values.entries()].find(([name]) => name.toLowerCase() === 'token')?.[1]
  const userId = [...values.entries()].find(([name]) => name.toLowerCase() === 'userid')?.[1]
  if (!token || !userId || userId === '0') return null
  return {
    cookie: [...values.entries()].map(([name, cookieValue]) => `${name}=${cookieValue}`).join('; '),
    userId: String(userId)
  }
}

function normalizeKcmAccountProfile(profile, userId) {
  const source = profile && typeof profile === 'object' ? profile : {}
  const stringValue = (value, maxLength) => {
    if (typeof value !== 'string') return null
    const trimmed = value.trim()
    return trimmed ? trimmed.slice(0, maxLength) : null
  }
  return {
    userId: String(userId),
    nickname: stringValue(source.nickname, 120),
    avatarUrl: stringValue(source.avatarUrl, 2048)
  }
}

function publicKcmAccount(account, activeAccountId) {
  return {
    id: account.id,
    userId: account.userId,
    nickname: account.nickname || null,
    avatarUrl: account.avatarUrl || null,
    membershipLevel: KCM_MEMBERSHIP_LEVELS.has(account.membershipLevel)
      ? account.membershipLevel
      : 'none',
    isActive: account.id === activeAccountId,
    createdAt: account.createdAt,
    updatedAt: account.updatedAt,
    lastUsedAt: account.lastUsedAt || null
  }
}

function groupedKcmAccounts(token) {
  const accounts = token.kcmAccounts.map(account => publicKcmAccount(account, token.activeKcmAccountId))
  return {
    none: accounts.filter(account => account.membershipLevel === 'none'),
    trial: accounts.filter(account => account.membershipLevel === 'trial'),
    full: accounts.filter(account => account.membershipLevel === 'full')
  }
}

function kcmPoolEntries(data) {
  const byUserId = new Map()
  for (const token of (data.tokens || []).map(migrateToken)) {
    for (const account of token.kcmAccounts) {
      if (!account?.id || !account?.userId || !account?.encryptedCookie) continue
      const existing = byUserId.get(String(account.userId))
      const updatedAt = Date.parse(account.updatedAt || account.createdAt || 0) || 0
      const existingUpdatedAt = existing
        ? Date.parse(existing.account.updatedAt || existing.account.createdAt || 0) || 0
        : -1
      if (!existing || updatedAt >= existingUpdatedAt) {
        byUserId.set(String(account.userId), { token, account })
      }
    }
  }
  return [...byUserId.values()]
}

function orderedKcmPoolEntries(data, excludeUserId = null, preferredUserId = null) {
  const membershipRank = { full: 0, trial: 1, none: 2 }
  return kcmPoolEntries(data)
    .filter(entry => !excludeUserId || String(entry.account.userId) !== String(excludeUserId))
    .sort((lhs, rhs) => {
      const lhsPreferred = preferredUserId && String(lhs.account.userId) === String(preferredUserId) ? 0 : 1
      const rhsPreferred = preferredUserId && String(rhs.account.userId) === String(preferredUserId) ? 0 : 1
      if (lhsPreferred !== rhsPreferred) return lhsPreferred - rhsPreferred
      const lhsActive = lhs.account.id === data.activeKcmPoolAccountId ? 0 : 1
      const rhsActive = rhs.account.id === data.activeKcmPoolAccountId ? 0 : 1
      if (lhsActive !== rhsActive) return lhsActive - rhsActive
      const lhsRank = membershipRank[lhs.account.membershipLevel] ?? membershipRank.none
      const rhsRank = membershipRank[rhs.account.membershipLevel] ?? membershipRank.none
      if (lhsRank !== rhsRank) return lhsRank - rhsRank
      return (Date.parse(rhs.account.updatedAt || 0) || 0) - (Date.parse(lhs.account.updatedAt || 0) || 0)
    })
}

function ensureActiveKcmPoolAccount(data) {
  const entries = orderedKcmPoolEntries(data)
  if (!entries.length) {
    data.activeKcmPoolAccountId = null
    return null
  }
  const active = entries.find(entry => entry.account.id === data.activeKcmPoolAccountId)
  if (active) return active
  data.activeKcmPoolAccountId = entries[0].account.id
  return entries[0]
}

function publicKcmPool(data) {
  ensureActiveKcmPoolAccount(data)
  const accounts = orderedKcmPoolEntries(data).map(entry => (
    publicKcmAccount(entry.account, data.activeKcmPoolAccountId)
  ))
  return {
    enabled: data.kcmPoolEnabled === true,
    activeAccountId: data.activeKcmPoolAccountId,
    accounts,
    groups: {
      none: accounts.filter(account => account.membershipLevel === 'none'),
      trial: accounts.filter(account => account.membershipLevel === 'trial'),
      full: accounts.filter(account => account.membershipLevel === 'full')
    }
  }
}

function proxyKcmPoolRequest(urlPath, cookie, timeout = 20000) {
  return new Promise((resolve, reject) => {
    const upstream = http.request({
      hostname: '127.0.0.1',
      port: 3004,
      path: urlPath,
      method: 'GET',
      headers: {
        Accept: 'application/json',
        Cookie: cookie,
        Authorization: cookie
      },
      timeout
    }, response => {
      let body = ''
      response.on('data', chunk => { body += chunk })
      response.on('end', () => {
        try {
          resolve({ status: response.statusCode, body: JSON.parse(body) })
        } catch {
          resolve({ status: response.statusCode, body: { raw: body } })
        }
      })
    })
    upstream.on('error', reject)
    upstream.on('timeout', () => {
      upstream.destroy()
      reject(new Error('KCM API timeout'))
    })
    upstream.end()
  })
}

function firstKcmPlaybackUrl(value, allowString = false) {
  if (!value) return null
  if (typeof value === 'string') {
    return allowString && /^https?:\/\//i.test(value) ? value : null
  }
  if (Array.isArray(value)) {
    for (const child of value) {
      const found = firstKcmPlaybackUrl(child, allowString)
      if (found) return found
    }
    return null
  }
  if (typeof value !== 'object') return null
  for (const key of ['url', 'play_url', 'playUrl', 'backup_url', 'backupUrl']) {
    const found = firstKcmPlaybackUrl(value[key], true)
    if (found) return found
  }
  for (const child of Object.values(value)) {
    const found = firstKcmPlaybackUrl(child)
    if (found) return found
  }
  return null
}

const KCM_STREAM_TICKET_TTL_MS = 30 * 60 * 1000
const kcmStreamTickets = new Map()

function pruneKcmStreamTickets() {
  const now = Date.now()
  for (const [ticket, payload] of kcmStreamTickets) {
    if (!payload || payload.expiresAt <= now) kcmStreamTickets.delete(ticket)
  }
}

const kcmStreamTicketCleanupTimer = setInterval(pruneKcmStreamTickets, 60 * 1000)
if (typeof kcmStreamTicketCleanupTimer.unref === 'function') {
  kcmStreamTicketCleanupTimer.unref()
}

function issueKcmStreamTicket(payload) {
  pruneKcmStreamTickets()
  const ticket = crypto.randomBytes(32).toString('hex')
  kcmStreamTickets.set(ticket, {
    ...payload,
    expiresAt: Date.now() + KCM_STREAM_TICKET_TTL_MS
  })
  return ticket
}

function publicKcmStreamUrl(req, ticket) {
  const proto = String(req.get('x-forwarded-proto') || req.protocol || 'https')
    .split(',')[0]
    .trim()
  const host = String(req.get('x-forwarded-host') || req.get('host') || '')
    .split(',')[0]
    .trim()
  return `${proto}://${host}/_admin/api/account/kcm/pool/stream/${ticket}`
}

function pipeKcmPlaybackStream(req, res, upstreamUrl, redirects = 0) {
  let parsed
  try {
    parsed = new URL(upstreamUrl)
  } catch {
    return res.status(502).json({ error: 'invalid kcm playback url' })
  }

  const client = parsed.protocol === 'https:' ? https : http
  const headers = {
    Accept: '*/*',
    'Accept-Encoding': 'identity',
    Referer: 'https://www.kugou.com/',
    'User-Agent': 'Android15-1070-11083-46-0-DiscoveryDRADProtocol-wifi'
  }
  if (typeof req.headers.range === 'string' && req.headers.range) {
    headers.Range = req.headers.range
  }

  const upstream = client.request(parsed, {
    method: req.method === 'HEAD' ? 'HEAD' : 'GET',
    headers,
    timeout: 20_000
  }, response => {
    const status = response.statusCode || 502
    const location = response.headers.location
    if (location && status >= 300 && status < 400 && redirects < 3) {
      response.resume()
      const redirectedUrl = new URL(location, parsed).toString()
      pipeKcmPlaybackStream(req, res, redirectedUrl, redirects + 1)
      return
    }

    const forwardedHeaders = [
      'content-type',
      'content-length',
      'content-range',
      'accept-ranges',
      'etag',
      'last-modified'
    ]
    for (const name of forwardedHeaders) {
      const value = response.headers[name]
      if (value !== undefined) res.setHeader(name, value)
    }
    res.setHeader('Cache-Control', 'private, no-store')
    res.setHeader('X-Content-Type-Options', 'nosniff')
    res.status(status)

    if (req.method === 'HEAD') {
      response.resume()
      res.end()
      return
    }
    response.pipe(res)
  })

  upstream.on('timeout', () => {
    upstream.destroy(new Error('KCM CDN timeout'))
  })
  upstream.on('error', error => {
    if (!res.headersSent) {
      res.status(502).json({ error: `kcm playback proxy failed: ${error.message}` })
    } else {
      res.destroy(error)
    }
  })
  res.once('close', () => upstream.destroy())
  upstream.end()
}

function migrateRelease(release) {
  if (!release.id) release.id = crypto.randomUUID()
  if (!release.version) release.version = '0.0.0'
  if (release.build === undefined || release.build === null) release.build = ''
  if (!release.title) release.title = `Version ${release.version}`
  if (!release.channel) release.channel = 'stable'
  if (release.releaseNotes === undefined) release.releaseNotes = ''
  if (release.minIosVersion === undefined) release.minIosVersion = ''
  if (release.fileName === undefined) release.fileName = null
  if (release.storedFileName === undefined) release.storedFileName = null
  if (release.fileSize === undefined) release.fileSize = 0
  if (release.checksum === undefined) release.checksum = null
  if (release.published === undefined) release.published = false
  if (release.downloadCount === undefined) release.downloadCount = 0
  if (release.createdAt === undefined) release.createdAt = new Date().toISOString()
  if (release.updatedAt === undefined) release.updatedAt = release.createdAt
  if (release.publishedAt === undefined) {
    release.publishedAt = release.published ? release.updatedAt : null
  }
  return release
}

function genToken() {
  return crypto.randomBytes(4).toString('hex')
}

function todayKey() {
  return new Date().toISOString().slice(0, 10)
}

function getTodayDownloads(t) {
  const today = todayKey()
  return (t.dailyDownloads && t.dailyDownloads[today]) || 0
}

function sanitizeFileName(value) {
  return String(value || '')
    .replace(/[/\\?%*:|"<>]/g, '-')
    .replace(/\s+/g, ' ')
    .trim()
}

function releaseFilePath(release) {
  if (!release || !release.storedFileName) return null
  return path.join(IPA_DIR, release.storedFileName)
}

function hasReleaseFile(release) {
  const filePath = releaseFilePath(release)
  return Boolean(filePath && fs.existsSync(filePath))
}

function publicReleasePayload(release) {
  return {
    id: release.id,
    version: release.version,
    build: release.build,
    title: release.title,
    channel: release.channel,
    releaseNotes: release.releaseNotes,
    minIosVersion: release.minIosVersion,
    fileName: release.fileName,
    fileSize: release.fileSize,
    checksum: release.checksum,
    downloadCount: release.downloadCount || 0,
    published: Boolean(release.published),
    createdAt: release.createdAt,
    updatedAt: release.updatedAt,
    publishedAt: release.publishedAt,
    hasFile: hasReleaseFile(release),
    downloadUrl: `./downloads/file/${release.id}`
  }
}

function adminReleasePayload(release) {
  return {
    ...publicReleasePayload(release),
    storedFileName: release.storedFileName
  }
}

function sortReleasesDesc(releases) {
  return [...releases].sort((a, b) => {
    const left = new Date(b.publishedAt || b.updatedAt || b.createdAt || 0).getTime()
    const right = new Date(a.publishedAt || a.updatedAt || a.createdAt || 0).getTime()
    return left - right
  })
}

function readReleaseInput(body = {}) {
  const version = String(body.version || '').trim()
  const build = String(body.build || '').trim()
  const title = String(body.title || '').trim()

  return {
    version: version || '0.0.0',
    build,
    title: title || `Version ${version || '0.0.0'}`,
    channel: ['stable', 'beta', 'internal'].includes(body.channel) ? body.channel : 'stable',
    releaseNotes: String(body.releaseNotes || '').trim(),
    minIosVersion: String(body.minIosVersion || '').trim(),
    published: Boolean(body.published)
  }
}

function updateReleaseFromInput(release, input) {
  release.version = input.version
  release.build = input.build
  release.title = input.title
  release.channel = input.channel
  release.releaseNotes = input.releaseNotes
  release.minIosVersion = input.minIosVersion
  release.published = input.published
  release.updatedAt = new Date().toISOString()
  if (release.published) {
    release.publishedAt = release.publishedAt || release.updatedAt
  } else {
    release.publishedAt = null
  }
  return release
}

function migrateChangelog(item) {
  if (!item.id) item.id = crypto.randomUUID()
  if (!item.version) item.version = '0.0.0'
  if (item.build === undefined || item.build === null) item.build = ''
  if (!item.title) item.title = `Version ${item.version}`
  if (!item.channel) item.channel = 'stable'
  if (item.releaseNotes === undefined) item.releaseNotes = ''
  if (item.summary === undefined) item.summary = ''
  if (item.published === undefined) item.published = false
  if (item.createdAt === undefined) item.createdAt = new Date().toISOString()
  if (item.updatedAt === undefined) item.updatedAt = item.createdAt
  if (item.publishedAt === undefined) {
    item.publishedAt = item.published ? item.updatedAt : null
  }
  return item
}

function resolvePublishedChangelog(id) {
  const targetId = String(id || '')
  const item = (loadData().appChangelogs || [])
    .map(migrateChangelog)
    .find((entry) => entry.id === targetId)
  return item && item.published ? item : null
}

function publicChangelogPayload(item) {
  return {
    id: item.id,
    version: item.version,
    build: item.build,
    title: item.title,
    channel: item.channel,
    summary: item.summary,
    releaseNotes: item.releaseNotes,
    published: Boolean(item.published),
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
    publishedAt: item.publishedAt
  }
}

function adminChangelogPayload(item) {
  return publicChangelogPayload(item)
}

function sortChangelogsDesc(items) {
  return [...items].sort((a, b) => {
    const left = new Date(b.publishedAt || b.updatedAt || b.createdAt || 0).getTime()
    const right = new Date(a.publishedAt || a.updatedAt || a.createdAt || 0).getTime()
    return left - right
  })
}

function readChangelogInput(body = {}) {
  const version = String(body.version || '').trim()
  const build = String(body.build || '').trim()
  const title = String(body.title || '').trim()

  return {
    version: version || '0.0.0',
    build,
    title: title || `Version ${version || '0.0.0'}`,
    channel: ['stable', 'beta', 'internal'].includes(body.channel) ? body.channel : 'stable',
    summary: String(body.summary || '').trim(),
    releaseNotes: String(body.releaseNotes || '').trim(),
    published: Boolean(body.published)
  }
}

function updateChangelogFromInput(item, input) {
  item.version = input.version
  item.build = input.build
  item.title = input.title
  item.channel = input.channel
  item.summary = input.summary
  item.releaseNotes = input.releaseNotes
  item.published = input.published
  item.updatedAt = new Date().toISOString()
  if (item.published) {
    item.publishedAt = item.publishedAt || item.updatedAt
  } else {
    item.publishedAt = null
  }
  return item
}



// --------------- Device bind helper ---------------
function checkDeviceBind(data, t, req) {
  if (!data.deviceBindEnabled) return { allowed: true }

  let deviceId, deviceModel, deviceName, systemName, systemVersion, appVersion, vendorId;

  if (req.method === 'POST') {
    deviceId = req.body?.device_uuid;
    deviceModel = req.body?.device_model;
    deviceName = req.body?.device_name;
    systemName = req.body?.system_name;
    systemVersion = req.body?.system_version;
    appVersion = req.body?.app_version;
    vendorId = req.body?.vendor_id;
  } else {
    deviceId = req.query?.deviceId || req.headers?.['x-device-id'];
  }
  
  if (!deviceId) {
    const origUri = req?.headers?.['x-original-uri'] || ''
    const dm = origUri.match(/[?&]deviceId=([^&]+)/)
    if (dm) deviceId = decodeURIComponent(dm[1])
  }

  if (!deviceId) return { allowed: true }

  t.devices = t.devices || []
  let updatedDevice = false

  let existing = t.devices.find(d => d.deviceId === deviceId)
  if (existing) {
    if (deviceModel && existing.deviceModel !== deviceModel) { existing.deviceModel = deviceModel; updatedDevice = true; }
    if (deviceName && existing.deviceName !== deviceName) { existing.deviceName = deviceName; updatedDevice = true; }
    if (systemName && existing.systemName !== systemName) { existing.systemName = systemName; updatedDevice = true; }
    if (systemVersion && existing.systemVersion !== systemVersion) { existing.systemVersion = systemVersion; updatedDevice = true; }
    if (appVersion && existing.appVersion !== appVersion) { existing.appVersion = appVersion; updatedDevice = true; }
    if (vendorId && existing.vendorId !== vendorId) { existing.vendorId = vendorId; updatedDevice = true; }
    // 更新 lastUsedAt 用于 LRU 踢人策略
    existing.lastUsedAt = new Date().toISOString();
    updatedDevice = true;
    return { allowed: true, newDevice: false, updatedDevice }
  }

  if (req.query?.is_refresh === '1' || req.body?.is_refresh === '1' || req.headers?.['x-is-refresh'] === '1') {
    return { allowed: false, reason: 'device_unbound' }
  }

  const max = t.maxDevices || data.maxDevicesPerToken || 3
  // LRU 踢人：按 lastUsedAt/firstSeen 排序，踢掉最久未用的
  while (t.devices.length >= max) {
    t.devices.sort((a, b) => {
      const ta = new Date(a.lastUsedAt || a.firstSeen || 0).getTime();
      const tb = new Date(b.lastUsedAt || b.firstSeen || 0).getTime();
      return ta - tb; // 升序，最老的在前
    });
    t.devices.shift(); // 踢最老的（最久未用）
  }

  const now = new Date().toISOString();
  t.devices.push({
    deviceId,
    deviceModel: deviceModel || '未知设备',
    deviceName: deviceName || '未知名称',
    systemName, systemVersion, appVersion,
    vendorId: vendorId || null,
    firstSeen: now,
    lastUsedAt: now
  })
  return { allowed: true, newDevice: true, updatedDevice: false }
}

function readPublicTokenFromRequest(req) {
  let tokenKey = req.query.token || req.headers['x-api-token']
  if (!tokenKey) {
    const origUri = req.headers['x-original-uri'] || ''
    const match = origUri.match(/[?&]token=([^&]+)/)
    if (match) tokenKey = decodeURIComponent(match[1])
  }
  return typeof tokenKey === 'string' ? tokenKey.trim() : ''
}

function readDeviceIdFromRequest(req) {
  if (typeof req.query.deviceId === 'string' && req.query.deviceId.trim()) {
    return req.query.deviceId.trim()
  }
  if (typeof req.headers['x-device-id'] === 'string' && req.headers['x-device-id'].trim()) {
    return req.headers['x-device-id'].trim()
  }
  if (typeof req.body?.deviceId === 'string' && req.body.deviceId.trim()) {
    return req.body.deviceId.trim()
  }
  const origUri = req.headers['x-original-uri'] || ''
  const match = origUri.match(/[?&]deviceId=([^&]+)/)
  return match ? decodeURIComponent(match[1]) : ''
}

function resolvePublicToken(req, res, options = {}) {
  const data = loadData()
  data.tokens = data.tokens.map(migrateToken)

  const tokenKey = readPublicTokenFromRequest(req)
  if (!tokenKey) {
    res.status(401).json({ error: 'missing token' })
    return null
  }

  const token = data.tokens.find(t => t.key === tokenKey && t.enabled)
  if (!token) {
    res.status(403).json({ error: 'invalid token' })
    return null
  }

  if (token.expiresAt && new Date(token.expiresAt) <= new Date()) {
    res.status(403).json({ error: 'expired token' })
    return null
  }

  const deviceId = readDeviceIdFromRequest(req)
  const shouldCheckDevice = options.checkDeviceBind !== false
  if (shouldCheckDevice) {
    const devCheck = checkDeviceBind(data, token, req)
    if (!devCheck.allowed) {
      res.status(403).json({
        error: devCheck.reason,
        current: devCheck.current,
        max: devCheck.max
      })
      return null
    }
    if (devCheck.newDevice || devCheck.updatedDevice) scheduleUsageSave(data)
  }

  return { data, token, tokenKey, deviceId }
}

function normalizeCloudCoverUrl(value) {
  if (typeof value !== 'string' || !value.trim()) return null
  const url = value.trim()
  if (url.startsWith('//')) return `https:${url}`
  if (url.startsWith('http://')) return `https://${url.slice(7)}`
  return url
}

function cloudSongCoverUrl(song) {
  if (!song || typeof song !== 'object') return null
  const direct = [
    song.coverUrl,
    song.picUrl,
    song.albumPic,
    song.artwork,
    song.al?.picUrl,
    song.al?.coverUrl,
    song.album?.picUrl,
    song.album?.coverUrl
  ].map(normalizeCloudCoverUrl).find(Boolean)
  if (direct) return direct

  const qqAlbumMid = String(song.qqAlbumMid || song.al?.mid || song.album?.mid || '').trim()
  return qqAlbumMid
    ? `https://y.gtimg.cn/music/photo_new/T002R500x500M000${encodeURIComponent(qqAlbumMid)}.jpg`
    : null
}

function cloudPlaylistCoverUrl(playlist) {
  if (!playlist || typeof playlist !== 'object') return null
  const direct = [
    playlist.coverUrl,
    playlist.coverImgUrl,
    playlist.picUrl,
    playlist.cover
  ].map(normalizeCloudCoverUrl).find(Boolean)
  if (direct) return direct
  return (Array.isArray(playlist.songs) ? playlist.songs : [])
    .map(cloudSongCoverUrl)
    .find(Boolean) || null
}

function normalizePlaylistItem(item) {
  if (!item || typeof item !== 'object') return null
  const songs = Array.isArray(item.songs) ? item.songs : []
  const now = new Date().toISOString()

  return {
    id: typeof item.id === 'string' && item.id.trim() ? item.id.trim() : crypto.randomUUID(),
    name: typeof item.name === 'string' && item.name.trim() ? item.name.trim() : '未命名歌单',
    desc: typeof item.desc === 'string' ? item.desc : null,
    coverUrl: cloudPlaylistCoverUrl(item),
    createdAt: typeof item.createdAt === 'string' && !Number.isNaN(Date.parse(item.createdAt))
      ? new Date(item.createdAt).toISOString()
      : now,
    updatedAt: typeof item.updatedAt === 'string' && !Number.isNaN(Date.parse(item.updatedAt))
      ? new Date(item.updatedAt).toISOString()
      : now,
    isSystem: Boolean(item.isSystem),
    songs
  }
}

const CLOUD_SNAPSHOT_VERSION = 3
const MAX_CLOUD_HISTORY_RECORDS = 20_000
const MAX_CLOUD_AI_CACHE_ENTRIES = 1_024
const MAX_CLOUD_AI_HISTORY_ENTRIES = 2_000
const MAX_CLOUD_EQ_PRESETS = 512

function isPlainObject(value) {
  return Boolean(value && typeof value === 'object' && !Array.isArray(value))
}

function normalizeThemeCustomization(value) {
  if (!isPlainObject(value)) return null
  const entries = Array.isArray(value.entries)
    ? value.entries.filter(isPlainObject).slice(0, 64)
    : []
  return entries.length ? { entries } : null
}

function normalizePlaybackHistory(value) {
  if (!isPlainObject(value)) return null
  const records = Array.isArray(value.records)
    ? value.records.filter(isPlainObject).slice(0, MAX_CLOUD_HISTORY_RECORDS)
    : []
  const recentClearedAt = typeof value.recentClearedAt === 'string'
    && !Number.isNaN(Date.parse(value.recentClearedAt))
    ? new Date(value.recentClearedAt).toISOString()
    : null
  return records.length || recentClearedAt ? { records, recentClearedAt } : null
}

function normalizeAIEqualizer(value) {
  if (!isPlainObject(value)) return null

  const cachedEntries = isPlainObject(value.cachedProposals)
    ? Object.entries(value.cachedProposals)
      .filter(([, proposal]) => isPlainObject(proposal))
      .slice(-MAX_CLOUD_AI_CACHE_ENTRIES)
    : []
  const cachedProposals = Object.fromEntries(cachedEntries)

  const savedProposals = {}
  let remaining = MAX_CLOUD_AI_HISTORY_ENTRIES
  if (isPlainObject(value.savedProposals)) {
    for (const [songIdentifier, entries] of Object.entries(value.savedProposals)) {
      if (remaining <= 0) break
      if (!Array.isArray(entries)) continue
      const normalized = entries.filter(isPlainObject).slice(0, Math.min(50, remaining))
      if (!normalized.length) continue
      savedProposals[String(songIdentifier)] = normalized
      remaining -= normalized.length
    }
  }

  const metadataEntries = isPlainObject(value.proposalMetadata)
    ? Object.entries(value.proposalMetadata)
      .filter(([key, metadata]) => typeof key === 'string' && isPlainObject(metadata))
      .slice(-(MAX_CLOUD_AI_CACHE_ENTRIES + MAX_CLOUD_AI_HISTORY_ENTRIES))
    : []
  const proposalMetadata = Object.fromEntries(metadataEntries)

  return cachedEntries.length || Object.keys(savedProposals).length || metadataEntries.length
    ? {
      cachedProposals,
      savedProposals,
      ...(metadataEntries.length ? { proposalMetadata } : {})
    }
    : null
}

function normalizeCustomEQPresets(value) {
  if (!Array.isArray(value)) return null
  const presets = value.filter(isPlainObject).slice(0, MAX_CLOUD_EQ_PRESETS)
  return presets.length ? presets : null
}

function resolveVersionedSnapshotField(value, previousValue, clientVersion, normalizer) {
  // v1/v2 客户端从未发送 v3 字段：缺失时必须保留服务端已有数据，
  // 防止旧版 App 登录或自动同步后清空新版备份。
  if (value === undefined && clientVersion < CLOUD_SNAPSHOT_VERSION) {
    return normalizer(previousValue)
  }
  // v3 客户端缺失该可选字段表示本地已经清空。
  return normalizer(value)
}

function resolveVersionedArray(value, previousValue, clientVersion) {
  if (value === undefined && clientVersion < CLOUD_SNAPSHOT_VERSION) {
    return Array.isArray(previousValue) ? previousValue : []
  }
  return Array.isArray(value) ? value : []
}

function countAIEqualizerPlans(snapshot) {
  if (!snapshot) return 0
  const ids = new Set()
  for (const proposal of Object.values(snapshot.cachedProposals || {})) {
    if (proposal?.id) ids.add(String(proposal.id))
  }
  for (const entries of Object.values(snapshot.savedProposals || {})) {
    if (!Array.isArray(entries)) continue
    for (const entry of entries) {
      const id = entry?.proposal?.id || entry?.id
      if (id) ids.add(String(id))
    }
  }
  return ids.size
}

function countThemeConfigurations(snapshot) {
  if (!snapshot || !Array.isArray(snapshot.entries)) return 0
  return snapshot.entries.reduce((count, entry) => {
    if (!isPlainObject(entry)) return count
    return count
      + (entry.currentLight ? 1 : 0)
      + (entry.currentDark ? 1 : 0)
      + (Array.isArray(entry.savedLight) ? entry.savedLight.length : 0)
      + (Array.isArray(entry.savedDark) ? entry.savedDark.length : 0)
  }, 0)
}

function cloudSongSourceRaw(song) {
  const value = String(song?.source || song?.provider || song?.platform || '').trim()
  if (value) return value
  if (song?.qishuiTrackId) return 'qishui'
  if (song?.qqMid) return 'qqmusic'
  return 'netease'
}

function cloudSongMetadata(song) {
  if (!isPlainObject(song)) return null
  const songId = song.id ?? song.songId ?? song.ncmId ?? song.cloudSongId
  if (songId === undefined || songId === null || songId === '') return null
  const sourceRaw = cloudSongSourceRaw(song)
  const album = isPlainObject(song.al) ? song.al : null
  return {
    songIdentifier: `${sourceRaw}:${songId}`,
    songId: Number.isFinite(Number(songId)) ? Number(songId) : songId,
    songName: String(song.name || song.songName || song.title || '').trim(),
    artistName: readArtistNames(song).join(', '),
    albumName: String(song.albumName || song.album || album?.name || '').trim() || null,
    coverUrl: cloudSongCoverUrl(song),
    sourceRaw
  }
}

function supplementAIEqualizerMetadata(aiEqualizer, playlists) {
  if (!isPlainObject(aiEqualizer)) return aiEqualizer

  const requestedKeys = new Set(Object.keys(aiEqualizer.cachedProposals || {}))
  const requestedSongIds = new Set()
  for (const proposal of Object.values(aiEqualizer.cachedProposals || {})) {
    if (proposal?.songID !== undefined && proposal?.songID !== null) {
      requestedSongIds.add(String(proposal.songID))
    }
  }
  for (const [songIdentifier, entries] of Object.entries(aiEqualizer.savedProposals || {})) {
    requestedKeys.add(String(songIdentifier))
    if (!Array.isArray(entries)) continue
    for (const entry of entries) {
      const songID = entry?.proposal?.songID ?? entry?.songID
      if (songID !== undefined && songID !== null) requestedSongIds.add(String(songID))
    }
  }

  const proposalMetadata = isPlainObject(aiEqualizer.proposalMetadata)
    ? { ...aiEqualizer.proposalMetadata }
    : {}

  for (const playlist of Array.isArray(playlists) ? playlists : []) {
    for (const song of Array.isArray(playlist?.songs) ? playlist.songs : []) {
      const item = cloudSongMetadata(song)
      if (!item) continue
      const songId = String(item.songId)
      const sourceRaw = item.sourceRaw
      const keys = [
        item.songIdentifier,
        songId,
        `${sourceRaw}:${songId}`,
        sourceRaw === 'netease' ? `netease|${songId}` : '',
        song.qqMid,
        song.qqMid ? `qqmusic:${song.qqMid}` : '',
        song.qishuiTrackId,
        song.qishuiTrackId ? `qishui:${song.qishuiTrackId}` : ''
      ].filter(Boolean).map(String)

      if (!requestedSongIds.has(songId) && !keys.some(key => requestedKeys.has(key))) continue
      for (const key of keys) proposalMetadata[key] = item
    }
  }

  return Object.keys(proposalMetadata).length
    ? { ...aiEqualizer, proposalMetadata }
    : aiEqualizer
}

function stableStringify(value) {
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(',')}]`
  }
  if (value && typeof value === 'object') {
    return `{${Object.keys(value)
      .sort()
      .map(key => `${JSON.stringify(key)}:${stableStringify(value[key])}`)
      .join(',')}}`
  }
  return JSON.stringify(value)
}

function makePlaylistSnapshot(playlists, extra = {}) {
  const normalizedPlaylists = Array.isArray(playlists)
    ? playlists.map(normalizePlaylistItem).filter(Boolean)
    : []

  const previousSnapshot = isPlainObject(extra.previousSnapshot) ? extra.previousSnapshot : null
  const clientVersion = Number.isFinite(Number(extra.clientVersion))
    ? Number(extra.clientVersion)
    : 2
  const version = Number.isInteger(extra.version)
    ? Math.max(1, extra.version)
    : CLOUD_SNAPSHOT_VERSION
  const downloads = resolveVersionedArray(
    extra.downloads,
    previousSnapshot?.downloads,
    clientVersion
  )
  const localRadioSubscriptions = resolveVersionedArray(
    extra.localRadioSubscriptions,
    previousSnapshot?.localRadioSubscriptions,
    clientVersion
  )
  const themeCustomization = resolveVersionedSnapshotField(
    extra.themeCustomization,
    previousSnapshot?.themeCustomization,
    clientVersion,
    normalizeThemeCustomization
  )
  const playbackHistory = resolveVersionedSnapshotField(
    extra.playbackHistory,
    previousSnapshot?.playbackHistory,
    clientVersion,
    normalizePlaybackHistory
  )
  let aiEqualizer = resolveVersionedSnapshotField(
    extra.aiEqualizer,
    previousSnapshot?.aiEqualizer,
    clientVersion,
    normalizeAIEqualizer
  )
  aiEqualizer = supplementAIEqualizerMetadata(aiEqualizer, normalizedPlaylists)
  const customEQPresets = resolveVersionedSnapshotField(
    extra.customEQPresets,
    previousSnapshot?.customEQPresets,
    clientVersion,
    normalizeCustomEQPresets
  )

  const revision = crypto
    .createHash('sha1')
    .update(stableStringify({
      playlists: normalizedPlaylists,
      downloads,
      localRadioSubscriptions,
      themeCustomization,
      playbackHistory,
      aiEqualizer,
      customEQPresets
    }))
    .digest('hex')
    .slice(0, 16)
  const updatedAt = typeof extra.updatedAt === 'string' && !Number.isNaN(Date.parse(extra.updatedAt))
    ? new Date(extra.updatedAt).toISOString()
    : new Date().toISOString()

  return {
    version,
    updatedAt,
    revision,
    deviceId: typeof extra.deviceId === 'string' ? extra.deviceId : null,
    deviceName: typeof extra.deviceName === 'string' ? extra.deviceName : null,
    playlistCount: normalizedPlaylists.length,
    songCount: normalizedPlaylists.reduce((sum, playlist) => {
      return sum + (Array.isArray(playlist.songs) ? playlist.songs.length : 0)
    }, 0),
    playlists: normalizedPlaylists,
    downloads,
    localRadioSubscriptions,
    themeCustomization,
    playbackHistory,
    aiEqualizer,
    customEQPresets
  }
}

function playlistSnapshotETag(snapshot) {
  return `"${snapshot?.revision || 'empty'}"`
}

function requestMatchesETag(req, etag) {
  const value = req.headers['if-none-match']
  if (typeof value !== 'string') return false
  return value
    .split(',')
    .map(item => item.trim().replace(/^W\//, ''))
    .some(item => item === '*' || item === etag)
}

function playlistSnapshotSummary(snapshot) {
  if (!snapshot) {
    return {
      hasSnapshot: false,
      version: null,
      updatedAt: null,
      revision: null,
      deviceId: null,
      deviceName: null,
      playlistCount: 0,
      songCount: 0,
      downloadCount: 0,
      radioCount: 0,
      colorConfigurationCount: 0,
      playbackRecordCount: 0,
      listeningRecordCount: 0,
      aiTuningPlanCount: 0,
      customEQPresetCount: 0
    }
  }

  const playbackRecords = Array.isArray(snapshot.playbackHistory?.records)
    ? snapshot.playbackHistory.records
    : []

  return {
    hasSnapshot: true,
    version: snapshot.version || 2,
    updatedAt: snapshot.updatedAt || null,
    revision: snapshot.revision || null,
    deviceId: snapshot.deviceId || null,
    deviceName: snapshot.deviceName || null,
    playlistCount: snapshot.playlistCount || 0,
    songCount: snapshot.songCount || 0,
    downloadCount: Array.isArray(snapshot.downloads) ? snapshot.downloads.length : 0,
    radioCount: Array.isArray(snapshot.localRadioSubscriptions) ? snapshot.localRadioSubscriptions.length : 0,
    colorConfigurationCount: countThemeConfigurations(snapshot.themeCustomization),
    playbackRecordCount: playbackRecords.length,
    listeningRecordCount: playbackRecords.filter(record => Number(record?.playDuration) > 0).length,
    aiTuningPlanCount: countAIEqualizerPlans(snapshot.aiEqualizer),
    customEQPresetCount: Array.isArray(snapshot.customEQPresets) ? snapshot.customEQPresets.length : 0
  }
}

function readArtistNames(song) {
  const values = []
  const push = value => {
    if (!value) return
    if (typeof value === 'string') {
      value
        .split(/[、,/，]+/)
        .map(item => item.trim())
        .filter(Boolean)
        .forEach(item => values.push(item))
      return
    }
    if (Array.isArray(value)) {
      value.forEach(push)
      return
    }
    if (typeof value === 'object') {
      push(value.name || value.artistName || value.nickname || value.title)
    }
  }
  push(song?.artist)
  push(song?.artists)
  push(song?.ar)
  push(song?.singer)
  push(song?.artistName)
  push(song?.author)
  return [...new Set(values)]
}

function readSongAlbum(song) {
  if (typeof song?.album === 'string' && song.album) return song.album
  if (typeof song?.albumName === 'string' && song.albumName) return song.albumName
  if (typeof song?.al?.name === 'string' && song.al.name) return song.al.name
  return ''
}

function cloudMusicStats(snapshot) {
  const artists = new Set()
  const albums = new Set()
  const playlists = Array.isArray(snapshot?.playlists) ? snapshot.playlists : []
  for (const playlist of playlists) {
    const songs = Array.isArray(playlist?.songs) ? playlist.songs : []
    for (const song of songs) {
      readArtistNames(song).forEach(name => artists.add(name))
      const album = readSongAlbum(song)
      if (album) albums.add(album)
    }
  }
  return {
    artistCount: artists.size,
    albumCount: albums.size
  }
}

function hasNonPlaylistSnapshotData(snapshot) {
  if (!snapshot) return false
  return (Array.isArray(snapshot.downloads) && snapshot.downloads.length > 0)
    || (Array.isArray(snapshot.localRadioSubscriptions) && snapshot.localRadioSubscriptions.length > 0)
    || Boolean(snapshot.themeCustomization)
    || Boolean(snapshot.playbackHistory)
    || Boolean(snapshot.aiEqualizer)
    || (Array.isArray(snapshot.customEQPresets) && snapshot.customEQPresets.length > 0)
}

function playlistAdminPayload(playlist) {
  return {
    id: playlist.id,
    name: playlist.name,
    desc: playlist.desc,
    coverUrl: cloudPlaylistCoverUrl(playlist),
    createdAt: playlist.createdAt,
    updatedAt: playlist.updatedAt,
    isSystem: Boolean(playlist.isSystem),
    songCount: Array.isArray(playlist.songs) ? playlist.songs.length : 0,
    songs: Array.isArray(playlist.songs)
      ? playlist.songs.map((song, index) => ({
        ...song,
        coverUrl: cloudSongCoverUrl(song),
        __songKey: playlistSongKey(song, index)
      }))
      : []
  }
}

function cloudPublicPayload(token) {
  const snapshot = token.playlistSnapshot
  const summary = playlistSnapshotSummary(snapshot)
  const musicStats = cloudMusicStats(snapshot)
  return {
    ok: true,
    token: {
      name: token.name,
      email: token.email || null,
      enabled: Boolean(token.enabled),
      expiresAt: token.expiresAt,
      isExpired: Boolean(token.expiresAt) && new Date(token.expiresAt) <= new Date()
    },
    snapshot: {
      ...summary,
      ...musicStats,
      playlists: snapshot?.playlists?.map(playlistAdminPayload) || [],
      downloads: snapshot?.downloads || [],
      localRadioSubscriptions: snapshot?.localRadioSubscriptions || [],
      themeCustomization: snapshot?.themeCustomization || null,
      playbackHistory: snapshot?.playbackHistory || null,
      aiEqualizer: snapshot?.aiEqualizer || null,
      customEQPresets: snapshot?.customEQPresets || []
    }
  }
}

const CLOUD_MODULES = new Set(['downloads', 'radios', 'themes', 'playback', 'ai', 'eq'])

function rebuildSnapshotWithModule(snapshot, module, value) {
  const next = snapshot || {}
  const extra = {
    version: CLOUD_SNAPSHOT_VERSION,
    clientVersion: CLOUD_SNAPSHOT_VERSION,
    previousSnapshot: next,
    deviceId: next.deviceId,
    deviceName: next.deviceName,
    downloads: next.downloads,
    localRadioSubscriptions: next.localRadioSubscriptions,
    themeCustomization: next.themeCustomization,
    playbackHistory: next.playbackHistory,
    aiEqualizer: next.aiEqualizer,
    customEQPresets: next.customEQPresets
  }
  if (module === 'downloads') extra.downloads = value
  if (module === 'radios') extra.localRadioSubscriptions = value
  if (module === 'themes') extra.themeCustomization = value
  if (module === 'playback') extra.playbackHistory = value
  if (module === 'ai') extra.aiEqualizer = value
  if (module === 'eq') extra.customEQPresets = value
  return makePlaylistSnapshot(next.playlists || [], extra)
}

function cloudModuleValue(snapshot, module) {
  if (!snapshot) return null
  if (module === 'downloads') return Array.isArray(snapshot.downloads) ? snapshot.downloads : []
  if (module === 'radios') return Array.isArray(snapshot.localRadioSubscriptions) ? snapshot.localRadioSubscriptions : []
  if (module === 'themes') return snapshot.themeCustomization || null
  if (module === 'playback') return snapshot.playbackHistory || null
  if (module === 'ai') return snapshot.aiEqualizer || null
  if (module === 'eq') return Array.isArray(snapshot.customEQPresets) ? snapshot.customEQPresets : []
  return null
}

function clearCloudModule(token, module) {
  if (module === 'downloads') token.playlistSnapshot = rebuildSnapshotWithModule(token.playlistSnapshot, module, [])
  if (module === 'radios') token.playlistSnapshot = rebuildSnapshotWithModule(token.playlistSnapshot, module, [])
  if (module === 'themes') token.playlistSnapshot = rebuildSnapshotWithModule(token.playlistSnapshot, module, null)
  if (module === 'playback') token.playlistSnapshot = rebuildSnapshotWithModule(token.playlistSnapshot, module, null)
  if (module === 'ai') token.playlistSnapshot = rebuildSnapshotWithModule(token.playlistSnapshot, module, null)
  if (module === 'eq') token.playlistSnapshot = rebuildSnapshotWithModule(token.playlistSnapshot, module, [])
}

function itemKeyForCloudItem(item, index) {
  const raw = item?.id
    ?? item?.songId
    ?? item?.key
    ?? item?.theme
    ?? item?.name
    ?? item?.title
    ?? item?.playedAt
  return encodeURIComponent(String(raw || `item-${index}`))
}

function removeArrayCloudItem(items, itemKey) {
  if (!Array.isArray(items)) return { items: [], removed: false }
  const decoded = decodeURIComponent(String(itemKey || ''))
  const next = items.filter((item, index) => {
    const raw = item?.id
      ?? item?.songId
      ?? item?.key
      ?? item?.theme
      ?? item?.name
      ?? item?.title
      ?? item?.playedAt
      ?? `item-${index}`
    return String(raw) !== decoded && String(index) !== decoded
  })
  return { items: next, removed: next.length !== items.length }
}

function playlistSongKey(song, index = 0) {
  const raw = song?.id
    ?? song?.songId
    ?? song?.mid
    ?? song?.cloudSongId
    ?? song?.ncmId
    ?? (song?.name && song?.artist ? `${song.name}::${song.artist}` : null)
  return String(raw || `song-${index}`)
}

function tokenSummaryPayload(token) {
  const isExpired = Boolean(token.expiresAt) && new Date(token.expiresAt) <= new Date()
  return {
    id: token.id,
    key: token.key,
    name: token.name,
    email: token.email || null,
    registeredName: token.registeredName || null,
    source: token.source || null,
    enabled: Boolean(token.enabled),
    createdAt: token.createdAt,
    expiresAt: token.expiresAt,
    lastUsed: token.lastUsed,
    requestCount: token.requestCount || 0,
    playRequestCount: token.playRequestCount || 0,
    playTrafficBytes: token.playTrafficBytes || 0,
    totalDownloads: token.totalDownloads || 0,
    rateLimit: token.rateLimit || 0,
    downloadLimit: token.downloadLimit || 0,
    maxDevices: token.maxDevices || 0,
    deviceCount: Array.isArray(token.devices) ? token.devices.length : 0,
    isExpired,
    playlistSnapshot: playlistSnapshotSummary(token.playlistSnapshot)
  }
}

function tokenDetailPayload(token) {
  const todayCount = getTodayDownloads(token)
  const remainingDownloads = token.downloadLimit > 0
    ? Math.max(0, token.downloadLimit - todayCount)
    : -1

  return {
    ...tokenSummaryPayload(token),
    devices: Array.isArray(token.devices) ? token.devices : [],
    dailyStats: token.dailyStats || {},
    dailyPlayStats: token.dailyPlayStats || {},
    dailyPlayTraffic: token.dailyPlayTraffic || {},
    dailyDownloads: token.dailyDownloads || {},
    todayDownloads: todayCount,
    remainingDownloads
  }
}

function rebuildPlaylistSnapshot(snapshot) {
  if (!snapshot) return null
  return makePlaylistSnapshot(snapshot.playlists || [], {
    version: snapshot.version,
    clientVersion: snapshot.version,
    previousSnapshot: snapshot,
    deviceId: snapshot.deviceId,
    deviceName: snapshot.deviceName,
    downloads: snapshot.downloads,
    localRadioSubscriptions: snapshot.localRadioSubscriptions,
    themeCustomization: snapshot.themeCustomization,
    playbackHistory: snapshot.playbackHistory,
    aiEqualizer: snapshot.aiEqualizer,
    customEQPresets: snapshot.customEQPresets
  })
}

function findTokenOrRespond(data, tokenId, res) {
  const token = data.tokens.find(item => item.id === tokenId)
  if (!token) {
    res.status(404).json({ error: '未找到' })
    return null
  }
  return token
}

function findPlaylistOrRespond(token, playlistId, res) {
  const snapshot = token.playlistSnapshot
  if (!snapshot || !Array.isArray(snapshot.playlists) || !snapshot.playlists.length) {
    res.status(404).json({ error: '未找到歌单快照' })
    return null
  }

  const playlist = snapshot.playlists.find(item => String(item.id) === String(playlistId))
  if (!playlist) {
    res.status(404).json({ error: '未找到歌单' })
    return null
  }
  return playlist
}
// --------------- Auth middleware ---------------
function authMiddleware(req, res, next) {
  const token = req.headers['x-admin-token']
  const data = loadData()
  const session = resolveAdminSession(token, data.adminPassword)
  if (!session) {
    return res.status(401).json({ error: '未授权' })
  }
  data.tokens = data.tokens.map(migrateToken)
  data.ipaReleases = sortReleasesDesc(data.ipaReleases.map(migrateRelease))
  data.appChangelogs = sortChangelogsDesc((data.appChangelogs || []).map(migrateChangelog))
  req.appData = data
  req.admin = { id: session.actorId }
  next()
}

installAIRemoteConfigRoutes({
  app,
  loadData,
  saveData,
  authMiddleware,
  resolvePublicToken
})

function songContentPublicRateLimit(req, res, next) {
  const identity = String(req.query?.token || req.ip || 'anonymous').slice(0, 256)
  if (!checkRateLimit(`song-content:${identity}`, 120)) {
    res.set('Retry-After', '60')
    return res.status(429).json({ error: '请求过于频繁', code: 'RATE_LIMITED' })
  }
  next()
}

const songContentAdapters = createTokenSongContentAdapters()
songContentService = installTokenSongContent({
  app,
  dataDirectory: __dirname,
  adminUIRoot: PUBLIC_DIR,
  authMiddleware,
  resolvePublicToken,
  publicRateLimit: songContentPublicRateLimit,
  appAIConfigProvider: () => loadData().aiProviderConfig,
  resolveChangelog: resolvePublishedChangelog,
  platformResolver: songContentAdapters.platformResolver,
  sourceCollector: songContentAdapters.sourceCollector,
  encryptionKey: process.env.SONG_CONTENT_MASTER_KEY
    || fs.readFileSync(path.join(__dirname, '.song-content-master-key'), 'utf8').trim(),
  logger: console
})

// --------------- Auth routes ---------------
app.get('/api/auth/check', authMiddleware, (req, res) => {
  res.json({
    ok: true,
    actorId: req.admin.id,
    permissions: songContentService?.store?.actorPermissions?.(req.admin.id) || []
  })
})

app.post('/api/auth/logout', authMiddleware, (req, res) => {
  const token = String(req.headers['x-admin-token'] || '')
  if (token && token !== req.appData.adminPassword) adminSessions.delete(token)
  res.json({ ok: true })
})

app.post('/api/auth/login', (req, res) => {
  const { password } = req.body
  const data = loadData()
  if (password === data.adminPassword) {
    const actorId = normalizeAdminActorId(req.body?.actorId)
    const hasAssignment = songContentService?.store?.listRoleAssignments?.()
      .some((assignment) => assignment.actorId === actorId)
    if (!hasAssignment) {
      songContentService?.store?.assignRole?.(actorId, 'content-admin', 'system-login')
    }
    const session = createAdminSession(actorId)
    return res.json({
      ok: true,
      token: session.token,
      actorId,
      permissions: songContentService?.store?.actorPermissions?.(actorId) || [],
      expiresAt: new Date(session.expiresAt).toISOString()
    })
  }
  res.status(401).json({ error: '密码错误' })
})

app.post('/api/auth/change-password', authMiddleware, (req, res) => {
  const { newPassword } = req.body
  if (!newPassword || newPassword.length < 6) {
    return res.status(400).json({ error: '密码至少6位' })
  }
  req.appData.adminPassword = newPassword
  saveData(req.appData)
  adminSessions.clear()
  res.json({ ok: true })
})

function playUsageKey() {
  try {
    return fs.readFileSync(PLAY_USAGE_KEY_FILE, 'utf8').trim()
  } catch (_) {
    return ''
  }
}

function trimDailySeries(series, days = 30) {
  const keys = Object.keys(series || {}).sort()
  if (keys.length <= days) return series || {}
  const next = {}
  keys.slice(-days).forEach(key => { next[key] = series[key] })
  return next
}

function ensurePlatformPlayUsage(data, platform) {
  if (!data.platformPlayUsage || typeof data.platformPlayUsage !== 'object') {
    data.platformPlayUsage = {}
  }
  if (!data.platformPlayUsage[platform] || typeof data.platformPlayUsage[platform] !== 'object') {
    data.platformPlayUsage[platform] = {
      requests: 0,
      bytes: 0,
      dailyStats: {},
      dailyTraffic: {}
    }
  }
  const usage = data.platformPlayUsage[platform]
  if (!usage.dailyStats || typeof usage.dailyStats !== 'object') usage.dailyStats = {}
  if (!usage.dailyTraffic || typeof usage.dailyTraffic !== 'object') usage.dailyTraffic = {}
  return usage
}

function playSeries(tokens, days = 14, globalUsage = null) {
  const dates = []
  const cursor = new Date()
  cursor.setUTCHours(0, 0, 0, 0)
  for (let offset = days - 1; offset >= 0; offset -= 1) {
    const date = new Date(cursor)
    date.setUTCDate(cursor.getUTCDate() - offset)
    dates.push(date.toISOString().slice(0, 10))
  }

  return dates.map(date => ({
    date,
    requests: tokens.reduce((sum, token) => sum + Number(token.dailyPlayStats?.[date] || 0), 0)
      + Number(globalUsage?.dailyStats?.[date] || 0),
    bytes: tokens.reduce((sum, token) => sum + Number(token.dailyPlayTraffic?.[date] || 0), 0)
      + Number(globalUsage?.dailyTraffic?.[date] || 0)
  }))
}

app.post('/api/internal/play-usage', (req, res) => {
  const expected = playUsageKey()
  const supplied = String(req.headers['x-play-usage-key'] || '')
  if (!expected || supplied.length !== expected.length) return res.sendStatus(403)
  if (!crypto.timingSafeEqual(Buffer.from(supplied), Buffer.from(expected))) return res.sendStatus(403)

  const data = loadData()
  data.tokens = data.tokens.map(migrateToken)
  const platform = ['ncm', 'qcm', 'qsm'].includes(req.body?.platform)
    ? req.body.platform
    : 'ncm'
  const token = data.tokens.find(item => item.key === req.body?.token)
  if (platform !== 'qsm' && !token) return res.sendStatus(404)

  const requests = Math.min(100, Math.max(0, Math.floor(Number(req.body?.requests || 0))))
  const bytes = Math.min(1024 ** 4, Math.max(0, Math.floor(Number(req.body?.bytes || 0))))
  if (!requests && !bytes) return res.status(400).json({ error: 'invalid play usage' })

  const today = todayKey()
  const platformUsage = ensurePlatformPlayUsage(data, platform)
  platformUsage.requests = Number(platformUsage.requests || 0) + requests
  platformUsage.bytes = Number(platformUsage.bytes || 0) + bytes
  platformUsage.dailyStats[today] = Number(platformUsage.dailyStats[today] || 0) + requests
  platformUsage.dailyTraffic[today] = Number(platformUsage.dailyTraffic[today] || 0) + bytes
  platformUsage.dailyStats = trimDailySeries(platformUsage.dailyStats)
  platformUsage.dailyTraffic = trimDailySeries(platformUsage.dailyTraffic)

  if (token && platform !== 'qsm') {
    token.lastUsed = new Date().toISOString()
    token.playRequestCount = (token.playRequestCount || 0) + requests
    token.playTrafficBytes = (token.playTrafficBytes || 0) + bytes
    token.requestCount = (token.requestCount || 0) + requests
    token.dailyStats[today] = (token.dailyStats[today] || 0) + requests
    token.dailyPlayStats[today] = (token.dailyPlayStats[today] || 0) + requests
    token.dailyPlayTraffic[today] = (token.dailyPlayTraffic[today] || 0) + bytes
    token.dailyStats = trimDailySeries(token.dailyStats)
    token.dailyPlayStats = trimDailySeries(token.dailyPlayStats)
    token.dailyPlayTraffic = trimDailySeries(token.dailyPlayTraffic)
  }
  scheduleUsageSave(data, 1_000)

  res.json({ ok: true })
})

// --------------- Status / Stats ---------------
app.get('/api/status', authMiddleware, (req, res) => {
  const {
    globalEnabled,
    rateLimitEnabled,
    defaultRateLimit,
    downloadLimitEnabled,
    defaultDownloadLimit,
    deviceBindEnabled,
    maxDevicesPerToken,
    qqRiskControlEnabled,
    tokens,
    ipaReleases,
    appChangelogs
  } = req.appData
  const today = todayKey()
  let totalRequests = 0
  let todayRequests = 0
  let totalDownloads = 0
  let todayDownloads = 0
  let totalPlayRequests = 0
  let todayPlayRequests = 0
  let totalPlayTrafficBytes = 0
  let todayPlayTrafficBytes = 0
  const activeCount = tokens.filter(t => {
    const notExpired = !t.expiresAt || new Date(t.expiresAt) > new Date()
    return t.enabled && notExpired
  }).length

  tokens.forEach(t => {
    totalRequests += t.requestCount || 0
    totalDownloads += t.totalDownloads || 0
    totalPlayRequests += t.playRequestCount || 0
    totalPlayTrafficBytes += t.playTrafficBytes || 0
    if (t.dailyStats && t.dailyStats[today]) {
      todayRequests += t.dailyStats[today]
    }
    if (t.dailyDownloads && t.dailyDownloads[today]) {
      todayDownloads += t.dailyDownloads[today]
    }
    if (t.dailyPlayStats && t.dailyPlayStats[today]) {
      todayPlayRequests += t.dailyPlayStats[today]
    }
    if (t.dailyPlayTraffic && t.dailyPlayTraffic[today]) {
      todayPlayTrafficBytes += t.dailyPlayTraffic[today]
    }
  })

  const publishedReleases = ipaReleases.filter(release => release.published && hasReleaseFile(release))
  const latestPublishedRelease = publishedReleases[0] ? publicReleasePayload(publishedReleases[0]) : null
  const publishedChangelogs = appChangelogs.filter(item => item.published)
  const latestPublishedChangelog = publishedChangelogs[0] ? publicChangelogPayload(publishedChangelogs[0]) : null
  const qsmUsage = ensurePlatformPlayUsage(req.appData, 'qsm')
  totalPlayRequests += Number(qsmUsage.requests || 0)
  todayPlayRequests += Number(qsmUsage.dailyStats?.[today] || 0)
  totalPlayTrafficBytes += Number(qsmUsage.bytes || 0)
  todayPlayTrafficBytes += Number(qsmUsage.dailyTraffic?.[today] || 0)

  res.json({
    globalEnabled,
    rateLimitEnabled,
    defaultRateLimit,
    downloadLimitEnabled,
    defaultDownloadLimit,
    tokens: tokens.map(tokenSummaryPayload),
    totalRequests,
    todayRequests,
    totalPlayRequests,
    todayPlayRequests,
    totalPlayTrafficBytes,
    todayPlayTrafficBytes,
    playSeries: playSeries(tokens, 14, qsmUsage),
    platformPlayUsage: req.appData.platformPlayUsage,
    totalDownloads,
    todayDownloads,
    activeCount,
    totalCount: tokens.length,
    deviceBindEnabled,
    maxDevicesPerToken,
    qqRiskControlEnabled,
    ipaReleases: ipaReleases.map(adminReleasePayload),
    ipaReleaseCount: ipaReleases.length,
    publishedIpaReleaseCount: publishedReleases.length,
    latestPublishedRelease,
    appChangelogs: appChangelogs.map(adminChangelogPayload),
    appChangelogCount: appChangelogs.length,
    publishedAppChangelogCount: publishedChangelogs.length,
    latestPublishedChangelog
  })
})

// --------------- Global toggle ---------------
app.post('/api/toggle', authMiddleware, (req, res) => {
  req.appData.globalEnabled = !req.appData.globalEnabled
  saveData(req.appData)
  res.json({ globalEnabled: req.appData.globalEnabled })
})

// --------------- QQ Risk Control toggle ---------------
app.post('/api/qq-risk-control/toggle', authMiddleware, (req, res) => {
  req.appData.qqRiskControlEnabled = !req.appData.qqRiskControlEnabled
  saveData(req.appData)
  res.json({ qqRiskControlEnabled: req.appData.qqRiskControlEnabled })
})

app.get('/api/public/qq-risk-control', (req, res) => {
  const data = loadData()
  res.json({ qqRiskControlEnabled: Boolean(data.qqRiskControlEnabled) })
})

// --------------- Rate limit settings ---------------
app.post('/api/ratelimit/toggle', authMiddleware, (req, res) => {
  req.appData.rateLimitEnabled = !req.appData.rateLimitEnabled
  saveData(req.appData)
  res.json({ rateLimitEnabled: req.appData.rateLimitEnabled })
})

app.post('/api/ratelimit/default', authMiddleware, (req, res) => {
  const { value } = req.body
  if (value === undefined || value < 0) {
    return res.status(400).json({ error: '无效的限速值' })
  }
  req.appData.defaultRateLimit = value
  saveData(req.appData)
  res.json({ defaultRateLimit: value })
})

app.post('/api/ratelimit/apply-all', authMiddleware, (req, res) => {
  const { value } = req.body
  const limit = value !== undefined ? value : req.appData.defaultRateLimit
  req.appData.tokens.forEach(t => { t.rateLimit = limit })
  saveData(req.appData)
  res.json({ ok: true, applied: req.appData.tokens.length, value: limit })
})

// --------------- Download limit settings ---------------
app.post('/api/downloadlimit/toggle', authMiddleware, (req, res) => {
  req.appData.downloadLimitEnabled = !req.appData.downloadLimitEnabled
  saveData(req.appData)
  res.json({ downloadLimitEnabled: req.appData.downloadLimitEnabled })
})

app.post('/api/downloadlimit/default', authMiddleware, (req, res) => {
  const { value } = req.body
  if (value === undefined || value < 0) {
    return res.status(400).json({ error: '无效的下载限制值' })
  }
  req.appData.defaultDownloadLimit = value
  saveData(req.appData)
  res.json({ defaultDownloadLimit: value })
})

app.post('/api/downloadlimit/apply-all', authMiddleware, (req, res) => {
  const { value } = req.body
  const limit = value !== undefined ? value : req.appData.defaultDownloadLimit
  req.appData.tokens.forEach(t => { t.downloadLimit = limit })
  saveData(req.appData)
  res.json({ ok: true, applied: req.appData.tokens.length, value: limit })
})

// --------------- Download stats per token ---------------
app.get('/api/tokens/:id/downloads', authMiddleware, (req, res) => {
  const t = req.appData.tokens.find(t => t.id === req.params.id)
  if (!t) return res.status(404).json({ error: '未找到' })
  const today = todayKey()
  const todayCount = getTodayDownloads(t)
  const remaining = t.downloadLimit > 0 ? Math.max(0, t.downloadLimit - todayCount) : -1
  res.json({
    tokenName: t.name,
    downloadLimit: t.downloadLimit,
    todayDownloads: todayCount,
    totalDownloads: t.totalDownloads || 0,
    remaining,
    dailyDownloads: t.dailyDownloads || {}
  })
})

app.get('/api/tokens/:id', authMiddleware, (req, res) => {
  const token = findTokenOrRespond(req.appData, req.params.id, res)
  if (!token) return
  res.json(tokenDetailPayload(token))
})

app.get('/api/tokens/:id/playlists', authMiddleware, (req, res) => {
  const token = findTokenOrRespond(req.appData, req.params.id, res)
  if (!token) return

  const snapshot = token.playlistSnapshot
  res.json({
    tokenId: token.id,
    tokenName: token.name,
    ...playlistSnapshotSummary(snapshot),
    playlists: snapshot?.playlists?.map(playlistAdminPayload) || []
  })
})

app.delete('/api/tokens/:id/playlists', authMiddleware, (req, res) => {
  const token = findTokenOrRespond(req.appData, req.params.id, res)
  if (!token) return

  token.playlistSnapshot = null
  saveData(req.appData)
  res.json({ ok: true })
})

app.delete('/api/tokens/:id/playlists/:playlistId', authMiddleware, (req, res) => {
  const token = findTokenOrRespond(req.appData, req.params.id, res)
  if (!token) return

  const playlist = findPlaylistOrRespond(token, req.params.playlistId, res)
  if (!playlist) return

  token.playlistSnapshot.playlists = token.playlistSnapshot.playlists.filter(item => item !== playlist)
  token.playlistSnapshot = token.playlistSnapshot.playlists.length
    || hasNonPlaylistSnapshotData(token.playlistSnapshot)
    ? rebuildPlaylistSnapshot(token.playlistSnapshot)
    : null
  saveData(req.appData)

  res.json({
    ok: true,
    playlistSnapshot: playlistSnapshotSummary(token.playlistSnapshot)
  })
})

app.delete('/api/tokens/:id/playlists/:playlistId/songs/:songId', authMiddleware, (req, res) => {
  const token = findTokenOrRespond(req.appData, req.params.id, res)
  if (!token) return

  const playlist = findPlaylistOrRespond(token, req.params.playlistId, res)
  if (!playlist) return

  const songId = String(req.params.songId)
  const nextSongs = (playlist.songs || []).filter((song, index) => playlistSongKey(song, index) !== songId)
  if (nextSongs.length === (playlist.songs || []).length) {
    return res.status(404).json({ error: '未找到歌曲' })
  }

  playlist.songs = nextSongs
  playlist.updatedAt = new Date().toISOString()
  token.playlistSnapshot = rebuildPlaylistSnapshot(token.playlistSnapshot)
  saveData(req.appData)

  res.json({
    ok: true,
    playlistSnapshot: playlistSnapshotSummary(token.playlistSnapshot),
    playlist: playlistAdminPayload(
      token.playlistSnapshot.playlists.find(item => String(item.id) === String(req.params.playlistId))
    )
  })
})

// --------------- Token CRUD ---------------
app.post('/api/tokens', authMiddleware, (req, res) => {
  const { name, email, expiresIn, expiresInHours, rateLimit, downloadLimit, maxDevices } = req.body
  if (!name || !name.trim()) {
    return res.status(400).json({ error: '请填写用户名' })
  }
  if (!email || !email.includes('@')) {
    return res.status(400).json({ error: '请填写有效邮箱' })
  }
  const key = genToken()

  let expiresAt = null
  if (expiresInHours && expiresInHours > 0) {
    expiresAt = new Date(Date.now() + expiresInHours * 3600_000).toISOString()
  } else if (expiresIn && expiresIn > 0) {
    expiresAt = new Date(Date.now() + expiresIn * 86400_000).toISOString()
  }

  const token = {
    id: crypto.randomUUID(),
    key,
    name: name.trim(),
    email: email.trim().toLowerCase(),
    registeredName: name.trim(),
    enabled: true,
    createdAt: new Date().toISOString(),
    expiresAt,
    lastUsed: null,
    requestCount: 0,
    rateLimit: rateLimit !== undefined ? rateLimit : (req.appData.defaultRateLimit || 60),
    downloadLimit: downloadLimit !== undefined ? downloadLimit : (req.appData.defaultDownloadLimit || 0),
    maxDevices: maxDevices !== undefined ? maxDevices : (req.appData.maxDevicesPerToken || 3),
    devices: [],
    dailyStats: {},
    dailyDownloads: {},
    totalDownloads: 0
  }
  req.appData.tokens.push(token)
  saveData(req.appData)
  res.json(token)
})

app.put('/api/tokens/:id/toggle', authMiddleware, (req, res) => {
  const t = req.appData.tokens.find(t => t.id === req.params.id)
  if (!t) return res.status(404).json({ error: '未找到' })
  t.enabled = !t.enabled
  saveData(req.appData)
  res.json(t)
})

app.put('/api/tokens/:id', authMiddleware, (req, res) => {
  const t = req.appData.tokens.find(t => t.id === req.params.id)
  if (!t) return res.status(404).json({ error: '未找到' })
  if (req.body.name !== undefined) t.name = req.body.name
  if (req.body.rateLimit !== undefined) t.rateLimit = req.body.rateLimit
  if (req.body.expiresAt !== undefined) t.expiresAt = req.body.expiresAt
  if (req.body.downloadLimit !== undefined) t.downloadLimit = req.body.downloadLimit
  if (req.body.maxDevices !== undefined) t.maxDevices = req.body.maxDevices
  saveData(req.appData)
  res.json(t)
})

app.delete('/api/tokens/:id', authMiddleware, (req, res) => {
  const idx = req.appData.tokens.findIndex(t => t.id === req.params.id)
  if (idx === -1) return res.status(404).json({ error: '未找到' })
  req.appData.tokens.splice(idx, 1)
  saveData(req.appData)
  res.json({ ok: true })
})

app.post('/api/tokens/:id/regenerate', authMiddleware, (req, res) => {
  const t = req.appData.tokens.find(t => t.id === req.params.id)
  if (!t) return res.status(404).json({ error: '未找到' })
  t.key = genToken()
  saveData(req.appData)
  res.json(t)
})

// --------------- Batch operations ---------------
app.post('/api/tokens/batch', authMiddleware, (req, res) => {
  const { action, ids } = req.body
  if (!Array.isArray(ids) || !ids.length) {
    return res.status(400).json({ error: '请选择至少一个 Token' })
  }

  let affected = 0
  if (action === 'enable') {
    req.appData.tokens.forEach(t => {
      if (ids.includes(t.id)) { t.enabled = true; affected++ }
    })
  } else if (action === 'disable') {
    req.appData.tokens.forEach(t => {
      if (ids.includes(t.id)) { t.enabled = false; affected++ }
    })
  } else if (action === 'delete') {
    req.appData.tokens = req.appData.tokens.filter(t => {
      if (ids.includes(t.id)) { affected++; return false }
      return true
    })
  } else {
    return res.status(400).json({ error: '未知操作' })
  }

  saveData(req.appData)
  res.json({ ok: true, affected })
})

// --------------- Health check (public, no auth) ---------------
const { execSync } = require('child_process')

async function probeHTTP(url, timeoutMs = 5000) {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), timeoutMs)
  const start = Date.now()
  try {
    const resp = await fetch(url, { signal: controller.signal })
    clearTimeout(timer)
    return { online: resp.ok || resp.status < 500, latency: Date.now() - start, statusCode: resp.status }
  } catch {
    clearTimeout(timer)
    return { online: false, latency: Date.now() - start, statusCode: 0 }
  }
}

function probeSystemd(unit) {
  try {
    const out = execSync(`systemctl is-active ${unit} 2>/dev/null`, { timeout: 3000 }).toString().trim()
    return { online: out === 'active', latency: 0, statusCode: out === 'active' ? 200 : 0 }
  } catch {
    return { online: false, latency: 0, statusCode: 0 }
  }
}

function probeProcess(pattern) {
  try {
    const out = execSync(`pgrep -f "${pattern}" 2>/dev/null`, { timeout: 3000 }).toString().trim()
    return { online: out.length > 0, latency: 0, statusCode: out.length > 0 ? 200 : 0 }
  } catch {
    return { online: false, latency: 0, statusCode: 0 }
  }
}

// --------------- Dynamic Service Discovery ---------------

const SYSTEMD_BLACKLIST = [
  "systemd-", "dbus", "getty", "sshd", "auditd", "crond", "rsyslog", "polkit",
  "rpcbind", "tuned", "lvm2", "multipathd", "NetworkManager", "kdump", "sssd",
  "cloud-", "rhel-", "selinux-", "dracut-", "kmod-", "import-state",
  "loadmodules", "nis-domainname", "vdo", "rngd", "rngd-wake", "microcode",
  "diskresize", "smartd", "mcelog", "qemu-guest", "libstoragemgmt",
  "rc-local", "atd", "autovt@", "user-runtime-dir@", "user@", "pm2-root",
  "containerd", "BT-Firewall", "site_total", "chronyd", "irqbalance", "syslog", "timedatex", "mdmonitor",
]

function isSystemdBlacklisted(unit) {
  const name = unit.replace(/\.service$/, "")
  for (const prefix of SYSTEMD_BLACKLIST) {
    if (name.startsWith(prefix) || name === prefix) return true
  }
  return false
}

function discoverPM2Services() {
  try {
    const raw = execSync("pm2 jlist 2>/dev/null", { timeout: 8000 }).toString()
    const list = JSON.parse(raw)
    return list.map(proc => {
      const env = proc.pm2_env || {}
      const monit = proc.monit || {}
      return {
        key: "pm2_" + proc.name,
        name: proc.name,
        type: "pm2",
        processId: proc.name,
        pmId: proc.pm_id,
        online: env.status === "online",
        latency: 0,
        category: "app",
        status: env.status || "unknown",
        uptime: env.pm_uptime || 0,
        memory: monit.memory || 0,
        cpu: monit.cpu || 0,
        restarts: env.restart_time || 0,
        version: env.version || "",
        cwd: env.pm_cwd || "",
      }
    })
  } catch { return [] }
}

function discoverSystemdServices() {
  try {
    const raw = execSync(
      "systemctl list-units --type=service --no-pager --no-legend 2>/dev/null",
      { timeout: 5000, encoding: "utf-8" }
    )
    const enabledRaw = execSync(
      "systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend 2>/dev/null",
      { timeout: 5000, encoding: "utf-8" }
    )
    const enabledSet = new Set()
    for (const line of enabledRaw.trim().split("\n")) {
      const unit = line.trim().split(/\s+/)[0]
      if (unit) enabledSet.add(unit.replace(/\.service$/, ""))
    }

    const services = []
    for (const line of raw.trim().split("\n")) {
      const parts = line.trim().split(/\s+/)
      if (parts.length < 4) continue
      const unit = parts[0].replace(/\.service$/, "")
      const active = parts[2]
      const sub = parts[3]
      if (isSystemdBlacklisted(unit)) continue
      if (sub === "exited" && active !== "failed" && !enabledSet.has(unit)) continue

      const probe = probeSystemd(unit)
      services.push({
        key: "sys_" + unit,
        name: unit,
        type: "systemd",
        processId: unit,
        pmId: -1,
        online: probe.online,
        latency: 0,
        category: "system",
        status: active === "active" ? sub : active,
        uptime: 0, memory: 0, cpu: 0,
        restarts: 0, version: "", cwd: "",
      })
    }

    for (const unit of enabledSet) {
      if (isSystemdBlacklisted(unit)) continue
      if (services.some(s => s.processId === unit)) continue
      const probe = probeSystemd(unit)
      services.push({
        key: "sys_" + unit,
        name: unit,
        type: "systemd",
        processId: unit,
        pmId: -1,
        online: probe.online,
        latency: 0,
        category: "system",
        status: probe.online ? "running" : "dead",
        uptime: 0, memory: 0, cpu: 0,
        restarts: 0, version: "", cwd: "",
      })
    }

    return services
  } catch { return [] }
}

function discoverNodeProcesses() {
  try {
    const pm2Pids = new Set()
    try {
      const pm2Raw = execSync("pm2 jlist 2>/dev/null", { timeout: 5000 }).toString()
      for (const p of JSON.parse(pm2Raw)) {
        if (p.pid) pm2Pids.add(String(p.pid))
      }
    } catch {}

    const psRaw = execSync(
      "ps -eo pid,ppid,rss,etime,args --no-headers | grep 'node ' | grep -v grep | grep -v pm2",
      { timeout: 5000, encoding: "utf-8" }
    ).trim()
    if (!psRaw) return []

    const results = []
    for (const line of psRaw.split("\n")) {
      const m = line.trim().match(/^(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(.+)$/)
      if (!m) continue
      const [, pid, ppid, rssKB, etime, cmdline] = m
      if (pm2Pids.has(pid)) continue

      let port = ""
      try {
        const ssOut = execSync(`ss -tlnp 2>/dev/null | grep "pid=${pid}"`, { timeout: 3000, encoding: "utf-8" }).trim()
        const pm = ssOut.match(/:(d+)\s/)
        if (pm) port = pm[1]
      } catch {}

      let cwd = ""
      try {
        cwd = execSync(`readlink /proc/${pid}/cwd 2>/dev/null`, { timeout: 2000, encoding: "utf-8" }).trim()
      } catch {}

      const name = cwd ? cwd.split("/").pop() : cmdline.split("/").pop().split(" ")[0]

      results.push({
        key: "node_" + pid,
        name: name + (port ? ":" + port : ""),
        type: "node",
        processId: pid,
        pmId: -1,
        online: true,
        latency: 0,
        category: "app",
        status: "running",
        uptime: 0,
        memory: parseInt(rssKB) * 1024 || 0,
        cpu: 0,
        restarts: 0,
        version: "",
        cwd: cwd,
      })
    }
    return results
  } catch { return [] }
}

function discoverDockerContainers() {
  try {
    const raw = execSync(
      'docker ps -a --format "{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}" 2>/dev/null',
      { timeout: 5000, encoding: "utf-8" }
    ).trim()
    if (!raw) return []
    return raw.split("\n").map(line => {
      const cols = line.split("\t")
      const online = (cols[2] || "").startsWith("Up")
      return {
        key: "docker_" + cols[1],
        name: cols[1] || cols[0],
        type: "docker",
        processId: cols[0],
        pmId: -1,
        online,
        latency: 0,
        category: "docker",
        status: (cols[2] || "").split(" ").slice(0, 2).join(" "),
        uptime: 0, memory: 0, cpu: 0,
        restarts: 0,
        version: cols[3] || "",
        cwd: cols[4] || "",
      }
    })
  } catch { return [] }
}

async function discoverAllServices() {
  return [...discoverPM2Services(), ...discoverNodeProcesses(), ...discoverSystemdServices(), ...discoverDockerContainers()]
}



// --------------- QQ Music Credential ---------------
const QQ_CREDENTIAL_FILE = "/www/wwwroot/qqmusic-api-v2/web/credential.json";
const QQ_REFRESH_LOG = "/var/log/qqmusic-refresh.log";

app.get("/api/qqmusic/credential", authMiddleware, (req, res) => {
  try {
    const raw = fs.readFileSync(QQ_CREDENTIAL_FILE, "utf-8");
    const d = JSON.parse(raw);
    const now = Date.now() / 1000;
    const createTime = d.musickeyCreateTime || 0;
    const expiresIn = d.keyExpiresIn || 0;
    let expireTs = 0, remainingHours = 0;
    if (createTime && expiresIn) {
      expireTs = createTime + expiresIn;
      remainingHours = Math.max(0, (expireTs - now) / 3600);
    } else if (d.expired_at) {
      expireTs = d.expired_at;
      remainingHours = Math.max(0, (expireTs - now) / 3600);
    }
    res.json({
      musicid: d.musicid || "",
      loginType: d.login_type || "",
      hasRefreshKey: !!d.refresh_key,
      expireTime: expireTs ? new Date(expireTs * 1000).toISOString() : null,
      remainingHours: Math.round(remainingHours * 10) / 10,
      isExpired: remainingHours <= 0,
      isExpiringSoon: remainingHours > 0 && remainingHours <= 1,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post("/api/qqmusic/refresh", authMiddleware, async (req, res) => {
  const { execSync } = require("child_process");
  try {
    const out = execSync(
      "cd /www/wwwroot/qqmusic-api && /usr/local/bin/uv run python auto_refresh.py 2>&1",
      { timeout: 30000, encoding: "utf-8" }
    );
    const success = out.includes("OK") || out.includes("\u65e0\u9700\u5237\u65b0") || out.includes("\u5237\u65b0\u6210\u529f");
    res.json({ success, output: out.trim() });
  } catch (e) {
    res.status(500).json({ success: false, output: (e.stdout || "") + (e.stderr || e.message) });
  }
});

app.get("/api/qqmusic/refresh-log", authMiddleware, (req, res) => {
  try {
    const log = fs.readFileSync(QQ_REFRESH_LOG, "utf-8");
    const lines = log.trim().split("\n").slice(-50);
    res.json({ log: lines.join("\n") });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});


app.get('/api/health', async (req, res) => {
  const data = loadData()
  const mem = process.memoryUsage()
  const os = require('os')
  const uptimeSec = process.uptime()
  const services = await discoverAllServices()

  res.json({
    status: 'ok',
    startedAt,
    uptime: uptimeSec,
    version: process.version,
    platform: process.platform,
    arch: process.arch,
    memory: { rss: mem.rss, heapUsed: mem.heapUsed, heapTotal: mem.heapTotal },
    system: {
      hostname: os.hostname(),
      cpus: os.cpus().length,
      totalMemory: os.totalmem(),
      freeMemory: os.freemem(),
      loadAvg: os.loadavg(),
      ...(() => {
        const info = {}
        try {
          const df = execSync("df -B1 / 2>/dev/null | awk 'NR==2{print $2,$3,$4}'", {timeout:3000}).toString().trim().split(" ")
          info.diskTotal = parseInt(df[0]) || 0; info.diskUsed = parseInt(df[1]) || 0; info.diskFree = parseInt(df[2]) || 0
        } catch { info.diskTotal = 0; info.diskUsed = 0; info.diskFree = 0 }
        try {
          const net = execSync("cat /proc/net/dev | awk 'NR>2{rx+=$2;tx+=$10} END{print rx,tx}'", {timeout:3000}).toString().trim().split(" ")
          info.netRx = parseInt(net[0]) || 0; info.netTx = parseInt(net[1]) || 0
        } catch { info.netRx = 0; info.netTx = 0 }
        try { info.processCount = parseInt(execSync("ps aux | wc -l", {timeout:3000}).toString().trim()) || 0 } catch { info.processCount = 0 }
        try {
          const tcp = execSync("ss -s 2>/dev/null | grep estab", {timeout:3000}).toString().trim()
          const m = tcp.match(/estab (\d+)/); info.tcpEstab = m ? parseInt(m[1]) : 0
          const t = tcp.match(/timewait (\d+)/); info.tcpTimeWait = t ? parseInt(t[1]) : 0
        } catch { info.tcpEstab = 0; info.tcpTimeWait = 0 }
        try { info.bootTime = execSync("uptime -s 2>/dev/null", {timeout:3000}).toString().trim() } catch { info.bootTime = "" }
        try { info.systemUptime = parseFloat(execSync("cat /proc/uptime | awk '{print $1}'", {timeout:3000}).toString().trim()) || 0 } catch { info.systemUptime = 0 }
        return info
      })()
    },
    service: {
      tokenCount: data.tokens.length,
      globalEnabled: data.globalEnabled,
      rateLimitEnabled: data.rateLimitEnabled,
      downloadLimitEnabled: data.downloadLimitEnabled
    },
    services
  })
})



// --------------- Device Bind Settings ---------------
app.post('/api/devicebind/toggle', authMiddleware, (req, res) => {
  req.appData.deviceBindEnabled = !req.appData.deviceBindEnabled
  saveData(req.appData)
  res.json({ deviceBindEnabled: req.appData.deviceBindEnabled })
})

app.post('/api/devicebind/max', authMiddleware, (req, res) => {
  const { value } = req.body
  if (value === undefined || value < 1 || value > 50) {
    return res.status(400).json({ error: '设备数量限制 1-50' })
  }
  req.appData.maxDevicesPerToken = value
  saveData(req.appData)
  res.json({ maxDevicesPerToken: value })
})

app.post('/api/devicebind/apply-all', authMiddleware, (req, res) => {
  const { value } = req.body
  const max = value !== undefined ? value : req.appData.maxDevicesPerToken
  req.appData.tokens.forEach(t => { t.maxDevices = max })
  saveData(req.appData)
  res.json({ ok: true, applied: req.appData.tokens.length, value: max })
})

app.get('/api/tokens/:id/devices', authMiddleware, (req, res) => {
  const t = req.appData.tokens.find(t => t.id === req.params.id)
  if (!t) return res.status(404).json({ error: '未找到' })
  res.json({ devices: t.devices || [], maxDevices: t.maxDevices || 3 })
})

app.delete('/api/tokens/:id/devices/:deviceId', authMiddleware, (req, res) => {
  const t = req.appData.tokens.find(t => t.id === req.params.id)
  if (!t) return res.status(404).json({ error: '未找到' })
  const before = t.devices.length
  t.devices = (t.devices || []).filter(d => d.deviceId !== req.params.deviceId)
  saveData(req.appData)
  res.json({ ok: true, removed: before - t.devices.length, remaining: t.devices.length })
})

app.delete('/api/tokens/:id/devices', authMiddleware, (req, res) => {
  const t = req.appData.tokens.find(t => t.id === req.params.id)
  if (!t) return res.status(404).json({ error: '未找到' })
  const count = t.devices.length
  t.devices = []
  saveData(req.appData)
  res.json({ ok: true, cleared: count })
})

// --------------- IPA Releases ---------------
app.post('/api/ipa-releases', authMiddleware, (req, res) => {
  const input = readReleaseInput(req.body)
  const now = new Date().toISOString()
  const release = updateReleaseFromInput({
    id: crypto.randomUUID(),
    createdAt: now,
    updatedAt: now,
    publishedAt: null,
    fileName: null,
    storedFileName: null,
    fileSize: 0,
    checksum: null,
    downloadCount: 0
  }, input)

  req.appData.ipaReleases.unshift(release)
  req.appData.ipaReleases = sortReleasesDesc(req.appData.ipaReleases)
  saveData(req.appData)
  res.json(adminReleasePayload(release))
})

app.post(
  '/api/ipa-releases/:id/file',
  authMiddleware,
  express.raw({ type: '*/*', limit: '2048mb' }),
  (req, res) => {
    const release = req.appData.ipaReleases.find(item => item.id === req.params.id)
    if (!release) return res.status(404).json({ error: '未找到版本' })
    if (!Buffer.isBuffer(req.body) || !req.body.length) {
      return res.status(400).json({ error: '未收到文件内容' })
    }

    const originalName = sanitizeFileName(decodeURIComponent(req.headers['x-file-name'] || '') || `${release.title || release.version}.ipa`)
    if (!originalName.toLowerCase().endsWith('.ipa')) {
      return res.status(400).json({ error: '只允许上传 ipa 文件' })
    }

    const ext = path.extname(originalName) || '.ipa'
    const storedFileName = `${release.id}-${Date.now()}${ext}`
    const targetPath = path.join(IPA_DIR, storedFileName)

    fs.writeFileSync(targetPath, req.body)
    const previousPath = releaseFilePath(release)
    if (previousPath && fs.existsSync(previousPath) && previousPath !== targetPath) {
      fs.unlinkSync(previousPath)
    }

    release.fileName = originalName
    release.storedFileName = storedFileName
    release.fileSize = req.body.length
    release.checksum = crypto.createHash('sha1').update(req.body).digest('hex')
    release.updatedAt = new Date().toISOString()
    req.appData.ipaReleases = sortReleasesDesc(req.appData.ipaReleases)
    saveData(req.appData)

    res.json(adminReleasePayload(release))
  }
)

app.put('/api/ipa-releases/:id', authMiddleware, (req, res) => {
  const release = req.appData.ipaReleases.find(item => item.id === req.params.id)
  if (!release) return res.status(404).json({ error: '未找到版本' })

  const input = readReleaseInput({
    version: req.body.version !== undefined ? req.body.version : release.version,
    build: req.body.build !== undefined ? req.body.build : release.build,
    title: req.body.title !== undefined ? req.body.title : release.title,
    channel: req.body.channel !== undefined ? req.body.channel : release.channel,
    releaseNotes: req.body.releaseNotes !== undefined ? req.body.releaseNotes : release.releaseNotes,
    minIosVersion: req.body.minIosVersion !== undefined ? req.body.minIosVersion : release.minIosVersion,
    published: req.body.published !== undefined ? req.body.published : release.published
  })

  updateReleaseFromInput(release, input)
  req.appData.ipaReleases = sortReleasesDesc(req.appData.ipaReleases)
  saveData(req.appData)
  res.json(adminReleasePayload(release))
})

app.delete('/api/ipa-releases/:id', authMiddleware, (req, res) => {
  const index = req.appData.ipaReleases.findIndex(item => item.id === req.params.id)
  if (index === -1) return res.status(404).json({ error: '未找到版本' })

  const [release] = req.appData.ipaReleases.splice(index, 1)
  const filePath = releaseFilePath(release)
  if (filePath && fs.existsSync(filePath)) {
    fs.unlinkSync(filePath)
  }

  saveData(req.appData)
  res.json({ ok: true })
})

app.get('/api/public/ipa-releases', (req, res) => {
  const data = loadData()
  const releases = sortReleasesDesc((data.ipaReleases || []).map(migrateRelease))
  const publishedReleases = releases.filter(release => release.published && hasReleaseFile(release))

  res.json({
    ok: true,
    latest: publishedReleases[0] ? publicReleasePayload(publishedReleases[0]) : null,
    releases: publishedReleases.map(publicReleasePayload)
  })
})

app.get('/downloads/file/:id', (req, res) => {
  const data = loadData()
  const releases = (data.ipaReleases || []).map(migrateRelease)
  const release = releases.find(item => item.id === req.params.id && item.published)
  if (!release || !hasReleaseFile(release)) {
    return res.status(404).send('Not Found')
  }

  release.downloadCount = (release.downloadCount || 0) + 1
  release.updatedAt = new Date().toISOString()
  data.ipaReleases = releases
  saveData(data)

  // Compute a clean download filename based on release info
  const ext = path.extname(release.storedFileName || release.fileName || '.ipa') || '.ipa'
  let dlName = 'Monologue'
  if (release.title) {
    dlName = release.title.trim()
  } else if (release.version) {
    dlName = `Monologue_${release.version}${release.build ? '_' + release.build : ''}`
  }
  // Remove chars that might cause header issues
  dlName = dlName.replace(/[\/\?<>\\:\*\|":\x00-\x1F\x80-\x9F]/g, '_')
  
  if (!dlName.toLowerCase().endsWith(ext.toLowerCase())) {
    dlName += ext
  }

  res.download(releaseFilePath(release), dlName)
})

// --------------- App Changelogs ---------------
app.post('/api/changelogs', authMiddleware, (req, res) => {
  const input = readChangelogInput(req.body)
  const now = new Date().toISOString()
  const item = updateChangelogFromInput({
    id: crypto.randomUUID(),
    createdAt: now,
    updatedAt: now,
    publishedAt: null
  }, input)

  req.appData.appChangelogs.unshift(item)
  req.appData.appChangelogs = sortChangelogsDesc(req.appData.appChangelogs)
  saveData(req.appData)
  res.json(adminChangelogPayload(item))
})

app.put('/api/changelogs/:id', authMiddleware, (req, res) => {
  const item = req.appData.appChangelogs.find(entry => entry.id === req.params.id)
  if (!item) return res.status(404).json({ error: '未找到更新日志' })

  const input = readChangelogInput({
    version: req.body.version !== undefined ? req.body.version : item.version,
    build: req.body.build !== undefined ? req.body.build : item.build,
    title: req.body.title !== undefined ? req.body.title : item.title,
    channel: req.body.channel !== undefined ? req.body.channel : item.channel,
    summary: req.body.summary !== undefined ? req.body.summary : item.summary,
    releaseNotes: req.body.releaseNotes !== undefined ? req.body.releaseNotes : item.releaseNotes,
    published: req.body.published !== undefined ? req.body.published : item.published
  })

  updateChangelogFromInput(item, input)
  req.appData.appChangelogs = sortChangelogsDesc(req.appData.appChangelogs)
  saveData(req.appData)
  res.json(adminChangelogPayload(item))
})

app.delete('/api/changelogs/:id', authMiddleware, (req, res) => {
  const index = req.appData.appChangelogs.findIndex(item => item.id === req.params.id)
  if (index === -1) return res.status(404).json({ error: '未找到更新日志' })

  req.appData.appChangelogs.splice(index, 1)
  saveData(req.appData)
  res.json({ ok: true })
})

app.get('/api/public/changelogs', (req, res) => {
  const data = loadData()
  const changelogs = sortChangelogsDesc((data.appChangelogs || []).map(migrateChangelog))
  const publishedChangelogs = changelogs.filter(item => item.published)

  res.json({
    ok: true,
    latest: publishedChangelogs[0] ? publicChangelogPayload(publishedChangelogs[0]) : null,
    releases: publishedChangelogs.map(publicChangelogPayload)
  })
})

// --------------- Service Control API ---------------
app.post("/api/services/control", authMiddleware, async (req, res) => {
  const { processId, type, action } = req.body
  if (!processId || !type || !action) return res.status(400).json({ error: "缺少 processId / type / action" })
  if (!["start", "stop", "restart"].includes(action)) return res.status(400).json({ error: "action 必须为 start / stop / restart" })
  let cmd
  if (type === "pm2") cmd = `pm2 ${action} ${processId} --silent 2>&1 && echo DONE`
  else if (type === "systemd") cmd = `systemctl ${action} ${processId} 2>&1 && echo DONE`
  else if (type === "node") {
    if (action === "stop") cmd = `kill ${processId} 2>&1 && echo DONE`
    else if (action === "restart") cmd = `kill ${processId} 2>&1; echo DONE`
    else return res.status(400).json({ error: "node 进程只支持 stop" })
  } else if (type === "docker") cmd = `docker ${action} ${processId} 2>&1 && echo DONE`
  else return res.status(400).json({ error: "type 必须为 pm2 / systemd / docker" })
  try {
    const out = execSync(cmd, { timeout: 15000, encoding: "utf-8" })
    res.json({ ok: true, output: out.trim() })
  } catch (e) {
    res.status(500).json({ ok: false, output: (e.stdout || "") + (e.stderr || e.message) })
  }
})

app.get("/api/services/logs", authMiddleware, (req, res) => {
  const { processId, type, lines } = req.query
  const n = parseInt(lines) || 100
  if (!processId || !type) return res.status(400).json({ error: "缺少 processId / type" })
  let cmd
  if (type === "pm2") cmd = `pm2 logs ${processId} --lines ${n} --nostream 2>&1`
  else if (type === "systemd") cmd = `journalctl -u ${processId} -n ${n} --no-pager 2>&1; true`
  else if (type === "node") cmd = `cat /proc/${processId}/fd/1 2>/dev/null | tail -${n} || echo "无法获取独立进程日志"`
  else if (type === "docker") cmd = `docker logs --tail ${n} ${processId} 2>&1`
  else return res.status(400).json({ error: "type 必须为 pm2 / systemd / docker" })
  try {
    const out = execSync(cmd, { timeout: 15000, encoding: "utf-8" })
    res.json({ logs: out })
  } catch (e) { res.status(500).json({ logs: (e.stdout || "") + (e.stderr || e.message) }) }
})

app.get("/api/services/info", authMiddleware, (req, res) => {
  const { processId, type } = req.query
  if (!processId || !type) return res.status(400).json({ error: "缺少 processId / type" })
  let cmd
  if (type === "pm2") cmd = `pm2 describe ${processId} 2>&1; true`
  else if (type === "systemd") cmd = `systemctl status ${processId} --no-pager 2>&1; true`
  else if (type === "node") cmd = `echo "PID: ${processId}" && ps -p ${processId} -o pid,ppid,user,rss,vsz,etime,args --no-headers 2>&1 && echo "---" && ls -la /proc/${processId}/cwd 2>/dev/null && echo "---" && ss -tlnp 2>/dev/null | grep "pid=${processId}" || true`
  else if (type === "docker") cmd = `docker inspect ${processId} 2>&1`
  else return res.status(400).json({ error: "type 必须为 pm2 / systemd / docker" })
  try {
    const out = execSync(cmd, { timeout: 10000, encoding: "utf-8" })
    res.json({ info: out })
  } catch (e) { res.status(500).json({ info: (e.stdout || "") + (e.stderr || e.message) }) }
})



// --------------- Public verify (app launch check) ---------------
app.all('/api/verify', (req, res) => {
  const data = loadData()
  data.tokens = data.tokens.map(migrateToken)

  if (!data.globalEnabled) {
    return res.json({ valid: true, enabled: false })
  }

  const tokenKey = req.query.token
  if (!tokenKey) {
    return res.json({ valid: false, reason: 'missing' })
  }

  const t = data.tokens.find(t => t.key === tokenKey && t.enabled)
  if (!t) {
    return res.json({ valid: false, reason: 'invalid' })
  }

  if (t.expiresAt && new Date(t.expiresAt) <= new Date()) {
    return res.json({ valid: false, reason: 'expired' })
  }

  const devCheck = checkDeviceBind(data, t, req)
  if (!devCheck.allowed) {
    return res.json({ valid: false, reason: 'device_limit', current: devCheck.current, max: devCheck.max })
  }
  if (devCheck.newDevice || devCheck.updatedDevice) scheduleUsageSave(data)

  res.json({ valid: true, name: t.name, deviceCount: t.devices.length, maxDevices: t.maxDevices })
})

// --------------- Nginx auth_request verify ---------------
app.get('/auth/verify', (req, res) => {
  const data = loadData()
  data.tokens = data.tokens.map(migrateToken)

  if (!data.globalEnabled) {
    return res.sendStatus(200)
  }

  let tokenKey = req.query.token || req.headers['x-api-token']
  if (!tokenKey) {
    const origUri = req.headers['x-original-uri'] || ''
    const m = origUri.match(/[?&]token=([^&]+)/)
    if (m) tokenKey = m[1]
  }

  if (!tokenKey) return res.sendStatus(401)

  const t = data.tokens.find(t => t.key === tokenKey && t.enabled)
  if (!t) return res.sendStatus(403)

  if (t.expiresAt && new Date(t.expiresAt) <= new Date()) {
    return res.sendStatus(403)
  }

  if (data.rateLimitEnabled && !checkRateLimit(t.id, t.rateLimit)) {
    return res.sendStatus(429)
  }

  let deviceId = req.headers['x-device-id']
  if (!deviceId) {
    const origUri = req.headers['x-original-uri'] || ''
    const dm = origUri.match(/[?&]deviceId=([^&]+)/)
    if (dm) deviceId = decodeURIComponent(dm[1])
  }
  const devCheck = checkDeviceBind(data, t, req)
  if (!devCheck.allowed) return res.status(403).json({ error: devCheck.reason, current: devCheck.current, max: devCheck.max })

  if (devCheck.newDevice || devCheck.updatedDevice) scheduleUsageSave(data)

  res.sendStatus(200)
})

// --------------- Download auth_request verify ---------------
app.get('/auth/download', (req, res) => {
  const data = loadData()
  data.tokens = data.tokens.map(migrateToken)

  if (!data.globalEnabled) {
    return res.sendStatus(200)
  }

  let tokenKey = req.query.token || req.headers['x-api-token']
  if (!tokenKey) {
    const origUri = req.headers['x-original-uri'] || ''
    const m = origUri.match(/[?&]token=([^&]+)/)
    if (m) tokenKey = m[1]
  }

  if (!tokenKey) return res.sendStatus(401)

  const t = data.tokens.find(t => t.key === tokenKey && t.enabled)
  if (!t) return res.sendStatus(403)

  if (t.expiresAt && new Date(t.expiresAt) <= new Date()) {
    return res.sendStatus(403)
  }

  if (data.rateLimitEnabled && !checkRateLimit(t.id, t.rateLimit)) {
    return res.sendStatus(429)
  }

  let deviceId = req.headers['x-device-id']
  if (!deviceId) {
    const origUri = req.headers['x-original-uri'] || ''
    const dm = origUri.match(/[?&]deviceId=([^&]+)/)
    if (dm) deviceId = decodeURIComponent(dm[1])
  }
  const devCheck = checkDeviceBind(data, t, req)
  if (!devCheck.allowed) return res.status(403).json({ error: devCheck.reason, current: devCheck.current, max: devCheck.max })

  if (devCheck.newDevice || devCheck.updatedDevice) {
    // Just in case metadata updated, we should save later since data is naturally saved in the end
  }

  const origUriAuth = req.headers['x-original-uri'] || ''
  const isRealDownload = /(?:[?&])_download=1(?:&|$)/.test(origUriAuth)

  if (isRealDownload && data.downloadLimitEnabled && t.downloadLimit > 0) {
    const todayCount = getTodayDownloads(t)
    if (todayCount >= t.downloadLimit) {
      return res.status(429).json({ error: 'download_limit_exceeded', limit: t.downloadLimit, used: todayCount })
    }
  }

  const today = todayKey()
  t.lastUsed = new Date().toISOString()

  if (isRealDownload) {
    t.totalDownloads = (t.totalDownloads || 0) + 1
    if (!t.dailyDownloads) t.dailyDownloads = {}
    t.dailyDownloads[today] = (t.dailyDownloads[today] || 0) + 1
  }

  const dlKeys = Object.keys(t.dailyDownloads).sort()
  if (dlKeys.length > 30) {
    const keep = dlKeys.slice(-30)
    const trimmed = {}
    keep.forEach(k => trimmed[k] = t.dailyDownloads[k])
    t.dailyDownloads = trimmed
  }

  scheduleUsageSave(data)
  res.sendStatus(200)
})

// --------------- Public download info (for client display) ---------------
app.get('/api/download-info', (req, res) => {
  const data = loadData()
  data.tokens = data.tokens.map(migrateToken)

  const tokenKey = req.query.token
  if (!tokenKey) {
    return res.status(401).json({ error: 'missing token' })
  }

  const t = data.tokens.find(t => t.key === tokenKey && t.enabled)
  if (!t) {
    return res.status(403).json({ error: 'invalid token' })
  }

  const todayCount = getTodayDownloads(t)
  const remaining = t.downloadLimit > 0 ? Math.max(0, t.downloadLimit - todayCount) : -1

  res.json({
    downloadLimitEnabled: data.downloadLimitEnabled,
    downloadLimit: t.downloadLimit,
    todayDownloads: todayCount,
    totalDownloads: t.totalDownloads || 0,
    remaining,
    limitExceeded: data.downloadLimitEnabled && t.downloadLimit > 0 && todayCount >= t.downloadLimit
  })
})

// --------------- Public cloud manager (token-scoped web management) ---------------
function cloudCors(req, res, next) {
  const origin = req.headers.origin
  const allowedOrigins = new Set([
    'https://mono.zijiu522.cn',
    'http://mono.zijiu522.cn',
    'http://127.0.0.1:5173',
    'http://localhost:5173'
  ])
  if (allowedOrigins.has(origin)) {
    res.set('Access-Control-Allow-Origin', origin)
  }
  res.vary('Origin')
  res.set('Access-Control-Allow-Methods', 'GET,POST,DELETE,OPTIONS')
  res.set('Access-Control-Allow-Headers', 'Content-Type, X-Cloud-Token, X-Api-Token')
  res.set('Access-Control-Max-Age', '86400')
  if (req.method === 'OPTIONS') return res.sendStatus(204)
  next()
}

function readCloudTokenFromRequest(req) {
  const value = req.body?.token
    || req.query.token
    || req.headers['x-cloud-token']
    || req.headers['x-api-token']
  return typeof value === 'string' ? value.trim() : ''
}

function cloudTokenMiddleware(req, res, next) {
  const data = loadData()
  data.tokens = data.tokens.map(migrateToken)
  const tokenKey = readCloudTokenFromRequest(req)
  if (!tokenKey) return res.status(401).json({ error: 'missing token' })
  const token = data.tokens.find(item => item.key === tokenKey && item.enabled)
  if (!token) return res.status(403).json({ error: 'invalid token' })
  if (token.expiresAt && new Date(token.expiresAt) <= new Date()) {
    return res.status(403).json({ error: 'expired token' })
  }
  req.cloudData = data
  req.cloudToken = token
  next()
}

app.use('/api/public/cloud', cloudCors)

app.post('/api/public/cloud/session', cloudTokenMiddleware, (req, res) => {
  res.set('Cache-Control', 'private, no-cache')
  res.json(cloudPublicPayload(req.cloudToken))
})

app.get('/api/public/cloud/snapshot', cloudTokenMiddleware, (req, res) => {
  const etag = playlistSnapshotETag(req.cloudToken.playlistSnapshot)
  res.set('ETag', etag)
  res.set('Cache-Control', 'private, no-cache')
  res.vary('X-Cloud-Token')
  if (requestMatchesETag(req, etag)) return res.status(304).end()
  res.json(cloudPublicPayload(req.cloudToken))
})

app.delete('/api/public/cloud/snapshot', cloudTokenMiddleware, (req, res) => {
  req.cloudToken.playlistSnapshot = null
  saveData(req.cloudData)
  res.json(cloudPublicPayload(req.cloudToken))
})

app.delete('/api/public/cloud/playlists/:playlistId', cloudTokenMiddleware, (req, res) => {
  const playlist = findPlaylistOrRespond(req.cloudToken, req.params.playlistId, res)
  if (!playlist) return

  req.cloudToken.playlistSnapshot.playlists = req.cloudToken.playlistSnapshot.playlists.filter(item => item !== playlist)
  req.cloudToken.playlistSnapshot = req.cloudToken.playlistSnapshot.playlists.length
    || hasNonPlaylistSnapshotData(req.cloudToken.playlistSnapshot)
    ? rebuildPlaylistSnapshot(req.cloudToken.playlistSnapshot)
    : null
  saveData(req.cloudData)
  res.json(cloudPublicPayload(req.cloudToken))
})

app.delete('/api/public/cloud/playlists/:playlistId/songs/:songId', cloudTokenMiddleware, (req, res) => {
  const playlist = findPlaylistOrRespond(req.cloudToken, req.params.playlistId, res)
  if (!playlist) return

  const songId = String(req.params.songId)
  const nextSongs = (playlist.songs || []).filter((song, index) => playlistSongKey(song, index) !== songId)
  if (nextSongs.length === (playlist.songs || []).length) {
    return res.status(404).json({ error: '未找到歌曲' })
  }

  playlist.songs = nextSongs
  playlist.updatedAt = new Date().toISOString()
  req.cloudToken.playlistSnapshot = rebuildPlaylistSnapshot(req.cloudToken.playlistSnapshot)
  saveData(req.cloudData)
  res.json(cloudPublicPayload(req.cloudToken))
})

app.delete('/api/public/cloud/modules/:module', cloudTokenMiddleware, (req, res) => {
  const module = String(req.params.module || '')
  if (!CLOUD_MODULES.has(module)) return res.status(404).json({ error: '未找到模块' })
  if (!req.cloudToken.playlistSnapshot) return res.status(404).json({ error: '未找到云端快照' })
  clearCloudModule(req.cloudToken, module)
  saveData(req.cloudData)
  res.json(cloudPublicPayload(req.cloudToken))
})

app.delete('/api/public/cloud/modules/:module/items/:itemKey', cloudTokenMiddleware, (req, res) => {
  const module = String(req.params.module || '')
  if (!CLOUD_MODULES.has(module)) return res.status(404).json({ error: '未找到模块' })
  const snapshot = req.cloudToken.playlistSnapshot
  if (!snapshot) return res.status(404).json({ error: '未找到云端快照' })
  let removed = false

  if (module === 'downloads') {
    const result = removeArrayCloudItem(snapshot.downloads, req.params.itemKey)
    removed = result.removed
    req.cloudToken.playlistSnapshot = rebuildSnapshotWithModule(snapshot, module, result.items)
  }
  if (module === 'radios') {
    const result = removeArrayCloudItem(snapshot.localRadioSubscriptions, req.params.itemKey)
    removed = result.removed
    req.cloudToken.playlistSnapshot = rebuildSnapshotWithModule(snapshot, module, result.items)
  }
  if (module === 'themes') {
    const entries = Array.isArray(snapshot.themeCustomization?.entries) ? snapshot.themeCustomization.entries : []
    const result = removeArrayCloudItem(entries, req.params.itemKey)
    removed = result.removed
    req.cloudToken.playlistSnapshot = rebuildSnapshotWithModule(snapshot, module, result.items.length ? { entries: result.items } : null)
  }
  if (module === 'playback') {
    const records = Array.isArray(snapshot.playbackHistory?.records) ? snapshot.playbackHistory.records : []
    const result = removeArrayCloudItem(records, req.params.itemKey)
    removed = result.removed
    req.cloudToken.playlistSnapshot = rebuildSnapshotWithModule(
      snapshot,
      module,
      result.items.length || snapshot.playbackHistory?.recentClearedAt
        ? { records: result.items, recentClearedAt: snapshot.playbackHistory?.recentClearedAt || null }
        : null
    )
  }
  if (module === 'eq') {
    const result = removeArrayCloudItem(snapshot.customEQPresets, req.params.itemKey)
    removed = result.removed
    req.cloudToken.playlistSnapshot = rebuildSnapshotWithModule(snapshot, module, result.items)
  }
  if (module === 'ai') {
    const decoded = decodeURIComponent(String(req.params.itemKey || ''))
    const cached = { ...(snapshot.aiEqualizer?.cachedProposals || {}) }
    const saved = { ...(snapshot.aiEqualizer?.savedProposals || {}) }
    if (Object.prototype.hasOwnProperty.call(cached, decoded)) {
      delete cached[decoded]
      removed = true
    }
    if (Object.prototype.hasOwnProperty.call(saved, decoded)) {
      delete saved[decoded]
      removed = true
    }
    req.cloudToken.playlistSnapshot = rebuildSnapshotWithModule(
      snapshot,
      module,
      Object.keys(cached).length || Object.keys(saved).length ? { cachedProposals: cached, savedProposals: saved } : null
    )
  }

  if (!removed) return res.status(404).json({ error: '未找到项目' })
  saveData(req.cloudData)
  res.json(cloudPublicPayload(req.cloudToken))
})

// --------------- Public playlist snapshot (token-scoped account storage) ---------------
app.get('/api/account/playlists', (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return

  const snapshot = resolved.token.playlistSnapshot
  const etag = playlistSnapshotETag(snapshot)
  res.set('ETag', etag)
  res.set('Cache-Control', 'private, no-cache')
  res.vary('X-Api-Token')
  res.vary('X-Device-ID')
  if (requestMatchesETag(req, etag)) {
    return res.status(304).end()
  }

  res.json({
    ok: true,
    tokenName: resolved.token.name,
    hasSnapshot: Boolean(snapshot),
    version: snapshot?.version || null,
    updatedAt: snapshot?.updatedAt || null,
    revision: snapshot?.revision || null,
    playlists: snapshot?.playlists || [],
    downloads: snapshot?.downloads || [],
    localRadioSubscriptions: snapshot?.localRadioSubscriptions || [],
    themeCustomization: snapshot?.themeCustomization || null,
    playbackHistory: snapshot?.playbackHistory || null,
    aiEqualizer: snapshot?.aiEqualizer || null,
    customEQPresets: snapshot?.customEQPresets || []
  })
})

app.put('/api/account/playlists', (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return

  const playlists = Array.isArray(req.body?.playlists) ? req.body.playlists : null
  if (!playlists) {
    return res.status(400).json({ error: 'invalid playlists payload' })
  }

  const previous = resolved.token.playlistSnapshot
  const requestedVersion = Number.isInteger(req.body?.version) ? req.body.version : 1
  const storedVersion = Math.max(requestedVersion, previous?.version || 1)
  const supportsV2 = requestedVersion >= 2
  const supportsV3 = requestedVersion >= 3
  const nextSnapshot = makePlaylistSnapshot(playlists, {
    version: storedVersion,
    clientVersion: storedVersion,
    updatedAt: req.body?.updatedAt,
    deviceId: resolved.deviceId,
    deviceName: req.body?.deviceName,
    downloads: supportsV2 ? req.body?.downloads : previous?.downloads,
    localRadioSubscriptions: supportsV2
      ? req.body?.localRadioSubscriptions
      : previous?.localRadioSubscriptions,
    // Older clients do not know these fields and must not erase a newer
    // device's cloud data merely by uploading a playlist snapshot.
    themeCustomization: supportsV3
      ? req.body?.themeCustomization
      : previous?.themeCustomization,
    playbackHistory: supportsV3
      ? req.body?.playbackHistory
      : previous?.playbackHistory,
    aiEqualizer: supportsV3
      ? req.body?.aiEqualizer
      : previous?.aiEqualizer,
    customEQPresets: supportsV3
      ? req.body?.customEQPresets
      : previous?.customEQPresets
  })

  const unchanged = previous?.revision === nextSnapshot.revision
  if (!unchanged) {
    resolved.token.playlistSnapshot = nextSnapshot
    saveData(resolved.data)
  }
  const storedSnapshot = unchanged ? previous : nextSnapshot

  const summary = playlistSnapshotSummary(storedSnapshot)
  res.json({
    ok: true,
    unchanged,
    version: storedSnapshot.version,
    updatedAt: storedSnapshot.updatedAt,
    revision: storedSnapshot.revision,
    playlistCount: summary.playlistCount,
    songCount: summary.songCount,
    downloadCount: summary.downloadCount,
    radioCount: summary.radioCount,
    colorConfigurationCount: summary.colorConfigurationCount,
    playbackRecordCount: summary.playbackRecordCount,
    listeningRecordCount: summary.listeningRecordCount,
    aiTuningPlanCount: summary.aiTuningPlanCount,
    customEQPresetCount: summary.customEQPresetCount
  })
})

app.delete('/api/account/playlists', (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return

  resolved.token.playlistSnapshot = null
  saveData(resolved.data)

  res.json({
    ok: true,
    updatedAt: new Date().toISOString()
  })
})

// --------------- KCM account vault (token-scoped, switch-ready) ---------------
app.get('/api/account/kcm/accounts', (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return

  res.set('Cache-Control', 'private, no-store')
  res.json({
    ok: true,
    activeAccountId: resolved.token.activeKcmAccountId,
    accounts: resolved.token.kcmAccounts.map(account => (
      publicKcmAccount(account, resolved.token.activeKcmAccountId)
    )),
    groups: groupedKcmAccounts(resolved.token)
  })
})

app.put('/api/account/kcm/accounts', (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return

  const normalizedCookie = normalizeKcmCookie(req.body?.cookie)
  if (!normalizedCookie) {
    return res.status(400).json({ error: 'invalid kcm cookie' })
  }

  const requestedLevel = typeof req.body?.membershipLevel === 'string'
    ? req.body.membershipLevel
    : 'none'
  const membershipLevel = KCM_MEMBERSHIP_LEVELS.has(requestedLevel) ? requestedLevel : 'none'
  const profile = normalizeKcmAccountProfile(req.body?.profile, normalizedCookie.userId)
  const now = new Date().toISOString()
  let account = resolved.token.kcmAccounts.find(item => item.userId === normalizedCookie.userId)

  if (!account) {
    account = {
      id: crypto
        .createHash('sha256')
        .update(`${resolved.token.id}:${normalizedCookie.userId}`)
        .digest('hex')
        .slice(0, 24),
      userId: normalizedCookie.userId,
      createdAt: now
    }
    resolved.token.kcmAccounts.push(account)
  }

  account.nickname = profile.nickname
  account.avatarUrl = profile.avatarUrl
  account.membershipLevel = membershipLevel
  account.encryptedCookie = encryptKcmCookie(resolved.data, normalizedCookie.cookie)
  account.updatedAt = now
  account.lastUsedAt = now
  resolved.token.activeKcmAccountId = account.id
  if (!resolved.data.activeKcmPoolAccountId) {
    resolved.data.activeKcmPoolAccountId = account.id
  }
  saveData(resolved.data)

  res.set('Cache-Control', 'private, no-store')
  res.json({
    ok: true,
    account: publicKcmAccount(account, resolved.token.activeKcmAccountId),
    groups: groupedKcmAccounts(resolved.token)
  })
})

app.get('/api/account/kcm/accounts/:accountId/session', (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return

  const account = resolved.token.kcmAccounts.find(item => item.id === req.params.accountId)
  if (!account) return res.status(404).json({ error: 'kcm account not found' })
  const cookie = decryptKcmCookie(resolved.data, account.encryptedCookie)
  if (!cookie) return res.status(409).json({ error: 'kcm account session unavailable' })

  account.lastUsedAt = new Date().toISOString()
  saveData(resolved.data)
  res.set('Cache-Control', 'private, no-store')
  res.json({
    ok: true,
    account: publicKcmAccount(account, resolved.token.activeKcmAccountId),
    cookie
  })
})

app.patch('/api/account/kcm/accounts/:accountId/active', (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return

  const account = resolved.token.kcmAccounts.find(item => item.id === req.params.accountId)
  if (!account) return res.status(404).json({ error: 'kcm account not found' })
  resolved.token.activeKcmAccountId = account.id
  account.lastUsedAt = new Date().toISOString()
  saveData(resolved.data)

  res.json({
    ok: true,
    account: publicKcmAccount(account, resolved.token.activeKcmAccountId)
  })
})

app.delete('/api/account/kcm/accounts/:accountId', (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return

  const index = resolved.token.kcmAccounts.findIndex(item => item.id === req.params.accountId)
  if (index < 0) return res.status(404).json({ error: 'kcm account not found' })
  resolved.token.kcmAccounts.splice(index, 1)
  if (resolved.token.activeKcmAccountId === req.params.accountId) {
    resolved.token.activeKcmAccountId = resolved.token.kcmAccounts[0]?.id || null
  }
  if (resolved.data.activeKcmPoolAccountId === req.params.accountId) {
    resolved.data.activeKcmPoolAccountId = null
    ensureActiveKcmPoolAccount(resolved.data)
  }
  saveData(resolved.data)
  res.json({ ok: true, activeAccountId: resolved.token.activeKcmAccountId })
})

// --------------- KCM global playback account pool ---------------
app.get('/api/account/kcm/pool', (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return

  res.set('Cache-Control', 'private, no-store')
  res.json({ ok: true, ...publicKcmPool(resolved.data) })
})

app.patch('/api/account/kcm/pool', (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return
  if (typeof req.body?.enabled !== 'boolean') {
    return res.status(400).json({ error: 'enabled must be boolean' })
  }

  resolved.data.kcmPoolEnabled = req.body.enabled
  ensureActiveKcmPoolAccount(resolved.data)
  saveData(resolved.data)
  res.set('Cache-Control', 'private, no-store')
  res.json({ ok: true, ...publicKcmPool(resolved.data) })
})

app.patch('/api/account/kcm/pool/accounts/:accountId/active', (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return
  const entry = kcmPoolEntries(resolved.data).find(item => item.account.id === req.params.accountId)
  if (!entry) return res.status(404).json({ error: 'kcm pool account not found' })

  resolved.data.activeKcmPoolAccountId = entry.account.id
  entry.account.lastUsedAt = new Date().toISOString()
  saveData(resolved.data)
  res.set('Cache-Control', 'private, no-store')
  res.json({ ok: true, ...publicKcmPool(resolved.data) })
})

app.get('/api/account/kcm/pool/stream/:ticket', async (req, res) => {
  const ticket = typeof req.params.ticket === 'string' ? req.params.ticket : ''
  if (!/^[a-f0-9]{64}$/.test(ticket)) {
    return res.status(404).json({ error: 'kcm playback ticket not found' })
  }

  const payload = kcmStreamTickets.get(ticket)
  if (!payload || payload.expiresAt <= Date.now()) {
    kcmStreamTickets.delete(ticket)
    return res.status(410).json({ error: 'kcm playback ticket expired' })
  }

  const query = new URLSearchParams({
    hash: payload.hash,
    album_id: payload.albumId,
    album_audio_id: payload.albumAudioId,
    quality: payload.quality,
    timestamp: String(Date.now())
  })

  try {
    const result = await proxyKcmPoolRequest(`/song/url?${query.toString()}`, payload.cookie)
    const upstreamUrl = result.status >= 200 && result.status < 300
      ? firstKcmPlaybackUrl(result.body)
      : null
    if (!upstreamUrl) {
      const message = result.body?.error_msg || result.body?.message || `KCM upstream ${result.status}`
      return res.status(502).json({ error: message })
    }
    pipeKcmPlaybackStream(req, res, upstreamUrl)
  } catch (error) {
    if (!res.headersSent) {
      res.status(502).json({ error: `kcm playback proxy failed: ${error.message}` })
    }
  }
})

app.post('/api/account/kcm/pool/song-url', async (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return

  const hash = typeof req.body?.hash === 'string' ? req.body.hash.trim() : ''
  if (!/^[A-Za-z0-9]{16,128}$/.test(hash)) {
    return res.status(400).json({ error: 'invalid kcm song hash' })
  }
  const numericString = value => /^\d{1,20}$/.test(String(value ?? '')) ? String(value) : '0'
  const albumId = numericString(req.body?.albumId)
  const albumAudioId = numericString(req.body?.albumAudioId)
  const allowedQualities = new Set(['128', '320', 'flac', 'high', 'viper_clear', 'viper_atmos', 'viper_tape'])
  const qualities = Array.isArray(req.body?.qualities)
    ? req.body.qualities.filter(value => allowedQualities.has(value)).slice(0, 8)
    : []
  if (!qualities.length) qualities.push('320', '128')
  const excludeUserId = typeof req.body?.excludeUserId === 'string'
    ? req.body.excludeUserId.trim()
    : null
  const preferredUserId = typeof req.body?.preferredUserId === 'string'
    ? req.body.preferredUserId.trim()
    : null
  let entries
  if (resolved.data.kcmPoolEnabled === true) {
    entries = orderedKcmPoolEntries(resolved.data, excludeUserId, preferredUserId)
  } else {
    const activeAccount = resolved.token.kcmAccounts.find(account => (
      account.id === resolved.token.activeKcmAccountId && account.encryptedCookie
    )) || resolved.token.kcmAccounts.find(account => account.encryptedCookie)
    entries = activeAccount ? [{ token: resolved.token, account: activeAccount }] : []
  }
  if (!entries.length) {
    return res.status(404).json({
      error: resolved.data.kcmPoolEnabled === true
        ? 'kcm account pool empty'
        : 'kcm user account unavailable'
    })
  }

  let lastError = 'kcm pool playback unavailable'
  for (const entry of entries) {
    const cookie = decryptKcmCookie(resolved.data, entry.account.encryptedCookie)
    if (!cookie) continue
    for (const quality of qualities) {
      const query = new URLSearchParams({
        hash,
        album_id: albumId,
        album_audio_id: albumAudioId,
        quality,
        timestamp: String(Date.now())
      })
      try {
        const result = await proxyKcmPoolRequest(`/song/url?${query.toString()}`, cookie)
        const url = result.status >= 200 && result.status < 300
          ? firstKcmPlaybackUrl(result.body)
          : null
        if (!url) {
          lastError = result.body?.error_msg || result.body?.message || `KCM upstream ${result.status}`
          continue
        }
        entry.account.lastUsedAt = new Date().toISOString()
        saveData(resolved.data)
        const ticket = issueKcmStreamTicket({
          hash,
          albumId,
          albumAudioId,
          quality,
          cookie
        })
        res.set('Cache-Control', 'private, no-store')
        return res.json({
          ok: true,
          url: publicKcmStreamUrl(req, ticket),
          quality,
          account: publicKcmAccount(entry.account, resolved.data.activeKcmPoolAccountId)
        })
      } catch (error) {
        lastError = error.message
      }
    }
  }
  res.status(502).json({ error: lastError })
})


// --------------- QQ Music Accounts Proxy ---------------
function proxyQQMusic(urlPath, timeout) {
  return new Promise((resolve, reject) => {
    const req = http.get('http://127.0.0.1:3301' + urlPath, { timeout: timeout || 15000 }, (res) => {
      let data = ''
      res.on('data', chunk => data += chunk)
      res.on('end', () => {
        try { resolve(JSON.parse(data)) }
        catch { resolve({ raw: data }) }
      })
    })
    req.on('error', e => reject(e))
    req.on('timeout', () => { req.destroy(); reject(new Error('QQ Music API timeout')) })
  })
}

function qcmLoginProvider(loginType) {
  if (Number(loginType) === 1) return 'wechat'
  if (Number(loginType) === 2) return 'qq'
  return 'unknown'
}

function qcmMembershipLevel(account) {
  if (Number(account?.is_svip) === 1) return 'svip'
  if (Number(account?.is_vip) === 1) return 'vip'
  return 'standard'
}

function publicQcmCredential(account) {
  const id = String(account?.name ?? account?.musicid ?? '').trim()
  const musicId = account?.musicid === undefined || account?.musicid === null
    ? null
    : String(account.musicid)
  const nickname = typeof account?.nickname === 'string' && account.nickname.trim()
    ? account.nickname.trim()
    : null
  let avatarUrl = typeof account?.avatar === 'string' && account.avatar.trim()
    ? account.avatar.trim()
    : null
  if (avatarUrl?.startsWith('http://')) avatarUrl = `https://${avatarUrl.slice(7)}`

  return {
    id,
    musicId,
    nickname,
    avatarUrl,
    loginType: Number(account?.login_type) || 0,
    loginProvider: qcmLoginProvider(account?.login_type),
    membershipLevel: qcmMembershipLevel(account),
    isActive: account?.active === true
  }
}

async function fetchPublicQcmCredentials() {
  const result = await proxyQQMusic('/accounts')
  if (Number(result?.code) !== 200 || !Array.isArray(result?.data?.accounts)) {
    const message = result?.message || result?.errors?.[0] || 'QCM credentials unavailable'
    throw new Error(message)
  }
  return {
    activeCredentialId: result.data.active ? String(result.data.active) : null,
    credentials: result.data.accounts
      .map(publicQcmCredential)
      .filter(credential => credential.id)
  }
}

async function sendPublicQcmCredentials(res) {
  const payload = await fetchPublicQcmCredentials()
  res.set('Cache-Control', 'private, no-store')
  res.json({ ok: true, ...payload })
}

// Manage the credentials already stored by QCM. Credential secrets never leave QCM.
app.get('/api/account/qcm/credentials', async (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return

  try {
    await sendPublicQcmCredentials(res)
  } catch (e) {
    res.status(502).json({ error: e.message })
  }
})

app.post('/api/account/qcm/credentials/:credentialId/active', async (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return

  try {
    const result = await proxyQQMusic(
      '/accounts/switch?name=' + encodeURIComponent(req.params.credentialId)
    )
    if (Number(result?.code) !== 200) {
      return res.status(400).json({
        error: result?.message || result?.errors?.[0] || 'QCM credential switch failed'
      })
    }
    await sendPublicQcmCredentials(res)
  } catch (e) {
    res.status(502).json({ error: e.message })
  }
})

app.post('/api/account/qcm/credentials/:credentialId/refresh', async (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return

  try {
    const result = await proxyQQMusic(
      '/accounts/refresh_profile?name=' + encodeURIComponent(req.params.credentialId),
      30000
    )
    if (Number(result?.code) !== 200) {
      return res.status(400).json({
        error: result?.message || result?.errors?.[0] || 'QCM credential refresh failed'
      })
    }
    await sendPublicQcmCredentials(res)
  } catch (e) {
    res.status(502).json({ error: e.message })
  }
})

app.get('/api/qqmusic/accounts', authMiddleware, async (req, res) => {
  try {
    const result = await proxyQQMusic('/accounts')
    res.json(result)
  } catch (e) {
    res.status(500).json({ error: 'QQ Music API 不可用: ' + e.message })
  }
})

app.post('/api/qqmusic/accounts/switch', authMiddleware, async (req, res) => {
  const { name } = req.body
  if (!name) return res.status(400).json({ error: '缺少 name' })
  try {
    const result = await proxyQQMusic('/accounts/switch?name=' + encodeURIComponent(name))
    res.json(result)
  } catch (e) {
    res.status(500).json({ error: e.message })
  }
})

app.post('/api/qqmusic/accounts/refresh', authMiddleware, async (req, res) => {
  const { name } = req.body
  if (!name) return res.status(400).json({ error: '缺少 name' })
  try {
    const result = await proxyQQMusic('/accounts/refresh_profile?name=' + encodeURIComponent(name), 30000)
    res.json(result)
  } catch (e) {
    res.status(500).json({ error: e.message })
  }
})

app.delete('/api/qqmusic/accounts/:name', authMiddleware, async (req, res) => {
  try {
    const result = await proxyQQMusic('/accounts/delete?name=' + encodeURIComponent(req.params.name))
    res.json(result)
  } catch (e) {
    res.status(500).json({ error: e.message })
  }
})

app.get('/api/qqmusic/accounts/test/:name', authMiddleware, async (req, res) => {
  try {
    const result = await proxyQQMusic('/accounts/refresh_profile?name=' + encodeURIComponent(req.params.name), 30000)
    if (result.code === 200) {
      res.json({ ok: true, ...result.data })
    } else {
      res.json({ ok: false, error: result.message || '测试失败' })
    }
  } catch (e) {
    res.json({ ok: false, error: e.message })
  }
})

// --------------- Self-register rate limit ---------------
const registerIPBuckets = new Map()

function checkRegisterLimit(ip, dailyLimit) {
  if (!dailyLimit || dailyLimit <= 0) return true
  const today = new Date().toISOString().slice(0, 10)
  const key = ip + ':' + today
  const count = registerIPBuckets.get(key) || 0
  if (count >= dailyLimit) return false
  registerIPBuckets.set(key, count + 1)
  return true
}

// Clean old register buckets daily
setInterval(() => {
  const today = new Date().toISOString().slice(0, 10)
  for (const key of registerIPBuckets.keys()) {
    if (!key.endsWith(':' + today)) registerIPBuckets.delete(key)
  }
}, 3600_000)

// --------------- Public self-register APIs (no auth) ---------------
app.get('/api/public/register/status', (req, res) => {
  const data = loadData()
  normalizeProtectCodeData(data)
  res.json({
    enabled: Boolean(data.selfRegisterEnabled),
    expiresIn: data.selfRegisterExpiresIn || 30,
    requireProtectCode: Boolean(data.selfRegisterRequireProtectCode),
    protectCodePurpose: 'ipa',
    protectCodeAcceptedPurposes: ['ipa', 'tf']
  })
})

app.post('/api/public/register', (req, res) => {
  const data = loadData()
  data.tokens = data.tokens.map(migrateToken)

  if (!data.selfRegisterEnabled) {
    return res.status(403).json({ error: '自助注册已关闭' })
  }

  const { email, name, protectCode } = req.body
  if (!email || !email.includes('@')) {
    return res.status(400).json({ error: '请填写有效邮箱' })
  }
  const trimName = (name || '').trim()
  if (!trimName) {
    return res.status(400).json({ error: '请填写用户名' })
  }

  // IPA 申请接受 IPA 自签保护码，也接受权限更高的 TestFlight 保护码。
  // 反向不兼容：IPA 自签保护码不能用于 TestFlight。
  normalizeProtectCodeData(data)
  const requireProtectCode = Boolean(data.selfRegisterRequireProtectCode)
  let matchedCode = null

  if (requireProtectCode) {
    if (!protectCode || !protectCode.trim()) {
      return res.status(400).json({ error: '请输入 IPA 自签保护码或 TestFlight 保护码' })
    }
    matchedCode = findProtectCode(data, protectCode, 'ipa')
    if (!matchedCode) {
      return res.status(403).json({ error: '保护码无效；IPA 申请支持 IPA 自签码或 TestFlight 码' })
    }
    if (matchedCode.currentUses >= matchedCode.maxUses) {
      return res.status(403).json({ error: '该保护码已达使用上限' })
    }
  }

  // Check IP rate limit
  const clientIP = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip
  if (!checkRegisterLimit(clientIP, data.selfRegisterDailyLimit)) {
    return res.status(429).json({ error: '今日注册次数已达上限，请明天再试' })
  }

  // Check if email already has a token
  const existing = data.tokens.find(t => t.email && t.email.toLowerCase() === email.toLowerCase())
  if (existing) {
    if (existing.expiresAt !== null) {
      existing.expiresAt = null
      existing.source = 'self-register'
      if (matchedCode) {
        matchedCode.currentUses += 1
      }
      recordBinding(data, { code: matchedCode ? matchedCode.code : null, codePurpose: matchedCode?.purpose || null, email: existing.email, name: existing.name, tokenKey: existing.key, tokenId: existing.id, source: 'self-register' })
      saveData(data)
      console.log('[升级正式] Token转为永久:', existing.name, existing.email, existing.key, matchedCode ? `(消耗保护码: ${matchedCode.code})` : '')
    }

    return res.json({
      exists: true,
      upgraded: existing.expiresAt === null,
      token: {
        name: existing.name,
        key: existing.key,
        email: existing.email,
        enabled: existing.enabled,
        expiresAt: existing.expiresAt,
        createdAt: existing.createdAt
      }
    })
  }

  // Consume protect code
  if (matchedCode) {
    matchedCode.currentUses += 1
  }

  // Create new token
  const key = genToken()
  let expiresAt = null

  const token = {
    id: crypto.randomUUID(),
    key,
    name: trimName,
    email: email.toLowerCase(),
    registeredName: trimName,
    source: 'self-register',
    enabled: true,
    createdAt: new Date().toISOString(),
    expiresAt,
    lastUsed: null,
    requestCount: 0,
    rateLimit: data.selfRegisterRateLimit || data.defaultRateLimit || 60,
    downloadLimit: data.selfRegisterDownloadLimit || data.defaultDownloadLimit || 0,
    maxDevices: data.selfRegisterMaxDevices || data.maxDevicesPerToken || 3,
    devices: [],
    dailyStats: {},
    dailyDownloads: {},
    totalDownloads: 0,
    playlistSnapshot: null
  }

  data.tokens.push(token)
  recordBinding(data, { code: matchedCode ? matchedCode.code : null, codePurpose: matchedCode?.purpose || null, email: token.email, name: token.name, tokenKey: token.key, tokenId: token.id, source: 'self-register' })
  saveData(data)
  console.log('[自助注册] 新 Token:', trimName, email, key, matchedCode ? `(保护码: ${matchedCode.code})` : '')

  res.json({
    exists: false,
    token: {
      name: token.name,
      key: token.key,
      email: token.email,
      enabled: token.enabled,
      expiresAt: token.expiresAt,
      createdAt: token.createdAt
    }
  })
})

app.post('/api/public/lookup', (req, res) => {
  const data = loadData()
  data.tokens = data.tokens.map(migrateToken)

  const { email, name, tokenKey } = req.body
  if (!email && !name && !tokenKey) {
    return res.status(400).json({ error: '请填写邮箱、用户名或 Token Key' })
  }

  let found = []
  if (tokenKey) {
    found = data.tokens.filter(t => t.key === tokenKey.trim())
  }
  if (!found.length && email) {
    found = data.tokens.filter(t => t.email && t.email.toLowerCase() === email.toLowerCase())
  }
  if (!found.length && name) {
    const q = name.trim().toLowerCase()
    found = data.tokens.filter(t =>
      (t.name && t.name.toLowerCase().includes(q)) ||
      (t.registeredName && t.registeredName.toLowerCase().includes(q))
    )
  }

  if (!found.length) {
    return res.status(404).json({ error: '未找到关联的 Token，请检查输入是否正确' })
  }

  res.json({
    tokens: found.map(t => ({
      name: t.name,
      key: t.key,
      email: t.email,
      enabled: t.enabled,
      expiresAt: t.expiresAt,
      createdAt: t.createdAt,
      isExpired: t.expiresAt ? new Date(t.expiresAt) <= new Date() : false
    }))
  })
})

app.post('/api/public/complete-profile', (req, res) => {
  const data = loadData()
  data.tokens = data.tokens.map(migrateToken)

  const { tokenKey, email, name } = req.body
  if (!tokenKey) {
    return res.status(400).json({ error: '请输入 Token Key' })
  }

  const token = data.tokens.find(t => t.key === tokenKey.trim())
  if (!token) {
    return res.status(404).json({ error: 'Token 不存在，请检查输入' })
  }

  let updated = false
  if (email && email.includes('@')) {
    const emailLower = email.trim().toLowerCase()
    const conflict = data.tokens.find(t => t.id !== token.id && t.email && t.email.toLowerCase() === emailLower)
    if (conflict) {
      return res.status(409).json({ error: '该邮箱已被其他 Token 绑定' })
    }
    token.email = emailLower
    updated = true
  }
  if (name && name.trim()) {
    token.registeredName = name.trim()
    if (!token.name || token.name === '未命名') {
      token.name = name.trim()
    }
    updated = true
  }

  if (!updated) {
    return res.status(400).json({ error: '请至少填写邮箱或用户名' })
  }

  saveData(data)
  res.json({
    ok: true,
    token: {
      name: token.name,
      key: token.key,
      email: token.email || '',
      registeredName: token.registeredName || '',
      createdAt: token.createdAt,
      expiresAt: token.expiresAt
    }
  })
})

// --------------- Internal auto-register API (for CertVault TF integration) ---------------
app.post('/api/internal/auto-register', (req, res) => {
  const adminToken = req.headers['x-admin-token']
  const data = loadData()
  if (adminToken !== data.adminPassword) {
    return res.status(401).json({ error: '未授权' })
  }
  data.tokens = data.tokens.map(migrateToken)

  const { email, name, source, expires_in_hours, make_permanent } = req.body
  if (!email) {
    return res.status(400).json({ error: '缺少 email' })
  }
  const trimName = (name || '').trim() || email.split('@')[0]

  // If already exists, optionally upgrade to permanent, then return existing
  const existing = data.tokens.find(t => t.email && t.email.toLowerCase() === email.toLowerCase())
  if (existing) {
    let upgraded = false
    if (make_permanent && existing.expiresAt !== null) {
      existing.expiresAt = null
      upgraded = true
    }
    if (source) existing.source = source
    recordBinding(data, { email: existing.email, name: existing.name, tokenKey: existing.key, tokenId: existing.id, source: existing.source })
    saveData(data)
    if (upgraded) console.log('[TF升级正式] Token转为永久:', existing.name, existing.email, existing.key)
    return res.json({ exists: true, upgraded, key: existing.key, name: existing.name, expiresAt: existing.expiresAt })
  }

  const key = genToken()
  let expiresAt = null
  if (!make_permanent && expires_in_hours && expires_in_hours > 0) {
    expiresAt = new Date(Date.now() + expires_in_hours * 3600_000).toISOString()
  }

  const token = {
    id: crypto.randomUUID(),
    key,
    name: trimName,
    email: email.toLowerCase(),
    registeredName: trimName,
    source: source || 'tf-auto',
    enabled: true,
    createdAt: new Date().toISOString(),
    expiresAt,
    lastUsed: null,
    requestCount: 0,
    rateLimit: data.selfRegisterRateLimit || data.defaultRateLimit || 60,
    downloadLimit: data.selfRegisterDownloadLimit || data.defaultDownloadLimit || 0,
    maxDevices: data.selfRegisterMaxDevices || data.maxDevicesPerToken || 3,
    devices: [],
    dailyStats: {},
    dailyDownloads: {},
    totalDownloads: 0,
    playlistSnapshot: null
  }

  data.tokens.push(token)
  recordBinding(data, { email: token.email, name: token.name, tokenKey: token.key, tokenId: token.id, source: token.source })
  saveData(data)
  console.log('[TF自动注册] 新 Token:', trimName, email, key)

  res.json({ exists: false, key: token.key, name: token.name, expiresAt: token.expiresAt })
})

// --------------- Self-register admin config ---------------
app.get('/api/self-register/config', authMiddleware, (req, res) => {
  res.json({
    selfRegisterEnabled: Boolean(req.appData.selfRegisterEnabled),
    selfRegisterExpiresIn: req.appData.selfRegisterExpiresIn || 30,
    selfRegisterRateLimit: req.appData.selfRegisterRateLimit || 60,
    selfRegisterDownloadLimit: req.appData.selfRegisterDownloadLimit || 0,
    selfRegisterMaxDevices: req.appData.selfRegisterMaxDevices || 3,
    selfRegisterDailyLimit: req.appData.selfRegisterDailyLimit || 50,
    selfRegisterRequireProtectCode: Boolean(req.appData.selfRegisterRequireProtectCode)
  })
})

app.put('/api/self-register/config', authMiddleware, (req, res) => {
  const fields = ['selfRegisterEnabled', 'selfRegisterExpiresIn', 'selfRegisterRateLimit',
                  'selfRegisterDownloadLimit', 'selfRegisterMaxDevices', 'selfRegisterDailyLimit',
                  'selfRegisterRequireProtectCode']
  fields.forEach(f => {
    if (req.body[f] !== undefined) req.appData[f] = req.body[f]
  })
  saveData(req.appData)
  res.json({ ok: true })
})

// --------------- Protect Codes API ---------------
app.get('/api/protect-codes', authMiddleware, (req, res) => {
  res.set('Cache-Control', 'no-store, no-cache, must-revalidate')
  res.set('Pragma', 'no-cache')
  normalizeProtectCodeData(req.appData)
  const protectCodes = req.appData.protectCodes || []
  res.json({
    ok: true,
    protectCodes,
    counts: {
      ipa: protectCodes.filter(item => item.purpose === 'ipa').length,
      tf: protectCodes.filter(item => item.purpose === 'tf').length
    }
  })
})

app.post('/api/protect-codes/generate', authMiddleware, (req, res) => {
  const count = Math.min(1000, Math.max(1, parseInt(req.body.count, 10) || 100))
  const maxUses = Math.min(100000, Math.max(1, parseInt(req.body.maxUses, 10) || 3))
  const requestedPurpose = String(req.body.purpose || 'tf').trim().toLowerCase()
  if (!PROTECT_CODE_PURPOSES.has(requestedPurpose)) {
    return res.status(400).json({ error: 'purpose 必须是 ipa 或 tf' })
  }
  normalizeProtectCodeData(req.appData)

  const newCodes = []
  for (let i = 0; i < count; i++) {
    let code = generateProtectCode()
    while (req.appData.protectCodes.some(item => item.code === code)) code = generateProtectCode()
    const item = {
      code,
      purpose: requestedPurpose,
      maxUses,
      currentUses: 0,
      createdAt: new Date().toISOString()
    }
    newCodes.push(item)
    req.appData.protectCodes.push(item)
  }

  saveData(req.appData)
  res.json({ ok: true, purpose: requestedPurpose, generated: newCodes.length, protectCodes: req.appData.protectCodes })
})

app.put('/api/protect-codes/:code', authMiddleware, (req, res) => {
  const code = req.params.code
  if (!Array.isArray(req.appData.protectCodes)) req.appData.protectCodes = []
  const target = req.appData.protectCodes.find(c => c.code === code)
  
  if (!target) {
    return res.status(404).json({ error: 'Code not found' })
  }

  const { addUses } = req.body
  if (addUses && !isNaN(parseInt(addUses, 10))) {
    target.maxUses += parseInt(addUses, 10)
    saveData(req.appData)
    res.json({ ok: true, item: target })
  } else {
    res.status(400).json({ error: 'Invalid addUses parameter' })
  }
})

app.delete('/api/protect-codes/:code', authMiddleware, (req, res) => {
  const code = req.params.code
  if (!Array.isArray(req.appData.protectCodes)) req.appData.protectCodes = []
  const initialLength = req.appData.protectCodes.length
  req.appData.protectCodes = req.appData.protectCodes.filter(c => c.code !== code)
  
  if (req.appData.protectCodes.length !== initialLength) {
    saveData(req.appData)
    res.json({ ok: true })
  } else {
    res.status(404).json({ error: 'Code not found' })
  }
})

app.post('/api/internal/verify-protect-code', (req, res) => {
  const adminToken = req.headers['x-admin-token']
  const data = loadData()
  if (adminToken !== data.adminPassword) {
    return res.status(401).json({ error: '未授权' })
  }

  const { code, consume, email, name, tokenKey, tokenId, testerId, groupId, accountId, source } = req.body
  if (!code) {
    return res.status(400).json({ error: '缺少 code' })
  }
  const requestedPurpose = String(req.body.purpose || 'tf').trim().toLowerCase()
  if (!PROTECT_CODE_PURPOSES.has(requestedPurpose)) {
    return res.status(400).json({ error: 'purpose 必须是 ipa 或 tf' })
  }

  const target = findProtectCode(data, code, requestedPurpose)
  if (!target) {
    return res.status(404).json({
      error: requestedPurpose === 'ipa'
        ? 'IPA 申请仅支持 IPA 自签保护码或 TestFlight 保护码'
        : 'TestFlight 申请仅支持 TestFlight 保护码'
    })
  }

  if (target.currentUses >= target.maxUses) {
    return res.status(403).json({ error: '保护码使用次数已达上限' })
  }

  // consume === false 时仅校验、不消耗次数（供加入成功前预检使用）
  if (consume === false) {
    return res.json({ ok: true, checked: true, purpose: target.purpose, currentUses: target.currentUses, maxUses: target.maxUses })
  }

  target.currentUses += 1
  if (email || tokenKey) {
    recordBinding(data, { code: target.code, codePurpose: target.purpose, email, name, tokenKey, tokenId, testerId, groupId, accountId, source: source || 'tf-public-join' })
  }
  saveData(data)

  res.json({ ok: true, purpose: target.purpose, currentUses: target.currentUses, maxUses: target.maxUses })
})

// --------------- Bindings management API ---------------
app.get('/api/bindings', authMiddleware, (req, res) => {
  res.set('Cache-Control', 'no-store, no-cache, must-revalidate')
  const data = req.appData
  if (!Array.isArray(data.bindings)) data.bindings = []
  const byId = {}, byKey = {}
  for (const t of (data.tokens || [])) { byId[t.id] = t; if (t.key) byKey[t.key] = t }
  const list = data.bindings.map(b => {
    const t = (b.tokenId && byId[b.tokenId]) || (b.tokenKey && byKey[b.tokenKey]) || null
    return {
      id: b.id, code: b.code, codePurpose: b.codePurpose, email: b.email, name: b.name,
      tokenKey: b.tokenKey, tokenId: b.tokenId, testerId: b.testerId, groupId: b.groupId,
      source: b.source, accountId: b.accountId, createdAt: b.createdAt, updatedAt: b.updatedAt, backfilled: Boolean(b.backfilled),
      tokenExists: Boolean(t),
      tokenEnabled: t ? t.enabled !== false : null,
      tokenExpiresAt: t ? t.expiresAt : null,
      canKick: Boolean(b.testerId && b.groupId && b.accountId)
    }
  }).sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
  res.json({ ok: true, count: list.length, bindings: list })
})

app.post('/api/bindings/:id/toggle-token', authMiddleware, (req, res) => {
  const data = req.appData
  const b = (data.bindings || []).find(x => x.id === req.params.id)
  if (!b) return res.status(404).json({ error: '绑定不存在' })
  const t = (data.tokens || []).find(x => x.id === b.tokenId || (b.tokenKey && x.key === b.tokenKey))
  if (!t) return res.status(404).json({ error: '对应 Token 不存在' })
  t.enabled = t.enabled === false
  saveData(data)
  res.json({ ok: true, enabled: t.enabled })
})

app.delete('/api/bindings/:id', authMiddleware, (req, res) => {
  const data = req.appData
  const before = (data.bindings || []).length
  data.bindings = (data.bindings || []).filter(x => x.id !== req.params.id)
  if (data.bindings.length === before) return res.status(404).json({ error: '绑定不存在' })
  saveData(data)
  res.json({ ok: true })
})

app.post('/api/bindings/:id/kick', authMiddleware, async (req, res) => {
  const data = req.appData
  const b = (data.bindings || []).find(x => x.id === req.params.id)
  if (!b) return res.status(404).json({ error: '绑定不存在' })
  if (!b.testerId || !b.groupId || !b.accountId) return res.status(400).json({ error: '该绑定缺少 testerId/groupId/accountId，无法踢出（仅新 TF 绑定支持）' })
  const base = process.env.CERT_MANAGER_URL || 'http://127.0.0.1:3006'
  try {
    const r = await postJson(base + '/api/public/tf/internal/kick-tester', { testerId: b.testerId, groupId: b.groupId, accountId: b.accountId }, { 'x-admin-token': data.adminPassword })
    if (r.status !== 200) return res.status(502).json({ error: '踢出失败', detail: r.body })
    res.json({ ok: true })
  } catch (e) {
    res.status(502).json({ error: '踢出请求失败: ' + e.message })
  }
})

app.use(express.static(PUBLIC_DIR))
app.get('/', (_, res) => res.sendFile('index.html', { root: PUBLIC_DIR }))
app.get('/tokens', (_, res) => res.sendFile('tokens.html', { root: PUBLIC_DIR }))
app.get('/tokens/:tokenId', (_, res) => res.sendFile('token-detail.html', { root: PUBLIC_DIR }))
app.get('/ipa', (_, res) => res.sendFile('ipa.html', { root: PUBLIC_DIR }))
app.get('/changelogs', (_, res) => res.sendFile('changelogs.html', { root: PUBLIC_DIR }))
app.get('/downloads', (_, res) => res.sendFile('downloads.html', { root: PUBLIC_DIR }))
app.get('/register', (_, res) => res.sendFile('register.html', { root: PUBLIC_DIR }))
app.get('/profile', (_, res) => res.sendFile('profile.html', { root: PUBLIC_DIR }))
app.get('/protect-codes', (_, res) => res.sendFile('protect-codes.html', { root: PUBLIC_DIR }))
app.get('/bindings', (_, res) => res.sendFile('bindings.html', { root: PUBLIC_DIR }))

app.listen(PORT, '127.0.0.1', () => {
  const data = loadData()
  const _bf = backfillBindings(data)
  const migratedCloudSnapshots = pendingCloudCompactionCount
  if (_bf > 0 || migratedCloudSnapshots > 0) saveData(data)
  if (_bf > 0) console.log(`[绑定回填] 已补录 ${_bf} 条历史绑定`)
  if (migratedCloudSnapshots > 0) {
    const cloudStats = cloudSnapshotStore.stats()
    console.log(`[cloud-storage] 已迁移 ${migratedCloudSnapshots} 份云端快照，数据库 ${(cloudStats.snapshotBytes / 1024 / 1024).toFixed(1)} MB`)
    pendingCloudCompactionCount = 0
  }
  console.log(`Token 管理服务运行在 http://127.0.0.1:${PORT}`)
  console.log(`Token 验证总开关: ${data.globalEnabled ? '开启' : '关闭'}`)
  console.log(`限速总开关: ${data.rateLimitEnabled ? '开启' : '关闭'}`)
  console.log(`默认限速: ${data.defaultRateLimit} 次/分钟`)
  console.log(`下载限制总开关: ${data.downloadLimitEnabled ? '开启' : '关闭'}`)
  console.log(`默认每日下载限制: ${data.defaultDownloadLimit} 次/天`)
  console.log(`已注册 Token 数: ${data.tokens.length}`)
})
