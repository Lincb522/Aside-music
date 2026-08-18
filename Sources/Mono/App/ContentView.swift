import HiconIcons
import SwiftUI

/// 应用根视图，负责启动阶段、全局主题、主导航与迷你播放器容器的装配。
@MainActor
public struct ContentView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @State private var showWelcome: Bool
    @State private var canMountMainContent = false
    @State private var currentTab: Tab = .home
    @State private var didSynchronizeLaunchTheme = false
    @State private var pendingDeepLink: URL?
    @State private var isDeliveringDeepLink = false
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @ObservedObject private var announcementCenter = AnnouncementCenter.shared
    @ObservedObject private var themeManager = GlobalThemeManager.shared
    @ObservedObject private var textInputActivity = MonoTextInputActivity.shared
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showPersonalFM = false
    @State private var showNormalPlayer = false
    @State private var showImmersivePlayer = false
    @State private var showRadioPlayer = false
    @State private var radioPlayerRadioId: Int? = nil
    @AppStorage("immersivePersistent") private var immersivePersistent = false

    public init() {
        _showWelcome = State(
            initialValue: !ProcessInfo.processInfo.arguments.contains("-SkipWelcome")
        )
    }

    public var body: some View {
        ThemeRenderHost {
            ZStack {
                if canMountMainContent || !showWelcome {
                    mainAppContent
                        .transition(.identity)
                }

                // 版本更新后的更新日志弹窗（欢迎页关闭后触发检查）
                ChangelogPopupOverlay()
                    .zIndex(60)

                // 周报 / 月报弹窗（与更新日志、专属问候错峰弹出）
                ListeningReportPopupOverlay()
                    .zIndex(65)

                // 浆糊专属问候弹窗（特定 Token 生效，与更新日志错峰弹出）
                SpecialGreetingOverlay()
                    .zIndex(70)

                // 通用公告采用轻量清单懒检查，命中未读版本后才加载详情。
                AnnouncementPopupOverlay()
                    .zIndex(75)

                if showWelcome {
                    WelcomeView(isPresented: $showWelcome)
                        .transition(.identity)
                        .zIndex(100)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: settings.floatingBarStyle)
        .onChange(of: showNormalPlayer) { _, show in
            withAnimation(MonoAnimation.playerTransition) {
                PlayerManager.shared.isTabBarHidden = show
            }
        }
        .onChange(of: showImmersivePlayer) { _, show in
            withAnimation(MonoAnimation.playerTransition) {
                PlayerManager.shared.isTabBarHidden = show
            }
        }
        .onChange(of: showPersonalFM) { _, show in
            withAnimation(MonoAnimation.playerTransition) {
                PlayerManager.shared.isTabBarHidden = show
            }
        }
        .onChange(of: showRadioPlayer) { _, show in
            withAnimation(MonoAnimation.playerTransition) {
                PlayerManager.shared.isTabBarHidden = show
            }
        }
        .onChange(of: systemColorScheme) { _, newScheme in
            if settings.themeMode == "system" {
                settings.activeColorScheme = newScheme
            }
        }
        .onAppear {
            synchronizeLaunchThemeIfNeeded()
            scheduleMainContentMountAfterWelcomeFirstFrame()
            deliverPendingDeepLinkIfReady()
        }
        .onChange(of: settings.globalThemeRevision) { _, _ in
            refreshHomeStateForThemeChange()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, !showWelcome {
                announcementCenter.checkIfNeeded()
            }
            if phase == .active {
                deliverPendingDeepLinkIfReady()
            }
        }
        .onChange(of: showWelcome) { _, isShowing in
            if !isShowing {
                mountMainContentWithoutAnimation()
                onlineAccess.refreshOnLaunch(showInvalidAlert: true)
                ChangelogManager.shared.presentLatestAfterUpdateIfNeeded()
                SpecialGreetingManager.shared.presentOnLaunchIfEligible()
                ListeningReportCenter.shared.presentOnLaunchIfEligible()
                announcementCenter.checkIfNeeded(force: true)
            }
        }
        .onOpenURL { url in
            queueDeepLink(url)
        }
    }

    private var mainAppContent: some View {
        ZStack {
            tabViewContent
                .themeRenderSceneLayer()
                .environment(\.themeCustomizationRevision, settings.globalThemeRevision)
                .simultaneousGesture(
                    !textInputActivity.isEditing ? swipeGesture : nil
                )
                .onReceive(NotificationCenter.default.publisher(for: .init("OpenFMPlayer"))) { _ in
                    showPersonalFM = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .init("OpenNormalPlayer"))) { _ in
                    openNormalPlaybackSurface()
                }
                .onReceive(NotificationCenter.default.publisher(for: .init("SwitchToLibrarySquare"))) { _ in
                    selectTabImmediately(.library)
                }
                .onReceive(NotificationCenter.default.publisher(for: .init("SwitchToLibraryArtists"))) { _ in
                    selectTabImmediately(.library)
                }
                .onReceive(NotificationCenter.default.publisher(for: .init("SwitchToHome"))) { _ in
                    selectTabImmediately(.home)
                }
                .onReceive(NotificationCenter.default.publisher(for: .init("SwitchToProfile"))) { _ in
                    selectTabImmediately(.profile)
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
                .fullScreenCover(isPresented: $showImmersivePlayer) {
                    AriaStageView()
                }
                .fullScreenCover(isPresented: $showRadioPlayer) {
                    if let radioId = radioPlayerRadioId {
                        PodcastPlayerView(radioId: radioId)
                    }
                }

            // MARK: - 自定义悬浮栏（所有样式）

            ContentViewFloatingBarContainer(
                currentTab: tabSelectionBinding,
                settings: settings
            )

            // MARK: - 系统 TabBar 模式下的紧凑迷你播放器

            ContentViewCompactPlayerContainer(settings: settings)
        }
    }

    private func scheduleMainContentMountAfterWelcomeFirstFrame() {
        guard showWelcome, !canMountMainContent else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 850_000_000)
            guard showWelcome, !canMountMainContent else { return }
            mountMainContentWithoutAnimation()
        }
    }

    private func mountMainContentWithoutAnimation() {
        guard !canMountMainContent else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            canMountMainContent = true
        }
    }

    /// TabView 内容：在 iOS 26 + 用户开启系统 TabBar 时，启用 Liquid Glass 的"滚动下滑最小化"效果
    /// 同时把迷你播放器嵌入到 TabView 的 bottomAccessory（和 TabBar 一起 Liquid Glass 风格展示）。
    /// 其他场景保持原有行为。
    @ViewBuilder
    private var tabViewContent: some View {
        if #available(iOS 26.0, *), settings.useSystemTabBar, settings.globalThemeId != .manga {
            SystemTabBarWithAccessory(content: { tabViewCore })
        } else {
            tabViewCore
        }
    }

    private var tabViewCore: some View {
        let _ = settings.globalThemeRevision
        let tabTint = themeManager.provider(for: settings.globalThemeId).colorPalette.accent

        return TabView(selection: tabSelectionBinding) {
            tabRootView(for: .home)
                .id(tabRootIdentity(for: .home))
                .toolbar(settings.useSystemTabBar && settings.globalThemeId != .manga ? .automatic : .hidden, for: .tabBar)
                .tabItem {
                    Label {
                        Text(tabLabel(for: .home))
                    } icon: {
                        tabIcon(for: .home)
                    }
                }
                .tag(Tab.home)
            tabRootView(for: .podcast)
                .id(tabRootIdentity(for: .podcast))
                .toolbar(settings.useSystemTabBar && settings.globalThemeId != .manga ? .automatic : .hidden, for: .tabBar)
                .tabItem {
                    Label {
                        Text(tabLabel(for: .podcast))
                    } icon: {
                        tabIcon(for: .podcast)
                    }
                }
                .tag(Tab.podcast)
            tabRootView(for: .library)
                .id(tabRootIdentity(for: .library))
                .toolbar(settings.useSystemTabBar && settings.globalThemeId != .manga ? .automatic : .hidden, for: .tabBar)
                .tabItem {
                    Label {
                        Text(tabLabel(for: .library))
                    } icon: {
                        tabIcon(for: .library)
                    }
                }
                .tag(Tab.library)
            tabRootView(for: .profile)
                .id(tabRootIdentity(for: .profile))
                .toolbar(settings.useSystemTabBar && settings.globalThemeId != .manga ? .automatic : .hidden, for: .tabBar)
                .tabItem {
                    Label {
                        Text(tabLabel(for: .profile))
                    } icon: {
                        tabIcon(for: .profile)
                    }
                }
                .tag(Tab.profile)
        }
        .tint(tabTint)
        .background {
            if settings.useSystemTabBar && settings.globalThemeId != .manga {
                SystemTabBarAppearanceBridge(
                    accent: tabTint,
                    colorScheme: settings.activeColorScheme,
                    revision: settings.globalThemeRevision
                )
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private func tabRootView(for tab: Tab) -> some View {
        let _ = themeManager.tokenRevision
        let theme = themeManager.provider(for: settings.globalThemeId)

        Group {
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
    }

    private func tabRootIdentity(for tab: Tab) -> String {
        let accessMode = onlineAccess.canUseOnlineFeatures ? "online" : "local"
        // TabView 本身必须保持稳定。启动主题同步会刷新 revision；若把 revision
        // 放进 identity，SwiftUI 会在 UITabBarController 切换/导航栏布局期间同时
        // 销毁四个 NavigationStack，iOS 26 会在 UINavigationBar.layoutSubviews
        // 内触发一致性断言。真正改变根结构的只有主题或在线能力，因此只用二者
        // 重建对应 tab 的内容，不再重建整个 TabView 容器。
        return "\(settings.globalThemeId.rawValue)-\(accessMode)-tab-\(tab.rawValue)"
    }

    private func refreshHomeStateForThemeChange() {
        HomeViewModel.shared.refreshThemeSensitiveHomeState(reason: "global theme changed \(settings.globalThemeId.rawValue)")
    }

    private var tabSelectionBinding: Binding<Tab> {
        Binding(
            get: { currentTab },
            set: { tab in
                if currentTab != tab, settings.useSystemTabBar {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                selectTabImmediately(tab)
            }
        )
    }

    private func selectTabImmediately(_ tab: Tab) {
        guard currentTab != tab else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentTab = tab
        }
    }

    private func synchronizeLaunchThemeIfNeeded() {
        guard !didSynchronizeLaunchTheme else { return }
        didSynchronizeLaunchTheme = true
        settings.synchronizeGlobalThemeAfterLaunch(reason: "content view appear")
    }

    private func tabLabelKey(for tab: Tab) -> String {
        tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures)
    }

    private func tabLabel(for tab: Tab) -> LocalizedStringKey {
        LocalizedStringKey(tabLabelKey(for: tab))
    }

    @ViewBuilder
    private func tabIcon(for tab: Tab) -> some View {
        let iconSet = AppInterfaceIconSet.selectedFromDefaults

        if iconSet == .sfSymbols {
            // 系统 TabBar 会提取 tabItem 内部的原始 UIImage，并忽略自定义
            // View 的 frame。SF 图标包内部使用 60pt 符号源，必须在这里
            // 交回原生 Image(systemName:) 才会应用系统标准 Tab 图标尺寸。
            systemTabSymbolIcon(for: tab)
        } else if iconSet == .hicon {
            defaultTabIcon(for: tab)
        } else if iconSet == .pawPrint {
            originalArtworkTabIcon(
                icon: pawPrintTabIcon(for: tab),
                iconSet: iconSet,
                visualSize: pawPrintTabIconVisualSize(for: tab)
            )
        } else if iconSet.usesOriginalArtwork {
            originalArtworkTabIcon(
                icon: themedTabIcon(for: tab),
                iconSet: iconSet,
                visualSize: themedTabIconVisualSize(for: iconSet)
            )
        } else {
            MonoIcon(
                icon: themedTabIcon(for: tab),
                size: themedTabIconVisualSize(for: iconSet),
                normalizesBitmapScale: true
            )
            .frame(width: tabIconFrameSize, height: tabIconFrameSize)
        }
    }

    @ViewBuilder
    private func systemTabSymbolIcon(for tab: Tab) -> some View {
        switch tab {
        case .home:
            Image(systemName: currentTab == .home ? "house.fill" : "house")
        case .podcast:
            if onlineAccess.canUseOnlineFeatures {
                Image(systemName: currentTab == .podcast ? "mic.fill" : "mic")
            } else {
                Image(systemName: currentTab == .podcast ? "music.note.list" : "music.note")
            }
        case .library:
            Image(systemName: currentTab == .library ? "square.stack.fill" : "square.stack")
        case .profile:
            Image(systemName: currentTab == .profile ? "person.fill" : "person")
        }
    }

    private func originalArtworkTabIcon(
        icon: MonoIcon.IconType,
        iconSet: AppInterfaceIconSet,
        visualSize: CGFloat
    ) -> some View {
        Image(uiImage: iconSet.image(for: icon).withRenderingMode(.alwaysOriginal))
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: visualSize, height: visualSize)
            .frame(width: tabIconFrameSize, height: tabIconFrameSize)
    }

    private var tabIconFrameSize: CGFloat { 23 }

    private func pawPrintTabIconVisualSize(for tab: Tab) -> CGFloat {
        let isSelected = currentTab == tab

        switch tab {
        case .library:
            return 23
        case .home, .podcast, .profile:
            return isSelected ? 17.5 : 18.5
        }
    }

    private func pawPrintTabIcon(for tab: Tab) -> MonoIcon.IconType {
        switch tab {
        case .home:
            return currentTab == .home ? .homeFilled : .home
        case .podcast:
            if onlineAccess.canUseOnlineFeatures {
                return currentTab == .podcast ? .podcastFilled : .podcast
            } else {
                return currentTab == .podcast ? .musicNoteList : .musicNote
            }
        case .library:
            return currentTab == .library ? .libraryFilled : .library
        case .profile:
            return currentTab == .profile ? .profileFilled : .profile
        }
    }

    private func themedTabIconVisualSize(for iconSet: AppInterfaceIconSet) -> CGFloat {
        switch iconSet {
        case .doodlePop:
            return 16.5
        case .blobIcons, .iconExport, .dotDogSnake, .minimalWhiteIcons:
            return 17
        case .pawPrint:
            return 18
        case .hicon, .sfSymbols, .zappicon, .lucide, .solar:
            return 23
        }
    }

    private func themedTabIcon(for tab: Tab) -> MonoIcon.IconType {
        switch tab {
        case .home:
            return currentTab == .home ? .homeFilled : .home
        case .podcast:
            if onlineAccess.canUseOnlineFeatures {
                return currentTab == .podcast ? .podcastFilled : .podcast
            } else {
                return currentTab == .podcast ? .musicNoteList : .musicNote
            }
        case .library:
            return currentTab == .library ? .libraryFilled : .library
        case .profile:
            return currentTab == .profile ? .profileFilled : .profile
        }
    }

    @ViewBuilder
    private func defaultTabIcon(for tab: Tab) -> some View {
        switch tab {
        case .home:
            Image(uiImage: currentTab == .home ? Hicon.home2 : Hicon.home1)
                .renderingMode(.template)
        case .podcast:
            if onlineAccess.canUseOnlineFeatures {
                Image(uiImage: currentTab == .podcast ? Hicon.microphone4 : Hicon.microphone3)
                    .renderingMode(.template)
            } else {
                MonoIcon(icon: currentTab == .podcast ? .musicNoteList : .musicNote, size: 23)
            }
        case .library:
            Image(uiImage: currentTab == .library ? Hicon.headphone2 : Hicon.headphone1)
                .renderingMode(.template)
        case .profile:
            Image(uiImage: currentTab == .profile ? Hicon.profileCircle : Hicon.profile1)
                .renderingMode(.template)
        }
    }

    private func queueDeepLink(_ url: URL) {
        guard url.scheme == "mono" else { return }
        pendingDeepLink = url
        deliverPendingDeepLinkIfReady()
    }

    /// 小组件冷启动时 `.onOpenURL` 可能发生在 Scene 尚未创建完成的阶段。
    /// 此时装配播放器会提前初始化播放恢复链路，并把 MusicKit/MediaPlayer
    /// 工作塞进 scene-create 的看门狗窗口。先缓存路由，等 Scene active 后
    /// 完成主界面首帧，再打开目标播放页。
    private func deliverPendingDeepLinkIfReady() {
        guard scenePhase == .active,
              !isDeliveringDeepLink,
              let url = pendingDeepLink else {
            return
        }

        isDeliveringDeepLink = true

        Task { @MainActor in
            // 先让 Scene 激活提交完成，再装配主界面，避免播放器恢复
            // 与 scene-create 共用同一个主线程时限。
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard scenePhase == .active else {
                isDeliveringDeepLink = false
                return
            }
            guard pendingDeepLink == url else {
                isDeliveringDeepLink = false
                deliverPendingDeepLinkIfReady()
                return
            }

            mountMainContentWithoutAnimation()
            showWelcome = false
            // 给根视图一次提交机会，再读取 PlayerManager 的恢复状态。
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard scenePhase == .active, pendingDeepLink == url else {
                isDeliveringDeepLink = false
                return
            }

            pendingDeepLink = nil
            performDeepLink(url)
            isDeliveringDeepLink = false
        }
    }

    private func performDeepLink(_ url: URL) {

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
        case let .podcast(radioID):
            radioPlayerRadioId = radioID
            showRadioPlayer = true
        case .normal:
            openNormalPlaybackSurface()
        }
    }

    private func openNormalPlaybackSurface() {
        guard PlayerManager.shared.currentSong != nil else { return }

        if immersivePersistent {
            OrientationManager.shared.enterLandscape()
            showImmersivePlayer = true
        } else {
            showNormalPlayer = true
        }
    }

    // MARK: - 滑动手势（极简/悬浮球模式）

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .global)
            .onEnded { value in
                guard !isFloatingBarGestureArea(value.startLocation) else { return }
                // 首页歌单、榜单等横向 ScrollView 必须优先消费手势。全局 Tab
                // 切换只在非横向滚动区域生效，避免滑歌单时整页被切走。
                guard !startsInsideHorizontalScrollRegion(value.startLocation) else { return }
                let translation = value.translation
                let projected = value.predictedEndTranslation
                let horizontalIntent = abs(projected.width) > abs(projected.height) * 1.45
                    || abs(translation.width) > abs(translation.height) * 1.65
                guard horizontalIntent else { return }

                let travel = abs(translation.width)
                let projectedTravel = abs(projected.width)
                guard travel >= 54 || projectedTravel >= 108 else { return }

                let allTabs = Tab.allCases
                guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }
                let direction = projectedTravel > travel ? projected.width : translation.width

                // 左侧返回边缘的右滑交给导航返回手势，避免全局 Tab 切换抢占。
                if direction > 0, value.startLocation.x <= 44 {
                    return
                }

                if direction < 0 {
                    let nextIndex = currentIndex + 1
                    if nextIndex < allTabs.count {
                        HapticManager.shared.light()
                        selectTabFromSwipe(allTabs[nextIndex])
                    }
                } else if direction > 0 {
                    let prevIndex = currentIndex - 1
                    if prevIndex >= 0 {
                        HapticManager.shared.light()
                        selectTabFromSwipe(allTabs[prevIndex])
                    }
                }
            }
    }

    private func selectTabFromSwipe(_ tab: Tab) {
        guard currentTab != tab else { return }
        var transaction = Transaction(animation: reduceMotion ? nil : MonoAnimation.tabSwitch)
        transaction.disablesAnimations = reduceMotion
        withTransaction(transaction) {
            currentTab = tab
        }
    }

    private var floatingBarGestureExclusionHeight: CGFloat {
        switch settings.floatingBarStyle {
        case .minimal:
            return playerAwareBottomGestureHeight(hasMiniPlayer: PlayerManager.shared.currentSong != nil)
        case .floatingBall:
            return 112
        case .unified, .classic, .flux, .liquid, .rivePulse:
            return 96
        case .cassette:
            return 132
        case .orbit:
            return 142
        case .vinylNeedle, .waveform, .filmstrip, .studioMeter:
            return 176
        }
    }

    private func playerAwareBottomGestureHeight(hasMiniPlayer: Bool) -> CGFloat {
        hasMiniPlayer ? 148 : 112
    }

    private func isFloatingBarGestureArea(_ location: CGPoint) -> Bool {
        let exclusionHeight = floatingBarGestureExclusionHeight
        guard exclusionHeight > 0 else { return false }
        return location.y >= UIScreen.main.bounds.height - exclusionHeight
    }

    private func startsInsideHorizontalScrollRegion(_ location: CGPoint) -> Bool {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first

        guard let window, var view = window.hitTest(location, with: nil) else {
            return false
        }

        while true {
            if let scrollView = view as? UIScrollView,
               scrollView.isScrollEnabled {
                let visibleWidth = max(
                    scrollView.bounds.width
                        - scrollView.adjustedContentInset.left
                        - scrollView.adjustedContentInset.right,
                    0
                )
                if scrollView.contentSize.width > visibleWidth + 8 {
                    return true
                }
            }

            guard let parent = view.superview else { break }
            view = parent
        }
        return false
    }
}

