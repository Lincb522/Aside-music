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

    public init() {}

    public var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()

            TabView(selection: $currentTab) {
                HomeView()
                    .toolbar(.hidden, for: .tabBar)
                    .tabItem { Label("tabbar_home", systemImage: "house.fill") }
                    .tag(Tab.home)
                PodcastView()
                    .toolbar(.hidden, for: .tabBar)
                    .tabItem { Label("tabbar_podcast", systemImage: "mic.fill") }
                    .tag(Tab.podcast)
                LibraryView()
                    .toolbar(.hidden, for: .tabBar)
                    .tabItem { Label("tabbar_library", systemImage: "square.stack.3d.up.fill") }
                    .tag(Tab.library)
                ProfileView()
                    .toolbar(.hidden, for: .tabBar)
                    .tabItem { Label("tabbar_profile", systemImage: "person.fill") }
                    .tag(Tab.profile)
            }
            .ignoresSafeArea(.keyboard)
            .gesture(
                (settings.floatingBarStyle == .minimal || settings.floatingBarStyle == .floatingBall)
                    ? swipeGesture : nil
            )
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

            // MARK: - 自定义悬浮栏（所有样式）
            if !player.isTabBarHidden {
                floatingBarView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
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
                    primaryAction: { alertManager.primaryAction?() },
                    secondaryAction: {
                        alertManager.secondaryAction?()
                        alertManager.dismiss()
                    },
                    isPresented: $alertManager.isPresented
                )
                .zIndex(999)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: player.isTabBarHidden)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: settings.floatingBarStyle)
        .onChange(of: systemColorScheme) { _, newScheme in
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
            VStack {
                Spacer()
                UnifiedFloatingBar(currentTab: $currentTab)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 0)
            }

        case .classic:
            ClassicFloatingBar(currentTab: $currentTab)

        case .minimal:
            VStack {
                Spacer()
                MinimalMiniPlayer(currentTab: $currentTab)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

        case .floatingBall:
            FloatingBallView(currentTab: $currentTab)
        }
    }

    // MARK: - 滑动手势（极简/悬浮球模式）

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }

                let allTabs = Tab.allCases
                guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }

                if value.translation.width < -20 {
                    let nextIndex = currentIndex + 1
                    if nextIndex < allTabs.count {
                        HapticManager.shared.light()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            currentTab = allTabs[nextIndex]
                        }
                    }
                } else if value.translation.width > 20 {
                    let prevIndex = currentIndex - 1
                    if prevIndex >= 0 {
                        HapticManager.shared.light()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            currentTab = allTabs[prevIndex]
                        }
                    }
                }
            }
    }
}

// MARK: - Tab Enum
enum Tab: Int, CaseIterable, Hashable {
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
