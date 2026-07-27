# 实施任务清单 — main-tabs-theme-frame-drop

> 对齐 `.kiro/specs/main-tabs-theme-frame-drop/bugfix.md` 与 `.kiro/specs/main-tabs-theme-frame-drop/design.md`。
> 严格按 M0 → M1 → M2 → M3 → M4 里程碑顺序执行；未完成 M0 SHALL NOT 进入 M1。
> 带 `*` 的任务为「diff 不通过即保守保留 F 原路径」的评估性任务。

---

## M0 · 修复前备份 + 基线采集 + 探索测试（零代码改动）

- [x] 1. 修复前完整备份（bugfix §5 硬前置，未完成 SHALL NOT 进入后续任何任务）
  - [x] 1.1 `.gitignore` 前置检查并补齐 `.local-backups/`
    - 读取当前 `.gitignore`，若未按前缀 `.local-backups/` 覆盖则在文件末尾追加一行 `.local-backups/`
    - 通过 `grep -q '^\.local-backups/' .gitignore` 自检
    - 确认 `.gitignore` 仍覆盖 `.env / Secrets.xcconfig* / .build / DerivedData / .kiro / .codex-backups` 等既有条目未被误删
  - [x] 1.2 新建 `scripts/backup-before-fix.sh`，实现 design §5.1~§5.7 全流程
    - 前置检查：强制校验 `.gitignore` 已覆盖 `.local-backups/`，未覆盖即 `exit 1` 并提示补齐重跑（§5.6）
    - 参数：可选 `--stage <name>`（增量备份） / `--dry-run` / `--list-samples`（§5.5 路径存在性自检）
    - UTC 时间戳：`STAMP=$(date -u +%Y%m%dT%H%M%SZ)`；目标目录 `BACKUP_DIR=".local-backups/main-tabs-theme-frame-drop-${STAMP}"`（或 `...-${STAGE}-${STAMP}`）
    - 排除清单（§5.2）：`.gitignore` 条目 + 强制排除 `.env / Secrets.xcconfig / Secrets_*.xcconfig / *.ipa / *.app / *.dSYM / *.xcarchive / NeteaseCloudMusicAPI-Swift/ / ffmpeg-swift/ / QQMusicKit/ / HiconIcons/ / .build/ / DerivedData/ / .kiro/ / .codex-backups/ / .local-backups/ / build/ / build-macos/ / tmp/ / .tmp*/ / *.tar.gz / *.zip`
    - 主体同步：`rsync -a --delete --exclude-from=<tmpfile> ./ "${BACKUP_DIR}/source/"`
    - spec 保活：rsync 完成后单独复制 `.kiro/specs/main-tabs-theme-frame-drop/` 到 `${BACKUP_DIR}/source/.kiro/specs/main-tabs-theme-frame-drop/`（§5.2 注，供 §5.5 抽样可达）
    - `manifest.txt` 字段（§5.3）：`GIT_HEAD / GIT_STATUS / GIT_DIFF_STAT / GIT_STASH_REF / BACKUP_START_UTC / BACKUP_END_UTC / OPERATOR / MAC_OS / XCODE / WORKING_TREE_ABS / GIT_REMOTES / STAGE`
    - `manifest.diff.txt`：独立存放 `git diff` 全文
    - `manifest.sha256`（§5.4）：`(cd "${BACKUP_DIR}" && find . -type f \! -path './manifest*' | LC_ALL=C sort | xargs -I{} shasum -a 256 "{}") > manifest.sha256`
    - 失败清理（§5.7）：任一步骤非零退出立即 `rm -rf "${BACKUP_DIR}"` 并 `exit 1`，不自动重试
    - 安全副作用：SHALL NOT 动 `.git/`、SHALL NOT 修改工作树、SHALL NOT 执行网络请求
    - `chmod +x`；本地 self-test 一次 `--dry-run` 与一次空目录真实运行
  - [x] 1.3 新建 `scripts/restore-backup.sh`（design §5.8）
    - 参数：`<backup_dir>`
    - 主体：`rsync -a --delete "${backup_dir}/source/" ./`，排除 `.git/`
    - 校验：`(cd "${backup_dir}" && shasum -a 256 -c manifest.sha256)` 全部 OK，否则 `exit 1`
    - 打印 `manifest.txt` 的 `GIT_HEAD` 与 `GIT_STASH_REF`，提示「若需恢复未提交改动，可 `git stash apply ${GIT_STASH_REF}`」
    - `chmod +x`；空临时目录 self-test 一次
  - [x] 1.4 首次执行一次完整备份
    - 运行 `scripts/backup-before-fix.sh`（不带 `--stage`）
    - 验证生成 `.local-backups/main-tabs-theme-frame-drop-<UTC>/source/ + manifest.txt + manifest.diff.txt + manifest.sha256`
    - 运行 `(cd "${BACKUP_DIR}" && shasum -a 256 -c manifest.sha256)` 全部 OK
    - 若工作树有未提交改动：确认 `GIT_STASH_REF` 记录了 `git stash create` 返回的 commit hash（§5.4 bugfix）
  - [x] 1.5 执行 sample diff 校验（5 个关键文件，bugfix §5.3 + design §5.5）
    - 对 `Package.swift` / `Sources/Mono/MonoApp.swift` / `Sources/Mono/Views/ContentView.swift` / `Sources/Mono/Themes/ThemeRenderLayer.swift` / `.kiro/specs/main-tabs-theme-frame-drop/bugfix.md` 分别执行 `diff -q "${BACKUP_DIR}/source/<file>" "./<file>"`
    - 任一不一致 → 按 §5.7 `rm -rf "${BACKUP_DIR}"` 并回 Task 1 修 backup 脚本
    - 全部一致才把 Task 1 标记 complete
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.7_
  - _Design Section: §5_

