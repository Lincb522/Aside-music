const crypto = require('node:crypto')
const fs = require('node:fs')
const path = require('node:path')
const { createSongContentDatabaseEngine } = require('./song-content-database-engine')

const ACTIVE_JOB_STATES = new Set(['queued', 'collecting', 'generating', 'validating', 'review'])
const TERMINAL_JOB_STATES = new Set(['completed', 'failed'])

function createSongContentStore({ directory, databasePath, logger = console }) {
  const { DatabaseSync } = require('node:sqlite')
  const resolvedDirectory = path.resolve(directory || path.dirname(databasePath || '.'))
  fs.mkdirSync(resolvedDirectory, { recursive: true })
  const resolvedDatabasePath = databasePath || path.join(resolvedDirectory, 'song-content.sqlite')
  const database = new DatabaseSync(resolvedDatabasePath)
  database.exec('PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL; PRAGMA busy_timeout = 5000;')
  const databaseEngine = createSongContentDatabaseEngine({
    database,
    databasePath: resolvedDatabasePath,
    migrationsDirectory: path.join(__dirname, 'migrations'),
    logger
  })

  const statements = prepareStatements(database)

  function transaction(operation) {
    database.exec('BEGIN IMMEDIATE')
    try {
      const result = operation()
      database.exec('COMMIT')
      return result
    } catch (error) {
      try { database.exec('ROLLBACK') } catch (_) {}
      throw error
    }
  }

  function resolveMapping(platform, platformSongId) {
    const row = statements.selectMapping.get(normalizePlatform(platform), cleanId(platformSongId))
    return row ? hydrateSong(row.song_id) : null
  }

  function upsertResolvedSong(identity, metadata) {
    const platform = normalizePlatform(identity?.platform)
    const platformSongId = cleanId(identity?.platformSongId || identity?.songId)
    if (!platform || !platformSongId) throw codedError('INVALID_SONG_IDENTITY', 'platform and song ID are required')

    const existing = statements.selectMapping.get(platform, platformSongId)
    if (existing) return hydrateSong(existing.song_id)

    const normalized = normalizeSongMetadata(metadata)
    if (!normalized.title || normalized.artists.length === 0) {
      throw codedError('SONG_IDENTITY_PENDING', 'trusted title and artist metadata are required')
    }

    return transaction(() => {
      const raced = statements.selectMapping.get(platform, platformSongId)
      if (raced) return hydrateSong(raced.song_id)

      const now = new Date().toISOString()
      const requestedCanonicalId = cleanId(metadata?.canonicalSongId)
      const canonicalExists = requestedCanonicalId && statements.selectSong.get(requestedCanonicalId)
      const songId = canonicalExists ? requestedCanonicalId : crypto.randomUUID()

      if (!canonicalExists) {
        statements.insertSong.run(
          songId,
          normalized.title,
          normalizeComparable(normalized.title),
          normalized.artists[0].id || null,
          normalized.artists[0].name,
          JSON.stringify(normalized.artists),
          normalized.album?.id || null,
          normalized.album?.name || null,
          normalized.durationMs,
          normalized.releaseDate?.value || null,
          normalized.releaseDate?.precision || null,
          normalized.isrc,
          normalized.versionLabel,
          normalized.coverUrl,
          normalized.identityStatus,
          now,
          now
        )
      }

      statements.insertMapping.run(
        crypto.randomUUID(),
        songId,
        platform,
        platformSongId,
        cleanOptional(metadata?.platformArtistId),
        cleanOptional(metadata?.platformAlbumId),
        normalized.title,
        normalized.artists.map((artist) => artist.name).join(' / '),
        normalized.album?.name || null,
        JSON.stringify(metadata?.rawMetadata || metadata || {}),
        normalizeMatchMethod(metadata?.matchMethod),
        clamp(Number(metadata?.matchConfidence), 0, 1, normalized.identityStatus === 'confirmed' ? 1 : 0.5),
        cleanOptional(metadata?.verifiedBy),
        now,
        now
      )
      return hydrateSong(songId)
    })
  }

  function hydrateSong(songId) {
    const row = statements.selectSong.get(songId)
    if (!row) return null
    const mappings = statements.selectMappings.all(songId).map((mapping) => ({
      id: mapping.id,
      platform: mapping.platform,
      songId: mapping.platform_song_id,
      artistId: mapping.platform_artist_id || null,
      albumId: mapping.platform_album_id || null,
      rawTitle: mapping.raw_title,
      rawArtist: mapping.raw_artist,
      rawAlbum: mapping.raw_album || null,
      matchMethod: mapping.match_method,
      matchConfidence: Number(mapping.match_confidence),
      verifiedBy: mapping.verified_by || null,
      updatedAt: mapping.updated_at
    }))
    return {
      id: row.id,
      title: row.title,
      artists: parseJSON(row.artists_json, [{ id: row.primary_artist_id, name: row.primary_artist_name }]),
      album: row.album_name ? { id: row.album_id, name: row.album_name } : null,
      durationMs: nullableNumber(row.duration_ms),
      releaseDate: row.release_date_value
        ? { value: row.release_date_value, precision: row.release_date_precision || null }
        : null,
      isrc: row.isrc || null,
      versionLabel: row.version_label || null,
      coverUrl: row.cover_url || null,
      identityStatus: row.identity_status,
      platformMappings: mappings
    }
  }

  function setWhitelist(songId, enabled, { note = null, actorId = null } = {}) {
    const now = new Date().toISOString()
    statements.upsertWhitelist.run(songId, enabled ? 1 : 0, cleanOptional(note), cleanOptional(actorId), now, now)
    appendAudit({ actorId, action: enabled ? 'whitelist.enable' : 'whitelist.disable', resourceType: 'song', resourceId: songId })
  }

  function isWhitelisted(songId) {
    const override = statements.selectWhitelist.get(songId)
    return override ? Boolean(override.enabled) : true
  }

  function getPublishedDetail(songId, locale) {
    const row = statements.selectPublished.get(songId, normalizeLocale(locale))
    if (!row) return null
    const version = hydrateContentVersion(row.id)
    return version ? { song: hydrateSong(songId), content: version, sources: version.sources } : null
  }

  function hydrateContentVersion(versionId) {
    const row = statements.selectContentVersion.get(versionId)
    if (!row) return null
    const sources = statements.selectVersionSources.all(versionId).map(hydrateSourceRow)
    return {
      id: row.id,
      songId: row.song_id,
      locale: row.locale,
      schemaVersion: row.schema_version,
      songSummary: row.song_summary || null,
      creationStory: row.creation_story || null,
      background: row.background || null,
      albumSummary: row.album_summary || null,
      sourceRefs: parseJSON(row.source_refs_json, {}),
      confidence: row.confidence,
      riskFlags: parseJSON(row.risk_flags_json, []),
      validation: parseJSON(row.validation_json, {}),
      status: row.status,
      modelProvider: row.model_provider || null,
      modelName: row.model_name || null,
      promptVersion: row.prompt_version || null,
      generatedAt: row.generated_at,
      publishedAt: row.published_at || null,
      publishedBy: row.published_by || null,
      supersedesId: row.supersedes_id || null,
      updatedAt: row.updated_at,
      sources
    }
  }

  function findContentHashOnOtherSong(contentHash, songId) {
    return statements.selectOtherSongContentHash.get(contentHash, songId) || null
  }

  function ensureGenerationJob({ songId, locale, schemaVersion, reason = 'first_access', maxAttempts = 3 }) {
    const normalizedLocale = normalizeLocale(locale)
    const normalizedSchema = cleanId(schemaVersion) || '1'
    const key = `${songId}:${normalizedSchema}:${normalizedLocale}`
    return transaction(() => {
      const existing = statements.selectActiveJob.get(key)
      if (existing) return hydrateJob(existing)

      const published = statements.selectPublished.get(songId, normalizedLocale)
      if (published && reason === 'first_access') return null

      const latest = statements.selectLatestJobByKey.get(key)
      if (reason === 'first_access' && (latest?.state === 'failed' || latest?.state === 'completed')) {
        return hydrateJob(latest)
      }
      if (reason === 'content_upgrade' && latest?.reason === 'content_upgrade') {
        return hydrateJob(latest)
      }

      const id = crypto.randomUUID()
      const now = new Date().toISOString()
      try {
        statements.insertJob.run(
          id, key, songId, normalizedLocale, normalizedSchema, reason,
          Math.max(1, Math.min(10, Number(maxAttempts) || 3)), now, now, now
        )
      } catch (error) {
        if (!String(error?.message || '').includes('UNIQUE')) throw error
        const raced = statements.selectActiveJob.get(key)
        if (raced) return hydrateJob(raced)
        throw error
      }
      return hydrateJob(statements.selectJob.get(id))
    })
  }

  function getJob(jobId) {
    const row = statements.selectJob.get(cleanId(jobId))
    return row ? hydrateJob(row) : null
  }

  function leaseNextJob(workerId, leaseSeconds = 120) {
    const owner = cleanId(workerId)
    if (!owner) throw codedError('INVALID_WORKER', 'worker ID is required')
    return transaction(() => {
      const now = new Date()
      const nowISO = now.toISOString()
      const row = statements.selectClaimableJob.get(nowISO, nowISO)
      if (!row) return null
      const leaseExpiry = new Date(now.getTime() + clamp(leaseSeconds, 15, 900, 120) * 1000).toISOString()
      const result = statements.claimJob.run(owner, leaseExpiry, nowISO, nowISO, row.id, nowISO, nowISO)
      if (result.changes !== 1) return null
      return hydrateJob(statements.selectJob.get(row.id))
    })
  }

  function transitionJob(jobId, state, patch = {}) {
    const allowed = new Set(['collecting', 'generating', 'validating', 'review', 'completed', 'failed', 'queued'])
    if (!allowed.has(state)) throw codedError('INVALID_JOB_STATE', `unsupported job state: ${state}`)
    const current = statements.selectJob.get(jobId)
    if (!current) throw codedError('JOB_NOT_FOUND', 'generation job not found')
    const now = new Date().toISOString()
    const terminal = TERMINAL_JOB_STATES.has(state)
    const leaseOwner = state === 'queued' || terminal || state === 'review' ? null : (patch.leaseOwner || current.lease_owner)
    const leaseExpiresAt = state === 'queued' || terminal || state === 'review' ? null : (patch.leaseExpiresAt || current.lease_expires_at)
    statements.updateJob.run(
      state,
      patch.availableAt || current.available_at,
      leaseOwner,
      leaseExpiresAt,
      cleanOptional(patch.errorCode),
      cleanOptional(patch.errorMessage)?.slice(0, 2_000) || null,
      nullableNumber(patch.tokenInput ?? current.token_input),
      nullableNumber(patch.tokenOutput ?? current.token_output),
      nullableNumber(patch.cost ?? current.cost),
      cleanOptional(patch.providerRequestId ?? current.provider_request_id),
      cleanOptional(patch.resultContentVersionId ?? current.result_content_version_id),
      now,
      patch.startedAt || current.started_at,
      terminal || state === 'review' ? now : null,
      jobId
    )
    return getJob(jobId)
  }

  function requeueJob(jobId, { errorCode, errorMessage, delaySeconds }) {
    const job = getJob(jobId)
    if (!job) throw codedError('JOB_NOT_FOUND', 'generation job not found')
    if (job.attemptCount >= job.maxAttempts) {
      return transitionJob(jobId, 'failed', { errorCode, errorMessage })
    }
    const availableAt = new Date(Date.now() + clamp(delaySeconds, 1, 86_400, 30) * 1000).toISOString()
    return transitionJob(jobId, 'queued', { availableAt, errorCode, errorMessage })
  }

  // Provider quota exhaustion is a scheduling delay, not a failed generation
  // attempt. Return the job to the queue without consuming its retry budget.
  function deferJob(jobId, { errorCode, errorMessage, delaySeconds }) {
    const job = getJob(jobId)
    if (!job) throw codedError('JOB_NOT_FOUND', 'generation job not found')
    const now = new Date().toISOString()
    const availableAt = new Date(
      Date.now() + clamp(delaySeconds, 1, 86_400, 300) * 1_000
    ).toISOString()
    statements.deferJob.run(
      availableAt,
      cleanOptional(errorCode),
      cleanOptional(errorMessage)?.slice(0, 2_000) || null,
      now,
      jobId
    )
    return getJob(jobId)
  }

  function saveEvidence(jobId, sources) {
    return transaction(() => sources.map((source) => {
      const normalized = normalizeSource(source)
      const existing = statements.selectSourceByFingerprint.get(normalized.canonicalUrl, normalized.contentHash)
      const id = existing?.id || crypto.randomUUID()
      if (!existing) {
        statements.insertSource.run(
          id, normalized.url, normalized.canonicalUrl, normalized.title, normalized.publisher,
          normalized.publishedAt, normalized.fetchedAt, normalized.grade, normalized.excerpt,
          normalized.contentHash, normalized.accessible ? 1 : 0, JSON.stringify(normalized.metadata)
        )
      } else {
        statements.refreshSourceEvidence.run(
          normalized.title,
          normalized.publisher,
          normalized.publishedAt,
          normalized.fetchedAt,
          normalized.excerpt,
          JSON.stringify(normalized.metadata),
          id
        )
      }
      statements.linkJobSource.run(jobId, id)
      return hydrateSourceRow(statements.selectSourceById.get(id))
    }))
  }

  function getJobSources(jobId) {
    return statements.selectJobSources.all(jobId).map(hydrateSourceRow)
  }

  function recentProviderRequestTimes(since = new Date(Date.now() - 86_400_000).toISOString()) {
    return statements.selectRecentProviderRequests.all(since)
      .map((row) => Date.parse(row.requested_at))
      .filter(Number.isFinite)
      .sort((left, right) => left - right)
  }

  function insertContentVersion({ jobId, songId, locale, schemaVersion, content, validation, generation }) {
    return transaction(() => {
      const id = crypto.randomUUID()
      const now = new Date().toISOString()
      const previous = statements.selectLatestVersion.get(songId, normalizeLocale(locale))
      statements.insertContentVersion.run(
        id, songId, normalizeLocale(locale), cleanId(schemaVersion) || '1',
        cleanContent(content.songSummary), cleanContent(content.creationStory), cleanContent(content.background),
        cleanContent(content.albumSummary), JSON.stringify(content.sourceRefs || {}), content.confidence,
        JSON.stringify(content.riskFlags || []), JSON.stringify(validation || {}), generation.status,
        cleanOptional(generation.modelProvider), cleanOptional(generation.modelName), cleanOptional(generation.promptVersion),
        generation.contentHash, now, previous?.id || null, now, now
      )
      const sourcesById = new Map(getJobSources(jobId).map((source) => [source.id, source]))
      const supportedFields = new Map()
      for (const [field, sourceIds] of Object.entries(content.sourceRefs || {})) {
        for (const sourceId of sourceIds) {
          if (!sourcesById.has(sourceId)) continue
          const fields = supportedFields.get(sourceId) || []
          fields.push(field)
          supportedFields.set(sourceId, fields)
        }
      }
      for (const [sourceId, fields] of supportedFields) {
        statements.linkVersionSource.run(id, sourceId, JSON.stringify([...new Set(fields)]))
      }
      return hydrateContentVersion(id)
    })
  }

  function publishContentVersion(versionId, actorId = 'automatic-policy') {
    return transaction(() => {
      const version = statements.selectContentVersion.get(versionId)
      if (!version) throw codedError('CONTENT_VERSION_NOT_FOUND', 'content version not found')
      const now = new Date().toISOString()
      statements.publishVersion.run(now, actorId, now, versionId)
      statements.upsertPublication.run(version.song_id, version.locale, versionId, now, actorId)
      statements.updateSongPublishedPointer.run(versionId, now, version.song_id)
      appendAudit({
        actorId,
        action: 'content.publish',
        resourceType: 'content_version',
        resourceId: versionId,
        after: { songId: version.song_id, locale: version.locale }
      })
      const generationJob = statements.selectJobByResult.get(versionId)
      if (generationJob?.state === 'review') {
        transitionJob(generationJob.id, 'completed', { resultContentVersionId: versionId })
      }
      return hydrateContentVersion(versionId)
    })
  }

  function appendAudit({ actorId = null, action, resourceType, resourceId, requestId = null, before = null, after = null, metadata = {} }) {
    statements.insertAudit.run(
      crypto.randomUUID(), cleanOptional(actorId), action, resourceType, resourceId, cleanOptional(requestId),
      before ? JSON.stringify(before) : null, after ? JSON.stringify(after) : null,
      JSON.stringify(metadata || {}), new Date().toISOString()
    )
  }

  function dashboardStats() {
    const row = statements.selectDashboardStats.get()
    return {
      songs: Number(row.song_count || 0),
      published: Number(row.published_count || 0),
      pendingReview: Number(row.review_count || 0),
      failedJobs: Number(row.failed_job_count || 0),
      queuedJobs: Number(row.queued_job_count || 0),
      processingJobs: Number(row.processing_job_count || 0),
      activeJobs: Number(row.active_job_count || 0),
      sources: Number(row.source_count || 0),
      tokenInput: Number(row.token_input || 0),
      tokenOutput: Number(row.token_output || 0),
      cost: Number(row.cost || 0)
    }
  }

  function listSongs({ query = '', limit = 50, offset = 0 } = {}) {
    const needle = `%${String(query).trim().slice(0, 200)}%`
    return statements.listSongs.all(needle, needle, needle, boundedLimit(limit), boundedOffset(offset)).map((row) => ({
      ...hydrateSong(row.id),
      whitelisted: Boolean(row.whitelisted),
      currentContentStatus: row.content_status || null,
      updatedAt: row.updated_at
    }))
  }

  function listContentVersions({ status = '', limit = 50, offset = 0 } = {}) {
    return statements.listContentVersions
      .all(cleanOptional(status) || '', cleanOptional(status) || '', boundedLimit(limit), boundedOffset(offset))
      .map((row) => ({
        id: row.id,
        songId: row.song_id,
        songTitle: row.song_title,
        artistName: row.primary_artist_name,
        locale: row.locale,
        schemaVersion: row.schema_version,
        confidence: row.confidence,
        riskFlags: parseJSON(row.risk_flags_json, []),
        status: row.status,
        modelName: row.model_name || null,
        generatedAt: row.generated_at,
        updatedAt: row.updated_at
      }))
  }

  function getContentReview(versionId) {
    const content = hydrateContentVersion(versionId)
    if (!content) return null
    const publication = statements.selectPublicationForSong.get(content.songId, content.locale)
    const published = publication?.current_content_version_id
      ? hydrateContentVersion(publication.current_content_version_id)
      : null
    return {
      song: hydrateSong(content.songId),
      candidate: content,
      published,
      fieldDiffs: contentDiff(published, content),
      generationJob: hydrateNullableJob(statements.selectJobByResult.get(content.id))
    }
  }

  function setSongIdentityStatus(songId, status, actorId) {
    if (!['confirmed', 'provisional', 'conflict'].includes(status)) throw codedError('INVALID_IDENTITY_STATUS', 'unsupported identity status')
    const before = hydrateSong(songId)
    if (!before) throw codedError('SONG_NOT_FOUND', 'song not found')
    statements.updateSongIdentity.run(status, new Date().toISOString(), songId)
    appendAudit({ actorId, action: 'song.identity.update', resourceType: 'song', resourceId: songId, before: { status: before.identityStatus }, after: { status } })
    return hydrateSong(songId)
  }

  function repointMapping(mappingId, targetSongId, actorId) {
    const mapping = statements.selectMappingById.get(cleanId(mappingId))
    if (!mapping) throw codedError('MAPPING_NOT_FOUND', 'platform mapping not found')
    if (!statements.selectSong.get(cleanId(targetSongId))) throw codedError('SONG_NOT_FOUND', 'target song not found')
    statements.updateMappingSong.run(targetSongId, actorId || null, new Date().toISOString(), mappingId)
    appendAudit({ actorId, action: 'song.mapping.repoint', resourceType: 'platform_mapping', resourceId: mappingId, before: { songId: mapping.song_id }, after: { songId: targetSongId } })
    return hydrateSong(targetSongId)
  }

  function splitMapping(mappingId, actorId) {
    const mapping = statements.selectMappingById.get(cleanId(mappingId))
    if (!mapping) throw codedError('MAPPING_NOT_FOUND', 'platform mapping not found')
    const source = statements.selectSong.get(mapping.song_id)
    if (!source) throw codedError('SONG_NOT_FOUND', 'source song not found')
    return transaction(() => {
      const id = crypto.randomUUID()
      const now = new Date().toISOString()
      statements.insertSong.run(
        id, mapping.raw_title || source.title, normalizeComparable(mapping.raw_title || source.title),
        mapping.platform_artist_id || source.primary_artist_id, mapping.raw_artist || source.primary_artist_name,
        JSON.stringify([{ id: mapping.platform_artist_id || source.primary_artist_id, name: mapping.raw_artist || source.primary_artist_name }]),
        mapping.platform_album_id || source.album_id, mapping.raw_album || source.album_name,
        source.duration_ms, source.release_date_value, source.release_date_precision, source.isrc,
        source.version_label, source.cover_url, 'provisional', now, now
      )
      statements.updateMappingSong.run(id, actorId || null, now, mappingId)
      appendAudit({ actorId, action: 'song.mapping.split', resourceType: 'platform_mapping', resourceId: mappingId, before: { songId: mapping.song_id }, after: { songId: id } })
      return hydrateSong(id)
    })
  }

  function mergeSongs(sourceSongId, targetSongId, actorId) {
    if (sourceSongId === targetSongId) throw codedError('INVALID_SONG_MERGE', 'source and target must differ')
    const source = hydrateSong(sourceSongId)
    const target = hydrateSong(targetSongId)
    if (!source || !target) throw codedError('SONG_NOT_FOUND', 'source or target song not found')
    return transaction(() => {
      const now = new Date().toISOString()
      statements.updateMappingsForSong.run(targetSongId, actorId || null, now, sourceSongId)
      statements.updateSongIdentity.run('provisional', now, sourceSongId)
      appendAudit({ actorId, action: 'song.merge', resourceType: 'song', resourceId: targetSongId, before: { sourceSongId }, after: { targetSongId, movedMappings: source.platformMappings.map((item) => item.id) } })
      return { target: hydrateSong(targetSongId), source: hydrateSong(sourceSongId) }
    })
  }

  function createEditedContentVersion(versionId, patch, actorId) {
    const original = hydrateContentVersion(versionId)
    if (!original) throw codedError('CONTENT_VERSION_NOT_FOUND', 'content version not found')
    return transaction(() => {
      const id = crypto.randomUUID()
      const now = new Date().toISOString()
      const content = {
        songSummary: patch.songSummary === undefined ? original.songSummary : cleanContent(patch.songSummary),
        creationStory: patch.creationStory === undefined ? original.creationStory : cleanContent(patch.creationStory),
        background: patch.background === undefined ? original.background : cleanContent(patch.background),
        albumSummary: patch.albumSummary === undefined ? original.albumSummary : cleanContent(patch.albumSummary),
        sourceRefs: patch.sourceRefs && typeof patch.sourceRefs === 'object' ? patch.sourceRefs : original.sourceRefs
      }
      const contentHash = crypto.createHash('sha256')
        .update([content.songSummary, content.creationStory, content.background, content.albumSummary].map((value) => value || '').join('\n---\n'))
        .digest('hex')
      statements.insertContentVersion.run(
        id, original.songId, original.locale, original.schemaVersion,
        content.songSummary, content.creationStory, content.background, content.albumSummary,
        JSON.stringify(content.sourceRefs), original.confidence, JSON.stringify(original.riskFlags),
        JSON.stringify({ ...original.validation, manuallyEdited: true, editedBy: actorId }),
        'draft', original.modelProvider, original.modelName, original.promptVersion,
        contentHash, now, original.id, now, now
      )
      for (const source of original.sources) {
        const fields = Object.entries(content.sourceRefs)
          .filter(([, sourceIds]) => Array.isArray(sourceIds) && sourceIds.includes(source.id))
          .map(([field]) => field)
        statements.linkVersionSource.run(id, source.id, JSON.stringify(fields))
      }
      appendAudit({
        actorId,
        action: 'content.edit',
        resourceType: 'content_version',
        resourceId: id,
        before: publicAuditContent(original),
        after: publicAuditContent({ ...original, ...content, id, status: 'draft' })
      })
      return hydrateContentVersion(id)
    })
  }

  function setContentStatus(versionId, status, actorId, action) {
    if (!['draft', 'pending_review', 'offline', 'rejected'].includes(status)) {
      throw codedError('INVALID_CONTENT_STATUS', 'unsupported content status')
    }
    const before = hydrateContentVersion(versionId)
    if (!before) throw codedError('CONTENT_VERSION_NOT_FOUND', 'content version not found')
    const now = new Date().toISOString()
    statements.setContentStatus.run(status, now, versionId)
    if (status === 'offline') statements.deletePublicationByVersion.run(versionId)
    const generationJob = statements.selectJobByResult.get(versionId)
    if (generationJob?.state === 'review' && ['offline', 'rejected'].includes(status)) {
      transitionJob(generationJob.id, 'failed', {
        resultContentVersionId: versionId,
        errorCode: status === 'rejected' ? 'CONTENT_REJECTED' : 'CONTENT_OFFLINE',
        errorMessage: status === 'rejected' ? 'content was rejected' : 'content was taken offline'
      })
    }
    appendAudit({
      actorId,
      action,
      resourceType: 'content_version',
      resourceId: versionId,
      before: { status: before.status },
      after: { status }
    })
    return hydrateContentVersion(versionId)
  }

  function rollbackContentVersion(versionId, actorId) {
    const target = hydrateContentVersion(versionId)
    if (!target) throw codedError('CONTENT_VERSION_NOT_FOUND', 'content version not found')
    const before = statements.selectPublicationForSong.get(target.songId, target.locale)
    const published = publishContentVersion(versionId, actorId)
    appendAudit({
      actorId,
      action: 'content.rollback',
      resourceType: 'content_version',
      resourceId: versionId,
      before: { versionId: before?.current_content_version_id || null },
      after: { versionId }
    })
    return published
  }

  function listJobs({ state = '', limit = 50, offset = 0 } = {}) {
    const normalizedState = normalizeJobFilter(state)
    return statements.listJobs
      .all(normalizedState, normalizedState, normalizedState, normalizedState, boundedLimit(limit), boundedOffset(offset))
      .map(hydrateJob)
  }

  function countJobs({ state = '' } = {}) {
    const normalizedState = normalizeJobFilter(state)
    return Number(statements.countJobs.get(normalizedState, normalizedState, normalizedState, normalizedState)?.count || 0)
  }

  function jobStateCounts() {
    const counts = {
      all: 0,
      active: 0,
      processing: 0,
      queued: 0,
      completed: 0,
      failed: 0,
      review: 0
    }
    for (const row of statements.jobStateCounts.all()) {
      const state = String(row.state || '')
      const count = Number(row.count || 0)
      counts.all += count
      counts[state] = count
      if (ACTIVE_JOB_STATES.has(state)) counts.active += count
      if (['collecting', 'generating', 'validating'].includes(state)) counts.processing += count
    }
    return counts
  }

  function retryJob(jobId, actorId) {
    const job = getJob(jobId)
    if (!job) throw codedError('JOB_NOT_FOUND', 'generation job not found')
    if (job.state !== 'failed') throw codedError('JOB_NOT_RETRYABLE', 'only failed jobs can be retried')
    const now = new Date().toISOString()
    statements.retryJob.run(now, now, jobId)
    appendAudit({ actorId, action: 'job.retry', resourceType: 'generation_job', resourceId: jobId })
    return getJob(jobId)
  }

  function listSources({ grade = '', limit = 50, offset = 0 } = {}) {
    const normalizedGrade = cleanOptional(grade) || ''
    return statements.listSources.all(normalizedGrade, normalizedGrade, boundedLimit(limit), boundedOffset(offset)).map(hydrateSourceRow)
  }

  function updateSource(sourceId, patch, actorId) {
    const before = statements.selectSourceById.get(cleanId(sourceId))
    if (!before) throw codedError('SOURCE_NOT_FOUND', 'source not found')
    const grade = ['A', 'B', 'C', 'D'].includes(patch?.grade) ? patch.grade : before.grade
    const accessible = patch?.accessible === undefined ? before.accessible : (patch.accessible ? 1 : 0)
    statements.updateSource.run(grade, accessible, sourceId)
    appendAudit({ actorId, action: 'source.update', resourceType: 'content_source', resourceId: sourceId, before: { grade: before.grade, accessible: Boolean(before.accessible) }, after: { grade, accessible: Boolean(accessible) } })
    return hydrateSourceRow(statements.selectSourceById.get(sourceId))
  }

  function listAuditLogs({ limit = 100, offset = 0 } = {}) {
    return statements.listAuditLogs.all(boundedLimit(limit, 200), boundedOffset(offset)).map((row) => ({
      id: row.id,
      actorId: row.actor_id || null,
      action: row.action,
      resourceType: row.resource_type,
      resourceId: row.resource_id,
      requestId: row.request_id || null,
      before: parseJSON(row.before_json, null),
      after: parseJSON(row.after_json, null),
      metadata: parseJSON(row.metadata_json, {}),
      createdAt: row.created_at
    }))
  }

  function assignRole(actorId, roleId, assignedBy = 'system') {
    const normalizedActor = cleanId(actorId)
    const normalizedRole = cleanId(roleId)
    if (!normalizedActor || !statements.selectRole.get(normalizedRole)) {
      throw codedError('INVALID_ROLE_ASSIGNMENT', 'actor and existing role are required')
    }
    statements.assignRole.run(normalizedActor, normalizedRole, new Date().toISOString())
    appendAudit({
      actorId: assignedBy,
      action: 'role.assign',
      resourceType: 'admin_actor',
      resourceId: normalizedActor,
      after: { roleId: normalizedRole }
    })
  }

  function actorPermissions(actorId) {
    return statements.selectActorPermissions.all(cleanId(actorId)).map((row) => row.permission)
  }

  function listRoles() {
    return statements.listRoles.all().map((row) => ({ ...row, permissions: parseJSON(row.permissions, []) }))
  }

  function listRoleAssignments() {
    return statements.listRoleAssignments.all().map((row) => ({ actorId: row.external_actor_id, roleId: row.role_id, createdAt: row.created_at }))
  }

  function close() {
    databaseEngine.close()
    database.close()
  }

  return {
    resolveMapping,
    upsertResolvedSong,
    hydrateSong,
    setWhitelist,
    isWhitelisted,
    getPublishedDetail,
    hydrateContentVersion,
    findContentHashOnOtherSong,
    ensureGenerationJob,
    getJob,
    leaseNextJob,
    transitionJob,
    requeueJob,
    deferJob,
    saveEvidence,
    getJobSources,
    recentProviderRequestTimes,
    insertContentVersion,
    publishContentVersion,
    appendAudit,
    dashboardStats,
    listSongs,
    listContentVersions,
    getContentReview,
    setSongIdentityStatus,
    repointMapping,
    splitMapping,
    mergeSongs,
    createEditedContentVersion,
    setContentStatus,
    rollbackContentVersion,
    listJobs,
    countJobs,
    jobStateCounts,
    retryJob,
    listSources,
    updateSource,
    listAuditLogs,
    assignRole,
    actorPermissions,
    listRoles,
    listRoleAssignments,
    databaseInspect: databaseEngine.inspect,
    databaseOptimize: databaseEngine.optimize,
    close,
    databasePath: resolvedDatabasePath
  }
}

