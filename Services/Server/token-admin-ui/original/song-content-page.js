(function () {
  const Admin = window.TokenAdmin
  const state = {
    activeView: 'config',
    selectedVersionId: null,
    review: null,
    jobsPage: 0,
    jobsPageSize: 50,
    jobsTotal: 0,
    jobsLoading: false
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
  const jobErrorLabels = {
    AI_AUTOMATIC_REVIEW_REJECTED: ['自动审核未通过', '生成内容未通过自动审核'],
    AI_CIRCUIT_OPEN: ['AI 服务暂时不可用', '服务保护已启动，请稍后重试'],
    AI_CONTEXT_LIMIT_EXCEEDED: ['AI 上下文超出限制', '输入资料超过当前模型容量，请降低单次输入上限'],
    AI_MISSING_EVIDENCE_BACKED_SECTION: ['内容生成不完整', '生成内容缺少可信资料依据'],
    AI_PROTOCOL_SERVER_UNSUPPORTED: ['AI 服务协议不受支持', '当前服务端不支持所选请求协议'],
    AI_PROTOCOL_UNSUPPORTED: ['AI 请求协议不受支持', '请检查 AI 服务协议配置'],
    AI_PROVIDER_ERROR: ['AI 服务请求失败', '上游 AI 服务返回错误'],
    AI_RATE_LIMITED: ['AI 请求过于频繁', '请求已受限，将稍后重试'],
    AI_SOURCE_ATTRIBUTION: ['内容表达不符合要求', '生成内容包含来源归因式表述'],
    AI_TIMEOUT: ['AI 生成超时', '内容生成未在限定时间内完成'],
    AI_TOKEN_LIMIT_EXCEEDED: ['内容长度超出限制', '生成内容使用的 Token 超出上限'],
    CONTENT_VERSION_NOT_FOUND: ['内容版本不存在', '找不到对应的内容版本'],
    GENERATION_TEMPORARY_FAILURE: ['生成任务暂时失败', '任务稍后会再次尝试'],
    INSUFFICIENT_SOURCES: ['可信资料不足', '没有足够的资料支持内容生成'],
    INVALID_AI_OUTPUT: ['AI 返回内容无效', '生成结果的格式或字段不符合要求'],
    INVALID_CONTENT_STATUS: ['内容状态无效', '当前内容状态不允许执行此操作'],
    INVALID_IDENTITY_STATUS: ['歌曲身份状态无效', '当前歌曲身份状态不允许生成内容'],
    INVALID_JOB_STATE: ['任务状态无效', '当前任务状态不允许执行此操作'],
    INVALID_ROLE_ASSIGNMENT: ['角色分配无效', '无法完成当前角色分配'],
    INVALID_SONG_IDENTITY: ['歌曲身份信息无效', '歌曲身份信息不完整或不一致'],
    INVALID_SONG_MERGE: ['歌曲合并无效', '所选歌曲记录无法合并'],
    INVALID_SOURCE: ['资料来源无效', '资料来源信息不完整或不可用'],
    INVALID_WORKER: ['任务执行器无效', '任务执行器身份不匹配'],
    JOB_NOT_FOUND: ['生成任务不存在', '找不到对应的生成任务'],
    JOB_NOT_RETRYABLE: ['任务无法重试', '当前任务状态不支持重新执行'],
    MAPPING_NOT_FOUND: ['平台映射不存在', '找不到对应的平台歌曲映射'],
    SONG_IDENTITY_PENDING: ['歌曲身份待确认', '确认歌曲身份后才能生成内容'],
    SONG_NOT_FOUND: ['歌曲不存在', '找不到对应的歌曲记录'],
    SONG_NOT_WHITELISTED: ['歌曲未加入生成名单', '当前歌曲暂不允许生成内容'],
    SOURCE_NOT_FOUND: ['资料来源不存在', '找不到对应的资料来源']
  }
  const contentFieldLabels = {
    songSummary: '歌曲介绍',
    creationStory: '创作故事',
    background: '乐评',
    albumSummary: '专辑介绍'
  }

  document.addEventListener('DOMContentLoaded', () => {
    buildAgentFields()
    cacheElements()
    bindEvents()
    Admin.setupAuth(loadInitial)
    window.setInterval(() => {
      if (state.activeView === 'jobs' && !document.hidden) loadJobs({ silent: true })
    }, 8_000)
  })

  function cacheElements() {
    for (const id of [
      'refreshButton', 'logoutButton', 'serviceHealth', 'contentSummary', 'statSongs', 'statPublished', 'statReview',
      'statQueuedJobs', 'statProcessingJobs', 'statFailedJobs', 'statSources', 'statCost', 'contentStatusFilter',
      'contentList', 'reviewEmpty', 'reviewDetail', 'reviewArtist', 'reviewTitle',
      'reviewMeta', 'reviewStatus', 'reviewComparison', 'publishedVersion', 'reviewIdentity',
      'reviewGeneration', 'reviewDiffSection', 'reviewDiff', 'candidateVersion', 'songSummary', 'creationStory', 'background',
      'albumSummary', 'sourceCount', 'reviewSources', 'reviewValidation',
      'saveDraftButton', 'submitButton', 'rejectButton', 'publishButton', 'rollbackButton', 'offlineButton',
      'songSearch', 'songsTable', 'jobsTable', 'jobsQueueMeta', 'jobsQueueOverview', 'jobsStateFilter',
      'jobsPageSize', 'jobsPreviousPage', 'jobsNextPage', 'jobsPageLabel', 'sourcesTable', 'auditTable',
      'appAIRevision', 'appAIKeyStatus', 'appAIEnabled', 'appAIProtocol', 'appAIBaseURL',
      'appAIModel', 'appAIModelDiscoveryURL', 'appAITimeout', 'appAIAPIKey', 'appAIHeaders',
      'appAIDailyLimit', 'appAIHourlyLimit', 'appAIMinInterval', 'testAppAIButton', 'saveAppAIButton',
      'configEnabled', 'configRollout', 'configPolling', 'configCache', 'configMinVersion',
      'configAgentManagementEnabled', 'configRetrievalStatus', 'configWebRetrieval', 'configWebMaximumSources',
      'configProvider360', 'configProviderBaidu', 'configProviderBing', 'configProviderSogou',
      'configSourceDouban', 'configSourceXiaohongshu',
      'configMaxVersion', 'configPlatforms', 'configRegions', 'configEffectiveAt', 'configDeviceWhitelist',
      'moduleSongSummary', 'moduleCreationStory', 'moduleBackground', 'moduleAlbumSummary', 'moduleSources',
      'moduleSimilarSongs', 'moduleArtistSongs', 'configFallbackModel', 'configPromptVersion',
      'configSchemaVersion', 'configTemperature', 'configMaxOutput', 'configMaxInput', 'configTaskTokenLimit',
      'configMaxAttempts', 'configConcurrency', 'configRequestsPerMinute', 'configCircuitBreaker', 'configCircuitRecovery',
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
    els.jobsStateFilter?.addEventListener('change', () => {
      state.jobsPage = 0
      loadJobs()
    })
    els.jobsPageSize?.addEventListener('change', () => {
      state.jobsPageSize = Number(els.jobsPageSize.value) || 50
      state.jobsPage = 0
      loadJobs()
    })
    els.jobsPreviousPage?.addEventListener('click', () => {
      if (state.jobsPage <= 0) return
      state.jobsPage -= 1
      loadJobs()
    })
    els.jobsNextPage?.addEventListener('click', () => {
      if ((state.jobsPage + 1) * state.jobsPageSize >= state.jobsTotal) return
      state.jobsPage += 1
      loadJobs()
    })
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
      els.configProviderBaidu,
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
      els.statQueuedJobs.textContent = Admin.fmtNum(data.stats.queuedJobs ?? 0)
      els.statProcessingJobs.textContent = Admin.fmtNum(data.stats.processingJobs ?? data.stats.activeJobs ?? 0)
      els.statFailedJobs.textContent = Admin.fmtNum(data.stats.failedJobs)
      els.statSources.textContent = Admin.fmtNum(data.stats.sources)
      els.statCost.textContent = Number(data.stats.cost || 0).toFixed(4)
      const circuit = data.stats.providerCircuit
      if (circuit?.state === 'open') {
        setHealth(`AI 服务保护中 · ${circuit.retryAfterSeconds} 秒后自动探测`, 'warning')
      } else if (circuit?.state === 'half_open') {
        setHealth('AI 服务恢复探测中', 'warning')
      } else {
        setHealth('服务正常', 'success')
      }
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

  async function loadJobs({ silent = false } = {}) {
    if (state.jobsLoading) return
    state.jobsLoading = true
    if (!silent) els.jobsTable.innerHTML = tableLoadingRow(7)
    try {
      const query = new URLSearchParams({
        state: els.jobsStateFilter?.value || '',
        limit: String(state.jobsPageSize),
        offset: String(state.jobsPage * state.jobsPageSize)
      })
      const data = await Admin.request(`/api/song-content/jobs?${query}`)
      const jobs = data.jobs || []
      state.jobsTotal = Number(data.total || 0)
      renderJobOverview(data.counts || {})
      renderJobPagination(jobs.length)
      els.jobsTable.innerHTML = jobs.length ? jobs.map((job) => {
        const errorText = localizeJobError(job)
        const processing = ['collecting', 'generating', 'validating'].includes(job.state)
        const resultTitle = job.state === 'failed'
          ? errorText.title
          : (job.state === 'completed' ? '生成完成' : '—')
        const resultDetail = job.state === 'failed'
          ? errorText.detail
          : (job.resultContentVersionId ? `内容 ${shortId(job.resultContentVersionId)}` : '')
        return `
          <tr class="${processing ? 'job-row is-processing' : 'job-row'}">
            <td class="job-song-cell">
              <div class="job-song">
                ${job.coverURL ? `<img src="${Admin.esc(job.coverURL)}" alt="" loading="lazy" decoding="async">` : '<span class="job-cover-placeholder" aria-hidden="true">♪</span>'}
                <span class="job-song-copy">
                  <strong title="${Admin.esc(job.songTitle || '')}">${Admin.esc(job.songTitle || '未知歌曲')}</strong>
                  <span>${Admin.esc([job.artistName, job.albumName].filter(Boolean).join(' · ') || '歌曲资料待补充')}</span>
                  <small>${Admin.esc([job.platform, job.locale].filter(Boolean).join(' · '))} · ${Admin.esc(shortId(job.songId))}</small>
                </span>
              </div>
            </td>
            <td>
              <div class="job-progress">
                ${processing ? `<span class="job-processing-label"><i aria-hidden="true"></i>正在处理 · ${Admin.esc(statusLabels[job.state])}</span>` : badge(job.state)}
                <span>${Admin.esc(jobReason(job.reason))}</span>
                <small>任务 ${Admin.esc(shortId(job.id))}</small>
              </div>
            </td>
            <td>${jobTimelineMarkup(job)}</td>
            <td><strong>${Admin.esc(`${job.attemptCount} / ${job.maxAttempts}`)}</strong></td>
            <td><strong>${Admin.esc(`${job.tokenInput ?? '—'} / ${job.tokenOutput ?? '—'}`)}</strong><span>${job.cost == null ? '—' : `¥ ${Number(job.cost).toFixed(6)}`}</span></td>
            <td><strong>${Admin.esc(resultTitle)}</strong>${resultDetail ? `<span title="${Admin.esc(resultDetail)}">${Admin.esc(resultDetail)}</span>` : ''}</td>
            <td class="job-action-cell">${job.state === 'failed' ? `<button class="btn btn-secondary btn-small" data-retry-job="${Admin.esc(job.id)}">重试</button>` : ''}</td>
          </tr>
        `
      }).join('') : tableEmptyRow(7, '没有符合条件的任务')
      els.jobsTable.querySelectorAll('[data-retry-job]').forEach((button) => button.addEventListener('click', () => retryJob(button)))
    } catch (error) {
      if (!silent) els.jobsTable.innerHTML = tableEmptyRow(7, error.message)
    } finally {
      state.jobsLoading = false
    }
  }

  function renderJobOverview(counts) {
    const items = [
      ['active', '活动任务', counts.active],
      ['processing', '正在处理', counts.processing],
      ['queued', '排队中', counts.queued],
      ['completed', '已完成', counts.completed],
      ['failed', '失败', counts.failed]
    ]
    els.jobsQueueOverview.innerHTML = items.map(([filter, label, value]) => `
      <button class="job-queue-stat ${els.jobsStateFilter.value === filter ? 'is-active' : ''}" type="button" data-job-filter="${filter}">
        <span>${label}</span><strong>${Admin.fmtNum(value || 0)}</strong>
      </button>
    `).join('')
    els.jobsQueueOverview.querySelectorAll('[data-job-filter]').forEach((button) => {
      button.addEventListener('click', () => {
        els.jobsStateFilter.value = els.jobsStateFilter.value === button.dataset.jobFilter ? '' : button.dataset.jobFilter
        state.jobsPage = 0
        loadJobs()
      })
    })
  }

  function renderJobPagination(visibleCount) {
    const first = state.jobsTotal === 0 ? 0 : state.jobsPage * state.jobsPageSize + 1
    const last = Math.min(state.jobsTotal, state.jobsPage * state.jobsPageSize + visibleCount)
    const totalPages = Math.max(1, Math.ceil(state.jobsTotal / state.jobsPageSize))
    els.jobsQueueMeta.textContent = `显示 ${first}–${last}，共 ${Admin.fmtNum(state.jobsTotal)} 个任务`
    els.jobsPageLabel.textContent = `第 ${state.jobsPage + 1} / ${totalPages} 页`
    els.jobsPreviousPage.disabled = state.jobsPage <= 0
    els.jobsNextPage.disabled = (state.jobsPage + 1) * state.jobsPageSize >= state.jobsTotal
  }

  function jobTimelineMarkup(job) {
    if (job.state === 'queued') {
      const availableAt = job.availableAt ? new Date(job.availableAt) : null
      const delayed = availableAt && availableAt.getTime() > Date.now()
      return `<strong>${job.queuePosition ? `队列第 ${Admin.fmtNum(job.queuePosition)} 位` : '等待调度'}</strong><span>${delayed ? `预计 ${Admin.fmtDate(job.availableAt)} 后继续` : `加入于 ${Admin.fmtDate(job.createdAt)}`}</span>`
    }
    if (['collecting', 'generating', 'validating'].includes(job.state)) {
      return `<strong>已处理 ${Admin.esc(formatElapsed(job.startedAt))}</strong><span>开始于 ${Admin.esc(Admin.fmtDate(job.startedAt))}</span>`
    }
    const timestamp = job.finishedAt || job.updatedAt
    return `<strong>${Admin.esc(formatDuration(job.durationMs))}</strong><span>${Admin.esc(Admin.fmtDate(timestamp))}</span>`
  }

  function jobReason(reason) {
    const value = String(reason || '')
    if (value === 'first_access') return '首次播放获取'
    if (value.startsWith('admin:')) return '管理端重新生成'
    if (value === 'retry') return '失败后重试'
    return value || '内容生成'
  }

  function formatElapsed(startedAt) {
    if (!startedAt) return '—'
    const elapsed = Math.max(0, Date.now() - Date.parse(startedAt))
    if (elapsed < 60_000) return `${Math.floor(elapsed / 1_000)} 秒`
    if (elapsed < 3_600_000) return `${Math.floor(elapsed / 60_000)} 分钟`
    return `${Math.floor(elapsed / 3_600_000)} 小时 ${Math.floor((elapsed % 3_600_000) / 60_000)} 分钟`
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
        <tr><td class="source-name-cell"><a href="${Admin.esc(source.url)}" target="_blank" rel="noreferrer" title="${Admin.esc(source.title)}">${Admin.esc(source.title)}</a></td><td><select class="source-grade-select" data-source-grade="${Admin.esc(source.id)}"><option ${source.grade === 'A' ? 'selected' : ''}>A</option><option ${source.grade === 'B' ? 'selected' : ''}>B</option><option ${source.grade === 'C' ? 'selected' : ''}>C</option><option ${source.grade === 'D' ? 'selected' : ''}>D</option></select></td><td>${Admin.esc(source.publisher)}</td><td>${Admin.esc(sourceKind(source))}</td><td>${Admin.esc(formatSourceFields(source.supportedFields) || '—')}</td><td>${Admin.esc(Admin.fmtDate(source.fetchedAt))}</td><td>${source.accessible ? badge('accessible') : badge('unavailable')}</td><td class="source-action-cell"><button class="btn btn-secondary btn-small" data-source-access="${Admin.esc(source.id)}" data-accessible="${source.accessible}">${source.accessible ? '标记失效' : '恢复'}</button></td></tr>
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
    els.configPromptVersion.value = ai.promptVersion || 'song-editor-web-v6'
    els.configSchemaVersion.value = ai.schemaVersion || '1'
    els.configTemperature.value = ai.temperature ?? 0.2
    els.configMaxOutput.value = ai.maxOutputTokens ?? 2000
    els.configMaxInput.value = ai.maxInputTokens ?? 12000
    els.configTaskTokenLimit.value = ai.perTaskTokenLimit ?? 20000
    els.configMaxAttempts.value = ai.maxAttempts ?? 3
    els.configConcurrency.value = ai.concurrency ?? 2
    els.configRequestsPerMinute.value = ai.requestsPerMinute ?? 60
    els.configCircuitBreaker.value = ai.circuitBreakerFailures ?? 5
    els.configCircuitRecovery.value = ai.circuitBreakerRecoverySeconds ?? 60
    els.configDailyBudget.value = ai.dailyBudget ?? 0
    els.configAutoPublish.value = String(ai.autoPublish === true)
    els.configMinimumGrade.value = ai.minimumSourceGrade || 'B'
    els.configHighRiskReview.value = String(ai.highRiskRequiresReview === true)
    els.configConflictReview.value = String(ai.sourceConflictRequiresReview === true)
    const retrievalEnabled = ai.webRetrievalEnabled !== false
    const configuredProviders = Array.isArray(ai.webSearchProviders) ? ai.webSearchProviders : ['360', 'baidu', 'bing', 'sogou']
    const configuredSources = Array.isArray(ai.webPreferredSources) ? ai.webPreferredSources : ['douban', 'xiaohongshu']
    els.configWebRetrieval.value = String(retrievalEnabled)
    els.configWebMaximumSources.value = ai.webMaximumSources ?? 10
    els.configProvider360.checked = configuredProviders.includes('360')
    els.configProviderBaidu.checked = configuredProviders.includes('baidu')
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
    const providerCount = [els.configProvider360, els.configProviderBaidu, els.configProviderBing, els.configProviderSogou].filter((input) => input?.checked).length
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
            maxInputTokens: Number(els.configMaxInput.value),
            perTaskTokenLimit: Number(els.configTaskTokenLimit.value),
            maxAttempts: Number(els.configMaxAttempts.value),
            concurrency: Number(els.configConcurrency.value),
            requestsPerMinute: Number(els.configRequestsPerMinute.value),
            circuitBreakerFailures: Number(els.configCircuitBreaker.value),
            circuitBreakerRecoverySeconds: Number(els.configCircuitRecovery.value),
            dailyBudget: Number(els.configDailyBudget.value),
            autoPublish: els.configAutoPublish.value === 'true',
            minimumSourceGrade: els.configMinimumGrade.value,
            highRiskRequiresReview: els.configHighRiskReview.value === 'true',
            sourceConflictRequiresReview: els.configConflictReview.value === 'true',
            webRetrievalEnabled: els.configWebRetrieval.value === 'true',
            webMaximumSources: Number(els.configWebMaximumSources.value),
            webSearchProviders: [
              els.configProvider360.checked ? '360' : null,
              els.configProviderBaidu.checked ? 'baidu' : null,
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
    const labels = { '360': '360', '360-search': '360', baidu: '百度', bing: 'Bing', sogou: '搜狗' }
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

  function localizeJobError(job) {
    if (job.errorTitle || job.errorDetail) {
      return {
        title: job.errorTitle || '任务执行失败',
        detail: job.errorDetail || '请查看服务端日志'
      }
    }
    const code = String(job?.errorCode || job?.internalErrorCode || '')
    if (!code) return { title: '—', detail: '' }

    if (code === 'AI_MISSING_EVIDENCE_BACKED_SECTION') {
      const rawMessage = String(job?.errorMessage || '')
      const missingLabels = Object.entries(contentFieldLabels)
        .filter(([field, label]) => rawMessage.includes(field) || rawMessage.includes(label))
        .map(([, label]) => label)
      return {
        title: '内容生成不完整',
        detail: missingLabels.length > 0
          ? `${missingLabels.join('、')}缺少可信资料依据`
          : jobErrorLabels[code][1]
      }
    }

    const labels = jobErrorLabels[code]
    if (labels) return { title: labels[0], detail: labels[1] }
    return { title: '任务执行失败', detail: '请查看服务端日志' }
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
