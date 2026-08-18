// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftPixelGrid",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "SwiftPixelGrid", targets: ["SwiftPixelGrid"]),
    ],
    targets: [
        .target(name: "SwiftPixelGrid"),
    ]
)