function prepareStatements(database) {
  return {
    selectSong: database.prepare('SELECT * FROM songs WHERE id = ?'),
    insertSong: database.prepare(`INSERT INTO songs (
      id, title, normalized_title, primary_artist_id, primary_artist_name, artists_json,
      album_id, album_name, duration_ms, release_date_value, release_date_precision,
      isrc, version_label, cover_url, identity_status, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`),
    updateSongPublishedPointer: database.prepare('UPDATE songs SET current_published_content_id = ?, updated_at = ? WHERE id = ?'),
    selectMapping: database.prepare('SELECT song_id FROM platform_song_mappings WHERE platform = ? AND platform_song_id = ?'),
    selectMappingById: database.prepare('SELECT * FROM platform_song_mappings WHERE id = ?'),
    selectMappings: database.prepare('SELECT * FROM platform_song_mappings WHERE song_id = ? ORDER BY platform'),
    updateMappingSong: database.prepare('UPDATE platform_song_mappings SET song_id = ?, verified_by = ?, match_method = \'manual\', match_confidence = 1, updated_at = ? WHERE id = ?'),
    updateMappingsForSong: database.prepare('UPDATE platform_song_mappings SET song_id = ?, verified_by = ?, match_method = \'manual\', match_confidence = 1, updated_at = ? WHERE song_id = ?'),
    updateSongIdentity: database.prepare('UPDATE songs SET identity_status = ?, updated_at = ? WHERE id = ?'),
    insertMapping: database.prepare(`INSERT INTO platform_song_mappings (
      id, song_id, platform, platform_song_id, platform_artist_id, platform_album_id,
      raw_title, raw_artist, raw_album, raw_metadata_json, match_method, match_confidence,
      verified_by, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`),
    upsertWhitelist: database.prepare(`INSERT INTO song_content_whitelist
      (song_id, enabled, note, created_by, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(song_id) DO UPDATE SET enabled = excluded.enabled, note = excluded.note,
      created_by = excluded.created_by, updated_at = excluded.updated_at`),
    selectWhitelist: database.prepare('SELECT enabled FROM song_content_whitelist WHERE song_id = ?'),
    selectPublished: database.prepare(`SELECT v.* FROM song_content_publications p
      JOIN song_content_versions v ON v.id = p.current_content_version_id
      WHERE p.song_id = ? AND p.locale = ? AND v.status = 'published'`),
    selectContentVersion: database.prepare('SELECT * FROM song_content_versions WHERE id = ?'),
    selectLatestVersion: database.prepare('SELECT id FROM song_content_versions WHERE song_id = ? AND locale = ? ORDER BY created_at DESC LIMIT 1'),
    selectOtherSongContentHash: database.prepare('SELECT id, song_id FROM song_content_versions WHERE content_hash = ? AND song_id <> ? LIMIT 1'),
    selectVersionSources: database.prepare(`SELECT s.*, vs.supported_fields_json FROM content_version_sources vs
      JOIN content_sources s ON s.id = vs.source_id WHERE vs.content_version_id = ? ORDER BY s.grade, s.publisher`),
    selectActiveJob: database.prepare(`SELECT * FROM generation_jobs WHERE idempotency_key = ?
      AND state IN ('queued', 'collecting', 'generating', 'validating', 'review') ORDER BY created_at DESC LIMIT 1`),
    selectLatestJobByKey: database.prepare('SELECT * FROM generation_jobs WHERE idempotency_key = ? ORDER BY created_at DESC LIMIT 1'),
    selectJob: database.prepare('SELECT * FROM generation_jobs WHERE id = ?'),
    selectJobByResult: database.prepare('SELECT * FROM generation_jobs WHERE result_content_version_id = ? ORDER BY updated_at DESC LIMIT 1'),
    insertJob: database.prepare(`INSERT INTO generation_jobs (
      id, idempotency_key, song_id, locale, schema_version, reason, state,
      max_attempts, available_at, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, 'queued', ?, ?, ?, ?)`),
    selectClaimableJob: database.prepare(`SELECT * FROM generation_jobs
      WHERE (state = 'queued' AND available_at <= ?)
         OR (state IN ('collecting', 'generating', 'validating') AND lease_expires_at < ?)
      ORDER BY created_at LIMIT 1`),
    claimJob: database.prepare(`UPDATE generation_jobs SET state = 'collecting',
      lease_owner = ?, lease_expires_at = ?, attempt_count = attempt_count + 1,
      started_at = COALESCE(started_at, ?), updated_at = ?, error_code = NULL, error_message = NULL
      WHERE id = ? AND ((state = 'queued' AND available_at <= ?)
        OR (state IN ('collecting', 'generating', 'validating') AND lease_expires_at < ?))`),
    updateJob: database.prepare(`UPDATE generation_jobs SET state = ?, available_at = ?,
      lease_owner = ?, lease_expires_at = ?, error_code = ?, error_message = ?, token_input = ?,
      token_output = ?, cost = ?, provider_request_id = ?, result_content_version_id = ?,
      updated_at = ?, started_at = ?, finished_at = ? WHERE id = ?`),
    selectSourceByFingerprint: database.prepare('SELECT id FROM content_sources WHERE canonical_url = ? AND content_hash = ?'),
    refreshSourceEvidence: database.prepare(`UPDATE content_sources SET title = ?, publisher = ?,
      published_at = ?, fetched_at = ?, excerpt = ?, metadata_json = ? WHERE id = ?`),
    insertSource: database.prepare(`INSERT INTO content_sources (
      id, url, canonical_url, title, publisher, published_at, fetched_at, grade,
      excerpt, content_hash, accessible, metadata_json
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`),
    linkJobSource: database.prepare('INSERT OR IGNORE INTO generation_job_sources (job_id, source_id) VALUES (?, ?)'),
    selectJobSources: database.prepare(`SELECT s.* FROM generation_job_sources js
      JOIN content_sources s ON s.id = js.source_id WHERE js.job_id = ? ORDER BY s.grade, s.publisher`),
    selectRecentProviderRequests: database.prepare(`SELECT updated_at AS requested_at
      FROM generation_jobs
      WHERE updated_at >= ? AND (
        provider_request_id IS NOT NULL
        OR error_code IN ('AI_RATE_LIMITED', 'AI_TIMEOUT', 'AI_PROVIDER_ERROR')
      )
      ORDER BY updated_at`),
    insertContentVersion: database.prepare(`INSERT INTO song_content_versions (
      id, song_id, locale, schema_version, song_summary, creation_story, background,
      album_summary, source_refs_json, confidence, risk_flags_json, validation_json,
      status, model_provider, model_name, prompt_version, content_hash, generated_at,
      supersedes_id, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`),
    linkVersionSource: database.prepare(`INSERT INTO content_version_sources
      (content_version_id, source_id, supported_fields_json) VALUES (?, ?, ?)`),
    publishVersion: database.prepare(`UPDATE song_content_versions SET status = 'published',
      published_at = ?, published_by = ?, updated_at = ? WHERE id = ?`),
    upsertPublication: database.prepare(`INSERT INTO song_content_publications
      (song_id, locale, current_content_version_id, published_at, published_by) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(song_id, locale) DO UPDATE SET current_content_version_id = excluded.current_content_version_id,
      published_at = excluded.published_at, published_by = excluded.published_by`),
    insertAudit: database.prepare(`INSERT INTO song_content_audit_logs (
      id, actor_id, action, resource_type, resource_id, request_id, before_json,
      after_json, metadata_json, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`),
    selectDashboardStats: database.prepare(`SELECT
      (SELECT COUNT(*) FROM songs) AS song_count,
      (SELECT COUNT(*) FROM song_content_versions WHERE status = 'published') AS published_count,
      (SELECT COUNT(*) FROM song_content_versions WHERE status = 'pending_review') AS review_count,
      (SELECT COUNT(*) FROM generation_jobs WHERE state = 'failed') AS failed_job_count,
      (SELECT COUNT(*) FROM generation_jobs WHERE state = 'queued') AS queued_job_count,
      (SELECT COUNT(*) FROM generation_jobs WHERE state IN ('collecting', 'generating', 'validating')) AS processing_job_count,
      (SELECT COUNT(*) FROM generation_jobs WHERE state IN ('queued', 'collecting', 'generating', 'validating')) AS active_job_count,
      (SELECT COUNT(*) FROM content_sources) AS source_count,
      (SELECT COALESCE(SUM(token_input), 0) FROM generation_jobs) AS token_input,
      (SELECT COALESCE(SUM(token_output), 0) FROM generation_jobs) AS token_output,
      (SELECT COALESCE(SUM(cost), 0) FROM generation_jobs) AS cost`),
    listSongs: database.prepare(`SELECT s.id, s.updated_at,
      COALESCE(w.enabled, 1) AS whitelisted, v.status AS content_status
      FROM songs s
      LEFT JOIN song_content_whitelist w ON w.song_id = s.id
      LEFT JOIN song_content_publications p ON p.song_id = s.id
      LEFT JOIN song_content_versions v ON v.id = p.current_content_version_id
      WHERE (? = '%%' OR s.title LIKE ? OR s.primary_artist_name LIKE ?)
      GROUP BY s.id ORDER BY s.updated_at DESC LIMIT ? OFFSET ?`),
    listContentVersions: database.prepare(`SELECT v.*, s.title AS song_title, s.primary_artist_name
      FROM song_content_versions v JOIN songs s ON s.id = v.song_id
      WHERE (? = '' OR v.status = ?) ORDER BY v.updated_at DESC LIMIT ? OFFSET ?`),
    selectPublicationForSong: database.prepare('SELECT * FROM song_content_publications WHERE song_id = ? AND locale = ?'),
    setContentStatus: database.prepare('UPDATE song_content_versions SET status = ?, updated_at = ? WHERE id = ?'),
    deletePublicationByVersion: database.prepare('DELETE FROM song_content_publications WHERE current_content_version_id = ?'),
    listJobs: database.prepare(`SELECT j.*,
      s.title AS song_title,
      s.primary_artist_name AS artist_name,
      s.album_name AS album_name,
      s.cover_url AS cover_url,
      (SELECT m.platform FROM platform_song_mappings m
        WHERE m.song_id = j.song_id ORDER BY m.created_at LIMIT 1) AS platform,
      CASE WHEN j.state = 'queued' THEN (
        SELECT COUNT(*) FROM generation_jobs q
        WHERE q.state = 'queued' AND (
          q.available_at < j.available_at
          OR (q.available_at = j.available_at AND q.created_at <= j.created_at)
        )
      ) ELSE NULL END AS queue_position
      FROM generation_jobs j
      JOIN songs s ON s.id = j.song_id
      WHERE (? = ''
        OR (? = 'active' AND j.state IN ('queued', 'collecting', 'generating', 'validating', 'review'))
        OR (? = 'processing' AND j.state IN ('collecting', 'generating', 'validating'))
        OR j.state = ?)
      ORDER BY
        CASE
          WHEN j.state IN ('collecting', 'generating', 'validating') THEN 0
          WHEN j.state = 'queued' THEN 1
          WHEN j.state = 'review' THEN 2
          WHEN j.state = 'failed' THEN 3
          ELSE 4
        END,
        CASE WHEN j.state = 'queued' THEN j.available_at END,
        j.updated_at DESC
      LIMIT ? OFFSET ?`),
    countJobs: database.prepare(`SELECT COUNT(*) AS count FROM generation_jobs
      WHERE (? = ''
        OR (? = 'active' AND state IN ('queued', 'collecting', 'generating', 'validating', 'review'))
        OR (? = 'processing' AND state IN ('collecting', 'generating', 'validating'))
        OR state = ?)`),
    jobStateCounts: database.prepare('SELECT state, COUNT(*) AS count FROM generation_jobs GROUP BY state'),
    retryJob: database.prepare(`UPDATE generation_jobs SET state = 'queued', attempt_count = 0, available_at = ?,
      lease_owner = NULL, lease_expires_at = NULL, error_code = NULL, error_message = NULL,
      finished_at = NULL, updated_at = ? WHERE id = ?`),
    deferJob: database.prepare(`UPDATE generation_jobs SET state = 'queued',
      attempt_count = MAX(0, attempt_count - 1), available_at = ?, lease_owner = NULL,
      lease_expires_at = NULL, error_code = ?, error_message = ?, finished_at = NULL,
      updated_at = ? WHERE id = ?`),
    listSources: database.prepare(`SELECT * FROM content_sources WHERE (? = '' OR grade = ?)
      ORDER BY fetched_at DESC LIMIT ? OFFSET ?`),
    selectSourceById: database.prepare('SELECT * FROM content_sources WHERE id = ?'),
    updateSource: database.prepare('UPDATE content_sources SET grade = ?, accessible = ? WHERE id = ?'),
    listAuditLogs: database.prepare('SELECT * FROM song_content_audit_logs ORDER BY created_at DESC LIMIT ? OFFSET ?'),
    selectRole: database.prepare('SELECT id FROM song_content_roles WHERE id = ?'),
    assignRole: database.prepare(`INSERT OR IGNORE INTO song_content_admin_assignments
      (external_actor_id, role_id, created_at) VALUES (?, ?, ?)`),
    selectActorPermissions: database.prepare(`SELECT DISTINCT rp.permission
      FROM song_content_admin_assignments a
      JOIN song_content_role_permissions rp ON rp.role_id = a.role_id
      WHERE a.external_actor_id = ? ORDER BY rp.permission`),
    listRoles: database.prepare(`SELECT r.id, r.name, COALESCE(json_group_array(rp.permission) FILTER (WHERE rp.permission IS NOT NULL), '[]') AS permissions
      FROM song_content_roles r LEFT JOIN song_content_role_permissions rp ON rp.role_id = r.id
      GROUP BY r.id ORDER BY r.id`),
    listRoleAssignments: database.prepare('SELECT * FROM song_content_admin_assignments ORDER BY created_at DESC')
  }
}

