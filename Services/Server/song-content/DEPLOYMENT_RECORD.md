# 生产部署记录

- 服务：现有 PM2 `token-admin`
- 运行文件：`/www/wwwroot/token-admin/server.js`
- 本地监听：`127.0.0.1:3388`
- 外部入口：`https://ncm.zijiu522.cn/_admin/agents`
- 公共 API：`https://ncm.zijiu522.cn/api/public/song-content*`
- 数据库：`/www/wwwroot/token-admin/song-content/song-content.sqlite`
- 反向代理：Nginx 仅将歌曲内容公共路径和后台路径转发至现有 token-admin
- 部署前备份：`/www/backup/token-admin-before-song-content-20260726T064914Z`
- App Agent 配置部署前备份：`/www/backup/token-admin-before-app-agent-prompts-20260726T080718Z`
- App Agent 配置部署后数据库备份：`/www/backup/token-admin-after-app-agent-prompts-20260726T080718Z`
- 最终歌曲 Agent 部署前备份：`/www/backup/token-admin-before-final-song-agent-20260726T091913Z`
- 叙事内容 v2 代码部署前备份：`/www/backup/token-admin-before-song-content-narrative-20260726T120744Z`
- 叙事内容 v2 配置发布前数据库备份：`/www/backup/token-admin-song-content-config-v2-20260726T121313Z`
- 跨平台“音乐幕后”部署前备份：`/www/backup/token-admin-before-cross-platform-content-20260726T130614070Z`
- 回滚：恢复备份中的 `server.js`、公共资源和 Nginx 配置，重启现有 PM2 进程

部署原则：不创建新 PM2 服务，不新增公网端口，不覆盖原有混淆 AI 配置运行文件。

2026-07-26 已发布公开配置 schema 2 / 版本 4，包含五类 App Agent 的独立启停、App 内置系统提示词、提示词版本、用户模板、温度、输出 Token 和最低超时。歌曲内容通过真实性与来源覆盖检查后自动发布。原 `ai-remote-config.js` 部署后 SHA-256 保持为 `f7bbcf29c06920a5843464221bd9785759716116d1639509c9c2c4f18c86cf6c`。

2026-07-26 已发布公开配置版本 6：歌曲内容提示词升级为 `song-editor-v2`，默认输出上限 4000 tokens，单任务上限 12000 tokens。生产冒烟 QCM `000NQDjk4BA0W3` 四模块全部生成并自动发布，校验通过，重复请求未新建生成任务。

生产冒烟歌曲：QCM `000NQDjk4BA0W3`（《暗号》/ 周杰伦 / 《八度空间》），统一歌曲 ID `3e91d466-c27e-4fc2-b12e-30bec256f901`，已发布内容版本 `94b4a82c-b008-451f-b138-f80b5712cb1d`。四个正文模块均有来源，自动校验通过；第二次 ensure 返回同一版本且生成任务数不增加。

2026-07-26 已将歌曲内容资料采集扩展到 KCM、QSM 和 AM：非 NCM/QCM 歌曲按标题、歌手、专辑与时长严格映射到可验证的 QCM/NCM 官方资料；仅在专辑完全一致且时长误差不超过 5 秒时，允许去除 Live 等版本后缀后匹配。公开内容对缺少独立歌曲简介的歌曲使用已有“音乐幕后/专辑介绍”回退，并继承原来源引用，不新增无来源文案。

生产冒烟歌曲：KCM `0011705422C00D4FEFA7E22F343F886A`（《你的 (Live)》/ 汪苏泷 / 《有歌2024 第7期》），统一歌曲 ID `6adf1f6a-fc42-4195-9a29-f9dcc9404622`，已发布 `zh-Hans` 内容版本 `cf87a235-e9b6-4e00-9356-7aaaa6fd5a9a`。连续两次公共 API 请求均返回 200、四个正文模块、QQ 音乐来源，且 `generation` 均为 null。QSM 与 AM 使用《暗号》元数据的跨平台采集冒烟均取得 2 个官方来源。

2026-07-27 已部署联网检索版“音乐幕后”。部署前文件与数据库备份位于 `/www/backup/token-admin-before-web-retrieval-20260727T020410584Z`。服务端先按歌曲、歌手和专辑严格检索网页，再提取可访问页面正文；来源按 `songSummary`、`creationStory`、`background`（乐评）、`albumSummary` 标记内容角色。Agent 只能引用允许对应字段的 B 级及以上来源，多余的跨字段引用会被剔除，没有评论类来源时不生成乐评。

已发布 Agent 配置版本 15，提示词 `song-editor-web-v4`、内容 schema 3。生产冒烟 QCM `000NQDjk4BA0W3`（《暗号》）检索到 QQ 音乐与搜狐共 3 个来源，发布内容版本 `0bb3ced5-dfe7-4577-9a3e-305ba41ef47b`：歌曲介绍 207 字、乐评 469 字、创作故事 319 字、专辑介绍 319 字。连续两次公共 API 请求均返回 200、同一持久化版本且 `generation` 为 null。

