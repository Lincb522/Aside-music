# main-tabs-theme-frame-drop Bugfix Design

> Spec ID: `0abfc4ca-c0e6-4405-a289-6e8053c0d235`
> Spec Type: bugfix · 性能缺陷
> Requirements: 见 `.kiro/specs/main-tabs-theme-frame-drop/bugfix.md`
> 修复两条核心硬约束：
> 1. **视觉零回归**（bugfix §1 Unchanged Behavior）——F' 在稳态下逐像素等价于 F；滚动 / 过渡期间视觉曲线等价。
> 2. **修复前必须完整备份**（bugfix §5 Unchanged Behavior）——未完成 `.local-backups/main-tabs-theme-frame-drop-<UTC>/` 备份前，不得启动任何修复类代码改动。

## Overview

Monologue 在 20 种 `(主题 T, 主 tab P)` 组合下出现 hitch、首屏卡顿、滚动抖动、主题 / 外观切换闪滞等性能缺陷。bugfix.md 已定位 14 大类缺陷条款（§1~§14）与 6 条性能不变量（§15.1~§15.6）。

本设计遵循"分层根因、分层修复、分层验证"的思路：
- **根因层**：把 14 类缺陷按"订阅粒度 / 视图身份 / 绘制成本 / 布局构建 / 时间推进"五层归类，每层独立定位。
- **修复层**：优先采用不改变像素输出的手段（失效收窄、identity 稳定化、lazy 化、TimelineView 可见性门控）；对必须改动绘制路径的部分（Canvas + blur 缓存、纹理共享、阴影预渲染），严格走 A/B 截图比对，任何视觉等价性存疑的替换必须加开关回退。
- **验证层**：以 "snapshot diff（稳态逐像素）+ transition curve diff（过渡曲线）+ Instruments hitch ratio" 三层校验组成"修复 = 视觉零回归 ∧ 性能改善"的充分条件。

**最重要的工程纪律**：

- 任何代码级改动前，先完成 §5《修复前完整备份方案》所述的备份与校验，并生成 `.local-backups/main-tabs-theme-frame-drop-<UTC>/baseline/` 的 Instruments 基线。
- 每一项具体修复（§3 Component Design 的 3.1 ~ 3.15）落地时都必须附带：(a) 一张"修复前稳态截图"、(b) 一张"修复后稳态截图"、(c) 两者的 pixel diff 报告。diff 超过阈值即回退。
- 本 design 不给具体阈值填回 bugfix.md 的 TBD 位（§6.3 会在 tasks 阶段通过 baseline × 目标倍率敲定后批量替换）；本 design 的阈值写成"baseline × r"或 TBD，避免在真实测量前写死。

## Glossary

- **Bug_Condition (C)**：性能上的故障谓词，即"在 F 下该输入越过帧预算或产生可感知 jitter"。等价于 bugfix.md 中 `isBugCondition(Interaction)` 返回 `true` 的输入集合。
- **Property (P)**：修复后（F'）对 C(X) 类输入应满足的性能目标（hitch ratio、P95 commit ms、redundant body invalidations 等）全部满足 bugfix §15 性能不变量。
- **Preservation**：对 ¬C(X) 类输入（以及 C(X) 输入在视觉 / 功能 / 数据维度上），F' 与 F 行为等价。在本 bug 中升格为硬约束——对所有输入都要求视觉零回归。
- **F**：当前未修复的渲染管线。见 bugfix §Introduction。
- **F'**：修复后的渲染管线。形态由本 design 决定。
- **Hitch**：单帧主线程 commit 耗时超过目标帧预算（60Hz ≈ 16.67ms，120Hz ≈ 8.33ms）。
- **Hitch Ratio**：`累积 hitch 时间 / 窗口时间`，单位 ms per second。Instruments Animation Hitches 模板直接输出。
- **(T, P)**：主题 × tab 组合，T ∈ {default, muji, manga, neumorphic, capsule}，P ∈ {home, podcast, library, profile}。
- **globalThemeRevision**：`SettingsManager.globalThemeRevision`，现为所有主题相关失效的单一失效总线。
- **paletteRevision / rendererRevision**：本 design 新引入的拆分，分别表示"仅颜色/主题 token 变化"与"需要重建 Canvas 缓存"。
- **ThemeChangeBus**：本 design 新引入的细粒度 Publisher，替代 `globalThemeRevision` 的"整屏广播"。
- **ThemedPageBackground / ThemeRenderBackdrop / ThemeRenderContext**：主题背景路径的既有抽象，本 design 复用并改造其"是否共享 backdrop"的走线。
- **ImageRenderer**：iOS 17+ 的 `SwiftUI.ImageRenderer`，用于把一段 View 栅格化为 `CGImage / UIImage`，供本 design 的"Canvas + blur 缓存化"方案使用。
- **drawingGroup()**：SwiftUI 强制离屏合成指令；本 design 仅在"合成结果对所有后续帧都相同"时才套用。
- **Visual Equivalence**：逐像素等价，允许 ≤ 1 像素的抗锯齿差异与 ≤ 1/256 的色差（见 bugfix §1.1）。
- **Transition Curve Equivalence**：滚动 / 主题切换期间，每 2 帧采样一帧，两条时间序列的归一化相关系数 ≥ 0.98，且无"闪烁 / 色带 / 裂帧 / 短暂错位"(bugfix §1.7)。

## Bug Details

### Fault Condition

Bug 在用户进入任意 `(T, P)` 并执行"切换 tab / 滚动 / 播放中时间推进 / 主题与色彩方案切换"之一时触发。当前 F 的失效粒度过粗、绘制路径过重、订阅链路过长、身份 key 过度抖动，导致主线程单帧 commit 越过帧预算，或出现无法被用户感知忽略的重复 body 重算。

**Formal Specification（沿用 bugfix.md 附录 §Bug Condition 与 Property 雏形）：**

```
TYPE Interaction = RECORD
  theme: GlobalThemeId         // default | muji | manga | neumorphic | capsule
  tab: MainTab                 // home | podcast | library | profile
  action: ActionKind           // enterTab | scroll | lyricTick | secondTick
                               // | themeRevisionBump | colorSchemeFlip
  isPlaying: boolean
  deviceRefreshRate: number    // 60 | 120
END

FUNCTION isBugCondition(X: Interaction)
  INPUT:  X
  OUTPUT: boolean
  RETURN exists_hitch(F, X)
         OR mainthread_commit_ms(F, X) > frameBudget(X.deviceRefreshRate)
         OR redundant_body_invalidations(F, X) > allowedBudget(X)
END FUNCTION
```

其中：
- `exists_hitch(F, X)`：在 F 上执行 X，Instruments Animation Hitches 模板记录到 ≥ 1 次 hitch。
- `mainthread_commit_ms(F, X)`：主线程 CA commit 耗时。
- `redundant_body_invalidations(F, X)`：SwiftUI `_printChanges()`（iOS 17+）在 F 执行 X 时看到的与 X 语义不相关的 body 重算次数（例：切换 tab 导致非当前 tab 的 view body 被计算 > 1 次）。
- `allowedBudget(X)`：依赖 X 的合理重算上限（例：`lyricTick` 允许歌词子视图重算 1 次，不允许 FloatingBar 根容器重算）。

### Examples

以下摘取 bugfix §15 严重度表中的高风险组合，作为 C(X) 的具体反例：

| 反例 | X.theme | X.tab | X.action | F 的症状 | 预期 F' |
|------|---------|-------|----------|----------|---------|
| E1 | manga | home | enterTab | 首帧伴随 3 层 Canvas 纹理绘制 + N 张卡 Dots Canvas + ThemeCustomDiffuseBackground blur(38/44) 栅格化，进入首帧 hitch ≥ 1 | hitch = 0，首帧 commit ≤ frameBudget |
| E2 | neumorphic | home | enterTab + isPlaying | 双层 shadow × N 卡 + 常驻 NeumorphicVinyl TimelineView 持续推进，稳态期间周期性 hitch | 稳态期间 hitch ratio ≤ baseline × 0.4 |
| E3 | capsule | home | secondTick × 5.4s bannerTimer | 翻页动画期间 CapsuleRootBackdrop 5 胶囊 Canvas 重绘，周期性 hitch | 翻页期间 hitch count ≤ 1 |
| E4 | any | podcast | scroll | 内部 ScrollView+HStack（非 lazy）全量构建，叠加 scrollTransition 每帧重算 scale，P95 frame interval 超预算 | P95 frame interval ≤ baseline × 0.6 |
| E5 | any | library | scroll (下拉) | DragGesture 与 ScrollView 原生手势仲裁冲突，起手首帧 hitch | 起手 hitch = 0 |
| E6 | any | profile | lyricTick 且 isPlaying | RecentRadioStrip 订阅 $currentSong/$isPlaying，整条 strip 每句重绘 | 重绘范围限定到真正消费该状态的子组件 |
| E7 | any | any | themeRevisionBump | globalThemeRevision &+= 1 → floating bar `.id("\(themeId)-\(revision)")` 整条换 identity + 4 tab 根 body 同时失效 | floating bar identity 稳定；重算 body 数 ≤ 该字段真正被消费节点数 |
| E8 | any | any | colorSchemeFlip | 见 E7 同路径 | 同 E7 |
| E9 | default | home | enterTab | MonologueBackground.defaultSystemBackground 的 Canvas+blur(60)+drawingGroup 每次入场重走 | 使用预渲染 Image 缓存，首帧无重复栅格化 |
| E10 | muji | * | scroll 且卡多 | 每卡 MujiPaperTexture Canvas 重绘 + shadow(radius:14) 叠加 | 纹理共享 cached Image；阴影视情况预渲染或保留原路径 |

边界样例（验证 preservation）：

- E11 `(default, home)` 稳态截图：修复前后 pixel diff ≤ 1/256，山脊渐变、hitokoto 文本 layout 完全一致。
- E12 `(neumorphic, home)` 播放中 NeumorphicVinyl 旋转：可见时观感一致；非可见时 TimelineView 暂停，恢复可见时角度相位无可感知跳变。
- E13 主题切换：从 `(muji, home)` → `(manga, home)` 的过渡动画曲线每帧采样与 F 等价（相关系数 ≥ 0.98）。

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors（bugfix §1 Unchanged Behavior 的 design 级落地）：**

