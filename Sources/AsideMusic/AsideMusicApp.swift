import SwiftUI
import SwiftData
import LiquidGlassEffect

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
    @ObservedObject private var settings = SettingsManager.shared
    
    init() {
        LiquidGlassEngine.shared.performanceMode = .balanced
        
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = .clear
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
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
        
        UICollectionView.appearance().backgroundColor = .clear
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(settings.preferredColorScheme)
                .background(SwipeBackInjector())
                .onAppear {
                    GlobalRefreshManager.shared.triggerAppLaunchRefresh()
                    
                    Task { @MainActor in
                        await OptimizedCacheManager.shared.cleanupExpiredData()
                    }
                }
                .modelContainer(DatabaseManager.shared.container)
        }
    }
}
