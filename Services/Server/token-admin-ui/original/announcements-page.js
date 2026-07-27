(function () {
  const { setupAuth, request, notify, logout, esc, fmtDate, fmtNum } = window.TokenAdmin

  const categoryLabels = {
    general: '通知', activity: '活动', maintenance: '维护',
    important: '重要提醒', policy: '协议政策', update: '版本更新'
  }
  const priorityLabels = { normal: '普通', high: '高', critical: '紧急' }
  const statusLabels = { draft: '草稿', published: '已发布', offline: '已下线' }

  const els = {
    logoutButton: document.getElementById('logoutButton'),
    refreshButton: document.getElementById('refreshButton'),
    summary: document.getElementById('announcementSummary'),
    list: document.getElementById('announcementList'),
    statusFilter: document.getElementById('statusFilter'),
    categoryFilter: document.getElementById('categoryFilter'),
    empty: document.getElementById('editorEmpty'),
    form: document.getElementById('announcementForm'),
    fields: document.getElementById('editorFields'),
    heading: document.getElementById('editorHeading'),
    eyebrow: document.getElementById('editorEyebrow'),
    meta: document.getElementById('editorMeta'),
    status: document.getElementById('editorStatus'),
    publishedHint: document.getElementById('publishedHint'),
    saveButton: document.getElementById('saveButton'),
    publishButton: document.getElementById('publishButton'),
    offlineButton: document.getElementById('offlineButton'),
    deleteButton: document.getElementById('deleteButton')
  }

  let announcements = []
  let releaseTargets = []
  let selectedId = null

  function field(id) { return document.getElementById(id) }
  function selected() { return announcements.find(item => item.id === selectedId) || null }
  function splitList(value) { return [...new Set(String(value || '').split(/[,，\n]/).map(item => item.trim().toLowerCase()).filter(Boolean))] }
  function toISO(value) { return value ? new Date(value).toISOString() : null }
  function toLocalDateTime(value) {
    if (!value) return ''
    const date = new Date(value)
    if (Number.isNaN(date.getTime())) return ''
    const shifted = new Date(date.getTime() - date.getTimezoneOffset() * 60_000)
    return shifted.toISOString().slice(0, 16)
  }

  function input() {
    const minimumTarget = selectedReleaseTarget('announcementMinVersion')
    const maximumTarget = selectedReleaseTarget('announcementMaxVersion')
    return {
      title: field('announcementTitle').value.trim(),
      category: field('announcementCategory').value,
      priority: field('announcementPriority').value,
      summary: field('announcementSummaryInput').value.trim() || null,
      body: field('announcementBody').value.trim(),
      imageURL: field('announcementImageURL').value.trim() || null,
      actionTitle: field('announcementActionTitle').value.trim() || null,
      actionURL: field('announcementActionURL').value.trim() || null,
      minAppVersion: minimumTarget?.appVersion || null,
      maxAppVersion: maximumTarget?.appVersion || null,
      minAppBuild: minimumTarget?.appBuild || null,
      maxAppBuild: maximumTarget?.appBuild || null,
      platforms: splitList(field('announcementPlatforms').value),
      locales: splitList(field('announcementLocales').value),
      startsAt: toISO(field('announcementStartsAt').value),
      endsAt: toISO(field('announcementEndsAt').value),
      requiresAcknowledgement: field('announcementRequiresAcknowledgement').checked
    }
  }

  function validate(payload) {
    if (!payload.title) throw new Error('请输入公告标题')
    if (!payload.body) throw new Error('请输入公告正文')
    if (payload.actionTitle && !payload.actionURL) throw new Error('填写按钮文字时必须填写跳转链接')
    if (payload.startsAt && payload.endsAt && new Date(payload.startsAt) >= new Date(payload.endsAt)) {
      throw new Error('结束时间必须晚于开始时间')
    }
    if (compareReleaseTargets(
      payload.minAppVersion,
      payload.minAppBuild,
      payload.maxAppVersion,
      payload.maxAppBuild
    ) > 0) {
      throw new Error('最低发布版本不能高于最高发布版本')
    }
  }

  function selectedReleaseTarget(id) {
    const select = field(id)
    const option = select?.selectedOptions?.[0]
    if (!option?.value) return null
    return {
      appVersion: option.dataset.appVersion || null,
      appBuild: option.dataset.appBuild || null
    }
  }

  function numericParts(value) {
    return String(value || '').split('.').map(part => Number.parseInt(part, 10) || 0)
  }

  function compareVersions(left, right) {
    const a = numericParts(left)
    const b = numericParts(right)
    const length = Math.max(a.length, b.length)
    for (let index = 0; index < length; index += 1) {
      const difference = (a[index] || 0) - (b[index] || 0)
      if (difference !== 0) return difference < 0 ? -1 : 1
    }
    return 0
  }

  function compareReleaseTargets(leftVersion, leftBuild, rightVersion, rightBuild) {
    if (!leftVersion || !rightVersion) return 0
    const versionComparison = compareVersions(leftVersion, rightVersion)
    if (versionComparison !== 0) return versionComparison
    if (!leftBuild || !rightBuild) return 0
    return Number(leftBuild) - Number(rightBuild)
  }

  function parseReleaseTarget(release) {
    if (!release?.published) return null
    const candidates = [release.version, release.title].filter(Boolean).map(String)
    const version = candidates.map(value => value.match(/\d+(?:\.\d+)+/u)?.[0]).find(Boolean)
    if (!version) return null

    const explicitBuild = String(release.buildNumber || '').trim()
    const parenthesizedBuild = candidates
      .map(value => value.match(/[（(]\s*(\d+)\s*[）)]/u)?.[1])
      .find(Boolean)
    const appBuild = /^\d+$/u.test(explicitBuild) ? explicitBuild : (parenthesizedBuild || null)
    return {
      key: `${version}:${appBuild || ''}`,
      appVersion: version,
      appBuild,
      label: appBuild ? `${version}（${appBuild}）` : version
    }
  }

  function collectReleaseTargets(status) {
    const targets = []
    const seen = new Set()
    for (const release of status?.ipaReleases || []) {
      const target = parseReleaseTarget(release)
      if (!target || seen.has(target.key)) continue
      seen.add(target.key)
      targets.push(target)
    }
    return targets.sort((left, right) => -compareReleaseTargets(
      left.appVersion,
      left.appBuild,
      right.appVersion,
      right.appBuild
    ))
  }

  function targetKey(appVersion, appBuild) {
    return appVersion ? `${appVersion}:${appBuild || ''}` : ''
  }

  function renderReleaseOptions(currentTargets = []) {
    for (const id of ['announcementMinVersion', 'announcementMaxVersion']) {
      const select = field(id)
      if (!select) continue
      const current = currentTargets.find(item => item.id === id)
      const options = [...releaseTargets]
      if (current?.appVersion) {
        const key = targetKey(current.appVersion, current.appBuild)
        if (!options.some(item => item.key === key)) {
          options.push({
            key,
            appVersion: current.appVersion,
            appBuild: current.appBuild || null,
            label: `${current.appVersion}${current.appBuild ? `（${current.appBuild}）` : ''}`
          })
        }
      }
      select.innerHTML = [
        '<option value="">不限</option>',
        ...options.map(item => `<option value="${esc(item.key)}" data-app-version="${esc(item.appVersion)}" data-app-build="${esc(item.appBuild || '')}">${esc(item.label)}</option>`)
      ].join('')
      select.value = current?.appVersion ? targetKey(current.appVersion, current.appBuild) : ''
    }
  }

  function renderSummary() {
    const count = status => announcements.filter(item => item.status === status).length
    const urgent = announcements.filter(item => item.status === 'published' && item.priority === 'critical').length
    els.summary.innerHTML = [
      ['全部', announcements.length], ['草稿', count('draft')], ['已发布', count('published')],
      ['已下线', count('offline')], ['紧急公告', urgent]
    ].map(([label, value]) => `<article class="summary-tile"><span>${label}</span><strong>${fmtNum(value)}</strong></article>`).join('')
  }

  function filteredAnnouncements() {
    return announcements.filter(item => {
      if (els.statusFilter.value && item.status !== els.statusFilter.value) return false
      if (els.categoryFilter.value && item.category !== els.categoryFilter.value) return false
      return true
    })
  }

  function renderList() {
    const items = filteredAnnouncements()
    els.list.innerHTML = items.length ? items.map(item => `
      <button class="announcement-list-item ${item.id === selectedId ? 'is-active' : ''}" type="button" data-action="select" data-id="${item.id}">
        <span class="announcement-list-title-row">
          <span class="announcement-list-title">${esc(item.title)}</span>
          <span class="announcement-priority" data-priority="${item.priority}">${priorityLabels[item.priority] || '普通'}</span>
        </span>
        <span class="announcement-list-meta">
          <span class="announcement-status-${item.status}">${statusLabels[item.status] || item.status}</span>
          <span>${categoryLabels[item.category] || '通知'}</span>
          <span>第 ${fmtNum(item.displayRevision)} 次展示</span>
          <span>${fmtDate(item.publishedAt || item.updatedAt)}</span>
        </span>
        ${item.summary ? `<span class="announcement-list-summary">${esc(item.summary)}</span>` : ''}
      </button>
    `).join('') : '<div class="empty">没有符合条件的公告</div>'
  }

  function setValue(id, value) { field(id).value = value ?? '' }

  function fillEditor(item) {
    const isNew = !item
    const isPublished = item?.status === 'published'
    els.empty.classList.add('hidden')
    els.form.classList.remove('hidden')
    els.fields.disabled = isPublished
    els.heading.textContent = isNew ? '新建公告' : item.title
    els.eyebrow.textContent = isNew ? 'New Announcement' : `Display Revision ${item.displayRevision}`
    els.meta.textContent = isNew ? '先保存草稿，再发布到客户端。' : `更新于 ${fmtDate(item.updatedAt)}`
    els.status.textContent = isNew ? '草稿' : (statusLabels[item.status] || item.status)
    els.status.className = `status-pill ${isPublished ? 'good' : item?.status === 'offline' ? 'warn' : 'soft'}`

    setValue('announcementTitle', item?.title)
    setValue('announcementCategory', item?.category || 'general')
    setValue('announcementPriority', item?.priority || 'normal')
    setValue('announcementSummaryInput', item?.summary)
    setValue('announcementBody', item?.body)
    setValue('announcementImageURL', item?.imageURL)
    setValue('announcementActionTitle', item?.actionTitle)
    setValue('announcementActionURL', item?.actionURL)
    renderReleaseOptions([
      { id: 'announcementMinVersion', appVersion: item?.minAppVersion, appBuild: item?.minAppBuild },
      { id: 'announcementMaxVersion', appVersion: item?.maxAppVersion, appBuild: item?.maxAppBuild }
    ])
    setValue('announcementPlatforms', (item?.platforms || ['ios']).join(', '))
    setValue('announcementLocales', (item?.locales || []).join(', '))
    setValue('announcementStartsAt', toLocalDateTime(item?.startsAt))
    setValue('announcementEndsAt', toLocalDateTime(item?.endsAt))
    field('announcementRequiresAcknowledgement').checked = Boolean(item?.requiresAcknowledgement)

    els.publishedHint.classList.toggle('hidden', !isPublished)
    els.saveButton.classList.toggle('hidden', isPublished)
    els.offlineButton.classList.toggle('hidden', !isPublished)
    els.deleteButton.classList.toggle('hidden', isNew || isPublished)
    els.publishButton.textContent = isPublished ? '再次发布' : '发布'
  }

  function selectAnnouncement(id) {
    selectedId = id
    renderList()
    fillEditor(selected())
  }

  function newAnnouncement() {
    selectedId = null
    renderList()
    fillEditor(null)
    field('announcementTitle').focus()
  }

  async function loadPage({ preserveSelection = true } = {}) {
    const previous = preserveSelection ? selectedId : null
    const [payload, status] = await Promise.all([
      request('/api/announcements'),
      request('/api/status').catch(() => ({ ipaReleases: [] }))
    ])
    announcements = payload.announcements || []
    releaseTargets = collectReleaseTargets(status)
    selectedId = previous && announcements.some(item => item.id === previous) ? previous : null
    renderSummary()
    renderList()
    if (selectedId) fillEditor(selected())
    else renderReleaseOptions()
  }

  async function saveDraft() {
    const payload = input()
    validate(payload)
    let response
    if (selectedId) {
      response = await request(`/api/announcements/${selectedId}`, { method: 'PUT', body: JSON.stringify(payload) })
    } else {
      response = await request('/api/announcements', { method: 'POST', body: JSON.stringify(payload) })
      selectedId = response.announcement.id
    }
    notify('草稿已保存', 'success')
    await loadPage()
    return response.announcement
  }

  async function publishAnnouncement() {
    const item = selected()
    if (!item || item.status !== 'published') await saveDraft()
    const message = item?.status === 'published'
      ? '再次发布后，客户端会把它作为新一轮公告展示。确定继续？'
      : '确定发布这条公告？'
    if (!confirm(message)) return
    const response = await request(`/api/announcements/${selectedId}/publish`, { method: 'POST' })
    notify(`已发布第 ${response.announcement.displayRevision} 次展示`, 'success')
    await loadPage()
  }

  async function takeOffline() {
    if (!selectedId || !confirm('确定下线这条公告？')) return
    await request(`/api/announcements/${selectedId}/offline`, { method: 'POST' })
    notify('公告已下线', 'success')
    await loadPage()
  }

  async function removeAnnouncement() {
    if (!selectedId || !confirm('确定删除这条公告？此操作不可撤销。')) return
    await request(`/api/announcements/${selectedId}`, { method: 'DELETE' })
    selectedId = null
    notify('公告已删除', 'success')
    await loadPage({ preserveSelection: false })
    els.form.classList.add('hidden')
    els.empty.classList.remove('hidden')
  }

  async function busy(button, task) {
    try {
      if (button) button.disabled = true
      await task()
    } catch (error) {
      notify(error.message || '操作失败', 'error')
    } finally {
      if (button) button.disabled = false
    }
  }

  els.logoutButton?.addEventListener('click', logout)
  els.refreshButton?.addEventListener('click', () => busy(els.refreshButton, () => loadPage()))
  els.statusFilter?.addEventListener('change', renderList)
  els.categoryFilter?.addEventListener('change', renderList)
  els.form?.addEventListener('submit', event => {
    event.preventDefault()
    busy(els.saveButton, saveDraft)
  })

  document.addEventListener('click', event => {
    const target = event.target.closest('[data-action]')
    if (!target) return
    const action = target.dataset.action
    if (action === 'new') newAnnouncement()
    if (action === 'select') selectAnnouncement(target.dataset.id)
    if (action === 'publish') busy(els.publishButton, publishAnnouncement)
    if (action === 'offline') busy(els.offlineButton, takeOffline)
    if (action === 'delete') busy(els.deleteButton, removeAnnouncement)
  })

  setupAuth(loadPage)
})()