- [ ] 2. 基线性能采集（Instruments 100 条 trace + metrics.csv）
  - [ ] 2.1 新建 `scripts/collect-baseline.sh`（design §6.2）
    - 封装 `xcrun xctrace record --template` 调用，支持 `Animation Hitches` / `Time Profiler` / `SwiftUI` 三种模板
    - 支持参数 `--theme <T> --tab <P> --scenario <S> --device <D>`
    - 输出到 `.local-backups/main-tabs-theme-frame-drop-<UTC>/baseline/<device>/<theme>-<tab>-<scenario>.trace`
    - `chmod +x`；self-test 一次单条 trace
  - [ ] 2.2 执行 20 (T, P) × 5 场景 = 100 条 Instruments trace（§6.3）
    - T ∈ {default, muji, manga, neumorphic, capsule}
    - P ∈ {home, podcast, library, profile}
    - 场景 ∈ {冷启进入, 30s 滚动, 60s 播放中停留, 20 次连切 tab, 10 次深浅色切换}
    - 每条 trace 归档到 `.local-backups/.../baseline/<device>/`
  - [ ] 2.3 导出 `baseline/metrics.csv`（§6.4）
    - 字段：`theme, tab, scenario, device, refreshRate, hitch_count, hitch_ratio_ms_per_s, frame_interval_p50_ms, frame_interval_p95_ms, frame_interval_p99_ms, commit_ms_mean, commit_ms_p95, scroll_fps, body_invalidations_per_second`
    - CSV 与 trace 同目录归档，作为 M1/M2/M3 出口阈值的输入源（§6.5：baseline × 倍率）
  - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6_
  - _Design Section: §6_

- [ ] 3. Exploratory fault condition checking（bugfix §Testing Strategy / design §Testing Strategy · Exploratory 的 5 条 case 分别跑并归档）
  - [ ] 3.1 Case 1：`globalThemeRevision` 广播证实（根因 A / bugfix §1.1、§1.2）
    - 进入 `(*, home)` → 切 colorScheme 1 次 → 记录 `_printChanges()` 所列节点
    - 预期失败（在 F 上）：4 tab 根 View + FloatingBar 根均在列表；总数显著超过「真正依赖色彩」的节点
    - 归档到 `.local-backups/.../exploratory/case-1/`
  - [ ] 3.2 Case 2：`.id("\(themeId)-\(revision)")` 卸载重建证实（根因 B / bugfix §1.3）
    - 给 FloatingBar 根 `init` / `deinit` 加计数 → `globalThemeRevision &+= 1` 一次
    - 预期失败：`init` + `deinit` 各 1 次
    - 归档到 `.../exploratory/case-2/`
  - [ ] 3.3 Case 3：Canvas + blur 热点证实（根因 C / bugfix §2.2、§7.1）
    - 冷启 `(default, home)` + Time Profiler 抽栈
    - 预期失败：`_draw` / `CGContext` / `CA::Render::ShadowRenderer` 出现在主线程热点前 5
    - 归档到 `.../exploratory/case-3/`
  - [ ] 3.4 Case 4：Podcast 横向 section 非 lazy 证实（根因 D / bugfix §9.1）
    - 给每个 section item `init` 加计数 + 进入 `(*, podcast)`
    - 预期失败：section 入视野即全量 init，不等滚动到可视区
    - 归档到 `.../exploratory/case-4/`
  - [ ] 3.5 Case 5：LibraryHeader 手势冲突证实（根因 D / bugfix §14.1）
    - `(*, library)` 下拉起手 500ms 用 Animation Hitches 录制
    - 预期失败：起手首帧产生 hitch
    - 归档到 `.../exploratory/case-5/`
  - [ ] 3.6 任一 case 不能复现 → 回到根因分析并更新 design，登记为 M0 的 issue
    - 产出 `exploratory/README.md`，记录每条 case 的通过 / 失败与对应 design 调整链接
    - 全部 5 条复现预期失败 → Task 3 complete；否则阻塞 M1
  - _Requirements: 1.1, 1.2, 1.3, 2.2, 7.1, 9.1, 14.1_
  - _Design Section: §Root Cause Analysis, §Hypothesized Root Cause, §Testing Strategy · Exploratory Fault Condition Checking_

- [ ] 4. 首帧 property-based 探索测试骨架（PBT-5 在本地 sandbox 仓库 dry-run，其余 Property 的 PBT 留到后续里程碑）
  - [ ] 4.1 为 Property 5（备份还原）在 sandbox 仓库实现 PBT-5
    - 生成器：随机「未提交改动」（随机文件数、随机路径、随机内容，含二进制 / 文本 / 空文件 / 权限位）
    - 性质：`backup-before-fix.sh` → `restore-backup.sh` 后，工作树与备份前 `git status --short` + 文件 sha256 全量等价
    - 失败缩小：保留最小反例目录留痕到 `sandbox/.pbt-5/failures/`
  - [ ] 4.2 PBT-5 dry-run 10 轮，全部通过后归档
    - 任一失败即回 Task 1.2 / 1.3 修 backup / restore 脚本
  - [ ] 4.3 登记 PBT-1 / PBT-2 / PBT-3 / PBT-4 / PBT-6 的占位
    - PBT-1（Property 1 / 性能不变量）：在 M1 / M2 / M3 的 fix checking 中逐步加入
    - PBT-2（Property 2 / 稳态等价）：随 §4.1 snapshot 矩阵在每个里程碑出口加入
    - PBT-3（Property 3 / 过渡曲线）：随 §4.2 transition curve 在每个里程碑出口加入
    - PBT-4（Property 4 / 功能等价）：随 §3.12 / §3.13 订阅下沉在 M1 出口加入
    - PBT-6（Property 6 / 迁移兼容）：在 M4 整体验收时加入
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  - _Design Section: §Testing Strategy · Property-Based Tests, §5_


---

## M1 · 订阅 / identity 治理（Level 0 · 纯非绘制改动）

