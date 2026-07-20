const crypto = require('crypto')

const SCHEMA_VERSION = 1
const ALLOWED_PROTOCOLS = new Set([
  'appleIntelligence',
  'openAIResponses',
  'openAIChat',
  'anthropicMessages',
  'googleGemini',
  'azureOpenAI',
  'ollama',
  'openAICompatible'
])
const FORBIDDEN_CUSTOM_HEADERS = new Set([
  'authorization',
  'content-length',
  'host',
  'x-admin-token',
  'x-api-token',
  'x-device-id'
])

function installAIRemoteConfigRoutes({ app, saveData, authMiddleware, resolvePublicToken }) {

  app.get('/api/ai/config', authMiddleware, (req, res) => {
    res.json(adminPayload(ensureConfiguration(req.appData.aiProviderConfig)))
  })

  app.put('/api/ai/config', authMiddleware, (req, res) => {
    const current = ensureConfiguration(req.appData.aiProviderConfig)
    const expectedRevision = cleanString(req.body?.expectedRevision, 160)
    if (expectedRevision && expectedRevision !== current.revision) {
      return res.status(409).json({
        error: 'configuration changed',
        revision: current.revision,
        updatedAt: current.updatedAt
      })
    }

    const validation = validateAdminUpdate(req.body, current)
    if (!validation.ok) {
      return res.status(400).json({ error: validation.error })
    }

    req.appData.aiProviderConfig = validation.configuration
    saveData(req.appData)
    res.json(adminPayload(validation.configuration))
  })

  app.get('/api/public/ai/config', (req, res) => {
    const resolved = resolvePublicToken(req, res)
    if (!resolved) return

    const configuration = ensureConfiguration(resolved.data.aiProviderConfig)
    res.set('Cache-Control', 'private, max-age=60, must-revalidate')
    res.set('ETag', `"${configuration.revision}"`)
    if (req.headers['if-none-match'] === `"${configuration.revision}"`) {
      return res.status(304).end()
    }
    res.json(publicPayload(configuration))
  })

}

function defaultConfiguration() {
  return {
    schemaVersion: SCHEMA_VERSION,
    enabled: false,
    wireProtocol: 'openAICompatible',
    baseURL: '',
    model: '',
    modelDiscoveryURL: '',
    timeout: 60,
    customHeadersJSON: '',
    apiKey: '',
    usageLimits: {
      dailyRequestLimit: 50,
      hourlyRequestLimit: 20,
      minimumRequestInterval: 15
    },
    revision: 'unpublished',
    updatedAt: null
  }
}

function ensureConfiguration(raw) {
  const fallback = defaultConfiguration()
  if (!raw || typeof raw !== 'object') return fallback

  const wireProtocol = ALLOWED_PROTOCOLS.has(raw.wireProtocol)
    ? raw.wireProtocol
    : fallback.wireProtocol
  return {
    schemaVersion: SCHEMA_VERSION,
    enabled: Boolean(raw.enabled),
    wireProtocol,
    baseURL: cleanString(raw.baseURL, 2_048),
    model: cleanString(raw.model, 240),
    modelDiscoveryURL: cleanString(raw.modelDiscoveryURL, 2_048),
    timeout: clampNumber(raw.timeout, 10, 180, fallback.timeout),
    customHeadersJSON: normalizeCustomHeadersJSON(raw.customHeadersJSON),
    apiKey: typeof raw.apiKey === 'string' ? raw.apiKey.trim() : '',
    usageLimits: normalizeUsageLimits(raw.usageLimits),
    revision: cleanString(raw.revision, 160) || 'unpublished',
    updatedAt: validISODate(raw.updatedAt) ? new Date(raw.updatedAt).toISOString() : null
  }
}

