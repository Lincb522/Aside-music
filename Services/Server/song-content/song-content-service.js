const crypto = require('node:crypto')
const { createSongContentStore, codedError } = require('./song-content-store')
const { createSongContentPipeline } = require('./song-content-pipeline')

function createSongContentService({
  directory,
  databasePath,
  platformResolver,
  sourceCollector,
  contentGenerator,
  schemaVersion = '3',
  promptVersion = 'song-editor-web-v6',
  autoPublish = true,
  policyProvider,
  startWorker = true,
  logger = console
}) {
  if (typeof platformResolver !== 'function') throw new TypeError('platformResolver(identity) is required')
  const store = createSongContentStore({ directory, databasePath, logger })
  const pipeline = createSongContentPipeline({
    store,
    sourceCollector,
    contentGenerator,
    schemaVersion,
    promptVersion,
    autoPublish,
    policyProvider,
    logger
  })
  const stopWorker = startWorker ? pipeline.start() : () => {}

  async function resolveSong(identity, requestContext = {}) {
    const normalized = normalizeIdentity(identity)
    let song = store.resolveMapping(normalized.platform, normalized.platformSongId)
    if (song) return song
    const metadata = await platformResolver({ ...normalized, requestContext })
      || normalizeClientSongSnapshot(requestContext.song, normalized)
    if (!metadata) throw codedError('SONG_NOT_FOUND', 'platform song could not be resolved')
    song = store.upsertResolvedSong(normalized, metadata)
    return song
  }

  async function getPublicDetail(identity, locale, requestContext = {}) {
    const song = await resolveSong(identity, requestContext)
    const normalizedLocale = normalizeLocale(locale)
    const published = store.getPublishedDetail(song.id, normalizedLocale)
    if (published) {
      return publicPublishedPayload(published, null)
    }

    let job = null
    if (song.identityStatus === 'confirmed' && store.isWhitelisted(song.id)) {
      const policy = typeof policyProvider === 'function' ? await policyProvider() : {}
      job = store.ensureGenerationJob({
        songId: song.id,
        locale: normalizedLocale,
        schemaVersion,
        reason: 'first_access',
        maxAttempts: policy?.maxAttempts
      })
    }
    return {
      song: publicSong(song),
      content: null,
      generation: job ? publicGeneration(job) : null,
      sources: [],
      cache: { etag: null, max_age: 30 }
    }
  }

  async function ensureContent(identity, locale, requestContext = {}) {
    const song = await resolveSong(identity, requestContext)
    if (song.identityStatus !== 'confirmed') throw codedError('SONG_IDENTITY_PENDING', 'song identity is not confirmed')
    if (!store.isWhitelisted(song.id)) throw codedError('SONG_NOT_WHITELISTED', 'song is outside the internal whitelist')
    const published = store.getPublishedDetail(song.id, normalizeLocale(locale))
    if (published) {
      return { song: publicSong(song), content: publicContent(published.content), generation: null }
    }
    const policy = typeof policyProvider === 'function' ? await policyProvider() : {}
    const job = store.ensureGenerationJob({
      songId: song.id,
      locale,
      schemaVersion,
      reason: 'first_access',
      maxAttempts: policy?.maxAttempts
    })
    return {
      song: publicSong(song),
      content: null,
      generation: job?.isActive ? publicGeneration(job) : null
    }
  }

  function getPublicJob(jobId) {
    const job = store.getJob(jobId)
    if (!job) return null
    return publicGeneration(job)
  }

  function close() {
    stopWorker()
    store.close()
  }

  return {
    close,
    ensureContent,
    getPublicDetail,
    getPublicJob,
    pipeline,
    resolveSong,
    store
  }
}

