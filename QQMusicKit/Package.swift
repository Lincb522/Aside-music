// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QQMusicKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        .library(name: "QQMusicKit", targets: ["QQMusicKit"]),
    ],
    targets: [
        .target(name: "QQMusicKit", path: "Sources"),
    ]
)