function validateAdminUpdate(body, current) {
  const source = body?.configuration && typeof body.configuration === 'object'
    ? body.configuration
    : (body || {})
  const wireProtocol = cleanString(source.wireProtocol, 80)
  if (!ALLOWED_PROTOCOLS.has(wireProtocol)) {
    return { ok: false, error: 'invalid wireProtocol' }
  }

  const enabled = body?.enabled === undefined
    ? (source.enabled === undefined ? true : Boolean(source.enabled))
    : Boolean(body.enabled)
  const baseURL = cleanString(source.baseURL, 2_048)
  const model = cleanString(source.model, 240)
  const modelDiscoveryURL = cleanString(source.modelDiscoveryURL, 2_048)

  if (wireProtocol !== 'appleIntelligence') {
    if (!isHTTPURL(baseURL)) return { ok: false, error: 'invalid baseURL' }
    if (!model) return { ok: false, error: 'model is required' }
  }
  if (modelDiscoveryURL && !isHTTPURL(modelDiscoveryURL)) {
    return { ok: false, error: 'invalid modelDiscoveryURL' }
  }

  let customHeadersJSON = ''
  try {
    customHeadersJSON = validateCustomHeadersJSON(source.customHeadersJSON)
  } catch (error) {
    return { ok: false, error: error.message }
  }

  const apiKeySource = body?.apiKey === undefined ? source.apiKey : body.apiKey
  const apiKey = apiKeySource === undefined
    ? current.apiKey
    : (typeof apiKeySource === 'string' ? apiKeySource.trim() : '')
  const updatedAt = new Date().toISOString()
  const configuration = {
    schemaVersion: SCHEMA_VERSION,
    enabled,
    wireProtocol,
    baseURL,
    model,
    modelDiscoveryURL,
    timeout: clampNumber(source.timeout, 10, 180, 60),
    customHeadersJSON,
    apiKey,
    usageLimits: normalizeUsageLimits(body?.usageLimits || source.usageLimits),
    revision: crypto.randomUUID(),
    updatedAt
  }
  return { ok: true, configuration }
}

function adminPayload(configuration) {
  return {
    ok: true,
    ...configuration,
    hasAPIKey: Boolean(configuration.apiKey)
  }
}

function publicPayload(configuration) {
  return {
    ok: true,
    schemaVersion: configuration.schemaVersion,
    enabled: configuration.enabled,
    wireProtocol: configuration.wireProtocol,
    baseURL: configuration.baseURL,
    model: configuration.model,
    modelDiscoveryURL: configuration.modelDiscoveryURL,
    timeout: configuration.timeout,
    customHeadersJSON: configuration.customHeadersJSON,
    apiKey: configuration.apiKey,
    usageLimits: configuration.usageLimits,
    revision: configuration.revision,
    updatedAt: configuration.updatedAt
  }
}

function normalizeUsageLimits(raw) {
  return {
    dailyRequestLimit: Math.round(clampNumber(raw?.dailyRequestLimit, 0, 10_000, 50)),
    hourlyRequestLimit: Math.round(clampNumber(raw?.hourlyRequestLimit, 0, 1_000, 20)),
    minimumRequestInterval: clampNumber(raw?.minimumRequestInterval, 0, 3_600, 15)
  }
}

function validateCustomHeadersJSON(raw) {
  const normalized = typeof raw === 'string' ? raw.trim() : ''
  if (!normalized) return ''
  const value = JSON.parse(normalized)
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('customHeadersJSON must be an object')
  }
  for (const [key, headerValue] of Object.entries(value)) {
    if (!key.trim() || FORBIDDEN_CUSTOM_HEADERS.has(key.toLowerCase())) {
      throw new Error(`forbidden custom header: ${key}`)
    }
    if (typeof headerValue !== 'string') {
      throw new Error(`invalid custom header value: ${key}`)
    }
  }
  return JSON.stringify(value)
}

function normalizeCustomHeadersJSON(raw) {
  try {
    return validateCustomHeadersJSON(raw)
  } catch (_) {
    return ''
  }
}

function cleanString(value, maxLength) {
  return typeof value === 'string' ? value.trim().slice(0, maxLength) : ''
}

function clampNumber(value, minimum, maximum, fallback) {
  const number = Number(value)
  if (!Number.isFinite(number)) return fallback
  return Math.min(maximum, Math.max(minimum, number))
}

function validISODate(value) {
  return typeof value === 'string' && !Number.isNaN(Date.parse(value))
}

function isHTTPURL(value) {
  try {
    const url = new URL(value)
    return url.protocol === 'http:' || url.protocol === 'https:'
  } catch (_) {
    return false
  }
}

module.exports = { installAIRemoteConfigRoutes }
