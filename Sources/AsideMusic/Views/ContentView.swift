import SwiftUI

public struct ContentView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @State private var showWelcome = true
    @State private var currentTab: Tab = .home
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var showPersonalFM = false
    @State private var showNormalPlayer = false
    @State private var showRadioPlayer = false
    @State private var radioPlayerRadioId: Int? = nil
    @StateObject private var alertManager = AlertManager.shared
    @Namespace private var animation

    public init() {
        // TabBar 外观配置已在 AsideMusicApp.init() 中统一设置
        // 根据悬浮栏样式决定是否隐藏系统 TabBar
    }

    public var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()

            ZStack(alignment: .bottom) {
                // 预加载所有视图，使用 opacity + offset 控制显示
                // 极简/悬浮球模式下滑动切换带水平位移动画
                let useSlide = settings.floatingBarStyle == .minimal || settings.floatingBarStyle == .floatingBall
                let currentIndex = Tab.allCases.firstIndex(of: currentTab) ?? 0
                
                ZStack {
                    ForEach(Array(Tab.allCases.enumerated()), id: \.element) { index, tab in
                        tabView(for: tab)
                            .opacity(currentTab == tab ? 1 : 0)
                            .offset(x: useSlide ? CGFloat(index - currentIndex) * UIScreen.main.bounds.width : 0)
                            .zIndex(currentTab == tab ? 1 : 0)
                    }
                }
                .ignoresSafeArea()
                .animation(AsideAnimation.tabSwitch, value: currentTab)
                // 极简模式和悬浮球模式下添加滑动手势切换页面
                .gesture((settings.floatingBarStyle == .minimal || settings.floatingBarStyle == .floatingBall) ? swipeGesture : nil)

                if !player.isTabBarHidden {
                    floatingBarView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .animation(AsideAnimation.floatingBar, value: player.isTabBarHidden)
            .animation(AsideAnimation.panelToggle, value: settings.floatingBarStyle)
            .ignoresSafeArea(.keyboard)
            .onReceive(NotificationCenter.default.publisher(for: .init("OpenFMPlayer"))) { _ in
                showPersonalFM = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("OpenNormalPlayer"))) { _ in
                showNormalPlayer = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("SwitchToLibrarySquare"))) { _ in
                currentTab = .library
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("OpenRadioPlayer"))) { notification in
                if let radioId = notification.object as? Int, radioId > 0 {
                    radioPlayerRadioId = radioId
                    showRadioPlayer = true
                }
            }
            .fullScreenCover(isPresented: $showPersonalFM) {
                PersonalFMView()
            }
            .fullScreenCover(isPresented: $showNormalPlayer) {
                FullScreenPlayerView()
            }
            .fullScreenCover(isPresented: $showRadioPlayer) {
                if let radioId = radioPlayerRadioId {
                    RadioPlayerView(radioId: radioId)
                }
            }

            if showWelcome {
                WelcomeView(isPresented: $showWelcome)
                    .transition(.opacity.animation(.easeOut(duration: 0.8)))
                    .zIndex(100)
            }

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
        // SwipeBackInjector 已在 AsideMusicApp 层注入
        .onAppear {
            updateTabBarVisibility()
        }
        .onChange(of: settings.floatingBarStyle) { _, _ in
            updateTabBarVisibility()
        }
        .onChange(of: systemColorScheme) { _, newScheme in
            // 系统深浅色切换时，自动模式下直接用 SwiftUI 传入的值更新
            if settings.themeMode == "system" {
                settings.activeColorScheme = newScheme
            }
        }
    }
    
    // MARK: - 悬浮栏视图
    
    @ViewBuilder
    private var floatingBarView: some View {
        switch settings.floatingBarStyle {
        case .unified:
            // 统一悬浮栏：MiniPlayer + TabBar 合一
            VStack {
                Spacer()
                UnifiedFloatingBar(currentTab: $currentTab)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 0)
            }
            
        case .classic:
            // 经典模式：MiniPlayer + TabBar 合一，贴底不悬浮
            ClassicFloatingBar(currentTab: $currentTab)
            
        case .minimal:
            // 极简模式：仅 MiniPlayer
            VStack {
                Spacer()
                MinimalMiniPlayer(currentTab: $currentTab)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            
        case .floatingBall:
            // 悬浮球模式
            FloatingBallView(currentTab: $currentTab)
        }
    }
    
    // MARK: - 滑动手势（极简模式）
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                
                let allTabs = Tab.allCases
                guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }
                
                if value.translation.width < 0 {
                    // 向左滑 -> 下一个 tab
                    let nextIndex = currentIndex + 1
                    if nextIndex < allTabs.count {
                        withAnimation(AsideAnimation.tabSwitch) {
                            currentTab = allTabs[nextIndex]
                        }
                    }
                } else {
                    // 向右滑 -> 上一个 tab
                    let prevIndex = currentIndex - 1
                    if prevIndex >= 0 {
                        withAnimation(AsideAnimation.tabSwitch) {
                            currentTab = allTabs[prevIndex]
                        }
                    }
                }
            }
    }
    
    // MARK: - Tab 页面视图
    
    @ViewBuilder
    private func tabView(for tab: Tab) -> some View {
        switch tab {
        case .home: HomeView()
        case .podcast: PodcastView()
        case .library: LibraryView()
        case .profile: ProfileView()
        }
    }
    
    // MARK: - 更新 TabBar 可见性
    
    private func updateTabBarVisibility() {
        // 经典模式使用自定义 TabBar，其他模式隐藏系统 TabBar
        UITabBar.appearance().isHidden = true
    }
}

// MARK: - Tab Enum
enum Tab: Int, CaseIterable {
    case home = 0
    case podcast = 1
    case library = 2
    case profile = 3

    var icon: String {
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