2026-07-27 已将联网检索策略接入 Agent 管理前端和生成管线。管理页可设置联网检索开关与单任务网页来源上限，并在来源列表区分“平台资料 / 联网检索”、显示中文内容字段。配置草稿保存后，生成任务会读取已发布策略执行；默认开启，网页来源上限为 6，服务端限制范围为 1–10。部署前文件与数据库备份位于 `/www/backup/token-admin-before-web-retrieval-admin-ui-20260727T022700Z`，继续复用原 PM2 `token-admin` 与本地端口 3388。

2026-07-27 联网检索由单一 360 扩展为 360、Bing、搜狗三路并行，任一路失败不阻断其余来源；管理页可逐项启停，来源记录保存实际命中的检索服务。生产网络以《暗号》冒烟，360 命中搜狐、Bing 命中网易云音乐，搜狗候选未通过正文与可信度筛选而被正常丢弃。部署前文件与数据库备份位于 `/www/backup/token-admin-before-multi-search-20260727T023948Z`。

2026-07-27 新增豆瓣与小红书重点来源。两者通过已启用搜索服务做站内定向检索，只用于乐评和专辑相关证据；目标网页正文自身必须同时匹配歌曲与歌手，登录墙、空壳页和仅搜索摘要匹配的结果不入库。生产冒烟中豆瓣《暗号》页面通过校验，小红书返回的无关公开笔记被正确过滤。部署前文件与数据库备份位于 `/www/backup/token-admin-before-douban-xhs-20260727T024935Z`。

2026-07-27 修复 Agent 管理的字段差异、角色权限和内容空状态溢出：长文双列按容器换行，权限逐项折行，权限面板增加内边距并调整列宽。已发布配置版本 16，提示词 `song-editor-web-v5`；正文禁止“现有评论认为”“报道提到”“资料显示”以及平台名称转述，歌曲介绍和专辑介绍不得用平台标签定义作品。服务端校验发现来源转述腔会拒绝结果并自动重试。部署前文件与数据库备份位于 `/www/backup/token-admin-before-layout-prompt-v5-20260727T025858Z`。

多来源证据使《凄美地》首次 v5 重写超过原 12,000 Token 单任务上限，配置版本 17 将单任务总上限调整为 20,000，最大输出仍为 4,000。重试后已发布内容版本 `c70edead-5bb7-445e-b507-9f9542dffae0`，提示词 `song-editor-web-v5`，四个字段来源覆盖率 100%，校验无错误和警告，正文不含平台名或来源转述句式。配置调整前备份位于 `/www/backup/token-admin-before-config-v17-20260727T030336Z`。

2026-07-27 启用全自动内容审核并发布配置版本 18：生成结果有校验错误或警告时自动重试，不再创建待审核内容；高风险事实只有通过多来源覆盖校验才自动发布，证据不足时自动重试，耗尽次数后标记失败。人工发布或驳回会同步关联生成任务状态。历史 3 个 `review` 任务已按最终内容状态清理为 2 个完成、1 个失败。部署前备份位于 `/www/backup/token-admin-before-auto-review-20260727T040124Z`。

2026-07-27 已部署通用公告与 AI 熔断恢复更新。公告支持通知、活动、维护、重要提醒、协议政策和版本更新，管理端可配置优先级、展示版本、时间窗口、客户端版本、平台、地区、确认要求及跳转；App 公共接口采用轻量清单 ETag/304，并仅按未读展示版本读取详情。AI 熔断期间 Worker 不再领取新任务，恢复窗口到期后只允许一个半开探测；后台任务错误只返回中文展示信息，并可配置 15–900 秒恢复窗口。继续复用 PM2 `token-admin`、本地端口 3388 和 `/_admin/` 入口。数据库、运行文件、管理页与 Nginx 部署前备份位于 `/www/backup/token-admin-before-announcements-circuit-20260727T123718Z`；HTTPS 公告页面、清单接口、轻量字段约束、数据库 `quick_check`、后台错误中文化和熔断关闭状态均已冒烟通过。

2026-07-27 修复“音乐幕后”批量生成失败与来源操作列溢出。根因是内容 Worker 未遵守 App AI 的每日、每小时和最小请求间隔，连续请求触发上游 429；现已合并 App AI 用量限制、按 `Retry-After` 退避、限流不消耗任务重试次数，并将受限 Provider 串行调度。重试复用已保存的有效证据，旧来源缺少内容角色时重新采集并刷新元数据；模型返回空字段或抄错来源 ID 时，丢弃未知引用并使用同一证据包中的平台正式歌曲/专辑介绍兜底。来源表改为受控列宽，长标题省略显示，状态与“标记失效”操作始终保留在容器内。部署前备份位于 `/www/backup/token-admin-before-agent-rate-limit-layout-20260727T133143Z`；45 个可恢复任务已重新排队，生产验证《偏爱》《暗号》均生成发布成功，恢复后 12 条任务完成且无新增 `AI_RATE_LIMITED` 失败。

