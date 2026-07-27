const crypto = require('node:crypto')
const { DatabaseSync } = require('node:sqlite')

const CATEGORIES = new Set(['general', 'activity', 'maintenance', 'important', 'policy', 'update'])
const PRIORITIES = new Set(['normal', 'high', 'critical'])
const STATUSES = new Set(['draft', 'published', 'offline'])

function createAnnouncementService({ databasePath, logger = console }) {
  if (!databasePath) throw new TypeError('announcement databasePath is required')
  const database = new DatabaseSync(databasePath)
  database.exec(`
    CREATE TABLE IF NOT EXISTS announcements (
      id TEXT PRIMARY KEY,
      display_revision INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'draft',
      category TEXT NOT NULL DEFAULT 'general',
      priority TEXT NOT NULL DEFAULT 'normal',
      title TEXT NOT NULL,
      summary TEXT,
      body TEXT NOT NULL,
      image_url TEXT,
      action_title TEXT,
      action_url TEXT,
      min_app_version TEXT,
      max_app_version TEXT,
      platforms_json TEXT NOT NULL DEFAULT '["ios"]',
      locales_json TEXT NOT NULL DEFAULT '[]',
      starts_at TEXT,
      ends_at TEXT,
      requires_acknowledgement INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      published_at TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_announcements_status_window
    ON announcements(status, starts_at, ends_at, published_at);
  `)

  const selectAll = database.prepare('SELECT * FROM announcements ORDER BY COALESCE(published_at, updated_at) DESC, created_at DESC')
  const selectById = database.prepare('SELECT * FROM announcements WHERE id = ?')
  const selectPublished = database.prepare("SELECT * FROM announcements WHERE status = 'published' ORDER BY CASE priority WHEN 'critical' THEN 3 WHEN 'high' THEN 2 ELSE 1 END DESC, published_at DESC")
  const insert = database.prepare(`
    INSERT INTO announcements (
      id, display_revision, status, category, priority, title, summary, body,
      image_url, action_title, action_url, min_app_version, max_app_version,
      platforms_json, locales_json, starts_at, ends_at, requires_acknowledgement,
      created_at, updated_at, published_at
    ) VALUES (?, 0, 'draft', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
  `)
  const update = database.prepare(`
    UPDATE announcements SET
      category = ?, priority = ?, title = ?, summary = ?, body = ?, image_url = ?,
      action_title = ?, action_url = ?, min_app_version = ?, max_app_version = ?,
      platforms_json = ?, locales_json = ?, starts_at = ?, ends_at = ?,
      requires_acknowledgement = ?, updated_at = ?
    WHERE id = ? AND status != 'published'
  `)
  const publish = database.prepare(`
    UPDATE announcements SET status = 'published', display_revision = display_revision + 1,
      published_at = ?, updated_at = ? WHERE id = ?
  `)
  const republish = database.prepare(`
    UPDATE announcements SET display_revision = display_revision + 1,
      published_at = ?, updated_at = ? WHERE id = ? AND status = 'published'
  `)
  const offline = database.prepare("UPDATE announcements SET status = 'offline', updated_at = ? WHERE id = ? AND status = 'published'")
  const remove = database.prepare("DELETE FROM announcements WHERE id = ? AND status != 'published'")

  function list() {
    return selectAll.all().map(hydrateAnnouncement)
  }

  function get(id) {
    return hydrateNullable(selectById.get(clean(id, 120)))
  }

  function create(input) {
    const normalized = normalizeAnnouncement(input)
    const now = new Date().toISOString()
    const id = crypto.randomUUID()
    insert.run(
      id, normalized.category, normalized.priority, normalized.title, normalized.summary,
      normalized.body, normalized.imageURL, normalized.actionTitle, normalized.actionURL,
      normalized.minAppVersion, normalized.maxAppVersion, JSON.stringify(normalized.platforms),
      JSON.stringify(normalized.locales), normalized.startsAt, normalized.endsAt,
      normalized.requiresAcknowledgement ? 1 : 0, now, now
    )
    return get(id)
  }

  function updateDraft(id, input) {
    const current = get(id)
    if (!current) throw announcementError('ANNOUNCEMENT_NOT_FOUND', '公告不存在', 404)
    if (current.status === 'published') {
      throw announcementError('ANNOUNCEMENT_ALREADY_PUBLISHED', '已发布公告请先下线后再编辑', 409)
    }
    const normalized = normalizeAnnouncement(input, current)
    const now = new Date().toISOString()
    update.run(
      normalized.category, normalized.priority, normalized.title, normalized.summary,
      normalized.body, normalized.imageURL, normalized.actionTitle, normalized.actionURL,
      normalized.minAppVersion, normalized.maxAppVersion, JSON.stringify(normalized.platforms),
      JSON.stringify(normalized.locales), normalized.startsAt, normalized.endsAt,
      normalized.requiresAcknowledgement ? 1 : 0, now, current.id
    )
    return get(current.id)
  }

  function publishAnnouncement(id) {
    const current = get(id)
    if (!current) throw announcementError('ANNOUNCEMENT_NOT_FOUND', '公告不存在', 404)
    validatePublishable(current)
    const now = new Date().toISOString()
    if (current.status === 'published') republish.run(now, now, current.id)
    else publish.run(now, now, current.id)
    return get(current.id)
  }

  function takeOffline(id) {
    const current = get(id)
    if (!current) throw announcementError('ANNOUNCEMENT_NOT_FOUND', '公告不存在', 404)
    if (current.status !== 'published') return current
    offline.run(new Date().toISOString(), current.id)
    return get(current.id)
  }

  function deleteAnnouncement(id) {
    const current = get(id)
    if (!current) return false
    if (current.status === 'published') {
      throw announcementError('ANNOUNCEMENT_IS_PUBLISHED', '已发布公告需要先下线', 409)
    }
    return remove.run(current.id).changes > 0
  }

  function publicManifest({ appVersion, platform, locale, now = new Date() }) {
    const currentDate = now instanceof Date ? now : new Date(now)
    const publishedAnnouncements = selectPublished.all().map(hydrateAnnouncement)
    const eligible = publishedAnnouncements
      .filter((announcement) => isEligible(announcement, { appVersion, platform, locale, now: currentDate }))
      .slice(0, 40)
    const items = eligible.map((announcement) => ({
      id: announcement.id,
      displayRevision: announcement.displayRevision,
      category: announcement.category,
      priority: announcement.priority,
      title: announcement.title,
      summary: announcement.summary,
      publishedAt: announcement.publishedAt,
      startsAt: announcement.startsAt,
      endsAt: announcement.endsAt,
      requiresAcknowledgement: announcement.requiresAcknowledgement
    }))
    const etag = crypto.createHash('sha256')
      .update(JSON.stringify(items.map((item) => [item.id, item.displayRevision])))
      .digest('hex')
      .slice(0, 32)
    const boundaries = publishedAnnouncements
      .flatMap((announcement) => [announcement.startsAt, announcement.endsAt])
      .filter((value) => value && Date.parse(value) > currentDate.getTime())
      .sort()
    return {
      etag,
      items,
      nextBoundaryAt: boundaries[0] || null,
      recommendedCheckAfterSeconds: 21_600
    }
  }

  function publicDetail(id, displayRevision, context) {
    const announcement = get(id)
    if (!announcement || announcement.status !== 'published') return null
    if (Number(displayRevision) !== announcement.displayRevision) return null
    if (!isEligible(announcement, context)) return null
    return {
      id: announcement.id,
      displayRevision: announcement.displayRevision,
      category: announcement.category,
      priority: announcement.priority,
      title: announcement.title,
      summary: announcement.summary,
      body: announcement.body,
      imageURL: announcement.imageURL,
      actionTitle: announcement.actionTitle,
      actionURL: announcement.actionURL,
      publishedAt: announcement.publishedAt,
      requiresAcknowledgement: announcement.requiresAcknowledgement
    }
  }

  function close() {
    try { database.close() } catch (error) { logger.warn?.('[announcements] database close failed', error) }
  }

  return { close, create, deleteAnnouncement, get, list, publicDetail, publicManifest, publishAnnouncement, takeOffline, updateDraft }
}

