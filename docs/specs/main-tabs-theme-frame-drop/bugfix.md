# Bugfix Requirements Document — 主 tab × 主题组合掉帧

## Introduction

Mono（SwiftUI + FFmpeg，iOS 17+）在 4 个主 tab 主页面（Home / Podcast / Library / Profile）× 5 个主题（default / muji / manga / neumorphic / capsule）= **20 种组合** 下，出现普遍可观测的掉帧、首屏卡顿、滚动抖动与主题/外观切换时的全屏一卡等性能缺陷。

本文档仅定位"什么条件下会掉帧、表现成什么样、哪些行为必须保留"，不约束任何修复方案。具体修复路径（例如是否引入全局 backdrop、是否拆 `globalThemeRevision`、是否替换 `AnyView` 工厂、是否将 Canvas 缓存为静态纹理等）全部留到 design 阶段讨论。

**Bug 类型：** 性能 bug（非功能性缺陷）。用户可感知症状为"掉帧 / 卡顿 / jitter / 首屏白屏拉长 / 主题切换时整页闪滞"，但无崩溃、无数据错误、无视觉错位。

**影响范围：** 覆盖 App 启动后最核心的 4 条导航路径，且越是"重主题"（manga / neumorphic / capsule）、越是播放中（持续有歌词/进度推送）、越是在 ProMotion 设备以外（60Hz 屏更容易超出 16.67ms 预算）越明显。

**术语：**

- **Hitch：** 单帧主线程 commit 耗时超过目标帧预算（60Hz ≈ 16.67ms，120Hz ≈ 8.33ms）导致 CoreAnimation 掉帧。
- **F（原函数）：** 当前未修复的 4 个 tab 主页面渲染管线，包含 `ContentView.tabViewCore` → `theme.makeHomeView()/makePodcastView()/makeLibraryView()/makeProfileView()` → `ThemedPageBackground` + 各主题根视图的当前实现。
- **F'（修复后函数）：** 未来修复后的等价渲染管线。本文档不规定 F' 形态。
- **Tab 组合 `(T, P)`：** T ∈ { default, muji, manga, neumorphic, capsule }（`GlobalThemeId` 中未被标记 removed 的 5 个值），P ∈ { home, podcast, library, profile }。

## Bug Analysis

### Current Behavior (Defect)

以下列出在当前实现（F）下可被观察到的缺陷行为。条件 `(T, P)` 表示"在主题 T 下进入 tab P"。

#### 1. 主题失效传播过广（全局 revision 抖动）

1.1 WHEN 用户切换系统深浅色、或在设置页调整主题色（导致 `SettingsManager.activeColorScheme.didSet` 或 `notifyThemeCustomizationChanged()` 触发）THEN `SettingsManager.globalThemeRevision` `&+=` 1，4 个 tab 视图、常驻的 floating bar、所有订阅 `globalThemeRevision` 的 `@Published` 订阅者同时失效并重算 body，在主线程产生 **单帧 > 帧预算** 的 commit，视觉上表现为"整屏冻一下"。

1.2 WHEN 播放中封面亮度变化触发颜色再采样（仍归并进 `globalThemeRevision`）THEN 同样路径放大为周期性 jitter，而非单次闪烁。

1.3 WHEN `FloatingBarPlaybackModel` 上层容器使用 `.id("\(themeId)-\(revision)")` 作为 identity THEN `globalThemeRevision` 任何一次自增都会让常驻 floating bar **整条换 identity**、重新挂载子树，而非增量 diff。

#### 2. 每个 tab 各画一份 backdrop

2.1 WHEN 用户在 4 个 tab 间切换（`ThemeRenderContext.providesGlobalBackdrop == false` 恒成立）THEN `ThemedPageBackground` 在每个 tab 内部各自绘制一份 `ThemeRenderBackdrop`，同一主题的背景在 App 生命周期内被重复构建 **至少 N=4 次**（每个 tab 一次，切换一次再重建一次）。

2.2 WHEN 背景层含 `ThemeCustomDiffuseBackground` THEN 其 `baseLayer / accentLayer` 为 `Canvas + blur(radius: 38/44) + blendMode(.softLight)` 双层结构，进入任意 tab 首帧即承担这笔开销，多 tab 叠加后成倍放大。

#### 3. Manga 主题特定缺陷

3.1 WHEN `(manga, home)` 打开 THEN `MangaRootBackdrop` 连续绘制 3 层 `Canvas` 纹理且未使用 `drawingGroup()` 做离屏合成缓存，每次 body 失效都要重算纹理路径。

