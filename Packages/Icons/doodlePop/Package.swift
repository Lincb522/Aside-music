// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "doodlePop",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "doodlePop", targets: ["doodlePop"]),
    ],
    targets: [
        .target(name: "doodlePop", resources: [.process("icons.xcassets")]),
    ]
)
