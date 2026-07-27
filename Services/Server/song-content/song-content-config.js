const crypto = require('node:crypto')
const path = require('node:path')
const { createAIProviderContentGenerator } = require('./song-content-pipeline')
const { createSongContentDatabaseEngine } = require('./song-content-database-engine')

function createSongContentConfigStore({ databasePath, encryptionKey, logger = console }) {
  const { DatabaseSync } = require('node:sqlite')
  if (!databasePath) throw new TypeError('song-content databasePath is required')
  const database = new DatabaseSync(databasePath)
  database.exec('PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000;')
  const databaseEngine = createSongContentDatabaseEngine({
    database,
    databasePath,
    migrationsDirectory: path.join(__dirname, 'migrations'),
    logger
  })
  const key = encryptionKey ? crypto.createHash('sha256').update(String(encryptionKey)).digest() : null

  const statements = {
    current: database.prepare(`SELECT v.* FROM song_content_config_publication p
      JOIN song_content_config_versions v ON v.id = p.current_version_id WHERE p.singleton = 1`),
    byId: database.prepare('SELECT * FROM song_content_config_versions WHERE id = ?'),
    list: database.prepare('SELECT * FROM song_content_config_versions ORDER BY version DESC LIMIT 50'),
    insertValidation: database.prepare(`INSERT INTO song_content_config_validations
      (id, config_version_id, passed, result_json, validated_by, validated_at) VALUES (?, ?, ?, ?, ?, ?)`),
    latestValidation: database.prepare('SELECT * FROM song_content_config_validations WHERE config_version_id = ? ORDER BY validated_at DESC LIMIT 1'),
    nextVersion: database.prepare('SELECT COALESCE(MAX(version), 0) + 1 AS value FROM song_content_config_versions'),
    insert: database.prepare(`INSERT INTO song_content_config_versions
      (id, version, status, ai_config_json, client_config_json, created_by, created_at)
      VALUES (?, ?, 'draft', ?, ?, ?, ?)`),
    retirePublished: database.prepare(`UPDATE song_content_config_versions SET status = 'retired'
      WHERE status = 'published' AND id <> ?`),
    publish: database.prepare(`UPDATE song_content_config_versions SET status = 'published',
      published_by = ?, published_at = ? WHERE id = ?`),
    point: database.prepare(`INSERT INTO song_content_config_publication (singleton, current_version_id, updated_at)
      VALUES (1, ?, ?) ON CONFLICT(singleton) DO UPDATE SET current_version_id = excluded.current_version_id,
      updated_at = excluded.updated_at`),
    upsertCredential: database.prepare(`INSERT INTO ai_provider_credentials
      (id, provider, label, encrypted_secret, key_version, created_at, updated_at, rotated_by)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(provider, label) DO UPDATE SET encrypted_secret = excluded.encrypted_secret,
      key_version = excluded.key_version, updated_at = excluded.updated_at, rotated_by = excluded.rotated_by`),
    credential: database.prepare('SELECT * FROM ai_provider_credentials WHERE id = ? OR (provider = ? AND label = ?) LIMIT 1')
  }

  function transaction(operation) {
    database.exec('BEGIN IMMEDIATE')
    try { const result = operation(); database.exec('COMMIT'); return result }
    catch (error) { try { database.exec('ROLLBACK') } catch (_) {}; throw error }
  }

  function createDraft({ ai, client, actorId }) {
    const id = crypto.randomUUID()
    const version = Number(statements.nextVersion.get().value)
    const normalizedAI = normalizeAIConfig(ai)
    const normalizedClient = normalizeClientConfig(client)
    statements.insert.run(id, version, JSON.stringify(normalizedAI), JSON.stringify(normalizedClient), clean(actorId, 160), new Date().toISOString())
    return hydrate(statements.byId.get(id), statements.latestValidation)
  }

  function publish(versionId, actorId) {
    return transaction(() => {
      const target = statements.byId.get(versionId)
      if (!target) throw configError('CONFIG_NOT_FOUND', '配置版本不存在')
      const validation = statements.latestValidation.get(versionId)
      if (target.status === 'draft' && !validation?.passed) throw configError('CONFIG_VALIDATION_REQUIRED', '配置发布前必须通过预发布验证')
      const now = new Date().toISOString()
      statements.retirePublished.run(versionId)
      statements.publish.run(clean(actorId, 160), now, versionId)
      statements.point.run(versionId, now)
      return hydrate(statements.byId.get(versionId), statements.latestValidation)
    })
  }

  function current() {
    const row = statements.current.get()
    return row ? hydrate(row, statements.latestValidation) : defaultRelease()
  }

  function list() {
    return statements.list.all().map((row) => hydrate(row, statements.latestValidation))
  }

  function get(versionId) {
    const row = statements.byId.get(versionId)
    return row ? hydrate(row, statements.latestValidation) : null
  }

  function markValidated(versionId, validation, actorId) {
    if (!statements.byId.get(versionId)) throw configError('CONFIG_NOT_FOUND', '配置版本不存在')
    statements.insertValidation.run(crypto.randomUUID(), versionId, validation?.passed ? 1 : 0, JSON.stringify(validation || {}), clean(actorId, 160), new Date().toISOString())
    return get(versionId)
  }

  function publicConfiguration(context = {}) {
    const release = current()
    const eligible = isEligible(release.client, context, release.version)
    return {
      schema_version: 2,
      release: release.id,
      version: release.version,
      enabled: release.client.enabled && eligible,
      modules: release.client.modules,
      agent_management_enabled: release.client.agentManagementEnabled && eligible,
      agents: eligible ? release.client.agents : {},
      polling_interval_seconds: release.client.pollingIntervalSeconds,
      cache_max_age_seconds: release.client.cacheMaxAgeSeconds,
      generated_at: release.publishedAt,
      etag: `${release.id}:${release.hash.slice(0, 16)}:${eligible ? '1' : '0'}`
    }
  }

  function writeCredential({ provider, label = 'default', secret, actorId }) {
    if (!key) throw configError('ENCRYPTION_KEY_MISSING', '服务端未配置 SONG_CONTENT_MASTER_KEY')
    const normalizedProvider = clean(provider, 120)
    const normalizedLabel = clean(label, 120) || 'default'
    if (!normalizedProvider || typeof secret !== 'string' || !secret.trim()) {
      throw configError('INVALID_CREDENTIAL', '供应商和密钥不能为空')
    }
    const id = `${normalizedProvider}:${normalizedLabel}`
    const now = new Date().toISOString()
    statements.upsertCredential.run(
      id, normalizedProvider, normalizedLabel, encrypt(secret.trim(), key), 'v1', now, now, clean(actorId, 160)
    )
    return { id, provider: normalizedProvider, label: normalizedLabel, hasSecret: true, updatedAt: now }
  }

  function readCredential(reference) {
    if (!key) throw configError('ENCRYPTION_KEY_MISSING', '服务端未配置 SONG_CONTENT_MASTER_KEY')
    const id = clean(reference?.id, 260)
    const provider = clean(reference?.provider, 120)
    const label = clean(reference?.label, 120) || 'default'
    const row = statements.credential.get(id, provider, label)
    if (!row) return null
    return { id: row.id, provider: row.provider, label: row.label, secret: decrypt(row.encrypted_secret, key) }
  }

  function close() {
    databaseEngine.close()
    database.close()
  }

  return { close, createDraft, current, get, list, markValidated, publicConfiguration, publish, readCredential, writeCredential }
}

