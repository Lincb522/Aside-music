(function () {
  const { setupAuth, request, notify, esc, fmtDate } = window.TokenAdmin

  const state = {
    bindings: [],
    filter: '',
  }

  const els = {
    logoutButton: document.getElementById('logoutButton'),
    refreshBtn: document.getElementById('refreshBtn'),
    searchInput: document.getElementById('searchInput'),
    grid: document.getElementById('bindingGrid'),
    count: document.getElementById('bindingCount'),
  }

  if (els.logoutButton) els.logoutButton.addEventListener('click', window.TokenAdmin.logout)

  const SOURCE_LABELS = {
    'self-register': '自助注册',
    'tf-public-join': 'TF 正式',
    'tf-public-trial': 'TF 体验',
    'tf-auto': 'TF 自动',
  }

  function escapeAttr(value) {
    return esc(String(value || '')).replace(/"/g, '&quot;')
  }

  function sourceLabel(s) {
    return SOURCE_LABELS[s] || (s ? esc(s) : '未知')
  }

  function matchesFilter(b, q) {
    if (!q) return true
    const hay = [b.email, b.name, b.tokenKey, b.code, b.codePurpose, b.source].map(x => String(x || '').toLowerCase()).join(' ')
    return hay.includes(q)
  }

  function renderList() {
    const q = state.filter.trim().toLowerCase()
    const list = state.bindings.filter(b => matchesFilter(b, q))
    els.count.textContent = `(${list.length}/${state.bindings.length})`

    if (!list.length) {
      els.grid.innerHTML = '<div class="empty">暂无匹配的绑定记录</div>'
      return
    }

    els.grid.innerHTML = list.map(b => {
      const tokenStatus = !b.tokenExists
        ? '<span class="status-pill soft">Token 不存在</span>'
        : (b.tokenEnabled
            ? '<span class="status-pill good">已启用</span>'
            : '<span class="status-pill soft">已禁用</span>')
      const permStatus = b.tokenExists
        ? (b.tokenExpiresAt ? '<span class="status-pill">限时</span>' : '<span class="status-pill good">永久</span>')
        : ''
      const backfilled = b.backfilled ? '<span class="status-pill soft">历史补录</span>' : ''
      const codeText = b.code ? esc(b.code) : '—'
      const codePurpose = b.code
        ? (b.codePurpose === 'ipa' ? 'IPA 自签' : 'TestFlight')
        : '—'
      const toggleLabel = b.tokenEnabled ? '禁用 Token' : '启用 Token'
      const kickBtn = b.canKick
        ? `<button class="btn btn-ghost btn-small" type="button" data-action="kick" data-id="${escapeAttr(b.id)}">踢出测试组</button>`
        : ''
      const toggleBtn = b.tokenExists
        ? `<button class="btn btn-ghost btn-small" type="button" data-action="toggle" data-id="${escapeAttr(b.id)}">${toggleLabel}</button>`
        : ''
      return `
        <article class="token-row binding-row">
          <div class="token-row-main">
            <div class="feature-copy">
              <div class="binding-row-head">
                <h3 class="token-name">${esc(b.name || '(未命名)')}</h3>
                <div class="binding-statuses">${tokenStatus} ${permStatus} ${backfilled}</div>
              </div>
              <div class="token-meta-line">
                <span>${esc(b.email || '—')}</span>
                <span>Token: <code>${esc(b.tokenKey || '—')}</code></span>
                <span>来源: ${sourceLabel(b.source)}</span>
              </div>
              <div class="token-meta-line">
                <span>保护码: <code>${codeText}</code></span>
                <span>用途: ${codePurpose}</span>
                <span>绑定于 ${fmtDate(b.createdAt)}</span>
              </div>
            </div>
          </div>
          <div class="token-row-aside">
            ${toggleBtn}
            ${kickBtn}
            <button class="btn btn-ghost btn-small" type="button" data-action="delete" data-id="${escapeAttr(b.id)}">删除记录</button>
          </div>
        </article>
      `
    }).join('')
  }

  async function loadBindings() {
    els.grid.innerHTML = '<div class="empty">加载中...</div>'
    try {
      const res = await request('/api/bindings')
      state.bindings = res.bindings || []
      renderList()
    } catch (e) {
      notify('加载失败: ' + e.message, 'error')
      els.grid.innerHTML = '<div class="empty">加载失败</div>'
    }
  }

  if (els.refreshBtn) els.refreshBtn.addEventListener('click', loadBindings)
  if (els.searchInput) els.searchInput.addEventListener('input', () => {
    state.filter = els.searchInput.value
    renderList()
  })

  els.grid.addEventListener('click', async event => {
    const btn = event.target.closest('button[data-action]')
    if (!btn) return
    const action = btn.dataset.action
    const id = btn.dataset.id
    const binding = state.bindings.find(b => b.id === id)
    if (!binding) return

    if (action === 'toggle') {
      try {
        const res = await request('/api/bindings/' + encodeURIComponent(id) + '/toggle-token', { method: 'POST' })
        binding.tokenEnabled = res.enabled
        notify(res.enabled ? 'Token 已启用' : 'Token 已禁用', 'success')
        renderList()
      } catch (e) {
        notify('操作失败: ' + e.message, 'error')
      }
    } else if (action === 'kick') {
      if (!confirm(`确定要把 ${binding.email} 踢出 TestFlight 测试组吗？此操作会从测试组移除该 Apple ID。`)) return
      btn.disabled = true
      try {
        await request('/api/bindings/' + encodeURIComponent(id) + '/kick', { method: 'POST' })
        notify('已踢出测试组', 'success')
      } catch (e) {
        notify('踢出失败: ' + e.message, 'error')
      } finally {
        btn.disabled = false
      }
    } else if (action === 'delete') {
      if (!confirm('仅删除绑定记录（不影响 Token / 测试组）。确定删除？')) return
      try {
        await request('/api/bindings/' + encodeURIComponent(id), { method: 'DELETE' })
        state.bindings = state.bindings.filter(b => b.id !== id)
        notify('已删除绑定记录', 'success')
        renderList()
      } catch (e) {
        notify('删除失败: ' + e.message, 'error')
      }
    }
  })

  setupAuth(loadBindings)
})()
