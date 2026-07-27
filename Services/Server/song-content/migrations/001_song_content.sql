PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS songs (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  normalized_title TEXT NOT NULL,
  primary_artist_id TEXT,
  primary_artist_name TEXT NOT NULL,
  artists_json TEXT NOT NULL DEFAULT '[]',
  album_id TEXT,
  album_name TEXT,
  duration_ms INTEGER,
  release_date_value TEXT,
  release_date_precision TEXT,
  isrc TEXT,
  version_label TEXT,
  cover_url TEXT,
  identity_status TEXT NOT NULL DEFAULT 'provisional'
    CHECK (identity_status IN ('confirmed', 'provisional', 'conflict')),
  current_published_content_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS songs_isrc_idx ON songs(isrc) WHERE isrc IS NOT NULL;
CREATE INDEX IF NOT EXISTS songs_identity_status_idx ON songs(identity_status);

CREATE TABLE IF NOT EXISTS platform_song_mappings (
  id TEXT PRIMARY KEY,
  song_id TEXT NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  platform TEXT NOT NULL,
  platform_song_id TEXT NOT NULL,
  platform_artist_id TEXT,
  platform_album_id TEXT,
  raw_title TEXT NOT NULL,
  raw_artist TEXT NOT NULL,
  raw_album TEXT,
  raw_metadata_json TEXT NOT NULL DEFAULT '{}',
  match_method TEXT NOT NULL,
  match_confidence REAL NOT NULL,
  verified_by TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(platform, platform_song_id)
);

CREATE INDEX IF NOT EXISTS platform_song_mappings_song_idx
  ON platform_song_mappings(song_id);

CREATE TABLE IF NOT EXISTS content_sources (
  id TEXT PRIMARY KEY,
  url TEXT NOT NULL,
  canonical_url TEXT NOT NULL,
  title TEXT NOT NULL,
  publisher TEXT NOT NULL,
  published_at TEXT,
  fetched_at TEXT NOT NULL,
  grade TEXT NOT NULL CHECK (grade IN ('A', 'B', 'C', 'D')),
  excerpt TEXT,
  content_hash TEXT NOT NULL,
  accessible INTEGER NOT NULL DEFAULT 1,
  metadata_json TEXT NOT NULL DEFAULT '{}',
  UNIQUE(canonical_url, content_hash)
);

CREATE INDEX IF NOT EXISTS content_sources_grade_idx ON content_sources(grade);

CREATE TABLE IF NOT EXISTS song_content_versions (
  id TEXT PRIMARY KEY,
  song_id TEXT NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  locale TEXT NOT NULL,
  schema_version TEXT NOT NULL,
  song_summary TEXT,
  creation_story TEXT,
  background TEXT,
  album_summary TEXT,
  source_refs_json TEXT NOT NULL DEFAULT '{}',
  confidence TEXT NOT NULL CHECK (confidence IN ('high', 'medium', 'insufficient')),
  risk_flags_json TEXT NOT NULL DEFAULT '[]',
  validation_json TEXT NOT NULL DEFAULT '{}',
  status TEXT NOT NULL
    CHECK (status IN ('draft', 'pending_review', 'published', 'offline', 'rejected')),
  model_provider TEXT,
  model_name TEXT,
  prompt_version TEXT,
  content_hash TEXT NOT NULL,
  generated_at TEXT NOT NULL,
  published_at TEXT,
  published_by TEXT,
  supersedes_id TEXT REFERENCES song_content_versions(id),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS song_content_versions_song_idx
  ON song_content_versions(song_id, locale, schema_version, created_at DESC);
CREATE INDEX IF NOT EXISTS song_content_versions_status_idx
  ON song_content_versions(status, updated_at DESC);
CREATE INDEX IF NOT EXISTS song_content_versions_hash_idx
  ON song_content_versions(content_hash);

CREATE TABLE IF NOT EXISTS song_content_publications (
  song_id TEXT NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  locale TEXT NOT NULL,
  current_content_version_id TEXT NOT NULL REFERENCES song_content_versions(id) ON DELETE RESTRICT,
  published_at TEXT NOT NULL,
  published_by TEXT,
  PRIMARY KEY(song_id, locale)
);

CREATE TABLE IF NOT EXISTS content_version_sources (
  content_version_id TEXT NOT NULL REFERENCES song_content_versions(id) ON DELETE CASCADE,
  source_id TEXT NOT NULL REFERENCES content_sources(id) ON DELETE RESTRICT,
  supported_fields_json TEXT NOT NULL DEFAULT '[]',
  PRIMARY KEY(content_version_id, source_id)
);

CREATE TABLE IF NOT EXISTS generation_jobs (
  id TEXT PRIMARY KEY,
  idempotency_key TEXT NOT NULL,
  song_id TEXT NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  locale TEXT NOT NULL,
  schema_version TEXT NOT NULL,
  reason TEXT NOT NULL DEFAULT 'first_access',
  state TEXT NOT NULL
    CHECK (state IN ('queued', 'collecting', 'generating', 'validating', 'review', 'completed', 'failed')),
  attempt_count INTEGER NOT NULL DEFAULT 0,
  max_attempts INTEGER NOT NULL DEFAULT 3,
  available_at TEXT NOT NULL,
  lease_owner TEXT,
  lease_expires_at TEXT,
  error_code TEXT,
  error_message TEXT,
  token_input INTEGER,
  token_output INTEGER,
  cost REAL,
  provider_request_id TEXT,
  result_content_version_id TEXT REFERENCES song_content_versions(id),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  started_at TEXT,
  finished_at TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS generation_jobs_active_key_unique
  ON generation_jobs(idempotency_key)
  WHERE state IN ('queued', 'collecting', 'generating', 'validating', 'review');
CREATE INDEX IF NOT EXISTS generation_jobs_claim_idx
  ON generation_jobs(state, available_at, lease_expires_at, created_at);

CREATE TABLE IF NOT EXISTS generation_job_sources (
  job_id TEXT NOT NULL REFERENCES generation_jobs(id) ON DELETE CASCADE,
  source_id TEXT NOT NULL REFERENCES content_sources(id) ON DELETE RESTRICT,
  PRIMARY KEY(job_id, source_id)
);

CREATE TABLE IF NOT EXISTS song_content_whitelist (
  song_id TEXT PRIMARY KEY REFERENCES songs(id) ON DELETE CASCADE,
  enabled INTEGER NOT NULL DEFAULT 1,
  note TEXT,
  created_by TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS song_content_audit_logs (
  id TEXT PRIMARY KEY,
  actor_id TEXT,
  action TEXT NOT NULL,
  resource_type TEXT NOT NULL,
  resource_id TEXT NOT NULL,
  request_id TEXT,
  before_json TEXT,
  after_json TEXT,
  metadata_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS song_content_audit_logs_resource_idx
  ON song_content_audit_logs(resource_type, resource_id, created_at DESC);

CREATE TABLE IF NOT EXISTS song_content_roles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS song_content_role_permissions (
  role_id TEXT NOT NULL REFERENCES song_content_roles(id) ON DELETE CASCADE,
  permission TEXT NOT NULL,
  PRIMARY KEY(role_id, permission)
);

CREATE TABLE IF NOT EXISTS song_content_admin_assignments (
  external_actor_id TEXT NOT NULL,
  role_id TEXT NOT NULL REFERENCES song_content_roles(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  PRIMARY KEY(external_actor_id, role_id)
);

INSERT OR IGNORE INTO song_content_roles (id, name, created_at)
VALUES ('content-editor', '内容编辑', CURRENT_TIMESTAMP),
       ('content-reviewer', '内容审核', CURRENT_TIMESTAMP),
       ('content-admin', '内容管理员', CURRENT_TIMESTAMP);

INSERT OR IGNORE INTO song_content_role_permissions (role_id, permission)
VALUES ('content-editor', 'content.read'),
       ('content-editor', 'content.edit'),
       ('content-reviewer', 'content.read'),
       ('content-reviewer', 'content.publish'),
       ('content-reviewer', 'content.rollback'),
       ('content-reviewer', 'content.offline'),
       ('content-admin', 'content.read'),
       ('content-admin', 'content.edit'),
       ('content-admin', 'content.publish'),
       ('content-admin', 'content.rollback'),
       ('content-admin', 'content.offline'),
       ('content-admin', 'jobs.manage'),
       ('content-admin', 'sources.manage'),
       ('content-admin', 'songs.manage'),
       ('content-admin', 'audit.read'),
       ('content-admin', 'config.manage'),
       ('content-admin', 'config.publish'),
       ('content-admin', 'credentials.write'),
       ('content-admin', 'roles.manage');

CREATE TABLE IF NOT EXISTS ai_provider_credentials (
  id TEXT PRIMARY KEY,
  provider TEXT NOT NULL,
  label TEXT NOT NULL,
  encrypted_secret TEXT NOT NULL,
  key_version TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  rotated_by TEXT,
  UNIQUE(provider, label)
);

CREATE TABLE IF NOT EXISTS song_content_config_versions (
  id TEXT PRIMARY KEY,
  version INTEGER NOT NULL UNIQUE,
  status TEXT NOT NULL CHECK (status IN ('draft', 'published', 'retired')),
  ai_config_json TEXT NOT NULL DEFAULT '{}',
  client_config_json TEXT NOT NULL DEFAULT '{}',
  created_by TEXT,
  created_at TEXT NOT NULL,
  published_by TEXT,
  published_at TEXT
);

CREATE TABLE IF NOT EXISTS song_content_config_publication (
  singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
  current_version_id TEXT NOT NULL REFERENCES song_content_config_versions(id) ON DELETE RESTRICT,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS song_content_config_validations (
  id TEXT PRIMARY KEY,
  config_version_id TEXT NOT NULL REFERENCES song_content_config_versions(id) ON DELETE CASCADE,
  passed INTEGER NOT NULL,
  result_json TEXT NOT NULL,
  validated_by TEXT,
  validated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS song_content_config_validations_version_idx
  ON song_content_config_validations(config_version_id, validated_at DESC);
