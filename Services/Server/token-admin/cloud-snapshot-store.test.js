'use strict'

const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const test = require('node:test')

const { createCloudSnapshotStore } = require('./cloud-snapshot-store')

test('a legacy client update cannot erase v5 training samples', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'mono-cloud-snapshot-'))
  try {
    const store = createCloudSnapshotStore({ directory, logger: { error() {} } })
    const token = { id: 'account-1' }
    store.attachToken(token)
    token.playlistSnapshot = {
      version: 5,
      playlists: [],
      aiEqualizer: { trainingSamples: { sample: { schemaVersion: 1 } } }
    }
    token.playlistSnapshot = {
      version: 4,
      playlists: [],
      aiEqualizer: { cachedProposals: {}, savedProposals: {} }
    }
    assert.deepEqual(
      token.playlistSnapshot.aiEqualizer.trainingSamples,
      { sample: { schemaVersion: 1 } }
    )
    store.close()
  } finally {
    fs.rmSync(directory, { recursive: true, force: true })
  }
})
