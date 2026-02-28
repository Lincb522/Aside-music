import SwiftUI

/// 极简顶栏 — 大字号层叠排版，Liquid Glass 风格
struct HomeHeader: View {
    let userProfile: UserProfile?
    let hitokoto: String?
    let onPersonalFM: () -> Void
    let onSearch: () -> Void

    @State private var greetingVisible = false

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                // 如果有一言，展示一言；否则后备展示“早上好/晚上好”等
                let topText = (hitokoto?.isEmpty == false) ? hitokoto! : String(localized: LocalizedStringResource(stringLiteral: greetingKey))
                Text(topText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextSecondary.opacity(0.8))
                    .textCase(.uppercase)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(greetingVisible ? 1 : 0)
                    .offset(y: greetingVisible ? 0 : 5)
                
                Text(userProfile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.asideTextPrimary, .asideTextPrimary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .opacity(greetingVisible ? 1 : 0)
                    .offset(y: greetingVisible ? 0 : 5)
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                    greetingVisible = true
                }
            }

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                pillIcon(icon: .fm, action: onPersonalFM)
                pillIcon(icon: .search, action: onSearch)
                avatarView
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, DeviceLayout.headerTopPadding + 8) // 多给一点顶部呼吸感
        .padding(.bottom, 0)
    }

    // MARK: - Private

    private func pillIcon(icon: AsideIcon.IconType, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            AsideIcon(icon: icon, size: 16, color: .asideTextPrimary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.asideTextPrimary.opacity(0.04)))
                .glassEffect(.regular, in: .circle)
        }
        .buttonStyle(AsideBouncingButtonStyle())
    }

    @ViewBuilder
    private var avatarView: some View {
        let size: CGFloat = 42
        if let avatarUrl = userProfile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url) { Circle().fill(Color.asideSeparator) }
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        } else {
            Circle().fill(Color.asideSeparator)
                .frame(width: size, height: size)
                .overlay(AsideIcon(icon: .profile, size: 18, color: .asideTextSecondary))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }

    private var greetingKey: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "good_morning"
        case 12..<17: return "good_afternoon"
        default:      return "good_evening"
        }
    }
}
