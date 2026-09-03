'use strict'

const AUDIO_AGENT_SKILLS_VERSION = 4
const AI_TRAINING_SAMPLES_VERSION = 5
const CLOUD_SNAPSHOT_VERSION = 5
const MAX_CLOUD_AI_CACHE_ENTRIES = 1_024
const MAX_CLOUD_AI_HISTORY_ENTRIES = 2_000
const MAX_CLOUD_AI_HISTORY_PER_SONG = 50
const MAX_CLOUD_AI_TRAINING_SAMPLES = MAX_CLOUD_AI_HISTORY_ENTRIES

function isPlainObject(value) {
  return Boolean(value && typeof value === 'object' && !Array.isArray(value))
}

// This payload is owned by the App. The server deliberately treats it as an
// opaque JSON object so additions within the v4 schema survive a round trip.
function normalizeAudioAgentSkills(value) {
  return isPlainObject(value) ? value : null
}

function resolveAudioAgentSkills(value, previousValue, clientVersion) {
  if (value === undefined && clientVersion < AUDIO_AGENT_SKILLS_VERSION) {
    return normalizeAudioAgentSkills(previousValue)
  }
  return normalizeAudioAgentSkills(value)
}

function normalizeAITrainingSamples(value) {
  return isPlainObject(value) ? value : null
}

// The token-admin host owns the surrounding playlist route, while this module
// owns the versioned AI payload contract. Keep the complete v5 sample beside
// its proposal instead of silently reducing the object to legacy outputs.
function normalizeAIEqualizerSnapshot(value, {
  previousValue = null,
  clientVersion = AI_TRAINING_SAMPLES_VERSION
} = {}) {
  if (!isPlainObject(value)) return null

  const cachedEntries = isPlainObject(value.cachedProposals)
    ? Object.entries(value.cachedProposals)
      .filter(([, proposal]) => isPlainObject(proposal))
      .slice(-MAX_CLOUD_AI_CACHE_ENTRIES)
    : []
  const cachedProposals = Object.fromEntries(cachedEntries)

  const savedProposals = {}
  let remaining = MAX_CLOUD_AI_HISTORY_ENTRIES
  if (isPlainObject(value.savedProposals)) {
    for (const [songIdentifier, entries] of Object.entries(value.savedProposals)) {
      if (remaining <= 0) break
      if (!Array.isArray(entries)) continue
      const normalized = entries
        .filter(isPlainObject)
        .slice(0, Math.min(MAX_CLOUD_AI_HISTORY_PER_SONG, remaining))
      if (!normalized.length) continue
      savedProposals[String(songIdentifier)] = normalized
      remaining -= normalized.length
    }
  }

  const metadataEntries = isPlainObject(value.proposalMetadata)
    ? Object.entries(value.proposalMetadata)
      .filter(([key, metadata]) => typeof key === 'string' && isPlainObject(metadata))
      .slice(-(MAX_CLOUD_AI_CACHE_ENTRIES + MAX_CLOUD_AI_HISTORY_ENTRIES))
    : []
  const proposalMetadata = Object.fromEntries(metadataEntries)

  const trainingValue = value.trainingSamples === undefined
    && clientVersion < AI_TRAINING_SAMPLES_VERSION
    ? previousValue?.trainingSamples
    : value.trainingSamples
  const trainingEntries = isPlainObject(trainingValue)
    ? Object.entries(trainingValue)
      .filter(([key, sample]) => typeof key === 'string' && isPlainObject(sample))
      .slice(-MAX_CLOUD_AI_TRAINING_SAMPLES)
    : []
  const trainingSamples = Object.fromEntries(trainingEntries)

  return cachedEntries.length
    || Object.keys(savedProposals).length
    || metadataEntries.length
    || trainingEntries.length
    ? {
        cachedProposals,
        savedProposals,
        ...(metadataEntries.length ? { proposalMetadata } : {}),
        ...(trainingEntries.length ? { trainingSamples } : {})
      }
    : null
}

function resolveAITrainingSamples(value, previousValue, clientVersion) {
  if (value === undefined && clientVersion < AI_TRAINING_SAMPLES_VERSION) {
    return normalizeAITrainingSamples(previousValue)
  }
  return normalizeAITrainingSamples(value)
}

function mergePlaylistSnapshotCompatibility(snapshot, previousSnapshot) {
  if (!isPlainObject(snapshot)) return snapshot
  const clientVersion = Number.isInteger(snapshot.version) ? snapshot.version : 1
  const merged = { ...snapshot }

  const skills = resolveAudioAgentSkills(
    snapshot.audioAgentSkills,
    previousSnapshot?.audioAgentSkills,
    clientVersion
  )
  if (skills) merged.audioAgentSkills = skills

  const samples = resolveAITrainingSamples(
    snapshot.aiEqualizer?.trainingSamples,
    previousSnapshot?.aiEqualizer?.trainingSamples,
    clientVersion
  )
  if (samples) {
    merged.aiEqualizer = isPlainObject(snapshot.aiEqualizer)
      ? { ...snapshot.aiEqualizer, trainingSamples: samples }
      : { trainingSamples: samples }
  }

  return merged
}

function countAudioAgentSkills(value) {
  if (!isPlainObject(value)) return 0
  return (typeof value.artistReferenceEnabled === 'boolean' ? 1 : 0)
    + (typeof value.vocalReferenceEnabled === 'boolean' ? 1 : 0)
    + (Array.isArray(value.customSkills) ? value.customSkills.length : 0)
}

function countAITrainingSamples(value) {
  return isPlainObject(value?.trainingSamples)
    ? Object.keys(value.trainingSamples).length
    : 0
}

function hasAudioAgentSkillsData(snapshot) {
  return isPlainObject(snapshot?.audioAgentSkills)
}

module.exports = {
  AUDIO_AGENT_SKILLS_VERSION,
  AI_TRAINING_SAMPLES_VERSION,
  CLOUD_SNAPSHOT_VERSION,
  normalizeAudioAgentSkills,
  resolveAudioAgentSkills,
  normalizeAITrainingSamples,
  normalizeAIEqualizerSnapshot,
  resolveAITrainingSamples,
  mergePlaylistSnapshotCompatibility,
  countAudioAgentSkills,
  countAITrainingSamples,
  hasAudioAgentSkillsData
}
