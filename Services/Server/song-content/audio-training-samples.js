'use strict'

// Dedicated, bounded intake for complete tuning training samples.
//
// Samples used to ride along inside the account's full playlist snapshot,
// which meant they only reached the server when the (up to 10 MB) snapshot was
// re-uploaded, at most once per 8-hour slot, and only for accounts with
// automatic playlist sync enabled. This store accepts small batches right after
// a proposal is produced, keeps every row in SQLite instead of process memory,
// and enforces per-request, per-account and global limits so 200+ accounts
// cannot grow the training set without bound.

const fs = require('node:fs')
const path = require('node:path')

const SUPPORTED_SCHEMA_VERSIONS = new Set([1, 2, 3, 4])
const MAX_SAMPLES_PER_REQUEST = 16
const MAX_SAMPLE_BYTES = 64 * 1024
const MAX_REQUEST_BYTES = MAX_SAMPLES_PER_REQUEST * MAX_SAMPLE_BYTES + 4096
const MAX_SAMPLES_PER_ACCOUNT = 600
const MAX_SAMPLES_PER_ACCOUNT_PER_HOUR = 120
const DEFAULT_GLOBAL_BYTE_BUDGET = 512 * 1024 * 1024
const ALLOWED_SAMPLE_KEYS = new Set([
  'schemaVersion', 'id', 'songIdentifier', 'capturedAt', 'features', 'deviceContext',
  'target', 'populationTarget', 'learningContext', 'personalizedTarget',
  'feedback', 'listenedSeconds', 'outcomeUpdatedAt', 'manualGainsDB'
])
const FEEDBACK_VALUES = new Set([
  'positive', 'retained', 'manualEqualizer', 'negative', 'reset', 'regenerated'
])
const SELF_GENERATED_EXECUTION_MODES = new Set([
  'trainedCoreMLModel', 'appleIntelligenceLocalCompiler'
])
const SELF_GENERATED_MODEL_PREFIXES = ['mono-audio-', 'mono-resonance-']
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