- 任意 `(T, P)` 稳态截图与 F 逐像素等价（允许 ≤ 1 像素的抗锯齿差异 / ≤ 1/256 色差 / ≤ 1 像素布局舍入）。
- manga 的纹理与 dots、muji 的纸质纹理、neumorphic 的软阴影浮雕、capsule 的胶囊背景与双层阴影的"纹理密度 / 阴影半径 / 阴影偏移 / 阴影颜色 / 描边宽度"与 F 完全一致。
- `(default, home)` 的 `ParallaxMountainHeader` 视差位移曲线、山脊颜色、天空渐变与 F 完全一致；hitokoto 的文本渲染与 F 一致。
- `(neumorphic, home)` 播放中 `NeumorphicVinyl` 旋转动画可见时完全保留；从不可见恢复可见时角度相位无可感知跳变。
- `(capsule, home)` 的 `bannerTimer` 周期与翻页过渡曲线与 F 一致。
- 任意 `(T, P)` 滚动时，`scrollTransition` 的 scale / rotation / opacity 曲线与 F 完全一致（允许走 GPU transform 代替重绘，但视觉输出无差异）。
- 主题 / 深浅色 / 主题色切换的稳态终态视觉与 F 一致；过渡期间不得出现新的闪烁 / 色带 / 裂帧 / 短暂错位。
- 所有功能语义保留：
  - `(*, podcast)` 所有 5 个横向 section 的全部数据项仍然可滚动访问（只改构建时机 eager→lazy）。
  - `(*, library)` 的 `TabView(.page)` 翻页交互与 `matchedGeometryEffect` 过渡保留。
  - `(*, profile)` 的 4 路数据刷新语义（`refreshProfilePublisher / $userProfile / $downloadedSongIds / $playlists`）保留。
  - 播放中 floating bar 在 4 个 tab 上仍反映最新歌词 / 进度 / 封面 / 播放状态。
  - `libraryHeaderCollapseProgress` 的最终折叠状态语义不变（只改手势仲裁路径）。
- 所有现有事件都被其消费者收到（`globalThemeRevision` / `FloatingBarPlaybackModel` / `PlayerManager` / `HomeViewModel` / `LyricViewModel` / `SettingsManager` 的事件订阅图不得丢事件）。
- 保持 iOS 17+ 最低版本策略，不得为了性能回退到低版本实现。
- `GlobalThemeId.removed` 值的迁移语义不动（out of scope）。

**Scope（修复范围外的输入）：**

所有"非性能"意义上的行为（视觉 / 功能 / 可达性 / 数据 / 副作用）都属于 preservation 范围。任何以"视觉简化"换性能的改造都属于违反 §1 Unchanged Behavior，必须回退。

**特别提醒：** 下列看似"性能优化"的做法在本 bug 中属于违规：

- 任何替换主题纹理为"肉眼相近但非等价"的材质（例：把 `MujiPaperTexture` 换成系统 `Material` / 把 `MangaDotsTexture` 换成 `Color.opacity` 纯色）。
- 任何改变阴影半径 / 偏移 / 颜色的"视觉近似"替换。
- 任何通过降采样、降精度、降分层数的方式压低 blur / shadow 成本。
- 任何改变字体 / 字重 / 圆角 / 间距的"性能微调"。

## Root Cause Analysis

把 bugfix.md 的 14 个缺陷条款按"订阅粒度 / 视图身份 / 绘制成本 / 布局构建 / 时间推进"五层分组。同一条款可能跨层（例如 §1.3 既是订阅层也是 identity 层），在原层归类，其它层引用回来。

### 1. 订阅粒度失控层（失效总线单一、订阅面过广）

定位缺陷：§1.1 / §1.2 / §1.3 / §11.1 / §11.2 / §12.1 / §12.2。

- **`SettingsManager.globalThemeRevision` 作为单一失效总线**：所有"深浅色切换 / 主题色切换 / 封面色再采样 / `notifyThemeCustomizationChanged()`"事件都被合并到这一个 `&+=` 计数器上。凡订阅该 `@Published` 的节点都被迫重算，无差别广播。对应 §1.1 / §1.2。
- **`FloatingBarPlaybackModel` 订阅链**：把"歌词当前句 / 进度 / 封面色"等高频事件推送到常驻于 4 个 tab 的 floating bar 容器，容器本身作为根订阅节点；一次歌词切换导致整个 floating bar 根 body 失效。对应 §12.1。
- **`ProfileView` 的 4 路 `onReceive`**：在根 View 层拉入 `refreshProfilePublisher / $userProfile / $downloadedSongIds.map(count) / $playlists.map(count)`。任意一路事件都让 Profile 根 body 重算。对应 §11.1。
- **`RecentRadioStrip` 订阅 `$currentSong / $isPlaying`**：播放中这两个属性高频变化，`RecentRadioStrip` 整条 strip 被失效。对应 §11.2。

**共性**：当前设计把"事件源"与"UI 的失效范围"耦合在了根容器（Settings / FloatingBar / ProfileView / RecentRadioStrip），而 SwiftUI 的 body diff 只能收敛到"依赖该 Published 的 body 节点"这一最近公共父节点。因此最小治理单元是"把订阅下沉到真正消费事件的叶子子 View"。

### 2. 视图身份层（identity key 抖动 + AnyView 擦除 + 每 tab 各挂 backdrop）

定位缺陷：§1.3 / §2.1 / §2.2 / §8.1 / §10.2 / §12.2。

- **`.id("\(themeId)-\(revision)")` 挂在 FloatingBar 容器上**：`revision` 任何一次自增都把子树 identity 换掉，SwiftUI 选择"卸载 + 重建"而非"diff"。对应 §1.3 / §12.2。
- **`AnyView` 类型擦除**：`theme.makeHomeView() / makePodcastView() / makeLibraryView() / makeProfileView()` 返回 `AnyView`，上游任一依赖变化都让整棵子树 identity 不可比较，SwiftUI 走保守 diff 近似"整棵重建"。对应 §8.1。
- **每个 tab 各挂一份 `ThemedPageBackground`**：`ThemeRenderContext.providesGlobalBackdrop == false`，导致同主题 backdrop 在 4 tab 内重复构建；切 tab 时仍然各自重建自己的那份。对应 §2.1 / §2.2。
- **`matchedGeometryEffect` in Library**：叠加在 `TabView(.page)` 之上，横滑期间匹配几何要求额外 layout pass。对应 §10.2。

**共性**：当前设计让"identity 的稳定性"反向由外部状态（revision / AnyView / 每 tab 各自持有的 backdrop）决定，违反了"identity 应仅由视图自身语义决定"的 SwiftUI 最佳实践。治理方向是"把 identity 与语义绑定，而非与 revision 绑定"。

### 3. 绘制成本层（Canvas + blur + shadow 每帧重走路径）

定位缺陷：§2.2 / §3.1 / §3.2 / §4.1 / §4.2 / §5.1 / §5.2 / §6.1 / §6.2 / §7.1 / §7.3。

- **`ThemeCustomDiffuseBackground`（所有主题共用）**：`baseLayer / accentLayer` 为 `Canvas + blur(38/44) + blendMode(.softLight)` 双层结构，任一 body 失效都要重走 Canvas draw + blur 栅格化。对应 §2.2 / §5.2。
- **Manga 根 backdrop + 卡片 dots**：
  - `MangaRootBackdrop` 连续 3 层 `Canvas` 纹理且未 `drawingGroup()`。对应 §3.1。
  - `MangaCardBackground` = 4 层填充 + 1 层 `MangaDotsTexture(Canvas)` + `compositingGroup()`；一屏 N 张卡时 ∝ N。对应 §3.2。
- **Muji 纸质纹理**：每张 `MujiPaperCardBackground` overlay 一次 `MujiPaperTexture(Canvas)`；加 `.shadow(radius: 14)` 的软阴影每帧栅格化。对应 §4.1 / §4.2。
- **Neumorphic 软阴影 + 背景堆叠**：
  - 每张 `NeumorphicSurfaceBackground` = 双层 shadow + 内 / 外 stroke overlay。对应 §5.1。
  - 背景层 ≈ `ThemeCustomDiffuseBackground` + `NeumorphicDiffuseGradient`（3 层渐变）+ `NeumorphicReliefTexture`（2 层渐变）共 6 层。对应 §5.2。
- **Capsule 胶囊 + 双层 shadow**：
  - `CapsuleRootBackdrop` = `ThemeCustomDiffuseBackground` + `Canvas(5 个旋转胶囊)`，每帧重算 5 条胶囊 transform。对应 §6.1。
  - `CapsuleSurfaceBackground` 双层 shadow。对应 §6.2。
- **Default 大半径模糊**：
  - `MonologueBackground.defaultSystemBackground` 含 `Canvas + blur(60) + drawingGroup()`。对应 §7.1。
  - `hitokoto` 组件含 `Canvas` 绘制，随无关 body 失效重绘。对应 §7.3。

**共性**：所有"Canvas + blur / 软 shadow / 多层渐变"组合在当前实现下都是"每帧现算"路径。GPU 上 blur 半径越大 / shadow 半径越大 / overlay 层数越多，消耗越大。治理方向是"把 frame 独立的绘制结果预渲染为 `UIImage` / `CGImage` 缓存，帧间直接贴图"；对仍需动态推进的部分（例如 Capsule 的胶囊旋转）改为 SwiftUI 原生 transform 动画（GPU-side 而非 CPU-side 重绘）。

### 4. 布局构建层（eager 构建 + TabView 预热 + 手势仲裁冲突）

定位缺陷：§9.1 / §9.2 / §10.1 / §10.2 / §14.1。

- **PodcastView 内部非 lazy 横向 ScrollView + HStack**：`categoriesSection / newestPrograms / chartPrograms / newcomerRadios / broadcastChannels` 在 section 一旦进入可视范围即全量构建所有 item，叠 `scrollTransition(scaleEffect)` 每帧重算 scale。对应 §9.1 / §9.2。
- **LibraryView 的 `TabView(.page)` 相邻页预热**：底层 `UIPageViewController` 预热相邻页，首屏即 ≥ 2 页完整内容；叠 `matchedGeometryEffect` 产生额外 layout pass。对应 §10.1 / §10.2。
- **`libraryHeaderCollapseProgress` 的 `DragGesture + withAnimation`**：与内部 `ScrollView` 原生滚动手势发生仲裁冲突，起手首帧产生 hitch。对应 §14.1。

**共性**：当前实现选择了"提前构建一切"来换取"切换即时"，实际反而把开销集中在进入 tab 首帧；`DragGesture` 被用作"监听滚动偏移"的副作用，而这个语义在 iOS 17+ 已经有更合适的 `onScrollGeometryChange` / `scrollPosition` API。

### 5. 时间推进层（常驻 TimelineView 不感知可见性）

定位缺陷：§5.3 / §13.1 / §12.x 的一部分间接贡献。

- **`TabBottomAccessoryPlaceholder`** 呼吸缩放动画常驻推进。对应 §13.1。
- **各主题 `NowPlayingIndicator` / `NeumorphicVinyl`** 使用 `TimelineView(.animation)`，即便当前主题 / tab 不需要该动画也持续推进时间依赖。对应 §5.3 / §13.1。
- **`CapsuleRootBackdrop` 的 Canvas 推进**：受 `TimelineView(.animation)` 驱动重绘 5 胶囊位置。对应 §6.1（兼属 3 层和 5 层）。

