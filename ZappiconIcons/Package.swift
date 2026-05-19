// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ZappiconIcons",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ZappiconIcons", targets: ["ZappiconIcons"]),
    ],
    targets: [
        .target(name: "ZappiconIcons", resources: [.process("icons.xcassets")]),
    ]
)
