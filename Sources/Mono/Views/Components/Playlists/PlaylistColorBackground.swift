import SwiftUI
import CoreImage

private let playlistBrightnessContext = CIContext(
    options: [.workingColorSpace: kCFNull as Any]
)

/// 封面模糊背景 — 封面图放大铺满 + 高斯模糊 + 蒙层
struct PlaylistColorBackground: View {
    let coverUrl: URL?
    var onBrightnessChanged: ((Bool) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var coverImage: UIImage?
    @StateObject private var colorExtractor = CoverColorExtractor()

    private var baseColor: Color {
        colorScheme == .dark ? Color(hex: "050507") : Color(hex: "F8F9FB")
    }

    var body: some View {
        ZStack {
            baseColor.ignoresSafeArea()

            if let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .blur(radius: 55)
                    .scaleEffect(1.3)
                    .clipped()
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeOut(duration: 0.6)))

                DynamicCoverPaletteLayer(
                    colors: colorExtractor.palette,
                    opacity: colorScheme == .dark ? 0.52 : 0.34
                )
                .drawingGroup(opaque: false)
                .blendMode(colorScheme == .dark ? .plusLighter : .softLight)

                tintOverlay
                bottomFade
            }
        }
        .ignoresSafeArea()
        .task(id: coverUrl) {
            guard let url = coverUrl else {
                withAnimation(.easeOut(duration: 0.25)) {
                    coverImage = nil
                }
                onBrightnessChanged?(false)
                colorExtractor.reset()
                return
            }
            colorExtractor.extract(from: url.absoluteString)
            // A heavily blurred background does not benefit from a 1200 px
            // decode. A 320 pt source preserves the rendered appearance while
            // reducing texture upload and blur working-set cost.
            let loaded = await ImageLoadCoordinator.shared.loadImage(
                url: url,
                maxSize: 320
            )
            if let loaded {
                let isDark = loaded.averageBrightness < 0.45
                onBrightnessChanged?(isDark)
            }
            withAnimation(.easeOut(duration: 0.6)) {
                coverImage = loaded
            }
        }
        .onChange(of: colorExtractor.isDark) { _, isDark in
            onBrightnessChanged?(isDark)
        }
    }

    // MARK: - 蒙层

    private var tintOverlay: some View {
        let isDark = colorScheme == .dark
        return Rectangle()
            .fill(baseColor.opacity(isDark ? 0.35 : 0.35))
            .ignoresSafeArea()
    }

    // MARK: - 底部渐隐

    private var bottomFade: some View {
        let isDark = colorScheme == .dark
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.45),
                .init(color: baseColor.opacity(isDark ? 0.5 : 0.55), location: 0.7),
                .init(color: baseColor.opacity(isDark ? 0.9 : 0.95), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - UIImage 亮度检测

extension UIImage {
    /// 使用 CIAreaAverage 计算图片平均感知亮度 (0 = 纯黑, 1 = 纯白)
    var averageBrightness: CGFloat {
        guard let ciImage = CIImage(image: self) else { return 0.5 }
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: ciImage.extent)
        ])
        guard let outputImage = filter?.outputImage else { return 0.5 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        playlistBrightnessContext.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let r = CGFloat(bitmap[0]) / 255
        let g = CGFloat(bitmap[1]) / 255
        let b = CGFloat(bitmap[2]) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}
