CREATE TABLE IF NOT EXISTS announcements (
  id TEXT PRIMARY KEY,
  display_revision INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'draft',
  category TEXT NOT NULL DEFAULT 'general',
  priority TEXT NOT NULL DEFAULT 'normal',
  title TEXT NOT NULL,
  summary TEXT,
  body TEXT NOT NULL,
  image_url TEXT,
  action_title TEXT,
  action_url TEXT,
  min_app_version TEXT,
  max_app_version TEXT,
  platforms_json TEXT NOT NULL DEFAULT '["ios"]',
  locales_json TEXT NOT NULL DEFAULT '[]',
  starts_at TEXT,
  ends_at TEXT,
  requires_acknowledgement INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  published_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_announcements_status_window
ON announcements(status, starts_at, ends_at, published_at);
