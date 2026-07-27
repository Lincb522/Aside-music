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
    const query = { query: req.query?.q, limit: req.query?.limit, offset: req.query?.offset }
    res.json({
      ok: true,
      songs: store.listSongs(query),
      total: store.countSongs(query)
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
    res.json({ ok: true, review: adminContentReview(review) })
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
    const query = { state: req.query?.state, limit: req.query?.limit, offset: req.query?.offset }
    const jobs = store.listJobs(query)
      .map(adminJob)
    res.json({
      ok: true,
      jobs,
      total: store.countJobs(query),
      counts: store.jobStateCounts()
    })
  }))

  app.get('/api/song-content/jobs/:jobId', ...route('content.read', async (req, res) => {
    const job = store.getJob(req.params.jobId)
    if (!job) throw adminError(404, 'JOB_NOT_FOUND', '生成任务不存在')
    res.json({ ok: true, job: adminJob(enrichJob(job, store)) })
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
    const roles = store.listRoles().map(adminRole)
    const roleNames = new Map(roles.map((role) => [role.id, role.name]))
    const assignments = store.listRoleAssignments().map((assignment) => ({
      ...assignment,
      roleName: roleNames.get(assignment.roleId) || assignment.roleId
    }))
    res.json({ ok: true, roles, assignments })
  }))

  app.put('/api/song-content/access/:actorId', ...route('roles.manage', async (req, res) => {
    requireConfirmation(req)
    store.assignRole(req.params.actorId, req.body?.roleId, actor(req))
    res.json({ ok: true, actorId: req.params.actorId, permissions: store.actorPermissions(req.params.actorId) })
  }))

  app.get('/api/song-content/audit', ...route('audit.read', async (req, res) => {
    const logs = store.listAuditLogs({ limit: req.query?.limit, offset: req.query?.offset })
      .map((log) => adminAuditLog(log, store))
    res.json({ ok: true, logs })
  }))
}

const PERMISSION_DETAILS = {
  'content.read': ['查看内容', '查看歌曲、内容版本和资料来源'],
  'content.edit': ['编辑内容', '修改文案并创建新的内容草稿'],
  'content.publish': ['审核与发布', '发布或驳回待审核内容'],
  'content.rollback': ['回滚内容', '恢复并重新发布历史内容版本'],
  'content.offline': ['下线内容', '将已发布内容从客户端下线'],
  'jobs.manage': ['管理生成任务', '重试或重新发起内容生成任务'],
  'sources.manage': ['管理资料来源', '调整来源等级和可访问状态'],
  'songs.manage': ['管理歌曲身份', '确认歌曲、平台映射和生成名单'],
  'audit.read': ['查看审计日志', '查看管理操作及自动审核记录'],
  'config.manage': ['编辑 Agent 配置', '修改内容 Agent 和客户端配置草稿'],
  'config.publish': ['发布 Agent 配置', '验证、发布或回滚 Agent 配置'],
  'credentials.write': ['更新 AI 凭据', '维护模型服务的访问凭据'],
  'roles.manage': ['管理权限', '为后台操作者分配管理角色']
}

const ROLE_DESCRIPTIONS = {
  'content-editor': '查看并编辑歌曲内容草稿',
  'content-reviewer': '审核、发布、驳回、回滚和下线内容',
  'content-admin': '管理内容、任务、来源、配置、凭据和角色权限'
}

const AUDIT_ACTIONS = {
  'whitelist.enable': ['加入生成名单', '歌曲已允许自动获取音乐幕后内容'],
  'whitelist.disable': ['移出生成名单', '歌曲已停止自动获取音乐幕后内容'],
  'song.identity.update': ['更新歌曲身份', '歌曲身份确认状态已变更'],
  'song.mapping.repoint': ['修正平台映射', '平台歌曲已重新关联到目标歌曲'],
  'song.mapping.split': ['拆分平台映射', '平台歌曲已拆分为独立歌曲'],
  'song.merge': ['合并歌曲', '重复歌曲身份已合并'],
  'content.edit': ['编辑内容', '已根据当前内容创建新的草稿版本'],
  'content.submit': ['提交审核', '内容草稿已进入审核流程'],
  'content.publish': ['发布内容', '内容已发布并可供客户端读取'],
  'content.rollback': ['回滚内容', '历史内容版本已恢复发布'],
  'content.offline': ['下线内容', '内容已从客户端下线'],
  'content.reject': ['驳回内容', '内容未通过人工审核'],
  'content.review.passed': ['自动审核通过', '内容满足来源、身份和事实校验规则'],
  'content.review.rejected': ['自动审核未通过', '内容未满足自动审核规则，详细原因见下方'],
  'job.retry': ['重试生成任务', '失败任务已重新加入生成队列'],
  'job.regenerate': ['重新生成内容', '歌曲已创建新的内容生成任务'],
  'source.update': ['更新资料来源', '来源等级或可访问状态已变更'],
  'role.assign': ['分配角色', '后台操作者的管理角色已更新']
}

