function createTokenSongContentAdapters({
  ncmBaseURL = process.env.NCM_INTERNAL_BASE_URL || 'http://127.0.0.1:4006',
  qcmBaseURL = process.env.QCM_INTERNAL_BASE_URL || 'http://127.0.0.1:3301',
  webSearchBaseURL = process.env.SONG_CONTENT_WEB_SEARCH_URL || 'https://www.so.com/s',
  baiduWebSearchBaseURL = process.env.SONG_CONTENT_BAIDU_SEARCH_URL || 'https://www.baidu.com/s',
  bingWebSearchBaseURL = process.env.SONG_CONTENT_BING_SEARCH_URL || 'https://cn.bing.com/search',
  sogouWebSearchBaseURL = process.env.SONG_CONTENT_SOGOU_SEARCH_URL || 'https://www.sogou.com/web',
  webSearchEnabled = process.env.SONG_CONTENT_WEB_SEARCH_ENABLED !== 'false',
  fetchImpl = globalThis.fetch,
  logger = console
} = {}) {
  if (typeof fetchImpl !== 'function') throw new TypeError('fetch implementation is required')
  const searchProviders = [
    { key: '360', label: '360 搜索', baseURL: webSearchBaseURL, queryParameter: 'q', parser: parse360SearchResults },
    { key: 'baidu', label: '百度', baseURL: baiduWebSearchBaseURL, queryParameter: 'wd', parser: parseBaiduSearchResults },
    { key: 'bing', label: 'Bing', baseURL: bingWebSearchBaseURL, queryParameter: 'q', parser: parseBingSearchResults },
    { key: 'sogou', label: '搜狗', baseURL: sogouWebSearchBaseURL, queryParameter: 'query', parser: parseSogouSearchResults }
  ]

  async function platformResolver({ platform, platformSongId }) {
    if (platform === 'QCM') return resolveQCMSong(platformSongId)
    if (platform !== 'NCM' || !/^\d+$/.test(platformSongId)) return null
    const payload = await fetchJSON(ncmBaseURL, `/song/detail?ids=${encodeURIComponent(platformSongId)}`, 'NCM')
    const raw = payload?.songs?.[0]
    if (!raw || String(raw.id) !== String(platformSongId)) return null

    const title = clean(raw.name, 500)
    const artists = Array.isArray(raw.ar)
      ? raw.ar.map((artist) => ({ id: String(artist.id || ''), name: clean(artist.name, 300) })).filter((artist) => artist.name)
      : []
    if (!title || artists.length === 0) return null

    return {
      title,
      artists,
      album: raw.al?.name ? { id: String(raw.al.id || ''), name: clean(raw.al.name, 500) } : null,
      durationMs: finiteNumber(raw.dt),
      releaseDate: finiteNumber(raw.publishTime)
        ? { value: new Date(raw.publishTime).toISOString().slice(0, 10), precision: 'day' }
        : null,
      versionLabel: inferVersionLabel(title, raw.alia),
      coverUrl: httpURL(raw.al?.picUrl),
      identityStatus: 'confirmed',
      platformArtistId: artists[0]?.id,
      platformAlbumId: raw.al?.id ? String(raw.al.id) : null,
      matchMethod: 'official_mapping',
      matchConfidence: 1,
      rawMetadata: raw
    }
  }

  async function sourceCollector({ song, retrievalPolicy = {} }) {
    let platformEvidence
    const qcmMapping = song.platformMappings.find((item) => item.platform === 'QCM')
    if (qcmMapping) {
      platformEvidence = await collectQCMSources(song, qcmMapping)
    }

    const ncmMapping = song.platformMappings.find((item) => item.platform === 'NCM')
    if (!platformEvidence && ncmMapping && /^\d+$/.test(ncmMapping.songId)) {
      platformEvidence = await collectNCMSources(song, {
        songId: ncmMapping.songId,
        albumId: song.album?.id,
        albumName: song.album?.name,
        matchMethod: 'official_mapping'
      })
    }

    if (!platformEvidence) {
      const qcmMatch = await resolveCrossPlatformQCMMatch(song)
      if (qcmMatch) platformEvidence = await collectQCMSources(song, qcmMatch)
    }

    if (!platformEvidence) {
      const ncmMatch = await resolveCrossPlatformNCMMatch(song)
      if (ncmMatch) platformEvidence = await collectNCMSources(song, ncmMatch)
    }

    platformEvidence ||= { sources: [], exclusions: buildExclusions(song) }
    if (!webSearchEnabled || retrievalPolicy.enabled === false) return platformEvidence

    const webSources = await collectWebSources(song, retrievalPolicy).catch((error) => {
      logger.warn?.('[song-content-adapter] web evidence collection failed', error.message)
      return []
    })
    return {
      ...platformEvidence,
      sources: deduplicateSources([...(platformEvidence.sources || []), ...webSources])
    }
  }

  async function collectNCMSources(song, reference) {
    const songId = String(reference.songId)
    const albumId = reference.albumId ? String(reference.albumId) : null

    const [wikiResult, albumResult] = await Promise.allSettled([
      fetchJSON(ncmBaseURL, `/song/wiki/summary?id=${encodeURIComponent(songId)}`, 'NCM'),
      albumId ? fetchJSON(ncmBaseURL, `/album?id=${encodeURIComponent(albumId)}`, 'NCM') : Promise.resolve(null)
    ])

    const wikiText = wikiResult.status === 'fulfilled'
      ? extractWikiText(wikiResult.value?.data?.blocks)
      : ''
    const albumText = albumResult.status === 'fulfilled'
      ? clean(albumResult.value?.album?.description || albumResult.value?.album?.briefDesc, 4_000)
      : ''
    const now = new Date().toISOString()
    const sources = []

    if (wikiText) {
      const roleAnalysis = analyzeContentRoles(['songSummary', 'creationStory'], wikiText, song, { platformSource: true })
      if (roleAnalysis.roles.length > 0) {
        sources.push({
          url: `https://music.163.com/song?id=${encodeURIComponent(songId)}`,
          title: `${song.title} - 音乐百科`,
          publisher: '网易云音乐',
          fetchedAt: now,
          grade: 'B',
          excerpt: wikiText,
          metadata: {
            platform: 'NCM',
            platformSongId: songId,
            sourceType: 'song_wiki',
            contentRoles: roleAnalysis.roles,
            contentRoleConfidence: roleAnalysis.confidence,
            contentRoleEvidence: roleAnalysis.evidence,
            matchMethod: reference.matchMethod
          }
        })
      }
    }
    if (albumText && albumId) {
      sources.push({
        url: `https://music.163.com/album?id=${encodeURIComponent(albumId)}`,
        title: `${reference.albumName || song.album?.name || '专辑'} - 专辑介绍`,
        publisher: '网易云音乐',
        fetchedAt: now,
        grade: 'B',
        excerpt: albumText,
        metadata: {
          platform: 'NCM',
          platformAlbumId: albumId,
          sourceType: 'album_description',
          contentRoles: ['albumSummary'],
          contentRoleConfidence: { albumSummary: 1 },
          contentRoleEvidence: { albumSummary: ['平台正式专辑介绍'] },
          matchMethod: reference.matchMethod
        }
      })
    }

    return {
      platformSummary: sources.some((source) => source.metadata.sourceType === 'song_wiki') ? wikiText : null,
      albumSummary: albumText || null,
      exclusions: buildExclusions(song),
      sources
    }
  }

  async function resolveCrossPlatformNCMMatch(song) {
    const primaryArtist = clean(song.artists?.[0]?.name, 300)
    if (!song.title || !primaryArtist) return null
    const keywords = `${song.title} ${primaryArtist}`
    const payload = await fetchJSON(
      ncmBaseURL,
      `/cloudsearch?keywords=${encodeURIComponent(keywords)}&type=1&limit=20`,
      'NCM'
    ).catch(() => null)
    const candidates = Array.isArray(payload?.result?.songs) ? payload.result.songs : []
    const targetArtists = new Set((song.artists || []).map((artist) => comparable(artist.name)).filter(Boolean))
    const targetAlbum = comparable(song.album?.name)
    const targetDuration = finiteNumber(song.durationMs)

    const matches = candidates.filter((candidate) => {
      const artists = candidate.ar || candidate.artists || []
      if (!artists.some((artist) => targetArtists.has(comparable(artist.name)))) return false
      const duration = finiteNumber(candidate.dt ?? candidate.duration)
      const albumName = comparable(candidate.al?.name ?? candidate.album?.name)
      const durationDelta = targetDuration && duration ? Math.abs(targetDuration - duration) : null
      if (!strictTitleMatch(song.title, candidate.name, targetAlbum, albumName, durationDelta)) return false
      if (durationDelta !== null) return durationDelta <= 8_000
      return Boolean(targetAlbum && albumName === targetAlbum)
    })

    const candidate = matches.sort((left, right) => {
      const leftAlbum = comparable(left.al?.name ?? left.album?.name) === targetAlbum ? 1 : 0
      const rightAlbum = comparable(right.al?.name ?? right.album?.name) === targetAlbum ? 1 : 0
      if (leftAlbum !== rightAlbum) return rightAlbum - leftAlbum
      const leftDelta = Math.abs((finiteNumber(left.dt ?? left.duration) || 0) - (targetDuration || 0))
      const rightDelta = Math.abs((finiteNumber(right.dt ?? right.duration) || 0) - (targetDuration || 0))
      return leftDelta - rightDelta
    })[0]
    if (!candidate?.id) return null

    return {
      songId: String(candidate.id),
      albumId: candidate.al?.id ?? candidate.album?.id ?? null,
      albumName: clean(candidate.al?.name ?? candidate.album?.name, 500),
      matchMethod: 'strict_cross_platform_metadata'
    }
  }

  async function resolveCrossPlatformQCMMatch(song) {
    const primaryArtist = clean(song.artists?.[0]?.name, 300)
    if (!song.title || !primaryArtist) return null
    const keyword = `${song.title} ${primaryArtist}`
    const payload = await fetchJSON(
      qcmBaseURL,
      `/search/search_by_type?keyword=${encodeURIComponent(keyword)}&search_type=0&num=20&page=1`,
      'QCM'
    ).catch(() => null)
    const candidates = payload?.data?.result?.song
    if (!Array.isArray(candidates)) return null

    const targetArtists = new Set((song.artists || []).map((artist) => comparable(artist.name)).filter(Boolean))
    const targetAlbum = comparable(song.album?.name)
    const targetDuration = finiteNumber(song.durationMs)
    const matches = candidates.filter((candidate) => {
      const artists = candidate.singer || []
      if (!artists.some((artist) => targetArtists.has(comparable(artist.name ?? artist.title)))) return false
      const duration = finiteNumber(candidate.interval)
      const durationMs = duration ? duration * 1_000 : null
      const albumName = comparable(candidate.album?.name ?? candidate.album?.title)
      const durationDelta = targetDuration && durationMs ? Math.abs(targetDuration - durationMs) : null
      if (!strictTitleMatch(song.title, candidate.name ?? candidate.title, targetAlbum, albumName, durationDelta)) return false
      if (durationDelta !== null) return durationDelta <= 8_000
      return Boolean(targetAlbum && albumName === targetAlbum)
    })
    const candidate = matches.sort((left, right) => {
      const leftAlbum = comparable(left.album?.name ?? left.album?.title) === targetAlbum ? 1 : 0
      const rightAlbum = comparable(right.album?.name ?? right.album?.title) === targetAlbum ? 1 : 0
      if (leftAlbum !== rightAlbum) return rightAlbum - leftAlbum
      const leftDuration = (finiteNumber(left.interval) || 0) * 1_000
      const rightDuration = (finiteNumber(right.interval) || 0) * 1_000
      return Math.abs(leftDuration - (targetDuration || 0)) - Math.abs(rightDuration - (targetDuration || 0))
    })[0]
    const songMid = clean(candidate?.mid, 256)
    if (!songMid) return null
    return { songId: songMid, matchMethod: 'strict_cross_platform_metadata' }
  }

  async function resolveQCMSong(platformSongId) {
    if (!/^[A-Za-z0-9_-]{6,128}$/.test(platformSongId)) return null
    const payload = await fetchJSON(qcmBaseURL, `/song/get_detail?value=${encodeURIComponent(platformSongId)}`, 'QCM')
    const detail = unwrapQCM(payload)
    const track = detail?.track
    if (!track || String(track.mid || '') !== platformSongId) return null
    const title = clean(track.name || track.title, 500)
    const artists = Array.isArray(track.singer)
      ? track.singer.map((artist) => ({
          id: clean(artist.mid || artist.id, 256),
          name: clean(artist.name || artist.title, 300)
        })).filter((artist) => artist.name)
      : []
    if (!title || artists.length === 0) return null
    const albumMid = clean(track.album?.mid || track.album?.id, 256)

    return {
      title,
      artists,
      album: track.album?.name ? { id: albumMid, name: clean(track.album.name, 500) } : null,
      durationMs: finiteNumber(track.interval) ? Number(track.interval) * 1_000 : null,
      releaseDate: qcmReleaseDate(track.time_public),
      versionLabel: inferVersionLabel(title, [track.subtitle]),
      coverUrl: albumMid ? `https://y.gtimg.cn/music/photo_new/T002R800x800M000${albumMid}.jpg` : null,
      identityStatus: 'confirmed',
      platformArtistId: artists[0]?.id,
      platformAlbumId: albumMid,
      matchMethod: 'official_mapping',
      matchConfidence: 1,
      rawMetadata: track
    }
  }

  async function collectQCMSources(song, mapping) {
    const songResult = await fetchJSON(qcmBaseURL, `/song/get_detail?value=${encodeURIComponent(mapping.songId)}`, 'QCM')
    const songDetail = unwrapQCM(songResult)
    const albumMid = clean(songDetail?.track?.album?.mid || song.album?.id, 256)
    const albumResult = albumMid
      ? await fetchJSON(qcmBaseURL, `/album/get_detail?value=${encodeURIComponent(albumMid)}`, 'QCM').catch(() => null)
      : null
    const intro = qcmDescription(songDetail?.intro)
    const albumDescription = clean(unwrapQCM(albumResult)?.album?.desc, 4_000)
    const now = new Date().toISOString()
    const sources = []

    if (intro) {
      const roleAnalysis = analyzeContentRoles(['songSummary', 'creationStory'], intro, song, { platformSource: true })
      if (roleAnalysis.roles.length > 0) {
        sources.push({
          url: `https://y.qq.com/n/ryqq/songDetail/${encodeURIComponent(mapping.songId)}`,
          title: `${song.title} - 歌曲资料`,
          publisher: 'QQ音乐',
          fetchedAt: now,
          grade: 'B',
          excerpt: intro,
          metadata: {
            platform: 'QCM',
            platformSongId: mapping.songId,
            sourceType: 'song_description',
            contentRoles: roleAnalysis.roles,
            contentRoleConfidence: roleAnalysis.confidence,
            contentRoleEvidence: roleAnalysis.evidence,
            matchMethod: mapping.matchMethod || 'official_mapping'
          }
        })
      }
    }
    if (albumDescription && albumMid) {
      sources.push({
        url: `https://y.qq.com/n/ryqq/albumDetail/${encodeURIComponent(albumMid)}`,
        title: `${song.album?.name || '专辑'} - 专辑介绍`,
        publisher: 'QQ音乐',
        fetchedAt: now,
        grade: 'B',
        excerpt: albumDescription,
        metadata: {
          platform: 'QCM',
          platformAlbumId: albumMid,
          sourceType: 'album_description',
          contentRoles: ['albumSummary'],
          contentRoleConfidence: { albumSummary: 1 },
          contentRoleEvidence: { albumSummary: ['平台正式专辑介绍'] },
          matchMethod: mapping.matchMethod || 'official_mapping'
        }
      })
    }

    return {
      platformSummary: sources.some((source) => source.metadata.sourceType === 'song_description') ? intro : null,
      albumSummary: albumDescription || null,
      exclusions: buildExclusions(song),
      sources
    }
  }

  async function collectWebSources(song, retrievalPolicy) {
    const primaryArtist = clean(song.artists?.[0]?.name, 300)
    if (!song.title || !primaryArtist) return []

    const albumName = clean(song.album?.name, 500)
    const preferredSources = selectPreferredSources(retrievalPolicy.preferredSources)
    const songIdentity = `"${song.title}" "${primaryArtist}"${albumName ? ` "${albumName}"` : ''}`
    const primarySearches = [
      { query: `${songIdentity} 歌曲介绍 发行 收录 主题`, roles: ['songSummary'] },
      { query: `${songIdentity} 创作故事 作词 作曲 制作人 采访`, roles: ['creationStory'] },
      { query: `${songIdentity} 乐评 赏析 音乐分析 编曲`, roles: ['background'] },
      ...(albumName ? [{ query: `"${albumName}" "${primaryArtist}" 专辑介绍 发行 制作 曲目`, roles: ['albumSummary'] }] : [])
    ]
    const supplementalSearches = [
      { query: `${songIdentity} 作品介绍 歌词 主题 单曲`, roles: ['songSummary'] },
      { query: `${songIdentity} 创作背景 录音 制作 幕后`, roles: ['creationStory'] },
      { query: `${songIdentity} 评论 旋律 节奏 和声 制作`, roles: ['background'] },
      ...(albumName ? [{ query: `"${albumName}" "${primaryArtist}" 专访 制作手记 专辑乐评`, roles: ['albumSummary', 'background'] }] : []),
      ...(preferredSources.has('douban') ? [
        { query: `site:music.douban.com/review "${song.title}" "${primaryArtist}" 乐评`, roles: ['background'] },
        ...(albumName ? [{ query: `site:music.douban.com/subject "${albumName}" "${primaryArtist}" 专辑 乐评`, roles: ['albumSummary', 'background'] }] : [])
      ] : []),
      ...(preferredSources.has('xiaohongshu')
        ? [{ query: `site:xiaohongshu.com/explore "${song.title}" "${primaryArtist}" 音乐 乐评`, roles: ['background'] }]
        : [])
    ]

    const enabledProviders = selectSearchProviders(searchProviders, retrievalPolicy.providers)
    async function searchCandidates(searches) {
      const batches = await Promise.all(searches.flatMap((search) => enabledProviders.map(async (provider) => {
        const url = new URL(provider.baseURL)
        url.searchParams.set(provider.queryParameter, search.query)
        if (provider.key === 'bing') url.searchParams.set('setlang', 'zh-hans')
        if (provider.key === 'sogou') url.searchParams.set('ie', 'utf8')
        try {
          const html = await fetchText(url, { maximumBytes: 1_200_000, timeoutMs: 10_000 })
          return provider.parser(html, search.roles, provider.key)
        } catch (error) {
          logger.warn?.(`[song-content-adapter] ${provider.label} failed for ${search.roles.join(',')}`, error.message)
          return []
        }
      })))
      return rankWebCandidates(batches.flat(), song)
    }

    const ranked = await searchCandidates(primarySearches)
    const maximumSources = Math.max(1, Math.min(16, Number(retrievalPolicy.maximumSources) || 10))
    const initialMaximum = maximumSources <= 4 ? maximumSources : maximumSources - 3
    const selected = selectBalancedWebCandidates(ranked, initialMaximum)

    async function materializeWebCandidate(candidate) {
      let pageText = ''
      let pageIdentityText = ''
      try {
        const html = await fetchText(candidate.url, { maximumBytes: 900_000, timeoutMs: 12_000 })
        pageText = extractArticleText(html)
        pageIdentityText = stripHTML(html).slice(0, 50_000)
      } catch (error) {
        logger.warn?.(`[song-content-adapter] web page unavailable: ${candidate.url}`, error.message)
      }
      if (!pageText || !webTextMatchesSong(`${pageIdentityText}\n${pageText}`, song, candidate.roles)) return null
      const combined = cleanWebExcerpt([candidate.snippet, pageText].filter(Boolean).join('\n'))
      if (!combined) return null
      const roleAnalysis = analyzeContentRoles(candidate.roles, combined, song)
      if (roleAnalysis.roles.length === 0) return null
      return {
        url: candidate.url,
        title: clean(candidate.title, 500) || `${song.title} - 网页资料`,
        publisher: candidate.trust.publisher,
        publishedAt: candidate.publishedAt,
        fetchedAt: new Date().toISOString(),
        grade: candidate.trust.grade,
        excerpt: combined,
        accessible: Boolean(pageText),
        metadata: {
          platform: 'WEB',
          sourceType: webSourceType(roleAnalysis.roles),
          contentRoles: roleAnalysis.roles,
          contentRoleConfidence: roleAnalysis.confidence,
          contentRoleEvidence: roleAnalysis.evidence,
          searchProvider: candidate.searchProviders?.[0] || candidate.searchProvider,
          searchProviders: candidate.searchProviders || [candidate.searchProvider].filter(Boolean),
          contentPlatform: candidate.contentPlatform,
          retrievalMode: 'web_search_and_page_extract',
          untrustedWebContent: true
        }
      }
    }

    const initialSources = (await Promise.all(selected.map(materializeWebCandidate))).filter(Boolean)
    const coveredRoles = new Set(initialSources.flatMap((source) => source.metadata.contentRoles))
    const missingRoles = ['songSummary', 'creationStory', 'background', 'albumSummary']
      .filter((role) => !coveredRoles.has(role) && (role !== 'albumSummary' || albumName))
    const selectedURLs = new Set(selected.map((candidate) => candidate.url))
    const searchesForMissingRoles = supplementalSearches
      .filter((search) => search.roles.some((role) => missingRoles.includes(role)))
    const searchedSupplements = missingRoles.length > 0
      ? await searchCandidates(searchesForMissingRoles)
      : []
    const supplementalCandidates = rankWebCandidates([
      ...ranked.filter((candidate) => !selectedURLs.has(candidate.url)),
      ...searchedSupplements
    ], song)
      .filter((candidate) => !selectedURLs.has(candidate.url) && candidate.roles.some((role) => missingRoles.includes(role)))
      .slice(0, Math.min(8, Math.max(2, missingRoles.length * 2)))
    const supplementalSources = missingRoles.length > 0
      ? (await Promise.all(supplementalCandidates.map(materializeWebCandidate))).filter(Boolean)
      : []

    return selectBalancedWebCandidates([...initialSources, ...supplementalSources], maximumSources)
  }

  async function fetchText(url, { maximumBytes, timeoutMs }) {
    const safeURL = safeExternalURL(url)
    if (!safeURL) throw new Error('unsafe or invalid external URL')
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), timeoutMs)
    try {
      const response = await fetchImpl(safeURL, {
        signal: controller.signal,
        redirect: 'follow',
        headers: {
          Accept: 'text/html,application/xhtml+xml,application/rss+xml,text/plain;q=0.9,*/*;q=0.4',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.5',
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124 Safari/537.36'
        }
      })
      if (!response.ok) throw new Error(`web source returned ${response.status}`)
      const contentLength = finiteNumber(response.headers.get('content-length'))
      if (contentLength && contentLength > maximumBytes * 2) throw new Error('web source is too large')
      if (!response.body?.getReader) return (await response.text()).slice(0, maximumBytes)

      const reader = response.body.getReader()
      const decoder = new TextDecoder()
      let total = 0
      let output = ''
      while (total < maximumBytes) {
        const { done, value } = await reader.read()
        if (done) break
        const remaining = maximumBytes - total
        const chunk = value.length > remaining ? value.subarray(0, remaining) : value
        total += chunk.length
        output += decoder.decode(chunk, { stream: total < maximumBytes })
        if (chunk.length < value.length) {
          await reader.cancel()
          break
        }
      }
      output += decoder.decode()
      return output
    } finally {
      clearTimeout(timer)
    }
  }

  async function fetchJSON(baseURL, route, label) {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), 10_000)
    try {
      const url = new URL(route, baseURL.endsWith('/') ? baseURL : `${baseURL}/`)
      const response = await fetchImpl(url, { signal: controller.signal, headers: { Accept: 'application/json' } })
      if (!response.ok) throw new Error(`${label} metadata returned ${response.status}`)
      return response.json()
    } catch (error) {
      logger.warn?.(`[song-content-adapter] ${label} ${route} failed`, error.message)
      throw error
    } finally {
      clearTimeout(timer)
    }
  }

  return { platformResolver, sourceCollector }
}

