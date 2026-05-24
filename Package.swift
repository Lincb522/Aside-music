// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Monologue",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "Monologue",
            targets: ["Monologue"]),
    ],
    dependencies: [
        // NeteaseCloudMusicAPI - ncm API 封装库（对齐后端 4.33.0 / 396+ 路由）
        .package(path: "NeteaseCloudMusicAPI-Swift"),
        // FFmpegSwiftSDK - 基于 FFmpeg 8.0 的流媒体播放引擎
        .package(path: "ffmpeg-swift"),
        // QQMusicKit - qcm API 封装库（本地包）
        .package(path: "QQMusicKit"),
        // HiconIcons - Hicon 图标库（本地包，从 Figma 导出）
        .package(path: "HiconIcons"),
        // ZappiconIcons - Zappicon (H173) 图标库（本地包，Light 风格）
        .package(path: "ZappiconIcons"),
        // LucideIcons - Lucide 图标库（本地包）
        .package(path: "LucideIcons"),
        // SolarIcons - Solar 图标库（本地包）
        .package(path: "SolarIcons"),
        // IconExportIcons - 新导入的 PNG 图标包
        .package(path: "IconExportIcons"),
        // BlobIcons - Blob 风格 PNG 图标包
        .package(path: "BlobIcons"),
        // doodlePop - 配套 PNG 图标包
        .package(path: "doodlePop"),
        // PawPrintIcons - 猫狗扁平 PNG 图标包
        .package(path: "PawPrintIcons"),
        // DotDogSnakeIcons - 点狗蛇 PNG 图标包
        .package(path: "DotDogSnakeIcons"),
    ],
    targets: [
        .target(
            name: "Monologue",
            dependencies: [
                .product(name: "NeteaseCloudMusicAPI", package: "NeteaseCloudMusicAPI-Swift"),
                .product(name: "FFmpegSwiftSDK", package: "ffmpeg-swift"),
                "QQMusicKit",
                "HiconIcons",
                "ZappiconIcons",
                "LucideIcons",
                "SolarIcons",
                "IconExportIcons",
                "BlobIcons",
                "doodlePop",
                "PawPrintIcons",
                "DotDogSnakeIcons",
            ],
            resources: [
                .process("Resources/SanJiPoMoTi.ttf"),
                .process("Resources/HYPixel11pxU.ttf"),
                .process("Resources/ZihunBantianyun.ttf"),
                .process("Resources/YeZiGongChangGangFengSong.ttf"),
                .process("Resources/WenDaoPaoPaoTi-2.ttf"),
                .process("Resources/k8x12S-4.ttf"),
                .process("Resources/eq_presets.json"),
                .process("Resources/en.lproj"),
                .process("Resources/zh-Hans.lproj"),
            ]
        ),
        // MARK: - 测试 Target(material3-expressive-theme Task 15)
        // 单元测试 + Property-Based Testing(PBT)Target
        .testTarget(
            name: "MonologueTests",
            dependencies: ["Monologue"],
            path: "Tests/MonologueTests"
        ),
        // UI / Snapshot 集成测试 Target
        .testTarget(
            name: "MonologueUITests",
            dependencies: ["Monologue"],
            path: "Tests/MonologueUITests"
        ),
    ]
)
