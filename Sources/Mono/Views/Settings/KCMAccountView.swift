import SwiftUI

@MainActor
struct KCMAccountView: View {
    @State private var isLoggedIn = KCMMusicService.shared.isAuthenticated
    @State private var profile: KCMAccountProfile?
    @State private var isLoadingProfile = false
    @State private var isProcessingVIP = false
    @State private var statusMessage: String?
    @State private var showLogoutConfirmation = false

    var body: some View {
        List {
            Section("账号") {
                accountRow
            }

            Section {
                NavigationLink {
                    PlatformLoginView(initialPlatform: .kcm)
                } label: {
                    Label(isLoggedIn ? "重新登录" : "扫码登录", systemImage: "qrcode")
                }
            }

            if isLoggedIn {
                Section("概念版会员") {
                    membershipRow(title: "当前状态", value: membershipDisplayName)

                    if let expiration = profile?.membershipExpiration {
                        membershipRow(title: "有效期至", value: expiration.formatted(date: .abbreviated, time: .shortened))
                    }

                    Button {
                        claimDailyVIP()
                    } label: {
                        HStack {
                            Label("领取今日会员", systemImage: "gift")
                            Spacer()
                            if isProcessingVIP {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isProcessingVIP)

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.monoTextSecondary)
                    }
                }

                Section {
                    Button("退出登录", role: .destructive) {
                        showLogoutConfirmation = true
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .claritySettingsListStyle()
        .background(ThemedPageBackground())
        .navigationTitle("KCM 账号")
        .navigationBarTitleDisplayMode(.inline)
        .monoNavigationBackButton()
        .task { await refreshAccount() }
        .refreshable { await refreshAccount() }
        .confirmationDialog("退出 KCM 登录？", isPresented: $showLogoutConfirmation) {
            Button("退出登录", role: .destructive, action: logout)
            Button("取消", role: .cancel) {}
        }
    }

    private var accountRow: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: profile?.avatarURL) {
                avatarPlaceholder
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 46, height: 46)
            .clipShape(Circle())
            .overlay(alignment: .bottomTrailing) {
                PlatformBadgeLabel(text: "KCM", source: .kugou, fontSize: 7)
                    .offset(x: 4, y: 2)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(profile?.nickname ?? "KCM")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.monoTextPrimary)
                    .lineLimit(1)

                if let userID = profile?.userID ?? KCMMusicService.shared.currentUserID {
                    Text("ID \(userID)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.monoTextSecondary)
                } else {
                    Text(isLoggedIn ? "已登录" : "未登录")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.monoTextSecondary)
                }
            }

            Spacer(minLength: 8)

            if isLoadingProfile {
                ProgressView()
            } else if isLoggedIn {
                Text(membershipDisplayName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        profile?.membershipLevel == KCMMembershipLevel.none
                            ? Color.monoTextSecondary
                            : MusicSource.kugou.themedBadgeColor
                    )
            }
        }
        .padding(.vertical, 4)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(MusicSource.kugou.themedBadgeColor.opacity(0.12))
            .overlay {
                MonoIcon(icon: .personCircle, size: 20, color: .monoTextSecondary)
            }
    }

    private var membershipDisplayName: String {
        guard let profile else { return isLoggedIn ? "查询中" : "无会员" }
        switch profile.membershipLevel {
        case .none:
            return "无会员"
        case .full:
            return "正式会员"
        case .trial:
            return profile.conceptProductType == "svip" ? "畅听会员" : "体验会员"
        }
    }

    private func membershipRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.monoTextPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(Color.monoTextSecondary)
        }
    }

    private func refreshAccount() async {
        isLoggedIn = KCMMusicService.shared.isAuthenticated
        guard isLoggedIn else {
            profile = nil
            return
        }

        isLoadingProfile = true
        defer { isLoadingProfile = false }
        do {
            let refreshedProfile = try await KCMMusicService.shared.fetchAccountProfile()
            profile = refreshedProfile
            if let refreshedProfile {
                await KCMMusicService.shared.synchronizeCurrentAccount(profile: refreshedProfile)
            }
        } catch {
            statusMessage = error.localizedDescription
            AppLogger.warning("KCM 账号信息获取失败: \(error)")
        }
    }

    private func claimDailyVIP() {
        guard !isProcessingVIP else { return }
        if KCMDailyMembershipEngine.shared.hasCompletedToday() {
            statusMessage = "今日会员已领取"
            HapticManager.shared.success()
            return
        }
        isProcessingVIP = true
        statusMessage = nil
        Task { @MainActor in
            defer { isProcessingVIP = false }
            do {
                let claimResult = try await KCMMusicService.shared.claimDailyLiteVIP()
                let claimText = switch claimResult {
                case .claimed: "领取成功"
                case .alreadyClaimed: "今日会员已领取"
                }
                KCMDailyMembershipEngine.shared.recordCompletion()

                let resultMessage: String
                do {
                    let upgraded = try await KCMMusicService.shared.upgradeDailyLiteVIP()
                    resultMessage = upgraded ? "\(claimText)，升级成功" : "\(claimText)，升级未完成"
                } catch {
                    resultMessage = "\(claimText)，\(error.localizedDescription)"
                }
                await refreshAccount()
                statusMessage = resultMessage
                HapticManager.shared.success()
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    private func logout() {
        KCMMusicService.shared.logout()
        isLoggedIn = false
        profile = nil
        statusMessage = nil
    }
}
