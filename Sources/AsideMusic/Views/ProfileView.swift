import SwiftUI
import Combine

struct ProfileView: View {
    // 直接使用单例，避免 @ObservedObject 的额外开销
    private var viewModel: HomeViewModel { HomeViewModel.shared }
    @AppStorage("isLoggedIn") private var isAppLoggedIn = false
    
    @State private var showLoginView = false
    @State private var showSettingsView = false
    @State private var showDownloadManage = false
    
    // 缓存用户数据，避免频繁访问 viewModel
    @State private var cachedProfile: UserProfile?
    @State private var hasAppeared = false
    
    private let primaryColor = Color.asideTextPrimary
    private let secondaryColor = Color.asideTextSecondary
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            if isAppLoggedIn {
                loggedInContent
            } else {
                notLoggedInContent
            }
        }
        .onAppear {
            if isAppLoggedIn {
                // 每次出现时都尝试同步最新的用户数据
                if let profile = viewModel.userProfile, profile.userId != cachedProfile?.userId {
                    cachedProfile = profile
                }
                
                // 只在首次出现时做完整加载
                guard !hasAppeared else {
                    GlobalRefreshManager.shared.markProfileDataReady()
                    return
                }
                hasAppeared = true
                
                // 延迟加载，让 tab 切换动画先完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // 先从缓存获取用户数据
                    cachedProfile = viewModel.userProfile
                    
                    // 延迟更新缓存大小，避免阻塞
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        updateCacheSizeIfNeeded()
                    }
                    
                    GlobalRefreshManager.shared.markProfileDataReady()
                }
            } else {
                GlobalRefreshManager.shared.markProfileDataReady()
            }
        }
        .onReceive(GlobalRefreshManager.shared.refreshProfilePublisher) { _ in
            if isAppLoggedIn {
                // 刷新时更新缓存的用户数据
                cachedProfile = viewModel.userProfile
                updateCacheSizeIfNeeded()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                GlobalRefreshManager.shared.markProfileDataReady()
            }
        }
        .onReceive(viewModel.$userProfile) { profile in
            // 当 viewModel 的 userProfile 更新时，同步到本地缓存
            if profile != nil {
                cachedProfile = profile
            }
        }
        .actionSheet(isPresented: $showSettingsActionSheet) {
            ActionSheet(
                title: Text(LocalizedStringKey("profile_settings")),
                message: Text("Cache Size: \(cacheSize)"),
                buttons: [
                    .destructive(Text("Clear Cache")) {
                        Task { @MainActor in
                            OptimizedCacheManager.shared.clearAll()
                            // 清除后重置缓存大小显示
                            cacheSize = "..."
                            lastCacheSizeUpdate = nil
                        }
                    },
                    .cancel()
                ]
            )
        }
        .fullScreenCover(isPresented: $showLoginView) {
            LoginView()
        }
        .fullScreenCover(isPresented: $showSettingsView) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showDownloadManage) {
            NavigationStack {
                DownloadManageView()
            }
        }
    }
    
    // MARK: - 已登录内容
    
    private var loggedInContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                headerStatsSection
                    .padding(.top, DeviceLayout.headerTopPadding + 80)
                    .padding(.bottom, 32)
                
                actionGridSection
                
                logoutSection
                
                Spacer(minLength: 120)
            }
        }
    }
    
    // MARK: - 未登录内容
    
    private var notLoggedInContent: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                Circle()
                    .fill(Color.asideCardBackground)
                    .frame(width: 120, height: 120)
                    .overlay(
                        AsideIcon(icon: .profile, size: 50, color: .asideTextPrimary.opacity(0.3))
                    )
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                
                VStack(spacing: 8) {
                    Text("未登录")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(primaryColor)
                    
                    Text("登录后享受完整功能")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(secondaryColor)
                }
                
                Button(action: { showLoginView = true }) {
                    HStack(spacing: 10) {
                        AsideIcon(icon: .profile, size: 18, color: .asideIconForeground)
                        Text("登录账号")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(Color.asideIconBackground)
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
                }
                .buttonStyle(AsideBouncingButtonStyle())
                .padding(.top, 16)
            }
            
            Spacer()
            
            // 底部功能卡片（未登录也可用）
            notLoggedInActionSection
                .padding(.bottom, 120)
        }
    }
    
    // MARK: - 未登录功能区
    
    private var notLoggedInActionSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ActionCard(
                    icon: .settings,
                    title: NSLocalizedString("profile_settings", comment: ""),
                    subtitle: "Settings",
                    action: { showSettingsView = true }
                )
                .frame(width: 140)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .onAppear {
            // 延迟更新缓存大小
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                updateCacheSizeIfNeeded()
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerStatsSection: some View {
        VStack(spacing: 24) {
            // 使用缓存的 profile 数据
            if let avatarUrl = cachedProfile?.avatarUrl ?? viewModel.userProfile?.avatarUrl, 
               let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url) {
                    Color.gray.opacity(0.1)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            } else {
                Circle()
                    .fill(Color.asideCardBackground.opacity(0.5))
                    .frame(width: 120, height: 120)
                    .overlay(
                        AsideIcon(icon: .profile, size: 50, color: .asideTextPrimary.opacity(0.5))
                    )
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            }
            
            // 使用缓存的 profile 数据
            let profile = cachedProfile ?? viewModel.userProfile
            VStack(spacing: 8) {
                Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(primaryColor)
                
                Text(String(format: NSLocalizedString("user_id_format", comment: ""), profile?.userId ?? 0))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(secondaryColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.asideCardBackground.opacity(0.6))
                    .cornerRadius(20)
                
                if let signature = profile?.signature, !signature.isEmpty {
                    Text(signature)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(secondaryColor.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 40)
                }
            }
            
            HStack(spacing: 40) {
                StatItemLarge(count: profile?.eventCount ?? 0, label: NSLocalizedString("profile_dynamic", comment: ""))
                StatItemLarge(count: profile?.follows ?? 0, label: NSLocalizedString("profile_following", comment: ""))
                StatItemLarge(count: profile?.followeds ?? 0, label: NSLocalizedString("profile_followers", comment: ""))
            }
            .padding(.top, 10)
        }
    }
    
    private var actionGridSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ActionCard(
                    icon: .download,
                    title: NSLocalizedString("profile_downloads", comment: ""),
                    subtitle: "Offline Music",
                    action: { showDownloadManage = true }
                )
                .frame(width: 140)
                
                ActionCard(
                    icon: .settings,
                    title: NSLocalizedString("profile_settings", comment: ""),
                    subtitle: "Settings",
                    action: { showSettingsView = true }
                )
                .frame(width: 140)
                
                ActionCard(
                    icon: .cloud,
                    title: NSLocalizedString("profile_cloud_disk", comment: "Cloud Disk"),
                    subtitle: "Personal Cloud"
                )
                .frame(width: 140)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
    
    @State private var showLogoutAlert = false
    @State private var showSettingsActionSheet = false
    @State private var cacheSize: String = "..."
    @State private var lastCacheSizeUpdate: Date?
    
    /// 只在需要时更新缓存大小（避免频繁计算）
    private func updateCacheSizeIfNeeded() {
        // 如果最近 30 秒内已更新，跳过
        if let lastUpdate = lastCacheSizeUpdate,
           Date().timeIntervalSince(lastUpdate) < 30 {
            return
        }
        
        // 在低优先级后台线程计算
        Task { @MainActor in
            let size = OptimizedCacheManager.shared.getCacheSize()
            self.cacheSize = size
            self.lastCacheSizeUpdate = Date()
        }
    }

    private var logoutSection: some View {
        Button(action: {
            AlertManager.shared.show(
                title: NSLocalizedString("alert_logout_title", comment: ""),
                message: NSLocalizedString("alert_logout_message", comment: ""),
                primaryButtonTitle: NSLocalizedString("alert_logout_confirm", comment: ""),
                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: "")
            ) {
                Task { @MainActor in
                    // 调用 logout API，无论成功失败都清理本地状态
                    do {
                        _ = try await APIService.shared.logout()
                            .async()
                    } catch {
                        // API 调用失败，手动清理本地状态
                        UserDefaults.standard.removeObject(forKey: "aside_music_cookie")
                        UserDefaults.standard.removeObject(forKey: "aside_music_uid")
                        UserDefaults.standard.set(false, forKey: "isLoggedIn")
                        APIService.shared.currentCookie = nil
                        OptimizedCacheManager.shared.clearAll()
                    }
                    isAppLoggedIn = false
                    cachedProfile = nil
                    hasAppeared = false
                    AlertManager.shared.dismiss()
                }
            }
        }) {
            Text(LocalizedStringKey("action_logout"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary.opacity(0.6))
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .stroke(Color.asideSeparator, lineWidth: 1)
                )
        }
        .padding(.top, 20)
    }
}

// MARK: - Components

struct StatItemLarge: View {
    let count: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary)
        }
    }
}

struct ActionCard: View {
    let icon: AsideIcon.IconType
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { action?() }) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.asideIconBackground)
                        .frame(width: 44, height: 44)
                    AsideIcon(icon: icon, size: 18, color: .asideIconForeground)
                }
                
                Spacer()
                
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .padding(16)
            .background(Color.asideCardBackground)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.96))
    }
}