const RESOURCE_LABELS = {
  song: '歌曲',
  platform_mapping: '平台映射',
  content_version: '内容版本',
  generation_job: '生成任务',
  content_source: '资料来源',
  admin_actor: '后台操作者'
}

function adminRole(role) {
  return {
    ...role,
    description: ROLE_DESCRIPTIONS[role.id] || '后台管理角色',
    permissionDetails: (role.permissions || []).map((id) => {
      const detail = PERMISSION_DETAILS[id] || [id, '后台管理权限']
      return { id, label: detail[0], description: detail[1] }
    })
  }
}

function enrichJob(job, store) {
  const song = store.hydrateSong(job.songId)
  if (!song) return job
  return {
    ...job,
    songTitle: song.title,
    artistName: (song.artists || []).map((artist) => artist.name).filter(Boolean).join(' / ') || null,
    albumName: song.album?.name || null,
    coverURL: song.coverUrl || null,
    platform: song.platformMappings?.[0]?.platform || null
  }
}

function adminContentReview(review) {
  return {
    ...review,
    reviewSummary: adminReviewSummary(review?.candidate?.validation, review?.candidate?.riskFlags)
  }
}

function adminReviewSummary(validation = {}, riskFlags = []) {
  const errors = Array.isArray(validation?.errors) ? validation.errors : []
  const warnings = Array.isArray(validation?.warnings) ? validation.warnings : []
  const risks = Array.isArray(riskFlags) ? riskFlags : []
  const checks = [
    ...errors.map((issue, index) => ({ id: `error-${index}`, severity: 'error', message: localizeValidationIssue(issue) })),
    ...warnings.map((issue, index) => ({ id: `warning-${index}`, severity: 'warning', message: localizeValidationIssue(issue) })),
    ...risks.map((issue, index) => ({ id: `risk-${index}`, severity: 'warning', message: localizeRiskFlag(issue) }))
  ]
  if (checks.length === 0) checks.push({ id: 'passed', severity: 'success', message: '自动审核通过，未发现需要处理的问题' })
  return {
    passed: validation?.passed !== false && errors.length === 0 && warnings.length === 0,
    checkedAt: validation?.checkedAt || null,
    sourceCoverage: Number.isFinite(Number(validation?.sourceCoverage)) ? Number(validation.sourceCoverage) : null,
    checks
  }
}

function localizeValidationIssue(issue) {
  const value = String(issue || '')
  const parts = value.split(':')
  const field = contentFieldLabel(parts[1])
  switch (parts[0]) {
    case 'empty_content': return '生成内容为空'
    case 'missing_source_refs': return `${field}没有关联任何资料来源`
    case 'unknown_source_ref': return `${field}引用了不存在的来源（${shortIdentifier(parts[2])}）`
    case 'source_role_mismatch': return `引用的来源不支持${field}（${shortIdentifier(parts[2])}）`
    case 'template_phrase': return `${field}包含模板化表达“${parts.slice(2).join(':')}”`
    case 'source_attribution': return `${field}正文出现“某平台认为”等来源转述，不符合成稿要求`
    case 'creation_story_without_reliable_source': return '创作故事缺少 A/B 级可靠资料依据'
    case 'high_risk_fact_without_required_sources': return '高风险事实缺少多个可靠来源交叉验证'
    case 'unverified_date': return `${field}出现未被资料验证的日期：${parts.slice(2).join(':')}`
    case 'excluded_identity_mentioned': return `正文混入了被排除的其他歌曲或版本：${parts.slice(1).join(':')}`
    case 'incomplete_song_identity': return '歌曲身份信息不完整，无法确认内容对应的具体录音版本'
    case 'cross_song_duplicate_content': return '生成内容与其他歌曲内容完全重复'
    default: return value || '未提供审核原因'
  }
}

