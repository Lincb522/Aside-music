// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NeteaseCloudMusicAPI",
    platforms: [
        .iOS(.v15), .tvOS(.v15), .watchOS(.v8), .macOS(.v12)
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
        .testTarget(
            name: "NeteaseCloudMusicAPIContractTests",
            dependencies: ["NeteaseCloudMusicAPI"],
            path: "ContractTests/NeteaseCloudMusicAPIContractTests"
        ),
    ]
)
