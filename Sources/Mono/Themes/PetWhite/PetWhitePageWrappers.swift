import SwiftUI

private enum PetWhitePageIdentity {
    case home
    case podcast
    case search
    case library
    case profile
    case localHome
    case localMusic
    case localLibrary
    case localProfile

    var tag: String {
        switch self {
        case .home: return "HOME"
        case .podcast: return "POD"
        case .search: return "SNIFF"
        case .library: return "BOX"
        case .profile: return "ME"
        case .localHome: return "LOCAL"
        case .localMusic: return "MUSIC"
        case .localLibrary: return "FILES"
        case .localProfile: return "SET"
        }
    }

    var icon: MonoIcon.IconType {
        switch self {
        case .home, .localHome: return .homeFilled
        case .podcast: return .podcastFilled
        case .search: return .magnifyingGlass
        case .library, .localLibrary: return .library
        case .profile, .localProfile: return .profileFilled
        case .localMusic: return .musicNoteList
        }
    }

    var mascot: PetWhiteMascotMark.Kind {
        switch self {
        case .podcast, .localMusic:
            return .dog
        case .search, .profile, .localProfile:
            return .cat
        default:
            return .pair
        }
    }

    var tint: Color {
        switch self {
        case .home, .localHome: return PetWhiteStyle.dogOrange
        case .podcast, .localMusic: return PetWhiteStyle.mint
        case .search: return PetWhiteStyle.sky
        case .library, .localLibrary: return PetWhiteStyle.butter
        case .profile, .localProfile: return PetWhiteStyle.blush.opacity(0.78)
        }
    }
}

private struct PetWhiteThemeRoot<Content: View>: View {
    let page: PetWhitePageIdentity
    let content: () -> Content
    @ObservedObject private var settings = SettingsManager.shared

    init(page: PetWhitePageIdentity, @ViewBuilder content: @escaping () -> Content) {
        self.page = page
        self.content = content
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        content()
            .tint(PetWhiteStyle.accent)
            .themeRenderSceneLayer()
            .background(PetWhiteRootBackdrop())
    }
}

private struct PetWhitePageChrome: View {
    let page: PetWhitePageIdentity

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PetWhiteSideRail(page: page)
                    .padding(.top, max(proxy.safeAreaInsets.top + 76, 92))
                    .padding(.leading, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                PetWhiteCornerTag(page: page)
                    .padding(.top, max(proxy.safeAreaInsets.top + 12, 22))
                    .padding(.trailing, DeviceLayout.usesExpandedLayout ? 30 : 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct PetWhiteSideRail: View {
    let page: PetWhitePageIdentity

    var body: some View {
        VStack(spacing: 12) {
            PetWhiteMascotMark(kind: page.mascot, size: 30)

            VStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    PetWhitePawPrint(
                        size: index.isMultiple(of: 2) ? 18 : 14,
                        tint: index.isMultiple(of: 2) ? page.tint.opacity(0.45) : PetWhiteStyle.ink.opacity(0.08)
                    )
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -12 : 12))
                }
            }
        }
        .opacity(0.92)
    }
}

private struct PetWhiteCornerTag: View {
    let page: PetWhitePageIdentity

    var body: some View {
        HStack(spacing: 8) {
            PetWhitePackIcon(icon: page.icon, size: 18, visualScale: 1.08)

            Text(page.tag)
                .font(PetWhiteStyle.labelFont(10, weight: .black))
                .foregroundStyle(PetWhiteStyle.ink)
                .tracking(1.0)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(page.tint)
                .overlay(Capsule(style: .continuous).stroke(PetWhiteStyle.separator, lineWidth: 1))
        )
    }
}

