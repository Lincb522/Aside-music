const path = require('path')

function createCloudSnapshotStore({ directory, cacheEntries = 8, logger = console }) {
  const { DatabaseSync } = require('node:sqlite')
  const databasePath = path.join(directory, 'cloud-storage.sqlite')
  const database = new DatabaseSync(databasePath)

  database.exec(`
    PRAGMA journal_mode = WAL;
    PRAGMA synchronous = NORMAL;
    PRAGMA busy_timeout = 5000;
    CREATE TABLE IF NOT EXISTS cloud_snapshots (
      token_id TEXT PRIMARY KEY,
      snapshot_json TEXT NOT NULL,
      revision TEXT,
      version INTEGER,
      updated_at TEXT,
      stored_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS cloud_snapshots_updated_at_idx
      ON cloud_snapshots(updated_at);
  `)

  const selectSnapshot = database.prepare(`
    SELECT snapshot_json
    FROM cloud_snapshots
    WHERE token_id = ?
  `)
  const selectMetadata = database.prepare(`
    SELECT revision, version, updated_at
    FROM cloud_snapshots
    WHERE token_id = ?
  `)
  const upsertSnapshot = database.prepare(`
    INSERT INTO cloud_snapshots (
      token_id, snapshot_json, revision, version, updated_at, stored_at
    ) VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT(token_id) DO UPDATE SET
      snapshot_json = excluded.snapshot_json,
      revision = excluded.revision,
      version = excluded.version,
      updated_at = excluded.updated_at,
      stored_at = excluded.stored_at
  `)
  const deleteSnapshotStatement = database.prepare(`
    DELETE FROM cloud_snapshots WHERE token_id = ?
  `)
  const storageStats = database.prepare(`
    SELECT
      COUNT(*) AS snapshot_count,
      COALESCE(SUM(length(CAST(snapshot_json AS BLOB))), 0) AS snapshot_bytes
    FROM cloud_snapshots
  `)

  const attachedTokens = new WeakSet()
  const cache = new Map()

  function normalizedTokenId(token) {
    return String(token?.id || token?.key || '').trim()
  }

  function cacheSnapshot(tokenId, snapshot) {
    cache.delete(tokenId)
    cache.set(tokenId, snapshot)
    while (cache.size > cacheEntries) {
      const oldestKey = cache.keys().next().value
      cache.delete(oldestKey)
    }
  }

  function readSnapshot(tokenId) {
    if (cache.has(tokenId)) {
      const cached = cache.get(tokenId)
      cache.delete(tokenId)
      cache.set(tokenId, cached)
      return cached
    }

    const row = selectSnapshot.get(tokenId)
    if (!row) return null
    try {
      const snapshot = JSON.parse(row.snapshot_json)
      cacheSnapshot(tokenId, snapshot)
      return snapshot
    } catch (error) {
      logger.error(`[cloud-storage] Token ${tokenId} 快照解析失败:`, error.message)
      return null
    }
  }

  function writeSnapshot(tokenId, snapshot) {
    if (snapshot === null || snapshot === undefined) {
      deleteSnapshotStatement.run(tokenId)
      cache.delete(tokenId)
      return
    }

    const payload = JSON.stringify(snapshot)
    upsertSnapshot.run(
      tokenId,
      payload,
      snapshot.revision || null,
      Number.isInteger(snapshot.version) ? snapshot.version : null,
      snapshot.updatedAt || null,
      new Date().toISOString()
    )
    cacheSnapshot(tokenId, snapshot)
  }

  function attachToken(token) {
    if (!token || attachedTokens.has(token)) return { attached: false, migrated: false }
    const tokenId = normalizedTokenId(token)
    if (!tokenId) return { attached: false, migrated: false }

    const descriptor = Object.getOwnPropertyDescriptor(token, 'playlistSnapshot')
    const legacySnapshot = descriptor && Object.prototype.hasOwnProperty.call(descriptor, 'value')
      ? descriptor.value
      : undefined

    let migrated = false
    if (legacySnapshot !== null && legacySnapshot !== undefined && !selectMetadata.get(tokenId)) {
      writeSnapshot(tokenId, legacySnapshot)
      migrated = true
    }

    delete token.playlistSnapshot
    Object.defineProperty(token, 'playlistSnapshot', {
      configurable: true,
      enumerable: false,
      get() {
        return readSnapshot(tokenId)
      },
      set(value) {
        writeSnapshot(tokenId, value)
      }
    })
    attachedTokens.add(token)
    return { attached: true, migrated }
  }

  function prepareData(data) {
    if (!Array.isArray(data?.tokens)) return { attached: 0, migrated: 0 }
    let attached = 0
    let migrated = 0
    database.exec('BEGIN IMMEDIATE')
    try {
      for (const token of data.tokens) {
        const result = attachToken(token)
        if (result.attached) attached += 1
        if (result.migrated) migrated += 1
      }
      database.exec('COMMIT')
      if (migrated > 0) database.exec('PRAGMA wal_checkpoint(TRUNCATE)')
    } catch (error) {
      database.exec('ROLLBACK')
      throw error
    }
    return { attached, migrated }
  }

  function stats() {
    const row = storageStats.get()
    return {
      snapshotCount: Number(row?.snapshot_count || 0),
      snapshotBytes: Number(row?.snapshot_bytes || 0),
      cachedSnapshots: cache.size,
      databasePath
    }
  }

  function close() {
    try { database.exec('PRAGMA wal_checkpoint(TRUNCATE)') } catch (_) {}
    database.close()
  }

  return {
    attachToken,
    prepareData,
    stats,
    close,
    databasePath
  }
}

module.exports = { createCloudSnapshotStore }