// MARK: - 悬浮栏容器（隔离 PlayerManager 订阅）

@MainActor
private struct ContentViewFloatingBarContainer: View {
    @Binding var currentTab: Tab
    @ObservedObject var settings: SettingsManager
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @ObservedObject private var textInputActivity = MonoTextInputActivity.shared

    var body: some View {
        if (!settings.useSystemTabBar || settings.globalThemeId == .manga),
           !player.isTabBarHidden,
           !textInputActivity.isEditing
        {
            floatingBarView
                .id("\(settings.globalThemeId.rawValue)-\(settings.globalThemeRevision)")
                .themeRenderInteractiveLayer()
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: player.isTabBarHidden)
                .animation(MonoAnimation.floatingBar, value: settings.globalThemeRevision)
        }
    }

    @ViewBuilder
    private var floatingBarView: some View {
        if settings.globalThemeId == .clarity {
            ClarityFloatingBarFamily(currentTab: $currentTab)
        } else if settings.globalThemeId == .manga {
            VStack {
                Spacer()
                UnifiedFloatingBar(currentTab: $currentTab)
                    .iPadContentWidth(600)
                    .padding(.horizontal, DeviceLayout.isPad ? 40 : 6)
                    .padding(.bottom, 0)
            }
        } else {
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

            case .flux:
                VStack {
                    Spacer()
                    FluxFloatingBar(currentTab: $currentTab)
                        .iPadContentWidth(600)
                        .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
                        .padding(.bottom, 6)
                }

            case .liquid:
                VStack {
                    Spacer()
                    LiquidFloatingBar(currentTab: $currentTab)
                        .iPadContentWidth(600)
                        .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
                        .padding(.bottom, 6)
                }

            case .rivePulse:
                VStack {
                    Spacer()
                    RivePulseFloatingBar(currentTab: $currentTab)
                        .iPadContentWidth(600)
                        .padding(.horizontal, DeviceLayout.isPad ? 40 : 18)
                        .padding(.bottom, 6)
                }

            case .vinylNeedle, .cassette, .orbit, .waveform, .filmstrip, .studioMeter:
                VStack {
                    Spacer()
                    SignatureFloatingBar(
                        currentTab: $currentTab,
                        kind: SignatureFloatingBarKind(style: settings.floatingBarStyle)
                    )
                    .iPadContentWidth(600)
                    .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
                    .padding(.bottom, 6)
                }

            }
        }
    }

}