2026-07-27 已部署 Agent 上下文预算优化。单次输入与单任务总 Token 预算拆分管理，证据正文按字段角色和来源等级保留后自适应压缩，平台映射及来源元数据不再把无关原始字段送入模型；遗漏字段补全只携带对应角色的来源和精简后的已有内容，不再重复提交整份证据。首轮有效结果即使超过总任务预算也会保留，只停止额外补全，避免已生成内容被错误丢弃；上游上下文容量错误会单独显示中文原因。管理页将“生成中”拆为“排队中”和“处理中”，并将歌曲总数标为“已收录歌曲”。部署前文件与数据库备份位于 `/www/backup/token-admin-before-context-budget-20260727T153439Z`；原 3 个 `AI_TOKEN_LIMIT_EXCEEDED` 任务已重试并全部完成，实际输入分别为 10,455、10,774 和 16,768 Token，继续复用 PM2 `token-admin`、本地端口 3388 和原域名入口。

2026-07-28 已部署公告发布版本选择与客户端 Build 匹配。公告管理页直接读取 IPA 管理中已发布的版本，可按 `CFBundleShortVersionString + CFBundleVersion` 选择最低和最高发布版本；服务端新增 Build 范围持久化、清单过滤及无效范围校验。App 公告请求同步携带 Version 与 Build，并在欢迎页结束后的首次检查强制刷新轻量清单，后续前后台切换仍按服务端建议间隔懒检查，公告正文继续仅在存在未读公告时读取；未上报 Build 的旧客户端按 Version 兼容匹配。生产已有测试公告未展示的原因是把 Build `69` 填入了 Version 字段，且当前状态为已下线。部署前文件与数据库备份位于 `/www/backup/token-admin-before-announcement-release-target-20260727T162515Z`，继续复用 PM2 `token-admin`、本地端口 3388 和原域名入口。

2026-07-28 已升级 Agent 生成任务为完整队列界面。服务端任务列表关联歌曲、平台映射与封面，返回歌名、歌手、专辑、平台、队列位置、任务总数及分状态统计；管理页显示任务阶段、触发原因、排队位置、处理时间、尝试次数、Token、费用和结果，支持状态筛选、25/50/100 条分页及活动任务自动刷新。TokenAdmin 同时新增全局深浅色切换，登录页、管理页和公开账号页面共享并持久化主题偏好，保留原有深色终端视觉。生产任务接口验证共 155 个任务，歌曲元数据和队列位置返回正常；浏览器实测浅色模式、队列 4 页及 1280px 页面无横向溢出。部署前文件与数据库备份位于 `/www/backup/token-admin-before-queue-light-20260728-022718`，继续复用 PM2 `token-admin`、本地端口 3388 和原域名入口。

2026-07-28 修复 Agent 队列长期停留在排队状态。根因是服务端 Worker 复用了 App 客户端的每日 100 次、每小时 20 次请求额度，额度耗尽后不会领取任何任务；现服务端继续遵守 15 秒请求间隔、每分钟限制、上游退避和熔断保护，但不再套用客户端日/小时额度。部署后完成任务由 103 增至 104，并自动继续处理下一首，排队任务由 83 降至 82，确认队列持续消费。歌曲管理同时新增总数、搜索结果总数、25/50/100 条分页及上一页/下一页控制；生产浏览器实测共 176 首、4 页，第 1 页与第 2 页歌曲不同，1280px 页面无横向溢出。部署前备份位于 `/www/backup/token-admin-before-worker-song-pagination-20260728-033228`，继续复用原 PM2 `token-admin`、本地端口 3388 和域名入口。

2026-07-28 修正生成任务处理时间口径。`started_at` 现在表示当前或最终一次连续 Worker 尝试的开始时间；任务重新排队、限流延迟和人工重试会清空旧计时，过期租约被其他 Worker 接管时重新开始计时，不再把队列等待或服务中断累计为处理时间。数据库迁移已隐藏无法可靠还原的历史异常时长，生产查询中超过 1 小时的错误记录现为 0；浏览器实测正在生成任务显示本轮 5 秒，排队任务只显示队列位置和加入时间。部署前备份位于 `/www/backup/token-admin-before-qcm-login-job-timing-20260728-042930`，继续复用原 PM2 `token-admin`、本地端口 3388 和域名入口。

