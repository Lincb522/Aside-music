import SwiftUI

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
