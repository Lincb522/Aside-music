import PhotosUI
import SwiftUI

struct AppBrandOptionCard: View {
    let style: AppBrandStyle
    let appearance: AppBrandAppearance
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(previewBackground)
                .frame(height: 94)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(previewStrokeColor, lineWidth: 1)
                }
                .overlay {
                    Image(style.previewAssetName(for: appearance))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(appearance == .dark ? 0.26 : 0.12), radius: 10, x: 0, y: 4)
                }

            if isSelected {
                Circle()
                    .fill(Color.monoAccent)
                    .frame(width: 20, height: 20)
                    .overlay(MonoIcon(icon: .checkmark, size: 11, color: .monoAccentForeground, lineWidth: 2.1))
                    .padding(7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.monoIconBackground.opacity(0.14) : Color.monoSeparator.opacity(0.38))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.monoAccent.opacity(0.4) : Color.clear, lineWidth: 1.2)
        }
    }

    private var previewBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: style.previewBackgroundColor(for: appearance)),
                Color(hex: style.previewBackgroundColor(for: appearance)).opacity(0.92),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var previewStrokeColor: Color {
        appearance == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.42)
    }
}