3.2 WHEN `(manga, *)` 可视区域出现卡片 THEN 每张 `MangaCardBackground` 内含 4 层填充 + 1 层 `MangaDotsTexture(Canvas)` + `.themeRenderSurfaceLayer()` 触发 `compositingGroup()`；一屏 N 张卡时绘制复杂度 ∝ N。

3.3 WHEN `(manga, home)` 中 `mangaDailySection` 或 `mangaNewSongsSection` 被滚动 THEN `scrollTransition` 每帧重算 rotation，与 `MangaDotsTexture` 叠加后导致滚动期间帧间隔不稳。

#### 4. Muji 主题特定缺陷

4.1 WHEN `(muji, *)` 渲染卡片列表 THEN 每张 `MujiPaperCardBackground` overlay 一次 `MujiPaperTexture(Canvas)`，一屏 ~10 张卡约 **≥ 11 次 Canvas 重画**（含根背景）。

4.2 WHEN `(muji, *)` 同屏卡片继续叠加 `.shadow(radius: 14)` THEN 大半径软阴影栅格化成本叠加到每一张卡上。

#### 5. Neumorphic 主题特定缺陷

5.1 WHEN `(neumorphic, *)` 渲染任何软拟物卡片 THEN `NeumorphicSurfaceBackground` 为每张卡贴 **双层 shadow + 内/外 stroke overlay**，软阴影在 GPU 上属于高成本操作，列表滚动期间持续累计。

5.2 WHEN `(neumorphic, *)` 打开 THEN 背景层叠放 `ThemeCustomDiffuseBackground` + `NeumorphicDiffuseGradient`（3 层线性渐变）+ `NeumorphicReliefTexture`（2 层线性渐变）共约 6 层绘制对象，首帧 commit 偏重。

5.3 WHEN `(neumorphic, home)` 且播放中 THEN `NeumorphicVinyl` 的 `TimelineView` 以动画 schedule 全速旋转，即使视图不在焦点 tab 也可能被 SwiftUI 保留渲染依赖，造成持续 CPU/GPU 占用。

#### 6. Capsule 主题特定缺陷

6.1 WHEN `(capsule, *)` 打开 THEN `CapsuleRootBackdrop` = `ThemeCustomDiffuseBackground` + 一个含 5 个旋转胶囊的 `Canvas`，每帧重算 5 条胶囊的 transform。

6.2 WHEN `(capsule, *)` 显示卡片 THEN `CapsuleSurfaceBackground` 双层 shadow 同样放大滚动期间的 GPU 压力。

6.3 WHEN `(capsule, home)` 停留 THEN `bannerTimer` 每 5.4s 触发自动翻页，翻页动画期间伴随 `CapsuleRootBackdrop` 的 `Canvas` 重绘，产生周期性 hitch。

#### 7. Default 主题特定缺陷

7.1 WHEN `(default, *)` 打开 THEN `MonoBackground.defaultSystemBackground` 内含 `Canvas + blur(60) + drawingGroup()`，`blur(60)` 大半径模糊本身成本高，加 `drawingGroup()` 会强制光栅化整层。

7.2 WHEN `(default, home)` 打开 THEN 顶部叠一个 **300pt 高** 的 `ParallaxMountainHeader`，首屏 layout 参与滚动视差计算。

7.3 WHEN `(default, home)` 中显示一言 hitokoto THEN 该组件含 `Canvas` 绘制，body 任一依赖变化均触发重绘。

#### 8. 主页工厂使用 AnyView

8.1 WHEN `ContentView.tabViewCore` 通过 `theme.makeHomeView() / makePodcastView() / makeLibraryView() / makeProfileView()`（返回 `AnyView`）获取主页 THEN SwiftUI 类型擦除打断 body diff，任一上游依赖变化都会整棵子树重建，而不是增量更新。

#### 9. PodcastView 内部非 lazy 横向滚动

9.1 WHEN `(*, podcast)` 进入视野 THEN `PodcastView` 外层虽为 `LazyVStack`，但内部 `categoriesSection / newestPrograms / chartPrograms / newcomerRadios / broadcastChannels` 采用 **非 lazy 的横向 `ScrollView + HStack`**，section 一旦进入可视范围即全量构建所有横向 item。

9.2 WHEN 上述横向列表叠加 `scrollTransition(scaleEffect)` THEN 每个 item 每帧都重算 scale，滚动期间主线程持续产生 layout/draw 工作。

#### 10. LibraryView 预热相邻页

