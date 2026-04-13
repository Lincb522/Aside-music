(function () {
  const { setupAuth, request, notify, esc, fmtDate, fmtNum, logout, href } = window.TokenAdmin

  const DURATION_PRESETS = [
    { id: 'permanent', label: '永久', days: 0 },
    { id: 'month', label: '月', days: 30 },
    { id: 'halfyear', label: '半年', days: 183 },
    { id: 'year', label: '年', days: 365 }
  ]

  const FILTERS = [
    { id: 'all', label: '全部' },
    { id: 'active', label: '启用' },
    { id: 'disabled', label: '停用' },
    { id: 'expired', label: '过期' },
    { id: 'synced', label: '已同步' }
  ]

  const state = {
    status: null,
    tokens: [],
    search: '',
    filter: 'all',
    createPreset: 'month',
    sort: 'desc',
    page: 1,
    pageSize: 12
  }

  const els = {
    logoutButton: document.getElementById('logoutButton'),
    createPanel: document.getElementById('createPanel'),
    filtersPanel: document.getElementById('filtersPanel'),
    tokenGrid: document.getElementById('tokenGrid'),
    tokenPager: document.getElementById('tokenPager'),
    policyPanel: document.getElementById('policyPanel')
  }

  if (els.logoutButton) els.logoutButton.addEventListener('click', logout)

  function escapeAttr(value) {
    return esc(String(value || '')).replace(/"/g, '&quot;')
  }

  function statusPill(token) {
    const kind = token.enabled && !token.isExpired ? 'good' : (token.isExpired ? 'warn' : 'soft')
    const label = token.enabled && !token.isExpired ? '在线' : (token.isExpired ? '过期' : '停用')
    return `<span class="status-pill ${kind}">${label}</span>`
  }

  function filteredTokens() {
    let tokens = [...state.tokens]
    if (state.filter === 'active') tokens = tokens.filter(token => token.enabled && !token.isExpired)
    if (state.filter === 'disabled') tokens = tokens.filter(token => !token.enabled)
    if (state.filter === 'expired') tokens = tokens.filter(token => token.isExpired)
    if (state.filter === 'synced') tokens = tokens.filter(token => token.playlistSnapshot?.hasSnapshot)
    if (state.search) {
      tokens = tokens.filter(token => [token.name, token.key].filter(Boolean).join(' ').toLowerCase().includes(state.search))
    }
    tokens.sort((left, right) => {
      const delta = new Date(right.createdAt) - new Date(left.createdAt)
      return state.sort === 'desc' ? delta : -delta
    })
    return tokens
  }

  function paginatedTokens() {
    const tokens = filteredTokens()
    const totalPages = Math.max(1, Math.ceil(tokens.length / state.pageSize))
    if (state.page > totalPages) state.page = totalPages
    const start = (state.page - 1) * state.pageSize
    return {
      tokens: tokens.slice(start, start + state.pageSize),
      total: tokens.length,
      totalPages
    }
  }

  function renderCreatePanel() {
    const status = state.status || {}
    const syncedCount = state.tokens.filter(token => token.playlistSnapshot?.hasSnapshot).length

    els.createPanel.innerHTML = `
      <div class="panel-head">
        <div>
          <small class="eyebrow">Create</small>
          <h3>新增 Token</h3>
          <p>只输入名称和时效，其他规则默认继承当前设置。</p>
        </div>
      </div>
      <div class="metric-ribbon" style="margin-bottom:18px">
        <div class="metric-line">
          <span>当前 Token</span>
          <strong>${fmtNum(state.tokens.length)}</strong>
        </div>
        <div class="metric-line">
          <span>已同步歌单</span>
          <strong>${fmtNum(syncedCount)}</strong>
        </div>
        <div class="metric-line">
          <span>默认设备</span>
          <strong>${fmtNum(status.maxDevicesPerToken ?? 3)} 台</strong>
        </div>
      </div>
      <div class="field-stack">
        <div class="field">
          <label for="createTokenName">名称</label>
          <input id="createTokenName" placeholder="例如：iPhone 16 Pro">
        </div>
        <div class="field">
          <label>有效期</label>
          <div class="preset-row">
            ${DURATION_PRESETS.map(preset => `
              <button class="preset-button ${state.createPreset === preset.id ? 'active' : ''}" type="button" data-create-preset="${preset.id}">
                ${preset.label}
              </button>
            `).join('')}
          </div>
        </div>
        <div class="field-grid">
          <div class="field">
            <label for="createRateLimit">每分钟</label>
            <input id="createRateLimit" type="number" min="0" value="${status.defaultRateLimit ?? 60}">
          </div>
          <div class="field">
            <label for="createDownloadLimit">每天下载</label>
            <input id="createDownloadLimit" type="number" min="0" value="${status.defaultDownloadLimit ?? 0}">
          </div>
          <div class="field">
            <label for="createMaxDevices">设备上限</label>
            <input id="createMaxDevices" type="number" min="1" max="50" value="${status.maxDevicesPerToken ?? 3}">
          </div>
        </div>
        <div class="action-row">
          <button class="btn btn-primary" type="button" data-action="create-token">创建 Token</button>
        </div>
      </div>
    `
  }

  function renderFiltersPanel() {
    const counts = {
      all: state.tokens.length,
      active: state.tokens.filter(token => token.enabled && !token.isExpired).length,
      disabled: state.tokens.filter(token => !token.enabled).length,
      expired: state.tokens.filter(token => token.isExpired).length,
      synced: state.tokens.filter(token => token.playlistSnapshot?.hasSnapshot).length
    }

    els.filtersPanel.innerHTML = `
      <div class="toolbar-band">
        <div class="panel-head" style="margin-bottom:0">
          <div>
            <small class="eyebrow">Filter</small>
            <h3>筛选与排序</h3>
            <p>列表页只看概要，详细操作进入单独 Token 页面。</p>
          </div>
        </div>
        <div class="search-row">
          <div class="field" style="min-width:min(420px, 100%); flex:1 1 420px">
            <label for="tokenSearchInput">搜索</label>
            <input id="tokenSearchInput" placeholder="名称 / Key" value="${escapeAttr(state.search)}">
          </div>
          <div class="field" style="min-width:160px">
            <label for="pageSizeSelect">每页</label>
            <select id="pageSizeSelect">
              <option value="10" ${state.pageSize === 10 ? 'selected' : ''}>10</option>
              <option value="12" ${state.pageSize === 12 ? 'selected' : ''}>12</option>
              <option value="20" ${state.pageSize === 20 ? 'selected' : ''}>20</option>
              <option value="30" ${state.pageSize === 30 ? 'selected' : ''}>30</option>
            </select>
          </div>
        </div>
        <div class="chip-row">
          ${FILTERS.map(filter => `
            <button class="chip ${state.filter === filter.id ? 'active' : ''}" type="button" data-filter="${filter.id}">
              ${filter.label} ${fmtNum(counts[filter.id] ?? 0)}
            </button>
          `).join('')}
        </div>
        <div class="chip-row">
          <button class="chip ${state.sort === 'desc' ? 'active' : ''}" type="button" data-sort="desc">倒序</button>
          <button class="chip ${state.sort === 'asc' ? 'active' : ''}" type="button" data-sort="asc">正序</button>
        </div>
      </div>
    `

    const searchInput = document.getElementById('tokenSearchInput')
    if (searchInput) {
      searchInput.addEventListener('input', event => {
        state.search = event.target.value.trim().toLowerCase()
        state.page = 1
        renderTokenGrid()
      })
    }

    const pageSizeSelect = document.getElementById('pageSizeSelect')
    if (pageSizeSelect) {
      pageSizeSelect.addEventListener('change', event => {
        state.pageSize = Number(event.target.value || 12)
        state.page = 1
        renderTokenGrid()
      })
    }
  }

  function renderTokenGrid() {
    const { tokens, total, totalPages } = paginatedTokens()

    els.tokenGrid.innerHTML = tokens.length
      ? tokens.map(token => {
        const snapshot = token.playlistSnapshot || {}
        const keyPreview = token.key ? token.key.slice(0, 16) : '—'

        return `
          <article class="token-row">
            <div class="token-row-main">
              <div class="feature-copy">
                <div class="token-row-header">
                  <h3 class="token-name">${esc(token.name || '未命名 Token')}</h3>
                  ${statusPill(token)}
                </div>
                <div class="token-meta-line">
                  <span>${token.expiresAt ? fmtDate(token.expiresAt) : '永久'}</span>
                  <span>${fmtNum(token.deviceCount || 0)} 台设备</span>
                  <span>Key ${esc(keyPreview)}...</span>
                </div>
              </div>
            </div>
            <div class="metric-ribbon">
              <div class="metric-line">
                <span>请求</span>
                <strong>${fmtNum(token.requestCount || 0)}</strong>
              </div>
              <div class="metric-line">
                <span>下载</span>
                <strong>${fmtNum(token.totalDownloads || 0)}</strong>
              </div>
              <div class="metric-line">
                <span>歌单</span>
                <strong>${fmtNum(snapshot.playlistCount || 0)}</strong>
              </div>
              <div class="metric-line">
                <span>歌曲</span>
                <strong>${fmtNum(snapshot.songCount || 0)}</strong>
              </div>
            </div>
            <div class="token-row-aside">
              <div class="notes-box">${snapshot.hasSnapshot ? `最后同步 ${fmtDate(snapshot.updatedAt)}<br>${fmtNum(snapshot.songCount || 0)} 首歌曲` : '未同步本地歌单'}</div>
              <a class="btn btn-primary btn-small" href="${href(`/tokens/${token.id}`)}">进入详情</a>
            </div>
          </article>
        `
      }).join('')
      : '<div class="empty">没有匹配的 Token</div>'

    els.tokenPager.innerHTML = total
      ? `
        <div class="toolbar-band">
          <div class="search-row" style="justify-content:space-between">
            <div class="muted">共 ${fmtNum(total)} 个 Token，第 ${state.page} / ${totalPages} 页</div>
            <div class="pagination-bar">
              <button class="btn btn-secondary btn-small" type="button" data-page="prev" ${state.page <= 1 ? 'disabled' : ''}>上一页</button>
              <button class="btn btn-secondary btn-small" type="button" data-page="next" ${state.page >= totalPages ? 'disabled' : ''}>下一页</button>
            </div>
          </div>
        </div>
      `
      : ''
  }

  function renderPolicyPanel() {
    const status = state.status || {}

    els.policyPanel.innerHTML = `
      <div class="panel-head">
        <div>
          <small class="eyebrow">Rules</small>
          <h3>默认规则</h3>
          <p>这里只设置默认值和批量应用。</p>
        </div>
      </div>
      <div class="policy-grid">
        <article class="rule-card">
          <div class="rule-head">
            <div>
              <span>验证</span>
              <strong>${status.globalEnabled ? '开启' : '关闭'}</strong>
            </div>
            <button class="btn btn-secondary btn-small" type="button" data-action="toggle-global">切换</button>
          </div>
          <div class="notes-box">控制 Token 是否需要验证。</div>
        </article>
        <article class="rule-card">
          <div class="rule-head">
            <div>
              <span>默认限速</span>
              <strong>${fmtNum(status.defaultRateLimit || 0)} / 分钟</strong>
            </div>
            <button class="chip ${status.rateLimitEnabled !== false ? 'active' : ''}" type="button" data-action="toggle-rate-enabled">
              ${status.rateLimitEnabled !== false ? '限速开启' : '限速关闭'}
            </button>
          </div>
          <div class="field">
            <label for="policyRateInput">默认值</label>
            <input id="policyRateInput" type="number" min="0" value="${status.defaultRateLimit ?? 0}">
          </div>
          <div class="rule-actions">
            <button class="btn btn-secondary btn-small" type="button" data-action="save-rate-default">保存</button>
            <button class="btn btn-ghost btn-small" type="button" data-action="apply-rate-all">应用全部</button>
          </div>
        </article>
        <article class="rule-card">
          <div class="rule-head">
            <div>
              <span>默认下载</span>
              <strong>${fmtNum(status.defaultDownloadLimit || 0)} / 天</strong>
            </div>
            <button class="chip ${status.downloadLimitEnabled ? 'active' : ''}" type="button" data-action="toggle-download-enabled">
              ${status.downloadLimitEnabled ? '下载开启' : '下载关闭'}
            </button>
          </div>
          <div class="field">
            <label for="policyDownloadInput">默认值</label>
            <input id="policyDownloadInput" type="number" min="0" value="${status.defaultDownloadLimit ?? 0}">
          </div>
          <div class="rule-actions">
            <button class="btn btn-secondary btn-small" type="button" data-action="save-download-default">保存</button>
            <button class="btn btn-ghost btn-small" type="button" data-action="apply-download-all">应用全部</button>
          </div>
        </article>
        <article class="rule-card">
          <div class="rule-head">
            <div>
              <span>默认设备</span>
              <strong>${fmtNum(status.maxDevicesPerToken || 0)} 台</strong>
            </div>
            <button class="chip ${status.deviceBindEnabled ? 'active' : ''}" type="button" data-action="toggle-device-enabled">
              ${status.deviceBindEnabled ? '设备开启' : '设备关闭'}
            </button>
          </div>
          <div class="field">
            <label for="policyDeviceInput">默认值</label>
            <input id="policyDeviceInput" type="number" min="1" max="50" value="${status.maxDevicesPerToken ?? 3}">
          </div>
          <div class="rule-actions">
            <button class="btn btn-secondary btn-small" type="button" data-action="save-device-default">保存</button>
            <button class="btn btn-ghost btn-small" type="button" data-action="apply-device-all">应用全部</button>
          </div>
        </article>
      </div>
    `
  }

  function renderAll() {
    renderCreatePanel()
    renderFiltersPanel()
    renderPolicyPanel()
    renderTokenGrid()
  }

  async function loadStatus() {
    state.status = await request('/api/status')
    state.tokens = state.status.tokens || []
    renderAll()
  }

  async function createToken() {
    const name = document.getElementById('createTokenName')?.value.trim() || '未命名 Token'
    const rateLimit = Number(document.getElementById('createRateLimit')?.value || 0)
    const downloadLimit = Number(document.getElementById('createDownloadLimit')?.value || 0)
    const maxDevices = Number(document.getElementById('createMaxDevices')?.value || 3)
    const preset = DURATION_PRESETS.find(item => item.id === state.createPreset)

    const token = await request('/api/tokens', {
      method: 'POST',
      body: JSON.stringify({
        name,
        expiresIn: preset?.days || 0,
        rateLimit,
        downloadLimit,
        maxDevices
      })
    })

    window.location.href = href(`/tokens/${token.id}`)
  }

  async function handlePolicyAction(action) {
    const rateValue = Number(document.getElementById('policyRateInput')?.value || 0)
    const downloadValue = Number(document.getElementById('policyDownloadInput')?.value || 0)
    const deviceValue = Number(document.getElementById('policyDeviceInput')?.value || 3)

    if (action === 'toggle-global') await request('/api/toggle', { method: 'POST' })
    if (action === 'toggle-rate-enabled') await request('/api/ratelimit/toggle', { method: 'POST' })
    if (action === 'toggle-download-enabled') await request('/api/downloadlimit/toggle', { method: 'POST' })
    if (action === 'toggle-device-enabled') await request('/api/devicebind/toggle', { method: 'POST' })
    if (action === 'save-rate-default') await request('/api/ratelimit/default', { method: 'POST', body: JSON.stringify({ value: rateValue }) })
    if (action === 'apply-rate-all') await request('/api/ratelimit/apply-all', { method: 'POST', body: JSON.stringify({ value: rateValue }) })
    if (action === 'save-download-default') await request('/api/downloadlimit/default', { method: 'POST', body: JSON.stringify({ value: downloadValue }) })
    if (action === 'apply-download-all') await request('/api/downloadlimit/apply-all', { method: 'POST', body: JSON.stringify({ value: downloadValue }) })
    if (action === 'save-device-default') await request('/api/devicebind/max', { method: 'POST', body: JSON.stringify({ value: deviceValue }) })
    if (action === 'apply-device-all') await request('/api/devicebind/apply-all', { method: 'POST', body: JSON.stringify({ value: deviceValue }) })

    notify('已更新', 'success')
    await loadStatus()
  }

  els.createPanel.addEventListener('click', async event => {
    const presetButton = event.target.closest('[data-create-preset]')
    if (presetButton) {
      state.createPreset = presetButton.dataset.createPreset
      renderCreatePanel()
      return
    }

    const actionButton = event.target.closest('[data-action="create-token"]')
    if (!actionButton) return

    try {
      await createToken()
    } catch (error) {
      notify(error.message || '创建失败', 'error')
    }
  })

  els.filtersPanel.addEventListener('click', event => {
    const filterButton = event.target.closest('[data-filter]')
    if (filterButton) {
      state.filter = filterButton.dataset.filter
      state.page = 1
      renderFiltersPanel()
      renderTokenGrid()
      return
    }

    const sortButton = event.target.closest('[data-sort]')
    if (sortButton) {
      state.sort = sortButton.dataset.sort
      state.page = 1
      renderFiltersPanel()
      renderTokenGrid()
    }
  })

  els.tokenPager.addEventListener('click', event => {
    const button = event.target.closest('[data-page]')
    if (!button) return
    if (button.dataset.page === 'prev' && state.page > 1) state.page -= 1
    if (button.dataset.page === 'next') state.page += 1
    renderTokenGrid()
  })

  els.policyPanel.addEventListener('click', async event => {
    const button = event.target.closest('[data-action]')
    if (!button) return

    try {
      await handlePolicyAction(button.dataset.action)
    } catch (error) {
      notify(error.message || '操作失败', 'error')
    }
  })

  setupAuth(loadStatus)
})()
