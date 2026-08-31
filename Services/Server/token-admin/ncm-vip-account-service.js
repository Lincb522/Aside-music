const crypto = require('crypto')
const http = require('http')

const QR_SESSION_TTL_MS = 5 * 60 * 1000
const SUPPORTED_CONTENT_ROUTES = new Set([
  '/lyric/new',
  '/recommend/songs',
  '/song/detail',
  '/song/qualities',
  '/song/url/v1'
])

function createNCMRequest({ hostname = '127.0.0.1', port = 4006 } = {}) {
  return function requestNCM(pathname, { params = {}, cookie = null } = {}) {
    return new Promise((resolve, reject) => {
      const body = new URLSearchParams()
      for (const [key, value] of Object.entries(params)) {
        if (value === undefined || value === null) continue
        body.set(key, typeof value === 'string' ? value : JSON.stringify(value))
      }
      const payload = body.toString()
      const headers = {
        Accept: 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(payload)
      }
      if (cookie) headers.Cookie = cookie

      const request = http.request({
        hostname,
        port,
        path: pathname,
        method: 'POST',
        headers,
        timeout: 20_000
      }, response => {
        let raw = ''
        response.on('data', chunk => {
          raw += chunk
          if (raw.length > 8 * 1024 * 1024) response.destroy(new Error('NCM response too large'))
        })
        response.on('end', () => {
          try {
            resolve({ status: response.statusCode || 502, body: JSON.parse(raw) })
          } catch {
            resolve({ status: response.statusCode || 502, body: { code: response.statusCode || 502 } })
          }
        })
      })
      request.on('error', reject)
      request.on('timeout', () => request.destroy(new Error('NCM API timeout')))
      request.end(payload)
    })
  }
}

function normalizeCookie(value) {
  if (typeof value !== 'string' || !value.trim()) return null
  const ignored = new Set([
    'domain', 'expires', 'httponly', 'max-age', 'path', 'samesite', 'secure'
  ])
  const values = new Map()
  for (const segment of value.split(';')) {
    const pair = segment.trim()
    const separator = pair.indexOf('=')
    if (separator <= 0) continue
    const name = pair.slice(0, separator).trim()
    const cookieValue = pair.slice(separator + 1).trim()
    if (!/^[A-Za-z0-9_-]+$/.test(name) || ignored.has(name.toLowerCase()) || !cookieValue) continue
    values.set(name, cookieValue)
  }
  if (!values.has('MUSIC_U') && !values.has('MUSIC_A')) return null
  return [...values.entries()].map(([name, cookieValue]) => `${name}=${cookieValue}`).join('; ')
}

function timestampMilliseconds(value) {
  const number = Number(value)
  if (!Number.isFinite(number) || number <= 0) return null
  return number < 10_000_000_000 ? Math.trunc(number * 1000) : Math.trunc(number)
}

function loginProfile(payload) {
  const data = payload?.data && typeof payload.data === 'object' ? payload.data : payload
  const profile = data?.profile
  return profile && typeof profile === 'object' ? profile : null
}

function membershipMetadata(profile, vipPayload) {
  const data = vipPayload?.data && typeof vipPayload.data === 'object' ? vipPayload.data : {}
  const nestedExpiries = [data.associator?.expireTime, data.musicPackage?.expireTime]
    .map(timestampMilliseconds)
    .filter(Boolean)
  const explicitExpiry = timestampMilliseconds(data.redVipExpireTime ?? data.expireTime)
  const expiresAt = [explicitExpiry, ...nestedExpiries].filter(Boolean).sort((a, b) => b - a)[0] || null
  const vipType = Number(profile?.vipType || data.vipType || 0)
  const redVipLevel = Number(data.redVipLevel ?? data.vipLevel ?? data.level ?? 0)
  const activeByExpiry = expiresAt === null || expiresAt > Date.now()
  const isMember = activeByExpiry && (vipType > 0 || redVipLevel > 0 || nestedExpiries.some(value => value > Date.now()))
  return {
    membershipLevel: isMember ? 'vip' : 'none',
    vipType,
    redVipLevel,
    expiresAt: expiresAt ? new Date(expiresAt).toISOString() : null,
    isMember
  }
}

