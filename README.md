<p align="center">
  <img src="docs/assets/logo.png" width="128" height="128" alt="Aside Music Logo" style="border-radius: 24px;">
</p>

<h1 align="center">Aside Music</h1>

<p align="center">
  <strong>🎵 一款精致的第三方网易云音乐 iOS 客户端</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2017%2B-blue?style=flat-square&logo=apple" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-Native-green?style=flat-square" alt="SwiftUI">
  <img src="https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square" alt="License">
</p>

<p align="center">
  <a href="#-特性">特性</a> •
  <a href="#-截图">截图</a> •
  <a href="#-安装">安装</a> •
  <a href="#-项目结构">项目结构</a> •
  <a href="#-技术栈">技术栈</a> •
  <a href="#-致谢">致谢</a>
</p>

---

## ✨ 特性

### 🎨 视觉设计
- **Liquid Glass 效果** - iOS 26 风格的液态玻璃视觉效果
- **Aura 图标系统** - 自研的浮动线条图标，1.6px 描边，64+ 自定义图标，零 SF Symbols 依赖
- **流畅动画** - 全局弹性动画与手势交互
- **深色/浅色模式** - 全局自适应系统主题，所有页面均已适配

### 🎵 播放功能
- **多种播放模式** - 顺序播放、单曲循环、随机播放
- **播放队列管理** - 下一首播放、添加到队列
- **私人 FM** - 个性化推荐电台
- **歌词显示** - 逐行滚动歌词
- **音质选择** - 标准/HQ/SQ/Hi-Res 多种音质
- **解灰功能** - 自动匹配其他音源播放无版权歌曲
- **多播放源独立管理** - 普通播放、私人FM、播客电台三种播放源互不干扰，各自维护播放状态

### 📻 播客电台
- **电台分类浏览** - 按分类标签筛选电台，支持无限滚动加载
- **电台详情** - 查看电台信息、节目列表
- **收音机模式** - 全屏沉浸式电台播放器，旋转封面、频率条动画
- **电台搜索** - 搜索电台，热门电台推荐
- **热门电台排行** - 查看热门电台排行榜

### 📱 核心功能
- **QR 码登录** - 扫码快速登录
- **手机号登录** - 验证码登录
- **每日推荐** - 每日 30 首个性化推荐
- **歌单管理** - 查看、播放用户歌单
- **歌单广场** - 按分类浏览热门歌单，无限滚动加载
- **搜索** - 歌曲、歌手、歌单、专辑搜索
- **排行榜** - 各类音乐榜单
- **歌手库** - 按地区/类型/首字母筛选歌手，支持搜索
- **歌手详情** - 歌手信息与热门歌曲
- **播放历史** - 最近播放记录

### 🔧 系统功能
- **后台播放** - 支持后台持续播放
- **锁屏控制** - 锁屏界面播放控制
- **控制中心** - 系统控制中心集成
- **智能缓存** - 图片与数据缓存优化
- **本地数据库** - SQLite 持久化存储

---

## 📸 截图

> 截图待添加

---

## 📦 安装

### 环境要求
- macOS 14.0+
- Xcode 15.0+
- iOS 17.0+

### 后端服务
本项目需要配合 [NeteaseCloudMusicApi Enhanced](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced) 后端服务使用。

```bash
# 克隆后端项目
git clone https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced.git
cd api-enhanced
pnpm install
node app.js
```

### 构建 iOS 应用

```bash
# 克隆本项目
git clone https://github.com/Lincb522/Aside-music.git
cd Aside-music

# 配置 API 地址
# 编辑 .env 文件设置 API_BASE_URL

# 使用 Xcode 打开项目
open AsideMusic.xcodeproj

# 或使用脚本构建 IPA
./build_ipa.sh
```

---

## 🏗 项目结构

