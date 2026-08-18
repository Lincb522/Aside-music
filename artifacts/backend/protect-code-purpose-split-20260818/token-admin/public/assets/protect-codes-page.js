(function () {
  const { setupAuth, request, notify, esc, fmtDate } = window.TokenAdmin

  const state = {
    protectCodes: [],
    sort: 'desc',
    filter: 'all',
    purpose: 'all',
  }

  const els = {
    logoutButton: document.getElementById('logoutButton'),
    generateBtn: document.getElementById('generateBtn'),
    exportBtn: document.getElementById('exportBtn'),
    codeGrid: document.getElementById('codeGrid'),
    protectSummary: document.getElementById('protectSummary'),
    codeFilter: document.getElementById('codeFilter'),
    purposeFilter: document.getElementById('purposeFilter'),
    generatePurpose: document.getElementById('generatePurpose'),
  }

  if (els.logoutButton) els.logoutButton.addEventListener('click', window.TokenAdmin.logout)

  function escapeAttr(value) {
    return esc(String(value || '')).replace(/"/g, '&quot;')
  }

  function sortedCodes(source = state.protectCodes) {
    return [...source].sort((a, b) => {
      const dateDelta = new Date(a.createdAt) - new Date(b.createdAt)
      if (dateDelta !== 0) return state.sort === 'asc' ? dateDelta : -dateDelta
      return state.sort === 'asc'
        ? String(a.code).localeCompare(String(b.code))
        : String(b.code).localeCompare(String(a.code))
    })
  }

  function visibleCodes() {
    const filtered = state.protectCodes.filter(code => {
      if (state.purpose !== 'all' && code.purpose !== state.purpose) return false
      const exhausted = code.currentUses >= code.maxUses
      if (state.filter === 'available') return !exhausted
      if (state.filter === 'exhausted') return exhausted
      return true
    })
    return sortedCodes(filtered)
  }

  function renderSummary() {
    const available = state.protectCodes.filter(code => code.currentUses < code.maxUses).length
    const exhausted = state.protectCodes.length - available
    const ipa = state.protectCodes.filter(code => code.purpose === 'ipa').length
    const tf = state.protectCodes.filter(code => code.purpose === 'tf').length
    if (!els.protectSummary) return
    els.protectSummary.innerHTML = `
      <div><span>IPA 自签</span><strong>${ipa}</strong></div>
      <div><span>TestFlight</span><strong>${tf}</strong></div>
      <div><span>可用 / 已用尽</span><strong>${available} / ${exhausted}</strong></div>
      <div><span>当前显示</span><strong>${visibleCodes().length}</strong></div>
    `
  }

  function renderCodes() {
    const sorted = visibleCodes()
    renderSummary()

    els.codeGrid.innerHTML = sorted.length
      ? sorted.map(c => `
          <article class="token-row protect-code-row">
            <div class="token-row-main">
              <div class="feature-copy">
                <div class="protect-code-head">
                  <h3 class="token-name" style="font-family: monospace; letter-spacing: 2px;">${esc(c.code)}</h3>
                  <span class="status-pill">${c.purpose === 'ipa' ? 'IPA 自签' : 'TestFlight'}</span>
                  <span class="status-pill ${c.currentUses >= c.maxUses ? 'soft' : 'good'}">
                    ${c.currentUses >= c.maxUses ? '已用尽' : '可用'}
                  </span>
                </div>
                <div class="token-meta-line">
                  <span>创建于 ${fmtDate(c.createdAt)}</span>
                </div>
              </div>
            </div>
            <div class="metric-ribbon" style="margin-top: 0;">
              <div class="metric-line">
                <span>已验证次数</span>
                <strong>${c.currentUses} / ${c.maxUses}</strong>
              </div>
            </div>
            <div class="token-row-aside">
              <button class="btn btn-ghost btn-small" type="button" data-action="addUse" data-code="${escapeAttr(c.code)}">+1 次数</button>
              <button class="btn btn-ghost btn-small" type="button" data-action="delete" data-code="${escapeAttr(c.code)}">删除</button>
            </div>
          </article>
        `).join('')
      : '<div class="empty">没有匹配的邀请码</div>'
  }

  async function loadCodes() {
    els.generateBtn.disabled = true;
    try {
      const res = await request('/api/protect-codes')
      state.protectCodes = res.protectCodes || []
      renderCodes()
    } catch (e) {
      notify('加载失败: ' + e.message, 'error')
    } finally {
      els.generateBtn.disabled = false;
    }
  }

  els.generateBtn.addEventListener('click', async () => {
    const rawCount = prompt('请输入要生成的代码数量', '100');
    if (!rawCount) return;
    const count = parseInt(rawCount, 10);
    if (isNaN(count) || count <= 0) return notify('数量无效', 'error');

    const rawMaxUses = prompt('请输入每个验证码允许申请的次数', '3');
    if (!rawMaxUses) return;
    const maxUses = parseInt(rawMaxUses, 10);
    if (isNaN(maxUses) || maxUses <= 0) return notify('次数无效', 'error');
    const purpose = els.generatePurpose?.value === 'ipa' ? 'ipa' : 'tf'
    const purposeLabel = purpose === 'ipa' ? 'IPA 自签' : 'TestFlight'

    if (!confirm(`确定要生成 ${count} 个 ${purposeLabel} 验证码（每个可用 ${maxUses} 次）吗？`)) return;
    try {
      els.generateBtn.disabled = true;
      const res = await request('/api/protect-codes/generate', {
        method: 'POST',
        body: JSON.stringify({ count, maxUses, purpose })
      })
      state.protectCodes = res.protectCodes || []
      notify(`成功生成 ${res.generated} 个 ${purposeLabel} 验证码`, 'success')
      renderCodes();
    } catch (e) {
      notify('生成失败: ' + e.message, 'error')
    } finally {
      els.generateBtn.disabled = false;
    }
  })

  els.codeGrid.addEventListener('click', async event => {
    const btn = event.target.closest('button[data-action]');
    if (!btn) return;
    const action = btn.dataset.action;
    const code = btn.dataset.code;

    if (action === 'delete') {
      if (!confirm('确定要删除保护码 ' + code + ' 吗？')) return;
      try {
        await request('/api/protect-codes/' + encodeURIComponent(code), { method: 'DELETE' })
        state.protectCodes = state.protectCodes.filter(c => c.code !== code)
        notify('已删除保护码', 'success')
        renderCodes()
      } catch (e) {
        notify('删除失败: ' + e.message, 'error')
      }
    } else if (action === 'addUse') {
      const addAmount = prompt('请输入要增加的使用次数', '1');
      if (!addAmount) return;
      const addUses = parseInt(addAmount, 10);
      if (isNaN(addUses) || addUses <= 0) return notify('次数无效', 'error');
      
      try {
        const res = await request('/api/protect-codes/' + encodeURIComponent(code), {
          method: 'PUT',
          body: JSON.stringify({ addUses })
        })
        const match = state.protectCodes.find(c => c.code === code)
        if (match) match.maxUses = res.item.maxUses;
        notify(`保护码可用次数已增加`, 'success')
        renderCodes()
      } catch (e) {
        notify('修改失败: ' + e.message, 'error')
      }
    }
  })

  if (els.exportBtn) els.exportBtn.addEventListener('click', () => {
    const validCodes = sortedCodes(state.protectCodes.filter(c =>
      c.currentUses < c.maxUses && (state.purpose === 'all' || c.purpose === state.purpose)
    ))
    if (!validCodes.length) {
      notify('当前没有任何可用邀请码可供导出', 'warning')
      return;
    }
    const lines = validCodes.map(c => c.code).join('\n')
    const blob = new Blob([lines], { type: 'text/plain' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `protect-codes-${state.purpose}-${fmtDate(new Date()).replace(/[\/ :]/g, '')}.txt`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
    notify(`成功导出 ${validCodes.length} 个邀请码`, 'success')
  })

  document.querySelectorAll('[data-sort]').forEach(button => {
    button.addEventListener('click', () => {
      state.sort = button.dataset.sort === 'asc' ? 'asc' : 'desc'
      document.querySelectorAll('[data-sort]').forEach(item => {
        item.classList.toggle('active', item.dataset.sort === state.sort)
      })
      renderCodes()
    })
  })

  if (els.codeFilter) {
    els.codeFilter.addEventListener('change', () => {
      state.filter = els.codeFilter.value
      renderCodes()
    })
  }

  if (els.purposeFilter) {
    els.purposeFilter.addEventListener('change', () => {
      state.purpose = els.purposeFilter.value
      renderCodes()
    })
  }

  setupAuth(loadCodes)
})()