> 准入：M0 全部完成且 Property 5 首次通过，baseline metrics CSV 已落盘，5 条 exploratory case 复现预期失败。
> 统一子任务范式：实现 → 单元测试 / 属性测试 → Snapshot 矩阵子集回归（§4.1）→ 过渡曲线 diff（如涉及，§4.2）→ Instruments hitch 对比（与 baseline 对比）→ Level 0 默认启用，无 feature flag。

- [x] 5. 拆分 `SettingsManager.globalThemeRevision` → `paletteRevision / rendererRevision` + 新增 `ThemeChangeBus`
  - [ ] 5.1 实现：在 `SettingsManager` 新增 `@Published paletteRevision: UInt64` 与 `@Published rendererRevision: UInt64`；按事件源分别 `&+= 1`（色彩 / 主题 token 变化 → palette；尺寸 / 主题类型 / 色彩方案切换 → renderer）
  - [ ] 5.2 实现：新增 `final class ThemeChangeBus: ObservableObject`，暴露 `palette / renderer / coverSampledColor` 三路 `CurrentValueSubject`（或 `@Published`）；4 个 tab 根 View 只订阅 `paletteRevision`
  - [ ] 5.3 实现：保留 `var globalThemeRevision: UInt64 { paletteRevision &+ rendererRevision }` 只读 getter（向后兼容）；旧 `&+=` 发射路径并行保留（§7.5，M4 再移除）
  - [ ] 5.4 单元测试 `GlobalThemeRevisionSplitTests` + `ThemeChangeBusTests`：断言各事件源独立 bump；订阅者只收到相关事件；旧 getter 返回值与新字段组合一致
  - [ ] 5.5 `_printChanges()` 断言「一次色彩方案切换触发的 body 重算节点数 ≤ baseline × 0.25」（§6.5 `body_invalidations_per_second`）
  - [ ] 5.6 Snapshot 矩阵子集回归（§4.1 M1 最小子集 80 组）：主题切换 / colorScheme 切换稳态截图与 F 逐像素等价
  - [ ] 5.7 Instruments hitch 对比：`colorSchemeFlip` × 20 (T, P) 场景与 baseline 比对
  - _Requirements: 1.1, 1.2, 1.3, 12.2_
  - _Design Section: §3.1_

- [ ] 6. `ThemeRenderContext.providesGlobalBackdrop` 切换 + `ThemeRenderHost` 共享 backdrop
  - [ ] 6.1 实现：在 `ContentView.tabViewCore` 外层包 `ThemeRenderHost`，其 `ZStack` 底层挂一次共享 `ThemeRenderBackdrop`；`providesGlobalBackdrop = true`；`ThemedPageBackground` 在新路径退化为 `Color.clear`
  - [ ] 6.2 实现：Host backdrop 与原 `ThemedPageBackground` 使用相同的 `ignoresSafeArea(.all)` / 安全区 / `GeometryReader` 尺寸约束；`(theme, colorScheme, size)` 变化才 rebuild
  - [ ] 6.3 单元测试 `BackdropInstanceCountTests`：注入 `ThemeRenderBackdrop.init` 计数器；一次会话内构建次数 ≤ 1（仅允许尺寸变化重建）
  - [ ] 6.4 Snapshot 矩阵子集回归（§4.1）：20 (T, P) × light / dark 稳态截图 pixel diff ≤ 1/256
  - [ ] 6.5 Instruments hitch 对比：冷启 → 连切 20 次 tab，hitch count 与 baseline 比对（目标 ≤ baseline × 0.4）
  - _Requirements: 2.1, 2.2_
  - _Design Section: §3.2_

- [ ] 7. `GlobalThemeProvider` 泛型化（`homeContent / podcastContent / libraryContent / profileContent`）+ `ThemedTabContainer` 去 `AnyView`
  - [ ] 7.1 实现：给 `GlobalThemeProvider` 加 `associatedtype HomeContent / PodcastContent / LibraryContent / ProfileContent: View` + `@ViewBuilder func homeContent() -> HomeContent ...`
  - [ ] 7.2 实现：新增 `struct ThemedTabContainer<HomeContent: View, PodcastContent: View, LibraryContent: View, ProfileContent: View>`；`ContentView.tabViewCore` 按具体类型注入
  - [ ] 7.3 实现：保留 `makeHomeView() -> AnyView` 等旧 API 作过渡期入口（`@available(*, deprecated)`），仅作为实验 / 测试主题注入的兜底
  - [ ] 7.4 单元测试：`_printChanges()` 断言「单次 tab 切换触发的根 body 重算数」相较 baseline 下降
  - [ ] 7.5 Snapshot 矩阵子集回归（§4.1）：20 (T, P) 稳态截图等价
  - [ ] 7.6 Instruments hitch 对比：`20 次连切 tab` 场景与 baseline 比对
  - _Requirements: 1.3, 8.1_
  - _Design Section: §3.9_

- [x] 8. `PodcastView` 5 个横向 section 改 `LazyHStack`
  - [x] 8.1 实现：`categoriesSection / newestPrograms / chartPrograms / newcomerRadios / broadcastChannels` 的 `ScrollView(.horizontal) { HStack { ForEach { item } } }` 改为 `LazyHStack`；保留 `scrollTransition(scaleEffect)` 原参数不变
  - [ ] 8.2 单元 / 功能测试：所有 item 可滚动进入视图、数据无截断（bugfix §2.2）；给 item `init` 加计数，lazy 化后只有可视区域 item 被构建
  - [ ] 8.3 Snapshot 矩阵子集回归（§4.1）：`(*, podcast)` 滚动前 / 中 / 后三帧稳态截图等价
  - [ ] 8.4 过渡曲线 diff（§4.2）：`scrollTransition` 的 scale / rotation / opacity 曲线相关系数 ≥ 0.98；若某 section phase 差异 > 阈值，保守回退到 `HStack`（§7.3）并记录*
  - [ ] 8.5 Instruments hitch 对比：`(*, podcast)` 的「30s 滚动」场景与 baseline 比对（目标 P95 frame interval ≤ baseline × 0.6）
  - _Requirements: 9.1, 9.2, 2.2_
  - _Design Section: §3.10_