function hydrateJob(row) {
  return {
    id: row.id,
    idempotencyKey: row.idempotency_key,
    songId: row.song_id,
    locale: row.locale,
    schemaVersion: row.schema_version,
    reason: row.reason,
    state: row.state,
    attemptCount: Number(row.attempt_count),
    maxAttempts: Number(row.max_attempts),
    availableAt: row.available_at,
    leaseOwner: row.lease_owner || null,
    leaseExpiresAt: row.lease_expires_at || null,
    errorCode: row.error_code || null,
    errorMessage: row.error_message || null,
    tokenInput: nullableNumber(row.token_input),
    tokenOutput: nullableNumber(row.token_output),
    cost: nullableNumber(row.cost),
    providerRequestId: row.provider_request_id || null,
    resultContentVersionId: row.result_content_version_id || null,
    startedAt: row.started_at || null,
    finishedAt: row.finished_at || null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    isActive: ACTIVE_JOB_STATES.has(row.state),
    durationMs: row.started_at && row.finished_at ? Math.max(0, Date.parse(row.finished_at) - Date.parse(row.started_at)) : null,
    queuePosition: nullableNumber(row.queue_position),
    songTitle: row.song_title || null,
    artistName: row.artist_name || null,
    albumName: row.album_name || null,
    coverURL: row.cover_url || null,
    platform: row.platform || null
  }
}

