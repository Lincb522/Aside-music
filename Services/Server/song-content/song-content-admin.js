const crypto = require('node:crypto')
const { localizePipelineError } = require('./song-content-pipeline')

function installSongContentAdminRoutes({ app, service, authMiddleware, authorize, logger = console }) {
  if (!app || typeof app.get !== 'function') throw new TypeError('Express-compatible app is required')
  if (!service?.store) throw new TypeError('song-content service is required')
  if (typeof authMiddleware !== 'function') throw new TypeError('token admin authMiddleware is required')

  const store = service.store
  const permitted = (permission) => typeof authorize === 'function'
    ? authorize(permission)
    : (_req, _res, next) => next()
  const route = (permission, handler) => [
    authMiddleware,
    permitted(permission),
    adminHandler(handler, logger)
  ]

  app.get('/api/song-content/dashboard', ...route('content.read', async (_req, res) => {
    res.json({
      ok: true,
      stats: {
        ...store.dashboardStats(),
        providerCircuit: service.pipeline?.circuitState?.() || null
      }
    })
  }))

  app.get('/api/song-content/songs', ...route('content.read', async (req, res) => {
    res.json({
      ok: true,
      songs: store.listSongs({ query: req.query?.q, limit: req.query?.limit, offset: req.query?.offset })
    })
  }))

  app.put('/api/song-content/songs/:songId/whitelist', ...route('songs.manage', async (req, res) => {
    const actorId = actor(req)
    store.setWhitelist(req.params.songId, Boolean(req.body?.enabled), { note: req.body?.note, actorId })
    res.json({ ok: true, song: store.hydrateSong(req.params.songId), whitelisted: store.isWhitelisted(req.params.songId) })
  }))

  app.put('/api/song-content/songs/:songId/identity', ...route('songs.manage', async (req, res) => {
    const song = store.setSongIdentityStatus(req.params.songId, req.body?.status, actor(req))
    res.json({ ok: true, song })
  }))

  app.post('/api/song-content/mappings/:mappingId/repoint', ...route('songs.manage', async (req, res) => {
    requireConfirmation(req)
    const song = store.repointMapping(req.params.mappingId, cleanString(req.body?.targetSongId, 200), actor(req))
    res.json({ ok: true, song })
  }))

  app.post('/api/song-content/mappings/:mappingId/split', ...route('songs.manage', async (req, res) => {
    requireConfirmation(req)
    const song = store.splitMapping(req.params.mappingId, actor(req))
    res.status(201).json({ ok: true, song })
  }))

  app.post('/api/song-content/songs/:songId/merge', ...route('songs.manage', async (req, res) => {
    requireConfirmation(req)
    const result = store.mergeSongs(req.params.songId, cleanString(req.body?.targetSongId, 200), actor(req))
    res.json({ ok: true, ...result })
  }))

  app.post('/api/song-content/songs/:songId/regenerate', ...route('jobs.manage', async (req, res) => {
    const song = store.hydrateSong(req.params.songId)
    if (!song) throw adminError(404, 'SONG_NOT_FOUND', '歌曲不存在')
    const reason = cleanString(req.body?.reason, 160)
    if (!reason) throw adminError(400, 'REASON_REQUIRED', '请选择重新生成原因')
    const job = store.ensureGenerationJob({
      songId: song.id,
      locale: req.body?.locale || 'zh-CN',
      schemaVersion: req.body?.schemaVersion || '1',
      reason: `admin:${reason}`
    })
    store.appendAudit({
      actorId: actor(req),
      action: 'job.regenerate',
      resourceType: 'generation_job',
      resourceId: job.id,
      requestId: traceId(req),
      metadata: { reason }
    })
    res.status(202).json({ ok: true, job })
  }))

  app.get('/api/song-content/content', ...route('content.read', async (req, res) => {
    res.json({
      ok: true,
      content: store.listContentVersions({ status: req.query?.status, limit: req.query?.limit, offset: req.query?.offset })
    })
  }))

  app.get('/api/song-content/content/:versionId', ...route('content.read', async (req, res) => {
    const review = store.getContentReview(req.params.versionId)
    if (!review) throw adminError(404, 'CONTENT_VERSION_NOT_FOUND', '内容版本不存在')
    res.json({ ok: true, review })
  }))

  app.post('/api/song-content/content/:versionId/edit', ...route('content.edit', async (req, res) => {
    const version = store.createEditedContentVersion(req.params.versionId, normalizeEdit(req.body), actor(req))
    res.status(201).json({ ok: true, version })
  }))

  app.post('/api/song-content/content/:versionId/submit', ...route('content.edit', async (req, res) => {
    const version = store.setContentStatus(req.params.versionId, 'pending_review', actor(req), 'content.submit')
    res.json({ ok: true, version })
  }))

  app.post('/api/song-content/content/:versionId/publish', ...route('content.publish', async (req, res) => {
    requireConfirmation(req)
    const version = store.publishContentVersion(req.params.versionId, actor(req))
    res.json({ ok: true, version })
  }))

  app.post('/api/song-content/content/:versionId/rollback', ...route('content.rollback', async (req, res) => {
    requireConfirmation(req)
    const version = store.rollbackContentVersion(req.params.versionId, actor(req))
    res.json({ ok: true, version })
  }))

  app.post('/api/song-content/content/:versionId/offline', ...route('content.offline', async (req, res) => {
    requireConfirmation(req)
    const version = store.setContentStatus(req.params.versionId, 'offline', actor(req), 'content.offline')
    res.json({ ok: true, version })
  }))

  app.post('/api/song-content/content/:versionId/reject', ...route('content.publish', async (req, res) => {
    const version = store.setContentStatus(req.params.versionId, 'rejected', actor(req), 'content.reject')
    res.json({ ok: true, version })
  }))

  app.get('/api/song-content/jobs', ...route('content.read', async (req, res) => {
    const jobs = store.listJobs({ state: req.query?.state, limit: req.query?.limit, offset: req.query?.offset })
      .map(adminJob)
    res.json({ ok: true, jobs })
  }))

  app.post('/api/song-content/jobs/:jobId/retry', ...route('jobs.manage', async (req, res) => {
    const job = store.retryJob(req.params.jobId, actor(req))
    res.status(202).json({ ok: true, job })
  }))

  app.get('/api/song-content/sources', ...route('content.read', async (req, res) => {
    res.json({ ok: true, sources: store.listSources({ grade: req.query?.grade, limit: req.query?.limit, offset: req.query?.offset }) })
  }))

  app.put('/api/song-content/sources/:sourceId', ...route('sources.manage', async (req, res) => {
    const source = store.updateSource(req.params.sourceId, { grade: req.body?.grade, accessible: req.body?.accessible }, actor(req))
    res.json({ ok: true, source })
  }))

  app.get('/api/song-content/access', ...route('audit.read', async (_req, res) => {
    res.json({ ok: true, roles: store.listRoles(), assignments: store.listRoleAssignments() })
  }))

  app.put('/api/song-content/access/:actorId', ...route('roles.manage', async (req, res) => {
    requireConfirmation(req)
    store.assignRole(req.params.actorId, req.body?.roleId, actor(req))
    res.json({ ok: true, actorId: req.params.actorId, permissions: store.actorPermissions(req.params.actorId) })
  }))

  app.get('/api/song-content/audit', ...route('audit.read', async (req, res) => {
    res.json({ ok: true, logs: store.listAuditLogs({ limit: req.query?.limit, offset: req.query?.offset }) })
  }))
}

