const test = require('node:test')
const assert = require('node:assert/strict')
const { serverProviderUsageLimits } = require('./song-content-integration')

test('服务端队列保留请求间隔但不复用客户端日小时额度', () => {
  assert.deepEqual(serverProviderUsageLimits({
    dailyRequestLimit: 100,
    hourlyRequestLimit: 20,
    minimumRequestInterval: 15
  }), {
    dailyRequestLimit: 0,
    hourlyRequestLimit: 0,
    minimumRequestInterval: 15
  })
})
