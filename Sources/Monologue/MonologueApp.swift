import SwiftUI
import SwiftData
import CoreText
import CarPlay
import HiconIcons
import UserNotifications
import Intents
import WidgetKit

// MARK: - AppDelegate（控制设备方向 + CarPlay 场景配置）

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return OrientationManager.shared.allowedOrientations
    }
    
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if connectingSceneSession.role == .carTemplateApplication {
            let config = UISceneConfiguration(name: "CarPlayConfiguration",
                                              sessionRole: connectingSceneSession.role)
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }
        let config = UISceneConfiguration(name: "Default Configuration",
                                          sessionRole: connectingSceneSession.role)
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
        
        INPreferences.requestSiriAuthorization { status in
            AppLogger.info("[Siri] 授权状态: \(status.rawValue)")
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
        if let groupDefaults = UserDefaults(suiteName: "group.zijiu.Monologue.com") {
            groupDefaults.set("paused", forKey: "widget_playbackState")
            groupDefaults.synchronize()
        }
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
        
        // 注册 SPM 包中的自定义字体
        Self.registerBundledFonts()
        
        _ = EQManager.shared
        
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
                .fontDesign(.rounded)
                .preferredColorScheme(effectiveColorScheme)
                .background(SwipeBackInjector())
                .onAppear {
                    let hasStoredToken = OnlineAccessManager.shared.hasStoredToken

                    AlertWindow.shared.setup()
                    
                    // 双重风控前置探测入口
                    RiskControlManager.shared.performRiskCheck()
                    
                    if hasStoredToken {
                        GlobalRefreshManager.shared.triggerAppLaunchRefresh()
                        PushService.shared.setup()
                    } else {
                        AppLogger.info("未配置 Token，跳过在线启动刷新")
                    }
                    
                    Task {
                        MonologueShortcuts.updateAppShortcutParameters()
                        AppLogger.info("[Siri] App Shortcuts 已注册")
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
                        if session.isLoggedIn {
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
                    if settings.themeMode == "system" {
                        DispatchQueue.main.async {
                            settings.applyTheme()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    PlayerManager.shared.saveStateImmediately()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    PlayerManager.shared.saveStateImmediately()
                    UserDefaults.standard.set(false, forKey: "qqDevMode")
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    PlayerManager.shared.saveStateImmediately()
                    #if canImport(ActivityKit) && os(iOS)
                    Task { @MainActor in
                        await LyricsLiveActivityManager.shared.endCurrentActivity()
                    }
                    #endif
                }
                .modelContainer(DatabaseManager.shared.container)
        }
    }
    
    /// 注册自定义字体 — 搜索主 bundle 和所有子 bundle
    private static func registerBundledFonts() {
        let fontFiles = [
            "SanJiPoMoTi",
            "HYPixel11pxU",
            "ZihunBantianyun",
            "YeZiGongChangGangFengSong",
        ]
        
        // 收集所有可能包含资源的 bundle
        var bundles: [Bundle] = [Bundle.main]
        // SPM 资源可能在子 bundle 中（如 Monologue_Monologue.bundle）
        if let resourceURL = Bundle.main.resourceURL,
           let contents = try? FileManager.default.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil) {
            for item in contents where item.pathExtension == "bundle" {
                if let sub = Bundle(url: item) {
                    bundles.append(sub)
                }
            }
        }
        
        for fontName in fontFiles {
            var registered = false
            for bundle in bundles {
                if let url = bundle.url(forResource: fontName, withExtension: "ttf") {
                    var error: Unmanaged<CFError>?
                    if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                        registered = true
                        break
                    } else {
                        // 已注册过也算成功（error domain kCTFontManagerErrorAlreadyRegistered）
                        registered = true
                        error?.release()
                        break
                    }
                }
            }
            if !registered {
                AppLogger.warning("[Font] 未找到字体文件: \(fontName).ttf")
            }
        }
    }

    /// 检测 App 是否为重新安装，若是则清除上次残留的 Keychain 数据
    private static func cleanupKeychainIfNeeded() {
        let hasLaunchedKey = "monologue_has_launched_before"
        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            KeychainHelper.deleteAll()
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            #if DEBUG
            print("[App] 检测到全新安装，已清除残留 Keychain 数据")
            #endif
        }
    }
    
}
