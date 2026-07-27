const test = require('node:test')
const assert = require('node:assert/strict')

const { analyzeContentRoles, parseBaiduSearchResults } = require('./song-content-adapters')

const song = {
  title: '晴天',
  artists: [{ name: '周杰伦' }],
  album: { name: '叶惠美' }
}

test('检索目标不会直接变成歌曲介绍证据', () => {
  const analysis = analyzeContentRoles(
    ['songSummary'],
    '周杰伦在采访中回忆《晴天》的创作灵感，也谈到作曲、录音与制作过程。',
    song
  )

  assert.equal(analysis.roles.includes('songSummary'), false)
  assert.equal(analysis.roles.includes('creationStory'), true)
})

test('正文包含作品资料时确认歌曲介绍角色', () => {
  const analysis = analyzeContentRoles(
    ['songSummary'],
    '《晴天》是周杰伦演唱并发行的歌曲，收录于专辑《叶惠美》。作品由周杰伦作词、作曲，以校园记忆作为叙事主题。',
    song
  )

  assert.equal(analysis.roles.includes('songSummary'), true)
  assert.ok(analysis.confidence.songSummary >= 0.58)
  assert.ok(analysis.evidence.songSummary.length > 0)
})

test('乐评角色必须命中评论或音乐分析信息', () => {
  const analysis = analyzeContentRoles(
    ['background'],
    '《晴天》由周杰伦演唱并发行，收录于专辑《叶惠美》，页面列出了发行时间和唱片公司。',
    song
  )

  assert.equal(analysis.roles.includes('background'), false)
  assert.equal(analysis.roles.includes('songSummary'), true)
})

test('百度检索结果提取真实来源地址', () => {
  const html = `
    <div class="result c-container" mu="https://example.com/music-review">
      <h3><a href="https://www.baidu.com/link?url=redirect">晴天 - 音乐评论</a></h3>
      <div class="c-abstract">周杰伦《晴天》的旋律与编曲分析。</div>
    </div>`
  const results = parseBaiduSearchResults(html, ['background'])

  assert.equal(results.length, 1)
  assert.equal(results[0].url, 'https://example.com/music-review')
  assert.deepEqual(results[0].roles, ['background'])
})
