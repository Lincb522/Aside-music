import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { once } from 'node:events'
import { mkdtemp, writeFile, rm } from 'node:fs/promises'
import http from 'node:http'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import test from 'node:test'

test('failed provider resolution never fetches a client-supplied URL', { timeout: 15_000 }, async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'mono-proxy-test-'))
  const empty = join(directory, 'empty.config')
  await writeFile(empty, '')
  let internalHits = 0
  const upstream = http.createServer((req, res) => {
    if (req.url === '/internal') internalHits += 1
    res.writeHead(200, { 'Content-Type': 'application/json' })
    res.end('{}')
  })
  upstream.listen(0, '127.0.0.1')
  await once(upstream, 'listening')
  const upstreamURL = `http://127.0.0.1:${upstream.address().port}`
  const child = spawn(process.execPath, [new URL('./daily-player-proxy.js', import.meta.url).pathname], {
    cwd: directory,
    env: {
      PATH: process.env.PATH,
      MONO_PLAYER_PROXY_PORT: '0',
      MONO_PLAYER_ENV_FILE: empty,
      MONO_SECRETS_XCCONFIG: empty,
      MONO_QQ_MUSIC_BASE_URL: upstreamURL,
      MONO_PLAY_SHARE_STORE: join(directory, 'shares.json'),
      MONO_FEEDBACK_STORE: join(directory, 'feedback.json'),
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  })
  t.after(async () => {
    const closed = once(child, 'exit')
    child.kill()
    await closed
    await new Promise((resolve) => upstream.close(resolve))
    await rm(directory, { recursive: true, force: true })
  })
  const port = await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('Proxy startup timeout')), 5000)
    child.stdout.on('data', (data) => {
      const match = data.toString().match(/listening on 127\.0\.0\.1:(\d+)/)
      if (match) { clearTimeout(timeout); resolve(match[1]) }
    })
    child.once('error', reject)
  })
  const base = `http://127.0.0.1:${port}`
  const created = await fetch(`${base}/api/public/play/shorten`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ source: 'qqmusic', qqMid: 'FixtureMID', url: `${upstreamURL}/internal` }),
  })
  assert.equal(created.status, 200)
  const { code } = await created.json()
  const download = await fetch(`${base}/api/public/play/${code}/download`)
  assert.equal(download.status, 500)
  assert.equal(internalHits, 0)
})
