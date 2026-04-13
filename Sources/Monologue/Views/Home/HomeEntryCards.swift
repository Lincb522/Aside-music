import SwiftUI

/// 底部入口 — 横排透明玻璃卡片
struct HomeEntryCards: View {
    let onNewSongExpress: () -> Void
    let onMVDiscover: () -> Void

    @Environment(\.colorScheme) private var colorScheme

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
                    .background(Circle().fill(Color.monologueTextPrimary.opacity(0.07)))

                Spacer()

                Text(LocalizedStringKey(title))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: DeviceLayout.entryCardHeight)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.08)
                          : Color.white)
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
    }
}