function createTrainingSampleStore({
  directory,
  databasePath,
  globalByteBudget = DEFAULT_GLOBAL_BYTE_BUDGET,
  logger = console
}) {
  const { DatabaseSync } = require('node:sqlite')
  const resolvedPath = databasePath || path.join(directory, 'training-samples.sqlite')
  fs.mkdirSync(path.dirname(resolvedPath), { recursive: true })
  const database = new DatabaseSync(resolvedPath)
  database.exec(`
    PRAGMA journal_mode = WAL;
    PRAGMA synchronous = NORMAL;
    PRAGMA busy_timeout = 5000;
    CREATE TABLE IF NOT EXISTS training_samples (
      token_id TEXT NOT NULL,
      sample_id TEXT NOT NULL,
      schema_version INTEGER NOT NULL,
      graphic_eq_mode TEXT NOT NULL,
      tuning_profile TEXT NOT NULL,
      feedback TEXT,
      captured_at TEXT,
      outcome_updated_at TEXT,
      byte_count INTEGER NOT NULL,
      sample_json TEXT NOT NULL,
      received_at TEXT NOT NULL,
      PRIMARY KEY (token_id, sample_id)
    );
    CREATE INDEX IF NOT EXISTS training_samples_received_idx
      ON training_samples(token_id, received_at);
    CREATE INDEX IF NOT EXISTS training_samples_captured_idx
      ON training_samples(captured_at);
  `)
  const statements = {
    select: database.prepare('SELECT * FROM training_samples WHERE token_id = ? AND sample_id = ?'),
    upsert: database.prepare(`INSERT INTO training_samples
      (token_id, sample_id, schema_version, graphic_eq_mode, tuning_profile, feedback,
       captured_at, outcome_updated_at, byte_count, sample_json, received_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(token_id, sample_id) DO UPDATE SET
        schema_version = excluded.schema_version,
        graphic_eq_mode = excluded.graphic_eq_mode,
        tuning_profile = excluded.tuning_profile,
        feedback = excluded.feedback,
        captured_at = excluded.captured_at,
        outcome_updated_at = excluded.outcome_updated_at,
        byte_count = excluded.byte_count,
        sample_json = excluded.sample_json,
        received_at = excluded.received_at`),
    accountCount: database.prepare('SELECT COUNT(*) AS n, COALESCE(SUM(byte_count), 0) AS bytes FROM training_samples WHERE token_id = ?'),
    accountRecentCount: database.prepare('SELECT COUNT(*) AS n FROM training_samples WHERE token_id = ? AND received_at >= ?'),
    accountOldest: database.prepare(`SELECT sample_id FROM training_samples WHERE token_id = ?
      ORDER BY CASE WHEN feedback IN ('positive','retained','manualEqualizer') THEN 1 ELSE 0 END,
               COALESCE(captured_at, received_at) ASC LIMIT ?`),
    deleteOne: database.prepare('DELETE FROM training_samples WHERE token_id = ? AND sample_id = ?'),
    deleteAccount: database.prepare('DELETE FROM training_samples WHERE token_id = ?'),
    globalStats: database.prepare('SELECT COUNT(*) AS n, COALESCE(SUM(byte_count), 0) AS bytes, COUNT(DISTINCT token_id) AS accounts FROM training_samples'),
    globalOldest: database.prepare(`SELECT token_id, sample_id, byte_count FROM training_samples
      ORDER BY CASE WHEN feedback IN ('positive','retained','manualEqualizer') THEN 1 ELSE 0 END,
               COALESCE(captured_at, received_at) ASC LIMIT ?`),
    iterateAll: database.prepare('SELECT token_id, sample_json FROM training_samples ORDER BY token_id'),
    listAccount: database.prepare('SELECT sample_id, feedback, captured_at, outcome_updated_at, byte_count FROM training_samples WHERE token_id = ? ORDER BY COALESCE(captured_at, received_at) DESC')
  }

  function ingest(tokenId, samples, { now = new Date(), skipRateLimit = false } = {}) {
    const token = String(tokenId || '').trim()
    if (!token) throw storeError('INVALID_TOKEN', '账号标识无效。', 400)
    if (!Array.isArray(samples)) throw storeError('INVALID_PAYLOAD', 'samples 必须是数组。', 400)
    if (!skipRateLimit && samples.length > MAX_SAMPLES_PER_REQUEST) {
      throw storeError('TOO_MANY_SAMPLES', `单次最多上传 ${MAX_SAMPLES_PER_REQUEST} 条样本。`, 413)
    }
    const nowISO = now.toISOString()
    const hourAgo = new Date(now.getTime() - 3_600_000).toISOString()
    const recent = statements.accountRecentCount.get(token, hourAgo).n
    const accepted = []
    const rejected = []
    let stored = 0
    let updated = 0
    let hourlyBudget = skipRateLimit
      ? Number.POSITIVE_INFINITY
      : Math.max(0, MAX_SAMPLES_PER_ACCOUNT_PER_HOUR - recent)

    database.exec('BEGIN IMMEDIATE')
    try {
      for (const raw of samples) {
        const result = normalizeSample(raw)
        if (result.error) {
          rejected.push({ id: result.id, reason: result.error })
          continue
        }
        const { sample, id } = result
        const existing = statements.select.get(token, id)
        if (existing) {
          const incomingStamp = sample.outcomeUpdatedAt || sample.capturedAt || ''
          const existingStamp = existing.outcome_updated_at || existing.captured_at || ''
          if (incomingStamp <= existingStamp) {
            accepted.push({ id, state: 'unchanged' })
            continue
          }
        } else {
          if (hourlyBudget <= 0) {
            rejected.push({ id, reason: 'RATE_LIMITED' })
            continue
          }
          hourlyBudget -= 1
        }
        const json = JSON.stringify(sample)
        if (json.length > MAX_SAMPLE_BYTES) {
          rejected.push({ id, reason: 'SAMPLE_TOO_LARGE' })
          continue
        }
        statements.upsert.run(
          token, id, sample.schemaVersion,
          sample.features.graphicEQMode === 'thirtyTwoBand' ? 'thirtyTwoBand' : 'tenBand',
          sample.target.tuningProfile === 'monoSpatialEnhancement' ? 'monoSpatialEnhancement' : 'standard',
          sample.feedback || null,
          sample.capturedAt || null,
          sample.outcomeUpdatedAt || null,
          json.length,
          json,
          nowISO
        )
        if (existing) updated += 1
        else stored += 1
        accepted.push({ id, state: existing ? 'updated' : 'stored' })
      }
      // Per-account cap: drop the oldest unconfirmed samples first.
      const count = statements.accountCount.get(token).n
      if (count > MAX_SAMPLES_PER_ACCOUNT) {
        for (const row of statements.accountOldest.all(token, count - MAX_SAMPLES_PER_ACCOUNT)) {
          statements.deleteOne.run(token, row.sample_id)
        }
      }
      // Global budget: evict oldest unconfirmed samples across accounts.
      let stats = statements.globalStats.get()
      let guard = 0
      while (stats.bytes > globalByteBudget && guard < 64) {
        for (const row of statements.globalOldest.all(32)) {
          statements.deleteOne.run(row.token_id, row.sample_id)
        }
        stats = statements.globalStats.get()
        guard += 1
      }
      database.exec('COMMIT')
    } catch (error) {
      try { database.exec('ROLLBACK') } catch (_) {}
      throw error
    }
    const account = statements.accountCount.get(token)
    return {
      accepted,
      rejected,
      stored,
      updated,
      accountSampleCount: account.n,
      accountByteCount: account.bytes
    }
  }

  function summary(tokenId) {
    const token = String(tokenId || '').trim()
    const account = statements.accountCount.get(token)
    return {
      sampleCount: account.n,
      byteCount: account.bytes,
      samples: statements.listAccount.all(token).map((row) => ({
        id: row.sample_id,
        feedback: row.feedback,
        capturedAt: row.captured_at,
        outcomeUpdatedAt: row.outcome_updated_at,
        byteCount: row.byte_count
      }))
    }
  }

  function deleteAccount(tokenId) {
    const token = String(tokenId || '').trim()
    if (!token) return 0
    return Number(statements.deleteAccount.run(token).changes || 0)
  }

  function * iterate() {
    for (const row of statements.iterateAll.iterate()) {
      const sample = parseJSON(row.sample_json)
      if (sample) yield { tokenId: row.token_id, sample }
    }
  }

  function stats() {
    const row = statements.globalStats.get()
    return { sampleCount: row.n, byteCount: row.bytes, accountCount: row.accounts, byteBudget: globalByteBudget }
  }

  function close() {
    try { database.exec('PRAGMA wal_checkpoint(TRUNCATE)') } catch (_) {}
    database.close()
  }

  return { databasePath: resolvedPath, ingest, summary, deleteAccount, iterate, stats, close }
}

