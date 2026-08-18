const test = require('node:test')
const assert = require('node:assert/strict')

const {
  containsInternalPayload,
  sanitizePublishedText,
  sanitizeWikiProse
} = require('./song-content-sanitizer')

test('识别音乐平台内部字段和跳转协议', () => {
  assert.equal(containsInternalPayload('songTag\n曲风\norpheus://rnpage?component=rn-genre&tagId=1035'), true)
  assert.equal(sanitizePublishedText('songBizTag\n推荐标签'), null)
})

test('百科清洗只保留自然语言正文', () => {
  const prose = '这首作品以舒缓的旋律承接叙事，主歌保持克制，副歌则逐步放大情绪，使整段表达显得自然而完整。'
  assert.equal(sanitizeWikiProse(prose), prose)
  assert.equal(sanitizeWikiProse('melody_style\n另类/独立-独立流行'), null)
  assert.equal(sanitizeWikiProse('orpheus://rnpage?component=rn-tag-detail&tagId=197123'), null)
})
