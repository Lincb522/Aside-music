import SwiftUI

@MainActor
struct PlatformAccountManagementView: View {
    @AppStorage("isLoggedIn") private var isNCMLoggedIn = false
    @ObservedObject private var homeViewModel = HomeViewModel.shared
    @ObservedObject private var qcmSession = QQUserSession.shared
    @ObservedObject private var appleMusicService = AppleMusicService.shared
    @State private var refreshedNCMProfile: UserProfile?
    @State private var isKCMLoggedIn = KCMMusicService.shared.isAuthenticated
    @State private var kcmProfile: KCMAccountProfile?
    @State private var isRefreshing = false

    var body: some View {
        ZStack {
            ThemedSettingsBackground()

            ScrollView {
                VStack(spacing: SettingsPageLayout.sectionSpacing) {
                    SettingsScrollablePageHeader(
                        title: String(localized: "platform_account_management"),
                        eyebrow: String(localized: "settings_eyebrow_accounts"),
                        icon: .personCircle
                    )

                    SettingsSection(title: String(localized: "platform_account_music_services")) {
                        NavigationLink {
                            NCMAccountView()
                        } label: {
                            platformRow(
                                source: .netease,
                                platformName: "NCM",
                                displayName: ncmProfile?.nickname ?? "NCM",
                                detail: ncmMembershipText,
                                isConnected: isNCMLoggedIn,
                                avatarURL: normalizedNCMAvatarURL
                            )
                        }
                        .buttonStyle(.plain)

                        rowDivider

                        NavigationLink {
                            QCMAccountView()
                        } label: {
                            platformRow(
                                source: .qqmusic,
                                platformName: "QCM",
                                displayName: qcmSession.nickname ?? "QCM",
                                detail: qcmSession.isVIP ? "VIP" : nil,
                                isConnected: qcmSession.isLoggedIn,
                                avatarURL: qcmSession.avatarURL
                            )
                        }
                        .buttonStyle(.plain)

                        rowDivider

                        NavigationLink {
                            KCMAccountView()
                        } label: {
                            platformRow(
                                source: .kugou,
                                platformName: "KCM",
                                displayName: kcmProfile?.nickname ?? "KCM",
                                detail: kcmProfile?.membershipLevel.displayName,
                                isConnected: isKCMLoggedIn,
                                avatarURL: kcmProfile?.avatarURL
                            )
                        }
                        .buttonStyle(.plain)

                        rowDivider

                        NavigationLink {
                            AppleMusicAccountView()
                        } label: {
                            platformRow(
                                source: .appleMusic,
                                platformName: "Apple Music",
                                displayName: "Apple Music",
                                detail: nil,
                                isConnected: appleMusicService.isAuthorized,
                                avatarURL: nil,
                                connectedText: String(localized: "platform_account_authorized"),
                                disconnectedText: String(localized: "platform_account_unauthorized")
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    FloatingBarBottomSpacer()
                }
                .padding(.horizontal, DeviceLayout.settingsSectionHorizontalPadding)
                .padding(.bottom, 44)
                .iPadContentWidth(SettingsPageLayout.contentWidth)
            }
            .scrollIndicators(.hidden)
            .refreshable { await refreshAccounts() }
        }
        .asideSettingsDetailChrome(String(localized: "platform_account_management"))
        .task { await refreshAccounts() }
    }

    private var rowDivider: some View {
        Divider()
            .opacity(0.4)
            .padding(.leading, 72)
    }

    private var normalizedNCMAvatarURL: URL? {
        guard var value = ncmProfile?.avatarUrl?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        if value.hasPrefix("//") {
            value = "https:\(value)"
        } else if value.lowercased().hasPrefix("http://") {
            value = "https://" + String(value.dropFirst("http://".count))
        }
        return URL(string: value)
    }

    private var ncmMembershipText: String? {
        guard let vipType = ncmProfile?.vipType, vipType > 0 else { return nil }
        return "VIP"
    }

    private var ncmProfile: UserProfile? {
        refreshedNCMProfile ?? homeViewModel.userProfile
    }

    private func platformRow(
        source: MusicSource,
        platformName: String,
        displayName: String,
        detail: String?,
        isConnected: Bool,
        avatarURL: URL?,
        connectedText: String = String(localized: "platform_account_connected"),
        disconnectedText: String = String(localized: "platform_account_disconnected")
    ) -> some View {
        HStack(spacing: 13) {
            platformAvatar(source: source, avatarURL: avatarURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.monoTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(platformName)
                    if let detail, !detail.isEmpty {
                        Text("·")
                        Text(detail)
                    }
                }
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(Color.monoTextSecondary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(isConnected ? connectedText : disconnectedText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    isConnected
                        ? ThemeColorCustomization.visibleTintColor(
                            source.themedBadgeColor,
                            darkFallback: Color.monoTextPrimary
                        )
                        : Color.monoTextSecondary
                )

            MonoIcon(icon: .chevronRight, size: 12, color: .monoTextSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private func platformAvatar(source: MusicSource, avatarURL: URL?) -> some View {
        ZStack(alignment: .bottomTrailing) {
            CachedAsyncImage(url: avatarURL) {
                Circle()
                    .fill(source.themedBadgeColor.opacity(0.12))
                    .overlay {
                        PlatformBadgeLabel(text: source.shortName, source: source, fontSize: 9)
                    }
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 46, height: 46)
            .clipShape(Circle())

            if avatarURL != nil {
                PlatformBadgeLabel(text: source.shortName, source: source, fontSize: 7)
                    .padding(2)
                    .background(Color.monoBackground)
                    .clipShape(Capsule())
                    .offset(x: 3, y: 2)
            }
        }
        .frame(width: 49, height: 48)
    }

    private func refreshAccounts() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        appleMusicService.refreshAuthorizationStatus()

        async let ncmRefresh = fetchNCMProfile()
        async let qcmRefresh: Void = qcmSession.refresh()
        async let kcmRefresh: KCMAccountProfile? = {
            guard KCMMusicService.shared.isAuthenticated else { return nil }
            return try? await KCMMusicService.shared.fetchAccountProfile()
        }()

        refreshedNCMProfile = await ncmRefresh
        await qcmRefresh
        kcmProfile = await kcmRefresh
        if let kcmProfile {
            await KCMMusicService.shared.synchronizeCurrentAccount(profile: kcmProfile)
        }
        isKCMLoggedIn = KCMMusicService.shared.isAuthenticated
    }

    private func fetchNCMProfile() async -> UserProfile? {
        guard isNCMLoggedIn else { return nil }
        do {
            let loginStatus = try await UnsafeSendableBox(APIService.shared.fetchLoginStatus()).value.async()
            guard let profile = loginStatus.data.profile else { return homeViewModel.userProfile }
            let detail = try? await UnsafeSendableBox(APIService.shared.fetchUserDetail(uid: profile.userId)).value.async()
            return detail?.profile ?? profile
        } catch {
            AppLogger.warning("NCM 账号信息获取失败，使用本地资料: \(error)")
            return homeViewModel.userProfile
        }
    }
}