10.1 WHEN `(default, library)` 打开 THEN 使用 `TabView(.page)` 4 页结构，底层 `UIPageViewController` 预热相邻页，首屏即构建 ≥ 2 页完整内容。

10.2 WHEN `(neumorphic, library)` 打开 THEN 在 10.1 基础上再叠 `matchedGeometryEffect`，每次横滑期间匹配几何需要额外的 layout pass。

#### 11. ProfileView 订阅爆炸

11.1 WHEN `(*, profile)` 打开 THEN 同时挂 4 个 `onReceive`（`refreshProfilePublisher`、`viewModel.$userProfile`、`DownloadManager.$downloadedSongIds.map(count)`、`LocalPlaylistManager.$playlists.map(count)`），任何一路事件都会触发根 body 重算。

11.2 WHEN 播放中停留在 `(*, profile)` THEN 多个 `RecentRadioStrip` 订阅 `PlayerManager.$history / $currentSong / $isPlaying`，由于 `$currentSong` / `$isPlaying` 播放时高频变化，Profile tab 持续重绘。

#### 12. Floating bar 歌词高频推送

12.1 WHEN 播放中歌词每句切换 THEN `FloatingBarPlaybackModel` 的订阅链将变化推送到常驻于所有 4 个 tab 的 floating bar 容器，触发每句至少一次 body 重算。

12.2 WHEN 同时 `globalThemeRevision` 变化 THEN 见 1.3，容器 `.id(...)` 重新挂载加剧抖动。

#### 13. 常驻 TimelineView 动画

13.1 WHEN App 进入任意 `(T, P)` THEN `TabBottomAccessoryPlaceholder` 呼吸缩放动画常驻运行；各主题 `NowPlayingIndicator` 等同样使用 `TimelineView(.animation)`，即便当前主题/tab 不需要该动画也持续推进时间依赖。

#### 14. LibraryView 手势仲裁冲突

14.1 WHEN `(*, library)` 用户下拉/上滑 THEN `libraryHeaderCollapseProgress` 的 `DragGesture + withAnimation` 与内部 `ScrollView` 的原生滚动手势发生仲裁冲突，滚动起手阶段出现掉帧与滑动"黏滞"。

#### 15. 组合严重度速览

15.1 WHEN 进入下列组合 THEN 在当前 F 下预计严重度分级如下（仅基于代码推断，真实阈值与测量留到 design 阶段）：

| 组合 `(T, P)` | 预计严重度 | 主因聚合 |
|---|---|---|
| (manga, home) | 高 | 3.1 + 3.2 + 3.3 + 2.2 + 8.1 |
| (neumorphic, home) | 高 | 5.1 + 5.2 + 5.3 + 12.1 + 8.1 |
| (capsule, home) | 高 | 6.1 + 6.2 + 6.3 + 2.2 + 8.1 |
| (default, home) | 中高 | 7.1 + 7.2 + 7.3 + 8.1 |
| (muji, home) | 中高 | 4.1 + 4.2 + 2.2 + 8.1 |
| (manga, podcast) | 高 | 3.2 + 9.1 + 9.2 + 2.2 |
| (neumorphic, podcast) | 高 | 5.1 + 5.2 + 9.1 + 9.2 |
| (capsule, podcast) | 中高 | 6.1 + 6.2 + 9.1 + 9.2 |
| (default, podcast) | 中 | 7.1 + 9.1 + 9.2 |
| (muji, podcast) | 中 | 4.1 + 4.2 + 9.1 + 9.2 |
| (neumorphic, library) | 高 | 10.1 + 10.2 + 5.1 + 14.1 |
| (manga, library) | 中高 | 3.2 + 14.1 + 2.2 |
| (default, library) | 中高 | 10.1 + 14.1 + 7.1 |
| (capsule, library) | 中 | 6.2 + 14.1 |
| (muji, library) | 中 | 4.1 + 14.1 |
| (manga, profile) | 中高 | 3.2 + 11.1 + 11.2 |
| (neumorphic, profile) | 中高 | 5.1 + 11.1 + 11.2 |
| (capsule, profile) | 中 | 6.2 + 11.1 + 11.2 |
| (default, profile) | 中 | 7.1 + 11.1 + 11.2 |
| (muji, profile) | 中 | 4.1 + 11.1 + 11.2 |

#### 16. 汇总：用户可观测症状

16.1 WHEN 用户切换 tab THEN 切换动画首帧出现可感知卡顿（包括首次进入新 tab、以及二次回切回已构建过的 tab 两种场景）。

16.2 WHEN 任意 `(T, P)` 首次打开 THEN 首屏 layout 出现延迟（表现为 tab 切换后短暂白屏 / 背景延迟上色）。

