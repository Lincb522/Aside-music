<p align="center">
  <img src="docs/assets/logo.png" width="128" height="128" alt="Aside Music Logo" style="border-radius: 24px;">
</p>

<h1 align="center">Aside Music</h1>

<p align="center">
  一款精致的第三方网易云音乐 iOS 客户端
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17%2B-black?style=flat-square&logo=apple" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.9-black?style=flat-square&logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-black?style=flat-square" alt="SwiftUI">
  <img src="https://img.shields.io/badge/FFmpeg-8.0-black?style=flat-square" alt="FFmpeg">
  <img src="https://img.shields.io/badge/License-MIT-black?style=flat-square" alt="License">
</p>

---

纯 SwiftUI 构建，自研 FFmpeg 播放引擎，支持 Hi-Res 无损播放、无缝切歌、10 段均衡器。全套自绘 Aura 图标系统，零 SF Symbols 依赖。

## 特性

- 基于自研 [FFmpegSwiftSDK](https://github.com/Lincb522/FFmpegSwiftSDK) 播放引擎，支持 192kHz/24bit 母带音质
- 无缝切歌 (Gapless Playback)，预加载下一首 pipeline
- 10 段 EQ 均衡器，基于 FFmpeg SwrContext 实时调节
- 自研 Aura 图标系统，64+ 自绘浮动线条图标
- 自研 [LiquidGlassEffect](https://github.com/Lincb522/LiquidGlassEffect) 液态玻璃视觉效果
- 弥散背景、弹性动画、深色/浅色自适应
- MV 播放器，横屏全屏，内嵌评论
- 播客电台，收音机模式沉浸播放
- 沉浸式歌词，横屏 VJ 风格逐词快闪
- 私人 FM、每日推荐、歌单广场、排行榜
- 云盘歌曲管理，浏览/播放/删除
- 评论系统，点赞/回复/排序
- 歌曲下载与离线播放
- 解灰功能，自动匹配第三方音源
- 听歌打卡，同步播放记录到网易云

## 安装

需要 macOS 14+、Xcode 15+、iOS 17+。

需配合 [NeteaseCloudMusicApi Enhanced](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced) 后端服务。

```bash
git clone https://github.com/Lincb522/Aside-music.git
cd Aside-music

# 编辑 .env 设置 API_BASE_URL
# Xcode 打开或脚本构建
open AsideMusic.xcodeproj
./build_ipa.sh
```

## 技术栈

| 类别 | 技术 |
|------|------|
| UI | SwiftUI + MVVM |
| 音频引擎 | [FFmpegSwiftSDK](https://github.com/Lincb522/FFmpegSwiftSDK) (FFmpeg 8.0) |
| 网易云 API | [NeteaseCloudMusicAPI-Swift](https://github.com/Lincb522/NeteaseCloudMusicAPI-Swift) |
| 视觉效果 | [LiquidGlassEffect](https://github.com/Lincb522/LiquidGlassEffect) |
| 数据持久化 | SQLite |
| 依赖管理 | Swift Package Manager |

## 致谢

- [NeteaseCloudMusicApiEnhanced](https://github.com/NeteaseCloudMusicApiEnhanced) — API 服务
- [Binaryify](https://github.com/Binaryify) — 原版 NeteaseCloudMusicApi
- [YesPlayMusic](https://github.com/qier222/YesPlayMusic)、[listen1](https://github.com/listen1/listen1_chrome_extension) — 参考项目

## 许可证

[MIT License](LICENSE)

---

> 仅供学习交流，请勿商用。音乐版权归网易云音乐及相关权利人所有。