```
AsideMusic/
├── Sources/AsideMusic/
│   ├── AsideMusicApp.swift          # 应用入口
│   │
│   ├── Models/                       # 数据模型
│   │   ├── Song.swift               # 歌曲模型
│   │   ├── SoundQuality.swift       # 音质枚举
│   │   └── RadioModels.swift        # 电台/播客模型
│   │
│   ├── Views/                        # 视图层
│   │   ├── ContentView.swift        # 主容器视图
│   │   ├── HomeView.swift           # 首页
│   │   ├── LibraryView.swift        # 音乐库（歌单/歌手/排行榜）
│   │   ├── SearchView.swift         # 搜索页
│   │   ├── ProfileView.swift        # 个人中心
│   │   ├── FullScreenPlayerView.swift # 全屏播放器
│   │   ├── ImmersivePlayerView.swift # 沉浸式播放器
│   │   ├── MiniPlayerView.swift     # 迷你播放器
│   │   ├── UnifiedFloatingBar.swift # 统一浮动栏（MiniPlayer + TabBar）
│   │   ├── PersonalFMView.swift     # 私人FM
│   │   ├── DailyRecommendView.swift # 每日推荐
│   │   ├── PlaylistDetailView.swift # 歌单详情
│   │   ├── ArtistDetailView.swift   # 歌手详情
│   │   ├── SongDetailView.swift     # 歌曲详情
│   │   ├── TopChartsView.swift      # 排行榜
│   │   │
│   │   ├── PodcastView.swift        # 播客首页
│   │   ├── PodcastSearchView.swift  # 播客搜索
│   │   ├── RadioDetailView.swift    # 电台详情
│   │   ├── RadioPlayerView.swift    # 收音机模式播放器
│   │   ├── RadioCategoryBrowseView.swift # 电台分类浏览
│   │   ├── CategoryRadioView.swift  # 分类电台列表
│   │   ├── TopRadioListView.swift   # 热门电台排行
│   │   │
│   │   ├── SettingsView.swift       # 设置页
│   │   ├── LoginView.swift          # 登录页
│   │   ├── LoginComponents.swift    # 登录组件
│   │   ├── WelcomeView.swift        # 欢迎页
│   │   ├── CachedAsyncImage.swift   # 缓存图片加载
│   │   ├── PlaylistPopupView.swift  # 歌单弹窗
│   │   ├── UserPlaylistRow.swift    # 用户歌单行
│   │   ├── Theme.swift              # 主题配置（自适应深色/浅色）
│   │   ├── AsideIcons.swift         # Aura 图标系统 (64+ 图标)
│   │   │
│   │   └── Components/              # 可复用组件
│   │       ├── SongListRow.swift    # 歌曲列表行
│   │       ├── LyricsView.swift     # 歌词视图
│   │       ├── LikeButton.swift     # 喜欢按钮
│   │       ├── NoMoreDataView.swift # "没有更多了"提示
│   │       ├── AsideAlert.swift     # 自定义弹窗
│   │       ├── AsideBackground.swift # 背景组件
│   │       ├── AsideLoadingView.swift # 加载动画
│   │       ├── SoundQualitySheet.swift # 音质选择
│   │       ├── StyleSelectionSheet.swift # 风格选择
│   │       ├── ScaleButtonStyle.swift # 按钮样式
│   │       ├── VisualEffectBlur.swift # 模糊效果
│   │       └── PlayingVisualizerView.swift # 播放动画
│   │
│   ├── ViewModels/                   # 视图模型
│   │   ├── PlayerManager.swift      # 播放器管理（多播放源）
│   │   ├── HomeViewModel.swift      # 首页数据
│   │   ├── LoginViewModel.swift     # 登录逻辑
│   │   ├── PodcastViewModel.swift   # 播客数据
│   │   ├── CategoryRadioViewModel.swift # 分类电台数据
│   │   └── RadioDetailViewModel.swift # 电台详情数据
│   │
│   ├── Network/                      # 网络层
│   │   ├── APIService.swift         # API 服务
│   │   └── APIService+Search.swift  # 搜索扩展
│   │
│   ├── Database/                     # 数据库层
│   │   ├── DatabaseManager.swift    # 数据库管理
│   │   ├── Models/                  # 缓存模型
│   │   └── Repositories/            # 数据仓库
│   │
│   ├── Managers/                     # 管理器
│   │   ├── SettingsManager.swift    # 设置管理
│   │   ├── CacheManager.swift       # 缓存管理
│   │   ├── OptimizedCacheManager.swift # 优化缓存管理
│   │   ├── LikeManager.swift        # 喜欢管理
│   │   ├── StyleManager.swift       # 样式管理
│   │   ├── AsideAnimation.swift     # 动画管理
│   │   ├── SwipeBackController.swift # 滑动返回控制
│   │   ├── GlobalRefreshManager.swift # 全局刷新管理
│   │   └── DataSyncCoordinator.swift # 数据同步
│   │
│   ├── Utils/                        # 工具类
│   │   ├── AlertManager.swift       # 弹窗管理
│   │   ├── AppConfig.swift          # 应用配置
│   │   ├── DeviceLayout.swift       # 设备布局
│   │   └── ErrorHandler.swift       # 错误处理
│   │
│   └── Resources/                    # 资源文件
│       ├── Assets.xcassets/         # 图片资源
│       ├── en.lproj/                # 英文本地化
│       └── zh-Hans.lproj/           # 中文本地化
│
├── Package.swift                     # Swift Package 配置
└── build_ipa.sh                      # IPA 构建脚本
```

---

## 🎯 Aura 图标系统

自研的浮动线条图标系统，采用 1.6px 描边，支持双色调渲染。项目中所有图标均为自绘 Path，不依赖任何 SF Symbols。

### 图标分类 (64+ 图标)

