// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NeteaseCloudMusicAPI",
    platforms: [
        .iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v8)
    ],
    products: [
        .library(name: "NeteaseCloudMusicAPI", targets: ["NeteaseCloudMusicAPI"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NeteaseCloudMusicAPI",
            path: "Sources/NeteaseCloudMusicAPI"
        ),
    ]
)