function hydrateSourceRow(row) {
  return {
    id: row.id,
    url: row.url,
    title: row.title,
    publisher: row.publisher,
    publishedAt: row.published_at || null,
    fetchedAt: row.fetched_at,
    grade: row.grade,
    excerpt: row.excerpt || null,
    contentHash: row.content_hash,
    accessible: Boolean(row.accessible),
    supportedFields: parseJSON(row.supported_fields_json, []),
    metadata: parseJSON(row.metadata_json, {})
  }
}

function hydrateNullableJob(row) { return row ? hydrateJob(row) : null }

function contentDiff(before, after) {
  const fields = ['songSummary', 'creationStory', 'background', 'albumSummary', 'confidence', 'riskFlags', 'sourceRefs']
  return fields.filter((field) => JSON.stringify(before?.[field] ?? null) !== JSON.stringify(after?.[field] ?? null)).map((field) => ({
    field,
    before: before?.[field] ?? null,
    after: after?.[field] ?? null
  }))
}

function normalizeSongMetadata(raw = {}) {
  const artists = Array.isArray(raw.artists)
    ? raw.artists.map((artist) => ({ id: cleanOptional(artist?.id), name: cleanOptional(artist?.name) })).filter((artist) => artist.name)
    : [{ id: cleanOptional(raw.artistId), name: cleanOptional(raw.artist || raw.artistName) }].filter((artist) => artist.name)
  const identityStatus = ['confirmed', 'provisional', 'conflict'].includes(raw.identityStatus)
    ? raw.identityStatus
    : 'provisional'
  return {
    title: cleanOptional(raw.title),
    artists,
    album: raw.album?.name || raw.albumName
      ? { id: cleanOptional(raw.album?.id || raw.albumId), name: cleanOptional(raw.album?.name || raw.albumName) }
      : null,
    durationMs: nullableNumber(raw.durationMs),
    releaseDate: normalizeReleaseDate(raw.releaseDate),
    isrc: cleanOptional(raw.isrc)?.toUpperCase() || null,
    versionLabel: cleanOptional(raw.versionLabel),
    coverUrl: cleanOptional(raw.coverUrl),
    identityStatus
  }
}

