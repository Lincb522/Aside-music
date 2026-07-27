import SwiftUI

/// 底部入口 — 横排透明玻璃卡片
struct HomeEntryCards: View {
    let onNewSongExpress: () -> Void
    let onMVDiscover: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var cardCornerRadius: CGFloat {
        if MinimalWhiteStyle.isActive { return 16 }
        if NeumorphicStyle.isActive { return 22 }
        return MujiStyle.isActive ? 16 : 20
    }

    var body: some View {
        HStack(spacing: 12) {
            entryBlock(icon: .musicNote, title: "new_song_express", action: onNewSongExpress)
            entryBlock(icon: .mv, title: "home_mv_zone", action: onMVDiscover)
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private func entryBlock(
        icon: MonoIcon.IconType,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                MonoIcon(icon: icon, size: 20, color: .monoTextPrimary)
                    .frame(width: 38, height: 38)
                    .background {
                        if MinimalWhiteStyle.isActive {
                            MinimalWhiteCircleBackground()
                        } else if NeumorphicStyle.isActive {
                            NeumorphicSurfaceBackground(cornerRadius: 15, elevated: false, pressed: true, lightweight: true)
                        } else {
                            Circle().fill(Color.monoTextPrimary.opacity(0.07))
                        }
                    }

                Spacer()

                Text(LocalizedStringKey(title))
                    .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(15, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(15, weight: .semibold) : .system(size: 15, weight: .bold, design: .rounded)))
                    .foregroundColor(.monoTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: DeviceLayout.entryCardHeight)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .overlay {
                if MinimalWhiteStyle.isActive {
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                } else if MujiStyle.isActive {
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .stroke(MujiStyle.hairline.opacity(0.52), lineWidth: 0.7)
                }
            }
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
    }

    private var entryFill: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.glassFill }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surface.opacity(colorScheme == .dark ? 0.78 : 0.88) }
        return colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    @ViewBuilder
    private var cardBackground: some View {
        if MinimalWhiteStyle.isActive {
            MinimalWhiteSurfaceBackground(
                cornerRadius: cardCornerRadius,
                elevated: false,
                tint: entryFill
            )
        } else if ThemedPageStyle.isActive {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(entryFill)
        } else {
            ClassicAsideEmbeddedSurface(cornerRadius: cardCornerRadius)
        }
    }
}