16.3 WHEN 用户在 `(T, P)` 内滚动 THEN 滚动期间帧间隔不稳，表现为列表滑动"顿挫"或滚停瞬间卡一下。

16.4 WHEN 用户停留在任意 `(T, P)` 且正在播放 THEN 歌词每句切换、进度每秒更新在 UI 上持续产生 jitter。

16.5 WHEN 用户切换深浅色 / 主题色 / 主题（`globalThemeRevision` 自增）THEN 整个 App（包括非当前 tab）出现一次全屏卡顿。

### Expected Behavior (Correct)

以下是修复后（F'）必须达到的行为约束。具体阈值中标注为 **TBD** 的需在 design 阶段由用户确认或通过基线测量敲定，本文档只给出不变量雏形。

#### 1. 失效传播收敛

1.1 WHEN 用户切换深浅色或调整主题色 THEN 系统 SHALL 将失效范围限制为"与该变化真正相关的视图子树"，整屏同时失效的 body 数量 SHALL ≤ **TBD** 且非当前 tab 的 view body **SHALL NOT** 在单次切换中重算超过 1 次。

1.2 WHEN 播放中封面亮度变化 THEN 系统 SHALL 将该变化的订阅者限制在真正消费该颜色的组件（例如 floating bar、now playing indicator），**SHALL NOT** 通过 `globalThemeRevision` 波及 4 个 tab 根 body。

1.3 WHEN `globalThemeRevision` 自增 THEN floating bar 容器 **SHALL NOT** 仅因 revision 变化就整体换 identity（即不得因 revision 导致子树卸载—重建）。

#### 2. Backdrop 共享

2.1 WHEN 用户在 4 个 tab 间切换 THEN 同一主题的 backdrop 实例在 App 单次会话内 SHALL 被构建不超过 **N=TBD（目标 ≤ 1，允许横竖屏/尺寸变化重建）** 次。

2.2 WHEN 任意 `(T, P)` 首屏显示 THEN 背景层的 `Canvas + blur` 组合 SHALL 以离屏缓存或静态 `Image` 形式复用，**SHALL NOT** 在每次 body 失效时重走路径栅格化。

#### 3. Manga

3.1 WHEN `(manga, home)` 打开 THEN `MangaRootBackdrop` 的 3 层 `Canvas` 纹理 SHALL 被缓存为静态合成结果（例如 `drawingGroup()` 或预渲染位图），**SHALL NOT** 在每次 body 失效时重算。

3.2 WHEN `(manga, *)` 可视区域出现卡片 THEN 单张 `MangaCardBackground` 的绘制层数 SHALL ≤ **TBD**，且 `MangaDotsTexture` 在滚动期间 **SHALL NOT** 重新光栅化。

3.3 WHEN `(manga, home)` 被滚动 THEN `scrollTransition` 的每帧变换 SHALL 限定在 GPU 可承受的 transform 范围，60Hz 设备滚动期间平均 hitch ratio SHALL ≤ **TBD%**。

#### 4. Muji

4.1 WHEN `(muji, *)` 渲染卡片列表 THEN 单屏内 `MujiPaperTexture(Canvas)` 的实际 draw 次数 SHALL ≤ **TBD**（目标：通过共享纹理降到常数级）。

4.2 WHEN 卡片叠加 `.shadow` THEN 软阴影 SHALL 通过离屏缓存或替代实现（如 `Image` 预渲染阴影），避免每帧栅格化。

#### 5. Neumorphic

5.1 WHEN `(neumorphic, *)` 渲染卡片 THEN 软阴影 SHALL 被缓存或替换为低成本等效表现，滚动期间平均 hitch ratio SHALL ≤ **TBD%**。

5.2 WHEN `(neumorphic, *)` 打开 THEN 背景层堆叠（diffuse + 渐变 + relief）SHALL 合并为不超过 **TBD** 个绘制对象，首帧 commit 耗时 SHALL ≤ **TBD ms**。

5.3 WHEN `(neumorphic, home)` 且播放中 THEN `NeumorphicVinyl` 的 `TimelineView` SHALL 仅在该视图实际可见时推进，非当前 tab 或被覆盖时 SHALL 暂停时间依赖。

#### 6. Capsule

6.1 WHEN `(capsule, *)` 打开 THEN `CapsuleRootBackdrop` 中的 5 胶囊 `Canvas` SHALL 以 transform 动画（非重绘）或缓存形式实现，**SHALL NOT** 每帧重走 `Canvas` draw 路径。

