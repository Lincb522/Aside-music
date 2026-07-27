const test = require('node:test')
const assert = require('node:assert/strict')

const {
  acquireProviderCircuitPermit,
  applyOfficialEvidenceFallbacks,
  createProviderCircuit,
  localizePipelineError,
  mergeGeneratedContent,
  missingEvidenceBackedSections,
  parseRetryAfterSeconds,
  providerCapacityRetryAfterSeconds,
  publicProviderCircuitState,
  recordProviderFailure,
  recordProviderSuccess
} = require('./song-content-pipeline')

function content(overrides = {}) {
  return {
    songSummary: null,
    creationStory: null,
    background: null,
    albumSummary: null,
    sourceRefs: {
      songSummary: [],
      creationStory: [],
      background: [],
      albumSummary: []
    },
    confidence: 'insufficient',
    riskFlags: [],
    ...overrides
  }
}

test('只把正文确认支持的空栏目列为待补全', () => {
  const evidencePackage = {
    sources: [{ metadata: { contentRoles: ['songSummary', 'background'] } }]
  }

  assert.deepEqual(
    missingEvidenceBackedSections(content(), evidencePackage),
    ['songSummary', 'background']
  )
})

test('没有正文角色证据时不强制补写栏目', () => {
  const evidencePackage = {
    sources: [{ metadata: { contentRoles: [] } }]
  }

  assert.deepEqual(missingEvidenceBackedSections(content(), evidencePackage), [])
})

test('二次补全只覆盖新生成的栏目并保留首轮有效内容', () => {
  const primary = content({
    creationStory: '首轮创作故事',
    sourceRefs: {
      songSummary: [],
      creationStory: ['source-1'],
      background: [],
      albumSummary: []
    },
    confidence: 'medium'
  })
  const completion = content({
    songSummary: '补全后的歌曲介绍',
    creationStory: '二次生成不应覆盖首轮内容',
    sourceRefs: {
      songSummary: ['source-2'],
      creationStory: ['source-3'],
      background: [],
      albumSummary: []
    },
    confidence: 'high'
  })

  const merged = mergeGeneratedContent(primary, completion)
  assert.equal(merged.songSummary, '补全后的歌曲介绍')
  assert.equal(merged.creationStory, '首轮创作故事')
  assert.deepEqual(merged.sourceRefs.songSummary, ['source-2'])
  assert.deepEqual(merged.sourceRefs.creationStory, ['source-1'])
  assert.equal(merged.confidence, 'high')
})

test('AI 熔断到期后只允许一个半开探测并在成功后恢复', () => {
  const circuit = createProviderCircuit()
  const policy = { circuitBreakerFailures: 2, circuitBreakerRecoverySeconds: 30 }
  const timeoutError = { code: 'AI_TIMEOUT', retryable: true }

  recordProviderFailure(circuit, timeoutError, policy, null, 1_000)
  assert.equal(publicProviderCircuitState(circuit, 1_000).state, 'closed')
  recordProviderFailure(circuit, timeoutError, policy, null, 2_000)
  assert.deepEqual(publicProviderCircuitState(circuit, 2_000), {
    state: 'open',
    consecutiveFailures: 2,
    retryAfterSeconds: 30
  })

  assert.equal(acquireProviderCircuitPermit(circuit, 10_000).allowed, false)
  const probe = acquireProviderCircuitPermit(circuit, 32_000)
  assert.equal(probe.allowed, true)
  assert.equal(probe.halfOpen, true)
  assert.equal(acquireProviderCircuitPermit(circuit, 32_000).allowed, false)

  recordProviderSuccess(circuit)
  assert.deepEqual(publicProviderCircuitState(circuit, 32_000), {
    state: 'closed',
    consecutiveFailures: 0,
    retryAfterSeconds: 0
  })
})

test('内容格式错误不会错误打开上游可用性熔断', () => {
  const circuit = createProviderCircuit()
  recordProviderFailure(
    circuit,
    { code: 'INVALID_AI_OUTPUT', retryable: true },
    { circuitBreakerFailures: 1, circuitBreakerRecoverySeconds: 60 },
    null,
    1_000
  )
  assert.equal(publicProviderCircuitState(circuit, 1_000).state, 'closed')
})

test('Agent 后台错误信息使用中文文案', () => {
  assert.deepEqual(localizePipelineError('AI_CIRCUIT_OPEN', 'AI provider circuit breaker is open'), {
    title: 'AI 服务暂时不可用',
    detail: '服务保护已启动，恢复后会自动继续任务'
  })
})

test('服务端遵守 App AI 的最小间隔、小时和每日额度', () => {
  const now = Date.UTC(2026, 6, 27, 12, 0, 0)
  const policy = {
    requestsPerMinute: 60,
    providerUsageLimits: {
      minimumRequestInterval: 15,
      hourlyRequestLimit: 2,
      dailyRequestLimit: 3
    }
  }

  assert.equal(providerCapacityRetryAfterSeconds(policy, [now - 5_000], now), 10)
  assert.equal(
    providerCapacityRetryAfterSeconds(policy, [now - 3_500_000, now - 20_000], now),
    100
  )
  assert.equal(
    providerCapacityRetryAfterSeconds(policy, [now - 80_000_000, now - 70_000_000, now - 4_000_000], now),
    6_400
  )
})

test('读取上游 Retry-After 秒数和 HTTP 日期', () => {
  const now = Date.UTC(2026, 6, 27, 12, 0, 0)
  assert.equal(parseRetryAfterSeconds('45', now), 45)
  assert.equal(parseRetryAfterSeconds(new Date(now + 90_000).toUTCString(), now), 90)
  assert.equal(parseRetryAfterSeconds('', now), 0)
})

test('AI 留空时使用平台正式歌曲和专辑介绍兜底', () => {
  const fallback = applyOfficialEvidenceFallbacks(content({
    albumSummary: '没有有效来源引用的模型内容'
  }), {
    sources: [
      {
        id: 'song-source',
        grade: 'B',
        excerpt: '正式歌曲介绍',
        metadata: { platform: 'QCM', sourceType: 'song_description', contentRoles: ['songSummary'] }
      },
      {
        id: 'album-source',
        grade: 'B',
        excerpt: '正式专辑介绍',
        metadata: { platform: 'QCM', sourceType: 'album_description', contentRoles: ['albumSummary'] }
      }
    ]
  })

  assert.equal(fallback.songSummary, '正式歌曲介绍')
  assert.equal(fallback.albumSummary, '正式专辑介绍')
  assert.equal(fallback.creationStory, '正式专辑介绍')
  assert.deepEqual(fallback.sourceRefs.songSummary, ['song-source'])
  assert.deepEqual(fallback.sourceRefs.albumSummary, ['album-source'])
  assert.deepEqual(fallback.sourceRefs.creationStory, ['album-source'])
  assert.equal(fallback.confidence, 'medium')
})
