// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NCMDemo",
    platforms: [.iOS(.v17), .macOS(.v14)],
    dependencies: [
        .package(name: "NeteaseCloudMusicAPI", path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "NCMDemo",
            dependencies: ["NeteaseCloudMusicAPI"],
            path: "Sources"
        ),
    ]
)
