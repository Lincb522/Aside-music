// QQAccountView.swift
// qcm账号管理界面

import SwiftUI
import QQMusicKit

struct QQAccountView: View {
    @Environment(\.dismiss) private var dismiss
    
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
    
    var body: some View {
        ZStack {
            MonologueBackground()
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
            }
        }
        .navigationTitle("qq_account_title")
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
        .sheet(isPresented: $showQQLogin) {
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
                .foregroundColor(.monologueTextSecondary)
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
                    .stroke(Color.monologueAccentGreen.opacity(0.15), lineWidth: 2)
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
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)
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
                        .fill(Color.monologueAccentGreen)
                        .frame(width: 7, height: 7)
                    Text(LocalizedStringKey("qq_connected"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.monologueAccentGreen)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.monologueAccentGreen.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .monologueGlass(cornerRadius: 24)
    }
    
    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.monologueGlassTint)
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
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(isSVIP || isVIP ? .monologueOrange : .monologueTextSecondary)
                )
            )
        }
        .monologueGlass(cornerRadius: 18)
    }
    
    private func detailRow(icon: MonologueIcon.IconType, title: String, trailing: AnyView) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.monologueIconBackground.opacity(0.08))
                    .frame(width: 32, height: 32)
                MonologueIcon(icon: icon, size: 15, color: .monologueTextSecondary)
            }
            
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.monologueTextPrimary)
            
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
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                Text(LocalizedStringKey("qq_expiry_desc"))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
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
                    MonologueIcon(icon: .refresh, size: 15, color: .monologueTextPrimary)
                    Text(LocalizedStringKey("qq_relogin"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundColor(.monologueTextPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .monologueGlass(cornerRadius: 14)
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
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary.opacity(0.5))
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
                Circle()
                    .fill(Color.monologueGlassTint)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 8)
                
                ZStack {
                    Circle()
                        .fill(Color.monologueSeparator)
                        .frame(width: 64, height: 64)
                    MonologueIcon(icon: .musicNote, size: 28, color: .monologueTextSecondary.opacity(0.4))
                }
            }
            .opacity(appearAnimation ? 1 : 0)
            .scaleEffect(appearAnimation ? 1 : 0.8)
            
            Spacer().frame(height: 28)
            
            VStack(spacing: 10) {
                Text(LocalizedStringKey("qq_not_logged_in"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                
                Text(LocalizedStringKey("qq_not_logged_desc"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .opacity(appearAnimation ? 1 : 0)
            .offset(y: appearAnimation ? 0 : 15)
            
            Spacer().frame(height: 36)
            
            Button(action: { showQQLogin = true }) {
                HStack(spacing: 10) {
                    MonologueIcon(icon: .qr, size: 18, color: .monologueTextPrimary)
                    Text(LocalizedStringKey("qq_login_action"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(.monologueTextPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .monologueGlass(cornerRadius: 20)
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
        .monologueGlass(cornerRadius: 18)
    }
    
    private func featureRow(icon: MonologueIcon.IconType, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.monologueIconBackground.opacity(0.08))
                    .frame(width: 32, height: 32)
                MonologueIcon(icon: icon, size: 15, color: .monologueTextSecondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
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
                if let baseInfo = homepage["Info"]?["BaseInfo"] {
                    if nickname == nil || nickname?.isEmpty == true {
                        nickname = baseInfo["Name"]?.stringValue
                    }
                    if avatarURL == nil || avatarURL?.isEmpty == true {
                        avatarURL = baseInfo["BigAvatar"]?.stringValue ?? baseInfo["Avatar"]?.stringValue
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