function installSongContentRoutes({
  app,
  service,
  publicAccessMiddleware,
  publicRateLimit,
  logger = console
}) {
  if (!app || typeof app.get !== 'function') throw new TypeError('Express-compatible app is required')
  if (!service) throw new TypeError('song-content service is required')
  const middleware = [publicRateLimit, publicAccessMiddleware].filter((value) => typeof value === 'function')

  app.get('/api/public/song-content', ...middleware, asyncHandler(async (req, res) => {
    const requestId = requestTraceId(req)
    const identity = requestIdentity(req)
    const payload = await service.getPublicDetail(identity, req.query?.locale, { req, requestId })
    setPublicHeaders(res, payload, requestId)
    if (payload.cache?.etag && req.headers['if-none-match'] === `"${payload.cache.etag}"`) {
      return res.status(304).end()
    }
    res.json(payload)
  }, logger))

  app.post('/api/public/song-content/ensure', ...middleware, asyncHandler(async (req, res) => {
    const requestId = requestTraceId(req)
    const identity = requestIdentity(req)
    const payload = await service.ensureContent(identity, req.body?.locale || req.query?.locale, {
      req,
      requestId,
      song: req.body?.song
    })
    res.set('Cache-Control', 'no-store')
    res.set('X-Request-ID', requestId)
    res.status(payload.generation ? 202 : 200).json(payload)
  }, logger))

  app.get('/api/public/song-content/jobs/:jobId', ...middleware, asyncHandler(async (req, res) => {
    const requestId = requestTraceId(req)
    const generation = service.getPublicJob(req.params.jobId)
    if (!generation) return sendError(res, 404, 'JOB_NOT_FOUND', 'generation job not found', requestId)
    res.set('Cache-Control', 'private, max-age=2, must-revalidate')
    res.set('X-Request-ID', requestId)
    res.json({ generation })
  }, logger))
}

function asyncHandler(handler, logger) {
  return async (req, res) => {
    const requestId = requestTraceId(req)
    try {
      await handler(req, res)
    } catch (error) {
      const response = errorResponse(error)
      logger.error?.(`[song-content] ${requestId} ${response.code}`, error)
      sendError(res, response.status, response.code, response.message, requestId, response.retryAfterSeconds)
    }
  }
}

function errorResponse(error) {
  const code = String(error?.code || 'INTERNAL_ERROR')
  const map = {
    INVALID_SONG_IDENTITY: [400, 'invalid song identity'],
    SONG_NOT_FOUND: [404, 'song not found'],
    SONG_IDENTITY_PENDING: [409, 'song identity is pending'],
    SONG_NOT_WHITELISTED: [404, 'content is not available'],
    RATE_LIMITED: [429, 'request rate limited']
  }
  const [status, message] = map[code] || [503, 'song content service unavailable']
  return { status, code, message, retryAfterSeconds: Number(error?.retryAfterSeconds) || null }
}

function sendError(res, status, code, message, requestId, retryAfterSeconds) {
  res.set('Cache-Control', 'no-store')
  res.set('X-Request-ID', requestId)
  if (retryAfterSeconds) res.set('Retry-After', String(retryAfterSeconds))
  return res.status(status).json({ error: { code, message, request_id: requestId } })
}

function requestIdentity(req) {
  return normalizeIdentity({
    platform: req.query?.platform || req.body?.platform,
    platformSongId: req.query?.song_id || req.body?.song_id
  })
}

function normalizeIdentity(identity) {
  const platform = String(identity?.platform || '').trim().toUpperCase().slice(0, 32)
  const platformSongId = String(identity?.platformSongId || identity?.songId || '').trim().slice(0, 256)
  if (!platform || !platformSongId) throw codedError('INVALID_SONG_IDENTITY', 'platform and song_id are required')
  return { platform, platformSongId }
}

function normalizeClientSongSnapshot(raw, identity) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null
  const title = cleanText(raw.title, 500)
  const artists = Array.isArray(raw.artists)
    ? raw.artists.map((artist) => ({
        id: cleanText(artist?.id, 256),
        name: cleanText(artist?.name, 300)
      })).filter((artist) => artist.name)
    : []
  if (!title || artists.length === 0) return null

  const albumName = cleanText(raw.album?.name, 500)
  const albumId = cleanText(raw.album?.id, 256)
  const duration = Number(raw.duration_ms ?? raw.durationMs)
  const coverURL = safeHTTPURL(raw.cover_url ?? raw.coverURL ?? raw.coverUrl)
  const isrc = cleanText(raw.isrc, 64)

  return {
    title,
    artists,
    album: albumName ? { id: albumId, name: albumName } : null,
    durationMs: Number.isFinite(duration) && duration > 0 ? Math.round(duration) : null,
    releaseDate: normalizeReleaseDate(raw.release_date ?? raw.releaseDate),
    isrc,
    versionLabel: cleanText(raw.version_label ?? raw.versionLabel, 120) || 'original',
    coverUrl: coverURL,
    identityStatus: 'confirmed',
    platformArtistId: cleanText(raw.platform_artist_id ?? raw.platformArtistId, 256) || artists[0]?.id,
    platformAlbumId: cleanText(raw.platform_album_id ?? raw.platformAlbumId, 256) || albumId,
    matchMethod: 'strict_metadata',
    matchConfidence: 1,
    verifiedBy: 'authenticated_app_snapshot',
    rawMetadata: {
      platform: identity.platform,
      platformSongId: identity.platformSongId,
      snapshot: raw
    }
  }
}