- [ ] 9. `ProfileView` 4 路 `onReceive` 下沉 + `RecentRadioStrip` 订阅下沉 + 新增 `ProfileRefreshCoordinator`
  - [ ] 9.1 实现：把 `viewModel.$userProfile` 下沉到 `UserProfileHeader`；`DownloadManager.$downloadedSongIds.map(count)` 下沉到 `DownloadCountBadge`；`LocalPlaylistManager.$playlists.map(count)` 下沉到 `LocalPlaylistCountBadge`
  - [ ] 9.2 实现：新增 `ProfileRefreshCoordinator`，用 `CurrentValueSubject`（而非 `PassthroughSubject`）广播「刷新请求」；根 View 只持有 coordinator，不订阅事件内容
  - [ ] 9.3 实现：`RecentRadioStrip` 的 `PlayerManager.$currentSong / $isPlaying` 订阅下沉到「当前正在播放」的高亮子视图（非整条 strip）
  - [ ] 9.4 单元 / 属性测试（PBT-4 雏形）：触发 4 路事件源的随机排列组合 → 断言每个叶子 View 都收到并正确刷新、事件不丢（Property 4）
  - [ ] 9.5 `_printChanges()` 断言：`(*, profile) + lyricTick + isPlaying` 下 Profile 根 body 重算次数 = 0（allowedBudget = 0），仅子组件重算
  - [ ] 9.6 Snapshot 矩阵子集回归（§4.1）：`(*, profile)` 稳态截图等价
  - [ ] 9.7 Instruments hitch 对比：`(*, profile)` 的「60s 播放中停留」场景与 baseline 比对
  - _Requirements: 11.1, 11.2, 2.4_
  - _Design Section: §3.12_

- [ ] 10. `FloatingBar` 去 `.id("theme-revision")` + 主题 token 通过 environment 注入 + 歌词 / 进度 / 封面子视图订阅下沉
  - [ ] 10.1 实现：移除容器 `.id("\(themeId)-\(revision)")`；identity 仅由 `themeId` 决定（`.id(themeId)`）
  - [ ] 10.2 实现：主题 token 通过 `.environment(\.themeTokens, tokens)` 注入
  - [ ] 10.3 实现：`FloatingBarPlaybackModel.lyricLineText` 下沉到 `FloatingBarLyricSubtitleView`；进度 / 封面色同理下沉到各自子视图；根容器不再订阅高频事件
  - [ ] 10.4 单元测试：FloatingBar 根 `init` / `deinit` 计数；`globalThemeRevision &+= 1` 一次后 init 计数不变（identity 稳定）
  - [ ] 10.5 `_printChanges()` 断言：一次 `lyricTick` 下 FloatingBar 根 body 重算次数 = 0，仅歌词子视图重算
  - [ ] 10.6 Snapshot 矩阵子集回归（§4.1）：主题 / colorScheme 切换下 FloatingBar 稳态截图等价
  - [ ] 10.7 过渡曲线 diff（§4.2）：切主题瞬间 FloatingBar 过渡帧相关系数 ≥ 0.98
  - [ ] 10.8 Instruments hitch 对比：`10 次深浅色切换` 场景 + 播放中 FloatingBar 稳态 hitch ratio 与 baseline 比对
  - _Requirements: 1.3, 12.1, 12.2, 2.5_
  - _Design Section: §3.13_

- [ ] 11. `VisibilityGatedTimelineView` 封装 + 现存所有 `TimelineView(.animation)` 迁移
  - [ ] 11.1 实现：封装 `VisibilityGatedTimelineView`，组合 `onAppear / onDisappear + Environment(\.scenePhase) + isCurrentTab` 三信号联合决定 `paused = !isAppeared || scenePhase != .active || !isCurrentTab`
  - [ ] 11.2 实现：迁移 `TabBottomAccessoryPlaceholder` 呼吸动画到 `VisibilityGatedTimelineView`
  - [ ] 11.3 实现：迁移各主题 `NowPlayingIndicator` 到 `VisibilityGatedTimelineView`
  - [ ] 11.4 实现：迁移 `NeumorphicVinyl` 到 `VisibilityGatedTimelineView`，记录 `pauseTime / resumeTime` 做相位补偿，保证恢复可见时旋转角度无可感知跳变（bugfix §1.4）
  - [ ] 11.5 实现：若 `MangaRootBackdrop` 存在 time-dependent 层，同步迁移
  - [ ] 11.6 单元测试 `VisibilityGatedTimelineViewTests`：`paused` 真值表覆盖（`isAppeared × scenePhase × isCurrentTab`）；`NeumorphicVinyl` 相位补偿在 `pause → resume` 下的角度计算
  - [ ] 11.7 Snapshot 矩阵子集回归（§4.1）：`(neumorphic, home)` 播放中不同相位时刻稳态截图等价
  - [ ] 11.8 过渡曲线 diff（§4.2）：`(neumorphic, home) → (neumorphic, podcast) → (neumorphic, home)` 往返后 vinyl 角度时间序列相关系数 ≥ 0.98
  - [ ] 11.9 Instruments hitch 对比：后台 tab 无 TimelineView 推进（CPU 采样断言）；稳态 hitch ratio 与 baseline 比对
  - _Requirements: 5.3, 6.1, 13.1, 1.4_
  - _Design Section: §3.15_