function unwrapQCM(payload) {
  return payload?.data?.result ?? payload?.result ?? payload?.data ?? payload
}

function qcmDescription(value) {
  if (!Array.isArray(value)) return ''
  return value.map((item) => clean(item?.value || item?.text, 2_000)).filter(Boolean).join('\n').slice(0, 4_000)
}

function qcmReleaseDate(value) {
  const normalized = clean(value, 32)
  if (!/^\d{4}(?:-\d{2})?(?:-\d{2})?$/.test(normalized)) return null
  return {
    value: normalized,
    precision: normalized.length === 4 ? 'year' : (normalized.length === 7 ? 'month' : 'day')
  }
}

function extractWikiText(blocks) {
  if (!Array.isArray(blocks)) return ''
  const values = []
  for (const block of blocks) {
    collectText(block?.uiElement?.descriptions, values)
    collectText(block?.creatives, values)
  }
  return [...new Set(values.map((value) => clean(value, 1_500)).filter(Boolean))].join('\n').slice(0, 4_000)
}

function collectText(value, output) {
  if (!value) return
  if (typeof value === 'string') {
    output.push(value)
    return
  }
  if (Array.isArray(value)) {
    for (const item of value) collectText(item, output)
    return
  }
  if (typeof value === 'object') {
    for (const [key, item] of Object.entries(value)) {
      if (['description', 'text', 'title', 'content'].includes(key) && typeof item === 'string') output.push(item)
      else collectText(item, output)
    }
  }
}

