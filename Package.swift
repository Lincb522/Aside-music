// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AsideMusic",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AsideMusic",
            targets: ["AsideMusic"]),
    ],
    dependencies: [
        // LiquidGlass - iOS 26 风格液态玻璃效果库
        .package(path: "LiquidGlass-main"),
        // NeteaseCloudMusicAPI - 网易云音乐 API 封装库（362+ 接口）
        .package(path: "NeteaseCloudMusicAPI-Swift"),
        // FFmpegSwiftSDK - 基于 FFmpeg 8.0 的流媒体播放引擎
        .package(path: "ffmpeg-swift"),
        // QQMusicKit - QQ 音乐 API 封装库（本地包）
        .package(path: "QQMusicKit"),
    ],
    targets: [
        .target(
            name: "AsideMusic",
            dependencies: [
                "LiquidGlass",
                .product(name: "NeteaseCloudMusicAPI", package: "NeteaseCloudMusicAPI-Swift"),
                "FFmpegSwiftSDK",
                "QQMusicKit",
            ],
            resources: [
                .process("Resources/SanJiPoMoTi.ttf"),
                .process("Resources/HYPixel11pxU.ttf"),
                .process("Resources/ZihunBantianyun.ttf"),
                .process("Resources/eq_presets.json"),
                .process("Resources/en.lproj"),
                .process("Resources/zh-Hans.lproj"),
            ]
        ),
    ]
)
