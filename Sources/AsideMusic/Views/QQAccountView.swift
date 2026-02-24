// QQAccountView.swift
// QQ 音乐账号管理界面

import SwiftUI
import QQMusicKit

struct QQAccountView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoggedIn = false
    @State private var musicId: Int?
    @State private var loginType: Int?
    @State private var isChecking = true
    @State private var showQQLogin = false
    @State private var showLogoutConfirm = false
    @State private var appearAnimation = false
    
    // 真实账号信息
    @State private var nickname: String?
    @State private var avatarURL: String?
    @State private var isSVIP = false
    @State private var isVIP = false
    
    private var qqClient: QQMusicClient { APIService.shared.qqClient }
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        if isChecking {
                            loadingView
                        } else if isLoggedIn {
                            loggedInContent
                        } else {
                            notLoggedInContent
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    .padding(.bottom, 120)
                }
            }
        }
        .navigationBarHidden(true)
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
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.asideCardBackground)
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                    AsideIcon(icon: .back, size: 16, color: .asideTextPrimary)
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())
            .contentShape(Circle())
            
            Spacer()
            
            Text(LocalizedStringKey("qq_account_title"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
            
            Spacer()
            
            Circle()
                .fill(Color.clear)
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, DeviceLayout.headerTopPadding)
        .padding(.bottom, 8)
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.asideCardBackground)
                    .frame(width: 80, height: 80)
                ProgressView()
                    .scaleEffect(1.3)
            }
            Text(LocalizedStringKey("qq_checking_status"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary)
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
                    .stroke(Color.asideAccentGreen.opacity(0.15), lineWidth: 2)
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
                        .foregroundColor(.asideTextPrimary)
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
                            .background(Color.asideAccentGreen)
                            .clipShape(Capsule())
                    }
                }
                
                // 状态标签
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.asideAccentGreen)
                        .frame(width: 7, height: 7)
                    Text(LocalizedStringKey("qq_connected"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.asideAccentGreen)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.asideAccentGreen.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.asideCardBackground)
                .frame(width: 92, height: 92)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
            
            ZStack {
                Circle()
                    .fill(.clear)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular, in: .circle)
                AsideIcon(icon: .musicNote, size: 24, color: .asideIconForeground)
            }
        }
    }
    
    private var detailCards: some View {
        VStack(spacing: 0) {
            detailRow(
                icon: .profile,
                title: NSLocalizedString("qq_login_method", comment: ""),
                trailing: AnyView(
                    Text(loginTypeText)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                )
            )
            
            if let mid = musicId {
                Divider().padding(.leading, 56)
                
                detailRow(
                    icon: .musicNote,
                    title: "Music ID",
                    trailing: AnyView(
                        Text("\(mid)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.asideTextSecondary)
                    )
                )
            }
            
            Divider().padding(.leading, 56)
            
            detailRow(
                icon: .sparkle,
                title: NSLocalizedString("qq_vip_status", comment: ""),
                trailing: AnyView(
                    Text(isSVIP ? NSLocalizedString("qq_svip", comment: "") : isVIP ? NSLocalizedString("qq_vip", comment: "") : NSLocalizedString("qq_normal_user", comment: ""))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(isSVIP || isVIP ? .asideOrange : .asideTextSecondary)
                )
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    private func detailRow(icon: AsideIcon.IconType, title: String, trailing: AnyView) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.asideIconBackground.opacity(0.08))
                    .frame(width: 32, height: 32)
                AsideIcon(icon: icon, size: 15, color: .asideTextSecondary)
            }
            
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextPrimary)
            
            Spacer()
            
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private var loginTypeText: String {
        switch loginType {
        case 1: return NSLocalizedString("qq_login_qq_scan", comment: "")
        case 2: return NSLocalizedString("qq_login_wx_scan", comment: "")
        case 3: return NSLocalizedString("qq_login_phone_code", comment: "")
        default: return NSLocalizedString("qq_login_unknown", comment: "")
        }
    }
    
    private var expiryTip: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.asideOrangeLight)
                    .frame(width: 28, height: 28)
                AsideIcon(icon: .clock, size: 13, color: .asideOrange)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("qq_expiry_title"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                Text(LocalizedStringKey("qq_expiry_desc"))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }
            
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.asideOrange.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.asideOrange.opacity(0.12), lineWidth: 1)
                )
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { showQQLogin = true }) {
                HStack(spacing: 8) {
                    AsideIcon(icon: .refresh, size: 15, color: .asideIconForeground)
                    Text(LocalizedStringKey("qq_relogin"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundColor(.asideIconForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 14))
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(AsideBouncingButtonStyle())
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            
            Button(action: { showLogoutConfirm = true }) {
                Text(LocalizedStringKey("qq_logout"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary.opacity(0.5))
            }
            .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
            .contentShape(Rectangle())
            .padding(.top, 4)
            .alert(NSLocalizedString("qq_logout_title", comment: ""), isPresented: $showLogoutConfirm) {
                Button(NSLocalizedString("alert_cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("alert_logout_confirm", comment: ""), role: .destructive) {
                    Task { await performLogout() }
                }
            } message: {
                Text(LocalizedStringKey("qq_logout_message"))
            }
        }
    }

    // MARK: - 未登录
    
    private var notLoggedInContent: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)
            
            ZStack {
                Circle()
                    .fill(Color.asideCardBackground)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 8)
                
                ZStack {
                    Circle()
                        .fill(Color.asideSeparator)
                        .frame(width: 64, height: 64)
                    AsideIcon(icon: .musicNote, size: 28, color: .asideTextSecondary.opacity(0.4))
                }
            }
            .opacity(appearAnimation ? 1 : 0)
            .scaleEffect(appearAnimation ? 1 : 0.8)
            
            Spacer().frame(height: 28)
            
            VStack(spacing: 10) {
                Text(LocalizedStringKey("qq_not_logged_in"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                
                Text(LocalizedStringKey("qq_not_logged_desc"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .opacity(appearAnimation ? 1 : 0)
            .offset(y: appearAnimation ? 0 : 15)
            
            Spacer().frame(height: 36)
            
            Button(action: { showQQLogin = true }) {
                HStack(spacing: 10) {
                    AsideIcon(icon: .qr, size: 18, color: .asideIconForeground)
                    Text(LocalizedStringKey("qq_login_action"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(.asideIconForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(AsideBouncingButtonStyle())
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
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    private func featureRow(icon: AsideIcon.IconType, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.asideIconBackground.opacity(0.08))
                    .frame(width: 32, height: 32)
                AsideIcon(icon: icon, size: 15, color: .asideTextSecondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
    
    // MARK: - Actions
    
    private func checkStatus() async {
        isChecking = true
        do {
            let status = try await qqClient.authStatus()
            isLoggedIn = status.loggedIn
            musicId = status.musicid
            loginType = status.loginType
            UserDefaults.standard.set(status.loggedIn, forKey: AppConfig.StorageKeys.qqMusicLoggedIn)
            
            if status.loggedIn, let mid = status.musicid {
                await fetchUserInfo(musicid: mid)
            }
        } catch {
            isLoggedIn = false
        }
        isChecking = false
    }
    
    /// 获取真实账号信息：musicid → euin → userHomepage + vipInfo
    private func fetchUserInfo(musicid: Int) async {
        // 获取 euin
        do {
            let euinResult = try await qqClient.getEuin(musicid: musicid)
            if let euin = euinResult.stringValue, !euin.isEmpty {
                // 获取用户主页信息
                let homepage = try await qqClient.userHomepage(euin: euin)
                if let baseInfo = homepage["Info"]?["BaseInfo"] {
                    nickname = baseInfo["Name"]?.stringValue
                    avatarURL = baseInfo["BigAvatar"]?.stringValue ?? baseInfo["Avatar"]?.stringValue
                }
            }
        } catch {
            AppLogger.warning("[QQMusic] 获取用户信息失败: \(error.localizedDescription)")
        }
        
        // 获取 VIP 信息
        do {
            let vip = try await qqClient.vipInfo()
            isSVIP = vip["svip"]?.intValue == 1
            isVIP = isSVIP || (vip["vip"]?.intValue == 1)
        } catch {
            AppLogger.warning("[QQMusic] 获取 VIP 信息失败: \(error.localizedDescription)")
        }
    }
    
    private func performLogout() async {
        do {
            try await qqClient.logout()
        } catch {}
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isLoggedIn = false
            musicId = nil
            loginType = nil
            nickname = nil
            avatarURL = nil
            isSVIP = false
            isVIP = false
        }
        UserDefaults.standard.set(false, forKey: AppConfig.StorageKeys.qqMusicLoggedIn)
    }
}