function installSongContentConfigRoutes({
  app,
  configStore,
  authMiddleware,
  authorize,
  publicAccessMiddleware,
  publicRateLimit,
  appAIConfigProvider,
  audit,
  logger = console
}) {
  const publicMiddleware = [publicRateLimit, publicAccessMiddleware].filter((value) => typeof value === 'function')
  app.get('/api/public/song-content-config', ...publicMiddleware, routeHandler(async (req, res) => {
    const payload = configStore.publicConfiguration({
      appVersion: req.query?.app_version,
      platform: req.query?.client_platform,
      region: req.query?.region,
      deviceId: req.query?.device_uuid
    })
    res.set('Cache-Control', `private, max-age=${payload.cache_max_age_seconds}, must-revalidate`)
    res.set('ETag', `"${payload.etag}"`)
    if (req.headers['if-none-match'] === `"${payload.etag}"`) return res.status(304).end()
    res.json(payload)
  }, logger))

  if (typeof authMiddleware !== 'function') return
  const permitted = (permission) => typeof authorize === 'function'
    ? authorize(permission)
    : (_req, _res, next) => next()

  app.get('/api/song-content/config', authMiddleware, permitted('content.read'), routeHandler(async (_req, res) => {
    res.json({ ok: true, current: configStore.current(), versions: configStore.list() })
  }, logger))

  app.post('/api/song-content/config/drafts', authMiddleware, permitted('config.manage'), routeHandler(async (req, res) => {
    const release = configStore.createDraft({ ai: req.body?.ai, client: req.body?.client, actorId: actor(req) })
    audit?.({ actorId: actor(req), action: 'config.draft.create', resourceType: 'config_version', resourceId: release.id })
    res.status(201).json({ ok: true, release })
  }, logger))

  app.post('/api/song-content/config/:versionId/validate', authMiddleware, permitted('config.manage'), routeHandler(async (req, res) => {
    const release = configStore.get(req.params.versionId)
    if (!release) throw configError('CONFIG_NOT_FOUND', '配置版本不存在')
    const validation = validateRelease(release, await resolveAppAIConfig(appAIConfigProvider))
    if (!validation.passed) return res.status(422).json({ ok: false, validation })
    const validated = configStore.markValidated(release.id, validation, actor(req))
    audit?.({ actorId: actor(req), action: 'config.validate', resourceType: 'config_version', resourceId: release.id, metadata: validation })
    res.json({ ok: true, release: validated, validation })
  }, logger))

  app.post('/api/song-content/app-ai/test', authMiddleware, permitted('config.manage'), routeHandler(async (req, res) => {
    const current = await resolveAppAIConfig(appAIConfigProvider)
    const source = req.body?.configuration || req.body || {}
    const configuration = normalizeAppAIConfig({
      ...current,
      ...source,
      enabled: req.body?.enabled ?? source.enabled ?? current.enabled,
      apiKey: req.body?.apiKey ?? source.apiKey ?? current.apiKey,
      usageLimits: req.body?.usageLimits ?? source.usageLimits ?? current.usageLimits
    }, current)
    const result = await testAppAIConfiguration(configuration)
    audit?.({ actorId: actor(req), action: 'app_ai.test', resourceType: 'ai_configuration', resourceId: configuration.revision || 'draft', metadata: { protocol: configuration.wireProtocol, model: configuration.model, latencyMs: result.latencyMs } })
    res.json({ ok: true, result })
  }, logger))

  app.post('/api/song-content/config/:versionId/publish', authMiddleware, permitted('config.publish'), routeHandler(async (req, res) => {
    requireConfirmation(req)
    const release = configStore.publish(req.params.versionId, actor(req))
    audit?.({ actorId: actor(req), action: 'config.publish', resourceType: 'config_version', resourceId: release.id })
    res.json({ ok: true, release })
  }, logger))

  app.post('/api/song-content/config/:versionId/rollback', authMiddleware, permitted('config.publish'), routeHandler(async (req, res) => {
    requireConfirmation(req)
    const release = configStore.publish(req.params.versionId, actor(req))
    audit?.({ actorId: actor(req), action: 'config.rollback', resourceType: 'config_version', resourceId: release.id })
    res.json({ ok: true, release })
  }, logger))

  app.put('/api/song-content/credentials', authMiddleware, permitted('credentials.write'), routeHandler(async (req, res) => {
    const credential = configStore.writeCredential({
      provider: req.body?.provider,
      label: req.body?.label,
      secret: req.body?.secret,
      actorId: actor(req)
    })
    audit?.({ actorId: actor(req), action: 'credential.rotate', resourceType: 'ai_credential', resourceId: credential.id })
    res.json({ ok: true, credential })
  }, logger))
}