- [ ] 12. `LibraryHeader` 手势替换 · `onScrollGeometryChange` / `GeometryReader+PreferenceKey` 取代 `DragGesture`
  - [ ] 12.1 实现：`libraryHeaderCollapseProgress` 改由 iOS 17+ `onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, newY in ... }` 驱动；不支持 API 的 fallback 用 `GeometryReader + PreferenceKey`
  - [ ] 12.2 实现：移除 `DragGesture`；保留 `withAnimation` 在 `libraryHeaderCollapseProgress` 写回时的 easing 曲线
  - [ ] 12.3 单元测试 `LibraryHeaderScrollGeometryTests`：新路径在相同 offset 输入下与原 `DragGesture` 版本输出一致（最终折叠状态语义不变，bugfix §2.6）
  - [ ] 12.4 Snapshot 矩阵子集回归（§4.1）：`(*, library)` 折叠前 / 中 / 后稳态截图等价
  - [ ] 12.5 过渡曲线 diff（§4.2）：下拉 → header 折叠的时间序列相关系数 ≥ 0.98；无闪烁 / 色带 / 裂帧
  - [ ] 12.6 Instruments hitch 对比：`(*, library)` 下拉起手首帧 hitch = 0（§6.5 E5）
  - _Requirements: 14.1, 2.6_
  - _Design Section: §3.16_

- [ ] 13. M1 出口验收（退出条件合关）
  - [ ] 13.1 PBT-2（稳态等价）+ PBT-3（过渡曲线）+ PBT-4（功能等价）接入并全部通过
  - [ ] 13.2 Property 1 阶段性性能改善：主题切换 body 重算节点数 ≤ baseline × 0.25（§6.5）
  - [ ] 13.3 Fix checking test case E4 / E5 / E6 / E7 在 M1 通过（§Testing Strategy · Fix Checking）
  - [ ] 13.4 追加一次 `scripts/backup-before-fix.sh --stage m1-level-0` 增量备份归档
  - _Requirements: 15.1, 15.2, 15.3, 15.5, 15.6_
  - _Design Section: §里程碑划分 · M1_


---

## M2 · 绘制缓存化（Level 1 · 逐主题上线，等价栅格化）

> 准入：M1 全部完成并出口验收通过。
> 统一子任务范式：实现缓存 + 并行保留原路径（feature flag）+ Snapshot 矩阵子集回归（§4.1）+ 过渡曲线 diff（若涉及，§4.2）+ Instruments hitch 对比（与 baseline 对比）+ feature flag 默认值 + 开启条件。
> 顺序按 design §M2 建议：Default → Manga → Muji → Capsule → 统一 `ThemeCustomDiffuseBackground`。

- [ ] 14. Default 主题缓存化 · `MonoBackground.defaultSystemBackground` + `ParallaxMountainHeader` + hitokoto 订阅下沉
  - [ ] 14.1 实现缓存：`defaultSystemBackground` 的 `Canvas + blur(60) + drawingGroup()` 通过 `ImageRenderer`（iOS 17+）按 `Key(themeId, colorScheme, paletteRevision, sizeRounded, displayScale)` 缓存为 `UIImage`，视图层改为 `Image(uiImage: cached)`；`rendererRevision` 变化时 evict
  - [ ] 14.2 实现缓存：`ParallaxMountainHeader` 的静态「山脊 / 天空渐变」预渲染为 `UIImage`；视差位移由外层 `ScrollView` 偏移驱动 `.offset(y:)`（保留原位移曲线）
  - [ ] 14.3 实现订阅下沉：hitokoto 组件的 `Canvas` 抽出独立子视图，仅在 hitokoto 文本 / 颜色变化时重绘
  - [ ] 14.4 并行保留原路径（feature flag）：`FeatureFlags.useCachedDefaultBackground` 默认 false；缓存命中失败或尺寸未覆盖时自动回退到原 `Canvas + blur(60) + drawingGroup()` 路径
  - [ ] 14.5 Snapshot 矩阵子集回归（§4.1）：`(default, *)` × light / dark × scale {2x, 3x} × Dynamic Type {.medium, .xxxLarge} pixel diff ≤ 1/256；任一失败即保留 flag 关
  - [ ] 14.6 过渡曲线 diff（§4.2）：`(default, home)` 滚动期间视差位移时间序列相关系数 ≥ 0.98
  - [ ] 14.7 Instruments hitch 对比：`(default, home) + enterTab` 首帧 commit 与 baseline 比对（目标 commit_ms_p95 ≤ baseline × 0.6）
  - [ ] 14.8 开启 flag：Snapshot + Instruments 双通过后 `FeatureFlags.useCachedDefaultBackground = true`；归档一次 A/B 截图对
  - _Requirements: 7.1, 7.2, 7.3_
  - _Design Section: §3.8_

- [ ] 15. Manga 主题缓存化 · `MangaRootBackdrop` drawingGroup + `MangaDotsTexturePattern` 共享
  - [ ] 15.1 实现缓存：`MangaRootBackdrop` 外层 wrap `.drawingGroup()` + `.id(paletteRevision)`，把 3 层 Canvas 纹理合成结果离屏缓存
  - [ ] 15.2 实现缓存：`MangaDotsTexture` 抽为 `MangaDotsTexturePattern`（静态 image pattern），按 `Key(cornerRadius, size, paletteRevision, colorScheme, displayScale)` 缓存；`MangaCardBackground` overlay 改为 `Image(uiImage: pattern).resizable()` + `clipShape(RoundedRectangle(cornerRadius:))`
  - [ ] 15.3 单元测试 `MangaDotsTexturePatternTests`：同 key 像素等价；dot 直径 / 间距 / 颜色 / 圆角与 F 一致
  - [ ] 15.4 并行保留原路径（feature flag）：`FeatureFlags.useCachedMangaTextures` 默认 false；miss 时回退到原 Canvas 绘制
  - [ ] 15.5 Snapshot 矩阵子集回归（§4.1）：`(manga, *)` × light / dark × scale {2x, 3x} pixel diff ≤ 1/256（重点校验 dots 密度与 `compositingGroup()` 边缘）
  - [ ] 15.6 过渡曲线 diff（§4.2）：`(manga, home)` 滚动期间 `scrollTransition(rotation)` 曲线相关系数 ≥ 0.98
  - [ ] 15.7 Instruments hitch 对比：`(manga, home) + enterTab` 首帧 hitch = 0（§Fix Checking E1）；`(manga, *)` 30s 滚动 hitch ratio ≤ baseline × 0.4
  - [ ] 15.8 开启 flag：双通过后 `FeatureFlags.useCachedMangaTextures = true`；归档 A/B 截图对
  - _Requirements: 3.1, 3.2, 3.3_
  - _Design Section: §3.4_