struct PetWhiteHomeView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var cacheManager = OptimizedCacheManager.shared
    @ObservedObject private var refreshManager = GlobalRefreshManager.shared
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigationPath = NavigationPath()
    @State private var showPersonalFM = false
    @State private var bannerWebURL: PetWhiteWebDestination?
    @State private var appeared = false
    @State private var emptyHomeRecoveryAttempts = 0
    @State private var homeRenderRevision = 0
    @State private var renderedHitokotoText = ""
    @State private var hitokotoRefreshRotation: Double = 0
    @State private var didRunInitialRenderedHomeDataSync = false
    @State private var didActivateHome = false
    private let maxEmptyHomeRecoveryAttempts = 8

    var body: some View {
        let _ = settings.globalThemeRevision

        PetWhiteThemeRoot(page: .home) {
            NavigationStack(path: $navigationPath) {
                presentedContent
            }
        }
    }

    private var navigationContent: AnyView {
        AnyView(
            ZStack {
                PetWhiteRootBackdrop()
                    .ignoresSafeArea()

                scrollBody
                    .zIndex(1)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        )
    }

    private var activationObservedContent: AnyView {
        AnyView(
            navigationContent
                .task {
                    guard await MainTabActivationGate.waitUntilSettled(.home) else { return }
                    await activateHomeIfNeeded(reason: "pet white home appear")
                }
                .onReceive(NotificationCenter.default.publisher(for: .mainTabDidSettle)) { notification in
                    guard notification.object as? Tab == .home,
                          MainTabActivationGate.isSettled(.home) else { return }
                    Task { @MainActor in
                        await activateHomeIfNeeded(reason: "pet white home selected")
                    }
                }
                .onChange(of: settings.globalThemeRevision) { _, _ in
                    guard MainTabActivationGate.isSettled(.home) else { return }
                    appeared = false
                    didRunInitialRenderedHomeDataSync = false
                    emptyHomeRecoveryAttempts = 0
                    syncPetWhiteHitokoto(reason: "pet white theme revision")
                    syncRenderedHomeData(reason: "pet white theme revision")
                    hydratePetWhiteHome(reason: "pet white theme revision")
                    recoverEmptyHomeIfNeeded(reason: "pet white theme empty recovery")
                    scheduleEmptyStateReveal(reason: "pet white theme revision")
                    invalidateHomeRender()
                    revealHomeContent()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active,
                          MainTabActivationGate.isSettled(.home) else { return }
                    emptyHomeRecoveryAttempts = 0
                    syncPetWhiteHitokoto(reason: "pet white foreground")
                    syncRenderedHomeData(reason: "pet white foreground")
                    refreshPetWhiteHitokotoIfNeeded(reason: "pet white foreground")
                    hydratePetWhiteHome(reason: "pet white foreground")
                    recoverEmptyHomeIfNeeded(reason: "pet white foreground empty recovery")
                    scheduleEmptyStateReveal(reason: "pet white foreground")
                    invalidateHomeRender()
                    revealHomeContent()
                }
                .onChange(of: isHomeDataEmpty) { _, isEmpty in
                    guard MainTabActivationGate.isSettled(.home) else { return }
                    if isEmpty {
                        scheduleEmptyStateReveal(reason: "pet white empty appeared")
                        recoverEmptyHomeIfNeeded(reason: "pet white empty appeared")
                    } else {
                        emptyHomeRecoveryAttempts = 0
                        hideEmptyState()
                    }
                }
                .onChange(of: viewModel.isLoading) { _, isLoading in
                    guard !isLoading,
                          MainTabActivationGate.isSettled(.home) else { return }
                    syncRenderedHomeData(reason: "pet white loading completed")
                    if isHomeDataEmpty {
                        scheduleEmptyStateReveal(reason: "pet white loading completed empty")
                        recoverEmptyHomeIfNeeded(reason: "pet white loading completed empty")
                    } else {
                        emptyHomeRecoveryAttempts = 0
                        hideEmptyState()
                    }
                    invalidateHomeRender()
                }
        )
    }

    private var dataObservedContent: AnyView {
        AnyView(
            activationObservedContent
                .onReceive(viewModel.$homeContentRevision) { _ in
                    guard MainTabActivationGate.isSettled(.home) else { return }
                    syncRenderedHomeData(reason: "pet white content revision")
                    if !isHomeDataEmpty {
                        emptyHomeRecoveryAttempts = 0
                        hideEmptyState()
                    }
                    invalidateHomeRender()
                }
                .onReceive(viewModel.$hitokoto) { hitokoto in
                    guard MainTabActivationGate.isSettled(.home) else { return }
                    syncPetWhiteHitokoto(hitokoto, reason: "pet white hitokoto updated")
                }
                .onReceive(viewModel.$userProfile) { _ in
                    guard MainTabActivationGate.isSettled(.home) else { return }
                    invalidateHomeRender()
                }
                .onChange(of: settings.hitokotoEnabled) { _, _ in
                    guard MainTabActivationGate.isSettled(.home) else { return }
                    syncPetWhiteHitokoto(reason: "pet white hitokoto setting changed")
                    refreshPetWhiteHitokotoIfNeeded(reason: "pet white hitokoto setting changed")
                }
                .onChange(of: viewModel.popularSongs.count) { _, _ in
                    guard MainTabActivationGate.isSettled(.home) else { return }
                    syncRenderedHomeData(reason: "pet white popular songs updated")
                    if !isHomeDataEmpty {
                        hideEmptyState()
                    }
                    invalidateHomeRender()
                }
        )
    }

    private var presentedContent: AnyView {
        AnyView(
            dataObservedContent
                .onChange(of: cacheManager.isPreloading) { _, isPreloading in
                    guard !isPreloading,
                          MainTabActivationGate.isSettled(.home) else { return }
                    syncRenderedHomeData(reason: "pet white cache preload completed")
                    if isHomeDataEmpty {
                        emptyHomeRecoveryAttempts = 0
                        viewModel.reloadHomeCacheIfUseful(reason: "pet white cache preload completed")
                        hydratePetWhiteHome(reason: "pet white cache preload completed")
                        recoverEmptyHomeIfNeeded(reason: "pet white cache preload empty recovery")
                        scheduleEmptyStateReveal(reason: "pet white cache preload completed")
                    }
                    invalidateHomeRender()
                }
                .onChange(of: refreshManager.isPreloading) { _, isPreloading in
                    guard !isPreloading,
                          MainTabActivationGate.isSettled(.home) else { return }
                    syncRenderedHomeData(reason: "pet white launch preload completed")
                    if isHomeDataEmpty {
                        emptyHomeRecoveryAttempts = 0
                        viewModel.reloadHomeCacheIfUseful(reason: "pet white launch preload completed")
                        hydratePetWhiteHome(reason: "pet white launch preload completed")
                        recoverEmptyHomeIfNeeded(reason: "pet white launch preload empty recovery")
                        scheduleEmptyStateReveal(reason: "pet white launch preload completed")
                    }
                    invalidateHomeRender()
                }
                .onChange(of: onlineAccess.lastTokenStatus) { _, _ in
                    guard onlineAccess.canUseOnlineFeatures,
                          MainTabActivationGate.isSettled(.home) else { return }
                    emptyHomeRecoveryAttempts = 0
                    syncRenderedHomeData(reason: "pet white online access refreshed")
                    hydratePetWhiteHome(reason: "pet white online access refreshed")
                    recoverEmptyHomeIfNeeded(reason: "pet white online access empty recovery")
                    scheduleEmptyStateReveal(reason: "pet white online access refreshed")
                    invalidateHomeRender()
                }
                .onChange(of: onlineAccess.isVerifying) { _, isVerifying in
                    guard !isVerifying,
                          onlineAccess.canUseOnlineFeatures,
                          MainTabActivationGate.isSettled(.home) else { return }
                    emptyHomeRecoveryAttempts = 0
                    syncRenderedHomeData(reason: "pet white online verification completed")
                    hydratePetWhiteHome(reason: "pet white online verification completed")
                    recoverEmptyHomeIfNeeded(reason: "pet white online verification empty recovery")
                    scheduleEmptyStateReveal(reason: "pet white online verification completed")
                    invalidateHomeRender()
                }
                .navigationDestination(for: HomeView.HomeDestination.self, destination: destinationView)
                .fullScreenCover(isPresented: $showPersonalFM) {
                    PersonalFMView()
                }
                .fullScreenCover(item: $bannerWebURL) { url in
                    MonoWebView(url: url.url, title: nil)
                }
        )
    }

    private var isInitialHomeLoading: Bool {
        isHomeDataEmpty
            && (viewModel.isLoading || cacheManager.isPreloading || refreshManager.isPreloading)
    }

    private var isHomeDataEmpty: Bool {
        displayHomeData.isEmpty
    }

    private var expectsUserProfile: Bool {
        (UserDefaults.standard.bool(forKey: AppConfig.StorageKeys.isLoggedIn)
            || APIService.shared.currentCookie != nil
            || APIService.shared.currentUserId != nil)
            && onlineAccess.hasStoredToken
    }

    private var homeDataIdentity: String {
        [
            displayHomeData.fingerprint,
            "loading-\(viewModel.isLoading)",
            "content-\(viewModel.homeContentRevision)",
            "profile-\(viewModel.displayedIdentityProfile?.userId ?? 0)-\(viewModel.displayedIdentityProfile?.nickname ?? "none")",
        ].joined(separator: "|")
    }

    private var homeRenderIdentity: String {
        "\(homeDataIdentity)|render-\(homeRenderRevision)"
    }

    private func activateHomeIfNeeded(reason: String) async {
        guard !didActivateHome else { return }
        didActivateHome = true
        viewModel.reloadHomeCacheForVisibleHomeIfNeeded(reason: "\(reason) cache sync")
        syncPetWhiteHitokoto(reason: reason)
        syncRenderedHomeData(reason: reason)
        invalidateHomeRender()
        revealHomeContent()
        guard !didRunInitialRenderedHomeDataSync else { return }
        didRunInitialRenderedHomeDataSync = true
        refreshPetWhiteHitokotoIfNeeded(reason: reason)
        hydratePetWhiteHome(reason: reason)
        recoverEmptyHomeIfNeeded(reason: "\(reason) empty")
        scheduleEmptyStateReveal(reason: reason)
        await runInitialRenderedHomeDataSync()
    }

    private func hydratePetWhiteHome(reason: String) {
        viewModel.ensureHomeDataLoaded(reason: reason)
        syncRenderedHomeData(reason: "\(reason) sync")
        if !isHomeDataEmpty {
            emptyHomeRecoveryAttempts = 0
            hideEmptyState()
        }
    }

    private func recoverEmptyHomeIfNeeded(reason: String) {
        guard isHomeDataEmpty, !viewModel.isLoading, emptyHomeRecoveryAttempts < maxEmptyHomeRecoveryAttempts else { return }
        emptyHomeRecoveryAttempts += 1
        invalidateHomeRender()
        viewModel.retryHomeDataLoad(reason: reason, resetsEmptyRecovery: false)
    }

    private func retryPetWhiteHome(reason: String) {
        emptyHomeRecoveryAttempts = 0
        hideEmptyState()
        scheduleEmptyStateReveal(reason: reason)
        invalidateHomeRender()
        viewModel.retryHomeDataLoad(reason: reason)
    }

    private func refreshPetWhiteHitokotoIfNeeded(reason: String) {
        guard settings.hitokotoEnabled else { return }

        let current = viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard current.isEmpty else { return }
        viewModel.refreshHitokoto(force: true)
        AppLogger.debug("PetWhiteHomeView: 检查每日一言 - \(reason)")
    }

    private func invalidateHomeRender() {
        homeRenderRevision += 1
    }

    private func syncPetWhiteHitokoto(reason: String) {
        syncPetWhiteHitokoto(viewModel.hitokoto, reason: reason)
    }

    private func syncPetWhiteHitokoto(_ hitokoto: String?, reason: String) {
        let nextText: String
        if settings.hitokotoEnabled {
            nextText = hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } else {
            nextText = ""
        }

        guard nextText != renderedHitokotoText else { return }

        renderedHitokotoText = nextText
        AppLogger.debug("PetWhiteHomeView: 每日一言渲染刷新 - \(reason)")
    }

    private func syncRenderedHomeData(reason: String) {
        let snapshot = displayHomeData
        if !snapshot.isEmpty {
            emptyHomeRecoveryAttempts = 0
            hideEmptyState()
        }
        invalidateHomeRender()
        AppLogger.debug("PetWhiteHomeView: 首页实时数据刷新 - \(reason) - \(snapshot.fingerprint)")
    }

    private var displayHomeData: PetWhiteHomeDataSnapshot {
        PetWhiteHomeDataSnapshot(
            dailySongs: firstNonEmpty(
                nonEmpty(viewModel.dailySongs, cacheKey: "daily_songs", type: [Song].self),
                nonEmpty(viewModel.popularSongs, cacheKey: "popular_songs", type: [Song].self)
            ),
            banners: nonEmpty(viewModel.banners, cacheKey: "banners", type: [Banner].self),
            recommendPlaylists: nonEmpty(viewModel.recommendPlaylists, cacheKey: "recommend_playlists", type: [Playlist].self),
            qqRecommendPlaylists: viewModel.qqRecommendPlaylists,
            qqNewSongs: viewModel.qqNewSongs
        )
    }

    private func nonEmpty<T: Codable>(_ source: [T], cacheKey: String, type: [T].Type) -> [T] {
        if !source.isEmpty {
            return source
        }
        return OptimizedCacheManager.shared.getObject(forKey: cacheKey, type: type) ?? []
    }

    private func firstNonEmpty<T>(_ candidates: [T]...) -> [T] {
        candidates.first { !$0.isEmpty } ?? []
    }

    private func runInitialRenderedHomeDataSync() async {
        for attempt in 0..<28 {
            if Task.isCancelled { return }

            await MainActor.run {
                viewModel.reloadHomeCacheForVisibleHomeIfNeeded(reason: "pet white startup sync \(attempt)")
                syncRenderedHomeData(reason: "pet white startup sync \(attempt)")
                syncPetWhiteHitokoto(reason: "pet white startup sync \(attempt)")
            }

            let hasContent = await MainActor.run {
                !displayHomeData.isEmpty
                    && (!settings.hitokotoEnabled || !renderedHitokotoText.isEmpty)
                    && (!expectsUserProfile || viewModel.displayedIdentityProfile != nil)
            }
            if hasContent { return }

            try? await Task.sleep(nanoseconds: 220_000_000)
        }
    }

    private func scheduleEmptyStateReveal(reason: String) {
        hideEmptyState()
    }

    private func hideEmptyState() {}

    private func revealHomeContent() {
        guard !appeared else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86).delay(0.04)) {
            appeared = true
        }
    }

    private var scrollBody: some View {
        let homeData = displayHomeData
        // 读取渲染版本号：缓存回退数据（getObject）不可观察，靠版本号驱动重算。
        // 注意只做依赖读取，不能当 .id 用 —— id 变化会整棵重建 ScrollView，
        // 冷启动时版本号连续跳变十几次，曾导致首页整页空白。
        let _ = homeRenderRevision

        return ScrollView {
            VStack(spacing: 30) {
                heroPanel
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .petWhiteAppear(appeared, order: 0)

                quickActionBoard
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .petWhiteAppear(appeared, order: 1)

                if !homeData.banners.isEmpty {
                    PetWhiteBannerCarousel(
                        banners: homeData.banners,
                        onTap: handleBannerTap
                    )
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .petWhiteAppear(appeared, order: 2)
                }

                if isInitialHomeLoading {
                    PetWhiteLoadingView()
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                        .petWhiteAppear(appeared, order: 3)
                } else if isHomeDataEmpty {
                    // 加载已结束但数据仍为空：给出可点重试的空态，而不是无限转圈
                    PetWhiteHomeEmptyState {
                        retryPetWhiteHome(reason: "pet white empty retry tap")
                    }
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .petWhiteAppear(appeared, order: 3)
                }

                if !homeData.dailySongs.isEmpty {
                    dailyTreats
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .petWhiteAppear(appeared, order: 4)
                }

                if !homeData.recommendPlaylists.isEmpty {
                    PetWhitePlaylistShelf(
                        title: String(localized: "recommended_playlists"),
                        detail: String(localized: "based_on_taste"),
                        playlists: homeData.recommendPlaylists,
                        tint: PetWhiteStyle.butter,
                        icon: .library,
                        onViewAll: openLibrarySquare,
                        onTap: { playlist in navigationPath.append(HomeView.HomeDestination.playlist(playlist)) }
                    )
                    .petWhiteAppear(appeared, order: 5)
                }

                if !homeData.qqRecommendPlaylists.isEmpty {
                    PetWhitePlaylistShelf(
                        title: "QCM",
                        detail: String(localized: "更多发现"),
                        playlists: homeData.qqRecommendPlaylists,
                        tint: PetWhiteStyle.sky,
                        icon: .podcast,
                        assetName: "qqMusic",
                        onViewAll: openLibrarySquare,
                        onTap: { playlist in navigationPath.append(HomeView.HomeDestination.playlist(playlist)) }
                    )
                    .petWhiteAppear(appeared, order: 6)
                }

                if !homeData.qqNewSongs.isEmpty {
                    PetWhiteNewSongsBoard(
                        songs: homeData.qqNewSongs,
                        onViewAll: { navigationPath.append(HomeView.HomeDestination.qcmNewSongs) },
                        onPlay: { song in PlayerManager.shared.play(song: song, in: homeData.qqNewSongs) }
                    )
                    .petWhiteAppear(appeared, order: 7)
                }

                FloatingBarBottomSpacer()
            }
            .padding(.top, DeviceLayout.headerTopPadding + 14)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
        .refreshable {
            retryPetWhiteHome(reason: "pet white pull refresh")
            viewModel.refreshHitokoto(force: true)
        }
    }

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                PetWhitePetPetHeroIcon(width: petPetHeroWidth)

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: LocalizedStringResource(stringLiteral: MonoTimeGreeting.localizedKey)))
                        .font(PetWhiteStyle.labelFont(12, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(PetWhiteStyle.dogEar)
                        .lineLimit(1)

                    Text(viewModel.displayedIdentityProfile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(PetWhiteStyle.titleFont(32, weight: .bold))
                        .foregroundStyle(PetWhiteStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                Button {
                    NotificationCenter.default.post(name: .init("SwitchToProfile"), object: nil)
                } label: {
                    avatarView
                }
                .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.92))
            }

            if settings.hitokotoEnabled {
                HStack(alignment: .center, spacing: 12) {
                    Capsule()
                        .fill(PetWhiteStyle.dogOrange.opacity(0.7))
                        .frame(width: 3)
                        .frame(maxHeight: .infinity)

                    Text(petWhiteHitokotoText.isEmpty ? HitokotoFallbackSlogan.text : petWhiteHitokotoText)
                        .font(PetWhiteStyle.bodyFont(14))
                        .foregroundStyle(PetWhiteStyle.inkSoft)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        refreshPetWhiteHitokotoWithFeedback()
                    } label: {
                        PetWhitePackIcon(icon: .refresh, size: 18, visualScale: 1.04, fallbackColor: PetWhiteStyle.inkMuted)
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(hitokotoRefreshRotation))
                            .animation(.linear(duration: 0.58), value: hitokotoRefreshRotation)
                    }
                    .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.92))
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 4)
            }
        }
        .padding(.top, 4)
        .padding(settings.petWhiteUsesIllustratedBackground ? 14 : 0)
        .background {
            if settings.petWhiteUsesIllustratedBackground {
                RoundedRectangle(cornerRadius: PetWhiteStyle.cardRadius, style: .continuous)
                    .fill(PetWhiteStyle.surfaceRaised.opacity(0.82))
                    .overlay(
                        RoundedRectangle(cornerRadius: PetWhiteStyle.cardRadius, style: .continuous)
                            .strokeBorder(PetWhiteStyle.stroke, lineWidth: 1)
                    )
            }
        }
    }

    private var petWhiteHitokotoText: String {
        renderedHitokotoText
    }

    private var petPetHeroWidth: CGFloat {
        if DeviceLayout.usesExpandedLayout { return 144 }
        return DeviceLayout.viewportWidth < 360 ? 104 : 118
    }

    private func refreshPetWhiteHitokotoWithFeedback() {
        withAnimation(.linear(duration: 0.58)) {
            hitokotoRefreshRotation += 360
        }
        viewModel.refreshHitokoto(force: true)
    }

    @ViewBuilder
    private var avatarView: some View {
        let size: CGFloat = 48
        if let avatarUrl = viewModel.displayedIdentityProfile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url) {
                PetWhiteMascotMark(kind: .cat, size: size)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1))
        } else {
            PetWhiteMascotMark(kind: .cat, size: size)
        }
    }

    private var quickActionBoard: some View {
        VStack(spacing: 14) {
            PetWhiteMeditationRoute {
                navigationPath.append(HomeView.HomeDestination.meditationMode)
            }

            HStack(spacing: 12) {
                PetWhiteQuickAction(title: "FM", icon: .fm, tint: PetWhiteStyle.dogOrange) {
                    showPersonalFM = true
                }
                PetWhiteQuickAction(title: String(localized: "action_search"), icon: .magnifyingGlass, tint: PetWhiteStyle.sky) {
                    navigationPath.append(HomeView.HomeDestination.search)
                }
                PetWhiteQuickAction(title: String(localized: "new_song_express"), icon: .musicNote, tint: PetWhiteStyle.mint) {
                    navigationPath.append(HomeView.HomeDestination.newSongExpress)
                }
                PetWhiteQuickAction(title: "MV", icon: .mv, tint: PetWhiteStyle.butter) {
                    navigationPath.append(HomeView.HomeDestination.mvDiscover)
                }
            }
        }
    }

    private var dailyTreats: some View {
        let songs = displayHomeData.dailySongs

        return VStack(alignment: .leading, spacing: 14) {
            PetWhiteSectionTitle(
                title: String(localized: "daily_recommend"),
                detail: String(localized: "今天的第一口音乐"),
                icon: .musicNote,
                tint: PetWhiteStyle.mint,
                action: { navigationPath.append(HomeView.HomeDestination.dailyRecommend) }
            )

            VStack(spacing: 0) {
                ForEach(Array(songs.prefix(4).enumerated()), id: \.element.id) { index, song in
                    Button {
                        PlayerManager.shared.play(song: song, in: songs)
                    } label: {
                        PetWhiteSongTreatRow(index: index + 1, song: song)
                    }
                    .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.965))

                    if index < min(songs.count, 4) - 1 {
                        Divider()
                            .overlay(PetWhiteStyle.separator)
                            .padding(.leading, 66)
                    }
                }
            }
            .padding(.horizontal, 6)
            .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.dogOrange))
        }
    }

    private func handleBannerTap(_ banner: Banner) {
        switch banner.targetType {
        case 1:
            Task {
                do {
                    let songs = try await APIService.shared.fetchSongDetails(ids: [banner.targetId]).async()
                    if let song = songs.first {
                        await MainActor.run { PlayerManager.shared.play(song: song, in: [song]) }
                    }
                } catch {
                    AppLogger.error("Banner 歌曲加载失败: \(error)")
                }
            }
        case 10:
            navigationPath.append(HomeView.HomeDestination.album(banner.targetId))
        case 1000:
            let playlist = Playlist(
                id: banner.targetId,
                name: banner.typeTitle ?? String(localized: "home_playlist"),
                coverImgUrl: banner.pic,
                picUrl: nil,
                trackCount: nil,
                playCount: nil,
                subscribedCount: nil,
                shareCount: nil,
                commentCount: nil,
                creator: nil,
                description: nil,
                tags: nil
            )
            navigationPath.append(HomeView.HomeDestination.bannerPlaylist(playlist, banner.pic))
        case 1004:
            navigationPath.append(HomeView.HomeDestination.mvDiscover)
        default:
            if let urlString = banner.url, let url = URL(string: urlString) {
                bannerWebURL = PetWhiteWebDestination(url: url)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: HomeView.HomeDestination) -> some View {
        switch destination {
        case .search:
            SearchView()
        case .dailyRecommend:
            DailyRecommendView()
        case let .playlist(playlist):
            PlaylistDetailView(playlist: playlist)
        case let .bannerPlaylist(playlist, bannerImage):
            PlaylistDetailView(playlist: playlist, bannerCoverURLString: bannerImage)
        case let .artist(id):
            ArtistDetailView(artistId: id)
        case let .album(id):
            AlbumDetailView(albumId: id, albumName: nil, albumCoverUrl: nil)
        case .mvDiscover:
            MVDiscoverView()
        case .newSongExpress:
            NewSongExpressView()
        case .qcmNewSongs:
            QCMNewSongsView()
        case .meditationMode:
            MeditationModeView()
        }
    }

    private func openLibrarySquare() {
        UserDefaults.standard.set(true, forKey: "pendingLibrarySquareSwitch")
        NotificationCenter.default.post(name: .init("SwitchToLibrarySquare"), object: nil)
    }
}

private struct PetWhiteWebDestination: Identifiable {
    let url: URL

    var id: URL { url }
}

private struct PetWhiteMeditationRoute: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                PetWhiteClayPuck(shape: Circle(), tint: PetWhiteStyle.sky)
                    .frame(width: 40, height: 40)
                    .overlay(
                        PetWhitePackIcon(icon: .moon, size: 19, visualScale: 1.05, lineWidth: 1.7)
                    )

                Text(String(localized: "meditation_mode_title"))
                    .font(PetWhiteStyle.titleFont(17, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

                PetWhitePackIcon(icon: .chevronRight, size: 16, visualScale: 1.04, fallbackColor: PetWhiteStyle.inkMuted)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: false, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.sky))
        }
        .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.92))
    }
}

