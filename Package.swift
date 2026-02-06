// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AsideMusic",
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
        // SwiftAudioEx - 音频播放
        .package(url: "https://github.com/doublesymmetry/SwiftAudioEx.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "AsideMusic",
            dependencies: [
                "LiquidGlassEffect",
                .product(name: "SwiftAudioEx", package: "SwiftAudioEx"),
            ]),
        .testTarget(
            name: "AsideMusicTests",
            dependencies: ["AsideMusic"]),
    ]
)
