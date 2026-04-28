import SwiftUI

/// 底部入口 — 横排透明玻璃卡片
struct HomeEntryCards: View {
    let onNewSongExpress: () -> Void
    let onMVDiscover: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var cardCornerRadius: CGFloat {
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
        icon: MonologueIcon.IconType,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                MonologueIcon(icon: icon, size: 20, color: .monologueTextPrimary)
                    .frame(width: 38, height: 38)
                    .background {
                        if NeumorphicStyle.isActive {
                            NeumorphicSurfaceBackground(cornerRadius: 15, elevated: false, pressed: true)
                        } else {
                            Circle().fill(Color.monologueTextPrimary.opacity(0.07))
                        }
                    }

                Spacer()

                Text(LocalizedStringKey(title))
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(15, weight: .semibold) : .system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: DeviceLayout.entryCardHeight)
            .background(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(entryFill)
            )
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .overlay {
                if MujiStyle.isActive {
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .stroke(MujiStyle.hairline.opacity(0.52), lineWidth: 0.7)
                }
            }
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
    }

    private var entryFill: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.surface.opacity(colorScheme == .dark ? 0.78 : 0.88) }
        return colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
}