2026-07-28 已部署“音乐幕后”平台内部数据清洗与英文资料检索增强。网易云音乐百科采集不再把 `songTag`、`songBizTag`、`melody_style`、`orpheus://` 及内部路由参数作为正文或兜底内容；历史已发布版本若含此类内部载荷会自动下线并创建升级任务。联网检索新增 Apple Music、SoundCloud、Spotify 与 Qobuz 定向查询，补充英文歌曲资料、制作信息、艺人说明和专辑资料识别；只有匹配歌曲艺人的 SoundCloud 官方主页可提升为 B 级来源。生产以 NCM `1379918404`（《time machine (feat. aren park)》）验证：原始百科数据命中内部字段，清洗结果不再输出任何内部载荷，旧污染版本已下线并进入重新生成队列。服务端 29 项测试、远端模块加载、公开配置、域名入口和 SQLite `quick_check` 均通过；部署前备份位于 `/www/backup/token-admin-before-ncm-wiki-sanitizer-20260728T021339Z`，继续复用原 PM2 `token-admin`、本地端口 3388 和域名入口。

2026-08-03 已完成全量 Agent 升级部署。歌曲内容 Agent 升级为 `song-editor-web-v7`，会对有证据支持但为空或明显过短的歌曲介绍、创作故事、乐评和专辑介绍执行一次定向补全；App 下发仅保留均衡器、听歌洞察和特别问候三个 Agent，版本分别升级为 `mono-audio-agent-v28`、`mono-listening-insight-v3` 和 `special-greeting-v2`，并下发独立的最大尝试次数。歌词舞台与壁纸搜索翻译 Agent 已从公开配置及管理页移除。发布配置为版本 19，ID `66c480e1-bf3d-478b-b780-da97028f9acb`；公共配置经真实有效 Token 与现有设备绑定请求验证返回 200，只包含三个目标 Agent。部署前 SQLite 一致性备份和 17 个代码/UI 文件快照位于 `/www/backup/token-admin-before-agent-upgrade-20260803T024412Z`，数据库 SHA-256 为 `ab8f08d18dabab6272a235c3ddd65230bb9e08068c12164cb113241dc00b3aa8`，`PRAGMA integrity_check` 返回 `ok`；部署后数据库恢复点位于 `/www/backup/token-admin-after-agent-upgrade-20260803T025223Z`，SHA-256 为 `5a73985f7e1e7934a132d399830dbb59371bc28762c6a665cc29498353bf0106`，完整性检查同样为 `ok`。部署后原 PM2 `token-admin` 保持 `online`，继续监听 `127.0.0.1:3388`；`https://ncm.zijiu522.cn/_admin/agents` 返回 HTTP 200，JS/CSS 公网哈希与本地文件一致。管理页静态资源版本更新为 `2026080301`，避免旧缓存继续显示已删除的 Agent。原混淆 AI 配置文件未覆盖，SHA-256 仍为 `f7bbcf29c06920a5843464221bd9785759716116d1639509c9c2c4f18c86cf6c`。部署前本地服务端测试共 34 项通过，远端所有运行 JavaScript 均通过 `node --check`。

2026-08-19 已部署调音 Agent v30 与 Mono 调音知识契约。均衡器 Agent 发布为 `mono-audio-agent-v30-dsp`，配置版本 20，ID `1148205e-69f0-4329-a1d5-c40bd59c5e46`；原 10 段和 32 段定制提示词完整保留，并追加 `mono-tuning-knowledge-v1` 的证据优先级、OPRA/设备基线隔离、DSP 阶段职责、动态处理互斥、组合余量、相位与单声道安全规则。管理页资源版本更新为 `2026081901`。部署前文件与一致性数据库备份位于 `/www/backup/token-admin-before-audio-agent-v30-20260819T013510Z`，部署后恢复点位于 `/www/backup/token-admin-after-audio-agent-v30-20260819T015300Z`，数据库 SHA-256 为 `b201347742bd190845fcde7f1602403504e9edeb1dd4ddf874ae9b378cb72942`，前后 `PRAGMA integrity_check` 均为 `ok`。生产公共配置经有效 Token 与现有设备绑定请求验证返回 HTTP 200、版本 20 和 `mono-audio-agent-v30-dsp`；管理页与静态资源公网入口均返回 HTTP 200，公网 JS SHA-256 为 `eb9a0d63cc051aa61665347d8ef05ac8839da4e0c632b6d16c7525d183c39c32`。原 PM2 `token-admin` 保持 `online` 并继续监听 `127.0.0.1:3388`，不稳定重启为 0；原混淆 `ai-remote-config.js` 未覆盖，SHA-256 仍为 `f7bbcf29c06920a5843464221bd9785759716116d1639509c9c2c4f18c86cf6c`。本地服务端测试 27 项通过，Swift 提示词文件通过解析，远端发布脚本在生产数据库副本上完成发布与幂等复跑验证。