// Returns { sample, id } for a structurally valid, human-supervised sample or
// { id, error } otherwise. Only whitelisted keys are retained.
function normalizeSample(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return { id: null, error: 'INVALID_SAMPLE' }
  const id = String(raw.id || '').trim().toLowerCase()
  if (!UUID_PATTERN.test(id)) return { id: id || null, error: 'INVALID_ID' }
  const schemaVersion = Number(raw.schemaVersion)
  if (!SUPPORTED_SCHEMA_VERSIONS.has(schemaVersion)) return { id, error: 'UNSUPPORTED_SCHEMA' }
  const features = raw.features
  const target = raw.target
  if (!isObject(features) || !isObject(target)) return { id, error: 'MISSING_FEATURES_OR_TARGET' }
  if (String(target.id || '').toLowerCase() !== id) return { id, error: 'TARGET_ID_MISMATCH' }
  const bandCount = features.graphicEQMode === 'thirtyTwoBand' ? 32 : 10
  if (!isFiniteArray(features.bandEnergyDB, bandCount)) return { id, error: 'INVALID_BAND_ENERGY' }
  if (!isFiniteArray(target.gains, bandCount)) return { id, error: 'INVALID_TARGET_GAINS' }
  if (target.skillCompliance?.accepted !== true || target.skillCompliance?.localValidationApplied !== true) {
    return { id, error: 'TARGET_NOT_VALIDATED' }
  }
  if (isSelfGeneratedProposal(target) && !hasHumanCorrection(raw, bandCount)) {
    return { id, error: 'SELF_GENERATED' }
  }
  for (const key of ['populationTarget', 'personalizedTarget']) {
    if (raw[key] !== undefined && raw[key] !== null) {
      if (!isObject(raw[key]) || !isFiniteArray(raw[key].gains, bandCount)) return { id, error: `INVALID_${key.toUpperCase()}` }
    }
  }
  if (raw.feedback !== undefined && raw.feedback !== null && !FEEDBACK_VALUES.has(String(raw.feedback))) {
    return { id, error: 'INVALID_FEEDBACK' }
  }
  if (raw.manualGainsDB !== undefined && raw.manualGainsDB !== null && !isFiniteArray(raw.manualGainsDB, bandCount)) {
    return { id, error: 'INVALID_MANUAL_GAINS' }
  }
  const capturedAt = isoOrNull(raw.capturedAt)
  const outcomeUpdatedAt = isoOrNull(raw.outcomeUpdatedAt)
  const sample = {}
  for (const key of ALLOWED_SAMPLE_KEYS) {
    if (raw[key] !== undefined && raw[key] !== null) sample[key] = raw[key]
  }
  sample.id = id
  sample.schemaVersion = schemaVersion
  if (capturedAt) sample.capturedAt = capturedAt
  else delete sample.capturedAt
  if (outcomeUpdatedAt) sample.outcomeUpdatedAt = outcomeUpdatedAt
  else delete sample.outcomeUpdatedAt
  sample.songIdentifier = String(raw.songIdentifier || '').slice(0, 256)
  return { sample, id }
}