function installAnnouncementRoutes({
  app,
  service,
  authMiddleware,
  authorize,
  resolvePublicToken,
  audit,
  logger = console
}) {
  const permitted = typeof authorize === 'function' ? authorize : () => (_req, _res, next) => next()
  const route = (handler) => async (req, res) => {
    try { await handler(req, res) } catch (error) {
      logger.error?.('[announcements] request failed', error)
      res.status(Number(error?.status) || 500).json({ ok: false, code: error?.code || 'ANNOUNCEMENT_ERROR', error: error?.message || '公告服务异常' })
    }
  }

  if (typeof authMiddleware === 'function') {
    app.get('/api/announcements', authMiddleware, permitted('config.manage'), route(async (_req, res) => {
      res.json({ ok: true, announcements: service.list() })
    }))
    app.post('/api/announcements', authMiddleware, permitted('config.manage'), route(async (req, res) => {
      const announcement = service.create(req.body)
      audit?.({ actorId: actor(req), action: 'announcement.create', resourceType: 'announcement', resourceId: announcement.id })
      res.status(201).json({ ok: true, announcement })
    }))
    app.put('/api/announcements/:id', authMiddleware, permitted('config.manage'), route(async (req, res) => {
      const announcement = service.updateDraft(req.params.id, req.body)
      audit?.({ actorId: actor(req), action: 'announcement.update', resourceType: 'announcement', resourceId: announcement.id })
      res.json({ ok: true, announcement })
    }))
    app.post('/api/announcements/:id/publish', authMiddleware, permitted('config.publish'), route(async (req, res) => {
      const announcement = service.publishAnnouncement(req.params.id)
      audit?.({ actorId: actor(req), action: 'announcement.publish', resourceType: 'announcement', resourceId: announcement.id, metadata: { displayRevision: announcement.displayRevision } })
      res.json({ ok: true, announcement })
    }))
    app.post('/api/announcements/:id/offline', authMiddleware, permitted('config.publish'), route(async (req, res) => {
      const announcement = service.takeOffline(req.params.id)
      audit?.({ actorId: actor(req), action: 'announcement.offline', resourceType: 'announcement', resourceId: announcement.id })
      res.json({ ok: true, announcement })
    }))
    app.delete('/api/announcements/:id', authMiddleware, permitted('config.manage'), route(async (req, res) => {
      const deleted = service.deleteAnnouncement(req.params.id)
      if (deleted) audit?.({ actorId: actor(req), action: 'announcement.delete', resourceType: 'announcement', resourceId: req.params.id })
      res.json({ ok: true, deleted })
    }))
  }

  app.get('/api/public/announcements/manifest', route(async (req, res) => {
    if (typeof resolvePublicToken !== 'function' || !resolvePublicToken(req, res)) return
    const context = requestContext(req)
    const manifest = service.publicManifest(context)
    const etag = `"${manifest.etag}"`
    res.set('Cache-Control', 'private, max-age=300, must-revalidate')
    res.set('ETag', etag)
    if (req.headers['if-none-match'] === etag) return res.status(304).end()
    res.json({
      ok: true,
      revision: manifest.etag,
      items: manifest.items,
      nextBoundaryAt: manifest.nextBoundaryAt,
      recommendedCheckAfterSeconds: manifest.recommendedCheckAfterSeconds
    })
  }))

  app.get('/api/public/announcements/:id', route(async (req, res) => {
    if (typeof resolvePublicToken !== 'function' || !resolvePublicToken(req, res)) return
    const revision = Number(req.query?.revision)
    const announcement = service.publicDetail(req.params.id, revision, requestContext(req))
    if (!announcement) return res.status(404).json({ ok: false, code: 'ANNOUNCEMENT_NOT_FOUND', error: '公告不存在或不适用于当前客户端' })
    const etag = `"announcement:${announcement.id}:${announcement.displayRevision}"`
    res.set('Cache-Control', 'private, max-age=86400, immutable')
    res.set('ETag', etag)
    if (req.headers['if-none-match'] === etag) return res.status(304).end()
    res.json({ ok: true, announcement })
  }))
}

