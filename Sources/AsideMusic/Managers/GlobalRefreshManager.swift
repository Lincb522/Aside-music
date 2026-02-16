import Foundation
import Combine
import SwiftUI

/// 全局刷新管理器
/// 统一管理数据刷新逻辑，确保基于时间和登录事件的智能更新
@MainActor
class GlobalRefreshManager: ObservableObject {
    static let shared = GlobalRefreshManager()
    
    // MARK: - Publishers
    let refreshHomePublisher = PassthroughSubject<Bool, Never>()
    let refreshLibraryPublisher = PassthroughSubject<Bool, Never>()
    let refreshProfilePublisher = PassthroughSubject<Bool, Never>()
    
    // MARK: - 数据加载状态
    @Published var isHomeDataReady = false
    @Published var isLibraryDataReady = false
    @Published var isProfileDataReady = false
    @Published var isPreloading = false
    @Published var loadingProgress: Double = 0
    @Published var loadingMessage: String = ""
    
    // MARK: - 回调
    var onPreloadComplete: (() -> Void)?
    var onDataReady: (() -> Void)?
    var onCoreDataReady: (() -> Void)?
    
    // MARK: - 配置
    private let lastFullRefreshKey = "last_full_refresh_timestamp"
    private let refreshCooldown: TimeInterval = 30 // 30秒内不重复刷新
    
    private var lastRefreshTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private var dataReadyWorkItem: DispatchWorkItem?
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // 监听应用进入前台
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
        
        // 监听应用进入后台 - 同步数据到数据库
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 应用生命周期
    
    /// 应用进入前台时检查是否需要刷新
    private func handleAppWillEnterForeground() {
        let isLoggedIn = UserDefaults.standard.bool(forKey: AppConfig.StorageKeys.isLoggedIn)
        guard isLoggedIn else { return }
        
        // 检查是否需要刷新每日数据
        if checkDailyRefreshNeeded() {
            AppLogger.debug("检测到新的一天，触发每日刷新")
            triggerDailyRefresh()
        }
    }
    
    /// 应用进入后台时同步数据
    private func handleAppDidEnterBackground() {
        Task { @MainActor in
            if OptimizedCacheManager.shared.shouldSync() {
                await OptimizedCacheManager.shared.syncToDatabase()
            }
        }
    }
    
    // MARK: - 公共触发器
    
    /// App 启动时调用
    func triggerAppLaunchRefresh() {
        let isLoggedIn = UserDefaults.standard.bool(forKey: AppConfig.StorageKeys.isLoggedIn)
        
        guard isLoggedIn else {
            AppLogger.debug("用户未登录，跳过启动刷新")
            return
        }
        
        AppLogger.debug("App 启动，开始数据加载...")
        
        Task { @MainActor in
            isPreloading = true
            loadingMessage = "正在加载缓存数据..."
            loadingProgress = 0.1
            
            // 1. 快速预加载 - 立即显示缓存数据
            await OptimizedCacheManager.shared.quickPreload()
            loadingProgress = 0.3
            
            // 2. 检查是否需要刷新
            let shouldRefreshDaily = checkDailyRefreshNeeded()
            loadingMessage = shouldRefreshDaily ? "正在更新数据..." : "正在加载..."
            loadingProgress = 0.4
            
            // 3. 触发数据刷新（并行）
            refreshHomePublisher.send(shouldRefreshDaily)
            refreshLibraryPublisher.send(false)
            refreshProfilePublisher.send(false)
            
            loadingProgress = 0.6
            
            // 4. 完整预加载（后台）
            await OptimizedCacheManager.shared.preloadCoreData()
            loadingProgress = 1.0
            
            isPreloading = false
            loadingMessage = ""
        }
    }
    
    /// 登录成功后调用 - 优化版
    func triggerLoginRefresh() {
        AppLogger.debug("登录成功，触发全量数据刷新...")
        
        // 重置状态
        resetDataReadyState()
        resetDailyRefreshTimer()
        OptimizedCacheManager.shared.resetDataReadyState()
        
        // 记录刷新时间
        lastRefreshTime = Date()
        
        Task { @MainActor in
            isPreloading = true
            loadingMessage = "正在加载您的数据..."
            loadingProgress = 0.1
            
            // 并行触发所有数据刷新
            loadingProgress = 0.2
            refreshHomePublisher.send(true)
            
            loadingProgress = 0.4
            refreshLibraryPublisher.send(true)
            
            loadingProgress = 0.6
            refreshProfilePublisher.send(true)
            
            // 等待核心数据就绪或超时
            await waitForCoreDataReady(timeout: 8.0)
            
            loadingProgress = 0.8
            
            // 后台预加载
            await OptimizedCacheManager.shared.preloadCoreData()
            
            loadingProgress = 1.0
            isPreloading = false
            loadingMessage = ""
        }
    }
    