function createConfiguredContentGenerator({ configStore, appAIConfigProvider, fetchImpl = globalThis.fetch }) {
  return async (context) => {
    const release = configStore.current()
    const ai = release.ai || {}
    const appAI = await resolveAppAIConfig(appAIConfigProvider)
    if (!appAI.enabled || !appAI.baseURL || !appAI.model) throw configError('AI_CONFIG_INCOMPLETE', 'App AI 配置未启用或不完整')
    const generatorOptions = {
      wireProtocol: appAI.wireProtocol,
      baseURL: appAI.baseURL,
      apiKey: appAI.apiKey,
      model: appAI.model,
      fetchImpl,
      timeoutMs: (appAI.timeout || ai.timeoutSeconds || 60) * 1_000,
      temperature: ai.temperature,
      maxOutputTokens: ai.maxOutputTokens,
      customHeaders: parseHeaders(appAI.customHeadersJSON),
      systemPromptText: ai.systemPrompt,
      contentPromptText: ai.contentPrompt
    }
    const input = { ...context, promptVersion: ai.promptVersion || context.promptVersion }
    try {
      const generated = await createAIProviderContentGenerator(generatorOptions)(input)
      return { ...generated, promptVersion: input.promptVersion }
    } catch (error) {
      if (!ai.fallbackModel || ai.fallbackModel === appAI.model || !error?.retryable) throw error
      const generated = await createAIProviderContentGenerator({ ...generatorOptions, model: ai.fallbackModel })(input)
      return { ...generated, promptVersion: input.promptVersion }
    }
  }
}