function adminJob(job) {
  if (!job?.errorCode) return { ...job, errorTitle: null, errorDetail: null }
  const localized = localizePipelineError(job.errorCode, job.errorMessage)
  return {
    ...job,
    internalErrorCode: job.errorCode,
    errorCode: null,
    errorMessage: localized.detail,
    errorTitle: localized.title,
    errorDetail: localized.detail
  }
}

function adminHandler(handler, logger) {
  return async (req, res) => {
    try {
      await handler(req, res)
    } catch (error) {
      const status = Number(error?.status) || mapStatus(error?.code)
      const requestId = traceId(req)
      logger.error?.(`[song-content-admin] ${requestId} ${error?.code || 'INTERNAL_ERROR'}`, error)
      res.status(status).json({
        error: error?.message || '操作失败',
        code: error?.code || 'INTERNAL_ERROR',
        requestId
      })
    }
  }
}

function normalizeEdit(body = {}) {
  return {
    songSummary: body.songSummary,
    creationStory: body.creationStory,
    background: body.background,
    albumSummary: body.albumSummary,
    sourceRefs: body.sourceRefs
  }
}

function requireConfirmation(req) {
  if (req.body?.confirmed !== true) {
    throw adminError(400, 'CONFIRMATION_REQUIRED', '此操作需要二次确认')
  }
}

function actor(req) {
  return cleanString(req.admin?.id || req.user?.id || req.auth?.id || req.headers?.['x-admin-actor'], 160) || 'token-admin'
}

function traceId(req) {
  return cleanString(req.headers?.['x-request-id'], 128) || crypto.randomUUID()
}

function cleanString(value, maxLength) {
  return typeof value === 'string' ? value.trim().slice(0, maxLength) : ''
}

function mapStatus(code) {
  if (String(code || '').includes('NOT_FOUND')) return 404
  if (String(code || '').startsWith('INVALID_')) return 400
  return 500
}

function adminError(status, code, message) {
  const error = new Error(message)
  error.status = status
  error.code = code
  return error
}

module.exports = { installSongContentAdminRoutes }