    /// 等待核心数据就绪
    private func waitForCoreDataReady(timeout: TimeInterval) async {
        let startTime = Date()
        
        while !isHomeDataReady {
            if Date().timeIntervalSince(startTime) > timeout {
                AppLogger.warning("等待核心数据超时")
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        }
    }
    
    /// 每日刷新（新的一天）
    func triggerDailyRefresh() {
        guard canRefresh() else {
            AppLogger.debug("刷新冷却中，跳过")
            return
        }
        
        AppLogger.debug("触发每日数据刷新...")
        lastRefreshTime = Date()
        
        refreshHomePublisher.send(true)
        // Library 和 Profile 不需要每日强制刷新
        refreshLibraryPublisher.send(false)
        refreshProfilePublisher.send(false)
    }
    
    /// 手动刷新（下拉刷新）
    func triggerManualRefresh(section: RefreshSection) {
        guard canRefresh() else {
            AppLogger.debug("刷新冷却中，跳过")
            return
        }
        
        AppLogger.debug("手动刷新: \(section)")
        lastRefreshTime = Date()
        
        switch section {
        case .home:
            refreshHomePublisher.send(true)
        case .library:
            refreshLibraryPublisher.send(true)
        case .profile:
            refreshProfilePublisher.send(true)
        case .all:
            refreshHomePublisher.send(true)
            refreshLibraryPublisher.send(true)
            refreshProfilePublisher.send(true)
        }
    }
    
    // MARK: - 数据就绪标记
    
    func markHomeDataReady() {
        guard !isHomeDataReady else { return }
        isHomeDataReady = true
        OptimizedCacheManager.shared.markDailySongsReady()
        AppLogger.success("Home 数据加载完成")
        
        // 核心数据就绪回调
        DispatchQueue.main.async {
            self.onCoreDataReady?()
            self.onDataReady?()
        }
        
        checkAllDataReady()
    }
    
    func markLibraryDataReady() {
        guard !isLibraryDataReady else { return }
        isLibraryDataReady = true
        OptimizedCacheManager.shared.markPlaylistsReady()
        AppLogger.success("Library 数据加载完成")
        checkAllDataReady()
    }
    
    func markProfileDataReady() {
        guard !isProfileDataReady else { return }
        isProfileDataReady = true
        OptimizedCacheManager.shared.markUserDataReady()
        AppLogger.success("Profile 数据加载完成")
        checkAllDataReady()
    }
    
    private func checkAllDataReady() {
        // 所有数据就绪
        if isHomeDataReady && isLibraryDataReady && isProfileDataReady {
            AppLogger.success("所有数据预加载完成")
            
            // 取消之前的延迟任务
            dataReadyWorkItem?.cancel()
            
            // 延迟一点点确保 UI 更新
            let workItem = DispatchWorkItem { [weak self] in
                self?.onPreloadComplete?()
            }
            dataReadyWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
            
            // 后台同步到数据库
            Task { @MainActor in
                await OptimizedCacheManager.shared.syncToDatabase()
            }
        }
    }
    
    var isCoreDataReady: Bool {
        return isHomeDataReady
    }
    
    /// 检查是否有缓存数据可以立即显示
    var hasCachedData: Bool {
        return OptimizedCacheManager.shared.isDailySongsReady || 
               OptimizedCacheManager.shared.isPlaylistsReady
    }
    
    private func resetDataReadyState() {
        isHomeDataReady = false
        isLibraryDataReady = false
        isProfileDataReady = false
        dataReadyWorkItem?.cancel()
        dataReadyWorkItem = nil
    }
    
    // MARK: - 智能刷新逻辑
    
    /// 检查是否可以刷新（防抖）
    private func canRefresh() -> Bool {
        guard let lastTime = lastRefreshTime else { return true }
        return Date().timeIntervalSince(lastTime) > refreshCooldown
    }
    
    /// 检查是否需要刷新每日数据
    func checkDailyRefreshNeeded() -> Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: AppConfig.StorageKeys.lastDailyRefresh) as? Date else {
            return true
        }
        
        let calendar = Calendar.current
        return !calendar.isDateInToday(lastDate)
    }
    
    /// 标记每日刷新完成
    func markDailyRefreshCompleted() {
        UserDefaults.standard.set(Date(), forKey: AppConfig.StorageKeys.lastDailyRefresh)
        OptimizedCacheManager.shared.markDailyDataRefreshed()
        AppLogger.debug("每日刷新标记完成")
    }
    
    private func resetDailyRefreshTimer() {
        UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.lastDailyRefresh)
    }
    
    // MARK: - 缓存状态
    
    /// 获取缓存状态摘要
    func getCacheStatus() -> CacheStatus {
        let stats = OptimizedCacheManager.shared.getStatistics()
        return CacheStatus(
            songsCount: stats.cachedSongs,
            playlistsCount: stats.cachedPlaylists,
            totalSize: stats.totalSize,
            lastDailyRefresh: UserDefaults.standard.object(forKey: AppConfig.StorageKeys.lastDailyRefresh) as? Date,
            needsDailyRefresh: checkDailyRefreshNeeded()
        )
    }
}

// MARK: - 辅助类型

enum RefreshSection {
    case home
    case library
    case profile
    case all
}

struct CacheStatus {
    let songsCount: Int
    let playlistsCount: Int
    let totalSize: String
    let lastDailyRefresh: Date?
    let needsDailyRefresh: Bool
    
    var description: String {
        let dateStr = lastDailyRefresh.map { 
            DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short)
        } ?? "从未"
        return "歌曲: \(songsCount), 歌单: \(playlistsCount), 大小: \(totalSize), 上次刷新: \(dateStr)"
    }
}
