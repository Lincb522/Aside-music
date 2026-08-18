# MonoMemory Engine

`MonoMemoryEngine` 是 Monologue 的统一内存治理层。它不替代数据库、磁盘缓存或播放引擎，而是为所有可重建的内存资源分配预算，并集中处理前后台、系统内存警告、低电量和热状态变化。

## 目标

- 避免图片、MusicKit 模型、歌单派生数据等缓存各自设置固定上限后叠加失控。
- 只保留一套内存压力监听和回收顺序。
- 优先清理可重新下载或重新计算的资源，最后处理当前播放依赖的模型。
- 内存回收不删除数据库、下载、用户配置和磁盘持久化缓存。
- 通过统一快照和日志观察进程占用、预算、回收原因与回收结果。
- 同时监听 UIKit 内存警告和 Darwin memory-pressure 事件，避免只依赖单一通知入口。

## 自适应预算

基础缓存总预算根据设备物理内存分档：

| 设备物理内存 | 前台基础预算 |
| --- | ---: |
| 不高于 3 GB | 128 MB |
| 不高于 4 GB | 176 MB |
| 不高于 6 GB | 240 MB |
| 高于 6 GB | 320 MB |

进入后台、开启低电量模式或设备处于严重/临界热状态时，总预算会继续按比例下降，最低保留 72 MB。各资源按照权重领取预算，而不是继续维持彼此独立的固定上限。

预算分配先满足各资源申报的最小工作集，再按权重分配剩余空间；如果最小工作集之和已经超过全局预算，则整体等比压缩。所有资源的分配结果总和不会再超过引擎给出的全局预算。

收到 warning/critical 压力后会进入 2–3 分钟压力预算期，临时将总预算降低到正常值的 72%/52%。压力期结束后由巡检自动恢复，不会在连续警告之间反复扩容。

## 分级回收

| 等级 | 触发 | 行为 |
| --- | --- | --- |
| `routine` | 30 秒巡检且占用正常 | 执行 TTL、数量上限和 LRU 维护 |
| `background` | App 进入后台 | 取消无用加载任务并收缩图片、派生数据和大集合 |
| `warning` | 进程占用超过软阈值、严重热状态 | 清空大部分可重建缓存，保留当前播放所需状态 |
| `critical` | 系统内存警告或超过硬阈值 | 立即清空可重建资源，关键资源仅保留正在使用的最小集合 |

软、硬阈值会同时参考设备物理内存，避免在低内存设备上等到系统终止前才回收，也避免高内存设备过早抖动。

回收状态机只允许一个回收任务运行。新的压力只有高于当前等级时才会排队，避免 UIKit 与 Darwin 同时上报造成重复清理；回收结束后如果进程占用仍越过更高阈值，引擎会自动升级到下一等级再执行一次。

## 已接入资源

- 解码封面与图片请求任务：`cache.artwork`
- 系统 URLSession 响应内存层：`cache.url-session`
- 通用编码数据缓存：`cache.encoded-data`
- L1 歌曲/歌单模型缓存：`cache.models`
- Apple Music / MusicKit 模型与曲目集合：`cache.apple-music`
- 本地歌单派生数据：`cache.local-playlists`
- 播放 URL：`cache.playback-url`
- 音乐幕后已发布内容：`cache.song-content`
- 自定义主题背景图：`cache.theme-background`
- 沉浸背景视频缩略图与时长：`cache.video-thumbnails`、`cache.video-duration`
- 收音机 LED 预渲染图与点阵：`cache.radio-led-images`、`cache.radio-led-raster`
- 听歌洞察内存结果：`cache.ai-listening-insight`
- 播放器下一曲解析、下载和预装任务：`runtime.playback-prefetch`

注册资源时必须声明：

1. 稳定且唯一的资源 ID；
2. `recreatable`、`retained` 或 `essential` 优先级；
3. 预算权重和最小预算；
4. 应用预算的方法；
5. 分级回收方法及估算释放量。

## 数据安全约束

- `CacheManager` 的内存层可以回收，磁盘层不会因内存压力被删除。
- `SongContentDetailCache` 回收后仍从持久化副本按需恢复，写入前会先合并被回收的内容。
- 本地歌单只清理派生数组，不修改 `MonoStore` 数据。
- Apple Music 缓存会优先保留当前播放歌曲的目录模型。
- 图片回收会取消已无必要的后台下载，但不会清除磁盘图片缓存。
- 播放资源回收只取消尚未进入可听管线的预取任务；当前歌曲、已提交切换事务和正在出声的 decoder 不会被内存治理中断。

## 诊断

`MonoMemoryEngine.shared.diagnosticSnapshot()` 提供：

- 当前进程物理占用；
- 设备物理内存；
- 当前缓存总预算；
- 已注册资源数量；
- 最近回收等级、原因和时间；
- 本次进程累计回收次数。
- 每个资源的实际分配预算、条目数、估算占用、最近释放量和回收耗时。

资源快照按估算占用从高到低排列，可直接定位内存增长来自封面、MusicKit、模型还是渲染缓存。无法低成本估算的资源会返回零估算值，但仍参与预算和回收。

`MonoMemoryEngine.shared.diagnosticReport()` 会把同一份信息输出为可复制的纯文本诊断报告，便于真机日志排查，不需要连接调试 UI。

日志事件：

- `memory.engine.start`
- `memory.engine.trim`

手动回收使用：

```swift
MonoMemoryEngine.shared.trim(level: .warning, reason: .manual)
```

该操作只处理已注册的内存资源，不等价于“清除所有缓存”，不会删除持久化数据。

## 新缓存接入要求

新增可能长期存在或批量增长的内存缓存时，禁止再自行监听 `UIApplication.didReceiveMemoryWarningNotification`。应为缓存设置自然上限并注册到 `MonoMemoryEngine`；对当前播放相关资源，回收实现必须明确保留正在使用的对象。
