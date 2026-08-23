'use strict'

const CLOUD_SNAPSHOT_VERSION = 4

function isPlainObject(value) {
  return Boolean(value && typeof value === 'object' && !Array.isArray(value))
}

// This payload is owned by the App. The server deliberately treats it as an
// opaque JSON object so additions within the v4 schema survive a round trip.
function normalizeAudioAgentSkills(value) {
  return isPlainObject(value) ? value : null
}

function resolveAudioAgentSkills(value, previousValue, clientVersion) {
  if (value === undefined && clientVersion < CLOUD_SNAPSHOT_VERSION) {
    return normalizeAudioAgentSkills(previousValue)
  }
  return normalizeAudioAgentSkills(value)
}

function countAudioAgentSkills(value) {
  if (!isPlainObject(value)) return 0
  return (typeof value.artistReferenceEnabled === 'boolean' ? 1 : 0)
    + (typeof value.vocalReferenceEnabled === 'boolean' ? 1 : 0)
    + (Array.isArray(value.customSkills) ? value.customSkills.length : 0)
}

function hasAudioAgentSkillsData(snapshot) {
  return isPlainObject(snapshot?.audioAgentSkills)
}

module.exports = {
  CLOUD_SNAPSHOT_VERSION,
  normalizeAudioAgentSkills,
  resolveAudioAgentSkills,
  countAudioAgentSkills,
  hasAudioAgentSkillsData
}
