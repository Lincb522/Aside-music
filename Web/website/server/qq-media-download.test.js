import assert from 'node:assert/strict'
import { EventEmitter } from 'node:events'
import { PassThrough } from 'node:stream'
import test from 'node:test'
import { fetchQQMedia, isPublicAddress, validateQQMediaURL } from './qq-media-download.js'

test('media URL policy rejects arbitrary hosts, credentials and ports', () => {
  for (const url of ['http://127.0.0.1/file', 'https://stream.qqmusic.qq.com.evil.invalid/file',
    'https://user@stream.qqmusic.qq.com/file', 'https://stream.qqmusic.qq.com:8443/file', 'file:///tmp/file']) {
    assert.throws(() => validateQQMediaURL(url))
  }
  assert.equal(validateQQMediaURL('http://dl.stream.qqmusic.qq.com/file').protocol, 'https:')
})

test('non-public DNS answers are rejected before requesting a media file', async () => {
  assert.equal(isPublicAddress('2606:4700:4700::1111'), true)
  for (const address of ['127.0.0.1', '10.0.0.1', '169.254.169.254', '::1', '::ffff:127.0.0.1', 'fc00::1', '2::1', '3::1', '2001:db8::1']) {
    assert.equal(isPublicAddress(address), false)
    await assert.rejects(fetchQQMedia('https://dl.stream.qqmusic.qq.com/file', {
      resolveHost: async () => [{ address, family: address.includes(':') ? 6 : 4 }],
      request() { assert.fail('A private address must never be requested') },
    }))
  }
})

function responseFixture(statusCode, headers, body = 'fLaC fixture') {
  let requests = 0
  return {
    get requests() { return requests },
    options: {
      resolveHost: async () => [{ address: '8.8.8.8', family: 4 }],
      request(_url, options, callback) {
        requests += 1
        options.lookup('ignored', {}, (error, address) => {
          assert.equal(error, null)
          assert.equal(address, '8.8.8.8')
        })
        const request = new EventEmitter()
        request.end = () => {
          const response = new PassThrough()
          response.statusCode = statusCode
          response.headers = headers
          callback(response)
          if (!response.destroyed) response.end(body)
        }
        return request
      },
    },
  }
}

test('redirect targets are checked before following them', async () => {
  const fixture = responseFixture(302, { location: 'http://127.0.0.1/private' })
  await assert.rejects(fetchQQMedia('https://dl.stream.qqmusic.qq.com/file', fixture.options))
  assert.equal(fixture.requests, 1)
})

test('HTTP errors, empty and oversized media are rejected', async () => {
  for (const fixture of [responseFixture(403, {}), responseFixture(200, {}, ''),
    responseFixture(200, { 'content-length': 300 * 1024 * 1024 })]) {
    await assert.rejects(fetchQQMedia('https://dl.stream.qqmusic.qq.com/file', fixture.options))
  }
})

test('checked CDN responses can still be downloaded', async () => {
  const fixture = responseFixture(200, {})
  const data = await fetchQQMedia('https://dl.stream.qqmusic.qq.com/file', fixture.options)
  assert.equal(data.toString(), 'fLaC fixture')
})

test('DNS lookup is included in the download deadline', async () => {
  const controller = new AbortController()
  const download = fetchQQMedia('https://dl.stream.qqmusic.qq.com/file', {
    signal: controller.signal,
    resolveHost: () => new Promise(() => {}),
    request() { assert.fail('An unresolved host must not be requested') },
  })
  controller.abort(new Error('fixture deadline'))
  await assert.rejects(download, /fixture deadline/)
})
