# NeteaseCloudMusicAPI-Swift
# 网易云音乐 API 原生 Swift SDK
# 362 个 API 接口的完整封装

## 概述

NeteaseCloudMusicAPI-Swift 是网易云音乐 API 的原生 Swift 封装库，
提供 362 个 API 接口，支持四种加密模式（WeAPI / EAPI / LinuxAPI / 明文），
零外部依赖，全平台支持。

## 版本

v1.0.0

## 特性

- 🎵 **362 个 API 接口** — 完整覆盖网易云音乐全部功能
- 🔐 **四种加密模式** — WeAPI / EAPI / LinuxAPI / 明文
- 🔄 **双模式运行** — 直连网易云（客户端加密）或走自部署 Node 后端
- 🍎 **全平台支持** — iOS 15+ / macOS 12+ / tvOS 15+ / watchOS 8+
- 📦 **零外部依赖** — 仅使用 Foundation + CommonCrypto + Security
- 🧪 **78 个测试用例** — 包含属性测试（SwiftCheck）
- 🎯 **Swift 原生** — async/await、强类型枚举、完整中文文档注释

## 安装

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/your-repo/NeteaseCloudMusicAPI-Swift.git", from: "1.0.0")
]
```

### Bazel

```python
# MODULE.bazel (bzlmod 模式)
bazel_dep(name = "rules_swift", version = "3.6.0", repo_name = "build_bazel_rules_swift")

# 或在 BUILD 文件中引用
deps = ["@netease_cloud_music_api//:NeteaseCloudMusicAPI"]
```

## 库结构

```
NeteaseCloudMusicAPI-Swift/
├── Package.swift                              # SPM 配置
├── BUILD.bazel                                # Bazel 构建规则
├── MODULE.bazel                               # Bazel 模块配置 (bzlmod)
├── WORKSPACE                                  # Bazel 工作区配置 (传统模式)
├── Sources/NeteaseCloudMusicAPI/
│   ├── NCMClient.swift                        # 主客户端入口
│   ├── API/                                   # 362 个 API 方法
│   │   ├── NCMClient+Auth.swift               #   登录认证 (11)
│   │   ├── NCMClient+Song.swift               #   歌曲 (26)
│   │   ├── NCMClient+Playlist.swift           #   歌单 (28)
│   │   ├── NCMClient+User.swift               #   用户 (25)
│   │   ├── NCMClient+Artist.swift             #   歌手 (17)
│   │   ├── NCMClient+Album.swift              #   专辑 (14)
│   │   ├── NCMClient+Comment.swift            #   评论 (13)
│   │   ├── NCMClient+MV.swift                 #   MV/视频 (18)
│   │   ├── NCMClient+DJ.swift                 #   电台/播客 (25)
│   │   ├── NCMClient+Search.swift             #   搜索 (8)
│   │   ├── NCMClient+Ranking.swift            #   排行榜 (8)
│   │   ├── NCMClient+Recommend.swift          #   推荐 (14)
│   │   ├── NCMClient+VIP.swift                #   VIP/云贝 (20)
│   │   ├── NCMClient+Message.swift            #   私信 (10)
│   │   ├── NCMClient+Cloud.swift              #   云盘 (6)
│   │   └── NCMClient+Misc.swift               #   其他 (119)
│   ├── Crypto/CryptoEngine.swift              # 加密引擎 (AES/RSA/MD5)
│   ├── Network/RequestClient.swift            # HTTP 请求客户端
│   ├── Session/SessionManager.swift           # 会话管理 (Cookie/UA/设备)
│   └── Models/
│       ├── APIResponse.swift                  # 响应类型、加密模式枚举
│       ├── Enums.swift                        # 搜索类型等业务枚举
│       ├── NCMConstants.swift                 # 密钥、域名等常量
│       └── NCMError.swift                     # 错误类型定义
├── Tests/NeteaseCloudMusicAPITests/           # 78 个测试用例
│   ├── CryptoEngineTests.swift                #   加密单元测试 (36)
│   ├── CryptoEnginePropertyTests.swift        #   加密属性测试 (3)
│   ├── EnumsPropertyTests.swift               #   枚举完整性测试 (27)
│   ├── RequestClientPropertyTests.swift       #   请求客户端测试 (6)
│   ├── SessionManagerPropertyTests.swift      #   会话管理测试 (5)
│   └── NeteaseCloudMusicAPITests.swift        #   常量定义测试 (1)
└── Example/                                   # iOS SwiftUI 示例应用
    ├── Package.swift
    ├── BUILD.bazel
    └── Sources/
        ├── NCMDemoApp.swift                   # App 入口
        ├── ContentView.swift                  # TabView 主界面
        ├── DemoViewModel.swift                # 核心 ViewModel
        ├── SearchView.swift                   # 搜索 + 歌词
        ├── PlaylistView.swift                 # 歌单浏览
        ├── ToplistView.swift                  # 排行榜
        └── SettingsView.swift                 # 连接设置
