import SwiftUI

/// 通用收藏/订阅按钮组件
struct SubscribeButton: View {
    let isSubscribed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSubscribed ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .semibold))
                Text(isSubscribed ? "已收藏" : "收藏")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSubscribed ? .white : .asideTextPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSubscribed ? Color.red.opacity(0.8) : Color.asideCardBackground)
            )
        }
        .buttonStyle(AsideBouncingButtonStyle())
    }
}
