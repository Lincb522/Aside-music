#!/usr/bin/env bash
set -euo pipefail

backup_path="${1:?usage: restore-song-content.sh BACKUP_PATH DATABASE_PATH --confirm-service-stopped}"
database_path="${2:?usage: restore-song-content.sh BACKUP_PATH DATABASE_PATH --confirm-service-stopped}"
confirmation="${3:-}"

if [[ "$confirmation" != "--confirm-service-stopped" ]]; then
  echo "refusing restore without --confirm-service-stopped" >&2
  exit 2
fi
if [[ ! -f "$backup_path" ]]; then
  echo "backup not found: $backup_path" >&2
  exit 1
fi

sqlite3 "$backup_path" "PRAGMA integrity_check;" | grep -qx "ok"
mkdir -p "$(dirname "$database_path")"
restore_path="$database_path.restore"
rm -f "$restore_path"
sqlite3 "$backup_path" ".backup '$restore_path'"
sqlite3 "$restore_path" "PRAGMA integrity_check;" | grep -qx "ok"

if [[ -f "$database_path" ]]; then
  mv "$database_path" "$database_path.before-restore-$(date -u +%Y%m%dT%H%M%SZ)"
fi
mv "$restore_path" "$database_path"

echo "$database_path"