function isSelfGeneratedProposal(proposal) {
  if (!isObject(proposal)) return false
  if (SELF_GENERATED_EXECUTION_MODES.has(String(proposal.skillCompliance?.executionMode || ''))) return true
  const model = String(proposal.model || '').toLowerCase()
  if (SELF_GENERATED_MODEL_PREFIXES.some((prefix) => model.startsWith(prefix))) return true
  return String(proposal.provider || '') === 'appleIntelligence'
}

// Only an actual listener edit supplies new supervision for a local model.
// Positive/retained feedback alone must not turn its prediction into a label.
function manualGainDelta(sample, bandCount) {
  if (sample?.feedback !== 'manualEqualizer') return null
  return editedGainDelta(sample, bandCount)
}

function hasHumanCorrection(sample, bandCount) {
  // A later rejection must be able to withdraw a previously uploaded edit.
  return ['manualEqualizer', 'negative', 'reset', 'regenerated'].includes(sample?.feedback)
    && editedGainDelta(sample, bandCount) !== null
}

function editedGainDelta(sample, bandCount) {
  const manual = sample.manualGainsDB
  const heard = sample.target?.gains
  if (!isFiniteArray(manual, bandCount) || !isFiniteArray(heard, bandCount)) return null
  const delta = manual.map((value, index) => Math.max(-12, Math.min(12, value - heard[index])))
  return delta.some((value) => Math.abs(value) > 0.05) ? delta : null
}

function installTrainingSampleRoutes({ app, store, publicAccessMiddleware, publicRateLimit, logger = console }) {
  if (typeof publicAccessMiddleware !== 'function') return
  const guards = [publicAccessMiddleware]
  if (typeof publicRateLimit === 'function') guards.unshift(publicRateLimit)
  const tokenIdOf = (req) => {
    const token = req.songContentCredential?.token
    return String(token?.id || token?.key || '').trim()
  }

  app.put('/api/account/training-samples', ...guards, (req, res) => {
    const declared = Number(req.headers['content-length'] || 0)
    if (declared > MAX_REQUEST_BYTES) {
      return res.status(413).json({ ok: false, code: 'PAYLOAD_TOO_LARGE', error: '样本请求过大。' })
    }
    try {
      const result = store.ingest(tokenIdOf(req), req.body?.samples)
      res.set('Cache-Control', 'private, no-store')
      res.json({ ok: true, ...result })
    } catch (error) {
      logger.error('[training-samples] ingest failed:', error?.message || error)
      res.status(error.statusCode || 500).json({
        ok: false,
        code: error.code || 'TRAINING_SAMPLE_INGEST_FAILED',
        error: error.message || '样本上传失败。'
      })
    }
  })

  app.get('/api/account/training-samples', ...guards, (req, res) => {
    res.set('Cache-Control', 'private, no-store')
    res.json({ ok: true, ...store.summary(tokenIdOf(req)) })
  })

  app.delete('/api/account/training-samples', ...guards, (req, res) => {
    const deleted = store.deleteAccount(tokenIdOf(req))
    res.json({ ok: true, deleted })
  })
}

function isObject(value) {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value)
}

function isFiniteArray(value, length) {
  return Array.isArray(value) && value.length === length && value.every((item) => Number.isFinite(Number(item)))
}

function isoOrNull(value) {
  if (typeof value !== 'string' || !value) return null
  const time = Date.parse(value)
  return Number.isFinite(time) ? new Date(time).toISOString() : null
}

function parseJSON(value) {
  try { return JSON.parse(value) } catch (_) { return null }
}

function storeError(code, message, statusCode) {
  const error = new Error(message)
  error.code = code
  error.statusCode = statusCode
  return error
}

module.exports = {
  MAX_SAMPLES_PER_ACCOUNT,
  MAX_SAMPLES_PER_REQUEST,
  MAX_SAMPLE_BYTES,
  createTrainingSampleStore,
  installTrainingSampleRoutes,
  isSelfGeneratedProposal,
  manualGainDelta,
  hasHumanCorrection,
  normalizeSample
}