function normalizeAnnouncement(input = {}, fallback = {}) {
  const category = CATEGORIES.has(input.category) ? input.category : (fallback.category || 'general')
  const priority = PRIORITIES.has(input.priority) ? input.priority : (fallback.priority || 'normal')
  const title = clean(input.title ?? fallback.title, 240)
  const body = clean(input.body ?? fallback.body, 30_000)
  if (!title) throw announcementError('ANNOUNCEMENT_TITLE_REQUIRED', '请输入公告标题', 400)
  if (!body) throw announcementError('ANNOUNCEMENT_BODY_REQUIRED', '请输入公告正文', 400)
  const imageURL = optionalHTTPURL(input.imageURL ?? fallback.imageURL)
  const actionURL = optionalHTTPURL(input.actionURL ?? fallback.actionURL)
  const startsAt = optionalISODate(input.startsAt ?? fallback.startsAt)
  const endsAt = optionalISODate(input.endsAt ?? fallback.endsAt)
  if (startsAt && endsAt && Date.parse(startsAt) >= Date.parse(endsAt)) {
    throw announcementError('ANNOUNCEMENT_WINDOW_INVALID', '结束时间必须晚于开始时间', 400)
  }
  return {
    category,
    priority,
    title,
    summary: clean(input.summary ?? fallback.summary, 500) || null,
    body,
    imageURL,
    actionTitle: clean(input.actionTitle ?? fallback.actionTitle, 80) || null,
    actionURL,
    minAppVersion: clean(input.minAppVersion ?? fallback.minAppVersion, 40) || null,
    maxAppVersion: clean(input.maxAppVersion ?? fallback.maxAppVersion, 40) || null,
    platforms: normalizeList(input.platforms ?? fallback.platforms, 10, 40, ['ios']),
    locales: normalizeList(input.locales ?? fallback.locales, 20, 40, []),
    startsAt,
    endsAt,
    requiresAcknowledgement: Boolean(input.requiresAcknowledgement ?? fallback.requiresAcknowledgement)
  }
}

