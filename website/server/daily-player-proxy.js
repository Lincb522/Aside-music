import http from 'node:http'
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const envFile = loadEnvFile()
const secrets = loadSecrets()
const port = Number(
  process.env.MONO_PLAYER_PROXY_PORT
    || envFile.MONO_PLAYER_PROXY_PORT
    || process.env.PORT
    || 3391
)
const musicBaseURL = stripTrailingSlash(
  process.env.MONO_PLAYER_API_BASE_URL
    || envFile.MONO_PLAYER_API_BASE_URL
    || process.env.API_BASE_URL
    || envFile.API_BASE_URL
    || secrets.API_BASE_URL
    || 'https://ncm.zijiu522.cn'
)
const playerToken = process.env.MONO_PLAYER_API_TOKEN
  || envFile.MONO_PLAYER_API_TOKEN
  || process.env.API_TOKEN
  || envFile.API_TOKEN
  || process.env.NCM_API_TOKEN
  || envFile.NCM_API_TOKEN
  || secrets.API_TOKEN
  || secrets.MONO_PLAYER_API_TOKEN
  || ''
const vipCookie = process.env.VIP_COOKIE
  || envFile.VIP_COOKIE
  || secrets.VIP_COOKIE
  || vipMusicUCookie(process.env.VIP_MUSIC_U || envFile.VIP_MUSIC_U || secrets.VIP_MUSIC_U)

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`)

    if (req.method !== 'GET') {
      sendJson(res, 405, { success: false, message: 'Method not allowed' })
      return
    }

    if (url.pathname === '/api/public/player/recommend') {
      const tracks = await fetchDailyTracks()
      sendJson(res, 200, { success: true, tracks })
      return
    }

    if (url.pathname === '/api/public/player/url') {
      const id = url.searchParams.get('id')
      if (!id) {
        sendJson(res, 400, { success: false, message: '缺少歌曲 ID' })
        return
      }

      const playUrl = await fetchPlayableUrl(id)
      sendJson(res, 200, { success: true, url: playUrl })
      return
    }

    sendJson(res, 404, { success: false, message: 'Not found' })
  } catch (error) {
    sendJson(res, 500, { success: false, message: error.message || '播放器服务暂不可用' })
  }
})

server.listen(port, '127.0.0.1', () => {
  console.log(`Mono daily player proxy listening on 127.0.0.1:${port}`)
})

async function fetchDailyTracks() {
  assertConfigured()
  const payload = await fetchMusicJson('/recommend/songs')
  const songs = payload.data?.dailySongs
    || payload.data?.songs
    || payload.recommend
    || payload.songs
    || []

  return songs.map(normalizeSong).filter((track) => track.id).slice(0, 30)
}

async function fetchPlayableUrl(id) {
  assertConfigured()
  const levels = ['jymaster', 'sky', 'jyeffect', 'hires', 'lossless', 'exhigh', 'standard']

  for (const level of levels) {
    try {
      const payload = await fetchMusicJson('/song/url/v1', { id, level })
      const item = Array.isArray(payload.data) ? payload.data[0] : null
      if (item?.url) return item.url
    } catch {}
  }

  throw new Error('当前歌曲暂时无法播放')
}

async function fetchMusicJson(pathname, params = {}) {
  const url = new URL(`${musicBaseURL}${pathname}`)
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      url.searchParams.set(key, String(value))
    }
  })
  if (playerToken) url.searchParams.set('token', playerToken)

  const response = await fetch(url, {
    headers: {
      Cookie: vipCookie,
      Accept: 'application/json',
    },
  })
  const payload = await response.json()

  if (!response.ok || (payload.code && payload.code !== 200)) {
    throw new Error(payload.message || payload.msg || '音乐服务请求失败')
  }

  return payload
}

function normalizeSong(song) {
  const album = song.al || song.album || {}
  const artists = song.ar || song.artists || song.artist || []
  const artist = Array.isArray(artists)
    ? artists.map((item) => item.name || item).filter(Boolean).join(' / ')
    : artists

  return {
    id: song.id,
    name: song.name || song.title || '未命名歌曲',
    artist: song.artistName || artist || '未知艺人',
    cover: song.cover || song.coverUrl || song.picUrl || album.picUrl || album.coverUrl || '',
  }
}

function assertConfigured() {
  if (!vipCookie) throw new Error('播放器服务未配置')
  if (!playerToken) throw new Error('播放器服务未配置')
}

function sendJson(res, status, payload) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  })
  res.end(JSON.stringify(payload))
}

function loadSecrets() {
  const candidates = [
    process.env.MONO_SECRETS_XCCONFIG,
    resolve(process.cwd(), 'Secrets.xcconfig'),
    resolve(process.cwd(), '../Secrets.xcconfig'),
    resolve(__dirname, '../../Secrets.xcconfig'),
  ].filter(Boolean)

  for (const candidate of candidates) {
    try {
      return parseXcconfig(readFileSync(candidate, 'utf8'))
    } catch {}
  }

  return {}
}

function loadEnvFile() {
  const candidates = [
    process.env.MONO_PLAYER_ENV_FILE,
    resolve(process.cwd(), '.env'),
    resolve(__dirname, '.env'),
  ].filter(Boolean)

  for (const candidate of candidates) {
    try {
      return parseEnv(readFileSync(candidate, 'utf8'))
    } catch {}
  }

  return {}
}

function parseXcconfig(content) {
  return content.split(/\r?\n/).reduce((result, line) => {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith('//') || trimmed.startsWith('#')) return result

    const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/)
    if (!match) return result

    result[match[1]] = match[2].trim().replace(/^['"]|['"]$/g, '')
    return result
  }, {})
}

function parseEnv(content) {
  return content.split(/\r?\n/).reduce((result, line) => {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith('#')) return result

    const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/)
    if (!match) return result

    result[match[1]] = match[2].trim().replace(/^['"]|['"]$/g, '')
    return result
  }, {})
}

function vipMusicUCookie(value) {
  return value ? `MUSIC_U=${value}` : ''
}

function stripTrailingSlash(value) {
  return String(value || '').replace(/\/+$/, '')
}
