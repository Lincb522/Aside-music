import SwiftUI
import HiconIcons
import UserNotifications
import WidgetKit

// MARK: - AppDelegate（控制设备方向 + 场景配置）

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return OrientationManager.shared.allowedOrientations
    }
    
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration",
                                          sessionRole: connectingSceneSession.role)
        // 指派自定义 scene delegate 以接收 Quick Actions / shortcutItem 回调
        config.delegateClass = MonologueSceneDelegate.self
        return config
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
            if let error = error {
                AppLogger.error("推送授权失败: \(error.localizedDescription)")
            }
        }
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        AppLogger.info("APNs Device Token: \(token)")
        UserDefaults.standard.set(token, forKey: "apns_device_token")
        PushService.shared.registerToken(token)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        AppLogger.error("APNs 注册失败: \(error.localizedDescription)")
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // App被划掉后台时，强制小组件回退到暂停态，但保留最后播放的歌曲信息
        UserDefaults(suiteName: "group.zijiu.Monologue.com")?
            .set("paused", forKey: "widget_playbackState")
        WidgetCenter.shared.reloadAllTimelines()

        #if canImport(ActivityKit) && os(iOS)
        Task { @MainActor in
            await LyricsLiveActivityManager.shared.endCurrentActivity()
        }
        #endif
    }
}

@main
struct MonologueApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var styleManager = StyleManager.shared
    @StateObject private var settings = SettingsManager.shared
    
    init() {
        // 检测是否为全新安装（删除 App 后 UserDefaults 会被清除，Keychain 不会）
        // 如果是重新安装，清除上次残留的 Keychain 数据
        Self.cleanupKeychainIfNeeded()
        
        _ = EQManager.shared
        _ = AIEqualizerAgent.shared
        _ = AILyricAlignmentAgent.shared
        _ = CustomFontManager.shared
        
        // iOS 26: 系统 TabView 自动使用 Liquid Glass 浮动标签栏，不再需要自定义外观
        
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        navBarAppearance.shadowColor = .clear
        navBarAppearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        
        UIPageControl.appearance().backgroundColor = .clear
        UIPageControl.appearance().pageIndicatorTintColor = .clear
        UIPageControl.appearance().currentPageIndicatorTintColor = .clear
        
        UIScrollView.appearance().backgroundColor = .clear
        UIScrollView.appearance().showsVerticalScrollIndicator = false
        UIScrollView.appearance().showsHorizontalScrollIndicator = false
        
        // List 内部的 UITableView / UICollectionView 也隐藏滚动条
        UITableView.appearance().showsVerticalScrollIndicator = false
        UITableView.appearance().showsHorizontalScrollIndicator = false
        UICollectionView.appearance().showsVerticalScrollIndicator = false
        UICollectionView.appearance().showsHorizontalScrollIndicator = false
        
        UICollectionView.appearance().backgroundColor = .clear
    }
    
    /// 全局动态背景开启时，根据封面亮度自动切换深/浅色主题
    private var effectiveColorScheme: ColorScheme? {
        if settings.coverBgGlobal && settings.globalCoverIsDark {
            return .dark
        }
        return settings.preferredColorScheme
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .compatFontDesign(.rounded)
                .preferredColorScheme(effectiveColorScheme)
                .background(SwipeBackInjector())
                .onAppear {
                    AppFrameRate.lockConnectedScenesToPreferredFrameRate(reason: "app root appear")

                    let hasStoredToken = OnlineAccessManager.shared.hasStoredToken

                    AlertWindow.shared.setup()
                    
                    // 双重风控前置探测入口
                    RiskControlManager.shared.performRiskCheck()
                    
                    if hasStoredToken {
                        OnlineAccessManager.shared.refreshOnLaunch(showInvalidAlert: false)
                        GlobalRefreshManager.shared.triggerAppLaunchRefresh()
                        PushService.shared.setup()
                    } else {
                        AppLogger.info("未配置 Token，跳过在线启动刷新")
                    }
                    
                    Task { @MainActor in
                        MonologueQuickActionsManager.refreshAsync()
                    }
                    // 冷启动只恢复 UI 状态（歌曲信息+进度），不自动加载播放
                    // 用户点击播放按钮时 togglePlayPause 会触发 restorePlaybackSessionIfNeeded
                    
                    Task { @MainActor in
                        await OptimizedCacheManager.shared.cleanupExpiredData()
                    }

                    guard hasStoredToken else { return }

                    // 检测管理员 qcm 登录状态（登录有效期约 3 天）
                    Task {
                        do {
                            let status = try await APIService.shared.qqClient.authStatus()
                            await MainActor.run {
                                UserDefaults.standard.set(status.loggedIn, forKey: AppConfig.StorageKeys.qqMusicLoggedIn)
                                if !status.loggedIn {
                                    AppLogger.warning("[QQMusic] 管理员登录已过期")
                                    PushService.shared.sendCookieExpiredNotification()
                                }
                            }
                        } catch {
                            AppLogger.warning("[QQMusic] 管理员登录状态检测失败: \(error.localizedDescription)")
                        }
                    }

                    // 检测用户 qcm 登录状态
                    Task { @MainActor in
                        let session = QQUserSession.shared
                        if session.isLoggedIn || session.hasStoredCredentials {
                            await session.refresh()
                            if !session.isLoggedIn {
                                AppLogger.warning("[QQMusic] 用户登录已过期")
                                AlertManager.shared.show(
                                    title: String(localized: "qq_session_expired_title"),
                                    message: String(localized: "qq_session_expired_message"),
                                    primaryButtonTitle: String(localized: "common_ok"),
                                    primaryAction: {}
                                )
                            }
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    AppFrameRate.lockConnectedScenesToPreferredFrameRate(reason: "application did become active")

                    if settings.themeMode == "system" {
                        DispatchQueue.main.async {
                            settings.applyTheme()
                        }
                    }
                    if OnlineAccessManager.shared.hasStoredToken {
                        OnlineAccessManager.shared.refreshOnLaunch(showInvalidAlert: true)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    PlayerManager.shared.saveStateImmediately()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    PlayerManager.shared.saveStateImmediately()
                    DatabaseManager.shared.save()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    PlayerManager.shared.saveStateImmediately()
                    #if canImport(ActivityKit) && os(iOS)
                    Task { @MainActor in
                        await LyricsLiveActivityManager.shared.endCurrentActivity()
                    }
                    #endif
                }
        }
    }
    
    /// 检测 App 是否为重新安装，若是则清除上次残留的 Keychain 数据
    private static func cleanupKeychainIfNeeded() {
        let hasLaunchedKey = "monologue_has_launched_before"
        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            // 根据要求，永久不删残留 Keychain 数据以保留设备 UDID 等标识
            // KeychainHelper.deleteAll()
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            #if DEBUG
            print("[App] 检测到全新安装，保留原有 Keychain 数据")
            #endif
        }
    }
    
}