function validatePublishable(announcement) {
  if (!announcement.title || !announcement.body) throw announcementError('ANNOUNCEMENT_INCOMPLETE', '公告标题和正文不能为空', 400)
  if (announcement.actionTitle && !announcement.actionURL) throw announcementError('ANNOUNCEMENT_ACTION_INVALID', '填写按钮文字时必须同时填写跳转链接', 400)
}

function isEligible(announcement, { appVersion, platform = 'ios', locale = 'zh-CN', now = new Date() }) {
  const timestamp = (now instanceof Date ? now : new Date(now)).getTime()
  if (announcement.startsAt && Date.parse(announcement.startsAt) > timestamp) return false
  if (announcement.endsAt && Date.parse(announcement.endsAt) <= timestamp) return false
  if (announcement.platforms.length > 0 && !announcement.platforms.includes(String(platform).toLowerCase())) return false
  const normalizedLocale = String(locale || '').toLowerCase()
  if (announcement.locales.length > 0 && !announcement.locales.some((value) => localeMatches(normalizedLocale, value))) return false
  if (announcement.minAppVersion && compareVersions(appVersion, announcement.minAppVersion) < 0) return false
  if (announcement.maxAppVersion && compareVersions(appVersion, announcement.maxAppVersion) > 0) return false
  return true
}

