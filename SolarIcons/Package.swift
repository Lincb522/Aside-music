// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SolarIcons",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SolarIcons", targets: ["SolarIcons"]),
    ],
    targets: [
        .target(name: "SolarIcons", resources: [.process("icons.xcassets")]),
    ]
)