// MARK: - 紧凑迷你播放器容器（隔离 PlayerManager + PlaybackTimePublisher 订阅）

@MainActor
private struct ContentViewCompactPlayerContainer: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @ObservedObject private var textInputActivity = MonoTextInputActivity.shared

    /// iOS 26+ 时改用 `.tabViewBottomAccessory` 原生嵌入，这里跳过避免重复显示
    private var shouldUseNativeBottomAccessory: Bool {
        if #available(iOS 26.0, *) {
            return settings.useSystemTabBar && settings.globalThemeId != .manga
        }
        return false
    }

    var body: some View {
        if !shouldUseNativeBottomAccessory,
           settings.useSystemTabBar && settings.globalThemeId != .manga && !player.isTabBarHidden,
           !textInputActivity.isEditing,
           let song = player.currentSong
        {
            VStack {
                Spacer()
                CompactMiniPlayerView(song: song)
                    .themeRenderInteractiveLayer()
                    .id("compact-mini-\(settings.globalThemeId.rawValue)-\(settings.globalThemeRevision)")
                    .iPadContentWidth(600)
                    .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
                    .padding(.bottom, DeviceLayout.isPad ? 72 : 62)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(9)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: player.isTabBarHidden)
            .animation(MonoAnimation.floatingBar, value: settings.globalThemeRevision)
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
@MainActor
private struct SystemTabBarWithAccessory<Content: View>: View {
    let content: () -> Content
    @State private var playlistPresented = false
    @ObservedObject private var textInputActivity = MonoTextInputActivity.shared

    var body: some View {
        content()
            .tabBarMinimizeBehavior(.onScrollDown)
            .tabViewBottomAccessory {
                if !textInputActivity.isEditing {
                    TabViewBottomMiniPlayer(playlistPresented: $playlistPresented)
                }
            }
            // sheet 挂在 TabView 层而不是 accessory 内部，避免按钮一点就被关
            .monoSheet(isPresented: $playlistPresented, preset: .standard) {
                Group {
                    if PlayerManager.shared.isPlayingPodcast {
                        PodcastPlaylistPopupView()
                    } else {
                        PlaylistPopupView()
                    }
                }
            }
    }
}

// MARK: - iOS 26 的 TabView bottomAccessory 迷你播放器

/// 原生嵌入在 TabBar 顶部的 Liquid Glass 胶囊迷你播放器。
/// 文字使用 `.primary` / `.secondary` 语义色，系统会根据 Liquid Glass 背景
/// 自动补偿对比度（浅色背景自动变深色字、反之亦然）。
@available(iOS 26.0, *)
@MainActor
private struct TabViewBottomMiniPlayer: View {
    @Binding var playlistPresented: Bool
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var themeManager = GlobalThemeManager.shared

    private var hasActiveSong: Bool {
        player.currentSong != nil && !player.isTabBarHidden
    }

    private var accent: Color {
        themeManager.provider(for: settings.globalThemeId).colorPalette.accent
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
                TabBottomAccessoryContent(
                    song: song,
                    accent: accent,
                    playlistPresented: $playlistPresented
                )
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
/// - 不抢戏：使用 Apple Music 式静态唱片占位，不制造持续动画
/// - 有召唤感：主标题与探索提示保持两级信息层次
/// - 可操作：整条胶囊可点击，发送 `SwitchToHome` 通知跳回首页发现音乐
@available(iOS 26.0, *)
private struct TabBottomAccessoryPlaceholder: View {
    private var primaryTextColor: Color {
        Color(uiColor: .label)
    }

    private var secondaryTextColor: Color {
        Color(uiColor: .secondaryLabel)
    }

    private var tertiaryTextColor: Color {
        Color(uiColor: .tertiaryLabel)
    }

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .init("SwitchToHome"), object: nil)
        } label: {
            HStack(spacing: 12) {
                idleIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("not_playing", comment: "未在播放"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)

                    Text(NSLocalizedString("not_playing_subtitle", comment: "点此探索音乐"))
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                MonoIcon(icon: .chevronRight, size: 12, color: tertiaryTextColor)
                    .frame(width: 20, height: 30)
            }
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var idleIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(uiColor: .quaternarySystemFill))
                .frame(width: 36, height: 36)

            MonoIcon(icon: .musicNote, size: 15, color: tertiaryTextColor)
        }
    }
}

