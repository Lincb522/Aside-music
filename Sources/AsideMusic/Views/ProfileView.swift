import SwiftUI
import Combine

struct ProfileView: View {
    private var viewModel: HomeViewModel { HomeViewModel.shared }
    @AppStorage("isLoggedIn") private var isAppLoggedIn = false
    
    @State private var showLoginView = false
    @State private var showSettingsView = false
    @State private var showDownloadManage = false
    @State private var showStorageManage = false
    @State private var showCloudDisk = false
    @State private var cachedProfile: UserProfile?
    @State private var hasAppeared = false
    
    // 用户详情数据（等级、听歌数、注册天数）
    @State private var userLevel: Int?
    @State private var listenSongs: Int?
    @State private var createDays: Int?
    
    // 最近播放
    @State private var recentSongs: [Song] = []
    @State private var showAllRecentSongs = false
    
    @ObservedObject private var playerManager = PlayerManager.shared
    @ObservedObject private var downloadManager = DownloadManager.shared
    
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
                if let profile = viewModel.userProfile, profile.userId != cachedProfile?.userId {
                    cachedProfile = profile
                }
                guard !hasAppeared else {
                    GlobalRefreshManager.shared.markProfileDataReady()
                    return
                }
                hasAppeared = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    cachedProfile = viewModel.userProfile
                    GlobalRefreshManager.shared.markProfileDataReady()
                    fetchUserExtra()
                    fetchRecentSongs()
                }
            } else {
                GlobalRefreshManager.shared.markProfileDataReady()
            }
        }
        .onReceive(GlobalRefreshManager.shared.refreshProfilePublisher) { _ in
            if isAppLoggedIn {
                cachedProfile = viewModel.userProfile
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                GlobalRefreshManager.shared.markProfileDataReady()
            }
        }
        .onReceive(viewModel.$userProfile) { profile in
            if profile != nil {
                cachedProfile = profile
            }
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
        .fullScreenCover(isPresented: $showStorageManage) {
            NavigationStack {
                StorageManageView()
            }
        }
        .fullScreenCover(isPresented: $showCloudDisk) {
            NavigationStack {
                CloudDiskView()
            }
        }
    }

    // MARK: - 已登录
    
    private var loggedInContent: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // 用户卡片
                    profileCard
                        .padding(.horizontal, 20)
                    
                    // 听歌数据概览
                    listeningStatsSection
                        .padding(.horizontal, 20)
                    
                    // 最近播放
                    if !recentSongs.isEmpty {
                        recentlyPlayedSection
                    }
                    
                    // 快捷操作
                    quickActions
                        .padding(.horizontal, 20)
                    
                    // 退出登录
                    logoutButton
                    
                    Color.clear.frame(height: 100)
                }
                .padding(.top, DeviceLayout.headerTopPadding + 100)
            }
            .navigationBarHidden(true)
            .background(Color.clear)
        }
    }
    
    // MARK: - 用户卡片
    
    private var profileCard: some View {
        let profile = cachedProfile ?? viewModel.userProfile
        
        return HStack(spacing: 16) {
            // 头像
            if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url) {
                    Color.asideSeparator
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.asideSeparator)
                    .frame(width: 72, height: 72)
                    .overlay(
                        AsideIcon(icon: .profile, size: 30, color: .asideTextSecondary.opacity(0.5))
                    )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)
                    
                    // 等级徽章
                    if let level = userLevel {
                        Text("Lv.\(level)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.asideIconForeground)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.asideIconBackground)
                            .clipShape(Capsule())
                    }
                }
                
                if let signature = profile?.signature, !signature.isEmpty {
                    Text(signature)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                } else {
                    Text("编辑个性签名")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.asideTextSecondary.opacity(0.5))
                }
                
                // 注册天数
                if let days = createDays {
                    Text("已陪伴你 \(days) 天")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary.opacity(0.6))
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color.asideCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    // MARK: - 听歌数据概览
    
    private var listeningStatsSection: some View {
        let profile = cachedProfile ?? viewModel.userProfile
        
        return HStack(spacing: 12) {
            StatCard(
                value: formatNumber(listenSongs ?? 0),
                label: "累计听歌",
                icon: .headphones
            )
            
            StatCard(
                value: "\(profile?.follows ?? 0)",
                label: NSLocalizedString("profile_following", comment: ""),
                icon: .personCircle
            )
            
            StatCard(
                value: "\(profile?.followeds ?? 0)",
                label: NSLocalizedString("profile_followers", comment: ""),
                icon: .liked
            )
            
            StatCard(
                value: "\(profile?.eventCount ?? 0)",
                label: NSLocalizedString("profile_dynamic", comment: ""),
                icon: .send
            )
        }
    }
    
    // MARK: - 最近播放
    
    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("最近播放")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                
                Spacer()
                
                NavigationLink(destination: RecentPlayHistoryView(songs: recentSongs)) {
                    HStack(spacing: 4) {
                        Text("\(recentSongs.count) 首")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                        AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(recentSongs.prefix(15)) { song in
                        Button(action: {
                            playerManager.play(song: song, in: recentSongs)
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                CachedAsyncImage(url: song.coverUrl) {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.asideSeparator)
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.name)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(.asideTextPrimary)
                                        .lineLimit(1)
                                    
                                    Text(song.artistName)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(.asideTextSecondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 110, alignment: .leading)
                            }
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - 快捷操作
    
    private var quickActions: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        
        return LazyVGrid(columns: columns, spacing: 12) {
            QuickActionCard(
                icon: .download,
                title: NSLocalizedString("profile_downloads", comment: ""),
                subtitle: "\(downloadManager.downloadedSongIds.count) 首"
            ) {
                showDownloadManage = true
            }
            
            QuickActionCard(
                icon: .storage,
                title: "缓存管理",
                subtitle: "管理本地缓存"
            ) {
                showStorageManage = true
            }
            
            QuickActionCard(
                icon: .cloud,
                title: NSLocalizedString("profile_cloud_disk", comment: "Cloud Disk"),
                subtitle: "云端存储"
            ) {
                showCloudDisk = true
            }
            
            QuickActionCard(
                icon: .settings,
                title: NSLocalizedString("profile_settings", comment: ""),
                subtitle: "偏好与账号"
            ) {
                showSettingsView = true
            }
        }
    }
    
    // MARK: - 退出登录
    
    private var logoutButton: some View {
        Button(action: {
            AlertManager.shared.show(
                title: NSLocalizedString("alert_logout_title", comment: ""),
                message: NSLocalizedString("alert_logout_message", comment: ""),
                primaryButtonTitle: NSLocalizedString("alert_logout_confirm", comment: ""),
                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: "")
            ) {
                Task { @MainActor in
                    do {
                        _ = try await APIService.shared.logout().async()
                    } catch {
                        APIService.shared.currentCookie = nil
                        OptimizedCacheManager.shared.clearAll()
                    }
                    isAppLoggedIn = false
                    cachedProfile = nil
                    hasAppeared = false
                    userLevel = nil
                    listenSongs = nil
                    createDays = nil
                    recentSongs = []
                    AlertManager.shared.dismiss()
                }
            }
        }) {
            Text(LocalizedStringKey("action_logout"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
        .padding(.horizontal, 20)
    }
    
    // MARK: - 未登录
    
    private var notLoggedInContent: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(Color.asideCardBackground)
                        .frame(width: 100, height: 100)
                    
                    AsideIcon(icon: .profile, size: 40, color: .asideTextSecondary.opacity(0.3))
                }
                
                VStack(spacing: 10) {
                    Text("未登录")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    
                    Text("登录后享受完整功能")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }
                
                Button(action: { showLoginView = true }) {
                    Text("登录账号")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.asideIconForeground)
                        .frame(width: 200)
                        .padding(.vertical, 15)
                        .background(Color.asideIconBackground)
                        .clipShape(Capsule())
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
            
            Spacer()
            
            VStack(spacing: 0) {
                ProfileMenuItem(
                    icon: .settings,
                    title: NSLocalizedString("profile_settings", comment: ""),
                    trailing: .chevron
                ) {
                    showSettingsView = true
                }
            }
            .background(Color.asideCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.bottom, 140)
        }
    }
    
    // MARK: - 数据获取
    
    private func fetchUserExtra() {
        guard let uid = APIService.shared.currentUserId else { return }
        APIService.shared.fetchUserDetail(uid: uid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [self] response in
                userLevel = response.level
                listenSongs = response.listenSongs
                createDays = response.createDays
            })
            .store(in: &ProfileCancellableStore.shared.cancellables)
    }
    
    // MARK: - 工具方法
    
    private func fetchRecentSongs() {
        // 先从本地 SwiftData 获取播放历史
        let localHistory = HistoryRepository().getPlayHistory(limit: 100)
        let localSongs = localHistory.map { $0.toSong() }
        
        // 再从网易云获取最近播放，合并去重
        APIService.shared.fetchRecentSongs()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [self] remoteSongs in
                // 合并：本地优先（更新），远程补充
                var merged: [Song] = []
                var seenIds = Set<Int>()
                
                // 先加本地历史（最新的在前）
                for song in localSongs {
                    if !seenIds.contains(song.id) {
                        seenIds.insert(song.id)
                        merged.append(song)
                    }
                }
                
                // 再加远程历史（去重）
                for song in remoteSongs {
                    if !seenIds.contains(song.id) {
                        seenIds.insert(song.id)
                        merged.append(song)
                    }
                }
                
                self.recentSongs = merged
            })
            .store(in: &ProfileCancellableStore.shared.cancellables)
    }
    
    private func formatNumber(_ value: Int) -> String {
        if value >= 10000 {
            return String(format: "%.1fw", Double(value) / 10000)
        }
        return "\(value)"
    }
}

