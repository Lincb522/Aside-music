import SwiftUI
import SwiftData
import CoreText

// MARK: - AppDelegate（控制设备方向）

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return OrientationManager.shared.allowedOrientations
    }
}

@main
struct AsideMusicApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var styleManager = StyleManager.shared
    @StateObject private var settings = SettingsManager.shared
    
    init() {
        // 注册 SPM 包中的自定义字体
        Self.registerBundledFonts()
        
        _ = EQManager.shared
        
        // iOS 26: 系统 TabView 自动使用 Liquid Glass 浮动标签栏，不再需要自定义外观
        
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithTransparentBackground()
        navBarAppearance.backgroundColor = .clear
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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .fontDesign(.rounded)
                .preferredColorScheme(settings.preferredColorScheme)
                .background(SwipeBackInjector())
                .onAppear {
                    GlobalRefreshManager.shared.triggerAppLaunchRefresh()
                    
                    Task { @MainActor in
                        await OptimizedCacheManager.shared.cleanupExpiredData()
                    }
                    
                    // 检测 QQ 音乐登录状态（登录有效期约 3 天）
                    Task {
                        do {
                            let status = try await APIService.shared.qqClient.authStatus()
                            await MainActor.run {
                                UserDefaults.standard.set(status.loggedIn, forKey: AppConfig.StorageKeys.qqMusicLoggedIn)
                                if !status.loggedIn {
                                    AppLogger.warning("[QQMusic] 登录已过期")
                                }
                            }
                        } catch {
                            AppLogger.warning("[QQMusic] 登录状态检测失败: \(error.localizedDescription)")
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // 从后台回来时，如果是跟随系统模式，延迟一帧确保 trait 已更新
                    if settings.themeMode == "system" {
                        DispatchQueue.main.async {
                            settings.applyTheme()
                        }
                    }
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
        // SPM 资源可能在子 bundle 中（如 AsideMusic_AsideMusic.bundle）
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
}