function requestContext(req) {
  return {
    appVersion: clean(req.query?.app_version, 40),
    platform: clean(req.query?.platform, 40).toLowerCase() || 'ios',
    locale: clean(req.query?.locale, 40) || 'zh-CN',
    now: new Date()
  }
}

function compareVersions(left, right) {
  const a = String(left || '0').split(/[.-]/u).map((value) => Number.parseInt(value, 10) || 0)
  const b = String(right || '0').split(/[.-]/u).map((value) => Number.parseInt(value, 10) || 0)
  for (let index = 0; index < Math.max(a.length, b.length); index += 1) {
    if ((a[index] || 0) !== (b[index] || 0)) return (a[index] || 0) < (b[index] || 0) ? -1 : 1
  }
  return 0
}

function localeMatches(clientLocale, configuredLocale) {
  const client = String(clientLocale || '').toLowerCase().replaceAll('_', '-')
  const configured = String(configuredLocale || '').toLowerCase().replaceAll('_', '-')
  if (!client || !configured) return false
  if (client === configured || client.startsWith(`${configured}-`)) return true
  const clientParts = client.split('-')
  const configuredParts = configured.split('-')
  if (clientParts[0] !== configuredParts[0]) return false
  if (configuredParts.length === 1) return true
  const configuredRegion = configuredParts.find((part, index) => index > 0 && (/^[a-z]{2}$/u.test(part) || /^\d{3}$/u.test(part)))
  return configuredRegion ? clientParts.includes(configuredRegion) : true
}

function hydrateAnnouncement(row) {
  return {
    id: row.id,
    displayRevision: Number(row.display_revision) || 0,
    status: STATUSES.has(row.status) ? row.status : 'draft',
    category: CATEGORIES.has(row.category) ? row.category : 'general',
    priority: PRIORITIES.has(row.priority) ? row.priority : 'normal',
    title: row.title,
    summary: row.summary || null,
    body: row.body,
    imageURL: row.image_url || null,
    actionTitle: row.action_title || null,
    actionURL: row.action_url || null,
    minAppVersion: row.min_app_version || null,
    maxAppVersion: row.max_app_version || null,
    platforms: parseList(row.platforms_json, ['ios']),
    locales: parseList(row.locales_json, []),
    startsAt: row.starts_at || null,
    endsAt: row.ends_at || null,
    requiresAcknowledgement: Boolean(row.requires_acknowledgement),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    publishedAt: row.published_at || null
  }
}

function hydrateNullable(row) { return row ? hydrateAnnouncement(row) : null }
function parseList(value, fallback) { try { const parsed = JSON.parse(value); return Array.isArray(parsed) ? parsed : fallback } catch (_) { return fallback } }
function normalizeList(value, maximumItems, maximumLength, fallback) { const source = Array.isArray(value) ? value : fallback; return [...new Set(source.map((item) => clean(item, maximumLength).toLowerCase()).filter(Boolean))].slice(0, maximumItems) }
function clean(value, maximum) { return typeof value === 'string' ? value.trim().slice(0, maximum) : '' }
function optionalISODate(value) { const normalized = clean(value, 80); if (!normalized) return null; if (Number.isNaN(Date.parse(normalized))) throw announcementError('ANNOUNCEMENT_DATE_INVALID', '公告时间格式无效', 400); return new Date(normalized).toISOString() }
function optionalHTTPURL(value) { const normalized = clean(value, 2_048); if (!normalized) return null; try { const url = new URL(normalized); if (!['http:', 'https:'].includes(url.protocol)) throw new Error(); return url.toString() } catch (_) { throw announcementError('ANNOUNCEMENT_URL_INVALID', '公告链接必须是有效的 HTTP 或 HTTPS 地址', 400) } }
function actor(req) { return String(req.admin?.id || req.user?.id || req.auth?.id || 'token-admin') }
function announcementError(code, message, status = 400) { const error = new Error(message); error.code = code; error.status = status; return error }

module.exports = { createAnnouncementService, installAnnouncementRoutes }