function localizeRiskFlag(flag) {
  const labels = {
    creation_motive: '包含创作动机，需要可靠资料支持',
    exact_date: '包含精确日期，需要资料交叉验证',
    disputed_fact: '包含可能存在争议的事实',
    source_conflict: '不同资料来源之间存在冲突'
  }
  return labels[String(flag || '')] || `风险标记：${String(flag || '未知')}`
}

function adminAuditLog(log, store) {
  const action = AUDIT_ACTIONS[log.action] || ['管理操作', '后台数据发生变更']
  const details = []
  const validation = log.metadata?.validation
  for (const issue of validation?.errors || []) details.push({ label: '未通过原因', value: localizeValidationIssue(issue), tone: 'error' })
  for (const issue of validation?.warnings || []) details.push({ label: '审核提醒', value: localizeValidationIssue(issue), tone: 'warning' })
  if (validation?.sourceCoverage != null) details.push({ label: '来源覆盖率', value: `${Math.round(Number(validation.sourceCoverage) * 100)}%`, tone: 'neutral' })
  if (log.metadata?.attemptCount != null) details.push({ label: '任务尝试', value: `第 ${log.metadata.attemptCount} 次`, tone: 'neutral' })
  appendChangeDetails(details, log.before, log.after)
  return {
    ...log,
    title: action[0],
    summary: action[1],
    actorLabel: actorLabel(log.actorId),
    resourceLabel: auditResourceLabel(log, store),
    outcome: log.action === 'content.review.rejected' || log.action === 'content.reject' ? 'failed'
      : log.action === 'content.review.passed' || log.action === 'content.publish' ? 'success'
        : 'neutral',
    details
  }
}

function appendChangeDetails(details, before, after) {
  const statusLabels = { draft: '草稿', pending_review: '待审核', published: '已发布', rejected: '已驳回', offline: '已下线', confirmed: '已确认', provisional: '待确认', conflict: '有冲突' }
  if (before?.status || after?.status) {
    details.push({ label: '状态变化', value: `${statusLabels[before?.status] || before?.status || '无'} → ${statusLabels[after?.status] || after?.status || '无'}`, tone: 'neutral' })
  }
  if (after?.roleId) details.push({ label: '分配角色', value: adminRoleName(after.roleId), tone: 'neutral' })
  if (before?.grade || after?.grade) details.push({ label: '来源等级', value: `${before?.grade || '无'} → ${after?.grade || '无'}`, tone: 'neutral' })
}

function auditResourceLabel(log, store) {
  if (log.resourceType === 'song') return songLabel(store.hydrateSong(log.resourceId))
  if (log.resourceType === 'generation_job') {
    const job = store.getJob(log.resourceId)
    return job ? `${songLabel(store.hydrateSong(job.songId))}的生成任务` : `生成任务 ${shortIdentifier(log.resourceId)}`
  }
  if (log.resourceType === 'content_version') {
    const version = store.hydrateContentVersion(log.resourceId)
    return version ? `${songLabel(store.hydrateSong(version.songId))}的内容版本` : `内容版本 ${shortIdentifier(log.resourceId)}`
  }
  if (log.resourceType === 'admin_actor') return `后台操作者 ${log.resourceId}`
  return `${RESOURCE_LABELS[log.resourceType] || log.resourceType} ${shortIdentifier(log.resourceId)}`
}

function songLabel(song) {
  if (!song) return '未知歌曲'
  const artist = (song.artists || []).map((item) => item.name).filter(Boolean).join(' / ')
  return artist ? `《${song.title}》— ${artist}` : `《${song.title}》`
}

function actorLabel(value) {
  const labels = { 'automatic-review': '自动审核', 'automatic-policy': '自动发布策略', 'token-admin': '管理员', system: '系统' }
  return labels[value] || value || '系统'
}

function adminRoleName(id) {
  const labels = { 'content-editor': '内容编辑', 'content-reviewer': '内容审核', 'content-admin': '内容管理员' }
  return labels[id] || id
}

function contentFieldLabel(value) {
  return { songSummary: '歌曲介绍', creationStory: '创作故事', background: '乐评', albumSummary: '专辑介绍' }[value] || value || '内容'
}

function shortIdentifier(value) {
  const text = String(value || '未知')
  return text.length > 12 ? `${text.slice(0, 8)}…` : text
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

module.exports = {
  adminAuditLog,
  adminContentReview,
  adminReviewSummary,
  installSongContentAdminRoutes,
  localizeValidationIssue
}
