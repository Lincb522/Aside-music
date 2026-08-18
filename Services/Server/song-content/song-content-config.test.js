const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')

const { createSongContentConfigStore } = require('./song-content-config')

test('默认配置只下发现有 Agent 及其升级版本', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'song-content-agent-config-'))
  const store = createSongContentConfigStore({
    databasePath: path.join(directory, 'song-content.sqlite'),
    logger: { info() {}, warn() {}, error() {} }
  })

  try {
    const release = store.current()
    assert.deepEqual(Object.keys(release.client.agents), [
      'equalizer',
      'listeningInsight',
      'specialGreeting'
    ])
    assert.equal(release.client.agents.equalizer.promptVersion, 'mono-audio-agent-v28')
    assert.equal(release.client.agents.listeningInsight.promptVersion, 'mono-listening-insight-v3')
    assert.equal(release.client.agents.specialGreeting.promptVersion, 'special-greeting-v2')
    assert.equal(release.ai.promptVersion, 'song-editor-web-v7')
  } finally {
    store.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
})

test('旧内置版本自动升级且 Agent 最大尝试次数会被约束', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'song-content-agent-upgrade-'))
  const store = createSongContentConfigStore({
    databasePath: path.join(directory, 'song-content.sqlite'),
    logger: { info() {}, warn() {}, error() {} }
  })

  try {
    const release = store.createDraft({
      actorId: 'test',
      ai: { promptVersion: 'song-editor-web-v6' },
      client: {
        agents: {
          equalizer: { promptVersion: 'mono-audio-agent-v27', maxAttempts: 99 },
          listeningInsight: { promptVersion: 'mono-listening-insight-v2', maxAttempts: 0 },
          specialGreeting: { promptVersion: 'special-greeting-v1', maxAttempts: 2 },
          obsoleteAgent: { promptVersion: 'removed-agent' }
        }
      }
    })

    assert.equal(release.ai.promptVersion, 'song-editor-web-v7')
    assert.equal(release.client.agents.equalizer.promptVersion, 'mono-audio-agent-v28')
    assert.equal(release.client.agents.equalizer.maxAttempts, 4)
    assert.equal(release.client.agents.listeningInsight.promptVersion, 'mono-listening-insight-v3')
    assert.equal(release.client.agents.listeningInsight.maxAttempts, 1)
    assert.equal(release.client.agents.specialGreeting.promptVersion, 'special-greeting-v2')
    assert.equal('obsoleteAgent' in release.client.agents, false)
  } finally {
    store.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
})