function normalizeReleaseDate(raw) {
  if (!raw) return null
  if (typeof raw === 'string') return { value: raw.slice(0, 10), precision: inferDatePrecision(raw) }
  const value = cleanOptional(raw.value)
  return value ? { value: value.slice(0, 10), precision: cleanOptional(raw.precision) || inferDatePrecision(value) } : null
}

function normalizeSource(raw = {}) {
  const url = cleanOptional(raw.url)
  if (!url) throw codedError('INVALID_SOURCE', 'source URL is required')
  let parsed
  try { parsed = new URL(url) } catch (_) { throw codedError('INVALID_SOURCE', 'source URL is invalid') }
  if (!['http:', 'https:'].includes(parsed.protocol)) throw codedError('INVALID_SOURCE', 'source URL must use HTTP or HTTPS')
  parsed.hash = ''
  const excerpt = cleanOptional(raw.excerpt)?.slice(0, 4_000) || null
  const hashInput = cleanOptional(raw.contentHash) || `${parsed.toString()}\n${excerpt || ''}`
  const grade = ['A', 'B', 'C', 'D'].includes(raw.grade) ? raw.grade : 'D'
  return {
    url,
    canonicalUrl: parsed.toString(),
    title: cleanOptional(raw.title)?.slice(0, 500) || parsed.hostname,
    publisher: cleanOptional(raw.publisher)?.slice(0, 300) || parsed.hostname,
    publishedAt: validDate(raw.publishedAt) ? new Date(raw.publishedAt).toISOString() : null,
    fetchedAt: validDate(raw.fetchedAt) ? new Date(raw.fetchedAt).toISOString() : new Date().toISOString(),
    grade,
    excerpt,
    contentHash: crypto.createHash('sha256').update(hashInput).digest('hex'),
    accessible: raw.accessible !== false,
    metadata: raw.metadata && typeof raw.metadata === 'object' ? raw.metadata : {}
  }
}

