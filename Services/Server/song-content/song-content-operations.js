function installSongContentOperationsRoutes({ app, service, authMiddleware, authorize }) {
  if (typeof authMiddleware !== 'function') return
  const permitted = (permission) => typeof authorize === 'function'
    ? authorize(permission)
    : (_req, _res, next) => next()

  app.get('/api/song-content/health', authMiddleware, permitted('content.read'), (_req, res) => {
    try {
      const stats = service.store.dashboardStats()
      const database = typeof service.store.databaseInspect === 'function'
        ? service.store.databaseInspect()
        : { integrity: 'ok' }
      const healthy = stats.failedJobs < 100 && database.integrity === 'ok'
      res.status(healthy ? 200 : 503).json({
        ok: healthy,
        database: 'available',
        databaseInfo: database,
        worker: stats.activeJobs >= 0 ? 'observable' : 'unknown',
        stats,
        checkedAt: new Date().toISOString()
      })
    } catch (_) {
      res.status(503).json({ ok: false, database: 'unavailable', checkedAt: new Date().toISOString() })
    }
  })

  app.get('/api/song-content/metrics', authMiddleware, permitted('audit.read'), (_req, res) => {
    const stats = service.store.dashboardStats()
    res.type('text/plain; version=0.0.4').send([
      '# HELP song_content_songs_total Canonical songs known to the service.',
      '# TYPE song_content_songs_total gauge',
      `song_content_songs_total ${stats.songs}`,
      '# HELP song_content_pending_review Content versions waiting for review.',
      '# TYPE song_content_pending_review gauge',
      `song_content_pending_review ${stats.pendingReview}`,
      '# HELP song_content_jobs_active Generation jobs in a non-terminal worker state.',
      '# TYPE song_content_jobs_active gauge',
      `song_content_jobs_active ${stats.activeJobs}`,
      '# HELP song_content_jobs_failed Generation jobs in failed state.',
      '# TYPE song_content_jobs_failed gauge',
      `song_content_jobs_failed ${stats.failedJobs}`,
      '# HELP song_content_ai_tokens_total AI token usage by direction.',
      '# TYPE song_content_ai_tokens_total counter',
      `song_content_ai_tokens_total{direction="input"} ${stats.tokenInput}`,
      `song_content_ai_tokens_total{direction="output"} ${stats.tokenOutput}`,
      '# HELP song_content_ai_cost_total Recorded AI provider cost.',
      '# TYPE song_content_ai_cost_total counter',
      `song_content_ai_cost_total ${stats.cost}`,
      ''
    ].join('\n'))
  })

  app.post('/api/song-content/maintenance', authMiddleware, permitted('jobs.manage'), (req, res) => {
    try {
      const maintenance = service.store.databaseOptimize({
        checkpoint: req.body?.checkpoint !== false,
        vacuum: req.body?.vacuum === true
      })
      res.json({ ok: true, maintenance, completedAt: new Date().toISOString() })
    } catch (error) {
      res.status(503).json({ ok: false, error: 'database maintenance failed' })
    }
  })
}

module.exports = { installSongContentOperationsRoutes }