function normalizeAIConfig(raw = {}) {
  return {
    fallbackModel: clean(raw.fallbackModel, 240),
    promptVersion: clean(raw.promptVersion, 160) || 'song-editor-web-v6',
    schemaVersion: clean(raw.schemaVersion, 80) || '3',
    systemPrompt: clean(raw.systemPrompt, 20_000),
    contentPrompt: clean(raw.contentPrompt, 20_000),
    temperature: clamp(raw.temperature, 0, 2, 0.2),
    maxOutputTokens: Math.round(clamp(raw.maxOutputTokens, 256, 32_000, 4_000)),
    timeoutSeconds: clamp(raw.timeoutSeconds, 10, 180, 60),
    maxAttempts: Math.round(clamp(raw.maxAttempts, 1, 10, 3)),
    concurrency: Math.round(clamp(raw.concurrency, 1, 64, 2)),
    requestsPerMinute: Math.round(clamp(raw.requestsPerMinute, 1, 10_000, 60)),
    circuitBreakerFailures: Math.round(clamp(raw.circuitBreakerFailures, 1, 100, 5)),
    circuitBreakerRecoverySeconds: Math.round(clamp(raw.circuitBreakerRecoverySeconds, 15, 900, 60)),
    dailyBudget: clamp(raw.dailyBudget, 0, 1_000_000, 0),
    perTaskTokenLimit: Math.round(clamp(raw.perTaskTokenLimit, 256, 100_000, 20_000)),
    autoPublish: raw.autoPublish !== false,
    minimumSourceGrade: ['A', 'B', 'C'].includes(raw.minimumSourceGrade) ? raw.minimumSourceGrade : 'B',
    highRiskRequiresReview: raw.highRiskRequiresReview === true,
    sourceConflictRequiresReview: raw.sourceConflictRequiresReview === true,
    webRetrievalEnabled: raw.webRetrievalEnabled !== false,
    webMaximumSources: Math.round(clamp(raw.webMaximumSources, 1, 16, 10)),
    webSearchProviders: normalizeSearchProviders(raw.webSearchProviders),
    webPreferredSources: normalizePreferredSources(raw.webPreferredSources)
  }
}

function normalizeSearchProviders(value) {
  const supported = new Set(['360', 'baidu', 'bing', 'sogou'])
  const providers = Array.isArray(value) ? value.filter((provider) => supported.has(provider)) : [...supported]
  return [...new Set(providers)]
}

function normalizePreferredSources(value) {
  const supported = new Set(['douban', 'xiaohongshu'])
  const sources = Array.isArray(value) ? value.filter((source) => supported.has(source)) : [...supported]
  return [...new Set(sources)]
}

