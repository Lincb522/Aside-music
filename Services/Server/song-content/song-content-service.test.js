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
          song_summary: '《测试歌曲》由测试歌手演唱并发行，收录于测试专辑。作品以明确的旋律线索展开，并在段落推进中保持完整结构。歌曲与专辑的发行关系清楚，演唱者和收录信息均来自正式资料。其声音表达围绕作品本身展开，不借用平台标签或未经证实的创作传闻。作为专辑中的一首正式录音，它保留了该时期作品连续而克制的表达。开篇、发展与收束之间形成清楚的听觉路径，使歌曲在完整播放时呈现连续的叙事方向。这里记录的内容只用于验证持久化发布流程，并保持歌曲、歌手和专辑身份的一致关系。',
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
    assert.equal(service.store.countSongs(), 1)
    assert.equal(service.store.countSongs({ query: '测试歌手' }), 1)
    assert.equal(service.store.countSongs({ query: '不存在' }), 0)
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

test('任务重新排队后只计算新一次实际处理时间', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'song-content-job-timing-'))
  const service = createSongContentService({
    directory,
    startWorker: false,
    platformResolver: async () => metadata(),
    sourceCollector: async () => ({ sources: [] }),
    contentGenerator: async () => {
      throw new Error('本测试不会进入内容生成')
    }
  })

  try {
    await service.ensureContent({ platform: 'QCM', platformSongId: 'timing-test' }, 'zh-Hans')
    const queued = service.store.listJobs({ state: 'queued' })[0]
    const firstAttempt = service.store.leaseNextJob('timing-worker')
    assert.equal(firstAttempt.id, queued.id)
    assert.ok(firstAttempt.startedAt)

    const deferred = service.store.deferJob(firstAttempt.id, {
      errorCode: 'AI_RATE_LIMITED',
      errorMessage: '稍后继续',
      delaySeconds: 1
    })
    assert.equal(deferred.state, 'queued')
    assert.equal(deferred.startedAt, null)

    service.store.transitionJob(firstAttempt.id, 'queued', {
      availableAt: new Date(0).toISOString()
    })
    await new Promise((resolve) => setTimeout(resolve, 5))

    const secondAttempt = service.store.leaseNextJob('timing-worker')
    assert.ok(secondAttempt.startedAt)
    assert.ok(Date.parse(secondAttempt.startedAt) >= Date.parse(firstAttempt.startedAt))

    const completed = service.store.transitionJob(secondAttempt.id, 'completed')
    assert.ok(completed.durationMs >= 0)
    assert.ok(completed.durationMs < 1_000)
  } finally {
    service.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
})

test('已发布内容含平台内部字段时自动下线并创建升级任务', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'song-content-sanitize-'))
  const identity = { platform: 'NCM', platformSongId: 'unsafe-content' }
  const service = createSongContentService({
    directory,
    startWorker: false,
    platformResolver: async () => metadata(),
    sourceCollector: async () => ({ sources: [] }),
    contentGenerator: async () => {
      throw new Error('本测试不会进入内容生成')
    }
  })

  try {
    const song = await service.resolveSong(identity)
    const version = service.store.insertContentVersion({
      jobId: 'legacy-job',
      songId: song.id,
      locale: 'zh-CN',
      schemaVersion: '3',
      content: {
        songSummary: 'songTag\n曲风\norpheus://rnpage?component=rn-genre&tagId=1035',
        creationStory: null,
        background: null,
        albumSummary: null,
        sourceRefs: {},
        confidence: 'medium',
        riskFlags: []
      },
      validation: { passed: true, errors: [], warnings: [] },
      generation: {
        status: 'published',
        modelProvider: 'legacy',
        modelName: 'legacy',
        promptVersion: 'legacy',
        contentHash: 'legacy-unsafe-content'
      }
    })
    service.store.publishContentVersion(version.id)

    const response = await service.ensureContent(identity, 'zh-CN')
    assert.equal(response.content, null)
    assert.equal(response.generation?.status, 'generating')
    assert.equal(service.store.getPublishedDetail(song.id, 'zh-CN'), null)
    assert.equal(service.store.listJobs({ state: 'active' })[0]?.reason, 'content_upgrade')
  } finally {
    service.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
})
