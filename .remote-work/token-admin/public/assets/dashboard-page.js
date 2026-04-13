(function () {
  const { setupAuth, request, fmtDate, fmtNum, fmtBytes, esc, nl2br, logout } = window.TokenAdmin

  const els = {
    logoutButton: document.getElementById('logoutButton'),
    latestReleaseVersion: document.getElementById('latestReleaseVersion'),
    cloudSyncCount: document.getElementById('cloudSyncCount'),
    heroDownloads: document.getElementById('heroDownloads'),
    statActive: document.getElementById('statActive'),
    statRequests: document.getElementById('statRequests'),
    statDownloads: document.getElementById('statDownloads'),
    statReleases: document.getElementById('statReleases'),
    statPublished: document.getElementById('statPublished'),
    statusList: document.getElementById('statusList'),
    tokenOverview: document.getElementById('tokenOverview'),
    releaseOverview: document.getElementById('releaseOverview')
  }

  if (els.logoutButton) els.logoutButton.addEventListener('click', logout)

  function statusPill(kind, label) {
    return `<span class="status-pill ${kind}">${label}</span>`
  }

  function tokenCard(token) {
    const snapshot = token.playlistSnapshot || {}
    const statusKind = token.enabled && !token.isExpired ? 'good' : (token.isExpired ? 'warn' : 'soft')
    const statusText = token.enabled && !token.isExpired ? '在线' : (token.isExpired ? '过期' : '停用')

    return `
      <article class="feature-card">
        <div class="feature-card-head">
          <div class="feature-copy">
            <h3 class="feature-card-title">${esc(token.name || '未命名 Token')}</h3>
            <div class="token-meta-line">
              <span>${token.expiresAt ? fmtDate(token.expiresAt) : '永久'}</span>
              <span>${fmtNum(token.deviceCount || 0)} 台设备</span>
            </div>
          </div>
          ${statusPill(statusKind, statusText)}
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
            <span>本地歌单</span>
            <strong>${fmtNum(snapshot.playlistCount || 0)}</strong>
          </div>
        </div>
        <div class="notes-box">${snapshot.hasSnapshot ? `最后同步 ${fmtDate(snapshot.updatedAt)}<br>${fmtNum(snapshot.songCount || 0)} 首歌曲` : '未同步本地歌单'}</div>
      </article>
    `
  }

  function releaseCard(release) {
    return `
      <article class="feature-card">
        <div class="feature-card-head">
          <div class="feature-copy">
            <h3 class="feature-card-title">${esc(release.title || release.version || '未命名版本')}</h3>
            <div class="release-meta">
              <span>Version ${esc(release.version || '—')}</span>
              <span>Build ${esc(release.build || '—')}</span>
              <span>${fmtDate(release.publishedAt || release.updatedAt)}</span>
            </div>
          </div>
          ${statusPill(release.published ? 'good' : 'soft', release.published ? '已发布' : '草稿')}
        </div>
        <div class="metric-ribbon">
          <div class="metric-line">
            <span>渠道</span>
            <strong>${esc(release.channel || 'stable')}</strong>
          </div>
          <div class="metric-line">
            <span>文件</span>
            <strong>${fmtBytes(release.fileSize || 0)}</strong>
          </div>
          <div class="metric-line">
            <span>下载</span>
            <strong>${fmtNum(release.downloadCount || 0)}</strong>
          </div>
        </div>
        <div class="notes-box">${release.releaseNotes ? nl2br(release.releaseNotes) : '暂无更新报告'}</div>
      </article>
    `
  }

  async function loadDashboard() {
    const status = await request('/api/status')
    const tokens = [...(status.tokens || [])].slice(0, 5)
    const releases = [...(status.ipaReleases || [])].slice(0, 4)
    const latest = status.latestPublishedRelease
    const cloudCount = (status.tokens || []).filter(token => token.playlistSnapshot?.hasSnapshot).length

    els.latestReleaseVersion.textContent = latest ? latest.version : '—'
    els.cloudSyncCount.textContent = fmtNum(cloudCount)
    els.heroDownloads.textContent = fmtNum(status.totalDownloads || 0)
    els.statActive.textContent = `${fmtNum(status.activeCount || 0)} / ${fmtNum(status.totalCount || 0)}`
    els.statRequests.textContent = fmtNum(status.totalRequests || 0)
    els.statDownloads.textContent = fmtNum(status.totalDownloads || 0)
    els.statReleases.textContent = fmtNum(status.ipaReleaseCount || 0)
    els.statPublished.textContent = fmtNum(status.publishedIpaReleaseCount || 0)

    els.statusList.innerHTML = `
      <div class="status-row">
        <div>
          <strong>Token 验证</strong>
          <div class="muted">${status.globalEnabled ? '当前要求验证' : '当前放行'}</div>
        </div>
        ${statusPill(status.globalEnabled ? 'good' : 'soft', status.globalEnabled ? '开启' : '关闭')}
      </div>
      <div class="status-row">
        <div>
          <strong>默认限速</strong>
          <div class="muted">${fmtNum(status.defaultRateLimit || 0)} / 分钟</div>
        </div>
        ${statusPill(status.rateLimitEnabled !== false ? 'good' : 'soft', status.rateLimitEnabled !== false ? '生效' : '关闭')}
      </div>
      <div class="status-row">
        <div>
          <strong>默认下载</strong>
          <div class="muted">${fmtNum(status.defaultDownloadLimit || 0)} / 天</div>
        </div>
        ${statusPill(status.downloadLimitEnabled ? 'good' : 'soft', status.downloadLimitEnabled ? '生效' : '关闭')}
      </div>
      <div class="status-row">
        <div>
          <strong>设备限制</strong>
          <div class="muted">${fmtNum(status.maxDevicesPerToken || 0)} 台</div>
        </div>
        ${statusPill(status.deviceBindEnabled ? 'good' : 'soft', status.deviceBindEnabled ? '生效' : '关闭')}
      </div>
    `

    els.tokenOverview.innerHTML = tokens.length
      ? tokens.map(tokenCard).join('')
      : '<div class="empty">暂无 Token</div>'

    els.releaseOverview.innerHTML = releases.length
      ? releases.map(releaseCard).join('')
      : '<div class="empty">暂无版本</div>'
  }

  setupAuth(loadDashboard)
})()
