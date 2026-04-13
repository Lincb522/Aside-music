(function () {
  const { request, esc, fmtDate, fmtBytes, fmtNum, nl2br } = window.TokenAdmin

  const els = {
    latestRelease: document.getElementById('latestRelease'),
    releaseArchive: document.getElementById('releaseArchive')
  }

  function releaseCard(release, featured = false) {
    return `
      <article class="${featured ? 'download-feature-card' : 'download-card'}">
        <div class="release-head">
          <div>
            <h3 class="public-card-title">${esc(release.title || release.version || '未命名版本')}</h3>
            <div class="public-meta">
              <span>Version ${esc(release.version || '—')}</span>
              <span>Build ${esc(release.build || '—')}</span>
              <span>${fmtDate(release.publishedAt || release.updatedAt)}</span>
            </div>
          </div>
          <span class="status-pill good">${featured ? '最新' : '已发布'}</span>
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
            <span>文件大小</span>
            <strong>${fmtBytes(release.fileSize || 0)}</strong>
          </div>
          <div class="metric-line">
            <span>下载</span>
            <strong>${fmtNum(release.downloadCount || 0)}</strong>
          </div>
        </div>
        <div class="report-box">${release.releaseNotes ? nl2br(release.releaseNotes) : '暂无更新报告'}</div>
        <div class="section-actions">
          <a class="btn btn-primary" href="./downloads/file/${release.id}">下载 IPA</a>
        </div>
      </article>
    `
  }

  async function loadPage() {
    const data = await request('/api/public/ipa-releases', { auth: false })
    const latest = data.latest
    const releases = data.releases || []
    const archive = latest ? releases.filter(item => item.id !== latest.id) : releases

    els.latestRelease.innerHTML = latest
      ? releaseCard(latest, true)
      : '<div class="empty">暂无可下载版本</div>'

    els.releaseArchive.innerHTML = archive.length
      ? archive.map(release => releaseCard(release)).join('')
      : '<div class="empty">暂无历史版本</div>'
  }

  loadPage().catch(() => {
    els.latestRelease.innerHTML = '<div class="empty">加载失败</div>'
    els.releaseArchive.innerHTML = ''
  })
})()
