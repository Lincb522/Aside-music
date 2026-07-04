// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BlobIcons",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BlobIcons", targets: ["BlobIcons"]),
    ],
    targets: [
        .target(name: "BlobIcons", resources: [.process("icons.xcassets")]),
    ]
)
