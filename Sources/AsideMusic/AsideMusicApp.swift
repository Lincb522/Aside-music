import SwiftUI
import SwiftData
import LiquidGlassEffect

@main
struct AsideMusicApp: App {
    // Keep StyleManager alive
    @StateObject private var styleManager = StyleManager.shared
    
    // SwiftData 容器
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CachedSong.self,
            CachedPlaylist.self,
            CachedArtist.self,
            PlayHistory.self,
            SearchHistory.self,
            CachedLyrics.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // 设置液态玻璃性能模式
        LiquidGlassEngine.shared.performanceMode = .balanced
        
        // 设置全局 TabView 背景为透明
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = .clear
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // 设置全局 NavigationBar 背景为透明
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithTransparentBackground()
        navBarAppearance.backgroundColor = .clear
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        
        // 设置 UIPageControl 背景为透明
        UIPageControl.appearance().backgroundColor = .clear
        UIPageControl.appearance().pageIndicatorTintColor = .clear
        UIPageControl.appearance().currentPageIndicatorTintColor = .clear
        
        // 设置 ScrollView 背景为透明
        UIScrollView.appearance().backgroundColor = .clear
        
        // 设置 UICollectionView 背景为透明 (TabView page style 使用)
        UICollectionView.appearance().backgroundColor = .clear
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(SwipeBackInjector()) // Inject Global Swipe Back Gesture
                .onAppear {
                    // App Launch Refresh
                    GlobalRefreshManager.shared.triggerAppLaunchRefresh()
                    
                    // 清理过期缓存数据
                    Task { @MainActor in
                        await OptimizedCacheManager.shared.cleanupExpiredData()
                    }
                }
                .environment(\.modelContext, sharedModelContainer.mainContext)
        }
    }
}
