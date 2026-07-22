// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MinimalWhiteIcons",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "MinimalWhiteIcons", targets: ["MinimalWhiteIcons"]),
    ],
    targets: [
        .target(name: "MinimalWhiteIcons", resources: [.process("icons.xcassets")]),
    ]
)
