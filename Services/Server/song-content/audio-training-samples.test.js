'use strict'

const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const test = require('node:test')

const {
  MAX_SAMPLES_PER_ACCOUNT,
  MAX_SAMPLES_PER_REQUEST,
  createTrainingSampleStore,
  installTrainingSampleRoutes,
  normalizeSample
} = require('./audio-training-samples')
const { collectDataset } = require('./audio-tuning-training')

function proposal(id, mode = 'tenBand') {
  return {
    id,
    graphicEQMode: mode,
    gains: Array.from({ length: mode === 'thirtyTwoBand' ? 32 : 10 }, (_, index) => index * 0.1),
    preampDB: -1,
    tone: { bassGain: 0.2, trebleGain: -0.1 },
    spatial: { surroundLevel: 0.1, reverbLevel: 0.05, stereoWidth: 1.05 },
    enhance: { isEnabled: true },
    calibration: {},
    professional: { processingIntensity: 0.3, dynamicEQ: {}, multiband: {}, parametricEQ: {} },
    effects: { finalLimiterEnabled: true, finalLimiterCeilingDB: -1 },
    tuningIntensity: 'strong',
    tuningProfile: 'standard',
    provider: 'openAICompatible',
    model: 'gpt-5.6-sol',
    skillCompliance: { accepted: true, localValidationApplied: true, executionMode: 'requiredModelTool' }
  }
}

function uuid(index) {
  return `00000000-0000-4000-8000-${String(index).padStart(12, '0')}`
}

function sample(index, mode = 'tenBand') {
  const id = uuid(index)
  return {
    schemaVersion: 4,
    id,
    songIdentifier: `netease:${index}`,
    capturedAt: `2026-09-03T12:${String(index % 60).padStart(2, '0')}:00.000Z`,
    features: {
      graphicEQMode: mode,
      bandEnergyDB: Array(mode === 'thirtyTwoBand' ? 32 : 10).fill(-24),
      genreScores: { pop: 0.7 },
      integratedLUFS: -14,
      outputKind: 'bluetooth'
    },
    deviceContext: { referenceGainsDB: Array(10).fill(0) },
    target: proposal(id, mode),
    populationTarget: proposal(id, mode),
    secretNote: 'must not be stored'
  }
}

function withStore(fn) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'mono-training-samples-'))
  const store = createTrainingSampleStore({ directory, logger: { error() {} } })
  try {
    return fn(store, directory)
  } finally {
    store.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
}

test('normalizeSample keeps only whitelisted keys and rejects self-generated targets', () => {
  const ok = normalizeSample(sample(1))
  assert.ok(ok.sample)
  assert.equal(ok.sample.secretNote, undefined)
  assert.equal(ok.sample.id, uuid(1))
  assert.equal(ok.sample.songIdentifier, 'netease:1')

  const machine = sample(2)
  machine.target.provider = 'appleIntelligence'
  machine.target.skillCompliance.executionMode = 'trainedCoreMLModel'
  assert.equal(normalizeSample(machine).error, 'SELF_GENERATED')

  const mismatched = sample(3)
  mismatched.target.id = uuid(99)
  assert.equal(normalizeSample(mismatched).error, 'TARGET_ID_MISMATCH')

  const unvalidated = sample(4)
  unvalidated.target.skillCompliance.accepted = false
  assert.equal(normalizeSample(unvalidated).error, 'TARGET_NOT_VALIDATED')

  assert.equal(normalizeSample({ id: 'not-a-uuid' }).error, 'INVALID_ID')
})

test('human corrections to local predictions are accepted without accepting unreviewed output', () => {
  for (const mode of ['tenBand', 'thirtyTwoBand']) {
    const value = sample(10, mode)
    value.target.provider = 'appleIntelligence'
    value.target.skillCompliance.executionMode = 'trainedCoreMLModel'
    value.feedback = 'manualEqualizer'
    value.manualGainsDB = value.target.gains.map((gain) => gain + 1)
    assert.ok(normalizeSample(value).sample)
    value.manualGainsDB = [...value.target.gains]
    assert.equal(normalizeSample(value).error, 'SELF_GENERATED')
    value.manualGainsDB[0] = NaN
    assert.ok(normalizeSample(value).error)
    value.feedback = 'positive'
    delete value.manualGainsDB
    assert.equal(normalizeSample(value).error, 'SELF_GENERATED')
  }
})

test('rejecting an uploaded human edit withdraws it from training instead of leaving a stale label', () => {
  withStore((store) => {
    const value = sample(12)
    value.target.model = 'mono-resonance-s1-test'
    value.feedback = 'manualEqualizer'
    value.manualGainsDB = value.target.gains.map((gain) => gain + 1)
    value.outcomeUpdatedAt = '2026-09-05T12:00:00.000Z'
    assert.equal(store.ingest('token-a', [value]).stored, 1)
    const options = { includeVectors: true, trainingSampleDatabasePath: store.databasePath }
    assert.equal(collectDataset(null, options).stats.manualCorrectedSamples, 1)
    value.feedback = 'negative'
    value.outcomeUpdatedAt = '2026-09-05T12:00:01.000Z'
    assert.equal(store.ingest('token-a', [value]).updated, 1)
    const collected = collectDataset(null, options)
    assert.equal(collected.stats.trainableSamples, 0)
    assert.equal(collected.stats.excludedOutcomeSamples, 1)
    assert.equal(collected.stats.legacyPlans, 0)
  })
})