6.2 WHEN `(capsule, *)` 显示卡片 THEN `CapsuleSurfaceBackground` 的软阴影遵循 5.1 同一约束。

6.3 WHEN `(capsule, home)` 停留且 `bannerTimer` 翻页 THEN 翻页动画期间 hitch count SHALL ≤ **TBD**，周期性卡顿 SHALL NOT 可被用户感知。

#### 7. Default

7.1 WHEN `(default, *)` 打开 THEN `defaultSystemBackground` 的 `Canvas + blur(60) + drawingGroup` SHALL 被替换为静态缓存或系统 `Material`，首帧 blur 成本 SHALL ≤ **TBD ms**。

7.2 WHEN `(default, home)` 打开 THEN `ParallaxMountainHeader` 的 300pt 区域 layout SHALL 不阻塞首屏可交互；首屏可交互时间 SHALL ≤ **TBD ms**。

7.3 WHEN `(default, home)` 显示 hitokoto THEN 其 `Canvas` SHALL 不随无关 body 失效重绘。

#### 8. AnyView

8.1 WHEN 主页工厂返回主页视图 THEN 其类型擦除 SHALL NOT 导致上游任一依赖变化整棵子树重建（可通过具体类型、`@ViewBuilder` 或 identity 稳定化实现，具体方案留 design）。

#### 9. Podcast

9.1 WHEN `(*, podcast)` 任一横向 section 进入视野 THEN 其 item 构建 SHALL 为 lazy（首次仅构建可视范围内 item），不可见 item 的 body SHALL NOT 在 section 初次进入视野时被构建。

9.2 WHEN 横向列表滚动 THEN `scrollTransition` 的缩放 SHALL 通过 GPU transform 完成，**SHALL NOT** 触发每帧的 layout 或 body 重算。

#### 10. Library

10.1 WHEN `(default, library)` 打开 THEN 相邻页预热构建的内容 SHALL ≤ **TBD**（目标：相邻页仅构建骨架，不预取重资源）。

10.2 WHEN `(neumorphic, library)` 横滑 THEN `matchedGeometryEffect` 的 layout pass 次数 SHALL ≤ **TBD**。

#### 11. Profile

11.1 WHEN `(*, profile)` 打开 THEN 4 个 `onReceive` 订阅 SHALL 被合并或下沉到真正消费该数据的子视图，根 body 失效次数 SHALL ≤ **TBD**。

11.2 WHEN 播放中停留在 `(*, profile)` THEN `RecentRadioStrip` 的订阅 SHALL 不因 `$currentSong / $isPlaying` 高频变化而重绘整条 strip，重绘范围 SHALL 限定在真正依赖这些状态的子组件。

#### 12. Floating bar

12.1 WHEN 歌词每句切换 THEN floating bar 的重算 SHALL 限定在显示歌词的子组件，**SHALL NOT** 波及 floating bar 根容器或同 tab 其他子树。

12.2 WHEN `globalThemeRevision` 变化 THEN floating bar 容器 identity SHALL 保持稳定（见 1.3）。

#### 13. TimelineView 动画

13.1 WHEN 视图不可见（非当前 tab、被覆盖或进入后台）THEN 常驻 `TimelineView(.animation)` SHALL 暂停时间推进，恢复可见时 SHALL 无缝续播。

#### 14. Library 手势

14.1 WHEN `(*, library)` 下拉/上滑 THEN `libraryHeaderCollapseProgress` 的手势 SHALL 与内部 `ScrollView` 协同（通过 `simultaneousGesture` 或统一滚动偏移驱动），起手阶段 hitch count SHALL = **0**（TBD：允许极少数首触发 hitch）。

#### 15. 性能不变量（Property-Based Test 雏形）

以下不变量用于后续 property test / 性能基线测试。具体阈值 **TBD** 由 design 阶段敲定。

15.1 WHEN 用户切换 tab（任意 `(T₁, Pᵢ) → (T₁, Pⱼ), i ≠ j`）THEN 切换期间主线程单帧 commit 耗时 SHALL ≤ **TBD ms**（建议 60Hz：16.67ms；120Hz：8.33ms），hitch count SHALL ≤ **TBD**。

15.2 WHEN 用户在任意 `(T, P)` 内滚动 THEN 已提交帧间隔 P95 SHALL ≤ **TBD ms**，hitch ratio SHALL ≤ **TBD%**。

15.3 WHEN 播放中停留在任意 `(T, P)` THEN 每秒由"歌词/进度/封面色"事件触发的根 body 重算次数 SHALL ≤ **TBD**。

