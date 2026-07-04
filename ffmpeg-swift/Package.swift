// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FFmpegSwiftSDK",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "FFmpegSwiftSDK",
            targets: ["FFmpegSwiftSDK"]
        ),
    ],
    dependencies: [],
    targets: [
        // CFFmpeg: C bridging target with bundled headers
        .target(
            name: "CFFmpeg",
            dependencies: [
                .target(name: "FFmpegLibs", condition: .when(platforms: [.iOS])),
            ],
            path: "Sources/CFFmpeg",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ],
            linkerSettings: [
                .linkedFramework("Security", .when(platforms: [.iOS])),
            ]
        ),

        // Single merged XCFramework for iOS (device + simulator)
        // 改为本地直接引用，彻底解决 DerivedData 无法下载/定位远程 artifacts 导致的 XCFramework 缺失错误
        .binaryTarget(
            name: "FFmpegLibs",
            path: "Frameworks/FFmpegLibs.xcframework"
        ),

        .target(
            name: "FFmpegSwiftSDK",
            dependencies: [
                "CFFmpeg",
                .target(name: "FFmpegLibs", condition: .when(platforms: [.iOS])),
            ]
        ),
    ]
)
