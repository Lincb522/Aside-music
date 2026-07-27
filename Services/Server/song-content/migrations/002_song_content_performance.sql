-- Read-path indexes for public song lookup, admin lists, and worker leasing.
CREATE INDEX IF NOT EXISTS songs_title_artist_idx
  ON songs(normalized_title, primary_artist_name);

CREATE INDEX IF NOT EXISTS song_content_versions_public_lookup_idx
  ON song_content_versions(song_id, locale, status, updated_at DESC);

CREATE INDEX IF NOT EXISTS song_content_publications_locale_song_idx
  ON song_content_publications(locale, song_id);

CREATE INDEX IF NOT EXISTS generation_jobs_result_idx
  ON generation_jobs(result_content_version_id)
  WHERE result_content_version_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS song_content_audit_logs_created_idx
  ON song_content_audit_logs(created_at DESC);

CREATE INDEX IF NOT EXISTS content_sources_access_grade_idx
  ON content_sources(accessible, grade, fetched_at DESC);
