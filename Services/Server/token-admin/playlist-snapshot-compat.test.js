'use strict'

const assert = require('node:assert/strict')
const test = require('node:test')

const {
  AI_TRAINING_SAMPLES_VERSION,
  CLOUD_SNAPSHOT_VERSION,
  normalizeAudioAgentSkills,
  normalizeAIEqualizerSnapshot,
  resolveAudioAgentSkills,
  resolveAITrainingSamples,
  mergePlaylistSnapshotCompatibility,
  countAudioAgentSkills,
  countAITrainingSamples,
  hasAudioAgentSkillsData
} = require('./playlist-snapshot-compat')

const skills = {
  schemaVersion: 1,
  revision: 9,
  updatedAt: '2026-08-22T12:00:00.000Z',
  artistReferenceEnabled: false,
  vocalReferenceEnabled: true,
  customSkills: [{
    id: '8F8AB4B8-6738-44B8-9A33-74EC857A20C6',
    name: 'Night reference',
    instruction: 'Keep the center image stable.',
    isEnabled: true,
    createdAt: '2026-08-20T12:00:00.000Z',
    updatedAt: '2026-08-22T12:00:00.000Z',
    futureField: { preserved: true }
  }]
}

test('v5 is the current cloud snapshot protocol', () => {
  assert.equal(CLOUD_SNAPSHOT_VERSION, 5)
  assert.equal(AI_TRAINING_SAMPLES_VERSION, 5)
})

test('audioAgentSkills remains opaque during a server round trip', () => {
  assert.strictEqual(normalizeAudioAgentSkills(skills), skills)
  assert.deepEqual(normalizeAudioAgentSkills(skills), skills)
})

test('clients older than v4 cannot erase a stored skill snapshot by omission', () => {
  assert.strictEqual(resolveAudioAgentSkills(undefined, skills, 1), skills)
  assert.strictEqual(resolveAudioAgentSkills(undefined, skills, 2), skills)
  assert.strictEqual(resolveAudioAgentSkills(undefined, skills, 3), skills)
})

test('a v4 omission or null explicitly clears the skill snapshot', () => {
  assert.equal(resolveAudioAgentSkills(undefined, skills, 4), null)
  assert.equal(resolveAudioAgentSkills(null, skills, 4), null)
})

test('clients older than v5 cannot erase stored training samples by omission', () => {
  const samples = { proposal: { schemaVersion: 1 } }
  assert.strictEqual(resolveAITrainingSamples(undefined, samples, 4), samples)
  assert.equal(resolveAITrainingSamples(undefined, samples, 5), null)
})

test('v5 AI snapshot normalization keeps complete training samples', () => {
  const complete = {
    schemaVersion: 1,
    id: 'proposal-1',
    capturedAt: '2026-09-03T01:00:00.000Z',
    features: { integratedLUFS: -14, bandEnergyDB: Array(10).fill(-24) },
    target: { id: 'proposal-1', gains: Array(10).fill(0) }
  }
  const normalized = normalizeAIEqualizerSnapshot({
    cachedProposals: { song: { id: 'proposal-1' } },
    savedProposals: { song: [{ proposal: { id: 'proposal-1' } }] },
    trainingSamples: { 'proposal-1': complete }
  })

  assert.deepEqual(normalized.trainingSamples, { 'proposal-1': complete })
  assert.equal(normalized.savedProposals.song.length, 1)
  assert.equal(countAITrainingSamples(normalized), 1)
})

test('v4 AI normalization cannot erase nested v5 samples by omission', () => {
  const samples = { 'proposal-1': { schemaVersion: 1 } }
  const normalized = normalizeAIEqualizerSnapshot(
    { cachedProposals: {}, savedProposals: {} },
    { previousValue: { trainingSamples: samples }, clientVersion: 4 }
  )
  const cleared = normalizeAIEqualizerSnapshot(
    { cachedProposals: {}, savedProposals: {} },
    { previousValue: { trainingSamples: samples }, clientVersion: 5 }
  )

  assert.deepEqual(normalized.trainingSamples, samples)
  assert.equal(cleared, null)
})

test('compatibility merge preserves v5 samples while accepting an old client payload', () => {
  const samples = { proposal: { schemaVersion: 1 } }
  const merged = mergePlaylistSnapshotCompatibility(
    { version: 4, playlists: [], aiEqualizer: { cachedProposals: {}, savedProposals: {} } },
    { version: 5, aiEqualizer: { trainingSamples: samples } }
  )
  assert.deepEqual(merged.aiEqualizer.trainingSamples, samples)
  assert.deepEqual(merged.aiEqualizer.savedProposals, {})
})

test('summary counts explicit built-in overrides and custom skills', () => {
  assert.equal(countAudioAgentSkills(skills), 3)
  assert.equal(countAudioAgentSkills({ customSkills: [] }), 0)
  assert.equal(countAudioAgentSkills(null), 0)
})

test('skill-only snapshots are non-playlist cloud data', () => {
  assert.equal(hasAudioAgentSkillsData({ audioAgentSkills: skills }), true)
  assert.equal(hasAudioAgentSkillsData({ audioAgentSkills: {} }), true)
  assert.equal(hasAudioAgentSkillsData({ audioAgentSkills: null }), false)
  assert.equal(hasAudioAgentSkillsData({}), false)
})