```

## 架构设计

```
┌─────────────────────────────────────────────┐
│                  NCMClient                   │
│          (面向用户的统一入口)                   │
│                                              │
│  ┌─ serverUrl? ──→ 后端代理模式 (HTTP POST)   │
│  └─ nil ─────────→ 直连加密模式 ↓             │
├──────────────────────────────────────────────┤
│              RequestClient                    │
│     (URL 构建 · 加密分发 · HTTP 执行)          │
├──────────┬───────────┬───────────────────────┤
│CryptoEngine│SessionManager│   NCMConstants    │
│ AES-CBC    │ Cookie 管理  │   密钥 · 域名     │
│ AES-ECB    │ 设备元数据   │   公钥 · 常量     │
│ RSA        │ UA 选择      │                   │
│ MD5        │ EAPI Header  │                   │
└──────────┴───────────┴───────────────────────┘
```

## 系统框架依赖

| 框架 | 用途 | 使用模块 |
|------|------|----------|
| Foundation | 网络请求、JSON、URL | 全部模块 |
| CommonCrypto | AES-CBC/ECB、MD5 | CryptoEngine |
| Security | RSA 加密 (SecKey) | CryptoEngine |

## 第三方依赖（仅测试）

| 依赖 | 版本 | 用途 | 传递依赖 |
|------|------|------|----------|
| [SwiftCheck](https://github.com/typelift/SwiftCheck) | 0.12.0 | 属性测试框架 | FileCheck → Chalk, swift-argument-parser |

> SDK 本身零外部依赖，SwiftCheck 仅用于测试目标。
> Bazel 构建时通过 rules_swift_package_manager 自动从 Package.resolved 解析下载。

## 构建

### Swift Package Manager

```bash
swift build                    # 构建 SDK
swift test                     # 运行测试
cd Example && swift run        # 运行示例应用
```

### Bazel (bzlmod 模式，推荐)

```bash
swift package resolve          # 确保 Package.resolved 存在
bazel mod tidy                 # 更新 use_repo 声明
bazel build //:NeteaseCloudMusicAPI
bazel test //:NeteaseCloudMusicAPITests
bazel build //Example:NCMDemo
```

### Bazel (WORKSPACE 传统模式)

```bash
bazel build //:NeteaseCloudMusicAPI
bazel test //:NeteaseCloudMusicAPITests
```

## Bazel 构建目标

| 目标 | 类型 | 说明 |
|------|------|------|
| `//:NeteaseCloudMusicAPI` | swift_library | SDK 主库 |
| `//:NeteaseCloudMusicAPITests` | swift_test | 单元测试 + 属性测试 |
| `//Example:NCMDemoLib` | swift_library | 示例应用源码库 |
| `//Example:NCMDemo` | ios_application | iOS 示例应用 (iPhone + iPad) |

## 使用方法

```swift
import NeteaseCloudMusicAPI

// 创建客户端
let client = NCMClient()

// 搜索歌曲
let result = try await client.cloudsearch(keywords: "周杰伦")

// 获取歌词
let lyric = try await client.lyric(id: 347230)

// 后端代理模式
client.serverUrl = "http://localhost:3000"
```

## 许可证

MIT License