private struct PetWhiteHomeDataSnapshot {
    var dailySongs: [Song] = []
    var banners: [Banner] = []
    var recommendPlaylists: [Playlist] = []
    var qqRecommendPlaylists: [Playlist] = []
    var qqNewSongs: [Song] = []

    var isEmpty: Bool {
        dailySongs.isEmpty
            && banners.isEmpty
            && recommendPlaylists.isEmpty
            && qqRecommendPlaylists.isEmpty
            && qqNewSongs.isEmpty
    }

    var fingerprint: String {
        [
            part("daily", count: dailySongs.count, first: dailySongs.first?.id, last: dailySongs.last?.id),
            part("banner", count: banners.count, first: banners.first?.id, last: banners.last?.id),
            part("ncm-playlist", count: recommendPlaylists.count, first: recommendPlaylists.first?.id, last: recommendPlaylists.last?.id),
            part("qq-playlist", count: qqRecommendPlaylists.count, first: qqRecommendPlaylists.first?.id, last: qqRecommendPlaylists.last?.id),
            part("qq-song", count: qqNewSongs.count, first: qqNewSongs.first?.id, last: qqNewSongs.last?.id),
        ].joined(separator: "|")
    }

    private func part<ID>(_ name: String, count: Int, first: ID?, last: ID?) -> String {
        let firstValue = first.map { String(describing: $0) } ?? "nil"
        let lastValue = last.map { String(describing: $0) } ?? "nil"
        return "\(name)-\(count)-\(firstValue)-\(lastValue)"
    }
}