/// iOS 26 bottomAccessory 里的紧凑播放器内容。
/// - 颜色使用 UIKit 动态语义色（`UIColor.label` / `UIColor.secondaryLabel`），
///   跟随系统 TabBar 所在窗口的 trait 反色，避免浅色 TabBar 背景下出现"白字"。
/// - 图标全部走自定义 `MonoIcon`，和 `CompactMiniPlayerView` 视觉一致。
/// - 支持左右滑动切歌（`swipeToSkip()`：右滑下一首、左滑上一首）。
/// - 歌名/歌词使用 `MarqueeText` 跑马灯滚动，不再缩略。
@available(iOS 26.0, *)
@MainActor
private struct TabBottomAccessoryContent: View {
    let song: Song
    let accent: Color
    @Binding var playlistPresented: Bool
    @ObservedObject private var player = FloatingBarPlaybackModel.shared

    private var subtitleText: String {
        if let text = player.lyricLineText {
            return text
        }
        return song.artistName
    }

    /// iOS 的 bottomAccessory 会让系统 TabBar 根据窗口级 userInterfaceStyle
    /// 渲染背景；用 UIKit 动态色可保证文字和系统 TabBar 背景一致。
    private var primaryTextColor: Color {
        Color(uiColor: .label)
    }

    private var secondaryTextColor: Color {
        Color(uiColor: .secondaryLabel)
    }

