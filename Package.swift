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
    ],
    targets: [
        .target(
            name: "AsideMusic",
            dependencies: [
                "LiquidGlassEffect",
                .product(name: "NeteaseCloudMusicAPI", package: "NeteaseCloudMusicAPI-Swift"),
            ]
        ),
    ]
)