- [ ] 16. Muji 主题缓存化 · `MujiPaperTexture` 缓存化
  - [ ] 16.1 实现缓存：抽 `MujiPaperTextureCache`，key = `Key(colorScheme, paletteRevision, size, displayScale)`；首次渲染用 `ImageRenderer` 输出 `UIImage`
  - [ ] 16.2 实现：`MujiPaperCardBackground.overlay(MujiPaperTexture())` 与根 `MujiPaperRootBackground` 改为 `.overlay(Image(uiImage: cachedTexture).resizable().interpolation(.high))`（固定 scale 匹配，避免插值差异）
  - [ ] 16.3 并行保留原路径（feature flag）：`FeatureFlags.useCachedMujiPaperTexture` 默认 false；miss / 尺寸未覆盖时回退
  - [ ] 16.4 Snapshot 矩阵子集回归（§4.1）：`(muji, *)` × light / dark × scale {2x, 3x} pixel diff ≤ 1/256（重点校验 `RoundedRectangle` 边缘亚像素差异）
  - [ ] 16.5 Instruments hitch 对比：`(muji, *) + scroll 30s` hitch ratio ≤ baseline × 0.4；单屏 `MujiPaperTexture` 实际 draw 次数从 ≥ 11 次降到常数级（bugfix §4.1）
  - [ ] 16.6 开启 flag：双通过后 `FeatureFlags.useCachedMujiPaperTexture = true`；归档 A/B 截图对
  - _Requirements: 4.1_
  - _Design Section: §3.5_

- [ ] 17. Capsule 主题 · 5 胶囊 Canvas → 独立 SwiftUI transform 动画（保留 phase 连续性）
  - [ ] 17.1 实现：抽取原 `CapsuleBackdropField` 的 `Canvas` 中 5 个胶囊 `angle(context)` 函数推导 phase 表（tasks 阶段从源码读出准确参数）；把 Canvas 重写为 5 个独立 `Capsule().fill().frame(...).offset(...).rotationEffect(.degrees(angle))`
  - [ ] 17.2 实现：用 `withAnimation(.linear.repeatForever)` 驱动相位（GPU-side transform），颜色 / offset / rotation 参数与 F 完全一致；若原 Canvas 版含 `.blendMode(.softLight)` 等混合则在新结构上保留对应 `.blendMode(...)`
  - [ ] 17.3 实现：`bannerTimer` 翻页逻辑不变；翻页时 backdrop 仅走 transform，无 Canvas 重绘
  - [ ] 17.4 并行保留原路径（feature flag）：`FeatureFlags.useCapsuleTransformBackdrop` 默认 false；关闭时走原 Canvas + TimelineView 路径
  - [ ] 17.5 Snapshot 矩阵子集回归（§4.1）：`(capsule, *)` 在相位固定时刻截图 pixel diff ≤ 1/256
  - [ ] 17.6 过渡曲线 diff（§4.2）：每 2 帧采样 5 胶囊位置，F 与 F' 轨迹相关系数 ≥ 0.98；`bannerTimer` 翻页期间时间序列相关系数 ≥ 0.98
  - [ ] 17.7 Instruments hitch 对比：`(capsule, home) + bannerTimer` 翻页期间 hitch count ≤ 1（§Fix Checking E3）
  - [ ] 17.8 开启 flag：三通过（snapshot + transition curve + Instruments）后 `FeatureFlags.useCapsuleTransformBackdrop = true`；归档 A/B 截图与曲线对
  - _Requirements: 6.1, 6.3, 1.5, 1.6_
  - _Design Section: §3.7_

- [ ] 18. 统一基础 · `ThemeCustomDiffuseBackground` 缓存化
  - [ ] 18.1 实现缓存：抽 `DiffuseBackgroundCache`（`NSCache` 或 `actor`），key = `Key(themeId, colorScheme, rendererRevision, sizeRounded, displayScale)`
  - [ ] 18.2 实现：只把底层 `Canvas + blur(38)` 用 `ImageRenderer` 栅格化为 `baseLayer` UIImage；`accentLayer` 的 `Canvas + blur(44)` 单独栅格化为 `UIImage`；视图层 `Image(uiImage: cachedBase)` + `Image(uiImage: cachedAccent).blendMode(.softLight)`（softLight 不合入栅格化，§7.2）
  - [ ] 18.3 实现：`rendererRevision` 变化时主动 evict；miss 或尺寸未命中回退到原 Canvas 路径
  - [ ] 18.4 单元测试 `DiffuseBackgroundCacheTests`：同 key `ImageRenderer` 输出缓存命中；`rendererRevision` 变化 miss；不同 scale 独立缓存
  - [ ] 18.5 并行保留原路径（feature flag）：`FeatureFlags.useCachedDiffuseBackground` 默认 false；提供 Debug menu 开关做 A/B
  - [ ] 18.6 Snapshot 矩阵子集回归（§4.1）：20 (T, P) × light / dark × scale {2x, 3x} 全量子集 pixel diff ≤ 1/256（此任务影响所有主题，矩阵扩全）
  - [ ] 18.7 Instruments hitch 对比：`enterTab × 20 (T, P)` 首帧 commit_ms_p95 ≤ baseline × 0.6；会话内同主题 backdrop 构建次数 ≤ 1（bugfix §2.1 / §15.4）
  - [ ] 18.8 开启 flag：双通过后 `FeatureFlags.useCachedDiffuseBackground = true`；归档 A/B 截图对
  - _Requirements: 2.1, 2.2, 5.2, 6.1, 15.4_
  - _Design Section: §3.3_

