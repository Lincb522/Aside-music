// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PulseBloomIcons",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "PulseBloomIcons", targets: ["PulseBloomIcons"]),
    ],
    targets: [
        .target(name: "PulseBloomIcons", resources: [.process("icons.xcassets")]),
    ]
)
