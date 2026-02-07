import SwiftUI
import SwiftData
import LiquidGlassEffect

@main
struct AsideMusicApp: App {
    @StateObject private var styleManager = StyleManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    
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
                .environment(\.modelContext, sharedModelContainer.mainContext)
        }
    }
}
