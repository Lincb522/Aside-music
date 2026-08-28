import PhotosUI
import SwiftUI

struct ThemeColorPresetPreviewSwatch: View {
    let theme: GlobalThemeId
    let preset: ThemeColorPreset
    var cornerRadius: CGFloat

    var body: some View {
        if theme == .manga {
            mangaSwatch
        } else {
            ThemeColorPreviewSwatch(
                colors: preset.backgroundPaletteHexes.map { Color(hex: $0) },
                cornerRadius: cornerRadius
            )
        }
    }

    private var mangaSwatch: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let stroke = Color(hex: preset.mangaStrokeHex ?? "17151F")
            let accent = Color(hex: preset.accentStartHex)
            let blockA = Color(hex: preset.mangaBlockAHex ?? "FFE067")
            let blockB = Color(hex: preset.mangaBlockBHex ?? "58B9FF")
            let blockC = Color(hex: preset.mangaBlockCHex ?? "8DE4B8")

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: preset.backgroundPaletteHexes.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(blockA)
                    .frame(width: size.width * 0.32, height: size.width * 0.32)
                    .overlay(Circle().stroke(stroke, lineWidth: 1.1))
                    .position(x: size.width * 0.32, y: size.height * 0.34)

                RoundedRectangle(cornerRadius: size.width * 0.1, style: .continuous)
                    .fill(blockB)
                    .frame(width: size.width * 0.38, height: size.height * 0.21)
                    .overlay(RoundedRectangle(cornerRadius: size.width * 0.1, style: .continuous).stroke(stroke, lineWidth: 1))
                    .position(x: size.width * 0.67, y: size.height * 0.38)

                RoundedRectangle(cornerRadius: size.width * 0.08, style: .continuous)
                    .fill(blockC)
                    .frame(width: size.width * 0.42, height: size.height * 0.18)
                    .overlay(RoundedRectangle(cornerRadius: size.width * 0.08, style: .continuous).stroke(stroke, lineWidth: 1))
                    .position(x: size.width * 0.4, y: size.height * 0.72)

                Circle()
                    .fill(accent)
                    .frame(width: size.width * 0.18, height: size.width * 0.18)
                    .overlay(Circle().stroke(stroke, lineWidth: 0.9))
                    .position(x: size.width * 0.76, y: size.height * 0.72)
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 1.35)
            )
        }
    }
}

struct ThemeColorPreviewSwatch: View {
    let colors: [Color]
    var cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.monoTextPrimary.opacity(0.12), lineWidth: 0.7)
            )
    }
}