function normalizeReleaseDate(raw) {
  if (!raw) return null
  const value = cleanText(typeof raw === 'string' ? raw : raw.value, 32)
  if (!value || !/^\d{4}(?:-\d{2})?(?:-\d{2})?$/.test(value)) return null
  const inferredPrecision = value.length === 4 ? 'year' : (value.length === 7 ? 'month' : 'day')
  const precision = ['year', 'month', 'day'].includes(raw?.precision) ? raw.precision : inferredPrecision
  return { value, precision }
}

function safeHTTPURL(raw) {
  try {
    const url = new URL(String(raw || '').trim())
    return ['http:', 'https:'].includes(url.protocol) ? url.toString() : null
  } catch (_) {
    return null
  }
}

function cleanText(value, maxLength) {
  if (value === null || value === undefined) return null
  const normalized = String(value).trim()
  return normalized ? normalized.slice(0, maxLength) : null
}

function publicPublishedPayload(detail, generation = null) {
  const content = publicContent(detail.content)
  return {
    song: publicSong(detail.song),
    content,
    generation: generation?.isActive ? publicGeneration(generation) : null,
    sources: detail.sources.map(publicSource),
    cache: {
      etag: generation?.isActive ? `${content.version}:${generation.id}` : content.version,
      max_age: generation?.isActive ? 2 : 3_600
    }
  }
}

function publicSong(song) {
  return {
    id: song.id,
    title: song.title,
    artists: song.artists,
    album: song.album,
    duration_ms: song.durationMs,
    release_date: song.releaseDate,
    cover_url: song.coverUrl,
    platform_mappings: song.platformMappings.map((mapping) => ({
      platform: mapping.platform,
      song_id: mapping.songId
    }))
  }
}

function publicContent(content) {
  const grades = content.sources.map((source) => source.grade).filter(Boolean)
  const albumFallback = content.albumSummary || null
  const creationStory = content.creationStory || albumFallback
  const background = content.background || null
  const songSummary = content.songSummary || creationStory || albumFallback
  const sourceRefs = {
    ...(content.sourceRefs || {}),
    songSummary: content.songSummary
      ? (content.sourceRefs?.songSummary || [])
      : (content.creationStory
          ? (content.sourceRefs?.creationStory || [])
          : (content.sourceRefs?.albumSummary || [])),
    creationStory: content.creationStory
      ? (content.sourceRefs?.creationStory || [])
      : (content.sourceRefs?.albumSummary || []),
    background: content.background
      ? (content.sourceRefs?.background || [])
      : []
  }
  return {
    status: 'published',
    version: content.id,
    song_summary: songSummary,
    creation_story: creationStory,
    background,
    album_summary: content.albumSummary,
    updated_at: content.updatedAt,
    source_summary: {
      count: content.sources.length,
      highest_grade: highestGrade(grades)
    },
    source_refs: sourceRefs,
    confidence: content.confidence,
    risk_flags: content.riskFlags
  }
}

function publicSource(source) {
  return {
    id: source.id,
    title: source.title,
    publisher: source.publisher,
    url: source.url,
    published_at: source.publishedAt,
    grade: source.grade
  }
}

function publicGeneration(job) {
  const status = ['completed'].includes(job.state)
    ? 'completed'
    : (job.state === 'failed' ? 'failed' : (job.state === 'review' ? 'pending_review' : 'generating'))
  return {
    id: job.id,
    status,
    retry_after_seconds: status === 'generating' ? 3 : null,
    error_code: job.errorCode || null
  }
}

function setPublicHeaders(res, payload, requestId) {
  const maxAge = payload.cache?.max_age || 30
  res.set('Cache-Control', `private, max-age=${maxAge}, must-revalidate`)
  res.set('X-Request-ID', requestId)
  if (payload.cache?.etag) res.set('ETag', `"${payload.cache.etag}"`)
}

function requestTraceId(req) {
  const supplied = String(req.headers?.['x-request-id'] || '').trim()
  return supplied && supplied.length <= 128 ? supplied : crypto.randomUUID()
}

function highestGrade(grades) {
  return ['A', 'B', 'C', 'D'].find((grade) => grades.includes(grade)) || null
}

function normalizeLocale(value) {
  return String(value || 'zh-CN').trim().replace('_', '-').slice(0, 32) || 'zh-CN'
}

module.exports = { createSongContentService, installSongContentRoutes }
