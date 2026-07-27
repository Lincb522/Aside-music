# Mono 工程目录审计

更新时间：2026-07-24

## 当前结论

工程同时包含 iOS App、小组件与扩展、共享代码、本地 Swift Package、服务端、官网、图标源文件、构建产物和历史备份。前三阶段已经把 App 源码、播放器内部结构以及根目录外部产品分区完成，产品代码、运行时依赖、设计源文件、服务端与官网之间已有明确边界。

工程使用 Xcode 文件系统同步分组，SwiftPM target 会递归包含 `Sources/Mono` 中的源码。本轮目录整理只调整文件位置和路径配置，不修改功能实现。

## 本轮已完成

- `Views` 根目录从 74 个 Swift 文件清理为 0，页面按声音中心、设置、开发工具、内容、媒体库、收听报告、一起听、社交、电台、视频等领域归类。
- `ViewModels` 根目录清理为 0，并与对应页面领域对齐。
- `Managers` 根目录清理为 0，拆分为 AI、音频、外观、缓存、云端、下载、媒体库、统计、会话、设置和系统能力。
- `Network` 根目录清理为 0，拆分为 API、AI、音乐服务、媒体服务和安全能力。
- `Models` 根目录清理为 0，拆分为账号、AI、外观、音频、内容、会话、来源和社交模型。
- `MonoPlaybackEngine*` 已从 `ViewModels` 迁移到 `Playback/Engine`。
- App 入口、Quick Action、设计系统和预览支持文件已归位。
- 通用 `Components` 已按 AI、品牌、控件、反馈、浮动播放器、交互、歌词、媒体、页面、歌单、Sheet、歌曲和系统能力继续拆分。
- 播放器组件已按背景、封面、控制、字体、歌词和菜单归类；Aria 舞台内部已拆分为核心、歌词、设置、歌架和视觉层。
- `Playback` 已拆分为 Engine、Cache、NowPlaying、Presentation、Resolution、Session、Sources 和 State。
- 本地 Swift Package 已统一迁入 `Packages`，并按 Audio、MusicServices、Icons 分类。
- 图标原始素材已迁入 `DesignAssets/IconSources`，不再与运行时图标包混放。
- 服务端已迁入 `Services/Server`，官网已迁入 `Web/website`。
- `Package.swift`、Xcode 本地 Package 引用、图标生成脚本、备份脚本与忽略规则已同步到新路径。
- 已删除未被 target 使用的根目录旧 `Info.plist`。
- 已删除写死旧页面路径的一次性脚本 `tmp_insert_stats.py`。

## 规模

| 区域 | Swift 文件 | 代码行数 |
| --- | ---: | ---: |
| `Views` | 220 | 157,333 |
| `Managers` | 51 | 24,243 |
| `Themes` | 37 | 16,885 |
| `ViewModels` | 39 | 10,495 |
| `Network` | 21 | 9,883 |
| `Models` | 29 | 6,762 |
| `Playback` | 11 | 5,964 |
| `Utils` | 11 | 2,797 |
| `Database` | 14 | 2,730 |

`Views`、`ViewModels`、`Managers`、`Network`、`Models`、`Components` 和 `Playback` 的直接根文件均已归类。最大的页面文件仍超过 5,000 行，目录整理不能替代后续按页面区域拆分组件。

## 主要问题

### 1. 根目录职责混杂（已处理）

迁移前根目录同时存在：

- App：`Sources/Mono`
- 扩展：`music`
- 共享代码：`Shared`
- 音频与平台 SDK：现位于 `Packages/Audio`、`Packages/MusicServices`
- 运行时图标包：现位于 `Packages/Icons`
- 图标原始素材：现位于 `DesignAssets/IconSources`
- 服务端与官网：现位于 `Services/Server`、`Web/website`
- 构建与临时目录：`build`、`tmp`
- 多套备份与压缩包

其中 `H173Icons-source` 约 481 MB、`new-icons-svg` 约 24 MB，而且不属于 `Package.swift` 的运行时依赖。现已作为设计源文件独立管理，不再与可编译包处于同一层级。

### 2. `Views` 根目录过度平铺

设置、开发工具、音频中心、社交、歌单、搜索、电台、MV 和播放器页面混在同一目录。已有 `Home`、`Library`、`Player`、`Podcast` 子目录，但同类页面仍有一部分留在根目录，分类规则不一致。

### 3. `Managers` 成为通用收纳目录

`Managers` 同时包含 AI、音频实验、缓存、下载、云同步、歌词、统计、主题、播放地址和会话能力。它们之间并不属于同一层，后续很难判断功能入口和依赖方向。