private struct PetWhiteQuickAction: View {
    let title: String
    let icon: MonoIcon.IconType
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                PetWhiteClayPuck(shape: Circle(), tint: tint)
                    .frame(width: 40, height: 40)
                    .overlay(
                        PetWhitePackIcon(icon: icon, size: 19, visualScale: 1.05, lineWidth: 1.7)
                    )

                Text(title)
                    .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: false, tint: PetWhiteStyle.surfaceRaised, accent: tint))
        }
        .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.92))
    }
}

private struct PetWhiteSongTreatRow: View {
    let index: Int
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(PetWhiteStyle.labelFont(13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(PetWhiteStyle.inkMuted)
                .frame(width: 18, alignment: .center)

            CachedAsyncImage(url: song.coverUrl) {
                PetWhiteMascotMark(kind: index.isMultiple(of: 2) ? .dog : .cat, size: 42)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(PetWhiteStyle.stroke, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(PetWhiteStyle.bodyFont(14, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(PetWhiteStyle.labelFont(11))
                    .foregroundStyle(PetWhiteStyle.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            PetWhitePackIcon(icon: .play, size: 17, visualScale: 1.04, fallbackColor: PetWhiteStyle.inkMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct PetWhiteBannerCarousel: View {
    let banners: [Banner]
    let onTap: (Banner) -> Void

    @State private var bannerIndex = 0
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $bannerIndex) {
                ForEach(Array(banners.prefix(6).enumerated()), id: \.element.id) { index, banner in
                    Button {
                        onTap(banner)
                    } label: {
                        PetWhiteBannerCard(banner: banner)
                    }
                    .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.965))
                    .padding(.horizontal, DeviceLayout.usesExpandedLayout ? 12 : 8)
                    .padding(.vertical, 5)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: DeviceLayout.usesExpandedLayout ? 206 : 176)
            .onReceive(timer) { _ in
                guard MainTabActivationGate.isSettled(.home) else { return }
                guard banners.count > 1 else { return }
                withAnimation(MonoAnimation.tabSwitch) {
                    bannerIndex = (bannerIndex + 1) % min(banners.count, 6)
                }
            }

            if banners.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<min(banners.count, 6), id: \.self) { index in
                        Capsule()
                            .fill(index == bannerIndex ? PetWhiteStyle.dogOrange : PetWhiteStyle.separator)
                            .frame(width: index == bannerIndex ? 20 : 7, height: 7)
                            .animation(MonoAnimation.micro, value: bannerIndex)
                    }
                }
            }
        }
    }
}

private struct PetWhiteBannerCard: View {
    let banner: Banner

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HomeBannerArtwork(url: banner.imageUrl, cornerRadius: PetWhiteStyle.cardRadius) {
                PetWhiteStyle.surfacePressed
                    .overlay {
                        PetWhitePetPetIcon(size: 64)
                    }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)

            LinearGradient(
                colors: [.clear, PetWhiteStyle.shadowInk.opacity(0.46)],
                startPoint: .center,
                endPoint: .bottom
            )

            if let title = banner.typeTitle, !title.isEmpty {
                Text(title)
                    .font(PetWhiteStyle.labelFont(12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
        .frame(height: DeviceLayout.usesExpandedLayout ? 176 : 146)
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: PetWhiteStyle.cardRadius, style: .continuous))
        .petWhiteClayShadow()
    }
}

private struct PetWhitePlaylistShelf: View {
    let title: String
    let detail: String
    let playlists: [Playlist]
    let tint: Color
    let icon: MonoIcon.IconType
    var assetName: String?
    let onViewAll: () -> Void
    let onTap: (Playlist) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PetWhiteSectionTitle(
                title: title,
                detail: detail,
                icon: icon,
                assetName: assetName,
                tint: tint,
                action: onViewAll
            )
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(Array(playlists.prefix(10).enumerated()), id: \.element.id) { index, playlist in
                        Button {
                            onTap(playlist)
                        } label: {
                            PetWhitePlaylistCard(playlist: playlist, index: index, tint: tint)
                        }
                        .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.94))
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .compatScrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .compatViewAlignedScrollBehavior(limitNever: true)
        }
    }
}

