(function () {
  const Admin = window.TokenAdmin
  const state = {
    activeView: 'config',
    selectedVersionId: null,
    review: null
  }

  const els = {}
  const agentKeys = ['equalizer', 'listeningInsight', 'specialGreeting', 'stageDirector', 'wallpaperTranslator']
  const agentDefaults = {
    equalizer: { promptVersion: 'mono-audio-agent-v27', temperature: 0.1, maxOutputTokens: 4096, minimumTimeoutSeconds: 120 },
    listeningInsight: { promptVersion: 'mono-listening-insight-v2', temperature: 0.1, maxOutputTokens: 4096, minimumTimeoutSeconds: 30 },
    specialGreeting: { promptVersion: 'special-greeting-v1', temperature: 0.7, maxOutputTokens: 1024, minimumTimeoutSeconds: 20 },
    stageDirector: { promptVersion: 'mono-stage-v3', temperature: 0.2, maxOutputTokens: 4096, minimumTimeoutSeconds: 60 },
    wallpaperTranslator: { promptVersion: 'wallpaper-translator-v1', temperature: 0.1, maxOutputTokens: 512, minimumTimeoutSeconds: 15 }
  }
  const statusLabels = {
    draft: '草稿',
    pending_review: '待审核',
    published: '已发布',
    offline: '已下线',
    rejected: '已驳回',
    validated: '已验证',
    retired: '已归档',
    queued: '排队',
    collecting: '采集资料',
    generating: '生成中',
    validating: '检查中',
    review: '待审核',
    completed: '完成',
    failed: '失败'
  }

  document.addEventListener('DOMContentLoaded', () => {
    buildAgentFields()
    cacheElements()
    bindEvents()
    Admin.setupAuth(loadInitial)
  })

  function cacheElements() {
    for (const id of [
      'refreshButton', 'logoutButton', 'serviceHealth', 'contentSummary', 'statSongs', 'statPublished', 'statReview',
      'statActiveJobs', 'statFailedJobs', 'statSources', 'statCost', 'contentStatusFilter',
      'contentList', 'reviewEmpty', 'reviewDetail', 'reviewArtist', 'reviewTitle',
      'reviewMeta', 'reviewStatus', 'reviewComparison', 'publishedVersion', 'reviewIdentity',
      'reviewGeneration', 'reviewDiffSection', 'reviewDiff', 'candidateVersion', 'songSummary', 'creationStory', 'background',
      'albumSummary', 'sourceCount', 'reviewSources', 'reviewValidation',
      'saveDraftButton', 'submitButton', 'rejectButton', 'publishButton', 'rollbackButton', 'offlineButton',
      'songSearch', 'songsTable', 'jobsTable', 'sourcesTable', 'auditTable',
      'appAIRevision', 'appAIKeyStatus', 'appAIEnabled', 'appAIProtocol', 'appAIBaseURL',
      'appAIModel', 'appAIModelDiscoveryURL', 'appAITimeout', 'appAIAPIKey', 'appAIHeaders',
      'appAIDailyLimit', 'appAIHourlyLimit', 'appAIMinInterval', 'testAppAIButton', 'saveAppAIButton',
      'configEnabled', 'configRollout', 'configPolling', 'configCache', 'configMinVersion',
      'configAgentManagementEnabled', 'configRetrievalStatus', 'configWebRetrieval', 'configWebMaximumSources',
      'configProvider360', 'configProviderBing', 'configProviderSogou',
      'configSourceDouban', 'configSourceXiaohongshu',
      'configMaxVersion', 'configPlatforms', 'configRegions', 'configEffectiveAt', 'configDeviceWhitelist',
      'moduleSongSummary', 'moduleCreationStory', 'moduleBackground', 'moduleAlbumSummary', 'moduleSources',
      'moduleSimilarSongs', 'moduleArtistSongs', 'configFallbackModel', 'configPromptVersion',
      'configSchemaVersion', 'configTemperature', 'configMaxOutput', 'configTaskTokenLimit',
      'configMaxAttempts', 'configConcurrency', 'configRequestsPerMinute', 'configCircuitBreaker',
      'configDailyBudget', 'configAutoPublish', 'configMinimumGrade', 'configHighRiskReview',
      'configConflictReview', 'configSystemPrompt', 'configContentPrompt', 'saveConfigButton', 'configVersions',
      'rolesList', 'accessActor', 'accessRole', 'assignRoleButton', 'assignmentsList'
    ]) els[id] = document.getElementById(id)
  }

  function buildAgentFields() {
    const markup = `
      <label class="field"><span>状态</span><select data-agent-field="enabled"><option value="true">开启</option><option value="false">关闭</option></select></label>
      <label class="field"><span>提示词版本</span><input data-agent-field="promptVersion" type="text"></label>
      <label class="field"><span>温度</span><input data-agent-field="temperature" type="number" min="0" max="2" step="0.1"></label>
      <label class="field"><span>最大输出 Token</span><input data-agent-field="maxOutputTokens" type="number" min="128" max="32000"></label>
      <label class="field"><span>最低超时（秒）</span><input data-agent-field="minimumTimeoutSeconds" type="number" min="0" max="180"></label>
      <label class="field config-wide"><span>系统提示词（空则使用 App 内置）</span><textarea data-agent-field="systemPrompt"></textarea></label>
      <label class="field config-wide"><span>用户提示词模板（{{input}} 为 App 输入）</span><textarea data-agent-field="userPromptTemplate"></textarea></label>`
    document.querySelectorAll('.agent-config-card:not([data-agent-key="equalizer"]) .agent-config-fields')
      .forEach((container) => { container.innerHTML = markup })
  }

  function bindEvents() {
    els.logoutButton?.addEventListener('click', Admin.logout)
    els.refreshButton?.addEventListener('click', refreshActiveView)
    els.contentStatusFilter?.addEventListener('change', loadContent)
    els.songSearch?.addEventListener('input', debounce(loadSongs, 250))
    els.saveDraftButton?.addEventListener('click', saveDraft)
    els.submitButton?.addEventListener('click', () => updateContentStatus('submit'))
    els.rejectButton?.addEventListener('click', () => updateContentStatus('reject'))
    els.publishButton?.addEventListener('click', () => updateContentStatus('publish', true))
    els.rollbackButton?.addEventListener('click', () => updateContentStatus('rollback', true))
    els.offlineButton?.addEventListener('click', () => updateContentStatus('offline', true))
    els.saveConfigButton?.addEventListener('click', saveConfigDraft)
    els.configWebRetrieval?.addEventListener('change', syncRetrievalStatus)
    for (const input of [
      els.configProvider360,
      els.configProviderBing,
      els.configProviderSogou,
      els.configSourceDouban,
      els.configSourceXiaohongshu
    ]) {
      input?.addEventListener('change', syncRetrievalStatus)
    }
    els.testAppAIButton?.addEventListener('click', testAppAI)
    els.saveAppAIButton?.addEventListener('click', saveAppAI)
    els.assignRoleButton?.addEventListener('click', assignRole)
    document.querySelectorAll('.content-console-tab').forEach((button) => {
      button.addEventListener('click', () => switchView(button.dataset.view))
    })
  }

  async function loadInitial() {
    await Promise.all([loadStats(), loadConfig()])
  }

  async function loadStats() {
    setHealth('正在读取', 'loading')
    try {
      const data = await Admin.request('/api/song-content/dashboard')
      els.statSongs.textContent = Admin.fmtNum(data.stats.songs)
      els.statPublished.textContent = Admin.fmtNum(data.stats.published)
      els.statReview.textContent = Admin.fmtNum(data.stats.pendingReview)
      els.statActiveJobs.textContent = Admin.fmtNum(data.stats.activeJobs)
      els.statFailedJobs.textContent = Admin.fmtNum(data.stats.failedJobs)
      els.statSources.textContent = Admin.fmtNum(data.stats.sources)
      els.statCost.textContent = Number(data.stats.cost || 0).toFixed(4)
      setHealth('服务正常', 'success')
    } catch (error) {
      setHealth('读取失败', 'error')
      throw error
    }
  }

  async function switchView(view) {
    state.activeView = view
    const showsContentSummary = ['content', 'songs', 'jobs', 'sources', 'audit'].includes(view)
    els.contentSummary?.classList.toggle('hidden', !showsContentSummary)
    document.querySelectorAll('.content-console-tab').forEach((button) => {
      const active = button.dataset.view === view
      button.classList.toggle('is-active', active)
      button.setAttribute('aria-selected', String(active))
    })
    document.querySelectorAll('.content-console-view').forEach((section) => section.classList.add('hidden'))
    document.getElementById(`${view}View`)?.classList.remove('hidden')
    await refreshActiveView()
  }

  async function refreshActiveView() {
    els.refreshButton.disabled = true
    try {
      await loadStats()
      if (state.activeView === 'content') await loadContent()
      if (state.activeView === 'songs') await loadSongs()
      if (state.activeView === 'jobs') await loadJobs()
      if (state.activeView === 'sources') await loadSources()
      if (state.activeView === 'config') await loadConfig()
      if (state.activeView === 'access') await loadAccess()
      if (state.activeView === 'audit') await loadAudit()
    } catch (error) {
      Admin.notify(error.message || '刷新失败', 'error')
    } finally {
      els.refreshButton.disabled = false
    }
  }

  async function loadContent() {
    els.contentList.innerHTML = skeletonRows(5)
    const status = encodeURIComponent(els.contentStatusFilter.value)
    try {
      const data = await Admin.request(`/api/song-content/content?status=${status}`)
      renderContentList(data.content || [])
    } catch (error) {
      renderInlineError(els.contentList, error.message)
    }
  }

  function renderContentList(items) {
    if (!items.length) {
      els.contentList.innerHTML = emptyMarkup('没有符合条件的内容版本')
      clearReview()
      return
    }
    els.contentList.innerHTML = items.map((item) => `
      <button class="review-list-item ${item.id === state.selectedVersionId ? 'is-active' : ''}" data-version-id="${Admin.esc(item.id)}">
        <span class="review-list-copy">
          <strong>${Admin.esc(item.songTitle)}</strong>
          <span>${Admin.esc(item.artistName)} · ${Admin.esc(item.locale)}</span>
        </span>
        <span class="review-list-side">
          ${badge(item.status)}
          <time>${Admin.esc(Admin.fmtDate(item.updatedAt))}</time>
        </span>
      </button>
    `).join('')
    els.contentList.querySelectorAll('[data-version-id]').forEach((button) => {
      button.addEventListener('click', () => selectContent(button.dataset.versionId))
    })
  }

  async function selectContent(versionId) {
    state.selectedVersionId = versionId
    els.reviewEmpty.classList.add('hidden')
    els.reviewDetail.classList.remove('hidden')
    setReviewLoading(true)
    try {
      const data = await Admin.request(`/api/song-content/content/${encodeURIComponent(versionId)}`)
      state.review = data.review
      renderReview(data.review)
      document.querySelectorAll('.review-list-item').forEach((item) => {
        item.classList.toggle('is-active', item.dataset.versionId === versionId)
      })
    } catch (error) {
      Admin.notify(error.message || '内容读取失败', 'error')
      clearReview()
    } finally {
      setReviewLoading(false)
    }
  }

  function renderReview(review) {
    const candidate = review.candidate
    els.reviewArtist.textContent = review.song.artists.map((artist) => artist.name).join(' / ')
    els.reviewTitle.textContent = review.song.title
    els.reviewMeta.textContent = `${candidate.locale} · ${candidate.modelName || '人工编辑'} · ${Admin.fmtDate(candidate.generatedAt)}`
    els.reviewStatus.className = `badge ${badgeClass(candidate.status)}`
    els.reviewStatus.textContent = statusLabels[candidate.status] || candidate.status
    els.songSummary.value = candidate.songSummary || ''
    els.creationStory.value = candidate.creationStory || ''
    els.background.value = candidate.background || ''
    els.albumSummary.value = candidate.albumSummary || ''
    els.sourceCount.textContent = `${candidate.sources.length} 条`
    els.reviewSources.innerHTML = candidate.sources.length
      ? candidate.sources.map(sourceMarkup).join('')
      : emptyMarkup('没有关联来源')
    els.reviewValidation.innerHTML = validationMarkup(candidate.validation, candidate.riskFlags)
    els.reviewIdentity.innerHTML = keyValueMarkup([
      ['内部 ID', review.song.id],
      ['专辑', review.song.album?.name || '—'],
      ['发行时间', review.song.releaseDate?.value || '—'],
      ['ISRC', review.song.isrc || '—'],
      ['版本', review.song.versionLabel || '—'],
      ['平台映射', review.song.platformMappings.map((item) => `${item.platform}:${item.songId}`).join(' / ') || '—']
    ])
    const job = review.generationJob || {}
    els.reviewGeneration.innerHTML = keyValueMarkup([
      ['模型', [candidate.modelProvider, candidate.modelName].filter(Boolean).join(' / ') || '人工编辑'],
      ['提示词版本', candidate.promptVersion || '—'],
      ['输入 Token', job.tokenInput ?? '—'],
      ['输出 Token', job.tokenOutput ?? '—'],
      ['费用', job.cost == null ? '—' : Number(job.cost).toFixed(6)],
      ['生成时间', Admin.fmtDate(candidate.generatedAt)]
    ])
    const diffs = review.fieldDiffs || []
    els.reviewDiffSection.classList.toggle('hidden', diffs.length === 0)
    els.reviewDiff.innerHTML = diffs.map(diffMarkup).join('')

    if (review.published && review.published.id !== candidate.id) {
      els.reviewComparison.classList.remove('hidden')
      els.publishedVersion.textContent = shortId(review.published.id)
      els.candidateVersion.textContent = shortId(candidate.id)
    } else {
      els.reviewComparison.classList.add('hidden')
    }

    const canPublish = ['draft', 'pending_review', 'rejected'].includes(candidate.status)
    els.publishButton.disabled = !canPublish
    els.submitButton.disabled = candidate.status !== 'draft'
    els.rollbackButton.disabled = candidate.status === 'published' || !review.published
    els.offlineButton.disabled = candidate.status !== 'published'
    els.rejectButton.disabled = !['draft', 'pending_review'].includes(candidate.status)
  }

  async function saveDraft() {
    if (!state.selectedVersionId) return
    setActionLoading(true)
    try {
      const data = await Admin.request(`/api/song-content/content/${encodeURIComponent(state.selectedVersionId)}/edit`, {
        method: 'POST',
        body: JSON.stringify({
          songSummary: els.songSummary.value,
          creationStory: els.creationStory.value,
          background: els.background.value,
          albumSummary: els.albumSummary.value,
          sourceRefs: state.review?.candidate?.sourceRefs || {}
        })
      })
      Admin.notify('草稿已保存', 'success')
      await loadContent()
      await selectContent(data.version.id)
    } catch (error) {
      Admin.notify(error.message || '保存失败', 'error')
    } finally {
      setActionLoading(false)
    }
  }

  async function updateContentStatus(action, requiresConfirmation = false) {
    if (!state.selectedVersionId) return
    if (requiresConfirmation && !window.confirm(action === 'offline' ? '确认下线当前内容？' : (action === 'rollback' ? '确认回滚到此内容版本？' : '确认发布此内容版本？'))) return
    setActionLoading(true)
    try {
      await Admin.request(`/api/song-content/content/${encodeURIComponent(state.selectedVersionId)}/${action}`, {
        method: 'POST',
        body: JSON.stringify({ confirmed: requiresConfirmation })
      })
      const messages = { publish: '内容已发布', offline: '内容已下线', reject: '内容已驳回', submit: '已提交审核', rollback: '内容已回滚' }
      Admin.notify(messages[action] || '操作完成', 'success')
      await Promise.all([loadStats(), loadContent()])
      await selectContent(state.selectedVersionId)
    } catch (error) {
      Admin.notify(error.message || '操作失败', 'error')
    } finally {
      setActionLoading(false)
    }
  }

  async function loadSongs() {
    els.songsTable.innerHTML = tableLoadingRow(6)
    try {
      const data = await Admin.request(`/api/song-content/songs?q=${encodeURIComponent(els.songSearch.value)}`)
      const songs = data.songs || []
      els.songsTable.innerHTML = songs.length ? songs.map((song) => `
        <tr>
          <td><strong>${Admin.esc(song.title)}</strong><span>${Admin.esc(song.artists.map((artist) => artist.name).join(' / '))}</span><span><code>${Admin.esc(shortId(song.id))}</code></span></td>
          <td><select class="source-grade-select" data-identity-song="${Admin.esc(song.id)}"><option value="confirmed" ${song.identityStatus === 'confirmed' ? 'selected' : ''}>已确认</option><option value="provisional" ${song.identityStatus === 'provisional' ? 'selected' : ''}>待确认</option><option value="conflict" ${song.identityStatus === 'conflict' ? 'selected' : ''}>冲突</option></select></td>
          <td><div class="mapping-list">${song.platformMappings.map((mapping) => `<span class="mapping-line" title="${Admin.esc(mapping.id)}">${Admin.esc(mapping.platform)}:${Admin.esc(mapping.songId)}</span>`).join('')}</div></td>
          <td><button class="content-toggle ${song.whitelisted ? 'is-on' : ''}" data-whitelist-song="${Admin.esc(song.id)}" aria-pressed="${song.whitelisted}">${song.whitelisted ? '已开启' : '未开启'}</button></td>
          <td>${song.currentContentStatus ? badge(song.currentContentStatus) : '—'}</td>
          <td><div class="table-actions"><button class="btn btn-secondary btn-small" data-regenerate-song="${Admin.esc(song.id)}">重新生成</button><button class="btn btn-secondary btn-small" data-merge-song="${Admin.esc(song.id)}">合并</button>${song.platformMappings.length ? `<button class="btn btn-secondary btn-small" data-split-mapping="${Admin.esc(song.platformMappings[0].id)}">拆分映射</button><button class="btn btn-secondary btn-small" data-repoint-mapping="${Admin.esc(song.platformMappings[0].id)}">修正映射</button>` : ''}</div></td>
        </tr>
      `).join('') : tableEmptyRow(6, '没有歌曲记录')
      bindSongActions()
    } catch (error) {
      els.songsTable.innerHTML = tableEmptyRow(6, error.message)
    }
  }

  function bindSongActions() {
    els.songsTable.querySelectorAll('[data-identity-song]').forEach((select) => {
      select.addEventListener('change', async () => {
        try {
          await Admin.request(`/api/song-content/songs/${encodeURIComponent(select.dataset.identitySong)}/identity`, { method: 'PUT', body: JSON.stringify({ status: select.value }) })
          Admin.notify('歌曲身份已更新', 'success')
        } catch (error) { Admin.notify(error.message, 'error'); await loadSongs() }
      })
    })
    els.songsTable.querySelectorAll('[data-whitelist-song]').forEach((button) => {
      button.addEventListener('click', async () => {
        button.disabled = true
        try {
          await Admin.request(`/api/song-content/songs/${encodeURIComponent(button.dataset.whitelistSong)}/whitelist`, {
            method: 'PUT', body: JSON.stringify({ enabled: button.getAttribute('aria-pressed') !== 'true' })
          })
          await loadSongs()
        } catch (error) { Admin.notify(error.message, 'error') }
      })
    })
    els.songsTable.querySelectorAll('[data-regenerate-song]').forEach((button) => {
      button.addEventListener('click', async () => {
        const reason = window.prompt('重新生成原因')
        if (!reason) return
        button.disabled = true
        try {
          await Admin.request(`/api/song-content/songs/${encodeURIComponent(button.dataset.regenerateSong)}/regenerate`, {
            method: 'POST', body: JSON.stringify({ reason })
          })
          Admin.notify('生成任务已创建', 'success')
        } catch (error) { Admin.notify(error.message, 'error') }
        finally { button.disabled = false }
      })
    })
    els.songsTable.querySelectorAll('[data-merge-song]').forEach((button) => button.addEventListener('click', async () => {
      const targetSongId = window.prompt('目标歌曲内部 ID')
      if (!targetSongId || !window.confirm('确认合并平台映射？')) return
      await songIdentityAction(`/api/song-content/songs/${encodeURIComponent(button.dataset.mergeSong)}/merge`, { targetSongId, confirmed: true }, '歌曲映射已合并')
    }))
    els.songsTable.querySelectorAll('[data-split-mapping]').forEach((button) => button.addEventListener('click', async () => {
      if (!window.confirm('确认将此平台映射拆分为独立歌曲？')) return
      await songIdentityAction(`/api/song-content/mappings/${encodeURIComponent(button.dataset.splitMapping)}/split`, { confirmed: true }, '平台映射已拆分')
    }))
    els.songsTable.querySelectorAll('[data-repoint-mapping]').forEach((button) => button.addEventListener('click', async () => {
      const targetSongId = window.prompt('目标歌曲内部 ID')
      if (!targetSongId || !window.confirm('确认修正此平台映射？')) return
      await songIdentityAction(`/api/song-content/mappings/${encodeURIComponent(button.dataset.repointMapping)}/repoint`, { targetSongId, confirmed: true }, '平台映射已修正')
    }))
  }

  async function songIdentityAction(url, body, success) {
    try {
      await Admin.request(url, { method: 'POST', body: JSON.stringify(body) })
      Admin.notify(success, 'success')
      await loadSongs()
    } catch (error) { Admin.notify(error.message || '操作失败', 'error') }
  }

  async function loadJobs() {
    els.jobsTable.innerHTML = tableLoadingRow(7)
    try {
      const data = await Admin.request('/api/song-content/jobs')
      const jobs = data.jobs || []
      els.jobsTable.innerHTML = jobs.length ? jobs.map((job) => `
        <tr><td><code>${Admin.esc(shortId(job.id))}</code><span>${Admin.esc(job.reason)}</span></td><td>${badge(job.state)}</td><td>${job.attemptCount} / ${job.maxAttempts}</td><td>${Admin.esc(`${job.tokenInput ?? 0} / ${job.tokenOutput ?? 0}`)}<span>${job.cost == null ? '—' : Number(job.cost).toFixed(6)}</span></td><td>${formatDuration(job.durationMs)}</td><td>${Admin.esc(job.errorCode || '—')}<span>${Admin.esc(job.errorMessage || '')}</span></td><td>${job.state === 'failed' ? `<button class="btn btn-secondary btn-small" data-retry-job="${Admin.esc(job.id)}">重试</button>` : ''}</td></tr>
      `).join('') : tableEmptyRow(7, '没有生成任务')
      els.jobsTable.querySelectorAll('[data-retry-job]').forEach((button) => button.addEventListener('click', () => retryJob(button)))
    } catch (error) { els.jobsTable.innerHTML = tableEmptyRow(7, error.message) }
  }

  async function retryJob(button) {
    button.disabled = true
    try {
      await Admin.request(`/api/song-content/jobs/${encodeURIComponent(button.dataset.retryJob)}/retry`, { method: 'POST' })
      Admin.notify('任务已重新排队', 'success')
      await loadJobs()
    } catch (error) { Admin.notify(error.message, 'error') }
  }

  async function loadSources() {
    els.sourcesTable.innerHTML = tableLoadingRow(8)
    try {
      const data = await Admin.request('/api/song-content/sources')
      const sources = data.sources || []
      els.sourcesTable.innerHTML = sources.length ? sources.map((source) => `
        <tr><td><a href="${Admin.esc(source.url)}" target="_blank" rel="noreferrer">${Admin.esc(source.title)}</a></td><td><select class="source-grade-select" data-source-grade="${Admin.esc(source.id)}"><option ${source.grade === 'A' ? 'selected' : ''}>A</option><option ${source.grade === 'B' ? 'selected' : ''}>B</option><option ${source.grade === 'C' ? 'selected' : ''}>C</option><option ${source.grade === 'D' ? 'selected' : ''}>D</option></select></td><td>${Admin.esc(source.publisher)}</td><td>${Admin.esc(sourceKind(source))}</td><td>${Admin.esc(formatSourceFields(source.supportedFields) || '—')}</td><td>${Admin.esc(Admin.fmtDate(source.fetchedAt))}</td><td>${source.accessible ? badge('accessible') : badge('unavailable')}</td><td><button class="btn btn-secondary btn-small" data-source-access="${Admin.esc(source.id)}" data-accessible="${source.accessible}">${source.accessible ? '标记失效' : '恢复'}</button></td></tr>
      `).join('') : tableEmptyRow(8, '没有来源记录')
      bindSourceActions()
    } catch (error) { els.sourcesTable.innerHTML = tableEmptyRow(8, error.message) }
  }

  function bindSourceActions() {
    els.sourcesTable.querySelectorAll('[data-source-grade]').forEach((select) => select.addEventListener('change', () => updateSource(select.dataset.sourceGrade, { grade: select.value })))
    els.sourcesTable.querySelectorAll('[data-source-access]').forEach((button) => button.addEventListener('click', () => updateSource(button.dataset.sourceAccess, { accessible: button.dataset.accessible !== 'true' })))
  }

  async function updateSource(sourceId, patch) {
    try {
      await Admin.request(`/api/song-content/sources/${encodeURIComponent(sourceId)}`, { method: 'PUT', body: JSON.stringify(patch) })
      Admin.notify('来源已更新', 'success')
      await loadSources()
    } catch (error) { Admin.notify(error.message || '来源更新失败', 'error') }
  }

  async function loadAudit() {
    els.auditTable.innerHTML = tableLoadingRow(5)
    try {
      const data = await Admin.request('/api/song-content/audit')
      const logs = data.logs || []
      els.auditTable.innerHTML = logs.length ? logs.map((log) => `
        <tr><td>${Admin.esc(Admin.fmtDate(log.createdAt))}</td><td>${Admin.esc(log.actorId || '系统')}</td><td><code>${Admin.esc(log.action)}</code></td><td>${Admin.esc(log.resourceType)} · ${Admin.esc(shortId(log.resourceId))}</td><td>${Admin.esc(shortId(log.requestId || '—'))}</td></tr>
      `).join('') : tableEmptyRow(5, '没有审计记录')
    } catch (error) { els.auditTable.innerHTML = tableEmptyRow(5, error.message) }
  }

  async function loadConfig() {
    els.configVersions.innerHTML = skeletonRows(3)
    try {
      const [data, appAI] = await Promise.all([
        Admin.request('/api/song-content/config'),
        Admin.request('/api/ai/config')
      ])
      fillConfig(data.current)
      fillAppAI(appAI)
      renderConfigVersions(data.versions || [])
    } catch (error) {
      renderInlineError(els.configVersions, error.message)
    }
  }

  function fillAppAI(configuration) {
    state.appAIRevision = configuration.revision || null
    els.appAIRevision.textContent = configuration.updatedAt ? `${shortId(configuration.revision)} · ${Admin.fmtDate(configuration.updatedAt)}` : ''
    els.appAIKeyStatus.className = `badge ${configuration.hasAPIKey || configuration.apiKey ? 'badge-success' : 'badge-warning'}`
    els.appAIKeyStatus.textContent = configuration.hasAPIKey || configuration.apiKey ? 'Key 已配置' : 'Key 未配置'
    els.appAIEnabled.value = String(configuration.enabled !== false)
    els.appAIProtocol.value = configuration.wireProtocol || 'openAICompatible'
    els.appAIBaseURL.value = configuration.baseURL || ''
    els.appAIModel.value = configuration.model || ''
    els.appAIModelDiscoveryURL.value = configuration.modelDiscoveryURL || ''
    els.appAITimeout.value = configuration.timeout ?? 60
    els.appAIAPIKey.value = ''
    els.appAIHeaders.value = configuration.customHeadersJSON || ''
    els.appAIDailyLimit.value = configuration.usageLimits?.dailyRequestLimit ?? 50
    els.appAIHourlyLimit.value = configuration.usageLimits?.hourlyRequestLimit ?? 20
    els.appAIMinInterval.value = configuration.usageLimits?.minimumRequestInterval ?? 15
  }

  function fillConfig(release) {
    const client = release?.client || {}
    const ai = release?.ai || {}
    const modules = client.modules || {}
    els.configEnabled.value = String(client.enabled !== false)
    els.configAgentManagementEnabled.value = String(client.agentManagementEnabled !== false)
    els.configRollout.value = client.rolloutPercentage ?? 100
    els.configPolling.value = client.pollingIntervalSeconds ?? 3
    els.configCache.value = client.cacheMaxAgeSeconds ?? 3600
    els.configMinVersion.value = client.minAppVersion || ''
    els.configMaxVersion.value = client.maxAppVersion || ''
    els.configPlatforms.value = (client.platforms || []).join(', ')
    els.configRegions.value = (client.regions || []).join(', ')
    els.configEffectiveAt.value = toLocalDateTime(client.effectiveAt)
    els.configDeviceWhitelist.value = (client.deviceWhitelist || []).join('\n')
    els.moduleSongSummary.checked = modules.songSummary !== false
    els.moduleCreationStory.checked = modules.creationStory !== false
    els.moduleBackground.checked = modules.background !== false
    els.moduleAlbumSummary.checked = modules.albumSummary !== false
    els.moduleSources.checked = modules.sources !== false
    els.moduleSimilarSongs.checked = modules.similarSongs !== false
    els.moduleArtistSongs.checked = modules.artistSongs !== false
    els.configFallbackModel.value = ai.fallbackModel || ''
    els.configPromptVersion.value = ai.promptVersion || 'song-editor-web-v5'
    els.configSchemaVersion.value = ai.schemaVersion || '1'
    els.configTemperature.value = ai.temperature ?? 0.2
    els.configMaxOutput.value = ai.maxOutputTokens ?? 2000
    els.configTaskTokenLimit.value = ai.perTaskTokenLimit ?? 20000
    els.configMaxAttempts.value = ai.maxAttempts ?? 3
    els.configConcurrency.value = ai.concurrency ?? 2
    els.configRequestsPerMinute.value = ai.requestsPerMinute ?? 60
    els.configCircuitBreaker.value = ai.circuitBreakerFailures ?? 5
    els.configDailyBudget.value = ai.dailyBudget ?? 0
    els.configAutoPublish.value = String(ai.autoPublish === true)
    els.configMinimumGrade.value = ai.minimumSourceGrade || 'B'
    els.configHighRiskReview.value = String(ai.highRiskRequiresReview === true)
    els.configConflictReview.value = String(ai.sourceConflictRequiresReview === true)
    const retrievalEnabled = ai.webRetrievalEnabled !== false
    const configuredProviders = Array.isArray(ai.webSearchProviders) ? ai.webSearchProviders : ['360', 'bing', 'sogou']
    const configuredSources = Array.isArray(ai.webPreferredSources) ? ai.webPreferredSources : ['douban', 'xiaohongshu']
    els.configWebRetrieval.value = String(retrievalEnabled)
    els.configWebMaximumSources.value = ai.webMaximumSources ?? 6
    els.configProvider360.checked = configuredProviders.includes('360')
    els.configProviderBing.checked = configuredProviders.includes('bing')
    els.configProviderSogou.checked = configuredProviders.includes('sogou')
    els.configSourceDouban.checked = configuredSources.includes('douban')
    els.configSourceXiaohongshu.checked = configuredSources.includes('xiaohongshu')
    syncRetrievalStatus()
    els.configSystemPrompt.value = ai.systemPrompt || ''
    els.configContentPrompt.value = ai.contentPrompt || ''
    fillAgentConfigurations(client.agents || {})
  }

  function fillAgentConfigurations(agents) {
    agentKeys.forEach((key) => {
      const root = document.querySelector(`.agent-config-card[data-agent-key="${key}"]`)
      const fallback = agentDefaults[key]
      const agent = { ...fallback, ...(agents[key] || {}) }
      setAgentField(root, 'enabled', String(agent.enabled !== false))
      setAgentField(root, 'promptVersion', agent.promptVersion || fallback.promptVersion)
      setAgentField(root, 'temperature', agent.temperature ?? fallback.temperature)
      setAgentField(root, 'maxOutputTokens', agent.maxOutputTokens ?? fallback.maxOutputTokens)
      setAgentField(root, 'minimumTimeoutSeconds', agent.minimumTimeoutSeconds ?? fallback.minimumTimeoutSeconds)
      setAgentField(root, 'systemPrompt', agent.systemPrompt || '')
      setAgentField(root, 'secondarySystemPrompt', agent.secondarySystemPrompt || '')
      setAgentField(root, 'userPromptTemplate', agent.userPromptTemplate || '')
      const version = root?.querySelector('[data-agent-version]')
      if (version) version.textContent = agent.promptVersion || fallback.promptVersion
    })
  }

  function syncRetrievalStatus() {
    const enabled = els.configWebRetrieval?.value !== 'false'
    if (!els.configRetrievalStatus) return
    const providerCount = [els.configProvider360, els.configProviderBing, els.configProviderSogou].filter((input) => input?.checked).length
    const sourceCount = [els.configSourceDouban, els.configSourceXiaohongshu].filter((input) => input?.checked).length
    els.configRetrievalStatus.className = `badge ${enabled ? 'badge-success' : 'badge-neutral'}`
    els.configRetrievalStatus.textContent = enabled ? `联网检索已开启 · ${providerCount} 路 · ${sourceCount} 个重点来源` : '联网检索已关闭'
  }

  function setAgentField(root, field, value) {
    const input = root?.querySelector(`[data-agent-field="${field}"]`)
    if (input) input.value = value
  }

  function readAgentConfigurations() {
    return Object.fromEntries(agentKeys.map((key) => {
      const root = document.querySelector(`.agent-config-card[data-agent-key="${key}"]`)
      const read = (field) => root?.querySelector(`[data-agent-field="${field}"]`)?.value || ''
      return [key, {
        enabled: read('enabled') !== 'false',
        promptVersion: read('promptVersion'),
        systemPrompt: read('systemPrompt'),
        secondarySystemPrompt: read('secondarySystemPrompt'),
        userPromptTemplate: read('userPromptTemplate'),
        temperature: Number(read('temperature')),
        maxOutputTokens: Number(read('maxOutputTokens')),
        minimumTimeoutSeconds: Number(read('minimumTimeoutSeconds'))
      }]
    }))
  }

  function renderConfigVersions(versions) {
    if (!versions.length) {
      els.configVersions.innerHTML = emptyMarkup('没有配置版本')
      return
    }
    els.configVersions.innerHTML = versions.map((release) => `
      <div class="review-list-item config-version-row">
        <span class="review-list-copy"><strong>版本 ${release.version}</strong><span>${Admin.esc(shortId(release.hash))} · ${Admin.esc(Admin.fmtDate(release.publishedAt || release.createdAt))}</span></span>
        <span class="config-version-actions">${badge(release.status)}${release.validation?.passed ? '<span class="badge badge-success">已验证</span>' : ''}${release.status === 'draft' ? `<button class="btn btn-secondary btn-small" data-validate-config="${Admin.esc(release.id)}">预发布验证</button>${release.validation?.passed ? `<button class="btn btn-primary btn-small" data-publish-config="${Admin.esc(release.id)}">发布</button>` : ''}` : ''}${release.status === 'retired' ? `<button class="btn btn-secondary btn-small" data-publish-config="${Admin.esc(release.id)}">回滚</button>` : ''}</span>
      </div>
    `).join('')
    els.configVersions.querySelectorAll('[data-publish-config]').forEach((button) => {
      button.addEventListener('click', () => publishConfig(button))
    })
    els.configVersions.querySelectorAll('[data-validate-config]').forEach((button) => button.addEventListener('click', () => validateConfig(button)))
  }

  async function saveConfigDraft() {
    els.saveConfigButton.disabled = true
    try {
      await Admin.request('/api/song-content/config/drafts', {
        method: 'POST',
        body: JSON.stringify({
          client: {
            enabled: els.configEnabled.value === 'true',
            agentManagementEnabled: els.configAgentManagementEnabled.value === 'true',
            agents: readAgentConfigurations(),
            rolloutPercentage: Number(els.configRollout.value),
            pollingIntervalSeconds: Number(els.configPolling.value),
            cacheMaxAgeSeconds: Number(els.configCache.value),
            minAppVersion: els.configMinVersion.value,
            maxAppVersion: els.configMaxVersion.value,
            platforms: splitList(els.configPlatforms.value),
            regions: splitList(els.configRegions.value),
            deviceWhitelist: splitList(els.configDeviceWhitelist.value),
            effectiveAt: els.configEffectiveAt.value ? new Date(els.configEffectiveAt.value).toISOString() : null,
            modules: {
              songSummary: els.moduleSongSummary.checked,
              creationStory: els.moduleCreationStory.checked,
              background: els.moduleBackground.checked,
              albumSummary: els.moduleAlbumSummary.checked,
              sources: els.moduleSources.checked,
              similarSongs: els.moduleSimilarSongs.checked,
              artistSongs: els.moduleArtistSongs.checked
            }
          },
          ai: {
            fallbackModel: els.configFallbackModel.value,
            promptVersion: els.configPromptVersion.value,
            schemaVersion: els.configSchemaVersion.value,
            temperature: Number(els.configTemperature.value),
            maxOutputTokens: Number(els.configMaxOutput.value),
            perTaskTokenLimit: Number(els.configTaskTokenLimit.value),
            maxAttempts: Number(els.configMaxAttempts.value),
            concurrency: Number(els.configConcurrency.value),
            requestsPerMinute: Number(els.configRequestsPerMinute.value),
            circuitBreakerFailures: Number(els.configCircuitBreaker.value),
            dailyBudget: Number(els.configDailyBudget.value),
            autoPublish: els.configAutoPublish.value === 'true',
            minimumSourceGrade: els.configMinimumGrade.value,
            highRiskRequiresReview: els.configHighRiskReview.value === 'true',
            sourceConflictRequiresReview: els.configConflictReview.value === 'true',
            webRetrievalEnabled: els.configWebRetrieval.value === 'true',
            webMaximumSources: Number(els.configWebMaximumSources.value),
            webSearchProviders: [
              els.configProvider360.checked ? '360' : null,
              els.configProviderBing.checked ? 'bing' : null,
              els.configProviderSogou.checked ? 'sogou' : null
            ].filter(Boolean),
            webPreferredSources: [
              els.configSourceDouban.checked ? 'douban' : null,
              els.configSourceXiaohongshu.checked ? 'xiaohongshu' : null
            ].filter(Boolean),
            systemPrompt: els.configSystemPrompt.value,
            contentPrompt: els.configContentPrompt.value
          }
        })
      })
      Admin.notify('配置草稿已保存', 'success')
      await loadConfig()
    } catch (error) { Admin.notify(error.message || '保存失败', 'error') }
    finally { els.saveConfigButton.disabled = false }
  }

  async function validateConfig(button) {
    button.disabled = true
    try {
      await Admin.request(`/api/song-content/config/${encodeURIComponent(button.dataset.validateConfig)}/validate`, { method: 'POST' })
      Admin.notify('预发布验证通过', 'success')
      await loadConfig()
    } catch (error) { Admin.notify(error.message || '预发布验证失败', 'error') }
    finally { button.disabled = false }
  }

  async function publishConfig(button) {
    if (!window.confirm(button.textContent.trim() === '回滚' ? '确认回滚到此配置版本？' : '确认发布此配置版本？')) return
    button.disabled = true
    const action = button.textContent.trim() === '回滚' ? 'rollback' : 'publish'
    try {
      await Admin.request(`/api/song-content/config/${encodeURIComponent(button.dataset.publishConfig)}/${action}`, {
        method: 'POST', body: JSON.stringify({ confirmed: true })
      })
      Admin.notify(action === 'rollback' ? '配置已回滚' : '配置已发布', 'success')
      await loadConfig()
    } catch (error) { Admin.notify(error.message || '操作失败', 'error') }
    finally { button.disabled = false }
  }

  function appAIForm() {
    const configuration = {
      wireProtocol: els.appAIProtocol.value,
      baseURL: els.appAIBaseURL.value,
      model: els.appAIModel.value,
      modelDiscoveryURL: els.appAIModelDiscoveryURL.value,
      timeout: Number(els.appAITimeout.value),
      customHeadersJSON: els.appAIHeaders.value
    }
    const payload = {
      enabled: els.appAIEnabled.value === 'true',
      expectedRevision: state.appAIRevision,
      configuration,
      usageLimits: {
        dailyRequestLimit: Number(els.appAIDailyLimit.value),
        hourlyRequestLimit: Number(els.appAIHourlyLimit.value),
        minimumRequestInterval: Number(els.appAIMinInterval.value)
      }
    }
    if (els.appAIAPIKey.value.trim()) payload.apiKey = els.appAIAPIKey.value.trim()
    return payload
  }

  async function testAppAI() {
    els.testAppAIButton.disabled = true
    try {
      const data = await Admin.request('/api/song-content/app-ai/test', { method: 'POST', body: JSON.stringify(appAIForm()) })
      Admin.notify(`连接正常 · ${data.result.latencyMs} ms`, 'success')
    } catch (error) { Admin.notify(error.message || '连接测试失败', 'error') }
    finally { els.testAppAIButton.disabled = false }
  }

  async function saveAppAI() {
    if (!window.confirm('确认保存 App AI 配置？')) return
    els.saveAppAIButton.disabled = true
    try {
      const data = await Admin.request('/api/ai/config', { method: 'PUT', body: JSON.stringify(appAIForm()) })
      fillAppAI(data)
      Admin.notify('App AI 配置已保存', 'success')
    } catch (error) { Admin.notify(error.message || 'App AI 配置保存失败', 'error') }
    finally { els.saveAppAIButton.disabled = false }
  }

  async function loadAccess() {
    els.rolesList.innerHTML = skeletonRows(3)
    els.assignmentsList.innerHTML = skeletonRows(3)
    try {
      const data = await Admin.request('/api/song-content/access')
      els.rolesList.innerHTML = (data.roles || []).map((role) => `<div class="key-value-row"><span>${Admin.esc(role.name)}</span><span class="permission-list">${(role.permissions || []).map((permission) => `<code>${Admin.esc(permission)}</code>`).join('')}</span></div>`).join('') || emptyMarkup('没有角色')
      els.accessRole.innerHTML = (data.roles || []).map((role) => `<option value="${Admin.esc(role.id)}">${Admin.esc(role.name)}</option>`).join('')
      els.assignmentsList.innerHTML = (data.assignments || []).map((item) => `<div class="review-list-item config-version-row"><span class="review-list-copy"><strong>${Admin.esc(item.actorId)}</strong><span>${Admin.esc(Admin.fmtDate(item.createdAt))}</span></span>${badge(item.roleId)}</div>`).join('') || emptyMarkup('没有权限分配')
    } catch (error) { renderInlineError(els.rolesList, error.message) }
  }

  async function assignRole() {
    const actorId = els.accessActor.value.trim()
    if (!actorId || !window.confirm('确认分配此角色？')) return
    els.assignRoleButton.disabled = true
    try {
      await Admin.request(`/api/song-content/access/${encodeURIComponent(actorId)}`, { method: 'PUT', body: JSON.stringify({ roleId: els.accessRole.value, confirmed: true }) })
      Admin.notify('角色已分配', 'success')
      els.accessActor.value = ''
      await loadAccess()
    } catch (error) { Admin.notify(error.message || '角色分配失败', 'error') }
    finally { els.assignRoleButton.disabled = false }
  }

  function sourceMarkup(source) {
    const fields = formatSourceFields(source.supportedFields)
    return `<a class="source-row" href="${Admin.esc(source.url)}" target="_blank" rel="noreferrer"><span><strong>${Admin.esc(source.title)}</strong><small>${Admin.esc(source.publisher)} · ${Admin.esc(sourceKind(source))} · ${Admin.esc(Admin.fmtDate(source.publishedAt))}${fields ? ` · ${Admin.esc(fields)}` : ''}</small></span>${badge(source.grade)}</a>`
  }

  function sourceKind(source) {
    if (source?.metadata?.platform !== 'WEB') return '平台资料'
    const labels = { '360': '360', '360-search': '360', bing: 'Bing', sogou: '搜狗' }
    const providers = Array.isArray(source.metadata.searchProviders)
      ? source.metadata.searchProviders
      : [source.metadata.searchProvider].filter(Boolean)
    const names = [...new Set(providers.map((provider) => labels[provider] || provider))]
    const platformLabels = { douban: '豆瓣', xiaohongshu: '小红书' }
    const contentPlatform = platformLabels[source.metadata.contentPlatform]
    const values = [...names, contentPlatform].filter(Boolean)
    return values.length ? `联网检索 · ${values.join(' / ')}` : '联网检索'
  }

  function formatSourceFields(fields) {
    const labels = {
      songSummary: '歌曲介绍',
      creationStory: '创作故事',
      background: '乐评',
      albumSummary: '专辑介绍'
    }
    return (Array.isArray(fields) ? fields : []).map((field) => labels[field] || field).join(' / ')
  }

  function keyValueMarkup(items) {
    return items.map(([label, value]) => `<div class="key-value-row"><span>${Admin.esc(label)}</span><span>${Admin.esc(String(value ?? '—'))}</span></div>`).join('')
  }

  function diffMarkup(diff) {
    const labels = {
      songSummary: '歌曲介绍',
      creationStory: '创作故事',
      background: '乐评',
      albumSummary: '专辑介绍',
      confidence: '可信度',
      riskFlags: '风险标记',
      sourceRefs: '来源引用'
    }
    return `<div class="diff-item"><strong>${Admin.esc(labels[diff.field] || diff.field)}</strong><div class="diff-values"><span>${Admin.esc(printValue(diff.before))}</span><span>${Admin.esc(printValue(diff.after))}</span></div></div>`
  }

  function printValue(value) {
    if (value == null || value === '') return '—'
    return typeof value === 'string' ? value : JSON.stringify(value, null, 2)
  }

  function validationMarkup(validation = {}, riskFlags = []) {
    const errors = Array.isArray(validation.errors) ? validation.errors : []
    const warnings = Array.isArray(validation.warnings) ? validation.warnings : []
    const risks = Array.isArray(riskFlags) ? riskFlags : []
    if (!errors.length && !warnings.length && !risks.length) return '<div class="validation-item is-success">自动检查通过</div>'
    return [
      ...errors.map((value) => `<div class="validation-item is-error">${Admin.esc(value)}</div>`),
      ...warnings.map((value) => `<div class="validation-item is-warning">${Admin.esc(value)}</div>`),
      ...risks.map((value) => `<div class="validation-item is-warning">${Admin.esc(value)}</div>`)
    ].join('')
  }

  function badge(status) {
    const label = statusLabels[status] || ({ confirmed: '已确认', provisional: '待确认', conflict: '冲突', A: 'A', B: 'B', C: 'C', D: 'D', accessible: '可访问', unavailable: '失效' }[status] || status)
    return `<span class="badge ${badgeClass(status)}">${Admin.esc(label)}</span>`
  }

  function badgeClass(status) {
    if (['published', 'completed', 'confirmed', 'A', 'accessible'].includes(status)) return 'badge-success'
    if (['pending_review', 'review', 'queued', 'collecting', 'generating', 'validating', 'provisional', 'B', 'C'].includes(status)) return 'badge-warning'
    if (['failed', 'rejected', 'conflict', 'offline', 'D', 'unavailable'].includes(status)) return 'badge-error'
    return 'badge-neutral'
  }

  function clearReview() {
    state.selectedVersionId = null
    state.review = null
    els.reviewDetail.classList.add('hidden')
    els.reviewEmpty.classList.remove('hidden')
  }

  function setReviewLoading(loading) {
    els.reviewDetail.classList.toggle('is-loading', loading)
  }

  function setActionLoading(loading) {
    if (!loading && state.review) return renderReview(state.review)
    [els.saveDraftButton, els.submitButton, els.rejectButton, els.publishButton, els.rollbackButton, els.offlineButton].forEach((button) => { button.disabled = true })
  }

  function setHealth(label, stateName) {
    els.serviceHealth.textContent = label
    els.serviceHealth.dataset.state = stateName
  }

  function skeletonRows(count) {
    return Array.from({ length: count }, () => '<div class="review-list-skeleton"><span></span><span></span></div>').join('')
  }

  function tableLoadingRow(columns) { return `<tr><td colspan="${columns}"><div class="table-loading"><span></span></div></td></tr>` }
  function tableEmptyRow(columns, message) { return `<tr><td colspan="${columns}" class="table-empty">${Admin.esc(message)}</td></tr>` }
  function emptyMarkup(message) { return `<div class="empty-state"><p class="empty-state-text">${Admin.esc(message)}</p></div>` }
  function renderInlineError(element, message) { element.innerHTML = `<div class="inline-error" role="alert">${Admin.esc(message || '读取失败')}</div>` }
  function shortId(value) { const text = String(value || ''); return text.length > 12 ? `${text.slice(0, 8)}…` : text }
  function splitList(value) { return [...new Set(String(value || '').split(/[\n,，]+/).map((item) => item.trim()).filter(Boolean))] }
  function toLocalDateTime(value) { if (!value) return ''; const date = new Date(value); if (Number.isNaN(date.getTime())) return ''; return new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16) }
  function formatDuration(value) { if (value == null) return '—'; if (value < 1000) return `${value} ms`; return `${(value / 1000).toFixed(1)} s` }
  function debounce(fn, wait) { let timer; return () => { clearTimeout(timer); timer = setTimeout(fn, wait) } }
})()