    /// 进度条颜色 — 跟随系统 Liquid Glass 背景自动适配亮/暗
    private var progressTrackColor: Color {
        Color(uiColor: .quaternaryLabel)
    }

    private var progressFillColors: [Color] {
        [accent.opacity(0.64), accent]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(
                        text: song.name,
                        font: .system(size: 14, weight: .semibold),
                        color: primaryTextColor,
                        speed: 25
                    )
                    .frame(height: 17)

                    MarqueeText(
                        text: subtitleText,
                        font: .system(size: 11.5, weight: .regular),
                        color: secondaryTextColor,
                        speed: 25
                    )
                    .frame(height: 15)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                Button(action: { player.togglePlayPause() }) {
                    MonoIcon(
                        icon: player.isPlaying ? .pause : .play,
                        size: 17,
                        color: primaryTextColor
                    )
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    player.isPlaying ? String(localized: "暂停") : String(localized: "action_play")
                )

                Button(action: { player.next() }) {
                    MonoIcon(icon: .next, size: 16, color: primaryTextColor)
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "playback_next_track"))

                Button(action: { playlistPresented = true }) {
                    MonoIcon(
                        icon: .list,
                        size: 14,
                        color: secondaryTextColor
                    )
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "player_queue"))
            }
            .padding(.horizontal, 10)

            MiniPlayerProgressStrip(
                height: 2,
                minFillWidth: 4,
                trackColor: progressTrackColor,
                strokeColor: .clear,
                fillColors: progressFillColors
            )
                .padding(.horizontal, 10)
                .padding(.top, 3)
                .padding(.bottom, 1)
        }
        .contentShape(Rectangle())
        .swipeToSkip()
        .onTapGesture {
            withAnimation(MonoAnimation.playerTransition) {
                switch player.playSource {
                case .fm:
                    NotificationCenter.default.post(name: .init("OpenFMPlayer"), object: nil)
                case let .podcast(radioId):
                    NotificationCenter.default.post(name: .init("OpenRadioPlayer"), object: radioId)
                case .normal:
                    NotificationCenter.default.post(name: .init("OpenNormalPlayer"), object: nil)
                }
            }
        }
    }
}

