// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "IconExportIcons",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "IconExportIcons", targets: ["IconExportIcons"]),
    ],
    targets: [
        .target(name: "IconExportIcons", resources: [.process("icons.xcassets")]),
    ]
)