function normalizeClientConfig(raw = {}) {
  return {
    enabled: raw.enabled !== false,
    agentManagementEnabled: raw.agentManagementEnabled !== false,
    agents: normalizeAppAgents(raw.agents),
    modules: {
      songSummary: raw.modules?.songSummary !== false,
      creationStory: raw.modules?.creationStory !== false,
      background: raw.modules?.background !== false,
      albumSummary: raw.modules?.albumSummary !== false,
      sources: raw.modules?.sources !== false,
      similarSongs: raw.modules?.similarSongs !== false,
      artistSongs: raw.modules?.artistSongs !== false
    },
    pollingIntervalSeconds: Math.round(clamp(raw.pollingIntervalSeconds, 2, 30, 3)),
    cacheMaxAgeSeconds: Math.round(clamp(raw.cacheMaxAgeSeconds, 30, 86_400, 3_600)),
    rolloutPercentage: clamp(raw.rolloutPercentage, 0, 100, 100),
    minAppVersion: clean(raw.minAppVersion, 40),
    maxAppVersion: clean(raw.maxAppVersion, 40),
    platforms: normalizeList(raw.platforms, 20),
    regions: normalizeList(raw.regions, 100),
    deviceWhitelist: normalizeList(raw.deviceWhitelist, 10_000),
    effectiveAt: validISODate(raw.effectiveAt) ? new Date(raw.effectiveAt).toISOString() : null
  }
}

function normalizeAppAgents(raw = {}) {
  const defaults = {
    equalizer: ['mono-audio-agent-v27', 0.1, 4096, 120],
    listeningInsight: ['mono-listening-insight-v2', 0.1, 4096, 30],
    specialGreeting: ['special-greeting-v1', 0.7, 1024, 20],
    stageDirector: ['mono-stage-v3', 0.2, 4096, 60],
    wallpaperTranslator: ['wallpaper-translator-v1', 0.1, 512, 15]
  }
  return Object.fromEntries(Object.entries(defaults).map(([key, fallback]) => {
    const value = raw?.[key] || {}
    return [key, {
      enabled: value.enabled !== false,
      promptVersion: clean(value.promptVersion, 160) || fallback[0],
      systemPrompt: clean(value.systemPrompt, 40_000),
      secondarySystemPrompt: clean(value.secondarySystemPrompt, 40_000),
      userPromptTemplate: clean(value.userPromptTemplate, 20_000),
      temperature: clamp(value.temperature, 0, 2, fallback[1]),
      maxOutputTokens: Math.round(clamp(value.maxOutputTokens, 128, 32_000, fallback[2])),
      minimumTimeoutSeconds: clamp(value.minimumTimeoutSeconds, 0, 180, fallback[3])
    }]
  }))
}

function isEligible(config, context, version) {
  const deviceId = clean(context.deviceId, 200)
  if (config.deviceWhitelist.length > 0 && config.deviceWhitelist.includes(deviceId)) return true
  if (config.effectiveAt && Date.parse(config.effectiveAt) > Date.now()) return false
  if (config.platforms.length > 0 && !config.platforms.includes(clean(context.platform, 40))) return false
  if (config.regions.length > 0 && !config.regions.includes(clean(context.region, 20).toUpperCase())) return false
  if (config.minAppVersion && compareVersions(context.appVersion, config.minAppVersion) < 0) return false
  if (config.maxAppVersion && compareVersions(context.appVersion, config.maxAppVersion) > 0) return false
  if (config.rolloutPercentage >= 100) return true
  if (config.rolloutPercentage <= 0 || !deviceId) return false
  const bucket = crypto.createHash('sha256').update(`${version}:${deviceId}`).digest().readUInt16BE(0) / 655.36
  return bucket < config.rolloutPercentage
}

function defaultRelease() {
  const release = {
    id: 'bundled-default', version: 0, status: 'published', ai: normalizeAIConfig({ autoPublish: true }),
    client: normalizeClientConfig({ enabled: true, rolloutPercentage: 100 }),
    createdBy: null, createdAt: null, publishedBy: null, publishedAt: null,
    validation: null
  }
  release.hash = crypto.createHash('sha256').update(JSON.stringify({ ai: release.ai, client: release.client })).digest('hex')
  return release
}

