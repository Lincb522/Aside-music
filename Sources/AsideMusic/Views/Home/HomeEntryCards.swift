import SwiftUI

/// 底部入口 — 横排透明玻璃卡片
struct HomeEntryCards: View {
    let onNewSongExpress: () -> Void
    let onMVDiscover: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            entryBlock(icon: .musicNote, title: "new_song_express", action: onNewSongExpress)
            entryBlock(icon: .playCircleFill, title: "home_mv_zone", action: onMVDiscover)
        }
        .padding(.horizontal, 16)
    }

    private func entryBlock(
        icon: AsideIcon.IconType,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                AsideIcon(icon: icon, size: 24, color: .asideTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.asideTextPrimary.opacity(0.08)))

                Spacer()

                Text(LocalizedStringKey(title))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.08)
                          : Color.white)
            )
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.96))
    }
}
