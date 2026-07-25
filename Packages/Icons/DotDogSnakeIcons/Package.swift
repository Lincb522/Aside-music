// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DotDogSnakeIcons",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "DotDogSnakeIcons", targets: ["DotDogSnakeIcons"]),
    ],
    targets: [
        .target(
            name: "DotDogSnakeIcons",
            resources: [.process("icons.xcassets")]
        ),
    ]
)