private struct PetWhitePlaylistCard: View {
    let playlist: Playlist
    let index: Int
    let tint: Color

    private var cardWidth: CGFloat {
        DeviceLayout.usesExpandedLayout ? 168 : 136
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(400)) {
                    PetWhiteMascotMark(kind: index.isMultiple(of: 2) ? .cat : .dog, size: 58)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PetWhiteStyle.surfacePressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: cardWidth, height: cardWidth)
                .clipShape(RoundedRectangle(cornerRadius: PetWhiteStyle.cardRadius, style: .continuous))

                if let playCount = playlist.playCount, playCount > 0 {
                    HStack(spacing: 4) {
                        PetWhitePackIcon(icon: .play, size: 11, visualScale: 1.02)
                        Text(PetWhiteHomeFormat.count(playCount))
                            .font(PetWhiteStyle.labelFont(10, weight: .semibold))
                    }
                    .foregroundStyle(PetWhiteStyle.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PetWhiteStyle.paper.opacity(0.9), in: Capsule())
                    .padding(8)
                }
            }
            .petWhiteClayShadow(elevated: false)

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(PetWhiteStyle.bodyFont(13, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 36, alignment: .top)

                Text(playlist.trackCount.map { "\($0) \(String(localized: "songs_unit"))" } ?? "Furry list")
                    .font(PetWhiteStyle.labelFont(10))
                    .foregroundStyle(PetWhiteStyle.inkMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)
        }
        .frame(width: cardWidth)
    }
}

