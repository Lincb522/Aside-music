#!/usr/bin/env bash
set -euo pipefail

database_path="${1:?usage: backup-song-content.sh DATABASE_PATH BACKUP_DIRECTORY}"
backup_directory="${2:?usage: backup-song-content.sh DATABASE_PATH BACKUP_DIRECTORY}"

if [[ ! -f "$database_path" ]]; then
  echo "database not found: $database_path" >&2
  exit 1
fi

mkdir -p "$backup_directory"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_path="$backup_directory/song-content-$timestamp.sqlite"

sqlite3 "$database_path" ".timeout 5000" ".backup '$backup_path'"
sqlite3 "$backup_path" "PRAGMA integrity_check;" | grep -qx "ok"
if command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "$backup_path" > "$backup_path.sha256"
else
  sha256sum "$backup_path" > "$backup_path.sha256"
fi

echo "$backup_path"
