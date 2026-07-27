const fs = require('node:fs')
const path = require('node:path')

/** Shared SQLite migration and maintenance engine for song-content stores. */
function createSongContentDatabaseEngine({ database, databasePath, migrationsDirectory, logger = console }) {
  if (!database) throw new TypeError('database is required')

  database.exec(`
    CREATE TABLE IF NOT EXISTS song_content_schema_migrations (
      version TEXT PRIMARY KEY,
      applied_at TEXT NOT NULL
    );
  `)

  const migrationFiles = fs.readdirSync(migrationsDirectory)
    .filter(file => /^\d+_.*\.sql$/.test(file))
    .sort()

  for (const file of migrationFiles) {
    database.exec('BEGIN IMMEDIATE')
    try {
      const applied = database.prepare(
        'SELECT 1 AS applied FROM song_content_schema_migrations WHERE version = ?'
      ).get(file)
      if (applied) {
        database.exec('COMMIT')
        continue
      }
      database.exec(fs.readFileSync(path.join(migrationsDirectory, file), 'utf8'))
      database.prepare(
        'INSERT INTO song_content_schema_migrations (version, applied_at) VALUES (?, ?)'
      ).run(file, new Date().toISOString())
      database.exec('COMMIT')
    } catch (error) {
      try { database.exec('ROLLBACK') } catch (_) {}
      throw error
    }
  }

  function inspect() {
    const integrity = database.prepare('PRAGMA quick_check(1)').get()
    const pageCount = database.prepare('PRAGMA page_count').get()
    const pageSize = database.prepare('PRAGMA page_size').get()
    return {
      databasePath,
      integrity: integrity?.quick_check || 'unknown',
      pageCount: Number(pageCount?.page_count || 0),
      pageSize: Number(pageSize?.page_size || 0),
      migrations: migrationFiles.length
    }
  }

  function optimize({ checkpoint = false, vacuum = false } = {}) {
    if (checkpoint) database.exec('PRAGMA wal_checkpoint(PASSIVE)')
    database.exec('PRAGMA optimize')
    if (vacuum) database.exec('VACUUM')
    return inspect()
  }

  function close() {
    try { database.exec('PRAGMA wal_checkpoint(TRUNCATE)') } catch (error) {
      logger.warn?.('[song-content-db] checkpoint failed', error)
    }
  }

  return { inspect, optimize, close }
}

module.exports = { createSongContentDatabaseEngine }
