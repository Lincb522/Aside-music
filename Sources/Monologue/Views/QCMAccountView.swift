// QQAccountView.swift
// qcm账号管理界面

import SwiftUI
import QQMusicKit

struct QQAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = SettingsManager.shared

    @State private var isLoggedIn = false
    @State private var musicId: Int?
    @State private var loginType: Int?
    @State private var isChecking = true
    @State private var showQQLogin = false
    @State private var appearAnimation = false

    // 真实账号信息
    @State private var nickname: String?
    @State private var avatarURL: String?
    @State private var isSVIP = false
    @State private var isVIP = false

    private var qqClient: QQMusicClient { APIService.shared.qqClient }

    private var themeAccent: Color {
        if MangaStyle.isActive { return MangaStyle.labelYellow }
        if MujiStyle.isActive { return MujiStyle.clay }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        return MusicSource.qqmusic.themedBadgeColor
    }

    private var themeAccentText: Color {
        if MangaStyle.isActive { return ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.ink, dark: MangaStyle.onStrokeInk) }
        if MujiStyle.isActive { return MujiStyle.paper }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        if NeumorphicStyle.isActive { return Color(light: .white, dark: .black) }
        return .white
    }

    private var themeText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return .monologueTextPrimary
    }

    private var themeSecondaryText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        return .monologueTextSecondary
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedPageBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        if isChecking {
                            loadingView
                        } else if isLoggedIn {
                            loggedInContent
                        } else {
                            notLoggedInContent
                        }
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 32)
                    .padding(.bottom, 120)
                    .iPadContentWidth(600)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
        }
        .themedNavigationChrome(title: String(localized: "qq_account_title"), eyebrow: "QCM", icon: .personCircle)
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { MonologueIcon(icon: .xmark, size: 16) }
            }
        }
        .task {
            await checkStatus()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appearAnimation = true
            }
        }
        .monologueSheet(isPresented: $showQQLogin, preset: .large) {
            NavigationStack {
                QQLoginView()

            }
        }
        .onChange(of: showQQLogin) { _, showing in
            if !showing {
                Task { await checkStatus() }
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.monologueGlassTint)
                    .frame(width: 80, height: 80)
                ProgressView()
                    .scaleEffect(1.3)
            }
            Text(LocalizedStringKey("qq_checking_status"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(themeSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - 已登录

    private var loggedInContent: some View {
        VStack(spacing: 24) {
            heroCard
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)

            detailCards
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 30)

            expiryTip
                .opacity(appearAnimation ? 1 : 0)

            actionButtons
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 15)
        }
    }

    private var heroCard: some View {
        VStack(spacing: 20) {
            // 头像
            ZStack {
                Circle()
                    .stroke(themeAccent.opacity(0.24), lineWidth: MangaStyle.isActive ? 2.4 : 2)
                    .frame(width: 108, height: 108)

                if let urlStr = avatarURL, let url = URL(string: urlStr) {
                    CachedAsyncImage(url: url) {
                        avatarPlaceholder
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 92, height: 92)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                } else {
                    avatarPlaceholder
                }
            }

            VStack(spacing: 10) {
                // 昵称
                HStack(spacing: 8) {
                    Text(nickname ?? NSLocalizedString("qq_user_default", comment: ""))
                        .font(accountTitleFont)
                        .foregroundColor(themeText)
                        .lineLimit(1)

                    // VIP 徽章
                    if isSVIP {
                        Text("SVIP")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "FF6B6B"), Color(hex: "FFB347")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    } else if isVIP {
                        Text("VIP")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.monologueAccentGreen)
                            .clipShape(Capsule())
                    }
                }

                // 状态标签
                HStack(spacing: 6) {
                    Circle()
                        .fill(themeAccent)
                        .frame(width: 7, height: 7)
                    Text(LocalizedStringKey("qq_connected"))
                        .font(accountLabelFont(13, weight: .semibold))
                        .foregroundColor(themeAccent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(themeAccent.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .themedPageSurface(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius + 4 : 20, elevated: true, mangaTint: MangaStyle.bubbleWhite)
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(SequoiaStyle.isActive ? SequoiaStyle.materialPressed : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint))
                .frame(width: 92, height: 92)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)

            ZStack {
                MonologueIcon(icon: .musicNote, size: 24, color: .monologueIconForeground)
            }
            .frame(width: 52, height: 52)
            .monologueGlassCircle()
        }
    }

    private var detailCards: some View {
        VStack(spacing: 0) {
            detailRow(
                icon: .sparkle,
                title: NSLocalizedString("qq_vip_status", comment: ""),
                trailing: AnyView(
                    Text(isSVIP ? NSLocalizedString("qq_svip", comment: "") : isVIP ? NSLocalizedString("qq_vip", comment: "") : NSLocalizedString("qq_normal_user", comment: ""))
                        .font(accountLabelFont(14))
                        .foregroundColor(isSVIP || isVIP ? .monologueOrange : themeSecondaryText)
                )
            )
        }
        .themedPageSurface(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius + 2 : 18, elevated: true, mangaTint: MangaStyle.bubbleWhite)
    }

    private func detailRow(icon: MonologueIcon.IconType, title: String, trailing: AnyView) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(themeAccent.opacity(0.1))
                    .frame(width: 32, height: 32)
                MonologueIcon(icon: icon, size: 15, color: themeSecondaryText)
            }

            Text(title)
                .font(accountBodyFont(15))
                .foregroundColor(themeText)

            Spacer()

            trailing
        }
        .padding(.horizontal, DeviceLayout.isPad ? 20 : 16)
        .padding(.vertical, 14)
    }


    private var expiryTip: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.monologueOrangeLight)
                    .frame(width: 28, height: 28)
                MonologueIcon(icon: .clock, size: 13, color: .monologueOrange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("qq_expiry_title"))
                    .font(accountLabelFont(13, weight: .semibold))
                    .foregroundColor(themeText)
                Text(LocalizedStringKey("qq_expiry_desc"))
                    .font(accountLabelFont(11, weight: .regular))
                    .foregroundColor(themeSecondaryText)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.monologueOrange.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.monologueOrange.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { showQQLogin = true }) {
                HStack(spacing: 8) {
                    MonologueIcon(icon: .refresh, size: 15, color: themeAccentText)
                    Text(LocalizedStringKey("qq_relogin"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundColor(themeAccentText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(themeAccent)
                .clipShape(RoundedRectangle(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius + 2 : 14, style: .continuous))
                .overlay {
                    if MangaStyle.isActive {
                        RoundedRectangle(cornerRadius: MangaStyle.cardRadius + 2, style: .continuous)
                            .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                    }
                }
            }
            .buttonStyle(MonologueBouncingButtonStyle())
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button(action: {
                AlertManager.shared.show(
                    title: NSLocalizedString("qq_logout_title", comment: ""),
                    message: NSLocalizedString("qq_logout_message", comment: ""),
                    primaryButtonTitle: NSLocalizedString("alert_logout_confirm", comment: ""),
                    secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                    primaryAction: {
                        Task { await performLogout() }
                    }
                )
            }) {
                Text(LocalizedStringKey("qq_logout"))
                    .font(accountLabelFont(14))
                    .foregroundColor(themeSecondaryText.opacity(0.62))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .monologueGlass(cornerRadius: 14)
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
            .padding(.top, 4)
        }
    }

    // MARK: - 未登录

    private var notLoggedInContent: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)

            ZStack {
                RoundedRectangle(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius + 4 : 36, style: .continuous)
                    .fill(accountHeroFill)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 8)
                    .overlay {
                        if MangaStyle.isActive {
                            RoundedRectangle(cornerRadius: MangaStyle.cardRadius + 4, style: .continuous)
                                .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                        }
                    }

                ZStack {
                    Circle()
                        .fill(SequoiaStyle.isActive ? SequoiaStyle.materialPressed : Color.monologueSeparator)
                        .frame(width: 64, height: 64)
                    MonologueIcon(icon: .musicNote, size: 28, color: themeSecondaryText.opacity(0.5))
                }
            }
            .opacity(appearAnimation ? 1 : 0)
            .scaleEffect(appearAnimation ? 1 : 0.8)

            Spacer().frame(height: 28)

            VStack(spacing: 10) {
                Text(LocalizedStringKey("qq_not_logged_in"))
                    .font(accountTitleFont)
                    .foregroundColor(themeText)

                Text(LocalizedStringKey("qq_not_logged_desc"))
                    .font(accountBodyFont(14))
                    .foregroundColor(themeSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .opacity(appearAnimation ? 1 : 0)
            .offset(y: appearAnimation ? 0 : 15)

            Spacer().frame(height: 36)

            Button(action: { showQQLogin = true }) {
                HStack(spacing: 10) {
                    MonologueIcon(icon: .qr, size: 18, color: themeAccentText)
                    Text(LocalizedStringKey("qq_login_action"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(themeAccentText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(themeAccent)
                .clipShape(RoundedRectangle(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius + 2 : 20, style: .continuous))
            }
            .buttonStyle(MonologueBouncingButtonStyle())
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(appearAnimation ? 1 : 0)
            .offset(y: appearAnimation ? 0 : 20)

            Spacer().frame(height: 32)

            featureList
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 25)
        }
    }

    private var featureList: some View {
        VStack(spacing: 0) {
            featureRow(icon: .search, title: NSLocalizedString("qq_feature_search", comment: ""), subtitle: NSLocalizedString("qq_feature_search_desc", comment: ""))
            Divider().padding(.leading, 56)
            featureRow(icon: .play, title: NSLocalizedString("qq_feature_play", comment: ""), subtitle: NSLocalizedString("qq_feature_play_desc", comment: ""))
            Divider().padding(.leading, 56)
            featureRow(icon: .translate, title: NSLocalizedString("qq_feature_lyrics", comment: ""), subtitle: NSLocalizedString("qq_feature_lyrics_desc", comment: ""))
        }
        .themedPageSurface(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius + 2 : 18, elevated: true, mangaTint: MangaStyle.bubbleWhite)
    }

    private var accountTitleFont: Font {
        if MangaStyle.isActive { return MangaStyle.titleFont(23, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.titleFont(22, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.titleFont(22, weight: .semibold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(22, weight: .semibold) }
        return .system(size: 22, weight: .bold, design: .rounded)
    }

    private var accountHeroFill: Color {
        if MangaStyle.isActive { return MangaStyle.bubbleBlue }
        if MujiStyle.isActive { return MujiStyle.surfaceRaised }
        if SequoiaStyle.isActive { return SequoiaStyle.materialRaised }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
        return Color.monologueGlassTint
    }

    private func accountBodyFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        if SequoiaStyle.isActive { return SequoiaStyle.bodyFont(size, weight: weight) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.bodyFont(size, weight: weight) }
        return .system(size: size, weight: weight, design: .rounded)
    }

    private func accountLabelFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(size, weight: weight) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(size, weight: weight) }
        return .system(size: size, weight: weight, design: .rounded)
    }

    private func featureRow(icon: MonologueIcon.IconType, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(themeAccent.opacity(0.1))
                    .frame(width: 32, height: 32)
                MonologueIcon(icon: icon, size: 15, color: themeSecondaryText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(accountBodyFont(15))
                    .foregroundColor(themeText)
                Text(subtitle)
                    .font(accountLabelFont(12, weight: .regular))
                    .foregroundColor(themeSecondaryText)
            }

            Spacer()
        }
        .padding(.horizontal, DeviceLayout.isPad ? 20 : 16)
        .padding(.vertical, 13)
    }

    // MARK: - Actions

    private var userSession: QQUserSession { QQUserSession.shared }

    private func checkStatus() async {
        isChecking = true
        await userSession.refresh()
        isLoggedIn = userSession.isLoggedIn
        musicId = userSession.musicId

        if isLoggedIn {
            do {
                let status = try await userSession.withUserSession { client in
                    try await client.authStatus()
                }
                loginType = status.loginType
                nickname = status.nickname
                avatarURL = status.avatar
                isSVIP = (status.isSvip ?? 0) == 1
                isVIP = isSVIP || (status.isVip ?? 0) == 1
                AppLogger.info("[QQAccount] authStatus: nickname=\(nickname ?? "nil"), avatar=\(avatarURL.map { String($0.prefix(50)) } ?? "nil"), svip=\(isSVIP)")

                if (nickname == nil || nickname?.isEmpty == true), let mid = musicId {
                    await fetchUserInfoFallback(musicid: mid)
                }

                if isVIP || isSVIP {
                    await QQUserSession.shared.refreshVIPStatus()
                }
            } catch {
                AppLogger.error("[QQAccount] authStatus 失败: \(error)")
                if let mid = musicId {
                    await fetchUserInfoFallback(musicid: mid)
                }
            }
        }
        isChecking = false
    }

    private func fetchUserInfoFallback(musicid: Int) async {
        do {
            AppLogger.info("[QQAccount] fallback fetchUserInfo: musicid=\(musicid)")
            let euinResult = try await userSession.withUserSession { client in
                try await client.getEuin(musicid: musicid)
            }
            if let euin = euinResult.stringValue, !euin.isEmpty {
                let homepage = try await userSession.withUserSession { client in
                    try await client.userHomepage(euin: euin)
                }
                // 新版 API: { base_info: { name, avatar }, singer, tab_detail }
                if let baseInfo = homepage["base_info"] ?? homepage["Info"]?["BaseInfo"] {
                    if nickname == nil || nickname?.isEmpty == true {
                        nickname = baseInfo["name"]?.stringValue ?? baseInfo["Name"]?.stringValue
                    }
                    if avatarURL == nil || avatarURL?.isEmpty == true {
                        avatarURL = baseInfo["avatar"]?.stringValue
                            ?? baseInfo["BigAvatar"]?.stringValue
                            ?? baseInfo["Avatar"]?.stringValue
                    }
                }
            }
        } catch {
            AppLogger.warning("[QQAccount] fallback 获取用户信息失败: \(error)")
        }

        if !isVIP && !isSVIP {
            do {
                let status = try await userSession.withUserSession { client in
                    try await client.authStatus()
                }
                isSVIP = (status.isSvip ?? 0) == 1
                isVIP = isSVIP || (status.isVip ?? 0) == 1
            } catch {}
        }
    }

    private func performLogout() async {
        userSession.onLogout()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isLoggedIn = false
            musicId = nil
            loginType = nil
            nickname = nil
            avatarURL = nil
            isSVIP = false
            isVIP = false
        }
    }
}