- [ ] 19. M2 出口验收
  - [ ] 19.1 PBT-1（性能不变量）首次在真机 HitchRecorder 上跑通（hitch_ratio ≤ baseline × 0.4）
  - [ ] 19.2 每主题 §4.1 snapshot 全通过 + Instruments 达到 §6.5 阈值
  - [ ] 19.3 追加 `scripts/backup-before-fix.sh --stage m2-level-1` 增量备份归档
  - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.6_
  - _Design Section: §里程碑划分 · M2_


---

## M3 · 阴影替换评估（Level 2 · 默认 flag 关，每主题独立开关）

> 准入：M2 全部完成。
> 统一子任务范式：实现 + 并行保留原路径（feature flag 默认 false）+ Snapshot 矩阵扩全子集回归（含 scale × cornerRadius × active/inactive）+ 过渡曲线 diff（若涉及）+ Instruments hitch 对比 + 开启条件（每主题独立开关，任一档 diff 超阈值即保守回退）。

- [ ] 20. `CachedSoftShadow` 通用 modifier（跨主题共享策略）
  - [ ] 20.1 实现：新增 `CachedSoftShadow(cornerRadius:size:shadows:)` 视图修饰器，把「同一 cornerRadius + 同一 size 档位 + 同一 shadow 参数集」的 `.shadow` 结果预渲染为 9-patch `UIImage`；缓存 key 含 `displayScale`（§7.1 风险缓解）
  - [ ] 20.2 实现：9-patch 拉伸算法，每 `displayScale` 独立缓存；miss / 尺寸未命中时回退到原 `.shadow`
  - [ ] 20.3 feature flag 默认值 + 开启条件：`FeatureFlags.useCachedSoftShadow = false`；每主题独立开关（`useCachedSoftShadow_Neumorphic / _Muji / _Capsule`）；仅在对应 M3 子任务 snapshot 矩阵通过后按主题默认启用
  - _Requirements: 4.2, 5.1, 6.2_
  - _Design Section: §3.14_

- [ ] 21. `NeumorphicSurfaceBackground` 双层 shadow 9-patch 缓存*（Level 2 · 默认 flag 关）
  - [ ] 21.1 实现：把 `NeumorphicSurfaceBackground` 的双层 shadow + 内 / 外 stroke overlay 合并为 9-patch 预渲染 Image，key = `Key(cornerRadius, size∈{几档离散值}, colorScheme, paletteRevision, displayScale)`
  - [ ] 21.2 实现：`NeumorphicDiffuseGradient`（3 层渐变）+ `NeumorphicReliefTexture`（2 层渐变）合并为一张缓存 Image（独立于软阴影）
  - [ ] 21.3 feature flag 默认值 + 开启条件：`FeatureFlags.useCachedSoftShadow_Neumorphic = false`；snapshot 矩阵（「主题 × scale × 是否 active × cornerRadius」矩阵）全通过才默认启用；任一档 diff > 阈值 → 保守保留原 `.shadow`
  - [ ] 21.4 Snapshot 矩阵扩全回归（§4.1 扩全子集）：`(neumorphic, *)` × light / dark × scale {2x, 3x} × cornerRadius 档位 × active / inactive pixel diff ≤ 1/256
  - [ ] 21.5 Instruments hitch 对比：`(neumorphic, *) + scroll` hitch ratio 与 baseline 比对；`(neumorphic, home) + secondTick + isPlaying` 稳态 hitch ratio ≤ baseline × 0.4（§Fix Checking E2）
  - [ ] 21.6 开启主题独立开关：双通过后 `useCachedSoftShadow_Neumorphic = true`；失败即保持 false 并在 issue log 登记*
  - _Requirements: 5.1, 5.2_
  - _Design Section: §3.6, §3.14_

- [ ] 22. `MujiPaperCardBackground` `.shadow(radius:14)` 预渲染评估*（Level 2 · 默认 flag 关）
  - [ ] 22.1 实现：通过 `CachedSoftShadow` 把 Muji 的 `.shadow(radius:14)` 软阴影预渲染为 9-patch
  - [ ] 22.2 feature flag 默认值 + 开启条件：`FeatureFlags.useCachedSoftShadow_Muji = false`；矩阵通过才默认启用
  - [ ] 22.3 Snapshot 矩阵扩全回归（§4.1）：`(muji, *)` × scale {2x, 3x} × cornerRadius 档 pixel diff ≤ 1/256
  - [ ] 22.4 Instruments hitch 对比：`(muji, *) + scroll` hitch ratio 与 baseline 比对
  - [ ] 22.5 开启主题独立开关：双通过后 `useCachedSoftShadow_Muji = true`；失败即保持 false（保守保留 `.shadow(radius:14)`）*
  - _Requirements: 4.2_
  - _Design Section: §3.14_

- [ ] 23. `CapsuleSurfaceBackground` 双层 shadow 预渲染评估*（Level 2 · 默认 flag 关）
  - [ ] 23.1 实现：通过 `CachedSoftShadow` 把 `CapsuleSurfaceBackground` 的双层 shadow 预渲染为 9-patch
  - [ ] 23.2 feature flag 默认值 + 开启条件：`FeatureFlags.useCachedSoftShadow_Capsule = false`；矩阵通过才默认启用
  - [ ] 23.3 Snapshot 矩阵扩全回归（§4.1）：`(capsule, *)` × scale {2x, 3x} × cornerRadius 档 pixel diff ≤ 1/256
  - [ ] 23.4 Instruments hitch 对比：`(capsule, *) + scroll` hitch ratio 与 baseline 比对
  - [ ] 23.5 开启主题独立开关：双通过后 `useCachedSoftShadow_Capsule = true`；失败即保持 false*
  - _Requirements: 6.2_
  - _Design Section: §3.14_