private struct PetWhiteNewSongsBoard: View {
    let songs: [Song]
    let onViewAll: () -> Void
    let onPlay: (Song) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PetWhiteSectionTitle(
                title: String(localized: "qq_new_songs"),
                detail: String(localized: "qq_new_songs_desc"),
                icon: .musicNote,
                assetName: "qqMusic",
                tint: PetWhiteStyle.mint,
                action: onViewAll
            )

            VStack(spacing: 0) {
                ForEach(Array(songs.prefix(5).enumerated()), id: \.element.id) { index, song in
                    Button {
                        onPlay(song)
                    } label: {
                        PetWhiteNewSongRow(index: index + 1, song: song)
                    }
                    .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.965))

                    if index < min(songs.count, 5) - 1 {
                        Divider()
                            .overlay(PetWhiteStyle.separator)
                            .padding(.leading, 70)
                    }
                }
            }
            .padding(.horizontal, 6)
            .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }
}

private struct PetWhiteNewSongRow: View {
    let index: Int
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(PetWhiteStyle.labelFont(13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(PetWhiteStyle.inkMuted)
                .frame(width: 18, alignment: .center)

            CachedAsyncImage(url: song.coverUrl) {
                PetWhitePetPetIcon(size: 38)
                    .frame(width: 46, height: 46)
                    .background(PetWhiteStyle.surfacePressed)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(PetWhiteStyle.stroke, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(PetWhiteStyle.bodyFont(14, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(PetWhiteStyle.labelFont(11))
                    .foregroundStyle(PetWhiteStyle.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            PetWhitePackIcon(icon: .play, size: 17, visualScale: 1.04, fallbackColor: PetWhiteStyle.inkMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private enum PetWhiteHomeFormat {
    static func count(_ count: Int) -> String {
        let locale = Locale.current
        if locale.language.languageCode?.identifier == "zh" {
            if count >= 100_000_000 {
                return String(format: NSLocalizedString("count_hundred_million", comment: ""), Double(count) / 100_000_000)
            }
            if count >= 10_000 {
                return String(format: NSLocalizedString("count_ten_thousand", comment: ""), Double(count) / 10_000)
            }
        } else {
            if count >= 1_000_000_000 { return String(format: "%.1fB", Double(count) / 1_000_000_000) }
            if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
            if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        }
        return "\(count)"
    }
}

private struct PetWhiteLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            PetWhiteMascotMark(kind: .pair, size: 84)

            HStack(spacing: 8) {
                Capsule().fill(PetWhiteStyle.dogOrange).frame(width: 28, height: 8)
                Capsule().fill(PetWhiteStyle.mint).frame(width: 46, height: 8)
                Capsule().fill(PetWhiteStyle.blush).frame(width: 18, height: 8)
            }
        }
    }
}

private struct PetWhiteHomeEmptyState: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            PetWhiteMascotMark(kind: .pair, size: 72)

            VStack(spacing: 5) {
                Text(String(localized: "首页内容正在路上"))
                    .font(PetWhiteStyle.titleFont(18, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)

                Text(String(localized: "网络或缓存暂时没有返回推荐内容，点一下让小爪子再找找。"))
                    .font(PetWhiteStyle.bodyFont(13, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onRetry) {
                HStack(spacing: 7) {
                    PetWhitePackIcon(icon: .refresh, size: 16, visualScale: 1.08, fallbackColor: PetWhiteStyle.onAccent)
                    Text(String(localized: "reload"))
                        .font(PetWhiteStyle.labelFont(12, weight: .black))
                }
                .foregroundStyle(PetWhiteStyle.onAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(PetWhiteStyle.accent, in: Capsule())
                .overlay(Capsule().stroke(PetWhiteStyle.stroke, lineWidth: 1))
            }
            .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.92))
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(PetWhiteSurfaceBackground(cornerRadius: 24, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.sky))
    }
}

struct PetWhitePodcastView: View {
    var body: some View {
        PetWhiteThemeRoot(page: .podcast) {
            PodcastView()
        }
    }
}

struct PetWhiteSearchView: View {
    var body: some View {
        PetWhiteThemeRoot(page: .search) {
            SearchView()
        }
    }
}

struct PetWhiteLibraryView: View {
    var body: some View {
        LibraryView()
            .tint(PetWhiteStyle.accent)
    }
}

struct PetWhiteProfileView: View {
    var body: some View {
        PetWhiteThemeRoot(page: .profile) {
            ProfileView()
        }
    }
}

struct PetWhiteLocalHomeView: View {
    var body: some View {
        PetWhiteThemeRoot(page: .localHome) {
            LocalModeHomeView()
        }
    }
}

struct PetWhiteLocalMusicView: View {
    var body: some View {
        PetWhiteThemeRoot(page: .localMusic) {
            LocalMusicView()
        }
    }
}

struct PetWhiteLocalLibraryView: View {
    var body: some View {
        PetWhiteThemeRoot(page: .localLibrary) {
            LocalLibraryView()
        }
    }
}

struct PetWhiteLocalProfileView: View {
    var body: some View {
        PetWhiteThemeRoot(page: .localProfile) {
            LocalModeProfileView()
        }
    }
}

private extension View {
    func petWhiteAppear(_ appeared: Bool, order: Int) -> some View {
        // 黏土块「弹」上桌面：轻微过冲的果冻感
        opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .scaleEffect(appeared ? 1 : 0.96)
            .animation(
                .spring(response: 0.48, dampingFraction: 0.68).delay(Double(order) * 0.05),
                value: appeared
            )
    }
}
