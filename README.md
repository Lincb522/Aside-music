<p align="center">
  <img src="assets/icon.png" width="112" height="112" alt="Mono App Icon" />
</p>

<h1 align="center">Mono</h1>

<p align="center">
  <strong>世界很吵，留一点声音给自己。</strong><br />
  <sub>LOUD WORLD · QUIET SOUND</sub>
</p>

<p align="center">
  <a href="https://github.com/Lincb522/Mono/actions/workflows/ios-ci.yml"><img alt="Mono iOS CI" src="https://github.com/Lincb522/Mono/actions/workflows/ios-ci.yml/badge.svg" /></a>
  <img alt="iOS 16+" src="https://img.shields.io/badge/iOS-16%2B-111111?style=flat-square&logo=apple&logoColor=white" />
  <img alt="Swift 6.2" src="https://img.shields.io/badge/Swift-6.2-F05138?style=flat-square&logo=swift&logoColor=white" />
  <img alt="SwiftUI" src="https://img.shields.io/badge/UI-SwiftUI-0A84FF?style=flat-square" />
  <img alt="FFmpeg 8" src="https://img.shields.io/badge/Audio-FFmpeg%208-5A9E2F?style=flat-square&logo=ffmpeg&logoColor=white" />
</p>

Mono 是一款面向 iPhone 与 iPad 的原生音乐播放器。它接入多个音乐平台与本地音乐，并统一处理搜索、歌单、播放队列、歌词、音效、后台播放和系统媒体状态。

## 功能

| 模块 | 内容 |
|---|---|
| 音乐来源 | NCM、QCM、QSM、KCM、Apple Music、本地音乐 |
| 播放 | 首播预载、无缝切歌、后台续播、控制中心、灵动岛、小组件 |
| 歌词 | 多歌词源、逐字歌词、翻译、自定义字体、沉浸模式 |
| 声音中心 | 10/32 段均衡器、内置预设、专业处理、输出设备校准、Mono Audio Agent |
| 内容 | 歌单、榜单、歌手、专辑、MV、评论、音乐幕后 |
| 数据 | 播放记录、听歌统计、日报与周报、云同步、下载管理 |
| 个性化 | 全局主题、播放器主题、图标包、配色与在线字体 |

## 核心系统

完整的当前实现、职责边界、接入状态与源码入口见 [Mono 引擎总览](docs/architecture/mono-engine-catalog.md)。

### Mono播放引擎

基于 FFmpeg 8 与 AVAudioEngine，负责网络媒体取址、格式探测、解封装、解码、缓冲、Seek、输出、音频会话和后台恢复。Apple Music 受保护内容使用 MusicKit 播放通道。

### Mono Continuity Engine

管理播放事务、队列身份和预加载任务。下一首歌曲会提前取址并准备解码管线；过期任务在切歌后失效，播放器界面与队列只在目标歌曲真正开始播放后提交状态。

### Mono Audio Agent

读取音效处理前的音频特征，结合歌曲信息、输出设备和用户选择生成均衡、音色、空间与动态参数。调音结果按歌曲、设备、均衡器模式和方案类型保存，可复用、重做或删除。

### Mono Listening Insight Agent

读取聚合后的播放记录、收听时长、时段分布、常听歌曲与歌手，为听歌统计、日报和周报生成个性化洞察。分析结果按统计范围和报告周期缓存，避免对同一份数据重复分析。

### Mono Content Agent

为「音乐幕后」检索公开资料，并基于可追溯来源整理歌曲介绍、创作故事、发行背景和专辑介绍。内容与具体平台及歌曲版本绑定，首次生成并审核发布后持久化保存到服务端，后续直接读取已发布内容。

### Mono Sound Pipeline

统一提交图形均衡、参数均衡、动态 EQ、多段动态、低高音、混响、环绕、Haas、输出校准、耳机校正、前级余量和最终限幅，避免在播放过程中反复重建音频处理链。

### MonoVault Engine

统一管理歌曲、歌单、歌词、播放记录、听歌统计、下载、本地音乐和可再生缓存。用户内容与缓存采用不同的保留和清理规则。

## 平台支持

| 来源 | 当前接入内容 |
|---|---|
| NCM | 搜索、推荐、歌单、榜单、歌手、专辑、MV、评论、歌词、播放 |
| QCM | 搜索、推荐、歌单、榜单、歌手、专辑、MV、评论、歌词、多档音质 |
| QSM | 搜索、播放、歌词、音质选择 |
| KCM | 搜索、推荐、歌单、榜单、歌手、专辑、MV、评论、歌词、多档音质 |
| Apple Music | 目录搜索、资料库、歌手、专辑、歌单、MusicKit 播放 |
| 本地音乐 | 文件导入、本地歌单、元数据、封面、歌词、离线播放 |

不同平台的数据使用独立来源标识。相同数字 ID 不会跨平台复用歌曲、封面、歌词、缓存或播放记录。

## 开发环境

- Xcode 26.4.1 或可运行 Swift 6.2 的更新版本
- iOS 16 或更高版本
- 对应音乐服务的自建后端
- Apple Music 功能需要 MusicKit entitlement

```bash
git clone https://github.com/Lincb522/Mono.git
cd Mono
cp Secrets.xcconfig.example Secrets.xcconfig
open Mono.xcodeproj
```

在 `Secrets.xcconfig` 中填写自己的服务地址与开发配置。该文件包含本地敏感信息，不应提交到版本库。运行前还需要在 Xcode 中配置签名、App Group、MusicKit 与 Widget Extension。

## 项目结构

```text
Mono/
├── Sources/Mono/        iOS App 源码与资源
│   ├── App/             应用入口与生命周期
│   ├── Playback/        播放引擎与播放子系统
│   ├── Managers/        音频、账号、缓存、云端与业务管理
│   ├── Network/         平台 API 与媒体服务
│   ├── Database/        数据持久化与仓库
│   ├── Models/          领域模型
│   ├── Themes/          主题系统
│   └── Views/           SwiftUI 页面与组件
├── Packages/            音频、音乐服务与图标包
├── music/               Widget Extension
├── Shared/              App 与 Widget 共享模型
└── Services/Server/     自建服务与配置分发
```

## 协议与说明

| 文件 | 内容 |
|---|---|
| [用户协议](USER_AGREEMENT.md) | 服务范围、账号授权、使用规则与责任边界 |
| [隐私政策](PRIVACY_POLICY.md) | 数据处理、第三方服务、保存与删除方式 |
| [免责声明](DISCLAIMER.md) | 内容版权、外部服务、AI 功能与使用风险 |
| [开源软件许可](OPEN_SOURCE_LICENSES.md) | App 与服务使用的主要开源组件及许可证 |

Mono 本体代码、名称、图标和品牌资产未因第三方组件的开源许可而自动开放授权。第三方组件分别适用其原始许可证。

## 致谢

- [FFmpeg](https://ffmpeg.org/)
- [NeteaseCloudMusicApi Enhanced](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced)
- [QQMusicApi](https://github.com/L-1124/QQMusicApi)
- [KuGouMusicApi](https://github.com/MakcRe/KuGouMusicApi)
- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation)
- [Lucide](https://github.com/lucide-icons/lucide)

---

<p align="center">
  <strong>世界很吵，留一点声音给自己。</strong><br />
  <sub>LOUD WORLD · QUIET SOUND</sub>
</p>
