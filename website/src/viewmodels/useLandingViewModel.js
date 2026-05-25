import { computed, onMounted, onUnmounted, ref } from 'vue'
import { assets, siteContent } from '../models/siteModel'

export function useLandingViewModel() {
  const contactCopied = ref(false)
  const showContactDialog = ref(false)
  const tokenQueryInput = ref('')
  const tokenQueryLoading = ref(false)
  const tokenQueryError = ref('')
  const tokenQueryMessage = ref('')
  const tokenResults = ref([])
  const copiedTokenKey = ref('')
  const updatesLoading = ref(false)
  const updatesError = ref('')
  const updatesData = ref(null)
  const ipaReleasesLoading = ref(false)
  const ipaReleasesError = ref('')
  const ipaReleasesData = ref(null)
  const expandedUpdateIds = ref(new Set())
  const showHistoryUpdates = ref(false)
  const downloadTab = ref('token')
  const ipaRegisterName = ref('')
  const ipaRegisterEmail = ref('')
  const ipaRegisterProtectCode = ref('')
  const ipaRegisterSubmitting = ref(false)
  const ipaRegisterError = ref('')
  const ipaRegisterMessage = ref('')
  const ipaRegisterResult = ref(null)
  const testFlightInfo = ref(null)
  const testFlightLoading = ref(false)
  const testFlightCheckingEmail = ref(false)
  const testFlightSubmitting = ref(false)
  const testFlightTrialSubmitting = ref(false)
  const testFlightError = ref('')
  const testFlightMessage = ref('')
  const testFlightResult = ref(null)
  const testFlightDuplicateDialog = ref(null)
  const testFlightNoticeDialog = ref(null)
  const testFlightName = ref('')
  const testFlightEmail = ref('')
  const testFlightProtectCode = ref('')
  const miniPlayerAudio = ref(null)
  const miniPlayerTracks = ref([])
  const miniPlayerLoading = ref(false)
  const miniPlayerError = ref('')
  const miniPlayerLoaded = ref(false)
  const miniPlayerIndex = ref(0)
  const miniPlayerPlaying = ref(false)
  const miniPlayerExpanded = ref(false)
  const playShareLoading = ref(false)
  const playShareError = ref('')
  const playShare = ref(null)

  const currentPath = ref(window.location.pathname)

  const currentPage = computed(() => {
    const path = currentPath.value.replace(/\/+$/, '') || '/'

    if (path === '/token') return 'token'
    if (path === '/updates') return 'updates'
    if (path === '/download') return 'download'
    if (path === '/testflight') return 'testflight'
    if (path.startsWith('/play/')) return 'playShare'

    return 'home'
  })

  const latestUpdate = computed(() => updatesData.value?.latest ?? null)
  const historyUpdates = computed(() => {
    const releases = updatesData.value?.releases ?? []
    return releases.filter((release) => release.id !== latestUpdate.value?.id)
  })
  const latestIpaRelease = computed(() => ipaReleasesData.value?.latest ?? null)
  const historyIpaReleases = computed(() => {
    const releases = ipaReleasesData.value?.releases ?? []
    return releases.filter((release) => release.id !== latestIpaRelease.value?.id)
  })
  const miniPlayerTrack = computed(() => miniPlayerTracks.value[miniPlayerIndex.value] ?? null)
  const miniPlayerArtist = computed(() => {
    const track = miniPlayerTrack.value
    if (!track) return '正在准备'
    return track.artist || track.artistName || 'Mono'
  })
  const miniPlayerCover = computed(() => miniPlayerTrack.value?.cover || assets.pawIcon)

  onMounted(() => {
    fetchMiniPlayerTracks()

    if (currentPage.value === 'updates') {
      fetchUpdates()
    }
    if (currentPage.value === 'download') {
      fetchIpaReleases()
    }

    if (currentPage.value === 'testflight') {
      fetchTestFlightInfo()
    }
    if (currentPage.value === 'playShare') {
      fetchPlayShare()
    }

    window.addEventListener('popstate', handlePopState)
  })

  onUnmounted(() => {
    window.removeEventListener('popstate', handlePopState)
  })

  function handlePopState() {
    currentPath.value = window.location.pathname
    if (currentPage.value === 'updates') {
      fetchUpdates()
    }
    if (currentPage.value === 'download') {
      fetchIpaReleases()
    }
    if (currentPage.value === 'testflight') {
      fetchTestFlightInfo()
    }
    if (currentPage.value === 'playShare') {
      fetchPlayShare()
    }
  }

  function navigateTo(path, event) {
    if (event) {
      if (
        event.button !== 0 ||
        event.metaKey ||
        event.altKey ||
        event.ctrlKey ||
        event.shiftKey
      ) {
        return
      }
      event.preventDefault()
    }

    window.scrollTo({ top: 0, behavior: 'smooth' })
    window.history.pushState(null, '', path)
    currentPath.value = path

    if (path === '/updates') {
      fetchUpdates()
    }
    if (path === '/download') {
      fetchIpaReleases()
    }
    if (path === '/testflight') {
      fetchTestFlightInfo()
    }
    if (path.startsWith('/play/')) {
      fetchPlayShare()
    }
  }

  function openContactDialog() {
    showContactDialog.value = true
  }

  function copyWechatAndOpen() {
    const wechatId = siteContent.contact.value
    const copyTask = copyText(wechatId)

    contactCopied.value = true
    showContactDialog.value = true
    openWechatApp()

    copyTask.catch(() => {
      copyWithFallback(wechatId)
    })

    window.setTimeout(() => {
      contactCopied.value = false
    }, 2200)
  }

  function copyText(value) {
    if (navigator.clipboard?.writeText) {
      return navigator.clipboard.writeText(value)
    }

    copyWithFallback(value)
    return Promise.resolve()
  }

  function openWechatApp() {
    window.location.href = 'weixin://'
    window.setTimeout(() => {
      if (document.visibilityState !== 'hidden') {
        window.location.href = 'weixin://dl/scan'
      }
    }, 450)
  }

  function copyWithFallback(value) {
    const textarea = document.createElement('textarea')
    textarea.value = value
    textarea.setAttribute('readonly', '')
    textarea.style.position = 'fixed'
    textarea.style.opacity = '0'
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand('copy')
    textarea.remove()
  }

  function closeContactDialog() {
    showContactDialog.value = false
  }

  async function parseJsonResponse(response, fallbackMessage) {
    const contentType = response.headers.get('content-type') || ''
    if (!contentType.includes('application/json')) {
      throw new Error(fallbackMessage)
    }

    try {
      return await response.json()
    } catch {
      throw new Error(fallbackMessage)
    }
  }

  async function queryToken() {
    const query = tokenQueryInput.value.trim()
    if (!query) {
      tokenQueryError.value = '请输入邮箱、用户名或 Token。'
      tokenQueryMessage.value = ''
      tokenResults.value = []
      return
    }

    tokenQueryLoading.value = true
    tokenQueryError.value = ''
    tokenQueryMessage.value = ''

    try {
      const response = await fetch('/api/public/lookup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(tokenLookupBody(query)),
      })
      const payload = await parseJsonResponse(response, '查询失败，请稍后重试。')

      if (!response.ok) {
        throw new Error(payload.error || '查询失败，请稍后重试。')
      }

      tokenResults.value = Array.isArray(payload.tokens) ? payload.tokens : []
      tokenQueryMessage.value = tokenResults.value.length
        ? `找到 ${tokenResults.value.length} 个 Token。`
        : siteContent.tokenQuery.emptyMessage
    } catch (error) {
      tokenResults.value = []
      tokenQueryError.value = error.message || '网络错误，请稍后重试。'
    } finally {
      tokenQueryLoading.value = false
    }
  }

  async function fetchUpdates() {
    updatesLoading.value = true
    updatesError.value = ''

    try {
      const response = await fetch('/api/public/changelogs')
      const payload = await parseJsonResponse(response, '更新公告读取失败。')

      if (!response.ok) {
        throw new Error(payload.error || '更新公告读取失败。')
      }

      updatesData.value = payload
    } catch (error) {
      updatesError.value = error.message || '更新公告读取失败。'
    } finally {
      updatesLoading.value = false
    }
  }

  async function fetchIpaReleases() {
    ipaReleasesLoading.value = true
    ipaReleasesError.value = ''

    try {
      const response = await fetch('/api/public/ipa-releases')
      const payload = await parseJsonResponse(response, 'IPA 信息读取失败。')

      if (!response.ok) {
        throw new Error(payload.error || 'IPA 信息读取失败。')
      }

      ipaReleasesData.value = payload
    } catch (error) {
      ipaReleasesError.value = error.message || 'IPA 信息读取失败。'
    } finally {
      ipaReleasesLoading.value = false
    }
  }

  async function submitIpaRegister() {
    const name = ipaRegisterName.value.trim()
    const email = ipaRegisterEmail.value.trim()
    const protectCode = ipaRegisterProtectCode.value.trim()

    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      ipaRegisterError.value = '请输入有效的邮箱地址。'
      return
    }

    if (!name) {
      ipaRegisterError.value = '请输入用户名。'
      return
    }

    if (!protectCode) {
      ipaRegisterError.value = '请输入保护码。'
      return
    }

    ipaRegisterSubmitting.value = true
    ipaRegisterError.value = ''
    ipaRegisterMessage.value = ''
    ipaRegisterResult.value = null

    try {
      const response = await fetch('/api/public/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, name, protectCode }),
      })
      const payload = await parseJsonResponse(response, '领取失败，请稍后重试。')

      if (!response.ok) {
        throw new Error(payload.error || '领取失败，请稍后重试。')
      }

      ipaRegisterResult.value = payload.token
      ipaRegisterMessage.value = payload.exists
        ? '该邮箱已注册 Token，已为你找回。'
        : 'Token 创建成功，请妥善保存。'

      if (!ipaReleasesData.value) {
        await fetchIpaReleases()
      }
    } catch (error) {
      ipaRegisterError.value = error.message || '领取失败，请稍后重试。'
    } finally {
      ipaRegisterSubmitting.value = false
    }
  }

  function toggleUpdateLog(release) {
    const id = updateLogId(release)
    const next = new Set(expandedUpdateIds.value)

    if (next.has(id)) {
      next.delete(id)
    } else {
      next.add(id)
    }

    expandedUpdateIds.value = next
  }

  function isUpdateLogExpanded(release) {
    return expandedUpdateIds.value.has(updateLogId(release))
  }

  function updateLogId(release) {
    return String(release?.id || release?.version || release?.createdAt || '')
  }

  function toggleHistoryUpdates() {
    showHistoryUpdates.value = !showHistoryUpdates.value
  }

  async function fetchTestFlightInfo() {
    testFlightLoading.value = true
    testFlightError.value = ''

    try {
      const response = await fetch(`/api/public/tf/${encodeURIComponent(siteContent.testflight.slug)}`)
      const payload = await parseJsonResponse(response, 'TestFlight 信息读取失败。')

      if (!response.ok || !payload.success) {
        throw new Error(payload.message || 'TestFlight 信息读取失败。')
      }

      testFlightInfo.value = payload.data
    } catch (error) {
      testFlightError.value = error.message || 'TestFlight 信息读取失败。'
    } finally {
      testFlightLoading.value = false
    }
  }

  async function submitTestFlightInvite() {
    await submitTestFlightRequest(false)
  }

  async function submitTestFlightTrial() {
    await submitTestFlightRequest(true)
  }

  async function submitTestFlightRequest(isTrial) {
    const fullName = testFlightName.value.trim()
    const email = testFlightEmail.value.trim()
    const protectCode = testFlightProtectCode.value.trim()

    if (!fullName) {
      showTestFlightNotice({
        type: 'error',
        title: '申请失败',
        message: '请填写姓名。',
      })
      return
    }

    if (!email) {
      showTestFlightNotice({
        type: 'error',
        title: '申请失败',
        message: '请填写邮箱。',
      })
      return
    }

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      showTestFlightNotice({
        type: 'error',
        title: '申请失败',
        message: '邮箱格式不正确。',
      })
      return
    }

    if (!isTrial && !protectCode) {
      showTestFlightNotice({
        type: 'error',
        title: '申请失败',
        message: '请填写保护码。',
      })
      return
    }

    testFlightError.value = ''
    testFlightMessage.value = ''
    testFlightResult.value = null
    testFlightDuplicateDialog.value = null
    testFlightNoticeDialog.value = null

    if (!isTrial) {
      testFlightCheckingEmail.value = true
      try {
        const canSubmit = await checkTestFlightEmail(email)
        if (!canSubmit) return
      } catch (error) {
        showTestFlightNotice({
          type: 'error',
          title: '申请失败',
          message: error.message || '邮箱查重失败，请稍后重试。',
          email,
        })
        return
      } finally {
        testFlightCheckingEmail.value = false
      }
    }

    if (isTrial) {
      testFlightTrialSubmitting.value = true
    } else {
      testFlightSubmitting.value = true
    }

    try {
      const endpoint = isTrial ? 'join-trial' : 'join'
      const response = await fetch(`/api/public/tf/${encodeURIComponent(siteContent.testflight.slug)}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          full_name: fullName,
          email,
          protect_code: protectCode,
        }),
      })
      const payload = await parseJsonResponse(response, '提交失败，请稍后重试。')

      if (!response.ok || !payload.success) {
        if (isTestFlightDuplicatePayload(payload)) {
          showTestFlightDuplicate(payload.data || { email })
          return
        }
        if (isTestFlightTrialUsedPayload(payload)) {
          showTestFlightNotice({
            type: 'error',
            title: '已体验过一次',
            message: payload.message || '该邮箱已经体验过免保护码 1 小时体验，请使用保护码正式申请或更换邮箱。',
            email,
          })
          return
        }
        if (!isTrial && response.status === 403) {
          showTestFlightNotice({
            type: 'error',
            title: '保护码不可用',
            message: '请检查保护码是否填写正确；如果保护码次数已用完，可以重新购买后再申请。',
            email,
          })
          return
        }
        throw new Error(payload.message || '提交失败，请稍后重试。')
      }

      testFlightResult.value = payload.data
      testFlightMessage.value = payload.message || siteContent.testflight.successTitle
      showTestFlightNotice({
        type: 'success',
        title: isTrial ? '体验申请成功' : '邀请申请成功',
        message: payload.message || (isTrial ? '已获得 1 小时体验，请查收 TestFlight 邀请邮件。' : '邀请邮件将发送到你的 Apple ID 邮箱，请前往邮箱查看。'),
        email: payload.data?.email || email,
        canOpenMailbox: true,
        canQueryToken: false,
      })
    } catch (error) {
      showTestFlightNotice({
        type: 'error',
        title: '申请失败',
        message: error.message || '提交失败，请稍后重试。',
        email,
      })
    } finally {
      testFlightSubmitting.value = false
      testFlightTrialSubmitting.value = false
    }
  }

  async function checkTestFlightEmail(email) {
    const response = await fetch(`/api/public/tf/${encodeURIComponent(siteContent.testflight.slug)}/check-email`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email }),
    })
    const payload = await parseJsonResponse(response, '邮箱查重失败，请稍后重试。')

    if (!response.ok || !payload.success) {
      if (isTestFlightDuplicatePayload(payload)) {
        showTestFlightDuplicate(payload.data || { email })
        return false
      }

      throw new Error(payload.message || '邮箱查重失败，请稍后重试。')
    }

    if (payload.data?.already_in_group) {
      showTestFlightDuplicate(payload.data)
      return false
    }

    return true
  }

  function isTestFlightDuplicatePayload(payload) {
    return payload?.code === 'TF_EMAIL_ALREADY_IN_GROUP'
      || payload?.data?.already_in_group === true
  }

  function isTestFlightTrialUsedPayload(payload) {
    return payload?.code === 'TF_TRIAL_EMAIL_ALREADY_USED'
  }

  function showTestFlightDuplicate(data) {
    testFlightDuplicateDialog.value = {
      email: data?.email || testFlightEmail.value.trim(),
      groupName: data?.group_name || testFlightInfo.value?.group_name || 'TestFlight 测试组',
      appName: data?.app_name || testFlightInfo.value?.app_name || 'Mono',
    }
  }

  function closeTestFlightDuplicateDialog() {
    testFlightDuplicateDialog.value = null
  }

  function changeTestFlightEmail() {
    testFlightEmail.value = ''
    closeTestFlightDuplicateDialog()
  }

  function showTestFlightNotice({ type, title, message, email = '', canOpenMailbox = false, canQueryToken = false }) {
    testFlightNoticeDialog.value = {
      type,
      title,
      message,
      email,
      canOpenMailbox,
      canQueryToken,
    }
  }

  function closeTestFlightNoticeDialog() {
    testFlightNoticeDialog.value = null
  }

  function goToTokenQuery() {
    window.location.href = '/token'
  }

  function openMailboxForTestFlight(email = '') {
    const target = mailboxTargetForEmail(email || testFlightResult.value?.email || testFlightEmail.value)
    if (!target) return

    const appUrls = Array.isArray(target.appUrls) ? target.appUrls : (target.appUrl ? [target.appUrl] : [])
    if (appUrls.length) {
      openMailboxAppUrls(appUrls, target.webUrl)
      return
    }

    window.open(target.webUrl, '_blank', 'noreferrer')
  }

  function openMailboxAppUrls(appUrls, fallbackUrl) {
    if (appUrls.length === 1) {
      window.location.href = appUrls[0]
      window.setTimeout(() => {
        if (document.visibilityState !== 'hidden' && fallbackUrl) {
          window.location.href = fallbackUrl
        }
      }, 1200)
      return
    }

    let stopped = false
    const stop = () => {
      stopped = true
    }
    const stopWhenHidden = () => {
      if (document.visibilityState === 'hidden') {
        stopped = true
      }
    }
    window.addEventListener('pagehide', stop, { once: true })
    document.addEventListener('visibilitychange', stopWhenHidden, { once: true })

    appUrls.forEach((appUrl, index) => {
      window.setTimeout(() => {
        if (!stopped) {
          window.location.href = appUrl
        }
      }, index * 450)
    })

    window.setTimeout(() => {
      if (!stopped && fallbackUrl) {
        window.location.href = fallbackUrl
      }
    }, appUrls.length * 450 + 900)
  }

  function mailboxTargetForEmail(email) {
    const domain = String(email || '').split('@')[1]?.toLowerCase()
    if (!domain) return null

    const providers = [
      { domains: ['gmail.com', 'googlemail.com'], appUrl: 'googlegmail://', webUrl: 'https://mail.google.com/mail/u/0/#inbox' },
      { domains: ['outlook.com', 'hotmail.com', 'live.com', 'msn.com'], appUrl: 'ms-outlook://', webUrl: 'https://outlook.live.com/mail/' },
      { domains: ['qq.com', 'foxmail.com', 'vip.qq.com'], appUrls: ['qqmail://'], webUrl: 'https://mail.qq.com/' },
      { domains: ['163.com', '126.com', 'yeah.net'], appUrls: ['neteasemail://'], webUrl: domain === '126.com' ? 'https://mail.126.com/' : 'https://mail.163.com/' },
      { domains: ['icloud.com', 'me.com', 'mac.com'], appUrl: 'message://', webUrl: 'https://www.icloud.com/mail/' },
      { domains: ['yahoo.com', 'ymail.com'], appUrl: 'ymail://mail/', webUrl: 'https://mail.yahoo.com/' },
      { domains: ['sina.com', 'sina.cn'], appUrl: '', webUrl: 'https://mail.sina.com.cn/' },
      { domains: ['sohu.com'], appUrl: '', webUrl: 'https://mail.sohu.com/' },
    ]
    const match = providers.find(provider => provider.domains.includes(domain))

    return match || {
      appUrl: '',
      webUrl: `https://${domain}`,
    }
  }

  function isMobileBrowser() {
    return /iPhone|iPad|iPod|Android/i.test(navigator.userAgent || '')
  }

  async function fetchMiniPlayerTracks() {
    if (miniPlayerLoading.value || miniPlayerLoaded.value) return

    miniPlayerLoading.value = true
    miniPlayerError.value = ''

    try {
      const response = await fetch('/api/public/player/recommend')
      const payload = await parseJsonResponse(response, '今日推荐暂时不可用。')

      if (!response.ok || payload.success === false) {
        throw new Error('今日推荐暂时不可用。')
      }

      const tracks = normalizeMiniPlayerTracks(payload)
      if (!tracks.length) {
        throw new Error('今日暂无可播放推荐。')
      }

      miniPlayerTracks.value = tracks
      miniPlayerLoaded.value = true
      miniPlayerIndex.value = 0
    } catch (error) {
      miniPlayerError.value = error.message || '今日推荐暂时不可用。'
    } finally {
      miniPlayerLoading.value = false
    }
  }

  async function toggleMiniPlayer() {
    if (miniPlayerPlaying.value) {
      miniPlayerAudio.value?.pause()
      return
    }

    await playMiniPlayerTrack(miniPlayerIndex.value)
  }

  function toggleMiniPlayerPanel() {
    miniPlayerExpanded.value = !miniPlayerExpanded.value
    if (miniPlayerExpanded.value) {
      fetchMiniPlayerTracks()
    }
  }

  async function playMiniPlayerTrack(index) {
    if (!miniPlayerLoaded.value) {
      await fetchMiniPlayerTracks()
    }

    const track = miniPlayerTracks.value[index]
    if (!track) return

    miniPlayerError.value = ''

    try {
      const playableTrack = await ensureMiniPlayerTrackUrl(track, index)
      const audio = miniPlayerAudio.value
      if (!audio || !playableTrack.url) return

      if (audio.src !== playableTrack.url) {
        audio.src = playableTrack.url
      }

      await audio.play()
      miniPlayerIndex.value = index
      miniPlayerPlaying.value = true
      
      // Dynamic ambient feedback based on the cover of the playing track
      if (playableTrack.cover) {
        updateAmbientBackdropColor(playableTrack.cover)
      }
    } catch (error) {
      miniPlayerPlaying.value = false
      miniPlayerError.value = error.message || '播放失败，请稍后重试。'
    }
  }

  // Extract dominant color from cover to drive fluid ambient glows dynamically
  function updateAmbientBackdropColor(coverUrl) {
    if (!coverUrl) return
    const img = new Image()
    img.crossOrigin = 'anonymous'
    img.src = coverUrl
    img.onload = () => {
      try {
        const canvas = document.createElement('canvas')
        const ctx = canvas.getContext('2d')
        canvas.width = 10
        canvas.height = 10
        ctx.drawImage(img, 0, 0, 10, 10)
        const data = ctx.getImageData(0, 0, 10, 10).data
        
        let r = 0, g = 0, b = 0, count = 0
        for (let i = 0; i < data.length; i += 4) {
          // Skip extremely bright white or extremely dark black pixels to get pure hues
          const max = Math.max(data[i], data[i+1], data[i+2])
          const min = Math.min(data[i], data[i+1], data[i+2])
          if (max - min < 15 || max > 245 || max < 25) continue
          r += data[i]
          g += data[i+1]
          b += data[i+2]
          count++
        }
        
        if (count > 0) {
          r = Math.round(r / count)
          g = Math.round(g / count)
          b = Math.round(b / count)
          
          // Apply extracted color to dynamic CSS custom properties
          document.documentElement.style.setProperty('--ambient-rgb-1', `${r}, ${g}, ${b}`)
          // Shift hues slightly for glow 2 and 3 to create beautiful analog color dynamics
          document.documentElement.style.setProperty('--ambient-rgb-2', `${Math.min(r + 30, 255)}, ${Math.max(g - 20, 0)}, ${b}`)
          document.documentElement.style.setProperty('--ambient-rgb-3', `${r}, ${Math.min(g + 25, 255)}, ${Math.max(b - 30, 0)}`)
        } else {
          resetAmbientBackdropColor()
        }
      } catch (e) {
        resetAmbientBackdropColor()
      }
    }
    img.onerror = () => {
      resetAmbientBackdropColor()
    }
  }

  function resetAmbientBackdropColor() {
    document.documentElement.style.setProperty('--ambient-rgb-1', '255, 184, 108')
    document.documentElement.style.setProperty('--ambient-rgb-2', '248, 183, 15')
    document.documentElement.style.setProperty('--ambient-rgb-3', '255, 218, 123')
  }

  async function nextMiniPlayerTrack() {
    if (!miniPlayerTracks.value.length) return

    const nextIndex = (miniPlayerIndex.value + 1) % miniPlayerTracks.value.length
    miniPlayerIndex.value = nextIndex

    if (miniPlayerPlaying.value) {
      await playMiniPlayerTrack(nextIndex)
    }
  }

  function onMiniPlayerPlay() {
    miniPlayerPlaying.value = true
  }

  function onMiniPlayerPause() {
    miniPlayerPlaying.value = false
  }

  function onMiniPlayerError() {
    miniPlayerPlaying.value = false
    miniPlayerError.value = '当前歌曲暂时无法播放。'
  }

  async function ensureMiniPlayerTrackUrl(track, index) {
    if (track.url) return track
    if (!track.id) throw new Error('歌曲缺少播放信息。')

    const response = await fetch(`/api/public/player/url?id=${encodeURIComponent(track.id)}`)
    const payload = await parseJsonResponse(response, '当前歌曲暂时无法播放。')

    if (!response.ok || payload.success === false) {
      throw new Error('当前歌曲暂时无法播放。')
    }

    const url = payload.url
      || payload.data?.url
      || payload.data?.playUrl
      || payload.data?.[0]?.url
      || payload.track?.url
    if (!url) throw new Error('播放链接为空。')

    const updatedTrack = {
      ...track,
      url,
    }
    miniPlayerTracks.value.splice(index, 1, updatedTrack)
    return updatedTrack
  }

  async function fetchPlayShare() {
    const code = currentPath.value.split('/').filter(Boolean)[1]
    if (!code) {
      playShare.value = null
      playShareError.value = '分享链接不完整。'
      return
    }

    playShareLoading.value = true
    playShareError.value = ''

    try {
      const response = await fetch(`/api/public/play/${encodeURIComponent(code)}`)
      const payload = await parseJsonResponse(response, '分享读取失败。')
      if (!response.ok || payload.success === false) {
        throw new Error(payload.message || '分享不存在或已失效。')
      }
      playShare.value = payload.data || payload
    } catch (error) {
      playShare.value = null
      playShareError.value = error.message || '分享读取失败。'
    } finally {
      playShareLoading.value = false
    }
  }

  function playSharePlatformLabel(source) {
    switch (source) {
      case 'qqmusic':
        return 'QCM'
      case 'qishui':
        return 'QSM'
      case 'netease':
        return 'NCM'
      default:
        return 'Mono'
    }
  }

  function formatDuration(value) {
    const milliseconds = Number(value)
    if (!milliseconds) return ''
    const seconds = Math.round(milliseconds / 1000)
    const minutes = Math.floor(seconds / 60)
    const rest = seconds % 60
    return `${minutes}:${String(rest).padStart(2, '0')}`
  }

  function normalizeMiniPlayerTracks(payload) {
    const source = payload.tracks
      || payload.songs
      || payload.data?.tracks
      || payload.data?.songs
      || payload.data?.dailySongs
      || payload.data?.recommend
      || payload.result?.songs
      || []

    if (!Array.isArray(source)) return []

    return source.map((item) => {
      const artists = item.artists || item.ar || item.artist || []
      const artist = Array.isArray(artists)
        ? artists.map((value) => value.name || value).filter(Boolean).join(' / ')
        : artists
      const album = item.album || item.al || {}

      let rawCover = item.cover || item.coverUrl || item.picUrl || album.picUrl || album.coverUrl || ''
      if (rawCover && typeof rawCover === 'string' && rawCover.startsWith('http://')) {
        rawCover = rawCover.replace(/^http:\/\//, 'https://')
      }
      let rawUrl = item.url || item.playUrl || item.src || ''
      if (rawUrl && typeof rawUrl === 'string' && rawUrl.startsWith('http://')) {
        rawUrl = rawUrl.replace(/^http:\/\//, 'https://')
      }

      return {
        id: item.id || item.songId,
        name: item.name || item.title || '未命名歌曲',
        artist: item.artistName || artist || '未知艺人',
        cover: rawCover,
        url: rawUrl,
      }
    }).filter((track) => track.id || track.url)
  }

  async function copyTokenKey(tokenKey) {
    if (!tokenKey) return

    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(tokenKey)
      } else {
        copyWithFallback(tokenKey)
      }
    } catch {
      copyWithFallback(tokenKey)
    }

    copiedTokenKey.value = tokenKey
    window.setTimeout(() => {
      copiedTokenKey.value = ''
    }, 1800)
  }

  function tokenLookupBody(query) {
    if (query.includes('@')) {
      return { email: query }
    }

    if (/^[0-9a-f]{8}$/i.test(query) || /^[A-Za-z0-9_-]{16,}$/.test(query)) {
      return { tokenKey: query }
    }

    return { name: query }
  }

  function tokenStatusLabel(token) {
    if (!token.enabled) return '已停用'
    if (token.isExpired) return '已过期'
    return '可使用'
  }

  function tokenStatusClass(token) {
    if (!token.enabled) return 'is-disabled'
    if (token.isExpired) return 'is-expired'
    return 'is-active'
  }

  function formatDate(value) {
    if (!value) return '—'

    const date = new Date(value)
    if (Number.isNaN(date.getTime())) return '—'

    return date.toLocaleDateString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    })
  }

  function formatSize(value) {
    const bytes = Number(value)
    if (!bytes) return ''

    if (bytes >= 1024 * 1024) {
      return `${(bytes / 1024 / 1024).toFixed(1)} MB`
    }

    return `${Math.round(bytes / 1024)} KB`
  }

  function setDownloadTab(tab) {
    downloadTab.value = tab
  }

  return {
    assets,
    content: siteContent,
    currentPage,
    contactCopied,
    showContactDialog,
    tokenQueryInput,
    tokenQueryLoading,
    tokenQueryError,
    tokenQueryMessage,
    tokenResults,
    copiedTokenKey,
    updatesLoading,
    updatesError,
    latestUpdate,
    historyUpdates,
    ipaReleasesLoading,
    ipaReleasesError,
    latestIpaRelease,
    historyIpaReleases,
    expandedUpdateIds,
    showHistoryUpdates,
    downloadTab,
    ipaRegisterName,
    ipaRegisterEmail,
    ipaRegisterProtectCode,
    ipaRegisterSubmitting,
    ipaRegisterError,
    ipaRegisterMessage,
    ipaRegisterResult,
    testFlightInfo,
    testFlightLoading,
    testFlightCheckingEmail,
    testFlightSubmitting,
    testFlightTrialSubmitting,
    testFlightError,
    testFlightMessage,
    testFlightResult,
    testFlightDuplicateDialog,
    testFlightNoticeDialog,
    testFlightName,
    testFlightEmail,
    testFlightProtectCode,
    miniPlayerAudio,
    miniPlayerTracks,
    miniPlayerLoading,
    miniPlayerError,
    miniPlayerTrack,
    miniPlayerArtist,
    miniPlayerCover,
    miniPlayerPlaying,
    miniPlayerExpanded,
    playShareLoading,
    playShareError,
    playShare,
    openContactDialog,
    copyWechatAndOpen,
    closeContactDialog,
    queryToken,
    fetchUpdates,
    fetchIpaReleases,
    submitIpaRegister,
    toggleUpdateLog,
    isUpdateLogExpanded,
    toggleHistoryUpdates,
    setDownloadTab,
    fetchTestFlightInfo,
    submitTestFlightInvite,
    submitTestFlightTrial,
    closeTestFlightDuplicateDialog,
    changeTestFlightEmail,
    closeTestFlightNoticeDialog,
    goToTokenQuery,
    openMailboxForTestFlight,
    fetchMiniPlayerTracks,
    toggleMiniPlayer,
    toggleMiniPlayerPanel,
    nextMiniPlayerTrack,
    onMiniPlayerPlay,
    onMiniPlayerPause,
    onMiniPlayerError,
    fetchPlayShare,
    playSharePlatformLabel,
    copyTokenKey,
    tokenStatusLabel,
    tokenStatusClass,
    formatDate,
    formatDuration,
    formatSize,
    navigateTo,
    currentPath,
  }
}
