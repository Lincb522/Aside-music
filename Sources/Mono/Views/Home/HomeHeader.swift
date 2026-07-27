import SwiftUI

/// 极简顶栏 — 大字号层叠排版，Liquid Glass 风格
struct HomeHeader: View {
    let userProfile: UserProfile?
    let hitokoto: String?
    let onPersonalFM: () -> Void
    let onSearch: () -> Void

    @ObservedObject private var settings = SettingsManager.shared
    @State private var greetingVisible = false

    private var showHitokoto: Bool {
        settings.hitokotoEnabled && hitokotoText.isEmpty == false
    }

    private var hitokotoText: String {
        hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                if showHitokoto {
                    Text(hitokotoText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.monoTextSecondary.opacity(0.8))
                        .textCase(.uppercase)
                        .lineLimit(1...2)
                        .minimumScaleFactor(0.85)
                        .opacity(greetingVisible ? 1 : 0)
                        .offset(y: greetingVisible ? 0 : 5)
                } else if settings.hitokotoEnabled {
                    Text(HitokotoFallbackSlogan.text)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.monoTextSecondary.opacity(0.8))
                        .lineLimit(1...2)
                        .minimumScaleFactor(0.85)
                        .opacity(greetingVisible ? 1 : 0)
                        .offset(y: greetingVisible ? 0 : 5)
                } else {
                    Text(String(localized: LocalizedStringResource(stringLiteral: greetingKey)))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.monoTextSecondary.opacity(0.8))
                        .opacity(greetingVisible ? 1 : 0)
                        .offset(y: greetingVisible ? 0 : 5)
                }
                
                Text(userProfile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.monoTextPrimary, .monoTextPrimary.opacity(0.7)],
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
        .padding(.top, DeviceLayout.headerTopPadding + 8)
        .padding(.bottom, 0)
    }

    // MARK: - Private

    private func pillIcon(icon: MonoIcon.IconType, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: 16)
                .padding(3)
        }
        .monoGlassButtonStyle()
        .compatCircleButtonBorderShape()
    }

    @ViewBuilder
    private var avatarView: some View {
        let size: CGFloat = 42
        if let avatarUrl = userProfile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url) { Circle().fill(Color.monoSeparator) }
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        } else {
            Circle().fill(Color.monoSeparator)
                .frame(width: size, height: size)
                .overlay(MonoIcon(icon: .profile, size: 18, color: .monoTextSecondary))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }

    private var greetingKey: String {
        MonoTimeGreeting.localizedKey
    }
}
