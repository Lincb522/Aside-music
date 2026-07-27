-- Processing time measures one continuous worker attempt, never queue or retry delay.
UPDATE generation_jobs
SET started_at = NULL
WHERE state = 'queued';

-- Old recovered jobs kept their first lease timestamp across worker restarts.
-- Those historical durations cannot be reconstructed reliably, so hide them.
UPDATE generation_jobs
SET started_at = NULL
WHERE state IN ('completed', 'failed', 'review')
  AND started_at IS NOT NULL
  AND finished_at IS NOT NULL
  AND (julianday(finished_at) - julianday(started_at)) * 86400 > 3600;

-- Keep a currently running legacy job readable until its next lease refresh.
UPDATE generation_jobs
SET started_at = updated_at
WHERE state IN ('collecting', 'generating', 'validating')
  AND started_at IS NOT NULL
  AND (julianday('now') - julianday(started_at)) * 86400 > 3600;
