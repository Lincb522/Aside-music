#!/usr/bin/env node
'use strict'

// One-time migration: copy training samples embedded in account playlist
// snapshots into the dedicated training-sample store. Snapshots are read-only;
// nothing is removed from them. Re-running is safe (upsert by freshness).
//
//   node scripts/migrate-embedded-training-samples.js --data-dir /www/wwwroot/token-admin [--dry-run]

const path = require('node:path')
const { createTrainingSampleStore } = require('../audio-training-samples')

function main() {
  const args = process.argv.slice(2)
  const dataDirectory = args[args.indexOf('--data-dir') + 1]
  const dryRun = args.includes('--dry-run')
  if (!dataDirectory || args.indexOf('--data-dir') < 0) {
    console.error('usage: migrate-embedded-training-samples.js --data-dir <dir> [--dry-run]')
    process.exit(2)
  }
  const { DatabaseSync } = require('node:sqlite')
  const cloud = new DatabaseSync(path.join(dataDirectory, 'cloud-storage.sqlite'), { readOnly: true })
  const store = dryRun ? null : createTrainingSampleStore({ directory: dataDirectory })
  let accounts = 0
  let seen = 0
  let stored = 0
  let updated = 0
  let rejected = 0
  const reasons = new Map()
  try {
    for (const row of cloud.prepare('SELECT token_id, snapshot_json FROM cloud_snapshots').iterate()) {
      let snapshot
      try { snapshot = JSON.parse(row.snapshot_json) } catch (_) { continue }
      const samples = Object.values(snapshot?.aiEqualizer?.trainingSamples || {})
      if (!samples.length) continue
      accounts += 1
      seen += samples.length
      if (dryRun) continue
      for (let start = 0; start < samples.length; start += 64) {
        const result = store.ingest(String(row.token_id), samples.slice(start, start + 64), { skipRateLimit: true })
        stored += result.stored
        updated += result.updated
        rejected += result.rejected.length
        for (const item of result.rejected) reasons.set(item.reason, (reasons.get(item.reason) || 0) + 1)
      }
    }
  } finally {
    cloud.close()
    store?.close()
  }
  console.log(JSON.stringify({ dryRun, accounts, seen, stored, updated, rejected, reasons: Object.fromEntries(reasons) }))
}

main()