function hydrate(row, latestValidation) {
  const release = {
    id: row.id,
    version: Number(row.version),
    status: row.status,
    ai: normalizeAIConfig(parseJSON(row.ai_config_json, {})),
    client: normalizeClientConfig(parseJSON(row.client_config_json, {})),
    createdBy: row.created_by || null,
    createdAt: row.created_at,
    publishedBy: row.published_by || null,
    publishedAt: row.published_at || null
  }
  release.hash = crypto.createHash('sha256').update(JSON.stringify({ ai: release.ai, client: release.client })).digest('hex')
  const validation = latestValidation?.get(release.id)
  release.validation = validation ? { ...parseJSON(validation.result_json, {}), passed: Boolean(validation.passed), validatedBy: validation.validated_by || null, validatedAt: validation.validated_at } : null
  return release
}

async function resolveAppAIConfig(provider) {
  if (typeof provider !== 'function') throw configError('APP_AI_CONFIG_UNAVAILABLE', '无法读取 App AI 配置')
  return normalizeAppAIConfig(await provider())
}

function normalizeAppAIConfig(raw = {}, fallback = {}) {
  const allowed = new Set(['appleIntelligence', 'openAIResponses', 'openAIChat', 'anthropicMessages', 'googleGemini', 'azureOpenAI', 'ollama', 'openAICompatible'])
  return {
    enabled: raw.enabled !== false,
    wireProtocol: allowed.has(raw.wireProtocol) ? raw.wireProtocol : (fallback.wireProtocol || 'openAICompatible'),
    baseURL: validHTTPURL(raw.baseURL) ? raw.baseURL : clean(fallback.baseURL, 2_048),
    model: clean(raw.model, 240) || clean(fallback.model, 240),
    modelDiscoveryURL: validHTTPURL(raw.modelDiscoveryURL) ? raw.modelDiscoveryURL : clean(fallback.modelDiscoveryURL, 2_048),
    timeout: clamp(raw.timeout, 10, 180, 60),
    customHeadersJSON: clean(raw.customHeadersJSON, 8_000),
    apiKey: typeof raw.apiKey === 'string' ? raw.apiKey.trim() : clean(fallback.apiKey, 8_000),
    usageLimits: raw.usageLimits || fallback.usageLimits || {},
    revision: clean(raw.revision, 160)
  }
}

function validateRelease(release, appAI) {
  const errors = []
  const warnings = []
  if (!appAI.enabled) errors.push('app_ai_disabled')
  if (appAI.wireProtocol !== 'appleIntelligence' && !appAI.baseURL) errors.push('app_ai_base_url_missing')
  if (!appAI.model) errors.push('app_ai_model_missing')
  if (appAI.wireProtocol === 'appleIntelligence') errors.push('apple_intelligence_not_available_for_server_jobs')
  if (release.client.rolloutPercentage === 100) warnings.push('full_rollout')
  if (!release.ai.systemPrompt) warnings.push('using_bundled_system_prompt')
  for (const [name, agent] of Object.entries(release.client.agents || {})) {
    if (agent.enabled && !agent.systemPrompt) warnings.push(`${name}_using_bundled_system_prompt`)
    if (agent.userPromptTemplate && !agent.userPromptTemplate.includes('{{input}}')) {
      warnings.push(`${name}_user_template_appends_input`)
    }
  }
  return { passed: errors.length === 0, errors, warnings, checkedAt: new Date().toISOString() }
}

async function testAppAIConfiguration(configuration, fetchImpl = globalThis.fetch) {
  if (!configuration.enabled) throw configError('AI_CONFIG_DISABLED', 'App AI 配置未启用')
  if (configuration.wireProtocol === 'appleIntelligence') throw configError('AI_PROTOCOL_SERVER_UNSUPPORTED', 'Apple Intelligence 无法由服务端测试')
  const target = configuration.modelDiscoveryURL || joinURL(configuration.baseURL, 'models')
  if (!validHTTPURL(target)) throw configError('AI_MODEL_DISCOVERY_URL_REQUIRED', '模型列表接口无效')
  const headers = parseHeaders(configuration.customHeadersJSON)
  if (configuration.apiKey) {
    if (configuration.wireProtocol === 'anthropicMessages') headers['x-api-key'] = configuration.apiKey
    else headers.Authorization = `Bearer ${configuration.apiKey}`
  }
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), configuration.timeout * 1_000)
  const started = Date.now()
  try {
    const response = await fetchImpl(target, { headers, signal: controller.signal })
    if (!response.ok) throw configError('AI_CONNECTION_FAILED', `模型接口返回 ${response.status}`)
    const payload = await response.json().catch(() => ({}))
    const models = extractModelNames(payload).slice(0, 100)
    return { protocol: configuration.wireProtocol, model: configuration.model, modelFound: models.length === 0 || models.includes(configuration.model), modelCount: models.length, latencyMs: Date.now() - started }
  } finally {
    clearTimeout(timer)
  }
}

