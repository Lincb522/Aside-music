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
    dependencies: [
        .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0"),
    ],
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
        .testTarget(
            name: "NeteaseCloudMusicAPITests",
            dependencies: ["NeteaseCloudMusicAPI", "SwiftCheck"],
            path: "Tests/NeteaseCloudMusicAPITests"
        ),
    ]
)
