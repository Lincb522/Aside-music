// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PawPrintIcons",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "PawPrintIcons", targets: ["PawPrintIcons"]),
    ],
    targets: [
        .target(name: "PawPrintIcons", resources: [.process("icons.xcassets")]),
    ]
)