// MARK: - 紧凑迷你播放器（独立视图，隔离高频订阅）

@MainActor
private struct CompactMiniPlayerView: View {
    let song: Song
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showCompactPlaylist = false

    private var subtitleText: String {
        if let text = player.lyricLineText {
            return text
        }
        return song.artistName
    }

    private var compactProgressTrackColor: Color {
        systemColorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.07)
    }

    private var compactProgressFillColors: [Color] {
        [Color.monoAccent.opacity(0.64), Color.monoAccent]
    }

    private var primaryTextColor: Color {
        Color(uiColor: .label)
    }

    private var secondaryTextColor: Color {
        Color(uiColor: .secondaryLabel)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(
                        text: song.name,
                        font: .system(size: 14, weight: .semibold),
                        color: primaryTextColor,
                        speed: 25
                    )
                    .frame(height: 17)

                    MarqueeText(
                        text: subtitleText,
                        font: .system(size: 11.5, weight: .regular),
                        color: secondaryTextColor,
                        speed: 22
                    )
                    .frame(height: 15)
                    .animation(.easeInOut(duration: 0.25), value: player.lyricLineText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                HStack(spacing: 2) {
                    Button(action: { player.togglePlayPause() }) {
                        MonoIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 18,
                            color: primaryTextColor
                        )
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        player.isPlaying ? String(localized: "暂停") : String(localized: "action_play")
                    )

                    Button(action: { player.next() }) {
                        MonoIcon(icon: .next, size: 17, color: primaryTextColor)
                            .frame(width: 40, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "playback_next_track"))

                    Button(action: { showCompactPlaylist = true }) {
                        MonoIcon(icon: .list, size: 14, color: secondaryTextColor)
                            .frame(width: 36, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "player_queue"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)

            MiniPlayerProgressStrip(
                height: 2,
                minFillWidth: 4,
                trackColor: compactProgressTrackColor,
                strokeColor: .clear,
                fillColors: compactProgressFillColors
            )
                .padding(.horizontal, 12)
                .padding(.bottom, 5)
        }
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            Color(uiColor: .systemBackground)
                                .opacity(systemColorScheme == .dark ? 0.30 : 0.52)
                        )
                }
                .shadow(
                    color: Color.black.opacity(systemColorScheme == .dark ? 0.24 : 0.10),
                    radius: 12,
                    x: 0,
                    y: 5
                )
        }
        .contentShape(Rectangle())
        .swipeToSkip()
        .onTapGesture {
            withAnimation(MonoAnimation.playerTransition) {
                switch player.playSource {
                case .fm:
                    NotificationCenter.default.post(name: .init("OpenFMPlayer"), object: nil)
                case let .podcast(radioId):
                    NotificationCenter.default.post(name: .init("OpenRadioPlayer"), object: radioId)
                case .normal:
                    NotificationCenter.default.post(name: .init("OpenNormalPlayer"), object: nil)
                }
            }
        }
        .monoSheet(isPresented: $showCompactPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }
}

@MainActor
private struct MiniPlayerProgressStrip: View {
    let height: CGFloat
    let minFillWidth: CGFloat
    let trackColor: Color
    let strokeColor: Color
    let fillColors: [Color]

    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared

    var body: some View {
        GlobalPlaybackProgressBar(
            progress: CGFloat(timePublisher.progress),
            height: height,
            minFillWidth: minFillWidth,
            trackColor: trackColor,
            strokeColor: strokeColor,
            fillColors: fillColors
        )
    }
}

// MARK: - Tab Enum

enum Tab: Int, CaseIterable, Hashable {
    case home = 0
    case podcast = 1
    case library = 2
    case profile = 3

    var icon: MonoIcon.IconType {
        switch self {
        case .home: return .homeFilled
        case .podcast: return .podcastFilled
        case .library: return .libraryFilled
        case .profile: return .profileFilled
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