**共性**：`TimelineView(.animation)` 的时间依赖由 SwiftUI 按"是否被 UIKit/UIWindow 视为 visible"来判定暂停 / 续播，但是在当前实现里："常驻于所有 tab 的 placeholder" 恒为 visible，"非当前 tab 的 vinyl"也可能被保留渲染依赖。治理方向是"让 `TimelineView` 主动根据 `onAppear / onDisappear` + `scenePhase` + `isCurrentTab` 切 `paused`"。

## Hypothesized Root Cause

基于 §Root Cause Analysis 的五层分层，给出四大类可独立验证的根因假设。每类都落到"具体缺陷条款"上，便于在 §Testing Strategy 用 exploratory 测试先行证伪或证实。

1. **根因 A：单一失效总线 `globalThemeRevision` 把无关事件打包广播**
   - 具体：主题色 / 深浅色 / 封面色采样三类事件并成一个计数器 `&+=` → 所有订阅者强制重算。
   - 对应 §1.1 / §1.2 / §1.3 / §12.2。
   - 验证手段：`_printChanges()` 观察"触发一次色彩方案切换时，4 tab 根 View 各有多少次 body 重算"。F 上预期 ≥ 4；F' 上预期仅"当前 tab 中实际依赖色彩的节点"。

2. **根因 B：identity 与语义解耦（AnyView + 身份 key 挂 revision）**
   - 具体：`.id("\(themeId)-\(revision)")` 让 identity 随 revision 抖动；`AnyView` 让 SwiftUI 无法做细粒度 diff。
   - 对应 §1.3 / §8.1。
   - 验证手段：用 `@_inheritActorContext`/`_printChanges()` 观察"bump revision 后，floating bar 子树是否被整条卸载重建"。

3. **根因 C：绘制路径每帧现算（Canvas + blur + shadow）**
   - 具体：`ThemeCustomDiffuseBackground` 的双层 Canvas + blur(38/44)；Manga root 3 层 Canvas；Muji per-card Canvas 纹理；Neumorphic 双层 shadow + overlay stroke；Capsule 5 胶囊 Canvas；Default blur(60) + drawingGroup。
   - 对应 §2.2 / §3.1 / §3.2 / §4.1 / §4.2 / §5.1 / §5.2 / §6.1 / §6.2 / §7.1 / §7.3。
   - 验证手段：Instruments Time Profiler 抽样主线程栈，确认 `Canvas._draw` / `ImageRenderer` / `CGContext` / `CA::Render::Shadow` 等符号是否在热点前列。

4. **根因 D：构建时机过早 + 手势仲裁冲突 + TimelineView 可见性缺失**
   - 具体：Podcast 内部非 lazy；Library `TabView(.page)` 预热；`DragGesture` 与 `ScrollView` 冲突；TimelineView 不感知 visibility。
   - 对应 §9 / §10 / §13 / §14。
   - 验证手段：用 Instruments Animation Hitches + View Debugger 观察"进入 tab 首帧有多少 view 被 build" 与 "后台 tab 中 TimelineView 是否仍推进"。

**说明**：四类根因之间不是互斥关系，而是复合贡献。A + B 解决后仍可能有 C 的成本，C + D 解决后仍可能有 A 的广播。因此 §Fix Implementation 按"低风险先、高风险后"的顺序推进（订阅 / identity → lazy / 手势 / Timeline → 绘制缓存），并在每个里程碑独立验收。

## Correctness Properties

> 本节为 PBT 追溯的单一来源。每条 Property 指向 bugfix.md 的具体条款。性能相关的阈值目前写为"baseline × 目标倍率"或 TBD，实测后在 tasks 阶段批量回填。

**Property 1**：Fault Condition — 性能不变量成立

*For any* `X: Interaction` where the bug condition holds (`isBugCondition(X) == true`), the fixed pipeline F' SHALL satisfy:
- `NOT exists_hitch(F', X)`；
- `mainthread_commit_ms(F', X) <= frameBudget(X.deviceRefreshRate)`；
- `redundant_body_invalidations(F', X) <= allowedBudget(X)`。

**Validates: Requirements 15.1, 15.2, 15.3, 15.4, 15.5, 15.6**

**Property 2**：Preservation — 稳态逐像素等价

