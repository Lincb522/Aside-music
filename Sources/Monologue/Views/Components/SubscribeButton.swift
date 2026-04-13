import SwiftUI

/// 通用收藏/订阅按钮组件 — 与"立即播放"按钮统一风格
struct SubscribeButton: View {
    let isSubscribed: Bool
    let action: () -> Void
    var label: (subscribed: String, unsubscribed: String) = (String(localized: "已收藏"), String(localized: "收藏"))

    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                MonologueIcon(
                    icon: isSubscribed ? .liked : .like,
                    size: 12,
                    color: .monologueIconForeground,
                    lineWidth: 1.4
                )
                Text(isSubscribed ? label.subscribed : label.unsubscribed)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.monologueIconForeground)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.accent)
            .cornerRadius(20)
            .shadow(color: Theme.accent.opacity(0.2), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
    }
}
