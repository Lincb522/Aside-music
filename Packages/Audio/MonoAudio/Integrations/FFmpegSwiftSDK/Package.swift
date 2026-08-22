// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MonoAudioFFmpegSwiftSDK",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "MonoAudioFFmpegSwiftSDK", targets: ["MonoAudioFFmpegSwiftSDK"]),
    ],
    dependencies: [
        .package(path: "../.."),
        .package(path: "../../../ffmpeg-swift"),
    ],
    targets: [
        .target(
            name: "MonoAudioFFmpegSwiftSDK",
            dependencies: [
                .product(name: "MonoAudioCore", package: "MonoAudio"),
                .product(name: "MonoAudioStreaming", package: "MonoAudio"),
                .product(name: "FFmpegSwiftSDK", package: "ffmpeg-swift"),
            ]
        ),
    ]
)