function publicAccount(account, activeAccountId) {
  return {
    id: account.id,
    userId: account.userId,
    nickname: account.nickname || null,
    avatarUrl: account.avatarUrl || null,
    membershipLevel: account.membershipLevel === 'vip' ? 'vip' : 'none',
    vipType: Number(account.vipType) || 0,
    redVipLevel: Number(account.redVipLevel) || 0,
    expiresAt: account.expiresAt || null,
    health: account.health || 'unknown',
    isActive: account.id === activeAccountId,
    createdAt: account.createdAt,
    updatedAt: account.updatedAt,
    lastCheckedAt: account.lastCheckedAt || null,
    lastUsedAt: account.lastUsedAt || null
  }
}

function installNCMVIPAccountPoolRoutes(options) {
  const {
    app,
    express,
    loadData,
    saveData,
    resolvePublicToken,
    encryptSecret,
    decryptSecret,
    requestNCM = createNCMRequest()
  } = options
  if (!app || !express || !loadData || !saveData || !resolvePublicToken || !encryptSecret || !decryptSecret) {
    throw new Error('NCM VIP account pool dependencies are incomplete')
  }

  const qrSessions = new Map()
  const urlencoded = express.urlencoded({ extended: false, limit: '256kb' })

  function ensurePool(data) {
    if (!Array.isArray(data.ncmVipAccounts)) data.ncmVipAccounts = []
    if (data.activeNcmVipAccountId === undefined) data.activeNcmVipAccountId = null
    if (!data.ncmVipAccounts.some(account => account.id === data.activeNcmVipAccountId && account.health === 'available')) {
      data.activeNcmVipAccountId = data.ncmVipAccounts.find(account => account.health === 'available')?.id || null
    }
    return data.ncmVipAccounts
  }

  function publicPool(data) {
    const accounts = ensurePool(data)
      .slice()
      .sort((lhs, rhs) => {
        const lhsActive = lhs.id === data.activeNcmVipAccountId ? 0 : 1
        const rhsActive = rhs.id === data.activeNcmVipAccountId ? 0 : 1
        if (lhsActive !== rhsActive) return lhsActive - rhsActive
        return (Date.parse(rhs.updatedAt || 0) || 0) - (Date.parse(lhs.updatedAt || 0) || 0)
      })
      .map(account => publicAccount(account, data.activeNcmVipAccountId))
    return {
      activeAccountId: data.activeNcmVipAccountId,
      available: accounts.some(account => account.health === 'available'),
      accounts
    }
  }

  function orderedAccounts(data) {
    ensurePool(data)
    return data.ncmVipAccounts
      .filter(account => account.encryptedCookie && account.health === 'available')
      .sort((lhs, rhs) => {
        const lhsActive = lhs.id === data.activeNcmVipAccountId ? 0 : 1
        const rhsActive = rhs.id === data.activeNcmVipAccountId ? 0 : 1
        if (lhsActive !== rhsActive) return lhsActive - rhsActive
        return (Date.parse(rhs.updatedAt || 0) || 0) - (Date.parse(lhs.updatedAt || 0) || 0)
      })
  }

  async function validateCookie(cookie) {
    const status = await requestNCM('/login/status', { cookie })
    const profile = loginProfile(status.body)
    const userId = String(profile?.userId ?? '').trim()
    if (status.status < 200 || status.status >= 300 || !userId) {
      return { valid: false, reason: 'NCM 登录状态已失效' }
    }
    const vip = await requestNCM('/vip/info', { params: { uid: userId }, cookie })
    const membership = membershipMetadata(profile, vip.body)
    if (vip.status < 200 || vip.status >= 300 || Number(vip.body?.code) !== 200 || !membership.isMember) {
      return { valid: false, reason: '该账号当前不是有效会员' }
    }
    return {
      valid: true,
      userId,
      nickname: typeof profile.nickname === 'string' ? profile.nickname.slice(0, 120) : null,
      avatarUrl: typeof profile.avatarUrl === 'string' ? profile.avatarUrl.slice(0, 2048) : null,
      ...membership
    }
  }

  async function saveScannedAccount(data, cookie) {
    const validation = await validateCookie(cookie)
    if (!validation.valid) return validation

    ensurePool(data)
    const now = new Date().toISOString()
    let account = data.ncmVipAccounts.find(item => String(item.userId) === validation.userId)
    if (!account) {
      account = {
        id: crypto.createHash('sha256').update(`ncm-vip:${validation.userId}`).digest('hex').slice(0, 24),
        userId: validation.userId,
        createdAt: now
      }
      data.ncmVipAccounts.push(account)
    }
    Object.assign(account, {
      nickname: validation.nickname,
      avatarUrl: validation.avatarUrl,
      membershipLevel: validation.membershipLevel,
      vipType: validation.vipType,
      redVipLevel: validation.redVipLevel,
      expiresAt: validation.expiresAt,
      health: 'available',
      encryptedCookie: encryptSecret(data, cookie),
      updatedAt: now,
      lastCheckedAt: now
    })
    data.activeNcmVipAccountId = account.id
    saveData(data)
    return { valid: true, account }
  }

  async function refreshAccount(data, account) {
    const cookie = decryptSecret(data, account.encryptedCookie)
    if (!cookie) {
      account.health = 'unavailable'
      account.lastCheckedAt = new Date().toISOString()
      account.updatedAt = account.lastCheckedAt
      saveData(data)
      return { valid: false, reason: '账号凭据不可用' }
    }
    const validation = await validateCookie(cookie)
    const now = new Date().toISOString()
    account.lastCheckedAt = now
    account.updatedAt = now
    if (!validation.valid) {
      account.health = 'expired'
      if (data.activeNcmVipAccountId === account.id) data.activeNcmVipAccountId = null
      ensurePool(data)
      saveData(data)
      return validation
    }
    Object.assign(account, {
      nickname: validation.nickname,
      avatarUrl: validation.avatarUrl,
      membershipLevel: validation.membershipLevel,
      vipType: validation.vipType,
      redVipLevel: validation.redVipLevel,
      expiresAt: validation.expiresAt,
      health: 'available'
    })
    saveData(data)
    return { valid: true, account }
  }

  function pruneQRSessions() {
    const now = Date.now()
    for (const [id, session] of qrSessions) {
      if (session.expiresAt <= now || session.completed) qrSessions.delete(id)
    }
  }

  app.get('/api/account/ncm/pool', (req, res) => {
    const resolved = resolvePublicToken(req, res)
    if (!resolved) return
    res.set('Cache-Control', 'private, no-store')
    res.json({ ok: true, ...publicPool(resolved.data) })
  })

  app.patch('/api/account/ncm/pool/accounts/:accountId/active', async (req, res) => {
    const resolved = resolvePublicToken(req, res)
    if (!resolved) return
    const account = ensurePool(resolved.data).find(item => item.id === req.params.accountId)
    if (!account) return res.status(404).json({ error: 'NCM VIP 账号不存在' })
    const refreshed = await refreshAccount(resolved.data, account)
    if (!refreshed.valid) return res.status(409).json({ error: refreshed.reason, ...publicPool(resolved.data) })
    resolved.data.activeNcmVipAccountId = account.id
    account.lastUsedAt = new Date().toISOString()
    saveData(resolved.data)
    res.set('Cache-Control', 'private, no-store')
    res.json({ ok: true, ...publicPool(resolved.data) })
  })

  app.post('/api/account/ncm/pool/accounts/:accountId/refresh', async (req, res) => {
    const resolved = resolvePublicToken(req, res)
    if (!resolved) return
    const account = ensurePool(resolved.data).find(item => item.id === req.params.accountId)
    if (!account) return res.status(404).json({ error: 'NCM VIP 账号不存在' })
    const refreshed = await refreshAccount(resolved.data, account)
    res.set('Cache-Control', 'private, no-store')
    res.status(refreshed.valid ? 200 : 409).json({
      ok: refreshed.valid,
      error: refreshed.valid ? undefined : refreshed.reason,
      ...publicPool(resolved.data)
    })
  })

  app.post('/api/account/ncm/pool/qr', async (req, res) => {
    const resolved = resolvePublicToken(req, res)
    if (!resolved) return
    pruneQRSessions()
    try {
      const anonymousCookie = `NMTID=${crypto.randomBytes(32).toString('hex')}; __remember_me=true`
      const keyResponse = await requestNCM('/login/qr/key', {
        params: { timestamp: Date.now() },
        cookie: anonymousCookie
      })
      const key = keyResponse.body?.data?.unikey
      if (keyResponse.status < 200 || keyResponse.status >= 300 || typeof key !== 'string' || !key) {
        return res.status(502).json({ error: '无法创建 NCM 登录二维码' })
      }
      const imageResponse = await requestNCM('/login/qr/create', {
        params: { key, qrimg: 'true', timestamp: Date.now() },
        cookie: anonymousCookie
      })
      const qrURL = imageResponse.body?.data?.qrurl
      if (imageResponse.status < 200 || imageResponse.status >= 300 || typeof qrURL !== 'string' || !qrURL) {
        return res.status(502).json({ error: '无法生成 NCM 登录二维码' })
      }
      const id = crypto.randomUUID()
      const expiresAt = Date.now() + QR_SESSION_TTL_MS
      qrSessions.set(id, {
        id,
        key,
        anonymousCookie,
        tokenId: resolved.token.id,
        expiresAt,
        completed: false
      })
      res.set('Cache-Control', 'private, no-store')
      res.status(201).json({ ok: true, sessionId: id, qrURL, expiresAt: new Date(expiresAt).toISOString() })
    } catch {
      res.status(502).json({ error: 'NCM 二维码服务暂不可用' })
    }
  })

  app.get('/api/account/ncm/pool/qr/:sessionId', async (req, res) => {
    const resolved = resolvePublicToken(req, res)
    if (!resolved) return
    pruneQRSessions()
    const session = qrSessions.get(req.params.sessionId)
    if (!session || session.tokenId !== resolved.token.id) {
      return res.status(404).json({ error: 'NCM 登录二维码不存在或已过期' })
    }
    try {
      const result = await requestNCM('/login/qr/check', {
        params: { key: session.key, timestamp: Date.now() },
        cookie: session.anonymousCookie
      })
      const code = Number(result.body?.code)
      if (code === 800) {
        qrSessions.delete(session.id)
        return res.status(410).json({ ok: false, state: 'expired', message: '二维码已过期' })
      }
      if (code === 801) return res.json({ ok: true, state: 'waiting' })
      if (code === 802) return res.json({ ok: true, state: 'authorizing' })
      if (code !== 803) return res.status(502).json({ error: 'NCM 扫码状态异常' })

      const cookie = normalizeCookie(result.body?.cookie)
      if (!cookie) return res.status(502).json({ error: 'NCM 登录未返回有效凭据' })
      const saved = await saveScannedAccount(resolved.data, cookie)
      session.completed = true
      qrSessions.delete(session.id)
      if (!saved.valid) return res.status(409).json({ ok: false, state: 'rejected', message: saved.reason })
      res.set('Cache-Control', 'private, no-store')
      res.json({
        ok: true,
        state: 'completed',
        account: publicAccount(saved.account, resolved.data.activeNcmVipAccountId),
        ...publicPool(resolved.data)
      })
    } catch {
      res.status(502).json({ error: 'NCM 扫码状态查询失败' })
    }
  })

  async function proxyContent(req, res, route) {
    const resolved = resolvePublicToken(req, res, { checkDeviceBind: false })
    if (!resolved) return
    const accounts = orderedAccounts(resolved.data)
    if (!accounts.length) return res.status(503).json({ error: 'NCM VIP 账号池暂无可用账号' })

    const params = { ...req.query, ...(req.body || {}) }
    delete params.token
    let lastStatus = 502
    let lastBody = { code: 502, message: 'NCM VIP 账号池请求失败' }
    for (const account of accounts) {
      const cookie = decryptSecret(resolved.data, account.encryptedCookie)
      if (!cookie) continue
      try {
        const result = await requestNCM(route, { params, cookie })
        lastStatus = result.status
        lastBody = result.body
        const code = Number(result.body?.code)
        if (code === 301) {
          account.health = 'expired'
          account.lastCheckedAt = new Date().toISOString()
          if (resolved.data.activeNcmVipAccountId === account.id) resolved.data.activeNcmVipAccountId = null
          ensurePool(resolved.data)
          saveData(resolved.data)
          continue
        }
        if (result.status >= 200 && result.status < 300 && (code === 200 || !Number.isFinite(code))) {
          account.lastUsedAt = new Date().toISOString()
          saveData(resolved.data)
          res.set('Cache-Control', 'private, no-store')
          return res.status(result.status).json(result.body)
        }
      } catch {
        lastStatus = 502
        lastBody = { code: 502, message: 'NCM VIP 上游暂不可用' }
      }
    }
    res.status(lastStatus >= 400 ? lastStatus : 502).json(lastBody)
  }

  for (const route of SUPPORTED_CONTENT_ROUTES) {
    const path = `/api/account/ncm/pool${route}`
    app.get(path, (req, res) => proxyContent(req, res, route))
    app.post(path, urlencoded, (req, res) => proxyContent(req, res, route))
  }

  return { publicPool, validateCookie }
}

module.exports = {
  createNCMRequest,
  installNCMVIPAccountPoolRoutes,
  membershipMetadata,
  normalizeCookie,
  publicAccount
}
