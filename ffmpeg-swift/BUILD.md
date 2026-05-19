# 🔨 从源码编译 FFmpeg for iOS

本文档介绍如何交叉编译 FFmpeg 8.0 并生成 `FFmpegLibs.xcframework`。

---

## 📋 前置条件

- macOS + Xcode 15+ 及 Command Line Tools
- FFmpeg 8.0 源码

---

## 📥 下载源码

```bash
mkdir -p build-ffmpeg && cd build-ffmpeg
curl -L https://ffmpeg.org/releases/ffmpeg-8.0.tar.xz | tar xJ
cd ..
```

源码位于 `build-ffmpeg/ffmpeg-8.0/`。

---

## ⚡ 一键编译

```bash
bash scripts/rebuild-all.sh
```

这个脚本会自动完成以下步骤：

| 步骤 | 说明 |
|:---:|:---|
| 1️⃣ | 交叉编译 3 个目标架构 |
| 2️⃣ | 合并模拟器 fat binary（`lipo`） |
| 3️⃣ | 合并 5 个静态库为 `libFFmpegAll.a`（`libtool`） |
| 4️⃣ | 创建 `FFmpegLibs.xcframework`（`xcodebuild`） |
| 5️⃣ | 清理平台特定头文件 |
| 6️⃣ | 重新生成示例工程 |

---

## 🎯 编译目标

| 平台 | 架构 | 用途 |
|:---:|:---:|:---|
| `iphoneos` | arm64 | 真机 |
| `iphonesimulator` | arm64 | Apple Silicon Mac 模拟器 |
| `iphonesimulator` | x86_64 | Intel Mac 模拟器 |

---

## 🎧 启用的音频解码器（约 30 个）


| 分类 | 解码器 |
|:---|:---|
| 有损压缩 | AAC、MP3、Vorbis、Opus、WMA v1/v2/Pro、AMR-NB/WB、Cook、MPC、ATRAC 1/3/3+ |
| 无损压缩 | FLAC、ALAC、WavPack、APE、TAK、TTA、WMA Lossless、DSD |
| PCM 原始 | S16/S24/S32/F32/F64（LE/BE）、μ-law、A-law、ADPCM |
| 环绕声 | AC3、EAC3、DTS |

---

## 🎬 视频解码器

- H.264
- HEVC (H.265)

---

## 🌐 支持的协议 & 封装格式

**协议：** file / http / https / tcp / udp / hls / rtmp

**封装格式：** MOV/MP4、MPEG-TS、FLV、HLS、RTSP、MP3、AAC、FLAC、OGG、WAV、APE、TAK、WavPack、TTA、DSF、DFF、ASF、Matroska/WebM、AIFF、CAF、AMR、AC3、EAC3、DTS 等

---

## ⚙️ 编译参数

```
--enable-static --disable-shared    # 仅静态库
--disable-programs --disable-doc    # 不编译命令行工具和文档
--enable-small                      # 体积优化
--enable-pic                        # 位置无关代码（框架嵌入必需）
--disable-asm                       # 禁用汇编（交叉编译兼容性）
最低部署目标：iOS 16.0
```

---

## 📁 输出结构

```
Frameworks/FFmpegLibs.xcframework/
├── Info.plist
├── ios-arm64/                          ← 真机
│   ├── Headers/
│   │   ├── libavcodec/
│   │   ├── libavfilter/
│   │   ├── libavformat/
│   │   ├── libavutil/
│   │   └── libswresample/
│   └── libFFmpegAll.a
└── ios-arm64_x86_64-simulator/         ← 模拟器（fat binary）
    ├── Headers/
    │   └── （同上）
    └── libFFmpegAll.a
```

---

## 📜 脚本说明

| 脚本 | 用途 |
|:---|:---|
| `scripts/rebuild-all.sh` | 全量编译：所有架构 + xcframework |
| `scripts/build-ffmpeg-ios.sh` | 编译单个架构 |
| `scripts/rebuild-sim-and-xcframework.sh` | 仅重编译模拟器 + xcframework |
| `scripts/build-ipa.sh` | 打包未签名 IPA（侧载用） |

---

## 🔧 常见问题

### "No such module 'CFFmpeg'"

清理 Build Folder（`Cmd+Shift+K`）后重新编译。SPM 需要先解析 xcframework。

### 头文件报错（d3d11va.h、dxva2.h 等）

运行 `scripts/rebuild-all.sh`，脚本会自动清理 iOS/macOS 上不存在的平台特定头文件。

### 模拟器链接错误

确认 xcframework 中的模拟器 binary 包含 arm64 和 x86_64 两个架构：

```bash
lipo -info Frameworks/FFmpegLibs.xcframework/ios-arm64_x86_64-simulator/libFFmpegAll.a
```
