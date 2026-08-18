(function () {
  const { setupAuth, request, notify, esc, fmtDate } = window.TokenAdmin

  const STORAGE_KEY = 'token-admin.protect-codes.settings.v2'
  const state = {
    protectCodes: [],
    settings: loadSettings(),
  }

  const els = {
    logoutButton: document.getElementById('logoutButton'),
    generateBtn: document.getElementById('generateBtn'),
    generatePurpose: document.getElementById('generatePurpose'),
    generateCount: document.getElementById('generateCount'),
    generateMaxUses: document.getElementById('generateMaxUses'),
    copyAfterGenerate: document.getElementById('copyAfterGenerate'),
    availabilitySort: document.getElementById('availabilitySort'),
    hideUnavailable: document.getElementById('hideUnavailable'),
    codeSearch: document.getElementById('codeSearch'),
    refreshBtn: document.getElementById('refreshBtn'),
    ipaCodeGrid: document.getElementById('ipaCodeGrid'),
    tfCodeGrid: document.getElementById('tfCodeGrid'),
    ipaSummary: document.getElementById('ipaSummary'),
    tfSummary: document.getElementById('tfSummary'),
  }

  if (els.logoutButton) els.logoutButton.addEventListener('click', window.TokenAdmin.logout)

  function loadSettings() {
    try {
      return {
        sort: 'available-first',
        hideUnavailable: false,
        generatePurpose: 'tf',
        generateCount: 10,
        generateMaxUses: 3,
        copyAfterGenerate: false,
        ...JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}'),
      }
    } catch (_) {
      return {
        sort: 'available-first',
        hideUnavailable: false,
        generatePurpose: 'tf',
        generateCount: 10,
        generateMaxUses: 3,
        copyAfterGenerate: false,
      }
    }
  }

  function saveSettings() {
    state.settings = {
      ...state.settings,
      sort: els.availabilitySort?.value || 'available-first',
      hideUnavailable: Boolean(els.hideUnavailable?.checked),
      generatePurpose: els.generatePurpose?.value === 'tf' ? 'tf' : 'ipa',
      generateCount: Number.parseInt(els.generateCount?.value, 10) || 10,
      generateMaxUses: Number.parseInt(els.generateMaxUses?.value, 10) || 3,
      copyAfterGenerate: Boolean(els.copyAfterGenerate?.checked),
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state.settings))
  }

  function restoreSettings() {
    if (els.availabilitySort) els.availabilitySort.value = state.settings.sort
    if (els.hideUnavailable) els.hideUnavailable.checked = state.settings.hideUnavailable
    if (els.generatePurpose) els.generatePurpose.value = state.settings.generatePurpose
    if (els.generateCount) els.generateCount.value = state.settings.generateCount
    if (els.generateMaxUses) els.generateMaxUses.value = state.settings.generateMaxUses
    if (els.copyAfterGenerate) els.copyAfterGenerate.checked = state.settings.copyAfterGenerate
    updatePresetState('count', state.settings.generateCount)
    updatePresetState('uses', state.settings.generateMaxUses)
  }

  function escapeAttr(value) {
    return esc(String(value || '')).replace(/"/g, '&quot;')
  }

  function purposeOf(code) {
    return code.purpose === 'ipa' ? 'ipa' : 'tf'
  }

  function isUnavailable(code) {
    return Number(code.currentUses) >= Number(code.maxUses)
  }

  function createdTime(code) {
    const value = new Date(code.createdAt || 0).getTime()
    return Number.isFinite(value) ? value : 0
  }

  function sortCodes(codes) {
    const sort = state.settings.sort
    return [...codes].sort((a, b) => {
      if (sort === 'available-first' || sort === 'unavailable-first') {
        const statusDelta = Number(isUnavailable(a)) - Number(isUnavailable(b))
        if (statusDelta !== 0) return sort === 'available-first' ? statusDelta : -statusDelta
        return createdTime(b) - createdTime(a)
      }
      const dateDelta = createdTime(a) - createdTime(b)
      if (dateDelta !== 0) return sort === 'oldest' ? dateDelta : -dateDelta
      return String(a.code).localeCompare(String(b.code))
    })
  }

  function codesFor(purpose) {
    const query = String(els.codeSearch?.value || '').trim().toLowerCase()
    const filtered = state.protectCodes.filter(code => {
      if (purposeOf(code) !== purpose) return false
      if (state.settings.hideUnavailable && isUnavailable(code)) return false
      return !query || String(code.code).toLowerCase().includes(query)
    })
    return sortCodes(filtered)
  }

  function renderCode(code) {
    const unavailable = isUnavailable(code)
    const remaining = Math.max(0, Number(code.maxUses) - Number(code.currentUses))
    return `
      <article class="token-row protect-code-row ${unavailable ? 'is-unavailable' : ''}">
        <div class="token-row-main">
          <div class="feature-copy">
            <div class="protect-code-head">
              <h3 class="token-name protect-code-value">${esc(code.code)}</h3>
              <span class="status-pill ${unavailable ? 'soft' : 'good'}">
                ${unavailable ? '不可用' : `可用 · 剩余 ${remaining}`}
              </span>
            </div>
            <div class="token-meta-line">
              <span>创建于 ${fmtDate(code.createdAt)}</span>
            </div>
          </div>
        </div>
        <div class="metric-ribbon">
          <div class="metric-line">
            <span>使用次数</span>
            <strong>${Number(code.currentUses) || 0} / ${Number(code.maxUses) || 0}</strong>
          </div>
        </div>
        <div class="token-row-aside">
          <button class="btn btn-ghost btn-small" type="button" data-action="copyCode" data-code="${escapeAttr(code.code)}">复制</button>
          <button class="btn btn-ghost btn-small" type="button" data-action="addUse" data-code="${escapeAttr(code.code)}">增加次数</button>
          <button class="btn btn-ghost btn-small" type="button" data-action="delete" data-code="${escapeAttr(code.code)}">删除</button>
        </div>
      </article>
    `
  }

  function renderPurpose(purpose) {
    const all = state.protectCodes.filter(code => purposeOf(code) === purpose)
    const available = all.filter(code => !isUnavailable(code)).length
    const unavailable = all.length - available
    const visible = codesFor(purpose)
    const grid = purpose === 'ipa' ? els.ipaCodeGrid : els.tfCodeGrid
    const summary = purpose === 'ipa' ? els.ipaSummary : els.tfSummary

    if (summary) {
      summary.textContent = `可用 ${available} · 不可用 ${unavailable} · 共 ${all.length}`
    }
    if (grid) {
      grid.innerHTML = visible.length
        ? visible.map(renderCode).join('')
        : `<div class="empty">${state.settings.hideUnavailable && all.length ? '没有可用保护码' : '暂无保护码'}</div>`
    }

    document.querySelectorAll(`[data-purpose="${purpose}"]`).forEach(button => {
      button.disabled = available === 0
    })
  }

  function renderCodes() {
    renderPurpose('ipa')
    renderPurpose('tf')
  }

  async function loadCodes() {
    if (els.generateBtn) els.generateBtn.disabled = true
    if (els.refreshBtn) els.refreshBtn.disabled = true
    try {
      const res = await request('/api/protect-codes')
      state.protectCodes = res.protectCodes || []
      renderCodes()
    } catch (error) {
      notify('加载失败: ' + error.message, 'error')
    } finally {
      if (els.generateBtn) els.generateBtn.disabled = false
      if (els.refreshBtn) els.refreshBtn.disabled = false
    }
  }

  async function copyText(value) {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(value)
      return
    }
    const textarea = document.createElement('textarea')
    textarea.value = value
    textarea.style.position = 'fixed'
    textarea.style.opacity = '0'
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand('copy')
    textarea.remove()
  }

  function availableCodesFor(purpose) {
    return sortCodes(state.protectCodes.filter(code => purposeOf(code) === purpose && !isUnavailable(code)))
  }

  async function copyPurpose(purpose) {
    const codes = availableCodesFor(purpose)
    await copyText(codes.map(code => code.code).join('\n'))
    notify(`已复制 ${codes.length} 个${purpose === 'ipa' ? 'IPA 自签' : 'TestFlight'}保护码`, 'success')
  }

  function exportPurpose(purpose) {
    const codes = availableCodesFor(purpose)
    const blob = new Blob([codes.map(code => code.code).join('\n')], { type: 'text/plain' })
    const url = URL.createObjectURL(blob)
    const anchor = document.createElement('a')
    anchor.href = url
    anchor.download = `protect-codes-${purpose}-${new Date().toISOString().replace(/[:.]/g, '-')}.txt`
    document.body.appendChild(anchor)
    anchor.click()
    anchor.remove()
    URL.revokeObjectURL(url)
    notify(`已导出 ${codes.length} 个可用保护码`, 'success')
  }

  async function generateCodes() {
    const count = Number.parseInt(els.generateCount?.value, 10)
    const maxUses = Number.parseInt(els.generateMaxUses?.value, 10)
    const purpose = els.generatePurpose?.value === 'tf' ? 'tf' : 'ipa'
    const purposeLabel = purpose === 'ipa' ? 'IPA 自签' : 'TestFlight'

    if (!Number.isInteger(count) || count < 1 || count > 1000) {
      return notify('生成数量需为 1–1000', 'error')
    }
    if (!Number.isInteger(maxUses) || maxUses < 1 || maxUses > 100000) {
      return notify('单码可用次数需为 1–100000', 'error')
    }
    if (!confirm(`生成 ${count} 个${purposeLabel}保护码，每个可用 ${maxUses} 次？`)) return

    saveSettings()
    const existingCodes = new Set(state.protectCodes.map(code => code.code))
    try {
      els.generateBtn.disabled = true
      const res = await request('/api/protect-codes/generate', {
        method: 'POST',
        body: JSON.stringify({ count, maxUses, purpose }),
      })
      state.protectCodes = res.protectCodes || []
      const generated = state.protectCodes.filter(code => !existingCodes.has(code.code) && purposeOf(code) === purpose)
      if (els.copyAfterGenerate?.checked && generated.length) {
        await copyText(generated.map(code => code.code).join('\n'))
      }
      renderCodes()
      notify(`已生成 ${res.generated} 个${purposeLabel}保护码`, 'success')
    } catch (error) {
      notify('生成失败: ' + error.message, 'error')
    } finally {
      els.generateBtn.disabled = false
    }
  }

  async function deleteCode(code) {
    if (!confirm('删除保护码 ' + code + '？')) return
    try {
      await request('/api/protect-codes/' + encodeURIComponent(code), { method: 'DELETE' })
      state.protectCodes = state.protectCodes.filter(item => item.code !== code)
      renderCodes()
      notify('已删除保护码', 'success')
    } catch (error) {
      notify('删除失败: ' + error.message, 'error')
    }
  }

  async function addUses(code) {
    const rawAmount = prompt('增加可用次数', '1')
    if (!rawAmount) return
    const addUses = Number.parseInt(rawAmount, 10)
    if (!Number.isInteger(addUses) || addUses < 1) return notify('次数无效', 'error')

    try {
      const res = await request('/api/protect-codes/' + encodeURIComponent(code), {
        method: 'PUT',
        body: JSON.stringify({ addUses }),
      })
      const index = state.protectCodes.findIndex(item => item.code === code)
      if (index >= 0 && res.item) state.protectCodes[index] = res.item
      renderCodes()
      notify(`已增加 ${addUses} 次`, 'success')
    } catch (error) {
      notify('修改失败: ' + error.message, 'error')
    }
  }

  function updatePresetState(type, value) {
    document.querySelectorAll(`[data-${type}-preset]`).forEach(button => {
      button.classList.toggle('active', Number(button.dataset[`${type}Preset`]) === Number(value))
    })
  }

  document.querySelectorAll('[data-count-preset]').forEach(button => {
    button.addEventListener('click', () => {
      els.generateCount.value = button.dataset.countPreset
      updatePresetState('count', button.dataset.countPreset)
      saveSettings()
    })
  })

  document.querySelectorAll('[data-uses-preset]').forEach(button => {
    button.addEventListener('click', () => {
      els.generateMaxUses.value = button.dataset.usesPreset
      updatePresetState('uses', button.dataset.usesPreset)
      saveSettings()
    })
  })

  document.addEventListener('click', async event => {
    const button = event.target.closest('button[data-action]')
    if (!button) return
    const { action, code, purpose } = button.dataset
    if (action === 'copyCode') {
      await copyText(code)
      notify('已复制保护码', 'success')
    } else if (action === 'addUse') {
      await addUses(code)
    } else if (action === 'delete') {
      await deleteCode(code)
    } else if (action === 'copyPurpose') {
      await copyPurpose(purpose)
    } else if (action === 'exportPurpose') {
      exportPurpose(purpose)
    }
  })

  if (els.generateBtn) els.generateBtn.addEventListener('click', generateCodes)
  if (els.refreshBtn) els.refreshBtn.addEventListener('click', loadCodes)
  if (els.codeSearch) els.codeSearch.addEventListener('input', renderCodes)

  ;[els.availabilitySort, els.hideUnavailable].forEach(element => {
    if (!element) return
    element.addEventListener('change', () => {
      saveSettings()
      renderCodes()
    })
  })

  ;[els.generatePurpose, els.copyAfterGenerate].forEach(element => {
    if (!element) return
    element.addEventListener('change', saveSettings)
  })

  if (els.generateCount) {
    els.generateCount.addEventListener('input', () => {
      updatePresetState('count', els.generateCount.value)
      saveSettings()
    })
  }
  if (els.generateMaxUses) {
    els.generateMaxUses.addEventListener('input', () => {
      updatePresetState('uses', els.generateMaxUses.value)
      saveSettings()
    })
  }

  restoreSettings()
  setupAuth(loadCodes)
})()
