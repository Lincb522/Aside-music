import SwiftUI
import HiconIcons

public struct ContentView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @State private var showWelcome = true
    @State private var currentTab: Tab = .home
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var showPersonalFM = false
    @State private var showNormalPlayer = false
    @State private var showRadioPlayer = false
    @State private var radioPlayerRadioId: Int? = nil
    
    public init() {}

    public var body: some View {
        ZStack {
            MonologueBackground()
                .ignoresSafeArea()

            TabView(selection: $currentTab) {
                tabRootView(for: .home)
                    .toolbar(settings.useSystemTabBar ? .automatic : .hidden, for: .tabBar)
                    .tabItem {
                        Label {
                            Text(tabLabel(for: .home))
                        } icon: {
                            tabIcon(for: .home)
                        }
                    }
                    .tag(Tab.home)
                tabRootView(for: .podcast)
                    .toolbar(settings.useSystemTabBar ? .automatic : .hidden, for: .tabBar)
                    .tabItem {
                        Label {
                            Text(tabLabel(for: .podcast))
                        } icon: {
                            tabIcon(for: .podcast)
                        }
                    }
                    .tag(Tab.podcast)
                tabRootView(for: .library)
                    .toolbar(settings.useSystemTabBar ? .automatic : .hidden, for: .tabBar)
                    .tabItem {
                        Label {
                            Text(tabLabel(for: .library))
                        } icon: {
                            tabIcon(for: .library)
                        }
                    }
                    .tag(Tab.library)
                tabRootView(for: .profile)
                    .toolbar(settings.useSystemTabBar ? .automatic : .hidden, for: .tabBar)
                    .tabItem {
                        Label {
                            Text(tabLabel(for: .profile))
                        } icon: {
                            tabIcon(for: .profile)
                        }
                    }
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
            .onReceive(NotificationCenter.default.publisher(for: .init("SwitchToProfile"))) { _ in
                currentTab = .profile
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
                    PodcastPlayerView(radioId: radioId)
                }
            }

            // MARK: - 自定义悬浮栏（所有样式）
            ContentViewFloatingBarContainer(
                currentTab: $currentTab,
                settings: settings
            )

            // MARK: - 系统 TabBar 模式下的紧凑迷你播放器
            ContentViewCompactPlayerContainer(settings: settings)


            if showWelcome {
                WelcomeView(isPresented: $showWelcome)
                    .transition(.opacity.animation(.easeOut(duration: 0.24)))
                    .zIndex(100)
            }

            
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: settings.floatingBarStyle)
        .onChange(of: showNormalPlayer) { _, show in
            withAnimation(MonologueAnimation.playerTransition) {
                PlayerManager.shared.isTabBarHidden = show
            }
        }
        .onChange(of: showPersonalFM) { _, show in
            withAnimation(MonologueAnimation.playerTransition) {
                PlayerManager.shared.isTabBarHidden = show
            }
        }
        .onChange(of: showRadioPlayer) { _, show in
            withAnimation(MonologueAnimation.playerTransition) {
                PlayerManager.shared.isTabBarHidden = show
            }
        }
        .onChange(of: systemColorScheme) { _, newScheme in
            if settings.themeMode == "system" {
                settings.activeColorScheme = newScheme
            }
        }
        .onChange(of: showWelcome) { _, isShowing in
            if !isShowing {
                onlineAccess.refreshOnLaunch(showInvalidAlert: true)
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    @ViewBuilder
    private func tabRootView(for tab: Tab) -> some View {
        switch tab {
        case .home:
            if onlineAccess.canUseOnlineFeatures {
                HomeView()
            } else {
                LocalModeHomeView()
            }
        case .podcast:
            if onlineAccess.canUseOnlineFeatures {
                PodcastView()
            } else {
                LocalMusicView()
            }
        case .library:
            if onlineAccess.canUseOnlineFeatures {
                LibraryView()
            } else {
                LocalLibraryView()
            }
        case .profile:
            if onlineAccess.canUseOnlineFeatures {
                ProfileView()
            } else {
                LocalModeProfileView()
            }
        }
    }

    private func tabLabelKey(for tab: Tab) -> String {
        tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures)
    }

    private func tabLabel(for tab: Tab) -> LocalizedStringKey {
        LocalizedStringKey(tabLabelKey(for: tab))
    }

    @ViewBuilder
    private func tabIcon(for tab: Tab) -> some View {
        switch tab {
        case .home:
            Image(uiImage: currentTab == .home ? Hicon.home2 : Hicon.home1)
                .renderingMode(.template)
        case .podcast:
            if onlineAccess.canUseOnlineFeatures {
                Image(uiImage: currentTab == .podcast ? Hicon.microphone4 : Hicon.microphone3)
                    .renderingMode(.template)
            } else {
                Image(systemName: currentTab == .podcast ? "music.note.list" : "music.note")
            }
        case .library:
            Image(uiImage: currentTab == .library ? Hicon.headphone2 : Hicon.headphone1)
                .renderingMode(.template)
        case .profile:
            Image(uiImage: currentTab == .profile ? Hicon.profileCircle : Hicon.profile1)
                .renderingMode(.template)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "monologue" else { return }
        showWelcome = false

        let route = (url.host?.isEmpty == false ? url.host : nil) ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        switch route {
        case "player":
            openPlayerForCurrentSource()
        case "fm":
            showPersonalFM = true
        case "normal":
            showNormalPlayer = true
        case "podcast":
            if let radioID = PlayerManager.shared.currentRadioId {
                radioPlayerRadioId = radioID
                showRadioPlayer = true
            }
        default:
            break
        }
    }

    private func openPlayerForCurrentSource() {
        guard PlayerManager.shared.currentSong != nil else { return }

        switch PlayerManager.shared.playSource {
        case .fm:
            showPersonalFM = true
        case .podcast(let radioID):
            radioPlayerRadioId = radioID
            showRadioPlayer = true
        case .normal:
            showNormalPlayer = true
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

// MARK: - 悬浮栏容器（隔离 PlayerManager 订阅）
private struct ContentViewFloatingBarContainer: View {
    @Binding var currentTab: Tab
    @ObservedObject var settings: SettingsManager
    @ObservedObject private var player = PlayerManager.shared

    var body: some View {
        if !settings.useSystemTabBar && !player.isTabBarHidden {
            floatingBarView
                .ignoresSafeArea(.keyboard)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: player.isTabBarHidden)
        }
    }

    @ViewBuilder
    private var floatingBarView: some View {
        switch settings.floatingBarStyle {
        case .unified:
            VStack {
                Spacer()
                UnifiedFloatingBar(currentTab: $currentTab)
                    .iPadContentWidth(600)
                    .padding(.horizontal, DeviceLayout.isPad ? 40 : 24)
                    .padding(.bottom, 0)
            }

        case .classic:
            ClassicFloatingBar(currentTab: $currentTab)

        case .minimal:
            VStack {
                Spacer()
                MinimalMiniPlayer(currentTab: $currentTab)
                    .iPadContentWidth(600)
                    .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
                    .padding(.bottom, 8)
            }

        case .floatingBall:
            FloatingBallView(currentTab: $currentTab)
        }
    }
}

// MARK: - 紧凑迷你播放器容器（隔离 PlayerManager + PlaybackTimePublisher 订阅）
private struct ContentViewCompactPlayerContainer: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject private var player = PlayerManager.shared

    var body: some View {
        if settings.useSystemTabBar && !player.isTabBarHidden, let song = player.currentSong {
            VStack {
                Spacer()
                CompactMiniPlayerView(song: song)
                    .monologueGlassCapsule()
                    .iPadContentWidth(600)
                    .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
                    .padding(.bottom, DeviceLayout.isPad ? 72 : 62)
            }
            .ignoresSafeArea(.keyboard)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(9)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: player.isTabBarHidden)
        }
    }
}

// MARK: - 紧凑迷你播放器（独立视图，隔离高频订阅）
private struct CompactMiniPlayerView: View {
    let song: Song
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject private var lyricVM = LyricViewModel.shared
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showCompactPlaylist = false

    private var subtitleText: String {
        if !player.isPlayingPodcast, lyricVM.hasLyrics, let text = lyricVM.currentLineText {
            return text
        }
        return song.artistName
    }

    private var compactProgressTrackColor: Color {
        systemColorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.monologueTextPrimary.opacity(0.07)
    }

    private var compactProgressStrokeColor: Color {
        systemColorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.04)
    }

    private var compactProgressFillColors: [Color] {
        systemColorScheme == .dark
            ? [Color.white.opacity(0.68), Color.white.opacity(0.94)]
            : [Color.monologueTextPrimary.opacity(0.46), Color.monologueTextPrimary.opacity(0.78)]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(1)

                    Text(subtitleText)
                        .font(.rounded(size: 11, weight: .medium))
                        .foregroundColor(.monologueTextSecondary)
                        .lineLimit(1)
                        .animation(.easeInOut(duration: 0.25), value: lyricVM.currentLineIndex)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Button(action: { player.togglePlayPause() }) {
                        MonologueIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 15,
                            color: .monologueTextPrimary
                        )
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button(action: { showCompactPlaylist = true }) {
                        MonologueIcon(icon: .list, size: 14, color: .monologueTextPrimary.opacity(0.6))
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if !player.isPlaying {
                        Button(action: {
                            withAnimation(MonologueAnimation.floatingBar) {
                                player.stopAndClear()
                            }
                        }) {
                            MonologueIcon(icon: .close, size: 9, color: .monologueTextSecondary)
                                .frame(width: 24, height: 24)
                                .background(Color.monologueTextPrimary.opacity(0.08))
                                .clipShape(Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 4)

            compactProgressBar
                .padding(.horizontal, 26)
                .padding(.bottom, 6)
        }
        .contentShape(Rectangle())
        .swipeToSkip()
        .onTapGesture {
            withAnimation(MonologueAnimation.playerTransition) {
                switch player.playSource {
                case .fm:
                    NotificationCenter.default.post(name: .init("OpenFMPlayer"), object: nil)
                case .podcast(let radioId):
                    NotificationCenter.default.post(name: .init("OpenRadioPlayer"), object: radioId)
                case .normal:
                    NotificationCenter.default.post(name: .init("OpenNormalPlayer"), object: nil)
                }
            }
        }
        .monologueSheet(isPresented: $showCompactPlaylist, preset: .standard){
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private var compactProgressBar: some View {
        GeometryReader { geometry in
            let progress = min(max(CGFloat(timePublisher.progress), 0), 1)
            let trackHeight: CGFloat = 3
            let fillWidth = progress > 0 ? max(6, geometry.size.width * progress) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(compactProgressTrackColor)
                    .overlay {
                        Capsule()
                            .stroke(compactProgressStrokeColor, lineWidth: 0.5)
                    }

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: compactProgressFillColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth)
            }
            .frame(height: trackHeight)
            .clipShape(Capsule())
        }
        .frame(height: 3)
        .allowsHitTesting(false)
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

    func titleKey(isLocalMode: Bool = false) -> String {
        switch self {
        case .home: return "tabbar_home"
        case .podcast: return isLocalMode ? "tabbar_local_music" : "tabbar_podcast"
        case .library: return "tabbar_library"
        case .profile: return "tabbar_profile"
        }
    }
}