function inferVersionLabel(title, aliases) {
  const value = [title, ...(Array.isArray(aliases) ? aliases : [])].join(' ')
  if (/live|现场/iu.test(value)) return 'live'
  if (/remaster|重制/iu.test(value)) return 'remastered'
  if (/伴奏|instrumental/iu.test(value)) return 'instrumental'
  if (/加速|sped up/iu.test(value)) return 'sped-up'
  return 'original'
}

function buildExclusions(song) {
  const artist = song.artists.map((item) => item.name).join(' / ')
  return [
    `其他艺人演唱的同名歌曲《${song.title}》`,
    `${artist}《${song.title}》的现场版、重制版、伴奏版和加速版`
  ]
}

function clean(value, maximum) {
  return typeof value === 'string' ? value.trim().slice(0, maximum) : ''
}

function comparable(value) {
  return String(value || '')
    .normalize('NFKC')
    .toLowerCase()
    .replace(/[\s\p{P}\p{S}]+/gu, '')
}

function parse360SearchResults(html, roles, searchProvider = '360') {
  const results = []
  const blocks = String(html || '').match(/<li\b[^>]*class=["'][^"']*\bres-list\b[^"']*["'][^>]*>[\s\S]*?<\/li>/giu) || []
  for (const block of blocks.slice(0, 12)) {
    const heading = block.match(/<h3\b[^>]*>[\s\S]*?<\/h3>/iu)?.[0] || ''
    const title = stripHTML(heading)
    const directURL = htmlAttribute(heading, 'data-mdurl') || htmlAttribute(heading, 'href')
    const url = safeExternalURL(decodeHTMLEntities(directURL))
    if (!url || url.hostname.endsWith('so.com')) continue
    const summaryHTML = block.match(/<span\b[^>]*class=["'][^"']*res-list-summary[^"']*["'][^>]*>([\s\S]*?)<\/span>/iu)?.[1]
      || block.match(/<p\b[^>]*class=["'][^"']*res-list-summary[^"']*["'][^>]*>([\s\S]*?)<\/p>/iu)?.[1]
      || block.match(/<div\b[^>]*class=["'][^"']*res-list-summary[^"']*["'][^>]*>([\s\S]*?)<\/div>/iu)?.[1]
      || ''
    const snippet = cleanWebExcerpt(stripHTML(summaryHTML))
    if (!title || !snippet) continue
    results.push({
      title,
      url: url.toString(),
      snippet,
      roles: [...new Set(roles)],
      searchProvider,
      publishedAt: webPublishedDate(block)
    })
  }
  return results
}

function parseBaiduSearchResults(html, roles, searchProvider = 'baidu') {
  const value = String(html || '')
  const starts = [...value.matchAll(/<div\b[^>]*(?:class=["'][^"']*\bresult(?:-op)?\b[^"']*["']|tpl=["']se_com_default["'])[^>]*>/giu)]
    .map((match) => match.index)
  const results = []
  for (let index = 0; index < Math.min(starts.length, 16); index += 1) {
    const block = value.slice(starts[index], starts[index + 1] || value.length)
    const heading = block.match(/<h3\b[^>]*>[\s\S]*?<\/h3>/iu)?.[0] || ''
    const directURL = htmlAttribute(block, 'mu')
      || htmlAttribute(block, 'data-landurl')
      || htmlAttribute(heading, 'href')
    const url = safeExternalURL(decodeHTMLEntities(directURL))
    if (!url || /(^|\.)baidu\.com$/iu.test(url.hostname)) continue
    const title = stripHTML(heading)
    const summaryHTML = block.match(/<div\b[^>]*class=["'][^"']*(?:c-abstract|content-right_8Zs40)[^"']*["'][^>]*>([\s\S]*?)<\/div>/iu)?.[1]
      || block.match(/<span\b[^>]*class=["'][^"']*content-right_8Zs40[^"']*["'][^>]*>([\s\S]*?)<\/span>/iu)?.[1]
      || ''
    const snippet = cleanWebExcerpt(stripHTML(summaryHTML))
    if (!title || !snippet) continue
    results.push({
      title,
      url: url.toString(),
      snippet,
      roles: [...new Set(roles)],
      searchProvider,
      publishedAt: webPublishedDate(block)
    })
  }
  return results
}

function parseBingSearchResults(html, roles, searchProvider = 'bing') {
  const results = []
  const blocks = String(html || '').match(/<li\b[^>]*class=["'][^"']*\bb_algo\b[^"']*["'][^>]*>[\s\S]*?<\/li>/giu) || []
  for (const block of blocks.slice(0, 12)) {
    const heading = block.match(/<h2\b[^>]*>[\s\S]*?<\/h2>/iu)?.[0] || ''
    const title = stripHTML(heading)
    const url = safeExternalURL(decodeHTMLEntities(htmlAttribute(heading, 'href')))
    if (!url || /(^|\.)bing\.com$/iu.test(url.hostname)) continue
    const summaryHTML = block.match(/<div\b[^>]*class=["'][^"']*\bb_caption\b[^"']*["'][^>]*>[\s\S]*?<p\b[^>]*>([\s\S]*?)<\/p>/iu)?.[1]
      || block.match(/<p\b[^>]*>([\s\S]*?)<\/p>/iu)?.[1]
      || ''
    const snippet = cleanWebExcerpt(stripHTML(summaryHTML))
    if (!title || !snippet) continue
    results.push({
      title,
      url: url.toString(),
      snippet,
      roles: [...new Set(roles)],
      searchProvider,
      publishedAt: webPublishedDate(block)
    })
  }
  return results
}

function parseSogouSearchResults(html, roles, searchProvider = 'sogou') {
  const value = String(html || '')
  const starts = [...value.matchAll(/<div\b[^>]*class=["'][^"']*\bvrwrap\b[^"']*["'][^>]*>/giu)].map((match) => match.index)
  const results = []
  for (let index = 0; index < Math.min(starts.length, 16); index += 1) {
    const block = value.slice(starts[index], starts[index + 1] || value.length)
    const heading = block.match(/<h3\b[^>]*>[\s\S]*?<\/h3>/iu)?.[0] || ''
    const directURL = decodeHTMLEntities(htmlAttribute(heading, 'href'))
    if (!/^https?:\/\//iu.test(directURL)) continue
    const url = safeExternalURL(directURL)
    if (!url || /(^|\.)sogou\.com$/iu.test(url.hostname)) continue
    const title = stripHTML(heading)
    const summaryHTML = block.match(/<div\b[^>]*class=["'][^"']*(?:text-layout|str_info)[^"']*["'][^>]*>([\s\S]*?)<\/div>/iu)?.[1]
      || block.match(/<p\b[^>]*class=["'][^"']*(?:fz-default|fz-mid|str_info)[^"']*["'][^>]*>([\s\S]*?)<\/p>/iu)?.[1]
      || ''
    const snippet = cleanWebExcerpt(stripHTML(summaryHTML))
    if (!title || !snippet) continue
    results.push({
      title,
      url: url.toString(),
      snippet,
      roles: [...new Set(roles)],
      searchProvider,
      publishedAt: webPublishedDate(block)
    })
  }
  return results
}

function selectSearchProviders(providers, requested) {
  const enabled = Array.isArray(requested) ? new Set(requested) : null
  return enabled ? providers.filter((provider) => enabled.has(provider.key)) : providers
}

function selectPreferredSources(requested) {
  const supported = new Set(['douban', 'xiaohongshu'])
  if (!Array.isArray(requested)) return supported
  return new Set(requested.filter((source) => supported.has(source)))
}

function htmlAttribute(html, name) {
  const escaped = String(name).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const match = String(html || '').match(new RegExp(`\\b${escaped}\\s*=\\s*(["'])([\\s\\S]*?)\\1`, 'iu'))
  return match?.[2] || ''
}

function stripHTML(value) {
  return decodeHTMLEntities(String(value || '')
    .replace(/<!--[\s\S]*?-->/gu, ' ')
    .replace(/<script\b[\s\S]*?<\/script>/giu, ' ')
    .replace(/<style\b[\s\S]*?<\/style>/giu, ' ')
    .replace(/<[^>]+>/gu, ' '))
    .replace(/\s+/gu, ' ')
    .trim()
}

function decodeHTMLEntities(value) {
  const named = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' }
  return String(value || '').replace(/&(#x?[0-9a-f]+|[a-z]+);/giu, (_match, entity) => {
    const normalized = entity.toLowerCase()
    if (normalized.startsWith('#x')) return String.fromCodePoint(Number.parseInt(normalized.slice(2), 16) || 32)
    if (normalized.startsWith('#')) return String.fromCodePoint(Number.parseInt(normalized.slice(1), 10) || 32)
    return named[normalized] ?? ' '
  })
}

function webPublishedDate(html) {
  const match = String(html || '').match(/((?:19|20)\d{2})[年/-](\d{1,2})[月/-](\d{1,2})日?/u)
  if (!match) return null
  return `${match[1]}-${match[2].padStart(2, '0')}-${match[3].padStart(2, '0')}`
}

function deduplicateWebCandidates(candidates) {
  const byURL = new Map()
  for (const candidate of candidates) {
    const url = safeExternalURL(candidate.url)
    if (!url) continue
    url.hash = ''
    const key = url.toString()
    const existing = byURL.get(key)
    if (!existing) {
      byURL.set(key, { ...candidate, url: key, searchProviders: [candidate.searchProvider].filter(Boolean) })
      continue
    }
    existing.roles = [...new Set([...existing.roles, ...candidate.roles])]
    existing.searchProviders = [...new Set([...(existing.searchProviders || []), candidate.searchProvider].filter(Boolean))]
    if (candidate.snippet.length > existing.snippet.length) existing.snippet = candidate.snippet
    existing.publishedAt ||= candidate.publishedAt
  }
  return [...byURL.values()]
}

function rankWebCandidates(candidates, song) {
  return deduplicateWebCandidates(candidates)
    .filter((candidate) => webCandidateMatchesSong(candidate, song))
    .map((candidate) => ({
      ...candidate,
      trust: candidate.trust || webSourceTrust(candidate.url),
      contentPlatform: candidate.contentPlatform || webContentPlatform(candidate.url)
    }))
    .sort((left, right) => {
      const gradeDifference = sourceGradeWeight(right.trust.grade) - sourceGradeWeight(left.trust.grade)
      if (gradeDifference) return gradeDifference
      const preferredDifference = Number(Boolean(right.contentPlatform)) - Number(Boolean(left.contentPlatform))
      if (preferredDifference) return preferredDifference
      const roleDifference = right.roles.length - left.roles.length
      if (roleDifference) return roleDifference
      return right.snippet.length - left.snippet.length
    })
}

function webCandidateMatchesSong(candidate, song) {
  return webTextMatchesSong(`${candidate.title}\n${candidate.snippet}`, song, candidate.roles)
}

function webTextMatchesSong(value, song, roles) {
  const haystack = comparable(value)
  const artist = comparable(song.artists?.[0]?.name)
  const title = comparableBaseTitle(song.title)
  const album = comparable(song.album?.name)
  if (!haystack || !artist || !haystack.includes(artist)) return false

  const albumOnly = roles.includes('albumSummary') && !roles.includes('songSummary') && !roles.includes('creationStory')
  if (albumOnly) return Boolean(album && haystack.includes(album))
  if (!title || !haystack.includes(title)) return false
  if (title.length <= 2 && album) return haystack.includes(album)
  return true
}

function webSourceTrust(value) {
  const url = safeExternalURL(value)
  if (!url) return { grade: 'D', publisher: '网页来源' }
  const hostname = url.hostname.toLowerCase().replace(/^www\./u, '')
  const publishers = [
    ['music.163.com', '网易云音乐'],
    ['y.qq.com', 'QQ音乐'],
    ['kugou.com', '酷狗音乐'],
    ['music.apple.com', 'Apple Music'],
    ['baike.baidu.com', '百度百科'],
    ['wikipedia.org', '维基百科'],
    ['musicbrainz.org', 'MusicBrainz'],
    ['billboard.com', 'Billboard'],
    ['rollingstone.com', 'Rolling Stone'],
    ['pitchfork.com', 'Pitchfork'],
    ['grammy.com', 'GRAMMY'],
    ['npr.org', 'NPR'],
    ['allmusic.com', 'AllMusic'],
    ['douban.com', '豆瓣'],
    ['xiaohongshu.com', '小红书'],
    ['people.com.cn', '人民网'],
    ['xinhuanet.com', '新华网'],
    ['chinanews.com.cn', '中国新闻网'],
    ['cnr.cn', '央广网'],
    ['cctv.com', '央视网'],
    ['thepaper.cn', '澎湃新闻'],
    ['jiemian.com', '界面新闻'],
    ['ifeng.com', '凤凰网'],
    ['sina.com.cn', '新浪'],
    ['sina.cn', '新浪'],
    ['sohu.com', '搜狐'],
    ['qq.com', '腾讯网'],
    ['163.com', '网易']
  ]
  const match = publishers.find(([domain]) => hostname === domain || hostname.endsWith(`.${domain}`))
  return match ? { grade: 'B', publisher: match[1] } : { grade: 'C', publisher: hostname }
}

function sourceGradeWeight(grade) {
  return ({ A: 4, B: 3, C: 2, D: 1 }[grade] || 0)
}

function webContentPlatform(value) {
  const url = safeExternalURL(value)
  if (!url) return null
  const hostname = url.hostname.toLowerCase().replace(/^www\./u, '')
  if (hostname === 'douban.com' || hostname.endsWith('.douban.com')) return 'douban'
  if (hostname === 'xiaohongshu.com' || hostname.endsWith('.xiaohongshu.com')) return 'xiaohongshu'
  return null
}

function selectBalancedWebCandidates(candidates, maximum) {
  const selected = []
  const seen = new Set()
  for (const role of ['songSummary', 'creationStory', 'background', 'albumSummary']) {
    const candidate = candidates.find((item) => candidateRoles(item).includes(role) && !seen.has(item.url))
    if (!candidate) continue
    selected.push(candidate)
    seen.add(candidate.url)
  }
  for (const candidate of candidates) {
    if (selected.length >= maximum) break
    if (seen.has(candidate.url)) continue
    selected.push(candidate)
    seen.add(candidate.url)
  }
  return selected
}

function candidateRoles(candidate) {
  if (Array.isArray(candidate?.metadata?.contentRoles)) return candidate.metadata.contentRoles
  return Array.isArray(candidate?.roles) ? candidate.roles : []
}

function extractArticleText(html) {
  const value = String(html || '')
  const values = []
  const documentTitle = value.match(/<title\b[^>]*>([\s\S]*?)<\/title>/iu)?.[1]
  if (documentTitle) values.push(stripHTML(documentTitle))
  const metaDescription = value.match(/<meta\b[^>]*(?:name|property)=["'](?:description|og:description)["'][^>]*content=["']([\s\S]*?)["'][^>]*>/iu)?.[1]
    || value.match(/<meta\b[^>]*content=["']([\s\S]*?)["'][^>]*(?:name|property)=["'](?:description|og:description)["'][^>]*>/iu)?.[1]
  if (metaDescription) values.push(stripHTML(metaDescription))

  for (const match of value.matchAll(/<script\b[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/giu)) {
    try {
      collectArticleBodies(JSON.parse(decodeHTMLEntities(match[1])), values)
    } catch (_) {}
  }

  const article = value.match(/<article\b[^>]*>([\s\S]*?)<\/article>/iu)?.[1]
  const main = value.match(/<main\b[^>]*>([\s\S]*?)<\/main>/iu)?.[1]
  if (article || main) values.push(stripHTML(article || main))

  if (values.join('').length < 800) {
    const paragraphs = [...value.matchAll(/<p\b[^>]*>([\s\S]*?)<\/p>/giu)]
      .map((match) => stripHTML(match[1]))
      .filter((paragraph) => paragraph.length >= 30)
      .slice(0, 40)
    values.push(...paragraphs)
  }
  return cleanWebExcerpt([...new Set(values.filter(Boolean))].join('\n'))
}

function collectArticleBodies(value, output) {
  if (!value) return
  if (Array.isArray(value)) {
    for (const item of value) collectArticleBodies(item, output)
    return
  }
  if (typeof value !== 'object') return
  if (typeof value.articleBody === 'string') output.push(value.articleBody)
  if (typeof value.description === 'string' && /article|review|news/iu.test(String(value['@type'] || ''))) output.push(value.description)
  for (const item of Object.values(value)) collectArticleBodies(item, output)
}

function cleanWebExcerpt(value) {
  return String(value || '')
    .normalize('NFKC')
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/gu, ' ')
    .replace(/(?:ignore|disregard)\s+(?:all|any|the)?\s*(?:previous|above|prior)\s+instructions?/giu, ' ')
    .replace(/(?:忽略|无视)(?:以上|此前|之前|所有)?(?:指令|提示词|要求)/gu, ' ')
    .replace(/[ \t]+/gu, ' ')
    .replace(/\n{3,}/gu, '\n\n')
    .trim()
    .slice(0, 6_000)
}

function webSourceType(roles) {
  if (roles.length > 1) return 'web_music_editorial'
  if (roles.includes('creationStory')) return 'web_creation_story'
  if (roles.includes('background')) return 'web_music_review'
  if (roles.includes('albumSummary')) return 'web_album_profile'
  return 'web_song_profile'
}

function analyzeContentRoles(seedRoles, value, song, { platformSource = false } = {}) {
  const seeds = new Set(Array.isArray(seedRoles) ? seedRoles : [])
  const text = String(value || '')
  const normalized = comparable(text)
  const title = comparableBaseTitle(song.title)
  const artist = comparable(song.artists?.[0]?.name)
  const album = comparable(song.album?.name)
  const titleMatched = Boolean(title && normalized.includes(title))
  const artistMatched = Boolean(artist && normalized.includes(artist))
  const albumMatched = Boolean(album && normalized.includes(album))
  const explicitReviewEvidence = /乐评|赏析|解析|评论|评价|听感|音乐分析|声音设计|配器|和声|音色|唱腔|制作水准/iu.test(text)
  const musicalObservationCount = new Set(
    text.match(/氛围|情绪|叙事|主题|表达|旋律|节奏|编曲|演唱|风格|制作/giu) || []
  ).size
  const confidence = {}
  const evidence = {}

  function score(role, checks) {
    let value = platformSource && seeds.has(role) ? 0.24 : 0
    const reasons = []
    if (platformSource && seeds.has(role)) reasons.push('平台歌曲资料')
    if (!platformSource && seeds.has(role)) {
      value += 0.08
      reasons.push('定向检索命中')
    }
    for (const [passed, weight, reason] of checks) {
      if (!passed) continue
      value += weight
      reasons.push(reason)
    }
    confidence[role] = Math.min(1, Number(value.toFixed(2)))
    evidence[role] = reasons
  }

  score('songSummary', [
    [titleMatched, 0.2, '正文匹配歌曲名'],
    [artistMatched, 0.12, '正文匹配歌手'],
    [/歌曲|单曲|作品|演唱|发行|发布|收录|主题曲|片尾曲|主打|歌词|曲目/iu.test(text), 0.28, '包含歌曲介绍信息'],
    [/作词|作曲|编曲|制作人|唱片公司|发行时间|所属专辑/iu.test(text), 0.16, '包含作品资料'],
    [text.length >= 240, 0.08, '正文信息量充足']
  ])
  score('creationStory', [
    [titleMatched, 0.12, '正文匹配歌曲名'],
    [artistMatched, 0.08, '正文匹配歌手'],
    [/创作|灵感|构思|写下|写作|诞生|由来|幕后|采访|自述|回忆|制作过程|录制过程/iu.test(text), 0.38, '包含创作过程'],
    [/作词|作曲|制作人|编曲者|录音|填词|谱曲|词曲/iu.test(text), 0.2, '包含创作人员或制作资料'],
    [text.length >= 320, 0.08, '正文信息量充足']
  ])
  score('background', [
    [titleMatched || albumMatched, 0.12, '正文匹配作品'],
    [artistMatched, 0.08, '正文匹配歌手'],
    [explicitReviewEvidence, 0.38, '包含明确评论或音乐分析'],
    [musicalObservationCount >= 3, 0.28, '包含多项音乐观察'],
    [text.length >= 400, 0.1, '评论正文信息量充足']
  ])
  score('albumSummary', [
    [albumMatched, 0.25, '正文匹配专辑名'],
    [artistMatched, 0.08, '正文匹配歌手'],
    [/专辑|唱片|曲目|发行|收录|概念专辑|录音室专辑|EP|音乐企划/iu.test(text), 0.32, '包含专辑资料'],
    [/制作|主题|概念|风格|时期|发行时间|唱片公司/iu.test(text), 0.16, '包含专辑背景'],
    [text.length >= 320, 0.08, '正文信息量充足']
  ])

  const thresholds = { songSummary: 0.58, creationStory: 0.58, background: 0.6, albumSummary: 0.6 }
  const roles = Object.keys(thresholds).filter((role) => {
    if (confidence[role] < thresholds[role]) return false
    if (role === 'background' && !explicitReviewEvidence && musicalObservationCount < 3) return false
    return true
  })
  return {
    roles,
    confidence: Object.fromEntries(roles.map((role) => [role, confidence[role]])),
    evidence: Object.fromEntries(roles.map((role) => [role, evidence[role]]))
  }
}

function safeExternalURL(value) {
  try {
    const url = value instanceof URL ? new URL(value) : new URL(String(value || ''))
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) return null
    const hostname = url.hostname.toLowerCase().replace(/\.$/u, '')
    if (!hostname || hostname === 'localhost' || hostname.endsWith('.local') || hostname.includes(':')) return null
    if (/^\d+(?:\.\d+){3}$/u.test(hostname)) return null
    return url
  } catch (_) {
    return null
  }
}

function deduplicateSources(sources) {
  const byURL = new Map()
  for (const source of sources) {
    const url = safeExternalURL(source?.url)
    if (!url) continue
    url.hash = ''
    const key = url.toString()
    if (!byURL.has(key)) byURL.set(key, { ...source, url: key })
  }
  return [...byURL.values()]
}

function comparableBaseTitle(value) {
  return comparable(String(value || '')
    .normalize('NFKC')
    .replace(/[([]\s*(?:live|现场(?:版)?|remaster(?:ed)?|重制(?:版)?|伴奏|instrumental|sped\s*up|加速(?:版)?)\s*[)\]]/giu, ' ')
    .replace(/\s*[-–—]\s*(?:live|现场(?:版)?|remaster(?:ed)?|重制(?:版)?|伴奏|instrumental|sped\s*up|加速(?:版)?)\s*$/giu, ' '))
}

function strictTitleMatch(targetTitle, candidateTitle, targetAlbum, candidateAlbum, durationDelta) {
  if (comparable(targetTitle) === comparable(candidateTitle)) return true
  return Boolean(
    comparableBaseTitle(targetTitle) &&
    comparableBaseTitle(targetTitle) === comparableBaseTitle(candidateTitle) &&
    targetAlbum &&
    targetAlbum === candidateAlbum &&
    durationDelta !== null &&
    durationDelta <= 5_000
  )
}

function finiteNumber(value) {
  const number = Number(value)
  return Number.isFinite(number) ? number : null
}

function httpURL(value) {
  try {
    const url = new URL(value)
    return ['http:', 'https:'].includes(url.protocol) ? url.toString() : null
  } catch (_) {
    return null
  }
}

module.exports = {
  analyzeContentRoles,
  createTokenSongContentAdapters,
  parseBaiduSearchResults
}