15.4 WHEN 用户在 App 单次会话内依次访问 4 个 tab THEN 同一主题的 backdrop 实例构建次数 SHALL ≤ **TBD**（目标 ≤ 1）。

15.5 WHEN `globalThemeRevision` 自增一次 THEN 被触发 body 重算的视图数量 SHALL ≤ **TBD**（目标：仅当前 tab 中消费对应属性的节点）。

15.6 FOR ALL `(T, P)` WHERE `T ∈ {default, muji, manga, neumorphic, capsule}` AND `P ∈ {home, podcast, library, profile}`：
  - fix checking：上述 15.1 ~ 15.5 在每个组合下 SHALL 成立；
  - preservation checking：非性能属性（视觉、功能、可访问性）SHALL 与 F 行为一致（见 Unchanged Behavior）。

### Unchanged Behavior (Regression Prevention)

以下行为在修复后必须保持与当前 F 完全一致。可表达为 `∀X WHERE ¬isBugCondition(X): F(X) = F'(X)`，其中 X 取视觉/功能/数据维度。

#### 1. 视觉一致性（硬约束：零视觉回归）

**本节为修复的硬约束。任一 F' 的实现若在稳态下引起可观测的视觉差异，即视为回归，必须回滚。**

1.1 WHEN 任意 `(T, P)` 在稳态下（非滚动中、非动画中间帧）截图 THEN 系统 SHALL CONTINUE TO 呈现与当前 F **逐像素等价** 的结果，允许的差异仅限于：
  - 文本抗锯齿（anti-aliasing）在亚像素层面的极小抖动；
  - 由 SwiftUI / UIKit 内部实现差异导致的、肉眼不可辨的 ≤ 1 像素舍入；
  - 除此之外 **SHALL NOT** 存在色差、圆角差、阴影半径差、间距差、描边粗细差、字体字重差、纹理密度差、模糊半径差、blendMode 差。

1.2 WHEN 主题为 manga / muji / neumorphic / capsule THEN 系统 SHALL CONTINUE TO 呈现各主题的标志性视觉语言（manga 的纹理与 dots、muji 的纸质纹理、neumorphic 的软阴影浮雕、capsule 的胶囊背景与双层阴影），且 **纹理密度、阴影观感、阴影颜色、阴影偏移、阴影半径、描边宽度 SHALL 与 F 保持一致**。

1.3 WHEN 主题为 default 且位于 home THEN 系统 SHALL CONTINUE TO 显示 `ParallaxMountainHeader` 的视差效果与 hitokoto 内容；视差位移曲线、山脊颜色、天空渐变 SHALL 与 F 一致。

1.4 WHEN `(neumorphic, home)` 且播放中 THEN 系统 SHALL CONTINUE TO 显示 `NeumorphicVinyl` 的旋转动画（仅要求在不可见时暂停、可见时观感一致，恢复可见后的角度相位 SHALL 无可感知跳变）。

1.5 WHEN `(capsule, home)` 停留 5.4s THEN 系统 SHALL CONTINUE TO 按 `bannerTimer` 自动翻页；翻页过渡曲线与当前实现一致。

1.6 WHEN 任意 `(T, P)` 处于滚动中 THEN `scrollTransition` 产生的 scale / rotation / opacity 曲线 SHALL 与 F 完全一致（允许通过 GPU transform 而非重绘实现，但视觉输出 SHALL 无差异）。

1.7 WHEN 切换 `globalThemeRevision`、深浅色、主题色 THEN 系统 SHALL CONTINUE TO 在"稳态到稳态"之间产生与 F 等价的最终视觉；过渡期间允许性能改善但 **SHALL NOT** 出现新的闪烁、色带、裂帧或短暂错位。

1.8 WHEN F' 引入任何"离屏缓存 / 预渲染位图 / drawingGroup / 共享纹理 / 系统 `Material` 替换"等手段 THEN 该缓存/替换结果 SHALL 在目标设备刷新率、色域（sRGB / Display P3）、深浅色、动态字体大小下产出与 F 等价像素；在任一条件下出现差异时，对应优化 SHALL 被回滚或加上条件开关（例如仅在支持等价输出的路径启用）。

#### 2. 功能一致性

2.1 WHEN 用户切换深浅色或主题色 THEN 系统 SHALL CONTINUE TO 更新所有需要反映该变化的 UI 元素（仅要求失效范围收敛，不要求取消更新本身）。

