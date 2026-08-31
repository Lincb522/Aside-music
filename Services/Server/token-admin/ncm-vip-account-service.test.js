const assert = require('node:assert/strict')
const test = require('node:test')

const {
  membershipMetadata,
  normalizeCookie,
  publicAccount
} = require('./ncm-vip-account-service')

test('normalizes a QR login cookie without forwarding Set-Cookie attributes', () => {
  const normalized = normalizeCookie(
    'MUSIC_U=session-value; Path=/; HttpOnly; __csrf=csrf-value; Max-Age=3600; SameSite=Lax'
  )
  assert.equal(normalized, 'MUSIC_U=session-value; __csrf=csrf-value')
})

test('rejects an anonymous cookie', () => {
  assert.equal(normalizeCookie('__csrf=value; Path=/'), null)
})

test('recognizes a current VIP account and preserves expiry metadata', () => {
  const expiry = Date.now() + 86_400_000
  const metadata = membershipMetadata(
    { vipType: 11 },
    { code: 200, data: { redVipLevel: 6, redVipExpireTime: expiry } }
  )
  assert.equal(metadata.isMember, true)
  assert.equal(metadata.membershipLevel, 'vip')
  assert.equal(metadata.redVipLevel, 6)
  assert.equal(metadata.expiresAt, new Date(expiry).toISOString())
})

test('does not accept expired membership metadata', () => {
  const metadata = membershipMetadata(
    { vipType: 11 },
    { code: 200, data: { redVipLevel: 6, redVipExpireTime: Date.now() - 60_000 } }
  )
  assert.equal(metadata.isMember, false)
  assert.equal(metadata.membershipLevel, 'none')
})

test('public account never includes encrypted credentials', () => {
  const account = publicAccount({
    id: 'account-id',
    userId: '10001',
    nickname: 'VIP',
    membershipLevel: 'vip',
    health: 'available',
    encryptedCookie: { ciphertext: 'secret' },
    createdAt: '2026-08-30T00:00:00.000Z',
    updatedAt: '2026-08-30T00:00:00.000Z'
  }, 'account-id')
  assert.equal(account.isActive, true)
  assert.equal(account.health, 'available')
  assert.equal('encryptedCookie' in account, false)
  assert.equal('cookie' in account, false)
})
