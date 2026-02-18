<h1 align="center">
  🎵 Aside Music
</h1>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2017+-blue?logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange?logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/SwiftUI-Framework-purple?logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/FFmpeg-Powered-green?logo=ffmpeg&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-yellow?logo=opensourceinitiative&logoColor=white" />
</p>

<p align="center">
  基于 SwiftUI + FFmpeg 构建的 iOS 音乐播放器
</p>

---

## 📦 依赖

| 库 | 地址 |
|---|---|
| NeteaseCloudMusicAPI-Swift | https://github.com/Lincb522/NeteaseCloudMusicAPI-Swift |
| FFmpegSwiftSDK | https://github.com/Lincb522/FFmpegSwiftSDK |
| LiquidGlassEffect | https://github.com/Lincb522/LiquidGlassEffect |
| QQMusicKit | https://github.com/Lincb522/MusicKit |

### 🖥️ 后端服务

| 服务 | 地址 |
|---|---|
| NeteaseCloudMusicApi Enhanced | https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced |
| QQMusicApi | https://github.com/L-1124/QQMusicApi |
| KuGouMusicApi | https://github.com/MakcRe/KuGouMusicApi |

---

## 🚀 源码使用

### 1️⃣ 克隆项目

```bash
git clone https://github.com/Lincb522/Aside-music.git
cd Aside-music
```

### 2️⃣ 配置服务器地址

复制示例配置文件并填入你的服务器地址：

```bash
cp Secrets.xcconfig.example Secrets.xcconfig
```

编辑 `Secrets.xcconfig`：

```
API_BASE_URL = https:/$()/your-ncm-server.com
QQ_MUSIC_BASE_URL = http:/$()/your-qq-server:8000
UNBLOCK_SERVER_URL = http:/$()/your-unblock-server:4000
```

### 3️⃣ 关联 xcconfig

Xcode → 点击项目 → Info → Configurations → 将 Debug 和 Release 都选择 `Secrets.xcconfig`。

### 4️⃣ 编译运行

Xcode 打开 `AsideMusic.xcodeproj`，SPM 会自动拉取远程依赖，编译运行即可。

---

## 🔓 免签调试

项目已配置免签（`CODE_SIGNING_ALLOWED = NO`），无需 Apple 开发者账号。

连接 iPhone，Xcode 选择设备，`Cmd + R` 直接运行。设备需开启开发者模式。

## 📱 免签打包 IPA

```bash
chmod +x build_ipa.sh
./build_ipa.sh
```

脚本以 `CODE_SIGNING_ALLOWED=NO` 编译 Release 版本并打包生成 `AsideMusic.ipa`，可通过 TrollStore 安装。

---

## 🙏 致谢

感谢以下开源项目的作者和贡献者：

| 项目 | 说明 |
|---|---|
| [NeteaseCloudMusicApi Enhanced](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced) | 网易云音乐 API |
| [QQMusicApi](https://github.com/L-1124/QQMusicApi) | QQ 音乐 API |
| [KuGouMusicApi](https://github.com/MakcRe/KuGouMusicApi) | 酷狗音乐 API |
| [FFmpeg](https://ffmpeg.org/) | 音视频解码引擎 |

---

## 📄 开源协议

本项目基于 [MIT License](LICENSE) 开源。

---

## ⚠️ 免责声明

> - 本项目仅供 **学习和研究** 使用，不得用于商业用途。
> - 本项目不提供任何音乐资源，所有音乐内容均来自第三方 API，版权归原作者所有。
> - 使用本项目产生的一切法律责任由使用者自行承担，与项目作者无关。
> - 如有侵权，请联系作者删除。