2.2 WHEN 用户在 `(*, podcast)` 滚动横向列表 THEN 系统 SHALL CONTINUE TO 显示 `categoriesSection / newestPrograms / chartPrograms / newcomerRadios / broadcastChannels` 的全部数据项（仅要求构建时机从 eager 改为 lazy，不要求删减内容）。

2.3 WHEN 用户在 `(default, library)` 或 `(neumorphic, library)` 横滑翻页 THEN 系统 SHALL CONTINUE TO 支持 `TabView(.page)` 的翻页交互与 `matchedGeometryEffect` 的视觉过渡效果。

2.4 WHEN `(*, profile)` 打开 THEN 系统 SHALL CONTINUE TO 根据 `refreshProfilePublisher / $userProfile / $downloadedSongIds / $playlists` 的最新值呈现正确数据。

2.5 WHEN 播放中 THEN 系统 SHALL CONTINUE TO 在所有 4 个 tab 上显示 floating bar，并反映最新的歌词、进度、封面、播放状态。

2.6 WHEN `(*, library)` 用户下拉/上滑 THEN 系统 SHALL CONTINUE TO 按照 `libraryHeaderCollapseProgress` 的逻辑折叠/展开 header（仅要求手势仲裁不再产生 hitch，不改变最终折叠状态的语义）。

#### 3. 数据与副作用一致性

3.1 WHEN `globalThemeRevision` 变化 THEN 系统 SHALL CONTINUE TO 通知需要响应该变化的订阅者（仅要求不以"整屏广播"的方式实现）。

3.2 WHEN `FloatingBarPlaybackModel` / `PlayerManager` / `HomeViewModel` / `LyricViewModel` / `SettingsManager` 发出事件 THEN 系统 SHALL CONTINUE TO 保证事件被真正消费该事件的视图正确处理（仅要求订阅下沉 / 合并，不允许丢事件）。

3.3 WHEN `iOS 17+` 条件下 THEN 系统 SHALL CONTINUE TO 仅使用 iOS 17+ 可用 API（不得为了性能回退到更低版本实现而破坏现有最低版本策略）。

#### 4. 迁移兼容

4.1 WHEN `GlobalThemeId` 的 removed 值被迁移 THEN 系统 SHALL CONTINUE TO 保持当前迁移逻辑与 `notifyThemeCustomizationChanged()` 语义不变（迁移路径不在本 bug 修复范围内）。

#### 5. 修复前置：完整项目备份（硬约束）

**本节为修复前置条件。未完成备份即 SHALL NOT 开始任何修复类代码变更。**

5.1 WHEN 本 bug 的 tasks 阶段启动 THEN 第一项任务 SHALL 为"完整项目备份"，在任何代码修改之前完成。

5.2 WHEN 备份被执行 THEN 备份产物 SHALL 同时满足以下条件：
  - 备份路径位于仓库根目录下 `.local-backups/main-tabs-theme-frame-drop-<UTC 时间戳>/`；
  - 备份 **SHALL** 包含：当前工作树中除 `.gitignore` 已忽略条目与第三方本地依赖目录（`NeteaseCloudMusicAPI-Swift/`、`ffmpeg-swift/`、`QQMusicKit/`、`HiconIcons/`、`.build/`、`DerivedData/`、`.kiro/`、`.codex-backups/` 等）之外的全部项目源码、资源、Xcode 工程、`Package.swift`、`Info.plist`、`Mono.entitlements`、`Secrets.xcconfig.example` 等工程描述文件；
  - 备份 **SHALL** 记录以下元数据（`manifest.txt` 或 `manifest.json`）：当前 `git rev-parse HEAD`、`git status --short` 快照、`git diff` 快照、备份开始/结束 UTC 时间、备份执行者（`whoami`）、macOS 版本与 Xcode 版本；
  - 备份 **SHALL NOT** 包含 `.env`、`Secrets.xcconfig`、任何密钥文件、任何 `.ipa / .app / .dSYM / .xcarchive`、任何用户数据。

5.3 WHEN 备份完成 THEN 系统 SHALL 通过以下两条独立校验确认备份可还原：
  - 对备份目录计算 `find … -type f | sort | xargs shasum -a 256` 并写入 `manifest.sha256`；
  - 在独立临时目录中随机抽取 ≥ 5 个关键文件（至少覆盖 `Package.swift`、`Sources/Mono/MonoApp.swift`、`Sources/Mono/Views/ContentView.swift`、`.kiro/specs/main-tabs-theme-frame-drop/bugfix.md`）做逐字节 `diff` 比对与当前工作树一致。