*For any* `X: Interaction` (包括 `isBugCondition(X) == true` 与 `== false` 两种），在稳态下（非滚动中、非动画中间帧），F' 的稳态截图 SHALL 与 F 逐像素等价，允许差异仅限于：
- 文本抗锯齿的亚像素抖动；
- 由 SwiftUI / UIKit 内部实现差异导致的、肉眼不可辨的 ≤ 1 像素舍入。

**Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.8**（Unchanged Behavior §1）

**Property 3**：Preservation — 过渡曲线等价

*For any* `X ∈ {scroll 期间, 主题/深浅色/主题色切换期间, TabView 翻页期间, bannerTimer 翻页期间}`，F' 在过渡期间每 2 帧采样一次的时间序列 SHALL 与 F 在相同条件下的时间序列满足：
- 归一化相关系数 ≥ 0.98；
- 不出现 F 不存在的闪烁 / 色带 / 裂帧 / 短暂错位。

**Validates: Requirements 1.5, 1.6, 1.7**（Unchanged Behavior §1.5 / §1.6 / §1.7）

**Property 4**：Preservation — 功能 / 数据 / 副作用等价

*For any* `X`，F' 的功能输出与数据副作用 SHALL 与 F 等价：
- 所有事件被其消费者收到（无丢事件）；
- Podcast 所有横向 section 的全部数据项仍然可访问；
- Library 的 `TabView(.page)` 翻页与 `matchedGeometryEffect` 过渡保留；
- Profile 的 4 路数据刷新语义保留；
- Floating bar 仍反映最新歌词 / 进度 / 封面 / 播放状态；
- `libraryHeaderCollapseProgress` 最终折叠状态语义不变。

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 3.3**（Unchanged Behavior §2 / §3）

**Property 5**：Preservation — 修复前置备份可还原

*For any* `X`，在 F' 首次部署前，`.local-backups/main-tabs-theme-frame-drop-<UTC>/` SHALL 存在且满足：
- `manifest.txt` 记录 `git rev-parse HEAD` / `git status --short` / `git diff` / 备份 UTC 时间 / 操作者 / macOS / Xcode 版本；
- `manifest.sha256` 与备份目录实际 `shasum -a 256` 校验一致；
- 随机抽样 ≥ 5 个关键文件（`Package.swift` / `Sources/Monologue/MonologueApp.swift` / `Sources/Monologue/Views/ContentView.swift` / `Sources/Monologue/Themes/ThemeRenderLayer.swift` / `.kiro/specs/main-tabs-theme-frame-drop/bugfix.md`）与工作树逐字节 `diff -q` 一致；
- `.local-backups/` 已被 `.gitignore` 覆盖。

**Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5, 5.7**（Unchanged Behavior §5）

**Property 6**：Preservation — 迁移兼容

*For any* `GlobalThemeId` 曾被标记 removed 的历史值，F' 的迁移语义与 F 一致。

**Validates: Requirements 4.1**（Unchanged Behavior §4）

## Fix Strategy（总体思路）

遵循视觉零回归的硬约束，修复策略按"对像素输出的影响"分 3 级：

- **Level 0 · 纯订阅 / identity / lazy 化**：不改变任何绘制路径，只重组订阅拓扑、拆分失效总线、稳定 identity、把 eager 构建改成 lazy 构建、给 TimelineView 加可见性门控。理论上视觉零回归"自动成立"，只要行为语义不变。
- **Level 1 · 绘制结果缓存化（等价栅格化）**：把"帧独立的 Canvas + blur 结果"用 `ImageRenderer`（iOS 17+）在相同 `displayScale` / colorSpace / colorScheme 下预渲染为 `UIImage`，缓存为 `NSCache<Key, UIImage>`（key 含主题 token、色彩方案、尺寸、revision）。只要输入一致，ImageRenderer 产出的栅格像素即与 runtime SwiftUI 一致；视觉等价性由 `ImageRenderer` 的"与视图树共享 renderer"语义保证。
- **Level 2 · 绘制替换（软阴影替换 / 纹理替换）**：把"软 shadow / overlay 纹理"整体替换为预渲染的 9-patch 图或共享 pattern。存在视觉等价性风险（跨 scale 栅格化差异、softLight blendMode 在栅格化后的合并差异），必须：
  1. 加 Debug 开关（`FeatureFlags.useCachedNeumorphicShadow` 等）；
  2. 稳态 snapshot diff 通过才默认启用；
  3. 启用后继续常态化比对，发现差异立即回退。

**优先顺序**：
1. M1 完成 Level 0（全部 §1 订阅 / §2 identity / §9 lazy / §13 timeline / §14 手势）——风险低，验证"视觉零回归 + 性能改善"的可行性路径。
2. M2 完成 Level 1（全部 Canvas + blur 背景的缓存化 / 所有 Manga 卡 dots / Muji 纸纹 / Default blur(60) 的缓存化）——风险中，逐主题推进，每主题独立发布。
3. M3 评估 Level 2（Neumorphic / Muji / Capsule 的 shadow 是否能预渲染替代）——风险高，需额外 snapshot 矩阵，默认保守保留 F 的原路径，仅在能通过像素比对时启用。
4. M4 阈值回填 + 验收。

## Component Design（按影响域分组）

> 每条按照"F 当前实现 / F' 修改点 / 视觉等价性论据 / 回归检测手段 / 对应缺陷条款"五栏展开。文件路径以 `Sources/Monologue/...` 为根；若 tasks 阶段发现实际路径不同，按实际路径落地。

### 3.1 拆分 `SettingsManager.globalThemeRevision`

- **F 当前实现**：`SettingsManager.globalThemeRevision: UInt64`，所有主题相关事件在触发路径（`activeColorScheme.didSet` / `notifyThemeCustomizationChanged()` / 封面色再采样）上 `&+=` 1；任意订阅者的 body 随之失效。
- **F' 修改点**：
  - 新增两个 `@Published` 字段：
    - `paletteRevision: UInt64`——仅当颜色 / 主题 token 变化时 bump；
    - `rendererRevision: UInt64`——仅当需要重建 Canvas 缓存（尺寸 / 主题类型 / 色彩方案切换）时 bump。
  - 新增 `ThemeChangeBus`（`final class ThemeChangeBus: ObservableObject`），暴露 3 个 `CurrentValueSubject`（或 `@Published`）：`palette`、`renderer`、`coverSampledColor`。订阅者按需订阅，不再订阅 `globalThemeRevision`。
  - 保留 `globalThemeRevision` 只读 getter：`var globalThemeRevision: UInt64 { paletteRevision &+ rendererRevision }`，向后兼容；内部不再 `@Published`。
  - 4 个 tab 的根 View 只订阅 `paletteRevision`（用于主题色重染），`rendererRevision` 仅被"Canvas 背景缓存键"消费。
- **视觉等价性论据**：不改变像素。只改变"哪些节点在什么时候 body 失效"，SwiftUI 最终渲染输出由 body diff 决定，而本次改造只收窄 diff 的范围，不改变 diff 的输出。
- **回归检测手段**：`_printChanges()` 在单元测试 `SubscriptionFanoutTests` 中断言"一次色彩方案切换只让相关节点的 body 执行 ≤ 1 次"。
- **对应缺陷**：§1.1 / §1.2 / §12.2（间接）。

### 3.2 `ThemeRenderContext.providesGlobalBackdrop` 走共享 backdrop

- **F 当前实现**：`providesGlobalBackdrop == false`，`ThemedPageBackground` 在每个 tab 内部各自构建 `ThemeRenderBackdrop`；4 个 tab = 4 份 backdrop 实例。
- **F' 修改点**：
  - 在 `ContentView.tabViewCore` 外层引入 `ThemeRenderHost`，该 Host 的 `ZStack` 底层挂一次共享 `ThemeRenderBackdrop`。
  - `ThemeRenderContext.providesGlobalBackdrop` 设为 true，`ThemedPageBackground` 在新路径下退化为 `Color.clear`（透出 Host 的 backdrop）。
  - 为保证视觉等价，Host 的 backdrop SHALL：
    - 与每 tab 原 `ThemedPageBackground` 使用完全相同的 `ignoresSafeArea(.all)` / 尺寸 / 安全区约束；
    - 在尺寸变化（横竖屏、splitView、iPad sidebar）上跟随 `GeometryReader` 重新布局；
    - 在 `colorScheme` / `theme` 变化上重新 build，但同一 `(theme, colorScheme, size)` 仅 build 1 次。
- **视觉等价性论据**：同一主题的 `ThemeRenderBackdrop` 本就是"tab-agnostic"（当前 4 份都是等价的），共享化只是去重。稳态截图逐像素等价由 `ThemedPageBackground` 变成 `Color.clear` + Host backdrop 的 Z 顺序保证——Host backdrop 位于每 tab 内容之下，与原结构"每 tab 背景位于自身内容之下"的 Z 顺序一致。
- **回归检测手段**：
  - `SnapshotEquivalenceTests` 对 20 个 (T, P) 组合拍 snapshot 比对。
  - `BackdropInstanceCountTests` 通过"对 `ThemeRenderBackdrop.init` 注入计数"确认一次会话内构建次数 ≤ 1（仅允许尺寸变化重建）。
- **对应缺陷**：§2.1 / §2.2。

### 3.3 `ThemeCustomDiffuseBackground` 缓存化

- **F 当前实现**：
  - `baseLayer`：`Canvas { … } .blur(radius: 38)`；
  - `accentLayer`：`Canvas { … } .blur(radius: 44) .blendMode(.softLight)`；
  - 每次 body 失效都重走 Canvas + blur 栅格化。
- **F' 修改点**：
  - 抽出 `DiffuseBackgroundCache`（`actor` 或 `NSCache`），key = `Key(themeId, colorScheme, rendererRevision, sizeRounded, displayScale)`。
  - 在首次 miss 时用 `ImageRenderer` 渲染对应的 `baseLayer` / `accentLayer`（两张独立 `UIImage`）。
  - 视图层用 `Image(uiImage: cachedBase).blendMode(.normal)` 底层 + `Image(uiImage: cachedAccent).blendMode(.softLight)` 叠加。
  - `rendererRevision` 变化时主动 evict 旧缓存。
  - 缓存失败或尺寸未命中时回退到原 Canvas 路径（feature flag: `FeatureFlags.useCachedDiffuseBackground`，默认 true，可通过 debug menu 关闭用于 A/B 对比）。
- **视觉等价性论据**：
  - `ImageRenderer` 在 iOS 17+ 支持 `scale` / `proposedSize` / `colorMode`；用与 runtime SwiftUI 相同的 `displayScale` 渲染，产出的栅格在相同 colorSpace 下逐像素一致。
  - `baseLayer` 的 `blur(38)` 属于"可栅格化后固定结果"的效果，栅格化后的 `Image` 贴图与原路径一致。
  - `accentLayer` 的 `blendMode(.softLight)` 保留在视图层，不合入栅格化；只把"Canvas + blur(44)"栅格化，`.softLight` 叠加仍由 runtime 合成。
- **回归检测手段**：
  - 稳态 snapshot：20 个 (T, P) × 明暗 2 × scale {2x, 3x}。
  - debug menu 提供"缓存开 / 关"开关，手动 A/B 比对。
- **对应缺陷**：§2.2 / §5.2（背景堆叠之一）/ §6.1（CapsuleRootBackdrop 底层复用 ThemeCustomDiffuseBackground）。

### 3.4 Manga backdrop 与 card 纹理

- **F 当前实现**：
  - `MangaRootBackdrop`：3 层 `Canvas` 纹理，无 `drawingGroup()`。
  - `MangaCardBackground`：4 层填充 + `MangaDotsTexture(Canvas)` + `compositingGroup()`，一屏 N 张卡即 N 次 Canvas。
- **F' 修改点**：
  - `MangaRootBackdrop` 外层 wrap `.drawingGroup()`，并绑定 `.id(paletteRevision)`，把 3 层 Canvas 合成结果离屏缓存；`paletteRevision` 不变则合成结果也不变。
  - `MangaDotsTexture` 抽出为 `MangaDotsTexturePattern`（静态 image pattern），按 `Key(cornerRadius, size, paletteRevision)` 缓存；`MangaCardBackground` overlay 改为 `Image(uiImage: pattern)` 覆盖 + `clipShape(RoundedRectangle(cornerRadius:))`。
  - 保留 4 层填充的 `compositingGroup()` 行为（填充本身成本低）。
- **视觉等价性论据**：
  - `drawingGroup()` 属于"强制离屏合成"，只要输入稳定（identity 稳定 + body 不失效），其输出为确定性栅格，像素等价。需要确保 `.id(paletteRevision)` 的 key 真的仅在"dots 纹理需要重建"时变化（否则缓存被反复 invalidate 就失去意义）。
  - `MangaDotsTexturePattern` 同样由 `ImageRenderer` 栅格化 dots canvas，固定 dot 直径、间距、颜色、圆角；像素等价。
- **回归检测手段**：snapshot diff for `(manga, *)`。
- **对应缺陷**：§3.1 / §3.2。

### 3.5 Muji 纸纹

- **F 当前实现**：`MujiPaperCardBackground` overlay `MujiPaperTexture(Canvas)`；根 `MujiPaperRootBackground` 也含一份 Canvas。
- **F' 修改点**：
  - `MujiPaperTexture` 抽为 `MujiPaperTextureCache`，key = `Key(colorScheme, paletteRevision, size)`；首次渲染用 `ImageRenderer` 输出 `UIImage`。
  - `MujiPaperCardBackground.overlay(MujiPaperTexture())` 改为 `.overlay(Image(uiImage: cachedTexture).resizable())`。
  - 根背景同处理。
- **视觉等价性论据**：纸纹为帧独立（不随时间变化、不依赖鼠标 / 触控位置），完全可栅格化。像素等价由 ImageRenderer 与 runtime SwiftUI 的相同 scale / colorSpace 保证。
- **回归检测手段**：snapshot diff for `(muji, *)`，重点校验卡片边缘的 `clipShape(RoundedRectangle)` 与贴图 resize 的插值是否产生亚像素差异（若出现，改用 `.interpolation(.high)` 与固定 `scale` 匹配）。
- **对应缺陷**：§4.1。`.shadow(radius:14)` 的软阴影暂保留（见 3.6 / 3.14 评估）。

### 3.6 Neumorphic 背景 + 软阴影

- **F 当前实现**：
  - 背景层：`ThemeCustomDiffuseBackground` + `NeumorphicDiffuseGradient`（3 层渐变）+ `NeumorphicReliefTexture`（2 层渐变）=≈ 6 层绘制对象。
  - 卡片：`NeumorphicSurfaceBackground` 双层 shadow + 内 / 外 stroke overlay。
- **F' 修改点（保守版）**：
  - 背景层：由 3.3 的 `ThemeCustomDiffuseBackground` 缓存化天然承担绝大部分收益；`NeumorphicDiffuseGradient` + `NeumorphicReliefTexture` 合并为一张缓存 Image（key = `Key(colorScheme, paletteRevision, size, displayScale)`）。
  - 卡片阴影：**保留原 `.shadow` 路径作为默认**（`FeatureFlags.useCachedNeumorphicShadow == false`）；提供 Level 2 版本作为实验开关。
- **F' 修改点（Level 2 实验版，需通过 M3 snapshot 矩阵后才默认启用）**：
  - `NeumorphicSurfaceBackground` 的双层 shadow + overlay stroke 合并为 9-patch 预渲染 Image（按 `Key(cornerRadius, size∈{几档离散值}, colorScheme, paletteRevision, displayScale)`）。
  - 实测跨设备 scale（2x / 3x）栅格化差异：若任一组合 pixel diff > 阈值则该主题保守回退。
- **视觉等价性论据**：
  - 背景渐变合并是"同一静态结果的等价栅格化"，像素等价。
  - 9-patch 阴影方案存在跨 scale 风险；只在"实验开关 + snapshot 通过"条件下启用。
- **回归检测手段**：
  - snapshot diff for `(neumorphic, *)`。
  - Level 2 开关 on/off 的 A/B 截图对比；任一差异即保守回退。
- **对应缺陷**：§5.1 / §5.2。

### 3.7 Capsule backdrop + 卡片

- **F 当前实现**：
  - `CapsuleBackdropField`：`Canvas { 5 个胶囊以各自 angle 旋转 }`，每帧（被 TimelineView 驱动）重绘。
  - `CapsuleSurfaceBackground`：双层 shadow。
  - `bannerTimer` 每 5.4s 触发翻页。
- **F' 修改点**：
  - 把 `CapsuleBackdropField` 的 5 个 Canvas 胶囊改写为 5 个独立 `Capsule().fill().frame(...).offset(...).rotationEffect(.degrees(angle))`，由 SwiftUI 原生 transform 动画（`withAnimation(.linear.repeatForever)`）驱动，走 GPU-side transform，而非 CPU-side Canvas 重绘。
  - 胶囊颜色 / offset / rotation 参数与 F 完全一致；动画 duration / easing / phase 与原 TimelineView 驱动下的 `angle(context)` 函数等价（tasks 阶段抽取原函数推导 phase 表）。
  - `CapsuleSurfaceBackground` 的双层 shadow 同 3.6 保守处理：保留原 `.shadow`，Level 2 可选预渲染。
  - `bannerTimer` 翻页逻辑不变；翻页时因为 backdrop 只走 transform 动画，不再重绘 Canvas，天然降低期间的重绘压力。
- **视觉等价性论据**：
  - `Capsule().fill()` 的栅格化与 `Canvas { context.fill(Capsule()) }` 输出相同；`.offset / .rotationEffect` 走 Core Animation transform，像素级栅格化由 CA 负责，与 runtime SwiftUI 的 Canvas 输出在抗锯齿层面等价（两者都走 CoreGraphics → CA 路径）。
  - 存在需要确认的细节：原 Canvas 版本是否使用了 `blendMode(.softLight)` 或其他混合。tasks 阶段检查原实现，若有，则在新结构上保留对应 `.blendMode(...)`。
- **回归检测手段**：
  - snapshot diff for `(capsule, *)` 在胶囊旋转 phase 固定时刻的截图；
  - 过渡曲线 diff：每 2 帧采样 5 胶囊位置，验证两版本轨迹相关系数 ≥ 0.98；
  - bannerTimer 翻页期间的时间序列 diff。
- **对应缺陷**：§6.1 / §6.2 / §6.3。

### 3.8 Default 背景 + ParallaxMountainHeader

- **F 当前实现**：
  - `MonologueBackground.defaultSystemBackground`：`Canvas + blur(60) + drawingGroup()`。
  - `ParallaxMountainHeader`：300pt 高，首屏 layout 参与视差计算。
  - `hitokoto` 组件含 Canvas 绘制。
- **F' 修改点**：
  - `defaultSystemBackground` 整体按 3.3 同方案缓存化（key 含 paletteRevision + displayScale + size）；保留原 `drawingGroup()` 作为回退路径。
  - `ParallaxMountainHeader`：
    - 静态的"山脊 / 天空渐变"预渲染为 `UIImage`；
    - 视差位移由外层 `ScrollView` 偏移驱动 `.offset(y:)`，不触发重建；
    - hitokoto 的 Canvas 单独抽子视图，仅在真正的 hitokoto 文本 / 颜色变化时重绘（订阅从根 body 下沉到该子视图）。
- **视觉等价性论据**：静态栅格化结果可缓存；视差位移曲线通过"ScrollView.offset → view.offset"保留不变。
- **回归检测手段**：`(default, home)` snapshot + 滚动时间序列 diff。
- **对应缺陷**：§7.1 / §7.2 / §7.3。

### 3.9 `AnyView` 工厂改造

- **F 当前实现**：`theme.makeHomeView() -> AnyView` / `makePodcastView() -> AnyView` / ...。`AnyView` 擦除让 SwiftUI 走保守 diff。
- **F' 修改点**：
  - 在 `GlobalThemeProvider` 上引入泛型关联类型入口：
    ```swift
    protocol GlobalThemeProvider {
        associatedtype HomeContent: View
        associatedtype PodcastContent: View
        associatedtype LibraryContent: View
        associatedtype ProfileContent: View
        @ViewBuilder func homeContent() -> HomeContent
        @ViewBuilder func podcastContent() -> PodcastContent
        @ViewBuilder func libraryContent() -> LibraryContent
        @ViewBuilder func profileContent() -> ProfileContent
    }
    ```
  - 引入通用容器 `ThemedTabContainer<HomeContent: View, PodcastContent: View, …>`，在 `ContentView.tabViewCore` 中按具体类型注入；`AnyView` 仅作为兜底（例如实验 / 测试主题的动态注入）。
  - 保留既有 `makeHomeView() -> AnyView` 作为过渡期 API（`@available(*, deprecated)`）。
- **视觉等价性论据**：只改变 SwiftUI 的 diff 粒度，不改变视图树输出。像素等价成立。
- **回归检测手段**：`_printChanges()` 断言"单次 tab 切换触发的根 body 重算数"显著下降；snapshot 保持等价。
- **对应缺陷**：§8.1 / §1.3（配合 identity 稳定化）。

### 3.10 PodcastView 横向 section lazy 化

- **F 当前实现**：`categoriesSection / newestPrograms / chartPrograms / newcomerRadios / broadcastChannels` 为 `ScrollView(.horizontal) { HStack { ForEach { item } } }`。
- **F' 修改点**：改写为 `ScrollView(.horizontal) { LazyHStack { ForEach { item } } }`；保留 `scrollTransition(scaleEffect)` 不变（视觉不变）。
- **视觉等价性论据**：`LazyHStack` 只改变 item 构建时机，同 item 在同 scroll offset 下的布局与 `HStack` 一致（iOS 17 已稳定）。`scrollTransition` 走 GPU transform，不受影响。
- **回归检测手段**：
  - snapshot for `(*, podcast)` 滚动前 / 中 / 后三帧；
  - 功能测试：所有 item 可滚动进入视图，数据无截断（bugfix §2.2）。
- **风险**：iOS 17 中某些 scrollTransition 组合在 `LazyHStack` 中测得的 transition 相位可能与 `HStack` 有亚像素差异；tasks 阶段抽样验证。
- **对应缺陷**：§9.1 / §9.2。

### 3.11 LibraryView 的 TabView(.page) 评估

- **F 当前实现**：`TabView(.page)` 4 页，`UIPageViewController` 预热相邻页；叠 `matchedGeometryEffect` 产生额外 layout。
- **F' 修改点**：
  - **保留 TabView(.page) 结构**（功能语义必须保留 — bugfix §2.3），不改翻页交互。
  - 降低"相邻页 eager 预热"的代价：相邻页的 data source 走 lazy loading（数据层仅在该页成为 `currentPage` 时才发起请求 / 访问重对象）；视图层 skeleton 保持 lightweight。
  - `matchedGeometryEffect` 保留；把该 effect 的 namespace / id 维度收窄到"真正共享转场的元素"，避免同一 namespace 下无关 view 的匹配。
- **视觉等价性论据**：翻页交互语义不变；相邻页 skeleton 与 eager 版本在"尚未可见的瞬间"视觉等价（都是被遮挡的状态）。首次滑入该页时 skeleton → 实内容过渡曲线可能有差异 → 需 transition curve diff 验证。
- **回归检测手段**：snapshot + scroll offset 0.25 / 0.5 / 0.75 的过渡帧 diff。
- **对应缺陷**：§10.1 / §10.2。

### 3.12 ProfileView 订阅下沉

- **F 当前实现**：`ProfileView` body 同时挂 4 个 `onReceive`：`refreshProfilePublisher / viewModel.$userProfile / DownloadManager.$downloadedSongIds.map(count) / LocalPlaylistManager.$playlists.map(count)`；且 `RecentRadioStrip` 订阅 `PlayerManager.$history / $currentSong / $isPlaying`。
- **F' 修改点**：
  - 4 个 `onReceive` 搬到真正消费数据的子 View：
    - `viewModel.$userProfile` → `UserProfileHeader`；
    - `DownloadManager.$downloadedSongIds` → `DownloadCountBadge`；
    - `LocalPlaylistManager.$playlists` → `LocalPlaylistCountBadge`；
    - `refreshProfilePublisher` → 引入 `ProfileRefreshCoordinator`（仅广播"刷新请求"而不广播内容），根 View 只持有该 coordinator，不订阅。
  - `RecentRadioStrip` 的 `$currentSong / $isPlaying` 订阅下沉到 strip 内"当前正在播放"的高亮子视图（而非整条 strip）。
- **视觉等价性论据**：订阅位置不同，但事件触发的 UI 更新仍然发生在相同视图上，像素等价。需保证订阅下沉后不会"延迟"收到事件（SwiftUI `onReceive` 在子视图未构建时的事件接收策略与 Combine `.receive(on: RunLoop.main)` 一致，需要确保 ProfileRefreshCoordinator 使用 `CurrentValueSubject` 而非 `PassthroughSubject`）。
- **回归检测手段**：
  - 功能测试：触发 4 路事件源，断言每个叶子 View 都收到并正确刷新；
  - `_printChanges()` 断言根 body 失效次数 ≤ allowedBudget。
- **对应缺陷**：§11.1 / §11.2。

### 3.13 Floating bar identity 与订阅下沉

- **F 当前实现**：
  - 容器 `.id("\(themeId)-\(revision)")`；
  - `FloatingBarPlaybackModel.lyricLineText` 在根层订阅，歌词每句切换触发根 body 重算。
- **F' 修改点**：
  - 去掉 `.id("\(themeId)-\(revision)")`，改为：
    - 主题 token 通过 `.environment(\.themeTokens, tokens)` 注入；
    - 容器 identity 仅由 `themeId` 决定（例如 `.id(themeId)`），不绑定 revision；对大多数切换场景（色彩方案 / 主题色）identity 稳定。
  - `FloatingBarPlaybackModel.lyricLineText` 下沉到 `FloatingBarLyricSubtitleView`，根 View 不订阅；进度 / 封面色同处理（下沉到各自的子视图）。
- **视觉等价性论据**：主题 token 注入的值与原 `.id` 驱动重建的结果在稳态下等价（只要 token 的一致性被保证）；identity 稳定只是让 SwiftUI 走 diff 而非"卸载 + 重建"。需验证"主题切换时 token 变化是否完整覆盖原 `.id` 改动带来的重建效果"；若发现某些样式不跟随 token 走（例如在 `onAppear` 里一次性算出的样式），需同步迁移到 token 驱动。
- **回归检测手段**：
  - `(*, *)` 主题 / 色彩方案切换的 snapshot diff；
  - 过渡曲线 diff（切主题的瞬间 floating bar 过渡）；
  - `_printChanges()` 断言 floating bar 根 body 在一次 `lyricTick` 上重算次数 = 0。
- **对应缺陷**：§1.3 / §12.1 / §12.2。

### 3.14 软阴影缓存评估（跨主题共享策略）

适用于 `NeumorphicSurfaceBackground / MujiPaperCardBackground / CapsuleSurfaceBackground` 的 `.shadow(...)` 叠加。

- **F 当前实现**：各 surface 背景内多次 `.shadow(color:…, radius:…, x:…, y:…)`。
- **F' 修改点（Level 2，默认关）**：
  - 引入 `CachedSoftShadow(cornerRadius:size:shadows:)` 视图修饰器，把"同一 cornerRadius + 同一 size 档位 + 同一 shadow 参数集"的 `.shadow` 结果预渲染为 9-patch `UIImage`（key 含 `displayScale`）。
  - 默认 `FeatureFlags.useCachedSoftShadow == false`；在 M3 snapshot 矩阵通过后按主题按开关启用。
- **视觉等价性论据**：
  - 9-patch 阴影本身在 UIKit 世界里是成熟技术；但 SwiftUI `.shadow` 与 9-patch 的合成差异存在"边缘锐度"层面的风险。
  - 关键风险：跨 scale 栅格化差异（2x / 3x 设备）。缓存 key 必须含 `displayScale`。
- **回归检测手段**：
  - 按"主题 × scale × 是否 active"矩阵拍 snapshot；
  - 任一组合 pixel diff > 阈值 → 对应主题回退。
- **对应缺陷**：§4.2 / §5.1 / §6.2。

### 3.15 TimelineView 可见性门控

- **F 当前实现**：
  - `TabBottomAccessoryPlaceholder` 呼吸缩放动画常驻。
  - 各主题 `NowPlayingIndicator / NeumorphicVinyl / CapsuleBackdropField`（见 3.7 已改造）使用 `TimelineView(.animation)`。
  - 已有工具 `AppFrameRate.animationTimeline(paused:)`，但部分点位未使用。
- **F' 修改点**：
  - 封装 `VisibilityGatedTimelineView`：组合 `onAppear / onDisappear` + `Environment(\.scenePhase)` + 外部 `isCurrentTab` 信号，内部对原 `TimelineView(.animation)` 的 `paused` 参数做联合判断：`paused = !isAppeared || scenePhase != .active || !isCurrentTab`。
  - 把所有现存 `TimelineView(.animation)` 点位迁移到 `VisibilityGatedTimelineView`：
    - `TabBottomAccessoryPlaceholder`；
    - 各主题 `NowPlayingIndicator`；
    - `NeumorphicVinyl`；
    - `MangaRootBackdrop` 若有依赖时间的层；
    - `CapsuleBackdropField`（3.7 改造后若保留 TimelineView 驱动相位）。
  - `NeumorphicVinyl` 的"相位无跳变"要求：记录 `pauseTime` 与 `resumeTime`，恢复时计算应有的累积相位偏移以保持旋转连续（bugfix §1.4）。
- **视觉等价性论据**：
  - 可见时行为与 F 一致；
  - 不可见时暂停不产生任何像素输出（视图本身不可见）；
  - 恢复可见时通过相位补偿保持观感一致。
- **回归检测手段**：
  - `(neumorphic, home)` 播放中切到 `(neumorphic, podcast)` 再切回，vinyl 角度相位无可感知跳变；
  - Instruments 验证后台 tab 无 TimelineView 推进。
- **对应缺陷**：§5.3 / §6.1 / §13.1。

### 3.16 LibraryHeader 手势替换

- **F 当前实现**：`libraryHeaderCollapseProgress` 由 `DragGesture + withAnimation` 驱动，与 `ScrollView` 原生滚动手势仲裁冲突，起手首帧 hitch。
- **F' 修改点**：
  - 用 iOS 17+ 的 `onScrollGeometryChange(for: CGFloat.self, of: { geom in geom.contentOffset.y }) { _, newY in ... }`（或在未支持的 fallback 里用 `GeometryReader + PreferenceKey`）统一驱动 `libraryHeaderCollapseProgress`。
  - 移除 `DragGesture`；保留 `withAnimation` 在 `libraryHeaderCollapseProgress` 写回时的 easing 曲线。
- **视觉等价性论据**：最终折叠状态语义不变（bugfix §2.6）；过渡曲线由原 `DragGesture + withAnimation` 映射到"ScrollView offset × withAnimation"，可在 tasks 阶段通过曲线 diff 验证。
- **回归检测手段**：
  - 过渡曲线 diff（下拉 → header 折叠的时间序列）；
  - 起手首帧 hitch = 0 断言（Instruments）。
- **对应缺陷**：§14.1。

## 视觉等价性验证策略

本 bug 的"视觉零回归"硬约束要求把"像素等价性"做成可机械验证的一级工程流程。以下策略在 tasks 阶段落地，但在本 design 中先固化验证矩阵与阈值。

### 4.1 Snapshot 矩阵（稳态逐像素）

维度：
- 主题 T ∈ {default, muji, manga, neumorphic, capsule}（5 个）；
- tab P ∈ {home, podcast, library, profile}（4 个）；
- `colorScheme` ∈ {light, dark}（2 个）；
- 动态字体 ∈ {.medium, .xxxLarge}（2 个）；
- 设备 ∈ {iPhone mini, iPhone Pro, iPad}（3 个）；
- 场景 ∈ {首屏稳态, 播放中稳态}（2 个）；

总矩阵 = 5 × 4 × 2 × 2 × 3 × 2 = **480 组**。考虑到工程成本，M1 阶段先跑"5 × 4 × 2 × 1 × 1 × 2 = 80 组"的最小子集；M2 / M3 每新增一个绘制路径改造时扩展对应主题的子矩阵。

执行：
- 使用 `XCTest` + `ImageRenderer` + `UIView.asImage` 在 iOS 17+ 拍摄；
- 阈值：**像素差 ≤ 1，单像素 RGB 通道差 ≤ 1 / 256**；
- 差异报告（diff image + 差异像素直方图）落盘到 `.local-backups/main-tabs-theme-frame-drop-<UTC>/snapshots/<stage>/diff/`；
- 任一组合 diff > 阈值 → 对应修复任务回退或走 feature flag 关闭。

### 4.2 Transition curve（过渡曲线）

适用场景：
- `scrollTransition` 下的 scale / rotation / opacity 曲线（bugfix §1.6）；
- 主题 / 深浅色 / 主题色切换的过渡动画（bugfix §1.7）；
- `TabView(.page)` 翻页过渡（bugfix §2.3）；
- `bannerTimer` 翻页过渡（bugfix §1.5）；
- LibraryHeader 折叠过渡（bugfix §2.6）。

执行：
- 使用 `XCUIApplication` 录制时间序列帧（每 2 帧采样一次）；
- 对每个像素（或 ROI 区域均值）计算 F 与 F' 的归一化时间序列；
- 阈值：**相关系数 ≥ 0.98**；
- 断言"无闪烁 / 色带 / 裂帧 / 短暂错位"通过 ROI 差异直方图检查。

### 4.3 Debug 开关统一约束

所有 Level 1 / Level 2 改造必须满足：
- 加 `FeatureFlags.xxx: Bool`（默认值在 M1 为 true 的 Level 0、M2 按主题逐步 true 的 Level 1、M3 默认 false 的 Level 2）；
- `scripts/snapshot-ab.sh` 在 CI 上分别跑"启 / 停"两种配置，自动对比并归档；
- tasks 阶段第一次实测启用 / 停用的截图必须落盘到 `.local-backups/main-tabs-theme-frame-drop-<UTC>/snapshots/` 以备比对。

## 修复前完整备份方案

> 严格对应 bugfix §5 的硬前置约束。tasks 阶段的第一个任务即为执行本方案。

### 5.1 备份脚本

脚本路径：`scripts/backup-before-fix.sh`（新建）。

接口：
- 可选参数 `--stage <name>`：用于后续里程碑的增量备份（例如 `--stage m1-subscription`）；缺省时走"修复前完整备份"。
- 可选参数 `--dry-run`：只打印将要执行的步骤与排除列表，不产生任何文件。

执行步骤（任一步非零退出立即 `exit 1` 并清理已创建目录）：

1. 前置检查 `.gitignore` 是否覆盖 `.local-backups/`：`grep -q '^\.local-backups/' .gitignore`，否则提示先补齐后再重跑。
2. 生成 UTC 时间戳 `STAMP=$(date -u +%Y%m%dT%H%M%SZ)`；目标目录 `BACKUP_DIR=".local-backups/main-tabs-theme-frame-drop-${STAMP}"`（若指定 `--stage`，`BACKUP_DIR=".local-backups/main-tabs-theme-frame-drop-${STAGE}-${STAMP}"`）。
3. 准备排除清单（见 §5.2）。
4. `rsync -a --delete --exclude-from=<tmpfile> ./ "${BACKUP_DIR}/source/"`。
5. 写入 `manifest.txt` 与 `manifest.diff.txt`（见 §5.3）。
6. 生成 `manifest.sha256`（见 §5.4）。
7. 抽样逐字节校验（见 §5.5）。
8. 打印备份目录绝对路径与 `manifest.sha256` 的前 16 字节摘要，告知用户备份完成。

**安全与副作用**：
- 脚本 SHALL NOT 动 `.git/` 目录；
- 脚本 SHALL NOT 修改工作树；
- 脚本 SHALL NOT 执行任何网络请求。

### 5.2 排除规则

排除来源 = `.gitignore` 的条目 + 以下强制排除（即使 `.gitignore` 未覆盖）：

```
.env
Secrets.xcconfig
Secrets_*.xcconfig
*.ipa
*.app
*.dSYM
*.xcarchive
NeteaseCloudMusicAPI-Swift/
ffmpeg-swift/
QQMusicKit/
HiconIcons/
.build/
DerivedData/
.kiro/                     # bugfix.md 已通过 §5.5 抽样校验路径单独保护
.codex-backups/
.local-backups/
build/
build-macos/
tmp/
.tmp*/
*.tar.gz
*.zip
```

**注意**：bugfix.md 是 spec 文件，位于 `.kiro/` 下。为保留它在备份中，脚本在 rsync 之后单独把 `.kiro/specs/main-tabs-theme-frame-drop/` 整个目录复制到 `${BACKUP_DIR}/source/.kiro/specs/main-tabs-theme-frame-drop/`，确保 §5.5 抽样能 diff 成功。

### 5.3 manifest.txt 与 manifest.diff.txt

`manifest.txt` 字段（每行 `KEY: VALUE`）：

- `GIT_HEAD`: `git rev-parse HEAD`
- `GIT_STATUS`: `git status --short`（多行）
- `GIT_DIFF_STAT`: `git diff --stat`
- `GIT_STASH_REF`: 若 `git status --short` 非空，执行 `git stash create`（不改变工作树，只生成 stash commit）并记录返回的 commit hash；否则 `none`
- `BACKUP_START_UTC`: 备份开始时间
- `BACKUP_END_UTC`: 备份结束时间
- `OPERATOR`: `whoami`
- `MAC_OS`: `sw_vers -productVersion` + `sw_vers -buildVersion`
- `XCODE`: `xcodebuild -version`（多行）
- `WORKING_TREE_ABS`: `pwd -P`
- `GIT_REMOTES`: `git remote -v`
- `STAGE`: `--stage` 参数值；缺省时 `full`

`git diff`（可能较大）单独存为 `manifest.diff.txt`，避免把 `manifest.txt` 写得过大。

### 5.4 manifest.sha256

生成方式：

```bash
(cd "${BACKUP_DIR}" && \
 find . -type f \! -path './manifest*' \
   | LC_ALL=C sort \
   | xargs -I{} shasum -a 256 "{}") \
  > "${BACKUP_DIR}/manifest.sha256"
```

- `LC_ALL=C sort` 保证跨环境的顺序一致。
- 排除 `manifest*` 文件本身避免循环。
- 文件内每行：`<sha256>  <relative path>`。

校验命令（事后）：`(cd "${BACKUP_DIR}" && shasum -a 256 -c manifest.sha256)` 必须全部 `OK`。

### 5.5 抽样验证

固定 5 个关键文件（与 bugfix §5.3 一致）：

```
Package.swift
Sources/Monologue/MonologueApp.swift
Sources/Monologue/Views/ContentView.swift
Sources/Monologue/Themes/ThemeRenderLayer.swift
.kiro/specs/main-tabs-theme-frame-drop/bugfix.md
```

对每个文件执行：

```bash
diff -q "${BACKUP_DIR}/source/${file}" "./${file}" >/dev/null
```

任意不一致（`diff -q` 非零退出）即 `echo "FATAL: sample mismatch for ${file}"; rm -rf "${BACKUP_DIR}"; exit 1`。

**路径存在性兜底**：若某个关键文件在当前工作树不存在（例如 `ThemeRenderLayer.swift` 路径发生过重命名），抽样检查会失败；tasks 阶段需在首次运行时通过 `--list-samples` 自检实际路径存在性并在 bugfix.md 登记该路径（仍保持 bugfix.md 为单一来源）。

### 5.6 `.gitignore` 前置检查

`.gitignore` 当前已覆盖 `.codex-backups/`、`.trae/` 等，但 **未覆盖 `.local-backups/`**（查阅当前工作树文件确认）。脚本首步 SHALL：

```bash
grep -q '^\.local-backups/$' .gitignore || {
  echo "ERROR: .gitignore must cover .local-backups/ before backing up. Add a line '.local-backups/' and rerun."
  exit 1
}
```

tasks 阶段的"备份前置任务"子任务之一就是补齐 `.gitignore`（单行追加 `.local-backups/`）。

### 5.7 失败处理

任一步骤非零退出：
- 已创建的 `${BACKUP_DIR}` 整体 `rm -rf`，避免"部分备份"造成误判；
- 终端打印失败步骤与退出码；
- `exit 1`，不尝试自动重试；修复流程随即停下。

### 5.8 还原脚本

配套 `scripts/restore-backup.sh <backup_dir>`：
- `rsync -a --delete "${backup_dir}/source/" ./`；排除 `.git/`；
- 校验 `manifest.sha256`；
- 打印 `manifest.txt` 的 `GIT_HEAD` 与 `GIT_STASH_REF`，提示用户"若需恢复未提交改动，可 `git stash apply ${GIT_STASH_REF}`"。

## 基线性能测试计划

### 6.1 基线采集时机

在 **§5 备份完成后、§Component Design 任何代码改动前**，使用 Instruments 采集修复前基线。

### 6.2 Instruments 模板

- **Animation Hitches**（iOS 17+）：记录 hitch ratio、P95 / P99 frame interval、scrollFPS；
- **Time Profiler**：主线程栈抽样；
- **SwiftUI**（iOS 17+）：`View body` 调用 trace；

**采样脚本**：`scripts/collect-baseline.sh`，驱动 `xcrun xctrace record --template ...` 并归档到 `.local-backups/main-tabs-theme-frame-drop-<UTC>/baseline/<device>/<scenario>.trace`。

### 6.3 场景矩阵

每个 (T, P) 组合执行以下 5 类场景（共 20 × 5 = **100 条 trace**）：

1. **冷启进入**：App kill → 启动 → 进入该 (T, P) 的首屏；
2. **30s 滚动**：在 (T, P) 内持续上下滚动 30 秒；
3. **60s 播放中停留**：启动播放 → 进入 (T, P) → 停留 60 秒（含歌词 / 进度 / 封面色高频事件）；
4. **20 次连切 tab**：在 T 不变下循环 `home → podcast → library → profile → home`，20 轮；
5. **10 次深浅色切换**：在 (T, P) 下连续切换系统外观 10 次。

### 6.4 量化指标

导出 CSV 到 `baseline/metrics.csv`，字段：

- `theme, tab, scenario, device, refreshRate, hitch_count, hitch_ratio_ms_per_s, frame_interval_p50_ms, frame_interval_p95_ms, frame_interval_p99_ms, commit_ms_mean, commit_ms_p95, scroll_fps, body_invalidations_per_second`

### 6.5 阈值敲定

按 bugfix §15 的"TBD"项，用基线值 × 目标改善倍率填回：

- `hitch_ratio_ms_per_s` 修复后 ≤ baseline × **0.4**；
- `frame_interval_p95` 修复后 ≤ baseline × **0.6**；
- `commit_ms_p95` 修复后 ≤ baseline × **0.6**；
- `body_invalidations_per_second` 修复后 ≤ baseline × **0.25**（因为 §1 / §11 / §12 订阅下沉预期下降幅度最大）。

tasks 阶段由本 design 的 M4 里程碑完成 TBD 替换，替换后 bugfix.md 不再有 TBD 字样。

### 6.6 验证采集

每个 §Component Design 的任务完成后：

- 在相同设备、相同场景下复采 Instruments trace；
- 与 §6.5 阈值比对；
- 未达阈值的任务 → 回退该任务的代码改动（通过 feature flag 关闭或代码级 revert）；记录在 `tasks.md`（后续 tasks 阶段生成）中。

## 风险与回退策略

### 7.1 软阴影缓存的跨 scale 风险

**风险**：§3.14 的 9-patch 阴影在 2x / 3x 设备上栅格化抗锯齿边缘可能与 SwiftUI `.shadow` 存在肉眼可见的差异。

**缓解**：
- 缓存 key 绑定 `UIScreen.main.scale`；
- 每 scale 独立缓存；
- snapshot 矩阵覆盖 2x (iPhone mini) 与 3x (iPhone Pro) 两档；
- 只要任一档出现 diff > 阈值 → 整个 Level 2 软阴影缓存按主题回退，保留 F 原 `.shadow` 路径。

### 7.2 `ImageRenderer` 对 `blendMode(.softLight)` 的栅格化风险

**风险**：若把 `Canvas + blur + softLight` 整体丢给 `ImageRenderer`，栅格化结果与 runtime SwiftUI 合成链（Canvas 栅格 → blur → softLight）可能有差异，主要来自 softLight 在栅格化后与底色合成的颜色空间差异。

**缓解**：
- `softLight` 层 **不** 合入栅格化；
- 只把最底层 `Canvas + blur` 栅格化为 `UIImage`；
- `softLight` 层仍由 runtime `.blendMode(.softLight)` 叠加。
- 对应 §3.3 的实现细节。

### 7.3 `LazyHStack` 内 `scrollTransition` 的 phase 差异

**风险**：在 iOS 17 中，`LazyHStack` 的 item 在进入 / 离开 recycle boundary 的瞬间，`scrollTransition` 计算的 phase 可能与 `HStack` 预构建的 item 有亚像素差异。

**缓解**：
- 过渡曲线 diff 矩阵中对每个 `(*, podcast)` 横向 section 加采样；
- 若出现 phase 差异 → 对该 section 保留 `HStack`（牺牲一点性能以换视觉等价）；
- 在 `tasks.md` 记录已保守保留的 section。

### 7.4 `TabView(.page)` 预热策略变更

**风险**：改变"相邻页 eager → lazy"可能导致 `UIPageViewController` 的页面指示器与实际页面之间出现错位（indicator 显示"相邻页已就绪"但内容尚未构建）。

**缓解**：
- 不改 `TabView(.page)` 结构本身；
- 只在数据层 lazy，视图层仍提供 skeleton 占位；
- `matchedGeometryEffect` 不动。

### 7.5 `ThemeChangeBus` 迁移期的混合态

**风险**：迁移过程中，存在"部分订阅者已迁移到 `ThemeChangeBus.palette`，部分仍订阅 `globalThemeRevision`"的混合态，若两路不同步可能造成"UI 一半已重染、一半未重染"。

**缓解**：
- 迁移期内 `SettingsManager` 并行发射新旧两种事件（旧 `globalThemeRevision.&+= 1` + 新 `ThemeChangeBus.palette.send()`）；
- 所有订阅者全部迁移完成后，再移除旧事件发射；
- 在 `tasks.md` 单独一条任务"移除 `globalThemeRevision` 旧发射路径"放在最末。

### 7.6 Snapshot diff 失败 → 回退路径

任何 §Component Design 的任务，若其 snapshot diff 或 transition curve diff 失败：

1. 立即关闭对应 `FeatureFlags.xxx`（默认设为 false）；
2. 若 flag 不可控（例如是"订阅拓扑"这种没有 flag 的改造），通过 `scripts/restore-backup.sh <backup_dir>` 针对性回退该文件；
3. 在 `tasks.md` 记录失败原因、diff 图、是否需要重新设计；
4. 若整个里程碑多项任务失败 → 整里程碑回滚，回到上一个稳定态（上一次备份点）。

### 7.7 测试覆盖不到的设备 / 环境

**风险**：snapshot 矩阵只覆盖 3 种设备 × 2 种 colorScheme × 2 种 Dynamic Type 档，不能覆盖所有 iOS 17+ 设备。

**缓解**：
- 在发布前人工回归抽样几台常见设备（至少 iPhone SE / iPhone Pro Max / iPad Pro）；
- 首次发布时对关键路径开启"内部灰度"，监控线上 hitch 报表；
- 保留 `Debug menu` 的 "revert to F pipeline" 选项，必要时在线运行时回退。

## Testing Strategy

### Validation Approach

两阶段：
1. **Exploratory Fault Condition Checking**：在 F（未改动）上跑 baseline + 写探索测试证伪 / 证实 §Hypothesized Root Cause 中的 A / B / C / D 四类假设；
2. **Fix Checking + Preservation Checking**：在 F'（逐项修复）上跑 §Correctness Properties 的 Property 1 ~ Property 6。

任何 Preservation Property 失败 → 严格回退。Fix Property 未达阈值 → 按 §7.6 回退或调阈值（阈值只允许在 baseline × 倍率范围内放松，不得无条件放宽）。

### Exploratory Fault Condition Checking

**Goal**：在修复前先观察到 F 的掉帧反例，证实根因假设；若观察不到 → 回到 §Root Cause Analysis 重新分层。

**Test Plan**：在 F 上跑 §6.3 的 100 条场景 trace，对比 Instruments 输出与根因假设。

**Test Cases**：

1. **`globalThemeRevision` 广播证实**（对应根因 A / 缺陷 §1.1 / §1.2）：
   - 脚本：`scripts/explore-theme-broadcast.sh`；
   - 步骤：进入 `(*, home)` → 切换 colorScheme 1 次 → 记录 `_printChanges()` 所列的 body 重算节点；
   - 预期失败（在 F 上）：4 个 tab 的根 View 都在列表中，FloatingBar 根也在列表中，总数显著超过"真正依赖色彩"的节点。

2. **`.id("\(themeId)-\(revision)")` 卸载重建证实**（对应根因 B / 缺陷 §1.3）：
   - 步骤：给 FloatingBar 根视图的 `init` / `deinit` 加计数；bump revision → 观察 `init` / `deinit` pair；
   - 预期失败（在 F 上）：revision 自增 1 次 → FloatingBar 根有 1 次 init + 1 次 deinit。

3. **Canvas + blur 热点证实**（对应根因 C / 缺陷 §2.2 / §7.1）：
   - 步骤：冷启进入 `(default, home)` → Time Profiler 栈采样；
   - 预期失败（在 F 上）：`_draw` / `CGContext` / `CA::Render::ShadowRenderer` 等符号出现在主线程热点前 5。

4. **Podcast 横向 section 非 lazy 证实**（对应根因 D / 缺陷 §9.1）：
   - 步骤：进入 `(*, podcast)` → 给每个 section 的 item `init` 加计数；
   - 预期失败（在 F 上）：section 一进入视野即全量 init，不等滚动到可视区。

5. **LibraryHeader 手势冲突证实**（对应根因 D / 缺陷 §14.1）：
   - 步骤：`(*, library)` 下拉起手瞬间用 Instruments Animation Hitches 录制 500ms；
   - 预期失败（在 F 上）：起手首帧产生 hitch。

**Expected Counterexamples**：以上 5 条均应在 F 上复现。若任一条不能复现 → 对应根因假设需要重新评估，本 design 的对应修复也需要重新设计。

### Fix Checking

**Goal**：对 `isBugCondition(X) == true` 的所有 X，F' 满足 §Correctness Properties Property 1。

**Pseudocode**：

```
FOR ALL X WHERE isBugCondition(F, X) DO
  result := runPipeline(F', X)
  ASSERT NOT exists_hitch(F', X)
  ASSERT mainthread_commit_ms(F', X) <= frameBudget(X.deviceRefreshRate)
  ASSERT redundant_body_invalidations(F', X) <= allowedBudget(X)
END FOR
```

**Test Plan**：§6.3 的 100 条场景在每个里程碑结束时复采，metrics 与阈值（§6.5）比对。

**Test Cases**：

1. `(manga, home) + enterTab`：hitch 从 baseline → 0（§3.1 / §3.4 配合）。
2. `(neumorphic, home) + secondTick + isPlaying`：稳态 hitch ratio ≤ baseline × 0.4。
3. `(capsule, home) + bannerTimer`：翻页期间 hitch count ≤ 1。
4. `(*, podcast) + scroll`：P95 frame interval ≤ baseline × 0.6。
5. `(*, library) + 下拉`：起手 hitch = 0。
6. `(*, profile) + lyricTick + isPlaying`：根 body 重算次数 = 0（allowedBudget = 0），仅子组件重算。
7. `any + themeRevisionBump`：FloatingBar 根 identity 稳定（无卸载 + 重建）；重算节点数 ≤ allowedBudget。

### Preservation Checking

**Goal**：对所有 X（C(X) 与 ¬C(X) 都算），F' 满足 Property 2 / 3 / 4 / 5 / 6。

**Pseudocode**：

```
FOR ALL X DO
  ASSERT visual_equivalent(F(X), F'(X))              // §4.1 稳态 snapshot
  ASSERT transition_curve_equivalent(F(X), F'(X))     // §4.2 过渡曲线
  ASSERT functional_equivalent(F(X), F'(X))
  ASSERT data_side_effects(F(X)) = data_side_effects(F'(X))
END FOR
```

**Testing Approach**：Snapshot + Property-based + 单元 / 集成三层。

**Test Plan**：
- 稳态 snapshot 矩阵见 §4.1；
- 过渡曲线矩阵见 §4.2；
- 功能等价：单元测试覆盖事件订阅下沉、迁移逻辑；集成测试覆盖用户操作路径。

**Test Cases**：

1. **稳态 snapshot**：§4.1 的 80 组最小子集在 M1 结束时全部通过（每个 Level 0 改造不应改变像素）。
2. **过渡曲线**：`scrollTransition` / 主题切换 / TabView 翻页 / bannerTimer / LibraryHeader 折叠 5 类过渡的曲线 diff 全部 ≥ 0.98。
3. **FloatingBar 事件不丢**：播放中切主题 → FloatingBar 歌词 / 进度 / 封面仍实时更新。
4. **Podcast 数据不丢**：lazy 化后所有 item 仍可访问。
5. **Library 翻页与 matchedGeometry 保留**：功能测试通过。
6. **Profile 4 路刷新保留**：功能测试通过。
7. **迁移兼容**：`GlobalThemeId.removed` 值历史持久化数据加载测试通过。

### Unit Tests

- `GlobalThemeRevisionSplitTests`：断言 `paletteRevision` / `rendererRevision` 在不同触发源下被独立 bump，且旧 `globalThemeRevision` getter 返回值与新字段组合一致。
- `ThemeChangeBusTests`：断言订阅者只收到相关事件。
- `DiffuseBackgroundCacheTests`：同一 key 的 `ImageRenderer` 输出缓存命中；`rendererRevision` 变化时 miss；不同 scale 独立缓存。
- `MangaDotsTexturePatternTests`：同 key 像素等价。
- `VisibilityGatedTimelineViewTests`：`paused` 在各信号组合下的真值表覆盖。
- `LibraryHeaderScrollGeometryTests`：`onScrollGeometryChange` 驱动 `libraryHeaderCollapseProgress` 与原 `DragGesture` 版本在相同 offset 输入下输出一致。
- `BackupScriptTests`：在 sandbox 仓库下 dry-run，断言排除列表 / manifest 字段 / sha256 / sample diff 全部正确。

### Property-Based Tests

（PBT 目标：用生成式输入覆盖离散样本难以穷举的场景）

- **PBT-1（Property 1 / 性能不变量）**：生成随机 `Interaction` 序列（长度 N），在真机上跑 HitchRecorder，断言 `hitch_ratio ≤ baseline × 0.4`。属真机 performance property；generator 受限于 XCTest Performance。
- **PBT-2（Property 2 / 稳态等价）**：生成随机主题 × 色彩方案 × Dynamic Type × 设备 × 滚动 offset，拍 snapshot 与 F 比对。
- **PBT-3（Property 3 / 过渡曲线）**：生成随机"触发序列"（切主题 / 切色彩 / 翻页 / 滚动），录过渡帧并比对曲线。
- **PBT-4（Property 4 / 功能等价）**：生成随机事件序列（`refreshProfilePublisher / $userProfile / $downloadedSongIds / $playlists` 事件排列组合），断言 F / F' 最终 UI 数据一致。
- **PBT-5（Property 5 / 备份还原）**：在 sandbox 仓库下生成随机"未提交改动"（随机文件 / 随机内容 / 随机路径），运行备份脚本 → 还原脚本 → 断言工作树与备份时一致。
- **PBT-6（Property 6 / 迁移兼容）**：生成随机历史持久化字符串（含 removed 值），断言 F / F' 迁移产出相同结果。

### Integration Tests

- **全流程 snapshot 对比**：冷启 → 依次进入 4 tab × 5 主题 = 20 组合，每组拍稳态 snapshot 与 F 比对。
- **切主题 / 深浅色的端到端**：在 `(T₁, P)` 下切到 `(T₂, P)` → 切 colorScheme → 切 Dynamic Type → 比对最终稳态。
- **播放中 tab 切换**：播放 → 连切 20 次 tab → FloatingBar 仍反映最新状态。
- **备份 / 还原闭环**：tasks 阶段真实跑一次 `scripts/backup-before-fix.sh` → 故意改动一个文件 → `scripts/restore-backup.sh` → 断言还原一致。

## 里程碑划分

### M0 · 备份 + 基线（无代码改动）

- M0.1 补齐 `.gitignore` 的 `.local-backups/` 行；
- M0.2 实现并跑通 `scripts/backup-before-fix.sh`；
- M0.3 实现并跑通 `scripts/collect-baseline.sh`（Instruments 自动化）；
- M0.4 归档 `.local-backups/main-tabs-theme-frame-drop-<UTC>/{source, baseline, snapshots}`；
- M0.5 跑探索性测试（§Testing Strategy · Exploratory），把根因假设证实 / 证伪结果写入 M0 报告。

**准入本里程碑的代码改动数**：0。
**退出条件**：Property 5 首次通过；baseline metrics CSV 落盘；5 条 exploratory test 全部复现预期失败。

### M1 · 订阅 / identity 治理（Level 0，纯非绘制改动）

涵盖：§3.1 拆 `globalThemeRevision`、§3.2 共享 backdrop、§3.9 `AnyView` 改造、§3.10 Podcast LazyHStack、§3.12 Profile 订阅下沉、§3.13 FloatingBar identity + 订阅下沉、§3.15 TimelineView 可见性、§3.16 LibraryHeader 手势替换。

**风险**：低（不改绘制路径）。
**退出条件**：
- Property 2 / 3 / 4 通过（§4.1 最小子集 80 组 snapshot + §4.2 过渡曲线）；
- Property 1 性能改善：主题切换 body 重算节点数 ≤ baseline × 0.25；
- 5 条 fix checking test case 部分通过（E4 / E5 / E6 / E7 预期在 M1 即可通过）。

### M2 · 绘制缓存化（Level 1，逐主题上线）

涵盖：§3.3 `ThemeCustomDiffuseBackground` 缓存化、§3.4 Manga、§3.5 Muji、§3.7 Capsule 胶囊改 transform、§3.8 Default 缓存化。

**风险**：中。
**顺序建议**（每个主题独立发布，不互相依赖）：
1. Default（blur(60) 收益最大、风险最低）；
2. Manga（drawingGroup + dots pattern 成熟）；
3. Muji（纯静态纹理缓存）；
4. Capsule（transform 动画等价性需过渡曲线验证）；
5. 统一 `ThemeCustomDiffuseBackground` 缓存化（所有主题共用基础）。

**退出条件**：每主题的 §4.1 snapshot 全通过 + Instruments 达到 §6.5 阈值。

### M3 · 阴影替换评估（Level 2，默认关）

涵盖：§3.6 Neumorphic 9-patch shadow、§3.5 Muji `.shadow(radius:14)` 预渲染评估、§3.7 Capsule 双层 shadow 评估、§3.14 `CachedSoftShadow` 通用 modifier。

**风险**：高。默认 `FeatureFlags.useCachedSoftShadow = false`。
**退出条件**：
- 扩充 §4.1 snapshot 矩阵到覆盖 2x / 3x × cornerRadius 档位 × active / inactive；
- 每主题独立 A/B（flag on / off）全通过 → 对该主题默认打开；
- 任何一档 diff > 阈值 → 该主题保守保留 F 的 `.shadow` 路径，不启用 Level 2。

### M4 · 阈值回填与验收

- 用 M1 / M2 / M3 的 Instruments 结果填回 bugfix.md 的所有 TBD；
- 移除 §7.5 所述的"并行发射旧 `globalThemeRevision`"过渡路径；
- 执行 §Testing Strategy · Integration Tests 完整闭环；
- 归档最终版 baseline + after metrics 对比报告到 `.local-backups/main-tabs-theme-frame-drop-<UTC>/`；
- Property 1 ~ Property 6 全部通过 → 本 bug 结案。
