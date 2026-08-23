'use strict'

const assert = require('node:assert/strict')
const test = require('node:test')

const {
  CLOUD_SNAPSHOT_VERSION,
  normalizeAudioAgentSkills,
  resolveAudioAgentSkills,
  countAudioAgentSkills,
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

test('v4 is the current cloud snapshot protocol', () => {
  assert.equal(CLOUD_SNAPSHOT_VERSION, 4)
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