// MARK: - Cancellable 存储（避免 struct 中持有 Set<AnyCancellable>）

private class ProfileCancellableStore {
    static let shared = ProfileCancellableStore()
    var cancellables = Set<AnyCancellable>()
}

// MARK: - 统计卡片

struct StatCard: View {
    let value: String
    let label: String
    let icon: AsideIcon.IconType
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
            
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.asideCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - 快捷操作卡片

struct QuickActionCard: View {
    let icon: AsideIcon.IconType
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { action?() }) {
            VStack(alignment: .leading, spacing: 12) {
                AsideIcon(icon: icon, size: 22, color: .asideTextPrimary)
                
                Spacer(minLength: 0)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .frame(height: 100)
            .background(Color.asideCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.97))
    }
}

// MARK: - 菜单项组件

struct ProfileMenuItem: View {
    let icon: AsideIcon.IconType
    let title: String
    var trailing: TrailingType = .chevron
    var action: (() -> Void)? = nil
    
    enum TrailingType {
        case chevron
        case text(String)
    }
    
    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 14) {
                AsideIcon(icon: icon, size: 20, color: .asideTextPrimary)
                    .frame(width: 28, height: 28)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                
                Spacer()
                
                switch trailing {
                case .chevron:
                    AsideIcon(icon: .chevronRight, size: 14, color: .asideTextSecondary.opacity(0.5))
                case .text(let value):
                    Text(value)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                    AsideIcon(icon: .chevronRight, size: 14, color: .asideTextSecondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
    }
}