### 4. 播放引擎放在 `ViewModels`

`MonoPlaybackEngine.swift` 及其扩展实际承担播放控制、队列事务、切歌、Seek、状态提交和播放恢复，不是页面 ViewModel。它们应归入 `Playback/Engine`。

### 5. 同一功能横跨多层目录

以 AI 调音为例，其模型位于 `Models`，Agent、采样器和提示词位于 `Managers`，请求客户端位于 `Network`，页面位于 `Views`。这种分层在规模较小时可用，但当前功能量已经更适合按领域聚合。

### 6. 根目录存在历史文件

- 根目录 `Info.plist` 没有被当前 Xcode target 使用；实际使用的是 `Sources/Mono/Info.plist`。
- `tmp_insert_stats.py` 没有发现工程引用，属于一次性历史脚本。
- `.local-backups` 已加入忽略规则，但仍有早期备份文件被 Git 跟踪。
- `build`、`tmp` 和多个压缩包虽多数已忽略，仍会显著增加本地工作区体积和搜索噪声。

## 建议目标结构

```text
asidemusic-main/
├── Sources/
│   └── Mono/
├── music/
├── Shared/
├── Packages/
│   ├── Audio/
│   │   └── ffmpeg-swift/
│   ├── MusicServices/
│   │   ├── NeteaseCloudMusicAPI-Swift/
│   │   └── QQMusicKit/
│   └── Icons/
│       ├── HiconIcons/
│       ├── ZappiconIcons/
│       └── ...
├── Services/
│   └── Server/
├── Web/
│   └── website/
├── DesignAssets/
│   └── IconSources/
├── Scripts/
├── Tools/
├── Tests/
└── docs/
```

该结构已在第三阶段落地。App、扩展和共享代码暂不继续套入新的 `Apps` 层，避免一次性扩大 Xcode target 路径变更范围。

## App 内建议结构

```text
Sources/Mono/
├── App/
│   ├── MonoApp.swift
│   ├── ContentView.swift
│   └── QuickActions/
├── Core/
│   ├── Audio/
│   │   ├── Engine/
│   │   ├── Processing/
│   │   └── Session/
│   ├── Networking/
│   ├── Persistence/
│   ├── Cache/
│   ├── DesignSystem/
│   ├── Logging/
│   └── Utilities/
├── Features/
│   ├── Home/
│   ├── Search/
│   ├── Library/
│   ├── Player/
│   ├── AudioCenter/
│   ├── Settings/
│   ├── Developer/
│   ├── Downloads/
│   ├── ListeningReports/
│   ├── Session/
│   ├── Social/
│   ├── Podcast/
│   ├── Radio/
│   ├── MV/
│   └── Authentication/
├── Themes/
└── Resources/
```

每个 `Features` 子目录可以包含自己的 `Views`、`ViewModels`、`Models` 和 `Components`。跨功能复用的能力才进入 `Core`，避免重新产生一个新的通用收纳目录。

## 建议迁移顺序

### 第一批：低风险清理

1. 已移除未被 target 使用的根目录 `Info.plist`。
2. 已删除失效的 `tmp_insert_stats.py`。
3. 停止跟踪 `.local-backups` 中的历史备份。
4. 将图标原始素材与运行时图标 Package 明确分开。
5. 删除两个空目录：
   - `Views/Player/Components/Previews`
   - `Views/Player/Themes`

### 第二批：只移动、不改实现

1. 已将 `MonoPlaybackEngine*` 从 `ViewModels` 移至 `Playback/Engine`。
2. 已将 `CachedAsyncImage`、`UnifiedFloatingBar`、`MonoIcons` 等公共视图归入 `Components` 或 `DesignSystem`。
3. 已将设置和开发者工具页面分别归入对应领域目录。
4. 已将 Library、Podcast、Player 等留在根目录的页面归位。

### 第三批：按功能聚合

已完成 AI 调音、声音中心、下载、听歌报告、一起听等主要功能的目录聚合。后续新增文件应直接进入现有领域目录，不再回到 `Views`、`ViewModels`、`Managers`、`Network` 或 `Models` 根目录。

### 第四批：拆分超大文件

优先拆分：

1. `ProfileView.swift`
2. `SearchView.swift`
3. `SettingsView.swift`
4. `LibraryDefaultViews.swift`
5. `UnifiedFloatingBar.swift`
6. `AIEqualizerLabView.swift`
7. `PodcastView.swift`

拆分依据应是页面区域和职责，而不是按固定行数切文件。