test('ingest stores, updates by freshness and enforces per-request and per-account caps', () => {
  withStore((store) => {
    const first = store.ingest('token-a', [sample(1), sample(2)])
    assert.equal(first.stored, 2)
    assert.equal(first.rejected.length, 0)
    assert.equal(first.accountSampleCount, 2)

    // Stale re-upload is a no-op; a newer outcome updates the row.
    const stale = store.ingest('token-a', [sample(1)])
    assert.deepEqual(stale.accepted, [{ id: uuid(1), state: 'unchanged' }])
    const outcome = { ...sample(1), feedback: 'retained', outcomeUpdatedAt: '2026-09-03T13:00:00.000Z' }
    const updated = store.ingest('token-a', [outcome])
    assert.equal(updated.updated, 1)
    assert.equal(store.summary('token-a').samples.find((item) => item.id === uuid(1)).feedback, 'retained')

    assert.throws(
      () => store.ingest('token-a', Array.from({ length: MAX_SAMPLES_PER_REQUEST + 1 }, (_, index) => sample(100 + index))),
      /单次最多上传/
    )

    // Hourly rate limit: new samples beyond the budget are rejected, not stored.
    let stored = 2
    for (let batch = 0; batch < 12; batch += 1) {
      const result = store.ingest('token-a', Array.from({ length: 16 }, (_, index) => sample(1000 + batch * 16 + index)))
      stored += result.stored
    }
    assert.equal(stored, 120)
    const limited = store.ingest('token-a', [sample(5000)])
    assert.deepEqual(limited.rejected, [{ id: uuid(5000), reason: 'RATE_LIMITED' }])
    assert.equal(limited.stored, 0)

    // Per-account cap evicts the oldest unconfirmed samples once exceeded.
    let clock = Date.parse('2026-09-04T00:00:00.000Z')
    for (let batch = 0; stored < MAX_SAMPLES_PER_ACCOUNT + 20; batch += 1) {
      clock += 3_600_000
      const result = store.ingest(
        'token-a',
        Array.from({ length: 16 }, (_, index) => sample(9000 + batch * 16 + index)),
        { now: new Date(clock) }
      )
      stored += result.stored
    }
    assert.equal(store.summary('token-a').sampleCount, MAX_SAMPLES_PER_ACCOUNT)
    assert.ok(store.summary('token-a').samples.some((item) => item.id === uuid(1)), 'confirmed samples survive eviction')
    assert.equal(store.deleteAccount('token-a'), MAX_SAMPLES_PER_ACCOUNT)
    assert.equal(store.summary('token-a').sampleCount, 0)
  })
})

test('global byte budget evicts oldest unconfirmed samples across accounts', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'mono-training-budget-'))
  const store = createTrainingSampleStore({ directory, globalByteBudget: 6_000, logger: { error() {} } })
  try {
    store.ingest('token-a', [sample(1), sample(2), sample(3)])
    store.ingest('token-b', [sample(4), sample(5), sample(6)])
    const stats = store.stats()
    assert.ok(stats.byteCount <= 6_000, `byte budget respected (${stats.byteCount})`)
    assert.ok(stats.sampleCount < 6)
  } finally {
    store.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
})

test('dataset collection merges intake samples with snapshot plans and account-only samples', () => {
  withStore((store, directory) => {
    const { DatabaseSync } = require('node:sqlite')
    const cloudPath = path.join(directory, 'cloud-storage.sqlite')
    const database = new DatabaseSync(cloudPath)
    database.exec('CREATE TABLE cloud_snapshots (token_id TEXT PRIMARY KEY, snapshot_json TEXT NOT NULL)')
    const embedded = sample(1)
    embedded.feedback = 'unverified'
    const plan = proposal(uuid(7))
    database.prepare('INSERT INTO cloud_snapshots VALUES (?, ?)').run('token-a', JSON.stringify({
      aiEqualizer: {
        cachedProposals: {},
        savedProposals: {
          [embedded.songIdentifier]: [{ id: embedded.id, proposal: embedded.target }],
          'netease:7': [{ id: plan.id, proposal: plan }]
        },
        trainingSamples: { [embedded.id]: embedded }
      }
    }))
    database.close()

    // Same sample later confirmed through the intake; plus an account that never
    // uploaded a snapshot at all.
    store.ingest('token-a', [{ ...sample(1), feedback: 'retained', outcomeUpdatedAt: '2026-09-03T14:00:00.000Z' }])
    store.ingest('token-b', [sample(2), sample(3, 'thirtyTwoBand')])

    const { stats, examples } = collectDataset(cloudPath, {
      includeVectors: true,
      trainingSampleDatabasePath: store.databasePath
    })
    assert.equal(stats.completeSamples, 3)
    assert.equal(stats.completeAccounts, 2)
    assert.equal(stats.legacyPlans, 1)
    assert.equal(stats.feedbackConfirmedSamples, 1, 'intake outcome overrides the stale embedded copy')
    assert.equal(stats.thirtyTwoBandSamples, 1)
    assert.equal(examples.filter((item) => item.source === 'complete').length, 3)
    assert.equal(new Set(examples.map((item) => item.accountId)).size, 2)
  })
})

test('training sample routes are mounted behind the public token middleware', () => {
  const registrations = []
  const app = {
    put(pathname, ...handlers) { registrations.push({ method: 'put', pathname, handlers }) },
    get(pathname, ...handlers) { registrations.push({ method: 'get', pathname, handlers }) },
    delete(pathname, ...handlers) { registrations.push({ method: 'delete', pathname, handlers }) }
  }
  const middleware = (_req, _res, next) => next()
  installTrainingSampleRoutes({ app, store: {}, publicAccessMiddleware: middleware, publicRateLimit: middleware })
  assert.deepEqual(registrations.map((item) => `${item.method} ${item.pathname}`), [
    'put /api/account/training-samples',
    'get /api/account/training-samples',
    'delete /api/account/training-samples'
  ])
  for (const item of registrations) {
    assert.equal(item.handlers[0], middleware)
    assert.equal(item.handlers[1], middleware)
  }
})