function normalizeMatchMethod(value) {
  return ['ISRC', 'manual', 'strict_metadata', 'official_mapping', 'other'].includes(value) ? value : 'other'
}

function normalizeComparable(value) {
  return String(value || '').normalize('NFKC').toLowerCase().replace(/[\s\p{P}\p{S}]+/gu, '')
}

function normalizePlatform(value) {
  return String(value || '').trim().toUpperCase().slice(0, 32)
}

function normalizeLocale(value) {
  return cleanOptional(value)?.replace('_', '-').slice(0, 32) || 'zh-CN'
}

function cleanId(value) {
  return String(value || '').trim().slice(0, 256)
}

function cleanOptional(value) {
  return typeof value === 'string' && value.trim() ? value.trim() : null
}

function normalizeJobFilter(value) {
  const normalized = cleanOptional(value) || ''
  return ['', 'active', 'processing', 'queued', 'collecting', 'generating', 'validating', 'review', 'completed', 'failed']
    .includes(normalized) ? normalized : ''
}

function cleanContent(value) {
  return cleanOptional(value)?.slice(0, 20_000) || null
}

function nullableNumber(value) {
  if (value === null || value === undefined || value === '') return null
  const number = Number(value)
  return Number.isFinite(number) ? number : null
}

function clamp(value, minimum, maximum, fallback) {
  const number = Number(value)
  return Number.isFinite(number) ? Math.min(maximum, Math.max(minimum, number)) : fallback
}

function inferDatePrecision(value) {
  if (/^\d{4}$/.test(value)) return 'year'
  if (/^\d{4}-\d{2}$/.test(value)) return 'month'
  return 'day'
}

function validDate(value) {
  return typeof value === 'string' && !Number.isNaN(Date.parse(value))
}

function parseJSON(value, fallback) {
  try { return JSON.parse(value) } catch (_) { return fallback }
}

function publicAuditContent(content) {
  return {
    id: content.id,
    status: content.status,
    songSummary: content.songSummary,
    creationStory: content.creationStory,
    background: content.background,
    albumSummary: content.albumSummary,
    sourceRefs: content.sourceRefs
  }
}

function boundedLimit(value, maximum = 100) {
  return Math.max(1, Math.min(maximum, Number(value) || 50))
}

function boundedOffset(value) {
  return Math.max(0, Number(value) || 0)
}

function codedError(code, message, retryable = false) {
  const error = new Error(message)
  error.code = code
  error.retryable = retryable
  return error
}

module.exports = { createSongContentStore, codedError, normalizeComparable }
