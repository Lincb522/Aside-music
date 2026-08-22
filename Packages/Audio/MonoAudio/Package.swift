// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MonoAudio",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "MonoAudioCore", targets: ["MonoAudioCore"]),
        .library(name: "MonoAudioAgent", targets: ["MonoAudioAgent"]),
        .library(name: "MonoAudioStreaming", targets: ["MonoAudioStreaming"]),
        .library(name: "MonoAudioFFmpeg", targets: ["MonoAudioFFmpeg"]),
        .executable(name: "mono-audio", targets: ["MonoAudioCLI"]),
    ],
    targets: [
        .target(name: "MonoAudioCore"),
        .target(
            name: "MonoAudioAgent",
            dependencies: ["MonoAudioCore"]
        ),
        .target(name: "MonoAudioStreaming"),
        .target(
            name: "MonoAudioFFmpeg",
            dependencies: ["MonoAudioCore", "MonoAudioStreaming"]
        ),
        .executableTarget(
            name: "MonoAudioCLI",
            dependencies: ["MonoAudioCore", "MonoAudioStreaming", "MonoAudioFFmpeg"]
        ),
        .testTarget(
            name: "MonoAudioCoreTests",
            dependencies: ["MonoAudioCore"]
        ),
        .testTarget(
            name: "MonoAudioAgentTests",
            dependencies: ["MonoAudioAgent", "MonoAudioCore"]
        ),
        .testTarget(
            name: "MonoAudioStreamingTests",
            dependencies: ["MonoAudioStreaming"]
        ),
        .testTarget(
            name: "MonoAudioFFmpegTests",
            dependencies: ["MonoAudioFFmpeg", "MonoAudioCore", "MonoAudioStreaming"]
        ),
    ]
)
