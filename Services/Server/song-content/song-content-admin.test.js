const test = require('node:test')
const assert = require('node:assert/strict')

const {
  adminAuditLog,
  adminReviewSummary,
  installSongContentAdminRoutes,
  localizeValidationIssue
} = require('./song-content-admin')

test('自动审核错误转换为中文原因', () => {
  assert.equal(localizeValidationIssue('missing_source_refs:songSummary'), '歌曲介绍没有关联任何资料来源')
  assert.equal(localizeValidationIssue('creation_story_without_reliable_source'), '创作故事缺少 A/B 级可靠资料依据')
  assert.equal(localizeValidationIssue('unverified_date:albumSummary:2026-07-28'), '专辑介绍出现未被资料验证的日期：2026-07-28')
})

test('审核摘要保留全部错误与警告', () => {
  const summary = adminReviewSummary({
    passed: false,
    errors: ['source_attribution:songSummary'],
    warnings: ['high_risk_fact_without_required_sources'],
    sourceCoverage: 0.75
  })
  assert.equal(summary.passed, false)
  assert.equal(summary.sourceCoverage, 0.75)
  assert.deepEqual(summary.checks.map((item) => item.severity), ['error', 'warning'])
  assert.match(summary.checks[0].message, /歌曲介绍/)
})

test('审计日志给出歌曲和自动审核未通过原因', () => {
  const store = {
    getJob: () => ({ id: 'job-1', songId: 'song-1' }),
    hydrateSong: () => ({ title: '测试歌曲', artists: [{ name: '测试歌手' }] }),
    hydrateContentVersion: () => null
  }
  const log = adminAuditLog({
    action: 'content.review.rejected',
    actorId: 'automatic-review',
    resourceType: 'generation_job',
    resourceId: 'job-1',
    metadata: {
      attemptCount: 1,
      validation: { errors: ['missing_source_refs:songSummary'], warnings: [], sourceCoverage: 0.5 }
    }
  }, store)

  assert.equal(log.title, '自动审核未通过')
  assert.equal(log.actorLabel, '自动审核')
  assert.match(log.resourceLabel, /测试歌曲/)
  assert.equal(log.details[0].value, '歌曲介绍没有关联任何资料来源')
})

test('注册客户端所需的任务详情接口', () => {
  const paths = []
  const app = {
    get: (path) => paths.push(`GET ${path}`),
    post: () => {},
    put: () => {}
  }
  installSongContentAdminRoutes({
    app,
    service: { store: {} },
    authMiddleware: (_req, _res, next) => next()
  })
  assert.ok(paths.includes('GET /api/song-content/jobs/:jobId'))
})
