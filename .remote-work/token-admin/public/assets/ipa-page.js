(function () {
  const { setupAuth, request, notify, esc, fmtDate, fmtBytes, fmtNum, nl2br, logout } = window.TokenAdmin

  const els = {
    logoutButton: document.getElementById('logoutButton'),
    releaseList: document.getElementById('releaseList'),
    composerPanel: document.getElementById('composerPanel'),
    statsPanel: document.getElementById('statsPanel')
  }

  let releases = []

  if (els.logoutButton) els.logoutButton.addEventListener('click', logout)

  function collectComposerInput() {
    return {
      title: document.getElementById('releaseTitle')?.value.trim(),
      version: document.getElementById('releaseVersion')?.value.trim(),
      build: document.getElementById('releaseBuild')?.value.trim(),
      channel: document.getElementById('releaseChannel')?.value,
      minIosVersion: document.getElementById('releaseMinIos')?.value.trim(),
      releaseNotes: document.getElementById('releaseNotes')?.value || '',
      published: document.getElementById('releasePublished')?.value === 'true'
    }
  }

  async function uploadReleaseFile(releaseId, file) {
    if (!file) return
    await request(`/api/ipa-releases/${releaseId}/file`, {
      method: 'POST',
      headers: {
        'X-File-Name': file.name
      },
      body: file
    })
  }

  function renderComposer() {
    els.composerPanel.innerHTML = `
      <div class="panel-head">
        <div>
          <small class="eyebrow">Compose</small>
          <h3>创建新版本</h3>
          <p>上传 IPA，填写版本信息和更新报告。</p>
        </div>
      </div>
      <div class="field-grid">
        <div class="field">
          <label for="releaseTitle">标题</label>
          <input id="releaseTitle" placeholder="Monologue 2.3.0">
        </div>
        <div class="field">
          <label for="releaseVersion">Version</label>
          <input id="releaseVersion" placeholder="2.3.0">
        </div>
        <div class="field">
          <label for="releaseBuild">Build</label>
          <input id="releaseBuild" placeholder="23001">
        </div>
        <div class="field">
          <label for="releaseChannel">渠道</label>
          <select id="releaseChannel">
            <option value="stable">stable</option>
            <option value="beta">beta</option>
            <option value="internal">internal</option>
          </select>
        </div>
        <div class="field">
          <label for="releaseMinIos">最低 iOS</label>
          <input id="releaseMinIos" placeholder="16.0">
        </div>
        <div class="field">
          <label for="releasePublished">状态</label>
          <select id="releasePublished">
            <option value="false">草稿</option>
            <option value="true">发布</option>
          </select>
        </div>
      </div>
      <div class="field" style="margin-top:18px">
        <label for="releaseNotes">更新报告</label>
        <textarea id="releaseNotes" placeholder="每行一条更新"></textarea>
      </div>
      <div class="file-row" style="margin-top:18px">
        <input id="newReleaseFile" class="file-input" type="file" accept=".ipa">
        <button class="btn btn-secondary" type="button" data-action="choose-file">选择 IPA</button>
        <span id="newReleaseFileLabel" class="file-pill">未选择文件</span>
        <button class="btn btn-primary" type="button" data-action="create-release">创建版本</button>
      </div>
    `

    const fileInput = document.getElementById('newReleaseFile')
    const fileLabel = document.getElementById('newReleaseFileLabel')
    if (fileInput && fileLabel) {
      fileInput.addEventListener('change', event => {
        const file = event.target.files?.[0]
        fileLabel.textContent = file ? `${file.name} · ${fmtBytes(file.size)}` : '未选择文件'
      })
    }
  }

  function renderStats() {
    const published = releases.filter(item => item.published).length
    const withFiles = releases.filter(item => item.hasFile).length
    const latest = releases[0]

    els.statsPanel.innerHTML = `
      <div class="panel-head">
        <div>
          <small class="eyebrow">Overview</small>
          <h3>版本概览</h3>
          <p>只看当前版本状态。</p>
        </div>
      </div>
      <div class="overview-ribbon">
        <article class="overview-card">
          <span>版本数</span>
          <strong>${fmtNum(releases.length)}</strong>
        </article>
        <article class="overview-card">
          <span>已发布</span>
          <strong>${fmtNum(published)}</strong>
        </article>
        <article class="overview-card">
          <span>已上传文件</span>
          <strong>${fmtNum(withFiles)}</strong>
        </article>
        <article class="overview-card">
          <span>最新版本</span>
          <strong>${esc(latest?.version || '—')}</strong>
        </article>
      </div>
      <div class="notes-box" style="margin-top:18px">
        ${latest ? `${esc(latest.title || latest.version)} · 更新于 ${fmtDate(latest.updatedAt)}` : '还没有版本'}
      </div>
    `
  }

  function releaseCard(release) {
    return `
      <article class="release-editor">
        <div class="release-head">
          <div>
            <h3>${esc(release.title || release.version || '未命名版本')}</h3>
            <div class="release-meta">
              <span>Version ${esc(release.version || '—')}</span>
              <span>Build ${esc(release.build || '—')}</span>
              <span>${fmtDate(release.updatedAt)}</span>
            </div>
          </div>
          <span class="status-pill ${release.published ? 'good' : 'soft'}">${release.published ? '已发布' : '草稿'}</span>
        </div>
        <div class="metric-ribbon">
          <div class="metric-line">
            <span>渠道</span>
            <strong>${esc(release.channel || 'stable')}</strong>
          </div>
          <div class="metric-line">
            <span>最低 iOS</span>
            <strong>${esc(release.minIosVersion || '—')}</strong>
          </div>
          <div class="metric-line">
            <span>文件</span>
            <strong>${release.hasFile ? fmtBytes(release.fileSize || 0) : '未上传'}</strong>
          </div>
          <div class="metric-line">
            <span>下载</span>
            <strong>${fmtNum(release.downloadCount || 0)}</strong>
          </div>
        </div>
        <div class="field-grid">
          <div class="field">
            <label for="${release.id}-title">标题</label>
            <input id="${release.id}-title" value="${esc(release.title || '')}">
          </div>
          <div class="field">
            <label for="${release.id}-version">Version</label>
            <input id="${release.id}-version" value="${esc(release.version || '')}">
          </div>
          <div class="field">
            <label for="${release.id}-build">Build</label>
            <input id="${release.id}-build" value="${esc(release.build || '')}">
          </div>
          <div class="field">
            <label for="${release.id}-channel">渠道</label>
            <select id="${release.id}-channel">
              <option value="stable" ${release.channel === 'stable' ? 'selected' : ''}>stable</option>
              <option value="beta" ${release.channel === 'beta' ? 'selected' : ''}>beta</option>
              <option value="internal" ${release.channel === 'internal' ? 'selected' : ''}>internal</option>
            </select>
          </div>
          <div class="field">
            <label for="${release.id}-minIos">最低 iOS</label>
            <input id="${release.id}-minIos" value="${esc(release.minIosVersion || '')}">
          </div>
          <div class="field">
            <label for="${release.id}-published">状态</label>
            <select id="${release.id}-published">
              <option value="false" ${!release.published ? 'selected' : ''}>草稿</option>
              <option value="true" ${release.published ? 'selected' : ''}>发布</option>
            </select>
          </div>
        </div>
        <div class="field">
          <label for="${release.id}-notes">更新报告</label>
          <textarea id="${release.id}-notes">${esc(release.releaseNotes || '')}</textarea>
        </div>
        <div class="file-row">
          <input id="${release.id}-file" class="file-input" type="file" accept=".ipa">
          <button class="btn btn-secondary btn-small" type="button" data-action="replace-file" data-release-id="${release.id}">替换 IPA</button>
          <span class="file-pill">${release.fileName ? esc(release.fileName) : '未上传文件'}</span>
          <div class="section-actions">
            ${release.published && release.hasFile ? `<a class="btn btn-secondary btn-small" href="./downloads/file/${release.id}" target="_blank" rel="noreferrer">下载</a>` : ''}
            <button class="btn btn-primary btn-small" type="button" data-action="save-release" data-release-id="${release.id}">保存</button>
            <button class="btn btn-danger btn-small" type="button" data-action="delete-release" data-release-id="${release.id}">删除</button>
          </div>
        </div>
        <div class="report-box">${release.releaseNotes ? nl2br(release.releaseNotes) : '暂无更新报告'}</div>
      </article>
    `
  }

  function renderReleaseList() {
    els.releaseList.innerHTML = releases.length
      ? releases.map(releaseCard).join('')
      : '<div class="empty">还没有版本</div>'
  }

  async function loadPage() {
    const status = await request('/api/status')
    releases = [...(status.ipaReleases || [])]
    renderComposer()
    renderStats()
    renderReleaseList()
  }

  async function createRelease() {
    const release = await request('/api/ipa-releases', {
      method: 'POST',
      body: JSON.stringify(collectComposerInput())
    })

    const file = document.getElementById('newReleaseFile')?.files?.[0]
    if (file) await uploadReleaseFile(release.id, file)

    notify('已创建', 'success')
    await loadPage()
  }

  function releaseInput(releaseId) {
    return {
      title: document.getElementById(`${releaseId}-title`)?.value.trim(),
      version: document.getElementById(`${releaseId}-version`)?.value.trim(),
      build: document.getElementById(`${releaseId}-build`)?.value.trim(),
      channel: document.getElementById(`${releaseId}-channel`)?.value,
      minIosVersion: document.getElementById(`${releaseId}-minIos`)?.value.trim(),
      releaseNotes: document.getElementById(`${releaseId}-notes`)?.value || '',
      published: document.getElementById(`${releaseId}-published`)?.value === 'true'
    }
  }

  async function saveRelease(releaseId) {
    await request(`/api/ipa-releases/${releaseId}`, {
      method: 'PUT',
      body: JSON.stringify(releaseInput(releaseId))
    })
    notify('已保存', 'success')
    await loadPage()
  }

  async function replaceFile(releaseId) {
    const input = document.getElementById(`${releaseId}-file`)
    const file = input?.files?.[0]
    if (!file) {
      input?.click()
      return
    }
    await uploadReleaseFile(releaseId, file)
    notify('已上传', 'success')
    await loadPage()
  }

  async function deleteRelease(releaseId) {
    if (!window.confirm('确定删除这个版本？')) return
    await request(`/api/ipa-releases/${releaseId}`, { method: 'DELETE' })
    notify('已删除', 'success')
    await loadPage()
  }

  els.composerPanel.addEventListener('click', async event => {
    const button = event.target.closest('[data-action]')
    if (!button) return

    try {
      if (button.dataset.action === 'choose-file') document.getElementById('newReleaseFile')?.click()
      if (button.dataset.action === 'create-release') await createRelease()
    } catch (error) {
      notify(error.message || '操作失败', 'error')
    }
  })

  els.releaseList.addEventListener('click', async event => {
    const button = event.target.closest('[data-action]')
    if (!button) return

    const releaseId = button.dataset.releaseId
    try {
      if (button.dataset.action === 'replace-file') {
        const input = document.getElementById(`${releaseId}-file`)
        if (input?.files?.[0]) await replaceFile(releaseId)
        else input?.click()
      }
      if (button.dataset.action === 'save-release') await saveRelease(releaseId)
      if (button.dataset.action === 'delete-release') await deleteRelease(releaseId)
    } catch (error) {
      notify(error.message || '操作失败', 'error')
    }
  })

  els.releaseList.addEventListener('change', async event => {
    const input = event.target
    if (!(input instanceof HTMLInputElement)) return
    if (!input.id.endsWith('-file')) return
    const releaseId = input.id.replace(/-file$/, '')
    if (!releaseId || !input.files?.[0]) return

    try {
      await replaceFile(releaseId)
    } catch (error) {
      notify(error.message || '上传失败', 'error')
    }
  })

  setupAuth(loadPage)
})()
