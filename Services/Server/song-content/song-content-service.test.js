const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')

const { createSongContentService } = require('./song-content-service')

function metadata() {
  return {
    title: '测试歌曲',
    artists: [{ id: 'artist-1', name: '测试歌手' }],
    album: { id: 'album-1', name: '测试专辑' },
    durationMs: 180_000,
    releaseDate: null,
    versionLabel: 'original',
    coverUrl: null,
    identityStatus: 'confirmed',
    platformArtistId: 'artist-1',
    platformAlbumId: 'album-1',
    matchMethod: 'official_mapping',
    matchConfidence: 1
  }
}

test('服务器已有持久化内容时播放请求不会再次创建生成任务', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'song-content-service-'))
  const identity = { platform: 'NCM', platformSongId: '10001' }
  let generationCount = 0

  const service = createSongContentService({
    directory,
    startWorker: false,
    platformResolver: async () => metadata(),
    sourceCollector: async () => ({
      sources: [{
        url: 'https://example.com/test-song',
        title: '测试歌曲资料',
        publisher: '测试来源',
        fetchedAt: new Date().toISOString(),
        grade: 'B',
        excerpt: '《测试歌曲》由测试歌手演唱并发行，收录于测试专辑。',
        metadata: { contentRoles: ['songSummary'] }
      }]
    }),
    contentGenerator: async ({ evidencePackage }) => {
      generationCount += 1
      return {
        content: {
          song_summary: '《测试歌曲》由测试歌手演唱并发行，收录于测试专辑。',
          creation_story: null,
          background: null,
          album_summary: null,
          source_refs: {
            song_summary: [evidencePackage.sources[0].id],
            creation_story: [],
            background: [],
            album_summary: []
          },
          confidence: 'medium',
          risk_flags: []
        },
        usage: { input: 100, output: 100, cost: null }
      }
    }
  })

  try {
    const first = await service.ensureContent(identity, 'zh-Hans')
    assert.equal(first.content, null)
    assert.equal(first.generation?.status, 'generating')
    const queuedJobs = service.store.listJobs({ state: 'active' })
    assert.equal(queuedJobs.length, 1)
    assert.equal(queuedJobs[0].songTitle, '测试歌曲')
    assert.equal(queuedJobs[0].artistName, '测试歌手')
    assert.equal(queuedJobs[0].albumName, '测试专辑')
    assert.equal(queuedJobs[0].platform, 'NCM')
    assert.equal(queuedJobs[0].queuePosition, 1)
    assert.equal(service.store.countJobs({ state: 'queued' }), 1)
    assert.equal(service.store.jobStateCounts().active, 1)

    const result = await service.pipeline.runOnce('test-worker')
    assert.equal(result.ok, true)
    assert.equal(generationCount, 1)

    const published = await service.ensureContent(identity, 'zh-Hans')
    assert.equal(published.content?.status, 'published')
    assert.equal(published.generation, null)
    assert.equal(generationCount, 1)
  } finally {
    service.close()
  }

  let restartedGenerationCount = 0
  const restarted = createSongContentService({
    directory,
    startWorker: false,
    promptVersion: 'future-prompt-version',
    platformResolver: async () => {
      throw new Error('已保存的平台映射不应重新解析')
    },
    sourceCollector: async () => {
      throw new Error('已发布内容不应重新检索')
    },
    contentGenerator: async () => {
      restartedGenerationCount += 1
      throw new Error('已发布内容不应重新生成')
    }
  })

  try {
    const persisted = await restarted.ensureContent(identity, 'zh-Hans')
    assert.equal(persisted.content?.status, 'published')
    assert.equal(persisted.generation, null)
    assert.equal(restartedGenerationCount, 0)
    assert.equal(await restarted.pipeline.runOnce('restart-worker'), null)
  } finally {
    restarted.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
})
