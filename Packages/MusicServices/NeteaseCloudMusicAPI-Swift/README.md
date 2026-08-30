<p align="center">
  <img src="https://raw.githubusercontent.com/Lincb522/NeteaseCloudMusicAPI-Swift/main/docs/logo.svg" width="120" height="120" />
</p>

<h1 align="center">NeteaseCloudMusicAPI-Swift</h1>

<p align="center">
  <strong>基于 <a href="https://github.com/Binaryify/NeteaseCloudMusicApi">NeteaseCloudMusicApi</a> 封装的原生 Swift SDK</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-5.9+-F05138?style=flat-square&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/平台-iOS%20|%20macOS%20|%20tvOS%20|%20watchOS-blue?style=flat-square" />
  <img src="https://img.shields.io/badge/API-439+-green?style=flat-square" />
  <img src="https://img.shields.io/badge/依赖-零依赖-orange?style=flat-square" />
</p>

---

## 特性

- 🎵 **439 个上游后端路由** — 对齐 NeteaseCloudMusicApiEnhanced 4.40.1，并接入 Mono 本地增强接口
- 🔐 **四种加密模式** — WeAPI / EAPI / LinuxAPI / 明文
- 🍎 **Apple 全系平台** — iOS 15+ / macOS 12+ / tvOS 15+ / watchOS 8+
- 📦 **零外部依赖** — 仅 Foundation + CommonCrypto
- 🎯 **Swift 原生** — async/await、强类型枚举、完整中文注释

---

## 安装

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/Lincb522/NeteaseCloudMusicAPI-Swift.git", from: "1.0.0")
]
```

或 Xcode：`File` → `Add Package Dependencies` → 输入仓库地址。

---

## 文档

接口用法、参数说明、架构设计等详见在线文档：

**👉 [https://lincb522.github.io/NeteaseCloudMusicAPI-Swift/](https://lincb522.github.io/NeteaseCloudMusicAPI-Swift/)**

---

## 示例应用

`Example/` 包含完整的 iOS SwiftUI 示例应用，14 个测试页面覆盖 SDK 全部模块。

```bash
cd Example && open NCMDemo.xcodeproj
```

---

## 致谢

- [Binaryify/NeteaseCloudMusicApi](https://github.com/Binaryify/NeteaseCloudMusicApi) — 核心参考
- [NeteaseCloudMusicApiEnhanced/api-enhanced](https://github.com/neteasecloudmusicapienhanced/api-enhanced) — 增强版社区维护- [darknessomi/musicbox](https://github.com/darknessomi/musicbox) — 加密算法参考

## 许可证

MIT License