- [ ] 24. M3 出口验收
  - [ ] 24.1 按主题独立记录 flag 开启 / 保守回退状态到 `.local-backups/.../m3-level-2-report.md`
  - [ ] 24.2 扩充 §4.1 snapshot 矩阵覆盖「主题 × scale × 是否 active × cornerRadius」并全部归档
  - [ ] 24.3 追加 `scripts/backup-before-fix.sh --stage m3-level-2` 增量备份归档
  - _Requirements: 15.1, 15.2, 15.6_
  - _Design Section: §里程碑划分 · M3_


---

## M4 · 阈值回填 · 并行发射清理 · 完整验收

> 准入：M3 全部完成。

- [ ] 25. 用 M1 / M2 / M3 的 Instruments 结果回填 bugfix.md 全部 TBD（按 design §6.5 的 baseline × 倍率）
  - [ ] 25.1 汇总 M1 / M2 / M3 各阶段 Instruments metrics.csv，按 (T, P, scenario) 计算 `after / baseline` 改善比率
  - [ ] 25.2 按 design §6.5 的目标倍率批量替换 bugfix.md 中所有 **TBD**：
    - `hitch_ratio_ms_per_s` ≤ baseline × **0.4**
    - `frame_interval_p95` ≤ baseline × **0.6**
    - `commit_ms_p95` ≤ baseline × **0.6**
    - `body_invalidations_per_second` ≤ baseline × **0.25**
  - [ ] 25.3 校验 bugfix.md 替换后无残留 **TBD** 字样
  - [ ] 25.4 Snapshot 矩阵子集回归（§4.1）：确认回填期间无误改代码导致视觉回归
  - _Requirements: 1.1, 2.1, 3.3, 4.1, 5.1, 5.2, 6.3, 7.1, 7.2, 10.1, 10.2, 11.1, 14.1, 15.1, 15.2, 15.3, 15.4, 15.5, 15.6_
  - _Design Section: §6.5, §里程碑划分 · M4_

- [ ] 26. 移除 `globalThemeRevision` 旧发射路径（design §7.5 过渡期混合态清理）
  - [ ] 26.1 实现：全仓库检索所有订阅 `SettingsManager.globalThemeRevision` 的代码路径；确认全部已迁移到 `ThemeChangeBus` / `paletteRevision` / `rendererRevision`
  - [ ] 26.2 实现：移除 `SettingsManager` 内在事件源上并行 `globalThemeRevision.&+= 1` 的语句
  - [ ] 26.3 实现：保留 `var globalThemeRevision: UInt64 { paletteRevision &+ rendererRevision }` 只读 getter（向后兼容）
  - [ ] 26.4 单元测试：迁移期 A/B 断言两路事件同步后最终语义一致；移除后单路事件源仍覆盖原全部消费者
  - [ ] 26.5 Snapshot 矩阵子集回归（§4.1）：主题 / colorScheme / 封面色变化下 20 (T, P) 稳态截图等价
  - [ ] 26.6 Instruments hitch 对比：全场景 baseline × 倍率全部达标
  - _Requirements: 1.1, 1.2, 1.3, 3.1, 3.2, 12.2_
  - _Design Section: §7.5_

- [ ] 27. 跑完整 Integration Tests 与 Property 1~6 全闭环
  - [ ] 27.1 全流程 snapshot 对比（§Integration Tests）：冷启 → 依次进入 4 tab × 5 主题 = 20 组合，每组拍稳态 snapshot 与 F 比对
  - [ ] 27.2 切主题 / 深浅色端到端（§Integration Tests）：`(T₁, P) → (T₂, P) → colorScheme → Dynamic Type` 最终稳态等价
  - [ ] 27.3 播放中 tab 切换（§Integration Tests）：播放 → 连切 20 次 tab → FloatingBar 反映最新状态；事件无丢
  - [ ] 27.4 备份 / 还原闭环（§Integration Tests）：真实跑 `scripts/backup-before-fix.sh` → 故意改动一个文件 → `scripts/restore-backup.sh` → 断言还原一致
  - [ ] 27.5 PBT-1（性能不变量）、PBT-2（稳态等价）、PBT-3（过渡曲线）、PBT-4（功能等价）、PBT-5（备份还原）、PBT-6（迁移兼容）全部通过
  - [ ] 27.6 Fix Checking 全部 7 条 test case 通过（§Testing Strategy · Fix Checking）
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 3.3, 4.1, 5.1, 5.2, 5.3, 5.4, 5.5, 5.7, 15.1, 15.2, 15.3, 15.4, 15.5, 15.6_
  - _Design Section: §Testing Strategy · Integration Tests, §Correctness Properties_

- [ ] 28. 归档最终报告
  - [ ] 28.1 生成 baseline vs after metrics 对比报告（CSV + 可读 Markdown），归档到 `.local-backups/main-tabs-theme-frame-drop-<UTC>/final-report/`
  - [ ] 28.2 汇总 M1 / M2 / M3 的 snapshot diff 报告 / 过渡曲线报告 / Instruments trace 索引到同目录
  - [ ] 28.3 记录每个主题 Level 2 flag 的最终开启 / 保守回退状态（对应 Task 21.6 / 22.5 / 23.5）
  - [ ] 28.4 追加一次 `scripts/backup-before-fix.sh --stage m4-final` 最终备份归档
  - [ ] 28.5 Property 1 ~ Property 6 全部通过 → 本 bug 结案
  - _Requirements: 5.1, 5.2, 5.3, 5.5, 5.7, 15.6_
  - _Design Section: §里程碑划分 · M4_
