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
        // LiquidGlassEffect - iOS 26 风格液态玻璃效果库
        .package(url: "https://github.com/Lincb522/LiquidGlassEffect.git", from: "2.1.0"),
        // NeteaseCloudMusicAPI - 网易云音乐 API 封装库（362+ 接口）
        .package(url: "https://github.com/Lincb522/NeteaseCloudMusicAPI-Swift.git", from: "1.0.0"),
        // FFmpegSwiftSDK - 基于 FFmpeg 8.0 的流媒体播放引擎
        .package(url: "https://github.com/Lincb522/FFmpegSwiftSDK.git", from: "0.12.2"),
        // QQMusicKit - QQ 音乐 API 封装库（本地包）
        .package(path: "../QQMusicKit/QQMusicKit"),
    ],
    targets: [
        .target(
            name: "AsideMusic",
            dependencies: [
                "LiquidGlassEffect",
                .product(name: "NeteaseCloudMusicAPI", package: "NeteaseCloudMusicAPI-Swift"),
                "FFmpegSwiftSDK",
                "QQMusicKit",
            ],
            resources: [
                .process("Resources/SanJiPoMoTi-2.ttf"),
                .process("Resources/HYPixel11pxU-2.ttf"),
                .process("Resources/字魂半天云魅黑手书(商用需授权).ttf"),
                .process("Resources/eq_presets.json"),
                .process("Resources/en.lproj"),
                .process("Resources/zh-Hans.lproj"),
            ]
        ),
    ]
)
