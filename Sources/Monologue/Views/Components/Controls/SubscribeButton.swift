import SwiftUI

/// 通用收藏/订阅按钮组件 — 与"立即播放"按钮统一风格
struct SubscribeButton: View {
    let isSubscribed: Bool
    let action: () -> Void
    var label: (subscribed: String, unsubscribed: String) = (String(localized: "playlist_picker_already_saved"), String(localized: "收藏"))

    typealias Theme = PlaylistDetailView.Theme

    @ViewBuilder
    var body: some View {
        if MujiStyle.isActive {
            Button(action: action) {
                MujiActionPill(
                    title: isSubscribed ? label.subscribed : label.unsubscribed,
                    icon: isSubscribed ? .liked : .like,
                    selected: true,
                    tint: isSubscribed ? MujiStyle.tea : MujiStyle.clay
                )
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
        } else if NeumorphicStyle.isActive {
            Button(action: action) {
                NeumorphicPill(
                    text: isSubscribed ? label.subscribed : label.unsubscribed,
                    tint: isSubscribed ? NeumorphicStyle.red : NeumorphicStyle.accent,
                    icon: isSubscribed ? .liked : .like,
                    selected: true
                )
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
        } else if SignalStyle.isActive {
            Button(action: action) {
                SignalPill(
                    text: isSubscribed ? label.subscribed : label.unsubscribed,
                    tint: isSubscribed ? SignalStyle.rust : SignalStyle.accent,
                    icon: isSubscribed ? .liked : .like,
                    selected: true
                )
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
        } else if SequoiaStyle.isActive {
            Button(action: action) {
                SequoiaPill(
                    text: isSubscribed ? label.subscribed : label.unsubscribed,
                    icon: isSubscribed ? .liked : .like,
                    tint: isSubscribed ? SequoiaStyle.red : SequoiaStyle.accent,
                    selected: true
                )
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
        } else {
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
}
