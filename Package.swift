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
        .package(url: "https://github.com/Lincb522/LiquidGlassEffect.git", from: "2.1.0")
    ],
    targets: [
        .target(
            name: "AsideMusic",
            dependencies: ["LiquidGlassEffect"]),
        .testTarget(
            name: "AsideMusicTests",
            dependencies: ["AsideMusic"]),
    ]
)