### 第五批：根目录与 Package 重排（已完成）

已移动 SDK、图标 Package、服务端和官网，并统一更新：

- `Package.swift`
- `Mono.xcodeproj/project.pbxproj`
- `Secrets.xcconfig` 相关路径
- 构建与部署脚本
- CI 或远程部署配置

## 安全规则

1. 一次只迁移一个领域，不同时修改功能逻辑。
2. Swift 文件移动后保持类型名和访问级别不变。
3. 字体、JSON、Asset Catalog 和本地化资源暂不移动，避免破坏 SwiftPM 资源路径。
4. `Sources/Mono/Info.plist`、entitlements 和扩展资源保持原位，直到 Xcode 配置一并迁移。
5. 每批迁移单独提交，确保可以按目录批次回退。

## 第四阶段根目录整理

正式 App、SwiftPM 和 Xcode 配置均没有引用 `ncm-home`、`website-redesign`、`.codex-site-work`、`architecture`、`Backups` 或 `backup`。这些目录已按用途迁移或归档，历史数据没有被直接销毁。

### 保留

| 路径 | 原因 |
| --- | --- |
| `.agents` | 当前仓库的 SwiftUI 性能审计 Skill 位于此处 |
| `.codex` | `AGENTS.md` 直接引用其中的 UI 文案约束 |
| `.codebase-memory` | 当前代码知识图谱及共享索引 |
| `Sources`、`Shared`、`music` | App、共享代码和扩展源码 |
| `Packages` | App 的本地 Swift Package 依赖 |
| `Services`、`Web` | 服务端与正式官网 |
| `DesignAssets` | 图标源文件、品牌文件与导出资产 |
| `assets` | `README.md` 仍引用其中的 App 图标 |

### 已迁移到明确分区

| 原路径 | 当前路径 | 说明 |
| --- | --- | --- |
| `studio` | `Tools/AgentStudio` | 独立的 2D Agent 开发工作室，不属于 iOS target |
| `architecture` | `docs/architecture` | Agent 生成的架构图与 HTML |
| `exports` | `DesignAssets/Exports` | 已导出的图标切图和压缩包 |
| `monoIcon.svg` | `DesignAssets/Branding` | 品牌源文件 |
| `build_ipa.sh` | `Scripts/Release` | 发布工具，不再散落在根目录 |
| `PRODUCT.md` | `docs/PRODUCT.md` | 产品定位与设计原则 |
| `LOCALIZATION.md` | `docs/LOCALIZATION.md` | 本地化维护说明 |
| `CHANGELOG.txt` | `docs/CHANGELOG.txt` | 历史更新日志 |
| `.kiro/specs/main-tabs-theme-frame-drop` | `docs/specs/main-tabs-theme-frame-drop` | 备份脚本仍使用的历史规格 |

`Tools/AgentStudio` 的默认工作区与启动说明已同步适配新目录；`Scripts/Release/build_ipa.sh` 会先自动切换到仓库根目录。

### 已移出仓库归档

归档位置：`/Users/linchengbo/Downloads/asidemusic-archives/2026-07-24`

| 原路径 | 体积 | 归档分区 |
| --- | ---: | --- |
| `.local-backups` | 约 256 MB | `backups/local-backups` |
| `Backups` | 约 15 MB | `backups/project-backups` |
| `backup` | 约 100 KB | `backups/legacy-backup` |
| `.codex-backups` | 约 872 KB | `backups/codex-backups` |
| `music-api-backup.tar.gz` | 约 145 MB | `archives` |
| `music 2.zip` | 约 44 KB | `archives` |
| `build` | 约 1.3 GB | `generated/build` |
| `tmp` | 约 51 MB | `generated/tmp` |
| `.codex-site-work` | 约 12 MB | `generated/codex-site-work` |
| `ncm-home` | 约 184 KB | `generated/ncm-home` |
| `website-redesign` | 约 12 MB | `generated/website-redesign` |
| `CODEX_UPDATE_LOG.md` | 约 1.3 MB | `generated` |
| `ExternalSources` | 约 31 MB | `references` |
| Skill 中的历史 `.mp4`、`*.ips` | 约 1.3 MB | `skill-attachments` |
| `.claude`、`.cursor`、`.vscode`、剩余 `.kiro` | 少量 | `configs` |
| `mono-main.code-workspace` | 少量 | `configs` |
| 损坏的 `Scripts/restore-backup.sh` | 少量 | `generated/broken-scripts` |

`ExternalSources/folia-major` 已移入仓库外归档。App 仅在注释中提到 Folia 设计，不依赖其本地文件。
