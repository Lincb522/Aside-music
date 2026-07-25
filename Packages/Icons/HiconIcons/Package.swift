// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "HiconIcons",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "HiconIcons",
            targets: ["HiconIcons"]),
    ],
    targets: [
        .target(
            name: "HiconIcons",
            resources: [
                .process("icons.xcassets")
            ]
        ),
    ]
)