| 类别 | 图标 |
|------|------|
| **Tab Bar** | home, podcast, library, search, profile |
| **播放控制** | play, pause, next, previous, stop, repeatMode, repeatOne, shuffle, refresh, skipBack, skipForward, rewind15, forward15, playCircleFill |
| **操作** | like, liked, list, back, more, close, trash, fm, bell, save, add, playNext, addToQueue, xmarkCircle |
| **设置** | settings, download, cloud, chevronRight, magnifyingGlass, xmark, fullscreen, sparkle, soundQuality, storage, haptic, info |
| **播放器** | clock, musicNoteList, chart, translate, karaoke, lock, unlock, qr, phone, send, musicNote, history, playCircle |
| **播客电台** | radio, micSlash, waveform, gridSquare |
| **状态** | warning, personEmpty |

### 设计特点

- **浮动元素** - 断开的线条，几何构造
- **双色调** - 描边 + 15% 透明度填充
- **圆角连接** - lineCap: round, lineJoin: round
- **统一尺寸** - 24x24 基准，支持任意缩放
- **零依赖** - 全部自绘 Path，不使用 SF Symbols

---

## 🛠 技术栈

| 类别 | 技术 |
|------|------|
| **UI 框架** | SwiftUI |
| **架构模式** | MVVM |
| **网络请求** | URLSession + Combine |
| **数据持久化** | SQLite (自定义封装) |
| **缓存策略** | 内存缓存 + 磁盘缓存 |
| **音频播放** | [SwiftAudioEx](https://github.com/doublesymmetry/SwiftAudioEx) |
| **远程控制** | MediaPlayer |
| **视觉效果** | [LiquidGlassEffect](https://github.com/Lincb522/LiquidGlassEffect) |
| **依赖管理** | Swift Package Manager |

---

## 🚧 待开发功能

### 高优先级
- [ ] **歌曲下载** - 离线缓存歌曲
- [ ] **播放列表编辑** - 创建、编辑、删除歌单
- [ ] **评论系统** - 查看歌曲评论
- [ ] **分享功能** - 分享歌曲/歌单

### 中优先级
- [ ] **MV 播放** - 音乐视频播放
- [ ] **歌词翻译** - 显示翻译歌词
- [ ] **定时关闭** - 睡眠定时器
- [ ] **均衡器** - 音效调节 (基于 AudioKit 重构中)
- [ ] **CarPlay 支持** - 车载播放

### 低优先级
- [ ] **社交功能** - 关注、动态
- [ ] **直播** - 音乐直播
- [ ] **Widget** - 桌面小组件
- [ ] **Apple Watch** - 手表应用

---

## 🙏 致谢

### 核心依赖

<table>
  <tr>
    <td align="center">
      <a href="https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced">
        <img src="https://avatars.githubusercontent.com/u/200893893?s=200&v=4" width="64" height="64" alt="NeteaseCloudMusicApi Enhanced">
        <br>
        <strong>NeteaseCloudMusicApi Enhanced</strong>
      </a>
      <br>
      <sub>网易云音乐 API 服务</sub>
    </td>
    <td align="center">
      <a href="https://github.com/Lincb522/LiquidGlassEffect">
        <img src="https://raw.githubusercontent.com/Lincb522/LiquidGlassEffect/main/docs/assets/logo.png" width="64" height="64" alt="LiquidGlassEffect">
        <br>
        <strong>LiquidGlassEffect</strong>
      </a>
      <br>
      <sub>iOS 26 液态玻璃效果库</sub>
    </td>
    <td align="center">
      <a href="https://github.com/doublesymmetry/SwiftAudioEx">
        <img src="https://avatars.githubusercontent.com/u/15884486?s=200&v=4" width="64" height="64" alt="SwiftAudioEx">
        <br>
        <strong>SwiftAudioEx</strong>
      </a>
      <br>
      <sub>iOS 音频播放引擎</sub>
    </td>
  </tr>
</table>

### 特别感谢

- [NeteaseCloudMusicApiEnhanced](https://github.com/NeteaseCloudMusicApiEnhanced) - 提供强大的网易云音乐 API 服务，包括解灰功能
- [Binaryify](https://github.com/Binaryify) - 原版 NeteaseCloudMusicApi 作者
- 所有为网易云音乐逆向工程做出贡献的开发者

### 参考项目

- [YesPlayMusic](https://github.com/qier222/YesPlayMusic) - 高颜值的第三方网易云播放器
- [listen1](https://github.com/listen1/listen1_chrome_extension) - 多平台音乐聚合

---

## 📄 许可证

本项目基于 [MIT License](LICENSE) 开源。

---

## ⚠️ 免责声明

- 本项目仅供学习交流使用，请勿用于商业用途
- 使用本项目时请遵守相关法律法规
- 音乐版权归网易云音乐及相关权利人所有
- 本项目不提供任何音乐资源，所有数据来自网易云音乐官方 API

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/Lincb522">Lincb522</a>
</p>
