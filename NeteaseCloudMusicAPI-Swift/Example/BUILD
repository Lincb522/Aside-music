# NCMDemo
# NeteaseCloudMusicAPI-Swift iOS 示例应用
# 演示 SDK 核心功能的 SwiftUI 应用

## 概述

NCMDemo 是 NeteaseCloudMusicAPI-Swift SDK 的 iOS 示例应用，
使用 SwiftUI 构建，演示搜索、歌单、排行榜、歌词等核心功能。

## 版本

v1.0.0

## 特性

- 📱 **iOS 原生** — SwiftUI + NavigationStack，支持 iPhone 和 iPad
- 🔍 **搜索** — iOS 原生搜索栏，歌曲搜索 + 歌词展示
- 📋 **歌单** — 热门歌单浏览，NavigationLink 进入歌曲列表
- 📊 **排行榜** — LazyVGrid 网格展示所有排行榜
- ⚙️ **设置** — Form 风格配置页，支持直连/代理模式切换、Cookie 设置
- 🔄 **双模式** — 可在直连网易云和后端代理之间切换

## 平台要求

| 平台 | 最低版本 |
|------|----------|
| iOS | 16.0 |
| macOS | 13.0 (Mac Catalyst) |

## 应用结构

```
Example/
├── Package.swift              # SPM 配置
├── BUILD.bazel                # Bazel 构建规则
└── Sources/
    ├── NCMDemoApp.swift       # @main App 入口
    ├── ContentView.swift      # TabView 底部导航
    │                          #   ├── 搜索 (NavigationStack)
    │                          #   ├── 歌单 (NavigationStack)
    │                          #   ├── 排行榜 (NavigationStack)
    │                          #   └── 设置 (NavigationStack)
    ├── DemoViewModel.swift    # @MainActor ViewModel
    │                          #   ├── NCMClient 管理
    │                          #   ├── 搜索 API 调用
    │                          #   ├── 歌单 API 调用
    │                          #   ├── 排行榜 API 调用
    │                          #   └── 连接测试
    ├── SearchView.swift       # 搜索页 + LyricView 歌词详情
    ├── PlaylistView.swift     # 歌单页 + PlaylistDetailView 详情
    ├── ToplistView.swift      # 排行榜网格页
    └── SettingsView.swift     # Form 设置页
```

## 构建

### Swift Package Manager

```bash
cd Example
swift run
```

### Bazel

```bash
bazel build //Example:NCMDemo
```

### 安装到模拟器

```bash
bazel run //Example:NCMDemo
```

## Bazel 构建目标

| 目标 | 类型 | 说明 |
|------|------|------|
| `//Example:NCMDemoLib` | swift_library | 示例应用源码库 |
| `//Example:NCMDemo` | ios_application | iOS 应用 (iPhone + iPad, iOS 16.0+) |

## 依赖

| 依赖 | 来源 | 说明 |
|------|------|------|
| NeteaseCloudMusicAPI | `//:NeteaseCloudMusicAPI` | SDK 主库 |
| SwiftUI | 系统框架 | UI 框架 |

## 截图

（待补充）

## 许可证

MIT License
