const express = require('express')
const crypto = require('crypto')
const fs = require('fs')
const path = require('path')

const http = require('http')
const app = express()
app.use(express.json({ limit: '10mb' }))

const DATA_FILE = path.join(__dirname, 'data.json')
const PUBLIC_DIR = path.join(__dirname, 'public')
const STORAGE_DIR = path.join(__dirname, 'storage')
const IPA_DIR = path.join(STORAGE_DIR, 'ipas')
const PORT = 3388
const startedAt = new Date().toISOString()

fs.mkdirSync(PUBLIC_DIR, { recursive: true })
fs.mkdirSync(IPA_DIR, { recursive: true })

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
function loadData() {
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
      ipaReleases: [],
      tokens: []
    }
    fs.writeFileSync(DATA_FILE, JSON.stringify(initial, null, 2))
    console.log('初始管理密码:', initial.adminPassword)
    return initial
  }
  const data = JSON.parse(fs.readFileSync(DATA_FILE, 'utf-8'))
  if (data.defaultRateLimit === undefined) data.defaultRateLimit = 60
  if (data.rateLimitEnabled === undefined) data.rateLimitEnabled = true
  if (data.downloadLimitEnabled === undefined) data.downloadLimitEnabled = false
  if (data.defaultDownloadLimit === undefined) data.defaultDownloadLimit = 0
  if (data.deviceBindEnabled === undefined) data.deviceBindEnabled = false
  if (data.maxDevicesPerToken === undefined) data.maxDevicesPerToken = 3
  if (!Array.isArray(data.ipaReleases)) data.ipaReleases = []
  return data
}

function saveData(data) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2))
}

function migrateToken(t) {
  if (t.expiresAt === undefined) t.expiresAt = null
  if (t.rateLimit === undefined) t.rateLimit = 60
  if (t.dailyStats === undefined) t.dailyStats = {}
  if (t.requestCount === undefined) t.requestCount = 0
  if (t.lastUsed === undefined) t.lastUsed = null
  if (t.downloadLimit === undefined) t.downloadLimit = 0
  if (t.dailyDownloads === undefined) t.dailyDownloads = {}
  if (t.totalDownloads === undefined) t.totalDownloads = 0
  if (t.devices === undefined) t.devices = []
  if (t.maxDevices === undefined) t.maxDevices = 3
  if (t.playlistSnapshot === undefined) t.playlistSnapshot = null
  return t
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



// --------------- Device bind helper ---------------
function checkDeviceBind(data, t, deviceId) {
  if (!data.deviceBindEnabled) return { allowed: true }
  if (!deviceId) return { allowed: true }
  const existing = t.devices.find(d => d.deviceId === deviceId)
  if (existing) {
    existing.lastSeen = new Date().toISOString()
    return { allowed: true }
  }
  const maxDev = t.maxDevices || data.maxDevicesPerToken || 3
  if (t.devices.length >= maxDev) {
    return { allowed: false, reason: 'device_limit', current: t.devices.length, max: maxDev }
  }
  t.devices.push({ deviceId, firstSeen: new Date().toISOString(), lastSeen: new Date().toISOString() })
  return { allowed: true, newDevice: true }
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
    const devCheck = checkDeviceBind(data, token, deviceId)
    if (!devCheck.allowed) {
      res.status(403).json({
        error: devCheck.reason,
        current: devCheck.current,
        max: devCheck.max
      })
      return null
    }
    if (devCheck.newDevice) saveData(data)
  }

  return { data, token, tokenKey, deviceId }
}

