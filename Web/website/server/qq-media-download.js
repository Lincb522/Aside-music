import https from 'node:https'
import { lookup } from 'node:dns/promises'
import { BlockList, isIP } from 'node:net'

const blocked = new BlockList()
for (const [address, prefix] of [
  ['0.0.0.0', 8], ['10.0.0.0', 8], ['100.64.0.0', 10], ['127.0.0.0', 8],
  ['169.254.0.0', 16], ['172.16.0.0', 12], ['192.0.0.0', 24], ['192.168.0.0', 16],
  ['192.0.2.0', 24], ['198.18.0.0', 15], ['198.51.100.0', 24], ['203.0.113.0', 24],
  ['224.0.0.0', 3],
]) blocked.addSubnet(address, prefix, 'ipv4')
blocked.addSubnet('2001:db8::', 32, 'ipv6')
const publicIPv6 = new BlockList()
publicIPv6.addSubnet('2000::', 3, 'ipv6')

export function validateQQMediaURL(value) {
  const url = new URL(value)
  const host = url.hostname.toLowerCase()
  if (!['https:', 'http:'].includes(url.protocol) || url.username || url.password || url.port
    || !(host === 'stream.qqmusic.qq.com' || host.endsWith('.stream.qqmusic.qq.com'))) {
    throw new Error('QCM 下载地址无效')
  }
  url.protocol = 'https:'
  return url
}

export function isPublicAddress(address) {
  const family = isIP(address)
  if (family === 4) return !blocked.check(address, 'ipv4')
  return family === 6 && publicIPv6.check(address, 'ipv6') && !blocked.check(address, 'ipv6')
}

export async function fetchQQMedia(value, { resolveHost = lookup, request = https.request, signal = AbortSignal.timeout(60_000) } = {}) {
  const maxBytes = 256 * 1024 * 1024
  let url = validateQQMediaURL(value)
  for (let redirects = 0; redirects <= 3; redirects += 1) {
    signal.throwIfAborted()
    let onAbort
    let addresses
    try {
      addresses = await Promise.race([
        resolveHost(url.hostname, { all: true }),
        new Promise((_, reject) => {
          onAbort = () => reject(signal.reason)
          signal.addEventListener('abort', onAbort, { once: true })
        }),
      ])
    } finally {
      if (onAbort) signal.removeEventListener('abort', onAbort)
    }
    signal.throwIfAborted()
    if (!addresses.length || addresses.some(({ address }) => !isPublicAddress(address))) {
      throw new Error('QCM 下载地址不可用')
    }
    const target = addresses[0]
    const result = await new Promise((resolve, reject) => {
      const req = request(url, {
        signal,
        // Pin the checked address so a second DNS answer cannot change the target.
        lookup(_host, options, callback) {
          if (options.all) callback(null, [target])
          else callback(null, target.address, target.family)
        },
      }, (response) => {
        response.on('error', reject)
        const status = response.statusCode || 0
        if ([301, 302, 303, 307, 308].includes(status)) {
          const location = response.headers.location
          response.destroy()
          if (!location) reject(new Error('QCM 下载重定向无效'))
          else resolve({ location })
          return
        }
        if (status !== 200 || Number(response.headers['content-length']) > maxBytes) {
          response.destroy()
          reject(new Error('QCM 文件下载失败'))
          return
        }
        let size = 0
        const chunks = []
        response.on('data', (chunk) => {
          size += chunk.length
          if (size > maxBytes) {
            response.destroy(new Error('QCM 文件超过下载限制'))
            return
          }
          chunks.push(chunk)
        })
        response.on('end', () => {
          if (size === 0) reject(new Error('QCM 文件为空'))
          else resolve({ data: Buffer.concat(chunks, size) })
        })
      })
      req.on('error', reject)
      req.end()
    })
    if (result.data) return result.data
    url = validateQQMediaURL(new URL(result.location, url))
  }
  throw new Error('QCM 下载重定向次数过多')
}
