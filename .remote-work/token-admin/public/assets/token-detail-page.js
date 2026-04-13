(function () {
  const { setupAuth, request, notify, esc, fmtDate, fmtNum, logout, href } = window.TokenAdmin
  const brandMarkUrl = href('/brand-mark.png')

  const DURATION_PRESETS = [
    { id: 'permanent', label: '永久', days: 0 },
    { id: 'month', label: '月', days: 30 },
    { id: 'halfyear', label: '半年', days: 183 },
    { id: 'year', label: '年', days: 365 }
  ]

  const state = {
    tokenId: null,
    tokenDetail: null,
    playlistData: null,
    selectedPlaylistId: null
  }

  const els = {
    logoutButton: document.getElementById('logoutButton'),
    detailPanel: document.getElementById('detailPanel')
  }

  if (els.logoutButton) els.logoutButton.addEventListener('click', logout)

  function pathTokenId() {
    const parts = window.location.pathname.split('/').filter(Boolean)
    return parts[parts.length - 1] || ''
  }

  function durationPresetFromDate(expiresAt) {
    if (!expiresAt) return 'permanent'
    const diff = Math.round((new Date(expiresAt).getTime() - Date.now()) / 86400_000)
    if (Math.abs(diff - 30) <= 2) return 'month'
    if (Math.abs(diff - 183) <= 3) return 'halfyear'
    if (Math.abs(diff - 365) <= 4) return 'year'
    return ''
  }

  function expiryDateFromPreset(presetId) {
    const preset = DURATION_PRESETS.find(item => item.id === presetId)
    if (!preset || !preset.days) return null
    return new Date(Date.now() + preset.days * 86400_000).toISOString()
  }

  function playlistSummary(snapshot) {
    return snapshot || {
      hasSnapshot: false,
      updatedAt: null,
      revision: null,
      deviceName: null,
      playlistCount: 0,
      songCount: 0
    }
  }

  function selectedPlaylist() {
    const playlists = state.playlistData?.playlists || []
    return playlists.find(item => item.id === state.selectedPlaylistId) || playlists[0] || null
  }

  function songTitle(song) {
    return song?.name || song?.songName || song?.title || '未命名歌曲'
  }

  function songArtist(song) {
    if (typeof song?.artist === 'string' && song.artist) return song.artist
    if (typeof song?.artists === 'string' && song.artists) return song.artists
    if (Array.isArray(song?.artists)) {
      return song.artists.map(item => item?.name || item).filter(Boolean).join(' / ')
    }
    if (typeof song?.singer === 'string' && song.singer) return song.singer
    return '未知歌手'
  }

  function songAlbum(song) {
    if (typeof song?.album === 'string' && song.album) return song.album
    if (typeof song?.albumName === 'string' && song.albumName) return song.albumName
    if (typeof song?.al?.name === 'string' && song.al.name) return song.al.name
    return ''
  }

  function songCover(song) {
    return song?.coverUrl || song?.picUrl || song?.albumPic || song?.artwork || ''
  }

  function escapeAttr(value) {
    return esc(String(value || '')).replace(/"/g, '&quot;')
  }

  function detailStatusPill(detail) {
    const kind = detail.enabled && !detail.isExpired ? 'good' : (detail.isExpired ? 'warn' : 'soft')
    const label = detail.enabled && !detail.isExpired ? '在线' : (detail.isExpired ? '过期' : '停用')
    return `<span class="status-pill ${kind}">${label}</span>`
  }

  function renderPlaylistList() {
    const playlistData = state.playlistData
    const snapshot = playlistSummary(playlistData)
    const playlists = playlistData?.playlists || []

    return `
      <div class="panel-head">
        <div>
          <small class="eyebrow">Local Playlists</small>
          <h3>本地歌单</h3>
          <p>${snapshot.hasSnapshot ? `最后同步 ${fmtDate(snapshot.updatedAt)}` : '还没有同步记录'}</p>
        </div>
        <div class="playlist-actions">
          <button class="btn btn-secondary btn-small" type="button" data-action="refresh-playlists">刷新</button>
          <button class="btn btn-danger btn-small" type="button" data-action="clear-playlists" ${!snapshot.hasSnapshot ? 'disabled' : ''}>清空</button>
        </div>
      </div>
      <div class="detail-summary" style="margin-bottom:18px">
        <article class="summary-card">
          <span>歌单</span>
          <strong>${fmtNum(snapshot.playlistCount || 0)}</strong>
        </article>
        <article class="summary-card">
          <span>歌曲</span>
          <strong>${fmtNum(snapshot.songCount || 0)}</strong>
        </article>
        <article class="summary-card">
          <span>同步设备</span>
          <strong>${esc(snapshot.deviceName || '—')}</strong>
        </article>
        <article class="summary-card">
          <span>版本</span>
          <strong>${esc(snapshot.revision || '—')}</strong>
        </article>
      </div>
      <div class="playlist-list">
        ${playlists.length
          ? playlists.map(playlist => `
            <article class="playlist-item ${state.selectedPlaylistId === playlist.id ? 'active' : ''}" data-playlist-id="${playlist.id}">
              <div class="playlist-head">
                <div class="playlist-head" style="justify-content:flex-start">
                  <img class="playlist-thumb" src="${escapeAttr(playlist.coverUrl || brandMarkUrl)}" alt="" onerror="this.src='${brandMarkUrl}'">
                  <div class="song-main">
                    <div class="song-title">${esc(playlist.name || '未命名歌单')}</div>
                    <div class="song-meta">${fmtNum(playlist.songCount || 0)} 首 · ${playlist.isSystem ? '系统歌单' : '自定义歌单'}</div>
                  </div>
                </div>
              </div>
            </article>
          `).join('')
          : '<div class="empty">当前没有歌单快照</div>'}
      </div>
    `
  }

  function renderPlaylistDetail() {
    const playlist = selectedPlaylist()
    if (!playlist) {
      return '<div class="empty">选择左侧歌单后，在这里管理歌曲。</div>'
    }

    return `
      <div class="panel-head">
        <div>
          <small class="eyebrow">Playlist Detail</small>
          <h3>${esc(playlist.name || '未命名歌单')}</h3>
          <p>${fmtNum(playlist.songCount || 0)} 首歌曲 · ${fmtDate(playlist.updatedAt)}</p>
        </div>
        <button class="btn btn-danger btn-small" type="button" data-action="delete-playlist" data-playlist-id="${playlist.id}">删除歌单</button>
      </div>
      ${playlist.desc ? `<div class="notes-box" style="margin-bottom:16px">${esc(playlist.desc)}</div>` : ''}
      <div class="song-list">
        ${(playlist.songs || []).length
          ? playlist.songs.map(song => `
            <article class="song-row">
              <div class="playlist-head" style="justify-content:flex-start">
                <img class="song-cover" src="${escapeAttr(songCover(song) || brandMarkUrl)}" alt="" onerror="this.src='${brandMarkUrl}'">
                <div class="song-main">
                  <div class="song-title">${esc(songTitle(song))}</div>
                  <div class="song-meta">${esc(songArtist(song))}${songAlbum(song) ? ` · ${esc(songAlbum(song))}` : ''}</div>
                </div>
              </div>
              <div class="inline-actions">
                <button class="btn btn-ghost btn-small" type="button" data-action="delete-song" data-playlist-id="${playlist.id}" data-song-id="${escapeAttr(song.__songKey)}">移除</button>
              </div>
            </article>
          `).join('')
          : '<div class="empty">这个歌单还没有歌曲</div>'}
      </div>
    `
  }

  function renderDevices(detail) {
    const devices = detail.devices || []
    return `
      <div class="panel-head">
        <div>
          <small class="eyebrow">Devices</small>
          <h3>设备绑定</h3>
          <p>${fmtNum(devices.length)} 台已绑定设备</p>
        </div>
        <button class="btn btn-ghost btn-small" type="button" data-action="clear-devices" ${!devices.length ? 'disabled' : ''}>清空设备</button>
      </div>
      <div class="device-list">
        ${devices.length
          ? devices.map(device => `
            <article class="device-row">
              <div class="device-main">
                <div class="song-title">${esc(device.deviceId || '未知设备')}</div>
                <div class="song-meta">首次 ${fmtDate(device.firstSeen)} · 最近 ${fmtDate(device.lastSeen)}</div>
              </div>
              <button class="btn btn-ghost btn-small" type="button" data-action="remove-device" data-device-id="${escapeAttr(device.deviceId)}">移除</button>
            </article>
          `).join('')
          : '<div class="empty">还没有绑定设备</div>'}
      </div>
    `
  }

  function renderDetail() {
    const detail = state.tokenDetail
    if (!detail) {
      els.detailPanel.innerHTML = `
        <section class="panel">
          <div class="empty">没有找到这个 Token。</div>
          <div class="action-row" style="margin-top:18px">
            <a class="btn btn-secondary" href="${href('/tokens')}">返回 Token 列表</a>
          </div>
        </section>
      `
      return
    }

    const preset = durationPresetFromDate(detail.expiresAt)
    const snapshot = playlistSummary(detail.playlistSnapshot)
    document.title = `${detail.name || 'Token'} · Token 管理`

    els.detailPanel.innerHTML = `
      <section class="detail-shell">
        <a class="back-link" href="${href('/tokens')}">返回 Token 列表</a>

        <div class="detail-banner">
          <div class="detail-heading">
            <small class="eyebrow">Token Detail</small>
            <div>
              <div class="detail-banner-head">
                <h2 class="detail-title">${esc(detail.name || '未命名 Token')}</h2>
                ${detailStatusPill(detail)}
              </div>
              <div class="detail-meta-line">
                <span>${detail.expiresAt ? fmtDate(detail.expiresAt) : '永久'}</span>
                <span>创建于 ${fmtDate(detail.createdAt)}</span>
                <span>${detail.lastUsed ? `最近 ${fmtDate(detail.lastUsed)}` : '未使用'}</span>
              </div>
            </div>
            <div class="key-slab">${esc(detail.key || '')}</div>
          </div>
          <div class="detail-actions">
            <button class="btn btn-secondary" type="button" data-action="copy-key">复制 Key</button>
            <button class="btn btn-secondary" type="button" data-action="regenerate-token">重置 Key</button>
            <button class="btn ${detail.enabled ? 'btn-ghost' : 'btn-success'}" type="button" data-action="toggle-token">${detail.enabled ? '停用' : '启用'}</button>
            <button class="btn btn-danger" type="button" data-action="delete-token">删除</button>
          </div>
        </div>

        <div class="detail-summary">
          <article class="summary-card">
            <span>请求</span>
            <strong>${fmtNum(detail.requestCount || 0)}</strong>
          </article>
          <article class="summary-card">
            <span>下载</span>
            <strong>${fmtNum(detail.totalDownloads || 0)}</strong>
          </article>
          <article class="summary-card">
            <span>今日下载</span>
            <strong>${fmtNum(detail.todayDownloads || 0)}</strong>
          </article>
          <article class="summary-card">
            <span>歌单快照</span>
            <strong>${fmtNum(snapshot.playlistCount || 0)}</strong>
          </article>
        </div>

        <section class="panel">
          <div class="panel-head">
            <div>
              <small class="eyebrow">Rules</small>
              <h3>规则与时效</h3>
              <p>当前 Token 的单独规则。</p>
            </div>
            <button class="btn btn-primary btn-small" type="button" data-action="save-token">保存</button>
          </div>
          <div class="field-grid">
            <div class="field">
              <label for="detailNameInput">名称</label>
              <input id="detailNameInput" value="${escapeAttr(detail.name || '')}">
            </div>
            <div class="field">
              <label for="detailRateInput">每分钟</label>
              <input id="detailRateInput" type="number" min="0" value="${detail.rateLimit ?? 0}">
            </div>
            <div class="field">
              <label for="detailDownloadInput">每天下载</label>
              <input id="detailDownloadInput" type="number" min="0" value="${detail.downloadLimit ?? 0}">
            </div>
            <div class="field">
              <label for="detailDeviceInput">设备上限</label>
              <input id="detailDeviceInput" type="number" min="1" max="50" value="${detail.maxDevices ?? 3}">
            </div>
          </div>
          <div class="field" style="margin-top:18px">
            <label>时效</label>
            <div class="preset-row">
              ${DURATION_PRESETS.map(item => `
                <button class="preset-button ${preset === item.id ? 'active' : ''}" type="button" data-action="set-expiry" data-preset-id="${item.id}">
                  ${item.label}
                </button>
              `).join('')}
            </div>
          </div>
        </section>

        <div class="playlist-shell">
          <section class="panel">${renderPlaylistList()}</section>
          <section class="panel">${renderPlaylistDetail()}</section>
        </div>

        <section class="panel">
          ${renderDevices(detail)}
        </section>
      </section>
    `
  }

  async function loadDetail() {
    if (!state.tokenId) {
      state.tokenDetail = null
      state.playlistData = null
      renderDetail()
      return
    }

    const [detail, playlists] = await Promise.all([
      request(`/api/tokens/${state.tokenId}`),
      request(`/api/tokens/${state.tokenId}/playlists`)
    ])

    state.tokenDetail = detail
    state.playlistData = playlists
    const playlistIds = (playlists.playlists || []).map(item => item.id)
    if (!playlistIds.includes(state.selectedPlaylistId)) {
      state.selectedPlaylistId = playlistIds[0] || null
    }
    renderDetail()
  }

  async function saveToken() {
    await request(`/api/tokens/${state.tokenId}`, {
      method: 'PUT',
      body: JSON.stringify({
        name: document.getElementById('detailNameInput')?.value.trim() || '未命名 Token',
        rateLimit: Number(document.getElementById('detailRateInput')?.value || 0),
        downloadLimit: Number(document.getElementById('detailDownloadInput')?.value || 0),
        maxDevices: Number(document.getElementById('detailDeviceInput')?.value || 1)
      })
    })
    notify('已保存', 'success')
    await loadDetail()
  }

  async function setExpiryPreset(presetId) {
    await request(`/api/tokens/${state.tokenId}`, {
      method: 'PUT',
      body: JSON.stringify({ expiresAt: expiryDateFromPreset(presetId) })
    })
    notify('时效已更新', 'success')
    await loadDetail()
  }

  async function toggleToken() {
    await request(`/api/tokens/${state.tokenId}/toggle`, { method: 'PUT' })
    notify('已切换', 'success')
    await loadDetail()
  }

  async function regenerateToken() {
    if (!window.confirm('确定重置这个 Token 的 Key？')) return
    await request(`/api/tokens/${state.tokenId}/regenerate`, { method: 'POST' })
    notify('已重置', 'success')
    await loadDetail()
  }

  async function deleteToken() {
    if (!window.confirm('确定删除这个 Token？')) return
    await request(`/api/tokens/${state.tokenId}`, { method: 'DELETE' })
    window.location.href = href('/tokens')
  }

  async function copyKey() {
    if (!state.tokenDetail?.key) return
    await navigator.clipboard.writeText(state.tokenDetail.key)
    notify('已复制', 'success')
  }

  async function clearPlaylists() {
    if (!window.confirm('确定清空这个 Token 下的所有歌单？')) return
    await request(`/api/tokens/${state.tokenId}/playlists`, { method: 'DELETE' })
    notify('已清空', 'success')
    await loadDetail()
  }

  async function deletePlaylist(playlistId) {
    if (!window.confirm('确定删除这个歌单？')) return
    await request(`/api/tokens/${state.tokenId}/playlists/${encodeURIComponent(playlistId)}`, { method: 'DELETE' })
    notify('已删除', 'success')
    await loadDetail()
  }

  async function deleteSong(playlistId, songId) {
    await request(`/api/tokens/${state.tokenId}/playlists/${encodeURIComponent(playlistId)}/songs/${encodeURIComponent(songId)}`, {
      method: 'DELETE'
    })
    notify('已移除', 'success')
    await loadDetail()
  }

  async function removeDevice(deviceId) {
    await request(`/api/tokens/${state.tokenId}/devices/${encodeURIComponent(deviceId)}`, { method: 'DELETE' })
    notify('已移除', 'success')
    await loadDetail()
  }

  async function clearDevices() {
    if (!window.confirm('确定清空设备绑定？')) return
    await request(`/api/tokens/${state.tokenId}/devices`, { method: 'DELETE' })
    notify('已清空', 'success')
    await loadDetail()
  }

  els.detailPanel.addEventListener('click', async event => {
    const playlistItem = event.target.closest('[data-playlist-id]')
    if (playlistItem && !event.target.closest('[data-action]')) {
      state.selectedPlaylistId = playlistItem.dataset.playlistId
      renderDetail()
      return
    }

    const button = event.target.closest('[data-action]')
    if (!button) return

    try {
      if (button.dataset.action === 'copy-key') await copyKey()
      if (button.dataset.action === 'regenerate-token') await regenerateToken()
      if (button.dataset.action === 'toggle-token') await toggleToken()
      if (button.dataset.action === 'delete-token') await deleteToken()
      if (button.dataset.action === 'save-token') await saveToken()
      if (button.dataset.action === 'set-expiry') await setExpiryPreset(button.dataset.presetId)
      if (button.dataset.action === 'refresh-playlists') await loadDetail()
      if (button.dataset.action === 'clear-playlists') await clearPlaylists()
      if (button.dataset.action === 'delete-playlist') await deletePlaylist(button.dataset.playlistId)
      if (button.dataset.action === 'delete-song') await deleteSong(button.dataset.playlistId, button.dataset.songId)
      if (button.dataset.action === 'remove-device') await removeDevice(button.dataset.deviceId)
      if (button.dataset.action === 'clear-devices') await clearDevices()
    } catch (error) {
      notify(error.message || '操作失败', 'error')
    }
  })

  async function boot() {
    state.tokenId = pathTokenId()
    try {
      await loadDetail()
    } catch (_) {
      state.tokenDetail = null
      state.playlistData = null
      renderDetail()
    }
  }

  setupAuth(boot)
})()