function extractModelNames(payload) {
  const values = payload.data || payload.models || []
  return Array.isArray(values) ? values.map((item) => clean(item?.id || item?.name || item, 240)).filter(Boolean) : []
}

function parseHeaders(raw) {
  try {
    const value = typeof raw === 'string' && raw.trim() ? JSON.parse(raw) : {}
    return value && typeof value === 'object' && !Array.isArray(value) ? value : {}
  } catch (_) { return {} }
}

function joinURL(baseURL, suffix) { return new URL(String(suffix).replace(/^\/+/, ''), String(baseURL).endsWith('/') ? baseURL : `${baseURL}/`).toString() }
function validISODate(value) { return typeof value === 'string' && !Number.isNaN(Date.parse(value)) }

function encrypt(secret, key) {
  const iv = crypto.randomBytes(12)
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv)
  const ciphertext = Buffer.concat([cipher.update(secret, 'utf8'), cipher.final()])
  return ['v1', iv.toString('base64url'), cipher.getAuthTag().toString('base64url'), ciphertext.toString('base64url')].join('.')
}

function decrypt(payload, key) {
  const [version, iv, tag, ciphertext] = String(payload).split('.')
  if (version !== 'v1') throw configError('CREDENTIAL_VERSION_UNSUPPORTED', '不支持的密钥版本')
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, Buffer.from(iv, 'base64url'))
  decipher.setAuthTag(Buffer.from(tag, 'base64url'))
  return Buffer.concat([decipher.update(Buffer.from(ciphertext, 'base64url')), decipher.final()]).toString('utf8')
}

function routeHandler(handler, logger) {
  return async (req, res) => {
    try { await handler(req, res) }
    catch (error) {
      logger.error?.(`[song-content-config] ${error?.code || 'INTERNAL_ERROR'}`, error)
      res.status(error?.code === 'CONFIG_NOT_FOUND' ? 404 : 400).json({ error: error?.message || '配置操作失败', code: error?.code || 'INTERNAL_ERROR' })
    }
  }
}

function requireConfirmation(req) {
  if (req.body?.confirmed !== true) throw configError('CONFIRMATION_REQUIRED', '此操作需要二次确认')
}

function actor(req) { return clean(req.admin?.id || req.user?.id || req.headers?.['x-admin-actor'], 160) || 'token-admin' }
function normalizeList(value, maximum) { return Array.isArray(value) ? [...new Set(value.map((item) => clean(item, 200)).filter(Boolean))].slice(0, maximum) : [] }
function compareVersions(left, right) { const a = String(left || '0').split('.').map(Number); const b = String(right || '0').split('.').map(Number); for (let i = 0; i < Math.max(a.length, b.length); i += 1) { const diff = (a[i] || 0) - (b[i] || 0); if (diff) return diff }; return 0 }
function validHTTPURL(value) { try { return ['http:', 'https:'].includes(new URL(value).protocol) } catch (_) { return false } }
function clean(value, maximum) { return typeof value === 'string' ? value.trim().slice(0, maximum) : '' }
function clamp(value, minimum, maximum, fallback) { const number = Number(value); return Number.isFinite(number) ? Math.min(maximum, Math.max(minimum, number)) : fallback }
function parseJSON(value, fallback) { try { return JSON.parse(value) } catch (_) { return fallback } }
function configError(code, message) { const error = new Error(message); error.code = code; return error }

module.exports = {
  createConfiguredContentGenerator,
  createSongContentConfigStore,
  installSongContentConfigRoutes
}
