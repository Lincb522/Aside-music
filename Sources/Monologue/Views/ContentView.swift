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

            tabViewContent
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
            .onReceive(NotificationCenter.default.publisher(for: .init("SwitchToHome"))) { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    currentTab = .home
                }
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

    /// TabView 内容：在 iOS 26 + 用户开启系统 TabBar 时，启用 Liquid Glass 的"滚动下滑最小化"效果
    /// 同时把迷你播放器嵌入到 TabView 的 bottomAccessory（和 TabBar 一起 Liquid Glass 风格展示）。
    /// 其他场景保持原有行为。
    @ViewBuilder
    private var tabViewContent: some View {
        if #available(iOS 26.0, *), settings.useSystemTabBar {
            SystemTabBarWithAccessory(content: { tabViewCore })
        } else {
            tabViewCore
        }
    }

    private var tabViewCore: some View {
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
    }

    @ViewBuilder
    private func tabRootView(for tab: Tab) -> some View {
        let theme = GlobalThemeManager.shared.current
        switch tab {
        case .home:
            if onlineAccess.canUseOnlineFeatures {
                theme.makeHomeView()
            } else {
                theme.makeLocalHomeView()
            }
        case .podcast:
            if onlineAccess.canUseOnlineFeatures {
                theme.makePodcastView()
            } else {
                theme.makeLocalMusicView()
            }
        case .library:
            if onlineAccess.canUseOnlineFeatures {
                theme.makeLibraryView()
            } else {
                theme.makeLocalLibraryView()
            }
        case .profile:
            if onlineAccess.canUseOnlineFeatures {
                theme.makeProfileView()
            } else {
                theme.makeLocalProfileView()
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

    /// iOS 26+ 时改用 `.tabViewBottomAccessory` 原生嵌入，这里跳过避免重复显示
    private var shouldUseNativeBottomAccessory: Bool {
        if #available(iOS 26.0, *) {
            return settings.useSystemTabBar
        }
        return false
    }

    var body: some View {
        if !shouldUseNativeBottomAccessory,
           settings.useSystemTabBar && !player.isTabBarHidden,
           let song = player.currentSong {
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

// MARK: - iOS 26 系统 TabBar + bottomAccessory 容器
/// `tabViewBottomAccessory` 始终挂载，无歌时由 `TabViewBottomMiniPlayer`
/// 显示占位内容（"未在播放"），保证胶囊在系统 TabBar 上始终有内容而不是"空玻璃"。
///
/// 另外：`playlistPresented` 状态由这个容器持有并通过 `.sheet` 挂在
/// **TabView 本身（而不是 accessory 内部）**。accessory 是系统管理的子视图，
/// 若直接在 accessory 上 present sheet，点击按钮瞬间会和系统 bottomAccessory
/// 的点击/hover 交互冲突，导致 sheet 刚出现就被即刻关闭。
@available(iOS 26.0, *)
private struct SystemTabBarWithAccessory<Content: View>: View {
    let content: () -> Content
    @ObservedObject private var player = PlayerManager.shared
    @State private var playlistPresented = false

    var body: some View {
        content()
            .tabBarMinimizeBehavior(.onScrollDown)
            .tabViewBottomAccessory {
                TabViewBottomMiniPlayer(playlistPresented: $playlistPresented)
            }
            // sheet 挂在 TabView 层而不是 accessory 内部，避免按钮一点就被关
            .sheet(isPresented: $playlistPresented) {
                Group {
                    if player.isPlayingPodcast {
                        PodcastPlaylistPopupView()
                    } else {
                        PlaylistPopupView()
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
            }
    }
}

// MARK: - iOS 26 的 TabView bottomAccessory 迷你播放器
/// 原生嵌入在 TabBar 顶部的 Liquid Glass 胶囊迷你播放器。
/// 文字使用 `.primary` / `.secondary` 语义色，系统会根据 Liquid Glass 背景
/// 自动补偿对比度（浅色背景自动变深色字、反之亦然）。
@available(iOS 26.0, *)
private struct TabViewBottomMiniPlayer: View {
    @Binding var playlistPresented: Bool
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared

    private var hasActiveSong: Bool {
        player.currentSong != nil && !player.isTabBarHidden
    }

    var body: some View {
        // 用 ZStack 而不是 if/else：让系统 accessory 容器感知的子视图身份稳定，
        // 两种内容交叉淡出即可，避免整条胶囊被系统 TabBar 判定为「换人」重新布局/重绘，
        // 造成用户看到的「关闭时整个页面重新加载」的观感。
        ZStack {
            TabBottomAccessoryPlaceholder()
                .opacity(hasActiveSong ? 0 : 1)
                .allowsHitTesting(!hasActiveSong)

            if let song = player.currentSong {
                TabBottomAccessoryContent(song: song, playlistPresented: $playlistPresented)
                    .opacity(hasActiveSong ? 1 : 0)
                    .allowsHitTesting(hasActiveSong)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: hasActiveSong)
        // 封面为深色时 app 会被强制 `.preferredColorScheme(.dark)`，
        // 但系统 TabBar 的 Liquid Glass 背景是按 `activeColorScheme`
        // （用户真实亮/暗模式）渲染的，这里把 environment 重置回去，
        // 避免出现"浅色 TabBar 背景 + 白色文字"的对比不足。
        .environment(\.colorScheme, settings.activeColorScheme)
    }
}

/// bottomAccessory 在无歌时的占位内容。
///
/// 设计目标：
/// - 不抢戏：颜色、字重、动效都克制，和系统 Liquid Glass TabBar 和谐共存
/// - 有生命感：音符圆点带轻微"呼吸"缩放，提示 app 处于待机而非崩溃
/// - 有召唤感：主标题「未在播放」+ 副标题「挑一首歌开始吧」，右侧轻点提示
/// - 可操作：整条胶囊可点击，发送 `SwitchToHome` 通知跳回首页发现音乐
@available(iOS 26.0, *)
private struct TabBottomAccessoryPlaceholder: View {
    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var primaryTextColor: Color { Color(uiColor: .label) }
    private var secondaryTextColor: Color { Color(uiColor: .secondaryLabel) }
    private var tertiaryTextColor: Color { Color(uiColor: .tertiaryLabel) }

    private var iconGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.white.opacity(0.18),
                    Color.white.opacity(0.06)
                ]
                : [
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.04)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .init("SwitchToHome"), object: nil)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(iconGradient)
                        .frame(width: 34, height: 34)

                    MonologueIcon(icon: .musicNote, size: 15, color: secondaryTextColor)
                }
                .scaleEffect(breathing ? 1.04 : 0.97)
                .animation(
                    reduceMotion
                        ? .default
                        : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                    value: breathing
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("not_playing", comment: "未在播放"))
                        .font(.system(size: 14.5, weight: .semibold))
                        .tracking(0.2)
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)

                    Text(NSLocalizedString("not_playing_subtitle", comment: "点此探索音乐"))
                        .font(.system(size: 11.5, weight: .regular))
                        .tracking(0.1)
                        .foregroundColor(secondaryTextColor.opacity(0.82))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                MonologueIcon(icon: .chevronRight, size: 12, color: tertiaryTextColor)
                    .frame(width: 20, height: 30)
            }
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear {
            if !reduceMotion {
                breathing = true
            }
        }
    }
}

/// iOS 26 bottomAccessory 里的紧凑播放器内容。
/// - 颜色使用 UIKit 动态语义色（`UIColor.label` / `UIColor.secondaryLabel`），
///   跟随系统 TabBar 所在窗口的 trait 反色，避免浅色 TabBar 背景下出现"白字"。
/// - 图标全部走自定义 `MonologueIcon`，和 `CompactMiniPlayerView` 视觉一致。
/// - 暂停时显示 close 按钮以手动关闭迷你播放器。
/// - 支持左右滑动切歌（`swipeToSkip()`：右滑下一首、左滑上一首）。
/// - 歌名/歌词使用 `MarqueeText` 跑马灯滚动，不再缩略。
@available(iOS 26.0, *)
private struct TabBottomAccessoryContent: View {
    let song: Song
    @Binding var playlistPresented: Bool
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var lyricVM = LyricViewModel.shared

    private var subtitleText: String {
        if !player.isPlayingPodcast, lyricVM.hasLyrics, let text = lyricVM.currentLineText {
            return text
        }
        return song.artistName
    }

    // iOS 的 bottomAccessory 会让系统 TabBar 根据窗口级 userInterfaceStyle
    // 渲染背景；用 UIKit 动态色可保证文字和系统 TabBar 背景一致。
    private var primaryTextColor: Color { Color(uiColor: .label) }
    private var secondaryTextColor: Color { Color(uiColor: .secondaryLabel) }

    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared

    // 进度条颜色 — 跟随系统 Liquid Glass 背景自动适配亮/暗
    private var progressTrackColor: Color { Color(uiColor: .quaternaryLabel) }
    private var progressFillColors: [Color] {
        [Color(uiColor: .label).opacity(0.45),
         Color(uiColor: .label).opacity(0.75)]
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
                    MarqueeText(
                        text: song.name,
                        font: .system(size: 13, weight: .semibold, design: .rounded),
                        color: primaryTextColor,
                        speed: 25
                    )
                    .frame(height: 16)

                    MarqueeText(
                        text: subtitleText,
                        font: .system(size: 11, weight: .medium, design: .rounded),
                        color: secondaryTextColor,
                        speed: 25
                    )
                    .frame(height: 14)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: { player.togglePlayPause() }) {
                    MonologueIcon(
                        icon: player.isPlaying ? .pause : .play,
                        size: 15,
                        color: primaryTextColor
                    )
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: { playlistPresented = true }) {
                    MonologueIcon(
                        icon: .list,
                        size: 14,
                        color: primaryTextColor.opacity(0.6)
                    )
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if !player.isPlaying {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            player.stopAndClear()
                        }
                    } label: {
                        MonologueIcon(icon: .close, size: 9, color: secondaryTextColor)
                            .frame(width: 24, height: 24)
                            .background(primaryTextColor.opacity(0.08))
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)

            // 进度条
            accessoryProgressBar
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 2)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: player.isPlaying)
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
    }

    /// 贴合 Liquid Glass 风格的超薄进度条
    private var accessoryProgressBar: some View {
        GeometryReader { geo in
            let progress = min(max(CGFloat(timePublisher.progress), 0), 1)
            let fillWidth = progress > 0 ? max(4, geo.size.width * progress) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(progressTrackColor)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: progressFillColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth)
            }
            .frame(height: 2.5)
            .clipShape(Capsule())
        }
        .frame(height: 2.5)
        .allowsHitTesting(false)
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
