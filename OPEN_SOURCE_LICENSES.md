# Mono 开源软件许可

更新日期：2026 年 8 月 18 日

Mono 使用了下列开源软件。各项目仍由原作者及贡献者持有权利，并分别适用其原始许可证。本文件不改变任何第三方许可证，也不代表 Mono 本体代码、名称、图标或品牌资产采用相同许可。

## App 与音频组件

| 项目 | 用途 | 许可证 |
|---|---|---|
| [FFmpeg](https://ffmpeg.org/) | 解封装、解码、重采样与音频滤镜 | LGPL-2.1-or-later；当前构建未启用 GPL 与 nonfree 组件 |
| FFmpegSwiftSDK | FFmpeg 的 Swift 封装与播放接口 | MIT |
| [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | ZIP 字体包解压与导入 | MIT |
| [Lucide](https://github.com/lucide-icons/lucide) | 部分界面图标 | ISC；其中 Feather 衍生部分适用 MIT |
| [OPRA](https://github.com/opra-project/OPRA) | 耳机与输出设备的公开参数均衡配置数据库 | 数据库内容 CC BY-SA-4.0；工具源码 MIT |
| [shuke-lab-flux](https://github.com/KTBOY/shuke-lab-flux) | 流光 TabBar 的域扭曲 FBM 材质算法参考 | MIT（仓库 README 声明） |
| [SwiftUI-Animations](https://github.com/Shubham0812/SwiftUI-Animations) | 中性触摸水波节奏与液态进度波面实现参考；当前适配基于 `f4e6b3ca6bfc83eb673bf5d8c77032270b93bbb5` | Apache-2.0 |
| [open-swiftui-animations](https://github.com/amosgyamfi/open-swiftui-animations) | KeyframeAnimator、PhaseAnimator 与短时状态微交互节奏参考；当前调研基于 `db0a59cc4b091644f4569339d7cb076eba91b9a0` | Unlicense |
| [SwiftPixelGrid](https://github.com/afetmin/SwiftPixelGrid) | 点阵播放器的 3×3 Canvas 动画渲染；当前适配基于 `v0.1.0` / `1496aacdf2ffb92ddd9d51788c24a33f35ef0b42` | MIT |
| [Rive Runtime](https://github.com/rive-app/rive-ios) | 矢量状态机动画渲染；当前接入版本 `6.23.1` | MIT |

## 音乐服务与后端参考

| 项目 | 许可证 |
|---|---|
| [NeteaseCloudMusicApi Enhanced](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced) | MIT |
| [QQMusicApi](https://github.com/L-1124/QQMusicApi) | GPL-3.0 |
| [KuGouMusicApi](https://github.com/MakcRe/KuGouMusicApi) | MIT |

## 许可证原文

- FFmpeg LGPL-2.1-or-later：[ffmpeg.org/legal.html](https://ffmpeg.org/legal.html)
- FFmpegSwiftSDK MIT：[`Packages/Audio/ffmpeg-swift/LICENSE`](Packages/Audio/ffmpeg-swift/LICENSE)
- ZIPFoundation MIT：[LICENSE](https://github.com/weichsel/ZIPFoundation/blob/development/LICENSE)
- Lucide ISC：[LICENSE](https://github.com/lucide-icons/lucide/blob/main/LICENSE)
- OPRA CC BY-SA-4.0 / MIT：[LICENSE](https://github.com/opra-project/OPRA/blob/main/LICENSE)
- shuke-lab-flux MIT：[README](https://github.com/KTBOY/shuke-lab-flux/blob/main/README.md)
- SwiftUI-Animations Apache-2.0：[`ThirdPartyLicenses/SwiftUI-Animations-APACHE-2.0.txt`](ThirdPartyLicenses/SwiftUI-Animations-APACHE-2.0.txt)
- open-swiftui-animations Unlicense：[`ThirdPartyLicenses/open-swiftui-animations-UNLICENSE.txt`](ThirdPartyLicenses/open-swiftui-animations-UNLICENSE.txt)
- SwiftPixelGrid MIT：[`Packages/UI/SwiftPixelGrid/LICENSE`](Packages/UI/SwiftPixelGrid/LICENSE)
- Rive Runtime MIT：[`ThirdPartyLicenses/RiveRuntime-MIT.txt`](ThirdPartyLicenses/RiveRuntime-MIT.txt)
- NeteaseCloudMusicApi Enhanced MIT：[LICENSE](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced/blob/main/LICENSE)
- QQMusicApi GPL-3.0：[LICENSE](https://github.com/L-1124/QQMusicApi/blob/main/LICENSE)
- KuGouMusicApi MIT：[LICENSE](https://github.com/MakcRe/KuGouMusicApi/blob/main/LICENSE)
发行、修改或重新分发相关组件时，应同时满足对应许可证中的版权声明、源代码提供、修改说明及其他义务。若仓库内的组件副本附带独立许可证文件，以该文件为准。
