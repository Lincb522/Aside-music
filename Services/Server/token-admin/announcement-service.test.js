const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const test = require('node:test')
const { createAnnouncementService } = require('./announcement-service')

function makeService(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'mono-announcements-'))
  const service = createAnnouncementService({ databasePath: path.join(directory, 'content.sqlite') })
  t.after(() => {
    service.close()
    fs.rmSync(directory, { recursive: true, force: true })
  })
  return service
}

function announcementInput(overrides = {}) {
  return {
    title: '服务维护通知',
    summary: '维护期间部分在线功能暂停使用',
    body: '我们将在凌晨进行服务维护，完成后功能会自动恢复。',
    category: 'maintenance',
    priority: 'high',
    platforms: ['ios'],
    locales: ['zh-CN'],
    ...overrides
  }
}

test('清单只返回轻量元数据，正文通过指定展示版本按需获取', t => {
  const service = makeService(t)
  const draft = service.create(announcementInput())
  assert.equal(draft.status, 'draft')
  assert.equal(draft.displayRevision, 0)

  const published = service.publishAnnouncement(draft.id)
  assert.equal(published.status, 'published')
  assert.equal(published.displayRevision, 1)

  const context = { appVersion: '1.8.0', platform: 'ios', locale: 'zh-CN', now: new Date() }
  const manifest = service.publicManifest(context)
  assert.equal(manifest.items.length, 1)
  assert.equal(manifest.items[0].id, draft.id)
  assert.equal(manifest.items[0].displayRevision, 1)
  assert.equal(Object.hasOwn(manifest.items[0], 'body'), false)
  assert.equal(Object.hasOwn(manifest.items[0], 'imageURL'), false)

  const detail = service.publicDetail(draft.id, 1, context)
  assert.equal(detail.body, announcementInput().body)
  assert.equal(service.publicDetail(draft.id, 2, context), null)
})

test('再次发布提升展示版本，旧版本详情立即失效', t => {
  const service = makeService(t)
  const draft = service.create(announcementInput({ category: 'general' }))
  service.publishAnnouncement(draft.id)
  const republished = service.publishAnnouncement(draft.id)

  assert.equal(republished.displayRevision, 2)
  const context = { appVersion: '1.0.0', platform: 'ios', locale: 'zh-CN', now: new Date() }
  assert.equal(service.publicDetail(draft.id, 1, context), null)
  assert.equal(service.publicDetail(draft.id, 2, context)?.title, draft.title)
})

test('版本、平台、地区与生效时间共同限制公告清单', t => {
  const service = makeService(t)
  const draft = service.create(announcementInput({
    minAppVersion: '2.0.0',
    maxAppVersion: '2.9.9',
    platforms: ['ios'],
    locales: ['zh-CN'],
    startsAt: '2026-07-27T00:00:00.000Z',
    endsAt: '2026-07-29T00:00:00.000Z'
  }))
  service.publishAnnouncement(draft.id)

  const base = { appVersion: '2.4.0', platform: 'ios', locale: 'zh-CN', now: new Date('2026-07-28T00:00:00.000Z') }
  assert.equal(service.publicManifest(base).items.length, 1)
  assert.equal(service.publicManifest({ ...base, locale: 'zh-Hans-CN' }).items.length, 1)
  assert.equal(service.publicManifest({ ...base, appVersion: '1.9.9' }).items.length, 0)
  assert.equal(service.publicManifest({ ...base, platform: 'android' }).items.length, 0)
  assert.equal(service.publicManifest({ ...base, locale: 'en-US' }).items.length, 0)
  assert.equal(service.publicManifest({ ...base, now: new Date('2026-07-30T00:00:00.000Z') }).items.length, 0)
})

test('发布后必须先下线才能编辑或删除', t => {
  const service = makeService(t)
  const draft = service.create(announcementInput())
  service.publishAnnouncement(draft.id)
  assert.throws(() => service.updateDraft(draft.id, announcementInput({ title: '修改' })), /先下线/)
  assert.throws(() => service.deleteAnnouncement(draft.id), /先下线/)

  service.takeOffline(draft.id)
  const updated = service.updateDraft(draft.id, announcementInput({ title: '维护完成通知' }))
  assert.equal(updated.title, '维护完成通知')
  assert.equal(service.deleteAnnouncement(draft.id), true)
})
