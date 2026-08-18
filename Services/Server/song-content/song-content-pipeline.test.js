const test = require('node:test')
const assert = require('node:assert/strict')

const {
  acquireProviderCircuitPermit,
  applyOfficialEvidenceFallbacks,
  compactEvidencePackage,
  createProviderCircuit,
  evidenceBackedSectionsNeedingCompletion,
  estimateGenerationInputTokens,
  localizePipelineError,
  mergeGeneratedContent,
  missingEvidenceBackedSections,
  parseRetryAfterSeconds,
  providerCapacityRetryAfterSeconds,
  publicProviderCircuitState,
  recordAutomaticReview,
  recordProviderFailure,
  recordProviderSuccess,
  shouldAttemptCompletion
} = require('./song-content-pipeline')

test('自动审核结果写入包含具体校验原因的审计记录', () => {
  const records = []
  recordAutomaticReview({ appendAudit: (record) => records.push(record) }, {
    job: { id: 'job-1', attemptCount: 2 },
    song: { id: 'song-1', title: '测试歌曲' },
    validation: {
      errors: ['missing_source_refs:songSummary'],
      warnings: ['creation_story_without_reliable_source'],
      sourceCoverage: 0.5
    },
    passed: false
  })

  assert.equal(records.length, 1)
  assert.equal(records[0].action, 'content.review.rejected')
  assert.equal(records[0].resourceId, 'job-1')
  assert.deepEqual(records[0].metadata.validation.errors, ['missing_source_refs:songSummary'])
  assert.equal(records[0].metadata.attemptCount, 2)
})

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

test('有角色证据时会二次增强明显过短的栏目', () => {
  const evidencePackage = {
    sources: [{ metadata: { contentRoles: ['songSummary', 'background'] } }]
  }
  const value = content({
    songSummary: '过短的歌曲介绍。',
    background: '过短的乐评。'
  })

  assert.deepEqual(
    evidenceBackedSectionsNeedingCompletion(value, evidencePackage),
    ['songSummary', 'background']
  )
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

test('二次增强只在新内容更完整时替换指定栏目', () => {
  const primary = content({
    songSummary: '首轮较短介绍',
    sourceRefs: { songSummary: ['source-1'], creationStory: [], background: [], albumSummary: [] }
  })
  const completion = content({
    songSummary: '补充了发行关系、作品定位和声音线索的更完整歌曲介绍。',
    sourceRefs: { songSummary: ['source-2'], creationStory: [], background: [], albumSummary: [] }
  })

  const merged = mergeGeneratedContent(primary, completion, ['songSummary'])
  assert.equal(merged.songSummary, completion.songSummary)
  assert.deepEqual(merged.sourceRefs.songSummary, ['source-2'])
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

test('生成前压缩证据正文并保留各内容角色的来源', () => {
  const roles = ['songSummary', 'creationStory', 'background', 'albumSummary']
  const evidencePackage = {
    canonicalSongId: 'song-1',
    platformMappings: { NCM: { platformSongId: '1', rawPayload: '不应进入提示词'.repeat(2_000) } },
    identity: {
      title: '测试歌曲',
      artists: [{ name: '测试歌手' }],
      album: { name: '测试专辑' }
    },
    locale: 'zh-Hans',
    schemaVersion: '3',
    platformSummary: '平台介绍'.repeat(2_000),
    albumSummary: '专辑介绍'.repeat(2_000),
    sources: roles.map((role, index) => ({
      id: `source-${index}`,
      title: `${role} 来源`,
      publisher: '测试来源',
      url: `https://example.com/${index}`,
      grade: 'B',
      excerpt: `${role} 正文`.repeat(4_000),
      metadata: {
        contentRoles: [role],
        contentRoleConfidence: { [role]: 0.9 },
        contentRoleEvidence: { [role]: ['命中依据'.repeat(100)] },
        rawHTML: '不应进入提示词'.repeat(2_000)
      }
    })),
    exclusions: [],
    rules: {}
  }

  const compacted = compactEvidencePackage(evidencePackage, {
    maxInputTokens: 2_048,
    systemPromptText: '系统要求',
    contentPromptText: '内容要求'
  })

  assert.deepEqual(
    new Set(compacted.sources.flatMap((source) => source.metadata.contentRoles)),
    new Set(roles)
  )
  assert.equal(compacted.platformMappings.NCM.rawPayload, undefined)
  assert.equal(compacted.sources[0].metadata.rawHTML, undefined)
  assert.ok(estimateGenerationInputTokens(compacted, {
    systemPromptText: '系统要求',
    contentPromptText: '内容要求'
  }) <= 2_048)
})

test('首轮已超总预算时保留结果但不再发起补全请求', () => {
  assert.equal(shouldAttemptCompletion({
    taskTokenLimit: 20_000,
    usedTokens: 21_000,
    estimatedInputTokens: 2_000,
    maxOutputTokens: 4_000
  }), false)
  assert.equal(shouldAttemptCompletion({
    taskTokenLimit: 20_000,
    usedTokens: 8_000,
    estimatedInputTokens: 3_000,
    maxOutputTokens: 4_000
  }), true)
  assert.equal(shouldAttemptCompletion({
    taskTokenLimit: 0,
    usedTokens: 100_000,
    estimatedInputTokens: 20_000,
    maxOutputTokens: 10_000
  }), true)
})
