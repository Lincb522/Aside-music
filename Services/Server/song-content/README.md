# Song Content Service

Persistent song identity, evidence, generated content, review, publication, remote configuration, and operations modules for the existing token server.

Agent 管理直接读写 App 现有的 `aiProviderConfig`。歌曲内容 Worker 复用相同协议、API 地址、模型、自定义请求头和密钥；生成策略与客户端灰度配置继续在 SQLite 中版本化。

配套交付：`openapi.yaml`、`DATA_DICTIONARY.md`、`IMPLEMENTATION_MATRIX.md`、`OPERATIONS.md`、`DEPLOYMENT_RECORD.md`、`TEST_REPORT.md`。

## Token server mount

The repository does not contain the token server's main Express entry point. Mount this module from that entry point after its body parser, admin authentication, token resolver, and rate-limit middleware are initialized:

```js
const path = require('node:path')
const { installTokenSongContent } = require('./token-admin/song-content-integration')

const songContent = installTokenSongContent({
  app,
  dataDirectory: DATA_DIRECTORY,
  adminUIRoot: path.join(__dirname, 'token-admin-ui', 'original'),
  authMiddleware,
  authorize: permission => requireAdminPermission(permission),
  resolvePublicToken,
  publicRateLimit: songContentRateLimit,
  platformResolver: resolvePlatformSong,
  sourceCollector: collectSongEvidence,
  appAIConfigProvider: () => loadData().aiProviderConfig,
  logger
})

process.once('SIGTERM', () => songContent.close())
```

`contentGenerator` is optional. When omitted, the worker reads the App AI configuration through `appAIConfigProvider`. `SONG_CONTENT_MASTER_KEY` remains required for the legacy encrypted credential compatibility endpoint.

## Required adapters

### Platform resolver

`platformResolver({ platform, platformSongId, requestContext })` must return trusted metadata. It must not merge recordings by title alone.

```js
{
  title: '歌曲名',
  artists: [{ id: 'artist-id', name: '歌手' }],
  album: { id: 'album-id', name: '专辑' },
  durationMs: 269000,
  releaseDate: { value: '2002-07', precision: 'month' },
  isrc: 'ISRC...',
  versionLabel: 'original',
  coverUrl: 'https://...',
  identityStatus: 'confirmed',
  matchMethod: 'official_mapping',
  matchConfidence: 1,
  rawMetadata: {}
}
```

Return `identityStatus: "provisional"` when a recording cannot be confirmed. Provisional or conflicting songs never enter AI generation.

### Evidence collector

`sourceCollector({ song, locale, schemaVersion })` returns platform descriptions and source excerpts. Store only controlled excerpts or hashes, not entire copyrighted pages.

```js
{
  platformSummary: '平台正式简介',
  albumSummary: '平台专辑简介',
  exclusions: ['同名歌曲或其他录音版本'],
  sources: [{
    url: 'https://...',
    title: '来源标题',
    publisher: '发布方',
    publishedAt: '2026-07-26T00:00:00Z',
    fetchedAt: '2026-07-26T00:00:00Z',
    grade: 'A',
    excerpt: '与当前歌曲直接相关的受控摘录'
  }]
}
```

## Routes

- `GET /api/public/song-content`
- `POST /api/public/song-content/ensure`
- `GET /api/public/song-content/jobs/:jobId`
- `GET /api/public/song-content-config`（歌曲内容模块、灰度策略及 App Agent 提示词与生成参数）
- `GET /api/public/announcements/manifest`（仅返回当前客户端适用的公告轻量清单，支持 ETag / 304）
- `GET /api/public/announcements/:id?revision=`（仅在发现未读展示版本后读取公告正文与展示资源）
- `/api/song-content/*` authenticated administration routes
- `/api/announcements/*` 公告草稿、发布、再次发布、下线与删除管理接口
- `POST /api/song-content/maintenance`（受 `jobs.manage` 权限保护的数据库检查、WAL checkpoint 与 optimize；`vacuum` 必须显式开启）
- `GET /agents` token Agent management page
- `GET /announcements` 通知、活动、维护、重要提醒、协议政策与版本更新发布页

The App first posts `platform`, `song_id`, `locale`, and a concrete song snapshot to the idempotent ensure route. The authenticated snapshot is stored only as the exact platform mapping fallback; NCM and QCM still resolve against their server-side official metadata adapters. Published responses use ETag and cache headers. Generating responses are short-lived and contain no draft text.

## Content guarantees

- One active generation job per canonical song, schema version, and locale.
- AI receives only the persisted evidence package for the selected recording.
- Every non-empty paragraph must reference stored sources.
- High-risk facts require one A-grade source or two independent B-grade publishers.
- Low-confidence, risky, conflicting, or template-like content enters review instead of automatic publication.
- Editing creates a new version; publication atomically changes the locale publication pointer.
- Provider credentials are AES-256-GCM encrypted and never returned by public routes.
- App Agent 配置覆盖音效调音、听歌洞察、每日问候、歌词舞台和壁纸搜索翻译；空提示词由 App 使用同版本内置值回退。
- 服务端内容生成提示词、凭据、预算、并发、限流和熔断策略不进入公开配置。

See [OPERATIONS.md](./OPERATIONS.md) before enabling a production rollout.
