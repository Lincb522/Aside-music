import SwiftUI
import QQMusicKit

struct QCMAccountView: View {
    @ObservedObject private var userSession = QQUserSession.shared
    @State private var isChecking = false
    @State private var showLogoutConfirmation = false

    var body: some View {
        List {
            Section("账号") {
                accountRow
            }

            Section {
                NavigationLink {
                    PlatformLoginView(initialPlatform: .qcm)
                } label: {
                    Label(userSession.isLoggedIn ? "重新登录" : "扫码登录", systemImage: "qrcode")
                }

                if userSession.isLoggedIn {
                    Button("退出登录", role: .destructive) {
                        showLogoutConfirmation = true
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .claritySettingsListStyle()
        .background(ThemedPageBackground())
        .navigationTitle("QCM 账号")
        .navigationBarTitleDisplayMode(.inline)
        .monoNavigationBackButton()
        .onAppear {
            Task { await refreshAccount() }
        }
        .confirmationDialog("退出 QCM 登录？", isPresented: $showLogoutConfirmation) {
            Button("退出登录", role: .destructive, action: logout)
            Button("取消", role: .cancel) {}
        }
    }

    private var accountRow: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: userSession.avatarURL) {
                avatarPlaceholder
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 46, height: 46)
            .clipShape(Circle())
            .overlay(alignment: .bottomTrailing) {
                PlatformBadgeLabel(text: "QCM", source: .qqmusic, fontSize: 7)
                    .offset(x: 4, y: 2)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(userSession.nickname ?? "QCM")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.monoTextPrimary)

                Text(userSession.isLoggedIn ? "已登录" : "未登录")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.monoTextSecondary)
            }

            Spacer()

            if isChecking {
                ProgressView()
            } else if userSession.isVIP {
                Text("VIP")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(MusicSource.qqmusic.themedBadgeColor)
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

    @MainActor
    private func refreshAccount() async {
        isChecking = true
        defer { isChecking = false }

        await userSession.refresh()
    }

    private func logout() {
        userSession.onLogout()
    }
}

typealias QQAccountView = QCMAccountView
