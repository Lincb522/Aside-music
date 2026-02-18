# Aside Music

iOS 音乐播放器，基于 SwiftUI + FFmpeg 构建。

## 依赖

| 库 | 地址 |
|---|---|
| NeteaseCloudMusicAPI-Swift | https://github.com/Lincb522/NeteaseCloudMusicAPI-Swift |
| FFmpegSwiftSDK | https://github.com/Lincb522/FFmpegSwiftSDK |
| LiquidGlassEffect | https://github.com/Lincb522/LiquidGlassEffect |
| QQMusicKit | https://github.com/Lincb522/MusicKit |

## 源码使用

### 1. 克隆项目

```bash
git clone https://github.com/Lincb522/Aside-music.git
cd Aside-music
```

### 2. 配置服务器地址

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

### 3. 关联 xcconfig

Xcode → 点击项目 → Info → Configurations → 将 Debug 和 Release 都选择 `Secrets.xcconfig`。

### 4. 编译运行

Xcode 打开 `AsideMusic.xcodeproj`，SPM 会自动拉取远程依赖，编译运行即可。

## 免签调试

项目已配置免签（`CODE_SIGNING_ALLOWED = NO`），无需 Apple 开发者账号。

连接 iPhone，Xcode 选择设备，`Cmd + R` 直接运行。设备需开启开发者模式。

## 免签打包 IPA

```bash
chmod +x build_ipa.sh
./build_ipa.sh
```

脚本以 `CODE_SIGNING_ALLOWED=NO` 编译 Release 版本并打包生成 `AsideMusic.ipa`，可通过 TrollStore 安装。
