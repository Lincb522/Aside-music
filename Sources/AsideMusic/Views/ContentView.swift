import SwiftUI

public struct ContentView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @State private var showWelcome = true // Control Welcome Screen
    @State private var currentTab: Tab = .home
    @ObservedObject var player = PlayerManager.shared
    
    @State private var showPersonalFM = false
    @State private var showNormalPlayer = false
    @StateObject private var alertManager = AlertManager.shared // Use Global AlertManager
    @Namespace private var animation // Namespace for Hero Transition
    
    public init() {
        // Hide native tab bar globally and persistently
        UITabBar.appearance().isHidden = true
        UITabBar.appearance().backgroundColor = .clear
        UITabBar.appearance().backgroundImage = UIImage()
        UITabBar.appearance().shadowImage = UIImage()
        
        // 设置 TabBar appearance 为完全透明
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = .clear
        tabBarAppearance.shadowColor = .clear
        tabBarAppearance.shadowImage = UIImage()
        tabBarAppearance.backgroundImage = UIImage()
        tabBarAppearance.backgroundEffect = nil
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    
    public var body: some View {
        ZStack {
            // 全局背景 - 确保底部安全区域也有背景
            AsideBackground()
                .ignoresSafeArea()
            
            // Main App Content (Always loaded, but covered if not logged in)
            ZStack(alignment: .bottom) {
                // 1. Content Layer - 使用自定义切换避免 TabView 的性能问题
                ZStack {
                    // 预加载所有视图，使用 opacity 控制显示
                    HomeView()
                        .opacity(currentTab == .home ? 1 : 0)
                        .zIndex(currentTab == .home ? 1 : 0)
                    
                    // Podcast/Discover Tab
                    ZStack {
                        AsideBackground()
                            .ignoresSafeArea()
                        Text(LocalizedStringKey("tab_podcast"))
                            .font(.rounded(size: 20, weight: .bold))
                            .foregroundColor(.asideTextPrimary)
                    }
                    .opacity(currentTab == .podcast ? 1 : 0)
                    .zIndex(currentTab == .podcast ? 1 : 0)
                    
                    // Library Tab
                    LibraryView()
                        .opacity(currentTab == .library ? 1 : 0)
                        .zIndex(currentTab == .library ? 1 : 0)
                    
                    // Profile Tab
                    ProfileView()
                        .opacity(currentTab == .profile ? 1 : 0)
                        .zIndex(currentTab == .profile ? 1 : 0)
                }
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.15), value: currentTab)
                
                // 2. Unified Floating Bar (MiniPlayer + TabBar)
                if !player.isTabBarHidden {
                    VStack {
                        Spacer()
                        UnifiedFloatingBar(currentTab: $currentTab)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 0) // Moved down to bottom safe area
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1) // Ensure it stays on top
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: player.isTabBarHidden) // Faster spring animation
            .ignoresSafeArea(.keyboard)
            // 3. Listen for Player Open Requests (Smart Routing)
            .onReceive(NotificationCenter.default.publisher(for: .init("OpenFMPlayer"))) { _ in
                showPersonalFM = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("OpenNormalPlayer"))) { _ in
                showNormalPlayer = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("SwitchToLibrarySquare"))) { _ in
                currentTab = .library
            }
            // 4. Full Screen Covers
            .fullScreenCover(isPresented: $showPersonalFM) {
                PersonalFMView()
            }
            .fullScreenCover(isPresented: $showNormalPlayer) {
                // Placeholder for now, later replaced by FullScreenPlayerView
                FullScreenPlayerView()
            }
            
            // Welcome / Login Overlay
            // Shows if explicitly requested (App Start)
            if showWelcome {
                WelcomeView(isPresented: $showWelcome)
                    .transition(.opacity.animation(.easeOut(duration: 0.8))) // Smooth fade out
                    .zIndex(100)
            }
            
            // Global Alert Overlay (Topmost - Covers both Login and Main App)
            if alertManager.isPresented {
                AsideAlertView(
                    title: alertManager.title,
                    message: alertManager.message,
                    primaryButtonTitle: alertManager.primaryButtonTitle,
                    secondaryButtonTitle: alertManager.secondaryButtonTitle,
                    primaryAction: {
                        alertManager.primaryAction?()
                    },
                    secondaryAction: {
                        alertManager.secondaryAction?()
                        alertManager.dismiss()
                    },
                    isPresented: $alertManager.isPresented
                )
                .zIndex(999)
            }
        }
        // Inject Global Swipe Back Controller
        .background(SwipeBackInjector())
    }
}

// MARK: - Tab Enum
enum Tab: Int, CaseIterable {
    case home = 0
    case podcast = 1
    case library = 2
    case profile = 3
    
    var icon: String {
        // Kept for compatibility if needed, but not used in UnifiedFloatingBar anymore
        switch self {
        case .home: return "house.fill"
        case .podcast: return "mic.fill"
        case .library: return "square.stack.3d.up.fill"
        case .profile: return "person.fill"
        }
    }
    
    var titleKey: String {
        switch self {
        case .home: return "tab_home"
        case .podcast: return "tab_podcast"
        case .library: return "tab_library"
        case .profile: return "tab_profile"
    }
    }
}

// MARK: - Unified Floating Bar
// Moved to UnifiedFloatingBar.swift for better performance and code organization
