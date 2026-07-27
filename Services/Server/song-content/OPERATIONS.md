# Song Content Operations

## Required environment

- `SONG_CONTENT_MASTER_KEY`: high-entropy secret supplied by the deployment secret manager. Do not commit it or place it in client configuration.
- Existing token server database/data directory with write access for the service account.
- HTTPS termination on the existing token domain.
- Existing admin authentication, permission middleware, public token resolver, and rate limiter.

Production and test environments must use separate databases, credentials, and AI accounts.

## Pre-deployment gate

1. Back up the token service and its data directory.
2. Apply the module against a copy of production data; schema creation is additive.
3. Confirm the token server uses a Node version with `node:sqlite`.
4. Register platform metadata and source-collection adapters.
5. Assign separate `content-editor` and `content-reviewer` roles where the token server exposes individual administrator identities.
6. Write the provider credential, create a configuration draft, and publish it with rollout at `0%`.
7. Confirm the default-on first-access policy is acceptable. Add a disabled `song_content_whitelist` row only for songs that must be blocked from generation.
8. Verify no response from `/api/public/*` contains provider credentials, prompts, internal errors, or unreviewed content.
9. Verify HTTPS, rate limits, request IDs, ETag behavior, and client cache fallback.
10. Verify the announcement manifest contains no body, image URL or action URL, and detail requests require the exact display revision.

Do not overwrite existing token routes, DNS, certificates, or reverse-proxy configuration.

## Backup and restore

Create a consistent SQLite backup while the service is running:

```bash
./scripts/backup-song-content.sh /srv/token/song-content/song-content.sqlite /srv/backups/song-content
```

The script runs an integrity check and writes a SHA-256 checksum. Test restoration in an isolated directory before production use.

Restore only while the token service is stopped:

```bash
./scripts/restore-song-content.sh backup.sqlite /srv/token/song-content/song-content.sqlite --confirm-service-stopped
```

The restore script preserves the previous database beside the restored file.

## Monitoring

Authenticated endpoints:

- `/api/song-content/health`: database availability and current counters.
- `POST /api/song-content/maintenance`: runs `PRAGMA optimize` and a passive WAL checkpoint. Send `{ "vacuum": true }` only during a maintenance window.
- `/api/song-content/metrics`: Prometheus text metrics for queue, failures, token use, and cost.

Alert when:

- the health endpoint is unavailable for two consecutive checks;
- active jobs grow continuously for 10 minutes;
- failed jobs exceed the normal baseline;
- no job completes while the queue is non-empty;
- AI rate limits or timeouts rise sharply;
- pending review grows beyond reviewer capacity;
- backup age exceeds 24 hours or an integrity check fails.

## Rollout

1. `0%`: internal device whitelist only while validating a new configuration release.
2. `1%`: observe detail latency, generation duplication, publication failures, and App fallback.
3. `5%`, `20%`, `50%`: advance only after metrics remain stable for the agreed observation window.
4. `100%`: retain the previous configuration version for immediate rollback.

Rollback by publishing the previous configuration version. Content versions remain immutable; rolling back configuration does not delete published content.

## Incident response

- Provider or prompt fault: publish the previous configuration version.
- Incorrect content: take the affected version offline; ordinary users receive no draft replacement.
- Identity collision: disable the song whitelist entry and resolve mappings before retrying.
- Worker backlog: stop new rollout, inspect leases and provider errors, then retry failed jobs from the admin page.
- Credential exposure suspicion: replace the provider credential, rotate `SONG_CONTENT_MASTER_KEY` through a controlled migration, and review audit logs.