function normalizePlaylistItem(item) {
  if (!item || typeof item !== 'object') return null
  const songs = Array.isArray(item.songs) ? item.songs : []
  const now = new Date().toISOString()

  return {
    id: typeof item.id === 'string' && item.id.trim() ? item.id.trim() : crypto.randomUUID(),
    name: typeof item.name === 'string' && item.name.trim() ? item.name.trim() : '未命名歌单',
    desc: typeof item.desc === 'string' ? item.desc : null,
    coverUrl: typeof item.coverUrl === 'string' ? item.coverUrl : null,
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

function makePlaylistSnapshot(playlists, extra = {}) {
  const normalizedPlaylists = Array.isArray(playlists)
    ? playlists.map(normalizePlaylistItem).filter(Boolean)
    : []
  const revision = crypto
    .createHash('sha1')
    .update(JSON.stringify(normalizedPlaylists))
    .digest('hex')
    .slice(0, 16)
  const updatedAt = typeof extra.updatedAt === 'string' && !Number.isNaN(Date.parse(extra.updatedAt))
    ? new Date(extra.updatedAt).toISOString()
    : new Date().toISOString()

  return {
    version: 1,
    updatedAt,
    revision,
    deviceId: typeof extra.deviceId === 'string' ? extra.deviceId : null,
    deviceName: typeof extra.deviceName === 'string' ? extra.deviceName : null,
    playlistCount: normalizedPlaylists.length,
    songCount: normalizedPlaylists.reduce((sum, playlist) => {
      return sum + (Array.isArray(playlist.songs) ? playlist.songs.length : 0)
    }, 0),
    playlists: normalizedPlaylists
  }
}

function playlistSnapshotSummary(snapshot) {
  if (!snapshot) {
    return {
      hasSnapshot: false,
      updatedAt: null,
      revision: null,
      deviceId: null,
      deviceName: null,
      playlistCount: 0,
      songCount: 0
    }
  }

  return {
    hasSnapshot: true,
    updatedAt: snapshot.updatedAt || null,
    revision: snapshot.revision || null,
    deviceId: snapshot.deviceId || null,
    deviceName: snapshot.deviceName || null,
    playlistCount: snapshot.playlistCount || 0,
    songCount: snapshot.songCount || 0
  }
}

function playlistAdminPayload(playlist) {
  return {
    id: playlist.id,
    name: playlist.name,
    desc: playlist.desc,
    coverUrl: playlist.coverUrl,
    createdAt: playlist.createdAt,
    updatedAt: playlist.updatedAt,
    isSystem: Boolean(playlist.isSystem),
    songCount: Array.isArray(playlist.songs) ? playlist.songs.length : 0,
    songs: Array.isArray(playlist.songs)
      ? playlist.songs.map((song, index) => ({
        ...song,
        __songKey: playlistSongKey(song, index)
      }))
      : []
  }
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
    enabled: Boolean(token.enabled),
    createdAt: token.createdAt,
    expiresAt: token.expiresAt,
    lastUsed: token.lastUsed,
    requestCount: token.requestCount || 0,
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
    dailyDownloads: token.dailyDownloads || {},
    todayDownloads: todayCount,
    remainingDownloads
  }
}

function rebuildPlaylistSnapshot(snapshot) {
  if (!snapshot) return null
  return makePlaylistSnapshot(snapshot.playlists || [], {
    deviceId: snapshot.deviceId,
    deviceName: snapshot.deviceName
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
  if (token !== data.adminPassword) {
    return res.status(401).json({ error: '未授权' })
  }
  data.tokens = data.tokens.map(migrateToken)
  data.ipaReleases = sortReleasesDesc(data.ipaReleases.map(migrateRelease))
  req.appData = data
  next()
}

// --------------- Auth routes ---------------
app.get('/api/auth/check', authMiddleware, (req, res) => {
  res.json({ ok: true })
})

app.post('/api/auth/login', (req, res) => {
  const { password } = req.body
  const data = loadData()
  if (password === data.adminPassword) {
    return res.json({ ok: true, token: data.adminPassword })
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
    tokens,
    ipaReleases
  } = req.appData
  const today = todayKey()
  let totalRequests = 0
  let todayRequests = 0
  let totalDownloads = 0
  let todayDownloads = 0
  const activeCount = tokens.filter(t => {
    const notExpired = !t.expiresAt || new Date(t.expiresAt) > new Date()
    return t.enabled && notExpired
  }).length

  tokens.forEach(t => {
    totalRequests += t.requestCount || 0
    totalDownloads += t.totalDownloads || 0
    if (t.dailyStats && t.dailyStats[today]) {
      todayRequests += t.dailyStats[today]
    }
    if (t.dailyDownloads && t.dailyDownloads[today]) {
      todayDownloads += t.dailyDownloads[today]
    }
  })

  const publishedReleases = ipaReleases.filter(release => release.published && hasReleaseFile(release))
  const latestPublishedRelease = publishedReleases[0] ? publicReleasePayload(publishedReleases[0]) : null

  res.json({
    globalEnabled,
    rateLimitEnabled,
    defaultRateLimit,
    downloadLimitEnabled,
    defaultDownloadLimit,
    tokens: tokens.map(tokenSummaryPayload),
    totalRequests,
    todayRequests,
    totalDownloads,
    todayDownloads,
    activeCount,
    totalCount: tokens.length,
    deviceBindEnabled,
    maxDevicesPerToken,
    ipaReleases: ipaReleases.map(adminReleasePayload),
    ipaReleaseCount: ipaReleases.length,
    publishedIpaReleaseCount: publishedReleases.length,
    latestPublishedRelease
  })
})

// --------------- Global toggle ---------------
app.post('/api/toggle', authMiddleware, (req, res) => {
  req.appData.globalEnabled = !req.appData.globalEnabled
  saveData(req.appData)
  res.json({ globalEnabled: req.appData.globalEnabled })
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
  const { name, expiresIn, rateLimit, downloadLimit, maxDevices } = req.body
  const key = genToken()

  let expiresAt = null
  if (expiresIn && expiresIn > 0) {
    expiresAt = new Date(Date.now() + expiresIn * 86400_000).toISOString()
  }

  const token = {
    id: crypto.randomUUID(),
    key,
    name: name || '未命名',
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
  express.raw({ type: () => true, limit: '2048mb' }),
  (req, res) => {
    const release = req.appData.ipaReleases.find(item => item.id === req.params.id)
    if (!release) return res.status(404).json({ error: '未找到版本' })
    if (!Buffer.isBuffer(req.body) || !req.body.length) {
      return res.status(400).json({ error: '未收到文件内容' })
    }

    const originalName = sanitizeFileName(req.headers['x-file-name'] || `${release.title || release.version}.ipa`)
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

  res.download(releaseFilePath(release), release.fileName || `${release.title || release.version}.ipa`)
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
app.get('/api/verify', (req, res) => {
  const data = loadData()
  data.tokens = data.tokens.map(migrateToken)

  if (!data.globalEnabled) {
    return res.json({ valid: true, enabled: false })
  }

  const tokenKey = req.query.token
  if (!tokenKey) {
    return res.status(401).json({ valid: false, reason: 'missing' })
  }

  const t = data.tokens.find(t => t.key === tokenKey && t.enabled)
  if (!t) {
    return res.status(403).json({ valid: false, reason: 'invalid' })
  }

  if (t.expiresAt && new Date(t.expiresAt) <= new Date()) {
    return res.status(403).json({ valid: false, reason: 'expired' })
  }

  const deviceId = req.query.deviceId
  const devCheck = checkDeviceBind(data, t, deviceId)
  if (!devCheck.allowed) {
    return res.status(403).json({ valid: false, reason: 'device_limit', current: devCheck.current, max: devCheck.max })
  }
  if (devCheck.newDevice) saveData(data)

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
  const devCheck = checkDeviceBind(data, t, deviceId)
  if (!devCheck.allowed) return res.status(403).json({ error: devCheck.reason, current: devCheck.current, max: devCheck.max })

  const today = todayKey()
  t.lastUsed = new Date().toISOString()
  t.requestCount = (t.requestCount || 0) + 1
  if (!t.dailyStats) t.dailyStats = {}
  t.dailyStats[today] = (t.dailyStats[today] || 0) + 1

  const statsKeys = Object.keys(t.dailyStats).sort()
  if (statsKeys.length > 30) {
    const keep = statsKeys.slice(-30)
    const trimmed = {}
    keep.forEach(k => trimmed[k] = t.dailyStats[k])
    t.dailyStats = trimmed
  }

  saveData(data)
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
  const devCheck = checkDeviceBind(data, t, deviceId)
  if (!devCheck.allowed) return res.status(403).json({ error: devCheck.reason, current: devCheck.current, max: devCheck.max })

  if (data.downloadLimitEnabled && t.downloadLimit > 0) {
    const todayCount = getTodayDownloads(t)
    if (todayCount >= t.downloadLimit) {
      return res.status(429).json({ error: 'download_limit_exceeded', limit: t.downloadLimit, used: todayCount })
    }
  }

  const today = todayKey()
  t.lastUsed = new Date().toISOString()
  t.requestCount = (t.requestCount || 0) + 1
  t.totalDownloads = (t.totalDownloads || 0) + 1
  if (!t.dailyStats) t.dailyStats = {}
  t.dailyStats[today] = (t.dailyStats[today] || 0) + 1
  if (!t.dailyDownloads) t.dailyDownloads = {}
  t.dailyDownloads[today] = (t.dailyDownloads[today] || 0) + 1

  const statsKeys = Object.keys(t.dailyStats).sort()
  if (statsKeys.length > 30) {
    const keep = statsKeys.slice(-30)
    const trimmed = {}
    keep.forEach(k => trimmed[k] = t.dailyStats[k])
    t.dailyStats = trimmed
  }

  const dlKeys = Object.keys(t.dailyDownloads).sort()
  if (dlKeys.length > 30) {
    const keep = dlKeys.slice(-30)
    const trimmed = {}
    keep.forEach(k => trimmed[k] = t.dailyDownloads[k])
    t.dailyDownloads = trimmed
  }

  saveData(data)
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

// --------------- Public playlist snapshot (token-scoped account storage) ---------------
app.get('/api/account/playlists', (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return

  const snapshot = resolved.token.playlistSnapshot
  res.json({
    ok: true,
    tokenName: resolved.token.name,
    hasSnapshot: Boolean(snapshot),
    updatedAt: snapshot?.updatedAt || null,
    revision: snapshot?.revision || null,
    playlists: snapshot?.playlists || []
  })
})

app.put('/api/account/playlists', (req, res) => {
  const resolved = resolvePublicToken(req, res)
  if (!resolved) return

  const playlists = Array.isArray(req.body?.playlists) ? req.body.playlists : null
  if (!playlists) {
    return res.status(400).json({ error: 'invalid playlists payload' })
  }

  resolved.token.playlistSnapshot = makePlaylistSnapshot(playlists, {
    updatedAt: req.body?.updatedAt,
    deviceId: resolved.deviceId,
    deviceName: req.body?.deviceName
  })
  saveData(resolved.data)

  res.json({
    ok: true,
    updatedAt: resolved.token.playlistSnapshot.updatedAt,
    revision: resolved.token.playlistSnapshot.revision,
    playlistCount: resolved.token.playlistSnapshot.playlistCount,
    songCount: resolved.token.playlistSnapshot.songCount
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
app.use(express.static(PUBLIC_DIR))
app.get('/', (_, res) => res.sendFile('index.html', { root: PUBLIC_DIR }))
app.get('/tokens', (_, res) => res.sendFile('tokens.html', { root: PUBLIC_DIR }))
app.get('/tokens/:tokenId', (_, res) => res.sendFile('token-detail.html', { root: PUBLIC_DIR }))
app.get('/ipa', (_, res) => res.sendFile('ipa.html', { root: PUBLIC_DIR }))
app.get('/downloads', (_, res) => res.sendFile('downloads.html', { root: PUBLIC_DIR }))

app.listen(PORT, '127.0.0.1', () => {
  const data = loadData()
  console.log(`Token 管理服务运行在 http://127.0.0.1:${PORT}`)
  console.log(`Token 验证总开关: ${data.globalEnabled ? '开启' : '关闭'}`)
  console.log(`限速总开关: ${data.rateLimitEnabled ? '开启' : '关闭'}`)
  console.log(`默认限速: ${data.defaultRateLimit} 次/分钟`)
  console.log(`下载限制总开关: ${data.downloadLimitEnabled ? '开启' : '关闭'}`)
  console.log(`默认每日下载限制: ${data.defaultDownloadLimit} 次/天`)
  console.log(`已注册 Token 数: ${data.tokens.length}`)
})