5.4 WHEN 当前工作树存在未提交变更（`git status --short` 非空）THEN 备份 **SHALL** 在备份前额外执行 `git stash create` 并把返回的 commit hash 一并写入 `manifest.txt`（不改变工作树），以保证未提交内容也有可追溯的 git 对象作为保底。

5.5 WHEN 修复过程中发现任何回归 THEN 系统 SHALL 能够通过备份 + `manifest.txt` 中记录的 `git rev-parse HEAD` 在同一本地环境下完整复现修复前状态。

5.6 WHEN 每进入一个新的代码修改阶段（对应 tasks 阶段的阶段性里程碑）THEN 系统 MAY 追加一次增量备份（路径 `.local-backups/main-tabs-theme-frame-drop-<阶段名>-<UTC 时间戳>/`），此为可选；但 5.1 所要求的"修复前完整备份"为必须项。

5.7 **备份产物 SHALL NOT 被提交到仓库**：`.local-backups/` 路径以 `.local-backups/` 前缀匹配，应加入或已被 `.gitignore` 覆盖；若未覆盖，tasks 阶段 SHALL 先补齐 `.gitignore` 再执行备份。

---

## 附录：范围说明

- **In scope：** 4 个主 tab 的主页面（Home / Podcast / Library / Profile）在 5 个活跃主题下的渲染性能缺陷定位。
- **修复约束：**
  - **视觉零回归**（Unchanged Behavior §1）——F' 必须与 F 在稳态下逐像素等价，在滚动/过渡期间视觉曲线等价，不得以"视觉简化"换取性能。
  - **修复前必须完整备份**（Unchanged Behavior §5）——未完成备份不允许启动修复；备份路径 `.local-backups/main-tabs-theme-frame-drop-<UTC 时间戳>/`，含工作树与 git 元数据，并做 SHA256 与抽样逐字节校验。
- **Out of scope：**
  - 具体修复方案与实现路径（属于 design 阶段）。
  - 非主 tab 页面（设置、歌词全屏、播放器详情、MV、播客详情等）的性能问题。
  - 数据层（请求合并、缓存策略、磁盘 I/O）性能问题，除非直接驱动上述 UI 重绘。
  - `GlobalThemeId` 中已被标记 removed 的 5 个主题的性能（仅迁移兼容）。
  - 真实阈值标定（所有 **TBD** 值）——留到 design 阶段通过 Instruments / SwiftUI Instrument / Hitch Ratio 基线测量后确定。

## 附录：Bug Condition 与 Property 雏形

```pascal
// 输入类型：一次用户操作或时间推进
TYPE Interaction = RECORD
  theme: GlobalThemeId        // default | muji | manga | neumorphic | capsule
  tab: MainTab                // home | podcast | library | profile
  action: ActionKind          // enterTab | scroll | lyricTick | secondTick
                              // | themeRevisionBump | colorSchemeFlip
  isPlaying: boolean
  deviceRefreshRate: number   // 60 | 120
END

FUNCTION isBugCondition(X: Interaction)
  OUTPUT: boolean
  // 当前 F 在该交互下会越过帧预算或产生可感知 jitter
  RETURN exists_hitch(F, X)
         OR mainthread_commit_ms(F, X) > frameBudget(X.deviceRefreshRate)
         OR redundant_body_invalidations(F, X) > allowedBudget
END FUNCTION

// Fix Checking
FOR ALL X WHERE isBugCondition(X) DO
  result ← run(F', X)
  ASSERT NOT exists_hitch(F', X)
  ASSERT mainthread_commit_ms(F', X) <= frameBudget(X.deviceRefreshRate)
  ASSERT redundant_body_invalidations(F', X) <= allowedBudget
END FOR

// Preservation Checking
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT visual_equivalent(F(X), F'(X))          // Unchanged §1：稳态逐像素等价
  ASSERT transition_curve_equivalent(F(X), F'(X)) // Unchanged §1.6 / §1.7：滚动/主题切换过渡视觉等价
  ASSERT functional_equivalent(F(X), F'(X))
  ASSERT data_side_effects(F(X)) = data_side_effects(F'(X))
END FOR

// Pre-fix Gate（Unchanged §5，硬前置）
REQUIRE backup_dir EXISTS AT `.local-backups/main-tabs-theme-frame-drop-<UTC>/`
REQUIRE manifest.txt RECORDS `git rev-parse HEAD` AND working tree snapshot
REQUIRE manifest.sha256 MATCHES `find backup -type f | sort | xargs shasum -a 256`
REQUIRE sampled_files_byte_identical(backup, working_tree) FOR ≥ 5 critical files
IF any REQUIRE fails THEN ABORT fix workflow
```
