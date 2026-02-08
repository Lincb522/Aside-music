import SwiftUI

/// 通用收藏/订阅按钮组件 — 与"立即播放"按钮统一风格
struct SubscribeButton: View {
    let isSubscribed: Bool
    let action: () -> Void

    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                AsideIcon(
                    icon: isSubscribed ? .liked : .like,
                    size: 12,
                    color: .asideIconForeground,
                    lineWidth: 1.4
                )
                Text(isSubscribed ? "已收藏" : "收藏")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.asideIconForeground)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.accent)
            .cornerRadius(20)
            .shadow(color: Theme.accent.opacity(0.2), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
    }
}
