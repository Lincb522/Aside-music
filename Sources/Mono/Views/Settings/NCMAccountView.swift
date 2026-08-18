import SwiftUI

struct NCMAccountView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @ObservedObject private var homeViewModel = HomeViewModel.shared
    @State private var showLogoutConfirmation = false

    var body: some View {
        List {
            Section("账号") {
                accountRow
            }

            Section {
                NavigationLink {
                    PlatformLoginView(initialPlatform: .ncm)
                } label: {
                    Label(isLoggedIn ? "重新登录" : "扫码登录", systemImage: "qrcode")
                }

                if isLoggedIn {
                    Button("退出登录", role: .destructive) {
                        showLogoutConfirmation = true
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .claritySettingsListStyle()
        .background(ThemedPageBackground())
        .navigationTitle("NCM 账号")
        .navigationBarTitleDisplayMode(.inline)
        .monoNavigationBackButton()
        .confirmationDialog("退出 NCM 登录？", isPresented: $showLogoutConfirmation) {
            Button("退出登录", role: .destructive, action: logout)
            Button("取消", role: .cancel) {}
        }
    }

    private var accountRow: some View {
        HStack(spacing: 12) {
            PlatformBadgeLabel(text: MusicSource.netease.shortName, source: .netease, fontSize: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(homeViewModel.userProfile?.nickname ?? "NCM")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.monoTextPrimary)

                Text(isLoggedIn ? "已登录" : "未登录")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.monoTextSecondary)
            }

            Spacer()

            if let avatar = homeViewModel.userProfile?.avatarUrl.flatMap(URL.init(string:)) {
                CachedAsyncImage(url: avatar) {
                    avatarPlaceholder
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 42, height: 42)
                .clipShape(Circle())
            }
        }
        .padding(.vertical, 4)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.monoSeparator)
            .overlay {
                MonoIcon(icon: .personCircle, size: 20, color: .monoTextSecondary)
            }
    }

    private func logout() {
        let publisher = UnsafeSendableBox(APIService.shared.logout())
        isLoggedIn = false
        Task {
            do {
                _ = try await publisher.value.async()
            } catch {
                AppLogger.warning("NCM 远端退出失败，本地已退出: \(error)")
            }
        }
    }
}
