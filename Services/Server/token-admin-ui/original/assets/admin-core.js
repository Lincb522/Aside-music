(function () {
  const suffixes = [
    '/tokens',
    '/song-content',
    '/agents',
    '/agent-management',
    '/ipa',
    '/changelogs',
    '/announcements',
    '/downloads',
    '/protect-codes',
    '/bindings',
    '/index.html',
    '/tokens.html',
    '/song-content.html',
    '/ipa.html',
    '/changelogs.html',
    '/announcements.html',
    '/downloads.html',
    '/protect-codes.html',
    '/bindings.html'
  ]

  function resolveRoot() {
    const pathname = window.location.pathname
    const tokenDetailMatch = pathname.match(/^(.*)\/tokens\/[^/]+\/?$/)
    if (tokenDetailMatch) {
      return tokenDetailMatch[1] || ''
    }
    for (const suffix of suffixes) {
      if (pathname.endsWith(suffix)) {
        return pathname.slice(0, -suffix.length) || ''
      }
    }
    return pathname.endsWith('/') ? pathname.slice(0, -1) : pathname
  }

  const root = resolveRoot()
  let adminToken = localStorage.getItem('admin_token') || ''

  function href(path) {
    const normalized = path.startsWith('/') ? path : `/${path}`
    return `${root}${normalized}` || normalized
  }

  function setToken(value) {
    adminToken = value || ''
    if (adminToken) localStorage.setItem('admin_token', adminToken)
    else localStorage.removeItem('admin_token')
  }

  function esc(value) {
    const div = document.createElement('div')
    div.textContent = value ?? ''
    return div.innerHTML
  }

  function fmtDate(value) {
    if (!value) return '—'
    const date = new Date(value)
    if (Number.isNaN(date.getTime())) return '—'
    return date.toLocaleString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  function fmtNum(value) {
    const number = Number(value || 0)
    return new Intl.NumberFormat('zh-CN').format(number)
  }

  function fmtBytes(value) {
    const size = Number(value || 0)
    if (size <= 0) return '0 B'
    const units = ['B', 'KB', 'MB', 'GB']
    let index = 0
    let current = size
    while (current >= 1024 && index < units.length - 1) {
      current /= 1024
      index += 1
    }
    return `${current >= 100 ? current.toFixed(0) : current.toFixed(1)} ${units[index]}`
  }

  function nl2br(value) {
    return esc(value).replace(/\n/g, '<br>')
  }

  async function request(path, options = {}) {
    const auth = options.auth !== false
    const headers = { ...(options.headers || {}) }
    if (!headers['Content-Type'] && !(options.body instanceof Blob) && !(options.body instanceof ArrayBuffer)) {
      headers['Content-Type'] = 'application/json'
    }
    if (auth && adminToken) headers['X-Admin-Token'] = adminToken

    const response = await fetch(href(path), {
      ...options,
      headers
    })

    let data = null
    try {
      data = await response.json()
    } catch (_) {
      data = null
    }

    if (response.status === 401 && auth) {
      setToken('')
      if (window.location.pathname !== href('/')) {
        window.location.href = href('/')
      }
      throw new Error('未授权')
    }

    if (!response.ok) {
      throw new Error(data && data.error ? data.error : '请求失败')
    }
    return data
  }

  function notify(message, type = 'info') {
    const toast = document.getElementById('toast')
    if (!toast) return
    toast.textContent = message
    toast.className = `toast show ${type}`
    clearTimeout(window.__tokenAdminToast)
    window.__tokenAdminToast = setTimeout(() => {
      toast.className = 'toast'
    }, 2600)
  }

  function logout() {
    setToken('')
    window.location.href = href('/')
  }

  async function setupAuth(onReady) {
    const gate = document.getElementById('authGate')
    const app = document.getElementById('appShell')
    const input = document.getElementById('loginPassword')
    const button = document.getElementById('loginButton')
    const error = document.getElementById('loginError')

    async function enterApp() {
      if (gate) gate.classList.add('hidden')
      if (app) app.classList.remove('hidden')
      if (typeof onReady === 'function') await onReady()
    }

    function showGate() {
      if (app) app.classList.add('hidden')
      if (gate) gate.classList.remove('hidden')
    }

    async function login() {
      if (!input) return
      const password = input.value.trim()
      if (!password) {
        if (error) error.textContent = '请输入密码'
        return
      }

      try {
        if (error) error.textContent = ''
        if (button) button.disabled = true
        const result = await request('/api/auth/login', {
          method: 'POST',
          auth: false,
          body: JSON.stringify({ password })
        })
        setToken(result.token)
        await enterApp()
      } catch (err) {
        if (error) error.textContent = err.message || '登录失败'
      } finally {
        if (button) button.disabled = false
      }
    }

    if (button) button.addEventListener('click', login)
    if (input) {
      input.addEventListener('keydown', event => {
        if (event.key === 'Enter') login()
      })
    }

    if (!adminToken) {
      showGate()
      return
    }

    try {
      if (gate) gate.classList.add('hidden')
      if (app) app.classList.remove('hidden')
      if (typeof onReady === 'function') await onReady()
    } catch (_) {
      setToken('')
      showGate()
    }
  }

  window.TokenAdmin = {
    root,
    href,
    request,
    notify,
    logout,
    setupAuth,
    esc,
    fmtDate,
    fmtNum,
    fmtBytes,
    nl2br
  }
})()
