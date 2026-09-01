import Combine
import QQMusicKit
import SwiftUI

extension ProfileView {
    // MARK: - aside 未登录页

    /// 编辑部风格的未登录页：眉题 + 大字状态 + 引文说明 + 索引目录，与登录后的版式同一套语汇
    var asideNotLoggedInContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedProfileBackground()

                VStack(alignment: .leading, spacing: 0) {
                    asideGuestEyebrow
                        .padding(.top, 12)

                    Spacer(minLength: 0)

                    asideGuestHero

                    Spacer(minLength: 0)

                    asideGuestMenuIndex
                        .padding(.bottom, 140)
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .iPadContentWidth(700)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .profileNavigationDestinations()
        }
    }

    var asideGuestEyebrow: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color.monoAccent)
                .frame(width: 18, height: 3)

            Text("PROFILE")
                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                .tracking(2.4)
                .foregroundColor(.monoTextSecondary.opacity(0.72))
                .fixedSize()

            Rectangle()
                .fill(Color.monoSeparator.opacity(0.5))
                .frame(height: 0.5)

            NavigationLink(value: ProfileNavigationDestination.settings) {
                MonoIcon(icon: .settings, size: 19, color: .monoTextPrimary.opacity(0.85), lineWidth: 1.7)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.monoIconBackground.opacity(0.1))
                            .overlay(Circle().stroke(Color.monoTextPrimary.opacity(0.12), lineWidth: 0.8))
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
        }
    }

    var asideGuestHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: LocalizedStringResource(stringLiteral: MonoTimeGreeting.localizedKey)))
                .font(.rounded(size: 12.5, weight: .semibold))
                .foregroundColor(.monoTextSecondary.opacity(0.85))

            Text(LocalizedStringKey("profile_not_logged_in"))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.monoTextPrimary)
                .padding(.top, 6)

            Text(LocalizedStringKey("profile_login_desc"))
                .font(.rounded(size: 13))
                .foregroundColor(.monoTextSecondary)
                .lineSpacing(3)
                .padding(.top, 14)
                .padding(.leading, 2)

            Button(action: { navigationPath.append(ProfileNavigationDestination.loginNCM) }) {
                HStack(spacing: 8) {
                    Text(LocalizedStringKey("profile_login_button"))
                        .font(.rounded(size: 14, weight: .bold))

                    MonoIcon(icon: .chevronRight, size: 11, color: .monoIconForeground)
                }
                .foregroundColor(.monoIconForeground)
                .padding(.horizontal, 26)
                .padding(.vertical, 13)
                .background(Capsule().fill(Color.monoIconBackground))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
            .padding(.top, 26)
        }
    }

    /// 登录前仍可使用的入口：QCM 独立登录、本地听歌统计
    var asideGuestMenuIndex: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.monoAccent)
                    .frame(width: 3, height: 13)

                Text(String(localized: "profile_settings"))
                    .font(.rounded(size: 15, weight: .bold))
                    .foregroundColor(.monoTextPrimary)

                Spacer(minLength: 0)
            }
            .padding(.bottom, 6)

            Button {
                navigationPath.append(ProfileNavigationDestination.platformAccounts)
            } label: {
                asideMenuRow(
                    index: 1,
                    title: "平台账号管理",
                    trailingText: "4 个平台"
                )
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

            asideMenuHairline

            NavigationLink(destination: ListeningStatsView()) {
                asideMenuRow(index: 2, title: String(localized: "cloud_sync_listening_stats"))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
        }
    }

    // MARK: - Signal 未登录页

    var signalNotLoggedInContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                SignalRootBackdrop()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        signalGuestHeader

                        SignalGuestIdentityPanel {
                            navigationPath.append(ProfileNavigationDestination.loginNCM)
                        }

                        signalGuestMenu

                        FloatingBarBottomSpacer()
                    }
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .padding(.top, 8)
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .profileNavigationDestinations()
        }
    }

    private var signalGuestHeader: some View {
        HStack(spacing: 12) {
            SignalBreathingIndicator(size: 6)

            Text(String(localized: "tab_profile"))
                .font(SignalStyle.titleFont(28, weight: .semibold))
                .foregroundStyle(SignalStyle.ink)

            Spacer(minLength: 8)

            NavigationLink(value: ProfileNavigationDestination.settings) {
                MonoIcon(
                    icon: .settings,
                    size: 17,
                    color: SignalStyle.inkSoft,
                    lineWidth: 1.6,
                    forceTemplateRendering: true
                )
                .frame(width: 42, height: 42)
                .contentShape(Rectangle())
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
            .accessibilityLabel(String(localized: "profile_settings"))
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SignalStyle.separator.opacity(0.62))
                .frame(height: 0.65)
        }
        .monoPageHeaderCollapse()
    }

    private var signalGuestMenu: some View {
        VStack(spacing: 0) {
            Button {
                navigationPath.append(ProfileNavigationDestination.platformAccounts)
            } label: {
                SignalGuestMenuRow(
                    icon: .musicNote,
                    title: String(localized: "platform_account_management")
                )
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

            signalGuestDivider

            NavigationLink(destination: ListeningStatsView()) {
                SignalGuestMenuRow(
                    icon: .sparkle,
                    title: String(localized: "cloud_sync_listening_stats")
                )
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

            signalGuestDivider

            NavigationLink(destination: StorageManageView()) {
                SignalGuestMenuRow(
                    icon: .storage,
                    title: String(localized: "profile_cache_manage")
                )
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
        }
    }

    private var signalGuestDivider: some View {
        Rectangle()
            .fill(SignalStyle.separator.opacity(0.62))
            .frame(height: 0.7)
            .padding(.leading, 64)
    }

    var minimalWhiteNotLoggedInContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                MinimalWhiteRootBackdrop().ignoresSafeArea()

                VStack(spacing: 24) {
                    HStack {
                        Text(String(localized: "tab_profile"))
                            .font(MinimalWhiteStyle.titleFont(30, weight: .semibold))
                            .foregroundStyle(MinimalWhiteStyle.ink)

                        Spacer(minLength: 0)

                        NavigationLink(value: ProfileNavigationDestination.settings) {
                            MonoIcon(icon: .settings, size: 17, color: MinimalWhiteStyle.ink, lineWidth: 1.7)
                                .frame(width: 40, height: 40)
                                .background(MinimalWhiteCircleBackground(elevated: true, selected: true))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)

                    MonoIcon(icon: .profile, size: 30, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.5)
                        .frame(width: 76, height: 76)
                        .background(MinimalWhiteCircleBackground(elevated: true))

                    Text(LocalizedStringKey("profile_not_logged_in"))
                        .font(MinimalWhiteStyle.titleFont(21, weight: .semibold))
                        .foregroundStyle(MinimalWhiteStyle.ink)

                    Button(action: { navigationPath.append(ProfileNavigationDestination.loginNCM) }) {
                        Text(LocalizedStringKey("profile_login_button"))
                            .font(MinimalWhiteStyle.labelFont(15, weight: .semibold))
                            .foregroundStyle(MinimalWhiteStyle.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(MinimalWhiteStyle.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                    FloatingBarBottomSpacer()
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.top, DeviceLayout.headerTopPadding + 8)
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .profileNavigationDestinations()
        }
    }

    var petWhiteNotLoggedInContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedProfileBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        petWhiteGuestIdentityDeck
                            .padding(.horizontal, 14)
                            .padding(.top, 8)

                        petWhiteProfileQuickActions
                            .padding(.horizontal, 14)

                        petWhiteProfileAccountPanel
                            .padding(.horizontal, 14)

                        FloatingBarBottomSpacer()
                    }
                    .iPadContentWidth(700)
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .profileNavigationDestinations()
        }
    }

    var petWhiteGuestIdentityDeck: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    PetWhitePill(text: "PAWCELAIN", tint: PetWhiteStyle.mint)

                    Text(LocalizedStringKey("profile_not_logged_in"))
                        .font(PetWhiteStyle.titleFont(29, weight: .black))
                        .foregroundStyle(PetWhiteStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(LocalizedStringKey("profile_login_hint"))
                        .font(PetWhiteStyle.bodyFont(13, weight: .semibold))
                        .foregroundStyle(PetWhiteStyle.inkSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                NavigationLink(value: ProfileNavigationDestination.settings) {
                    PetWhiteIconBadge(icon: .settings, tint: PetWhiteStyle.sky, size: 48)
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
            }

            HStack(alignment: .center, spacing: 16) {
                PetWhitePetPetIcon(size: 96)
                    .frame(width: 96, height: 96)
                    .background(PetWhiteStyle.surfacePressed, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(PetWhiteStyle.stroke, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 10) {
                    Button(action: { navigationPath.append(ProfileNavigationDestination.loginNCM) }) {
                        HStack(spacing: 8) {
                            PetWhitePackIcon(icon: .profileFilled, size: 16, visualScale: 1.06)
                            Text(LocalizedStringKey("profile_login_button"))
                                .font(PetWhiteStyle.labelFont(15, weight: .black))
                        }
                        .foregroundStyle(PetWhiteStyle.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(PetWhiteStyle.mint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(PetWhiteStyle.stroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(MonoBouncingButtonStyle())

                    HStack(spacing: 8) {
                        PetWhitePill(text: "NCM", tint: PetWhiteStyle.butter)
                        PetWhitePill(text: "QCM", tint: PetWhiteStyle.sky)
                    }
                }
            }
        }
        .padding(18)
        .background(
            PetWhiteSurfaceBackground(
                cornerRadius: 30,
                elevated: true,
                tint: PetWhiteStyle.surfaceRaised,
                accent: PetWhiteStyle.dogOrange
            )
        )
    }

    var capsuleNotLoggedInContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedProfileBackground()

                AnyView(
                    ScrollView {
                        capsuleGuestContent
                    }
                    .scrollIndicators(.hidden)
                    .themeRenderScrollLayer()
                )
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .profileNavigationDestinations()
        }
    }

    private var capsuleGuestContent: AnyView {
        AnyView(
            VStack(spacing: 16) {
                capsuleProfileHeader
                capsuleGuestIdentityCard
                capsuleGuestMenuSection
                FloatingBarBottomSpacer()
            }
            .iPadContentWidth(700)
        )
    }

    private var capsuleGuestIdentityCard: AnyView {
        AnyView(
            VStack(spacing: 18) {
                CapsuleIconBadge(icon: .profileFilled, tint: CapsuleStyle.accent, size: 78)

                VStack(spacing: 8) {
                    Text(LocalizedStringKey("profile_not_logged_in"))
                        .font(CapsuleStyle.titleFont(25, weight: .bold))
                        .foregroundStyle(CapsuleStyle.ink)

                    Text(LocalizedStringKey("profile_login_hint"))
                        .font(CapsuleStyle.bodyFont(13, weight: .medium))
                        .foregroundStyle(CapsuleStyle.inkSoft)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                Button(action: { navigationPath.append(ProfileNavigationDestination.loginNCM) }) {
                    Text(LocalizedStringKey("profile_login_button"))
                        .font(CapsuleStyle.labelFont(16, weight: .bold))
                        .foregroundStyle(CapsuleStyle.readableLabel(on: CapsuleStyle.accent))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            Capsule()
                                .fill(CapsuleStyle.accent)
                                .shadow(color: CapsuleStyle.accent.opacity(0.22), radius: 12, x: 0, y: 7)
                        )
                }
                .buttonStyle(CapsulePressStyle())
            }
            .padding(22)
            .background(CapsuleSurfaceBackground(cornerRadius: 34, elevated: true, tint: CapsuleStyle.surface.opacity(0.95)))
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        )
    }

    private var capsuleGuestMenuSection: AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 12) {
                CapsuleSectionTitle(title: String(localized: "profile_settings"), tint: CapsuleStyle.violet)

                VStack(spacing: 10) {
                    capsuleGuestPlatformAccountsRow

                    // 保留下载入口结构，由功能开关统一控制。
                    if AppConfig.Features.downloadEnabled {
                        capsuleGuestDownloadsRow
                    }

                    capsuleGuestListeningStatsRow
                    capsuleGuestStorageRow
                    capsuleGuestSettingsRow
                }
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        )
    }

    private var capsuleGuestPlatformAccountsRow: AnyView {
        AnyView(
            Button(action: { navigationPath.append(ProfileNavigationDestination.platformAccounts) }) {
                ProfileMenuRow(
                    icon: .musicNote,
                    title: "平台账号管理",
                    trailingText: "4 个平台"
                )
            }
            .buttonStyle(CapsulePressStyle())
        )
    }

    private var capsuleGuestDownloadsRow: AnyView {
        AnyView(
            NavigationLink(destination: DownloadManageView()) {
                ProfileMenuRow(
                    icon: .download,
                    title: NSLocalizedString("profile_downloads", comment: ""),
                    trailingText: String(format: String(localized: "profile_recent_count"), downloadedSongCount)
                )
            }
            .buttonStyle(CapsulePressStyle())
        )
    }

    private var capsuleGuestListeningStatsRow: AnyView {
        AnyView(
            NavigationLink(destination: ListeningStatsView()) {
                ProfileMenuRow(
                    icon: .sparkle,
                    title: String(localized: "cloud_sync_listening_stats")
                )
            }
            .buttonStyle(CapsulePressStyle())
        )
    }

    private var capsuleGuestStorageRow: AnyView {
        AnyView(
            NavigationLink(destination: StorageManageView()) {
                ProfileMenuRow(
                    icon: .storage,
                    title: String(localized: "profile_cache_manage")
                )
            }
            .buttonStyle(CapsulePressStyle())
        )
    }

    private var capsuleGuestSettingsRow: AnyView {
        AnyView(
            NavigationLink(value: ProfileNavigationDestination.settings) {
                ProfileMenuRow(
                    icon: .settings,
                    title: NSLocalizedString("profile_settings", comment: "")
                )
            }
            .buttonStyle(CapsulePressStyle())
        )
    }

    var liquidGlassNotLoggedInContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedProfileBackground()

                AnyView(
                    ScrollView {
                        VStack(spacing: 16) {
                        liquidGlassProfileHeaderBar

                        VStack(alignment: .leading, spacing: 18) {
                            HStack(spacing: 15) {
                                liquidGlassAvatar(profile: nil, size: 78)

                                VStack(alignment: .leading, spacing: 7) {
                                    Text(LocalizedStringKey("profile_not_logged_in"))
                                        .font(LiquidGlassStyle.titleFont(24, weight: .semibold))
                                        .foregroundStyle(LiquidGlassStyle.ink)

                                    Text(LocalizedStringKey("profile_login_hint"))
                                        .font(LiquidGlassStyle.labelFont(13, weight: .regular))
                                        .foregroundStyle(LiquidGlassStyle.inkSoft)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 0)
                            }

                            Button(action: { navigationPath.append(ProfileNavigationDestination.loginNCM) }) {
                                HStack(spacing: 9) {
                                    MonoIcon(icon: .profileFilled, size: 15, color: LiquidGlassStyle.onAccent, lineWidth: 1.55)
                                    Text(LocalizedStringKey("profile_login_button"))
                                        .font(LiquidGlassStyle.labelFont(15, weight: .semibold))
                                        .foregroundStyle(LiquidGlassStyle.onAccent)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(LiquidGlassPrismBand(tint: LiquidGlassStyle.accent, cornerRadius: 18))
                            }
                            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
                        }
                        .padding(16)
                        .background(LiquidGlassSurfaceBackground(cornerRadius: 28, elevated: true, role: .chrome))
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

                        menuList
                            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    }
                    .padding(.bottom, 140)
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
                )
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .profileNavigationDestinations()
        }
    }

}

private struct SignalGuestIdentityPanel: View {
    let login: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    guestAvatar
                    guestCopy
                }
            } else {
                HStack(spacing: 15) {
                    guestAvatar
                    guestCopy
                    Spacer(minLength: 0)
                }
            }

            Button(action: login) {
                HStack(spacing: 10) {
                    Text(LocalizedStringKey("profile_login_button"))
                        .font(SignalStyle.labelFont(15, weight: .semibold))

                    Spacer(minLength: 8)

                    MonoIcon(
                        icon: .chevronRight,
                        size: 13,
                        color: SignalStyle.onAccent,
                        lineWidth: 1.8,
                        forceTemplateRendering: true
                    )
                }
                .foregroundStyle(SignalStyle.onAccent)
                .padding(.horizontal, 17)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    RoundedRectangle(cornerRadius: SignalStyle.buttonRadius, style: .continuous)
                        .fill(SignalStyle.accent)
                )
                .contentShape(RoundedRectangle(cornerRadius: SignalStyle.buttonRadius, style: .continuous))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
        }
        .padding(.vertical, 18)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(SignalStyle.separator.opacity(0.68))
                .frame(height: 0.65)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SignalStyle.separator.opacity(0.5))
                .frame(height: 0.65)
        }
    }

    private var guestAvatar: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: SignalStyle.cardRadius, style: .continuous)
                .fill(SignalStyle.screen)
                .frame(width: 64, height: 64)
                .overlay {
                    RoundedRectangle(cornerRadius: SignalStyle.cardRadius, style: .continuous)
                        .stroke(SignalStyle.separator.opacity(0.72), lineWidth: 0.7)
                }
                .overlay {
                    MonoIcon(
                        icon: .profile,
                        size: 23,
                        color: SignalStyle.inkSoft,
                        lineWidth: 1.6,
                        forceTemplateRendering: true
                    )
                }

            SignalBreathingIndicator(size: 7)
                .padding(7)
        }
        .accessibilityHidden(true)
    }

    private var guestCopy: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(LocalizedStringKey("profile_not_logged_in"))
                .font(SignalStyle.titleFont(23, weight: .semibold))
                .foregroundStyle(SignalStyle.ink)

            Text(LocalizedStringKey("profile_login_hint"))
                .font(SignalStyle.bodyFont(13, weight: .regular))
                .foregroundStyle(SignalStyle.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SignalGuestMenuRow: View {
    let icon: MonoIcon.IconType
    let title: String
    var trailingText: String? = nil

    var body: some View {
        HStack(spacing: 13) {
            MonoIcon(
                icon: icon,
                size: 16,
                color: SignalStyle.inkSoft,
                lineWidth: 1.6,
                forceTemplateRendering: true
            )
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)

            Text(title)
                .font(SignalStyle.bodyFont(15, weight: .medium))
                .foregroundStyle(SignalStyle.ink)
                .lineLimit(2)

            Spacer(minLength: 8)

            if let trailingText {
                Text(trailingText)
                    .font(SignalStyle.labelFont(12, weight: .medium))
                    .foregroundStyle(SignalStyle.inkMuted)
                    .lineLimit(1)
            }

            MonoIcon(
                icon: .chevronRight,
                size: 12,
                color: SignalStyle.inkMuted,
                lineWidth: 1.7,
                forceTemplateRendering: true
            )
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
