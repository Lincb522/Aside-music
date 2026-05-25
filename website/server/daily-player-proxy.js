import crypto from 'node:crypto'
import http from 'node:http'
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
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
const publicSiteBaseURL = stripTrailingSlash(
  process.env.MONO_PUBLIC_SITE_BASE_URL
    || envFile.MONO_PUBLIC_SITE_BASE_URL
    || 'https://mono.zijiu522.cn'
)
const shareStorePath = process.env.MONO_PLAY_SHARE_STORE
  || envFile.MONO_PLAY_SHARE_STORE
  || resolve(__dirname, '../.mono-play-shares.json')
const qqMusicBaseURL = stripTrailingSlash(
  process.env.MONO_QQ_MUSIC_BASE_URL
    || envFile.MONO_QQ_MUSIC_BASE_URL
    || process.env.QQ_MUSIC_BASE_URL
    || envFile.QQ_MUSIC_BASE_URL
    || secrets.QQ_MUSIC_BASE_URL
    || ''
)
const qishuiBaseURL = stripTrailingSlash(
  process.env.MONO_QISHUI_BASE_URL
    || envFile.MONO_QISHUI_BASE_URL
    || process.env.QISHUI_BASE_URL
    || envFile.QISHUI_BASE_URL
    || secrets.QISHUI_BASE_URL
    || (qqMusicBaseURL ? `${qqMusicBaseURL}/qishui` : '')
)
const qishuiSessionID = process.env.MONO_QISHUI_SESSION_ID
  || envFile.MONO_QISHUI_SESSION_ID
  || process.env.QISHUI_SESSION_ID
  || envFile.QISHUI_SESSION_ID
  || secrets.QISHUI_SESSION_ID
  || ''
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
const shareStore = loadShareStore()

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`)

    if (req.method === 'POST' && url.pathname === '/api/public/play/shorten') {
      const payload = await readJsonBody(req)
      const record = createShareRecord(payload)
      shareStore.records[record.code] = record
      saveShareStore()
      sendJson(res, 200, {
        success: true,
        code: record.code,
        url: `${publicSiteBaseURL}/play/${record.code}`,
        data: {
          code: record.code,
          url: `${publicSiteBaseURL}/play/${record.code}`,
        },
      })
      return
    }

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

    const shareMatch = url.pathname.match(/^\/api\/public\/play\/([A-Za-z0-9_-]+)$/)
    if (shareMatch) {
      const record = shareStore.records[shareMatch[1]]
      if (!record) {
        sendJson(res, 404, { success: false, message: '分享不存在或已失效' })
        return
      }
      sendJson(res, 200, { success: true, data: publicShareRecord(record) })
      return
    }

    const downloadMatch = url.pathname.match(/^\/api\/public\/play\/([A-Za-z0-9_-]+)\/download$/)
    if (downloadMatch) {
      const record = shareStore.records[downloadMatch[1]]
      if (!record) {
        sendJson(res, 404, { success: false, message: '分享不存在或已失效' })
        return
      }
      if (record.source === 'qqmusic') {
        await sendQQDecryptedDownload(res, record)
        return
      }
      const downloadUrl = await resolveDownloadUrl(record)
      sendRedirect(res, downloadUrl)
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

async function resolveDownloadUrl(record) {
  if (record.source === 'qqmusic') {
    return fetchQQDownloadUrl(record)
  }
  if (record.source === 'qishui') {
    return fetchQishuiDownloadUrl(record)
  }
  if (record.playUrl) return record.playUrl
  if (record.songId) return fetchPlayableUrl(record.songId)
  throw new Error('下载链接不可用')
}

async function fetchQQDownloadUrl(record) {
  if (!qqMusicBaseURL) throw new Error('QCM 下载服务未配置')
  if (!record.qqMid) throw new Error('缺少 QCM 歌曲 MID')

  const fileTypes = qqQualityFallback(record.qqQualityRaw)
  for (const fileType of fileTypes) {
    try {
      const payload = await fetchQQJson('/song/get_song_urls', {
        mid: record.qqMid,
        file_type: fileType,
        _download: 1,
      })
      const url = extractPlayableUrl(payload)
      if (url) return url
    } catch {}
  }

  if (record.playUrl) return record.playUrl
  throw new Error('QCM 下载链接不可用')
}

async function sendQQDecryptedDownload(res, record) {
  const download = await fetchQQDownloadInfo(record)
  const response = await fetch(download.url)
  if (!response.ok) throw new Error('QCM 文件下载失败')

  const encrypted = Buffer.from(await response.arrayBuffer())
  const output = download.ekey
    ? qmcDecryptData(encrypted, download.ekey)
    : encrypted
  const extension = inferQQOutputExtension(download.url, download.fileType)
  const filename = contentDispositionFilename(`${record.name || 'Mono QCM'}.${extension}`)

  res.writeHead(200, {
    'Content-Type': extension === 'ogg' ? 'audio/ogg' : 'audio/flac',
    'Content-Length': output.length,
    'Content-Disposition': `attachment; filename*=UTF-8''${filename}`,
    'Cache-Control': 'no-store',
  })
  res.end(output)
}

async function fetchQQDownloadInfo(record) {
  if (!qqMusicBaseURL) throw new Error('QCM 下载服务未配置')
  if (!record.qqMid) throw new Error('缺少 QCM 歌曲 MID')

  const fileTypes = qqQualityFallback(record.qqQualityRaw)
  for (const fileType of fileTypes) {
    try {
      const payload = await fetchQQJson('/song/get_song_urls', {
        mid: record.qqMid,
        file_type: fileType,
        _download: 1,
      })
      const url = extractPlayableUrl(payload)
      if (url) {
        return {
          url,
          ekey: extractQQEKey(payload),
          fileType,
        }
      }
    } catch {}
  }

  if (record.playUrl) {
    return {
      url: record.playUrl,
      ekey: '',
      fileType: record.qqQualityRaw || '',
    }
  }
  throw new Error('QCM 下载链接不可用')
}

async function fetchQishuiDownloadUrl(record) {
  if (!qishuiBaseURL) throw new Error('QSM 下载服务未配置')
  if (!record.qishuiTrackId) throw new Error('缺少 QSM Track ID')

  const url = new URL(`${qishuiBaseURL}/play/${record.qishuiTrackId}`)
  url.searchParams.set('quality', record.qishuiQualityRaw || 'highest')
  url.searchParams.set('_download', '1')
  if (qishuiSessionID) url.searchParams.set('sessionid_ss', qishuiSessionID)
  return url.toString()
}

async function fetchQQJson(pathname, params = {}) {
  const url = new URL(`${qqMusicBaseURL}${pathname}`)
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      url.searchParams.set(key, String(value))
    }
  })
  if (playerToken) url.searchParams.set('token', playerToken)

  const response = await fetch(url, { headers: { Accept: 'application/json' } })
  const payload = await response.json()
  if (!response.ok || (payload.code && payload.code !== 200)) {
    throw new Error(payload.message || payload.msg || 'QCM 服务请求失败')
  }
  return payload
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

function createShareRecord(payload) {
  const playUrl = sanitizeString(payload.url || payload.playUrl)
  const source = normalizeSource(payload.source)
  const songId = optionalNumber(payload.songId)
  const qqMid = sanitizeString(payload.qqMid)
  const qishuiTrackId = optionalNumber(payload.qishuiTrackId)

  if (!playUrl && !songId && !qqMid && !qishuiTrackId) {
    throw new Error('缺少播放信息')
  }

  const now = new Date().toISOString()
  return {
    code: createShareCode(),
    source,
    songId,
    name: sanitizeString(payload.name) || 'Mono 分享歌曲',
    artistName: sanitizeString(payload.artistName) || '未知艺人',
    albumName: sanitizeString(payload.albumName),
    coverUrl: normalizeHttpsURL(payload.coverUrl),
    duration: optionalNumber(payload.duration),
    playUrl,
    qqMid,
    qqQualityRaw: sanitizeString(payload.qqQualityRaw),
    qishuiTrackId,
    qishuiQualityRaw: sanitizeString(payload.qishuiQualityRaw),
    createdAt: now,
  }
}

function publicShareRecord(record) {
  return {
    code: record.code,
    source: record.source,
    songId: record.songId,
    name: record.name,
    artistName: record.artistName,
    albumName: record.albumName,
    coverUrl: record.coverUrl,
    duration: record.duration,
    createdAt: record.createdAt,
    downloadUrl: `/api/public/play/${encodeURIComponent(record.code)}/download`,
  }
}

function createShareCode() {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const code = crypto.randomBytes(6).toString('base64url')
    if (!shareStore.records[code]) return code
  }
  return crypto.randomUUID().replace(/-/g, '').slice(0, 12)
}

function normalizeSource(value) {
  const source = sanitizeString(value)
  if (['netease', 'qqmusic', 'qishui'].includes(source)) return source
  return 'netease'
}

function normalizeHttpsURL(value) {
  const url = sanitizeString(value)
  return url.startsWith('http://') ? url.replace(/^http:\/\//, 'https://') : url
}

function sanitizeString(value) {
  return typeof value === 'string' ? value.trim() : ''
}

function optionalNumber(value) {
  const number = Number(value)
  return Number.isFinite(number) && number > 0 ? number : undefined
}

function extractPlayableUrl(payload) {
  return payload.url
    || payload.playUrl
    || payload.data?.url
    || payload.data?.playUrl
    || payload.data?.[0]?.url
    || payload.urls?.[0]?.url
    || payload.result?.url
    || ''
}

function extractQQEKey(payload) {
  return payload.ekey
    || payload.eKey
    || payload.data?.ekey
    || payload.data?.eKey
    || payload.data?.[0]?.ekey
    || payload.data?.[0]?.eKey
    || payload.urls?.[0]?.ekey
    || payload.urls?.[0]?.eKey
    || payload.result?.ekey
    || payload.result?.eKey
    || ''
}

function inferQQOutputExtension(url, fileType) {
  const lower = `${url || ''} ${fileType || ''}`.toLowerCase()
  if (lower.includes('mgg') || lower.includes('ogg')) return 'ogg'
  return 'flac'
}

function contentDispositionFilename(value) {
  return encodeURIComponent(String(value || 'mono-download.flac').replace(/[\\/\r\n]/g, '_'))
}

function qqQualityFallback(qualityRaw) {
  const order = [
    'MASTER', 'ATMOS_2', 'ATMOS_51', 'FLAC', 'OGG_640', 'OGG_320',
    'MP3_320', 'OGG_192', 'ACC_192', 'MP3_128', 'OGG_96', 'ACC_96', 'ACC_48'
  ]
  const quality = sanitizeString(qualityRaw)
  const index = order.indexOf(quality)
  return index >= 0 ? order.slice(index) : order
}

function qmcDecryptData(data, ekey) {
  const key = parseQmcEKey(ekey)
  return key.length > 300
    ? qmcRC4Decrypt(data, key)
    : qmcMapDecrypt(data, key)
}

function parseQmcEKey(ekey) {
  const encV2Prefix = Buffer.from('QQMusic EncV2,Key:')
  const trimmed = String(ekey || '').replace(/\0+$/g, '')
  let ekeyBytes = Buffer.from(trimmed, 'base64')
  if (ekeyBytes.length < 8) throw new Error('QCM ekey 解析失败')

  if (ekeyBytes.subarray(0, encV2Prefix.length).equals(encV2Prefix)) {
    const stage1 = tcTeaDecrypt(
      ekeyBytes.subarray(encV2Prefix.length),
      Buffer.from('386ZJY!@#*$%^&)(')
    )
    const stage2 = tcTeaDecrypt(stage1, Buffer.from('**#!(#$%&^a1cZ,T'))
    ekeyBytes = Buffer.from(stage2.toString('utf8'), 'base64')
    if (ekeyBytes.length < 8) throw new Error('QCM ekey 解析失败')
  }

  const header = ekeyBytes.subarray(0, 8)
  const body = ekeyBytes.subarray(8)
  const teaKey = deriveQmcTeaKey(header)
  const decryptedBody = tcTeaDecrypt(body, teaKey)
  return Buffer.concat([header, decryptedBody])
}

function deriveQmcTeaKey(header) {
  const simpleKey = simpleMakeQmcKey(106, 8)
  const teaKey = Buffer.alloc(16)
  for (let i = 0; i < 16; i += 2) {
    teaKey[i] = simpleKey[i / 2]
    teaKey[i + 1] = header[i / 2]
  }
  return teaKey
}

function simpleMakeQmcKey(seed, size) {
  return Buffer.from(Array.from({ length: size }, (_, i) => {
    const value = seed + i * 0.1
    return Math.trunc(100.0 * Math.abs(Math.tan(value))) & 0xff
  }))
}

function tcTeaDecrypt(cipher, keyBytes) {
  if (keyBytes.length < 16 || cipher.length < 10 || cipher.length % 8 !== 0) {
    throw new Error('QCM TEA 解密失败')
  }

  const teaKey = [
    readBE32(keyBytes, 0),
    readBE32(keyBytes, 4),
    readBE32(keyBytes, 8),
    readBE32(keyBytes, 12),
  ]
  const plain = Buffer.alloc(cipher.length)
  let iv1 = 0n
  let iv2 = 0n

  for (let offset = 0; offset < cipher.length; offset += 8) {
    const cipherBlock = readBE64(cipher, offset)
    const result = cipherBlock ^ iv2
    const nextIv2 = teaECBDecrypt(result, teaKey)
    const plainBlock = nextIv2 ^ iv1
    writeBE64(plainBlock, plain, offset)
    iv1 = cipherBlock
    iv2 = nextIv2
  }

  const padSize = plain[0] & 0x07
  const startLoc = 1 + padSize + 2
  const endLoc = cipher.length - 7
  if (endLoc <= startLoc) throw new Error('QCM TEA 解密失败')

  for (let i = endLoc; i < plain.length; i += 1) {
    if (plain[i] !== 0) throw new Error('QCM TEA 解密失败')
  }
  return plain.subarray(startLoc, endLoc)
}

function teaECBDecrypt(block, key) {
  let y = Number((block >> 32n) & 0xffffffffn) >>> 0
  let z = Number(block & 0xffffffffn) >>> 0
  let sum = Math.imul(0x9e3779b9, 16) >>> 0

  for (let i = 0; i < 16; i += 1) {
    z = (z - ((((y << 4) >>> 0) + key[2] >>> 0) ^ ((sum + y) >>> 0) ^ (((y >>> 5) + key[3]) >>> 0))) >>> 0
    y = (y - ((((z << 4) >>> 0) + key[0] >>> 0) ^ ((sum + z) >>> 0) ^ (((z >>> 5) + key[1]) >>> 0))) >>> 0
    sum = (sum - 0x9e3779b9) >>> 0
  }

  return (BigInt(y) << 32n) | BigInt(z)
}

function readBE32(data, offset) {
  return (
    ((data[offset] << 24) >>> 0)
    | (data[offset + 1] << 16)
    | (data[offset + 2] << 8)
    | data[offset + 3]
  ) >>> 0
}

function readBE64(data, offset) {
  return (BigInt(readBE32(data, offset)) << 32n) | BigInt(readBE32(data, offset + 4))
}

function writeBE64(value, data, offset) {
  data[offset] = Number((value >> 56n) & 0xffn)
  data[offset + 1] = Number((value >> 48n) & 0xffn)
  data[offset + 2] = Number((value >> 40n) & 0xffn)
  data[offset + 3] = Number((value >> 32n) & 0xffn)
  data[offset + 4] = Number((value >> 24n) & 0xffn)
  data[offset + 5] = Number((value >> 16n) & 0xffn)
  data[offset + 6] = Number((value >> 8n) & 0xffn)
  data[offset + 7] = Number(value & 0xffn)
}

function qmcMapDecrypt(data, key) {
  const output = Buffer.from(data)
  const n = key.length
  for (let i = 0; i < output.length; i += 1) {
    let off = i
    if (off > 0x7fff) off %= 0x7fff
    const index = (off * off + 71214) % n
    const value = key[index]
    const rotation = (index + 4) & 0b111
    output[i] ^= ((value << rotation) | (value >> rotation)) & 0xff
  }
  return output
}

function qmcRC4Decrypt(data, key) {
  const output = Buffer.from(data)
  const n = key.length
  const s = Buffer.alloc(n)
  for (let i = 0; i < n; i += 1) s[i] = i & 0xff
  for (let i = 0, j = 0; i < n; i += 1) {
    j = (j + s[i] + key[i]) % n
    const tmp = s[i]
    s[i] = s[j]
    s[j] = tmp
  }
  const hash = calcQmcHashBase(key)
  decryptQmcRC4Range(output, 0, output.length, s, key, hash)
  return output
}

function decryptQmcRC4Range(buffer, start, count, s, key, hash) {
  const firstSegmentSize = 0x80
  const otherSegmentSize = 0x1400
  let off = start
  let remaining = count
  let cursor = 0

  if (off < firstSegmentSize) {
    const len = Math.min(remaining, firstSegmentSize - off)
    encodeQmcRC4First(buffer, cursor, len, off, key, hash)
    cursor += len
    remaining -= len
    off += len
  }

  const toAlign = off % otherSegmentSize
  if (toAlign !== 0) {
    const len = Math.min(remaining, otherSegmentSize - toAlign)
    encodeQmcRC4Other(buffer, cursor, len, off, s, key, hash)
    cursor += len
    remaining -= len
    off += len
  }

  while (remaining > otherSegmentSize) {
    encodeQmcRC4Other(buffer, cursor, otherSegmentSize, off, s, key, hash)
    cursor += otherSegmentSize
    remaining -= otherSegmentSize
    off += otherSegmentSize
  }

  if (remaining > 0) {
    encodeQmcRC4Other(buffer, cursor, remaining, off, s, key, hash)
  }
}

function encodeQmcRC4First(buffer, cursor, count, offset, key, hash) {
  const n = key.length
  for (let i = 0; i < count; i += 1) {
    const pos = offset + i
    const key1 = key[pos % n]
    const key2 = calcQmcSegmentKey(hash, pos, key1)
    buffer[cursor + i] ^= key[key2 % n]
  }
}

function encodeQmcRC4Other(buffer, cursor, count, offset, s, key, hash) {
  const n = key.length
  const segId = Math.floor(offset / 0x1400)
  const segIdSmall = segId & 0x1ff
  let discardCount = calcQmcSegmentKey(hash, segId, key[segIdSmall]) & 0x1ff
  discardCount += offset % 0x1400

  const sBox = Buffer.from(s)
  let j = 0
  let k = 0
  for (let i = 0; i < discardCount; i += 1) {
    j = (j + 1) % n
    k = (sBox[j] + k) % n
    const tmp = sBox[j]
    sBox[j] = sBox[k]
    sBox[k] = tmp
  }

  for (let i = 0; i < count; i += 1) {
    j = (j + 1) % n
    k = (sBox[j] + k) % n
    const tmp = sBox[j]
    sBox[j] = sBox[k]
    sBox[k] = tmp
    buffer[cursor + i] ^= sBox[(sBox[j] + sBox[k]) % n]
  }
}

function calcQmcSegmentKey(hash, id, seed) {
  return Math.trunc((hash / ((id + 1) * seed)) * 100.0)
}

function calcQmcHashBase(data) {
  let hash = 1
  for (const value of data) {
    if (value === 0) continue
    const next = Math.imul(hash, value) >>> 0
    if (next === 0 || next <= hash) break
    hash = next
  }
  return hash >>> 0
}

function loadShareStore() {
  try {
    if (existsSync(shareStorePath)) {
      const parsed = JSON.parse(readFileSync(shareStorePath, 'utf8'))
      if (parsed && typeof parsed === 'object' && parsed.records) return parsed
    }
  } catch {}
  return { records: {} }
}

function saveShareStore() {
  writeFileSync(shareStorePath, JSON.stringify(shareStore, null, 2))
}

async function readJsonBody(req) {
  const chunks = []
  for await (const chunk of req) {
    chunks.push(chunk)
    if (Buffer.concat(chunks).length > 64 * 1024) {
      throw new Error('请求体过大')
    }
  }
  if (!chunks.length) return {}
  return JSON.parse(Buffer.concat(chunks).toString('utf8'))
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

function sendRedirect(res, location) {
  res.writeHead(302, {
    Location: location,
    'Cache-Control': 'no-store',
  })
  res.end()
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
