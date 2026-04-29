import SwiftUI

// MARK: - Subviews for Performance

struct MiniPlayerSection: View {
    let song: Song
    let isPlaying: Bool
    let togglePlayPause: () -> Void
    @State private var showPlaylist = false
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var lyricVM = LyricViewModel.shared

    private var subtitleText: String {
        if !player.isPlayingPodcast, lyricVM.hasLyrics, let text = lyricVM.currentLineText {
            return text
        }
        return song.artistName
    }

    private var primaryTextColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return Color.monologueTextPrimary
    }

    private var secondaryTextColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        return Color.monologueTextSecondary
    }

    private var controlFillColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
        return Color.monologueIconBackground
    }

    private var controlForegroundColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        return Color.monologueIconForeground
    }

    private var titleFont: Font {
        if MangaStyle.isActive {
            return MangaStyle.bodyFont(13, weight: .bold)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(13, weight: .semibold)
        }
        return MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .semibold) : .system(size: 13, weight: .semibold, design: .rounded)
    }

    private var subtitleFont: Font {
        if MangaStyle.isActive {
            return MangaStyle.bodyFont(11, weight: .medium)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(11, weight: .regular)
        }
        return MujiStyle.isActive ? MujiStyle.labelFont(11, weight: .regular) : .rounded(size: 11, weight: .medium)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: MujiStyle.isActive ? 5 : 8, style: .continuous))
                .overlay {
                    if MujiStyle.isActive {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(MujiStyle.hairline.opacity(0.5), lineWidth: 0.6)
                    }
                }
                .overlay {
                    if player.playSource == .fm {
                        sourceIndicator(icon: .fm)
                    } else if player.isPlayingPodcast {
                        sourceIndicator(icon: .radio)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(
                        text: song.name,
                        font: titleFont,
                        color: primaryTextColor,
                        speed: 25
                    )
                    .frame(height: 16)

                    Text(subtitleText)
                        .font(subtitleFont)
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(1)
                        .animation(.easeInOut(duration: 0.25), value: lyricVM.currentLineIndex)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 控制按钮
                HStack(spacing: 10) {
                    Button(action: togglePlayPause) {
                        ZStack {
                            Circle()
                                .fill(controlFillColor)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if MujiStyle.isActive {
                                        Circle().stroke(MujiStyle.hairline.opacity(0.32), lineWidth: 0.6)
                                    } else if NeumorphicStyle.isActive {
                                        Circle().stroke(NeumorphicStyle.lightShadow(.light, intensity: 0.4), lineWidth: 0.7)
                                    }
                                }

                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: controlForegroundColor))
                                    .scaleEffect(0.6)
                            } else {
                                MonologueIcon(
                                    icon: isPlaying ? .pause : .play,
                                    size: 14,
                                    color: controlForegroundColor
                                )
                            }
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    Button(action: { showPlaylist.toggle() }) {
                        MonologueIcon(icon: .list, size: 16, color: primaryTextColor.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    if !isPlaying {
                        Button(action: {
                            withAnimation(MonologueAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }) {
                            MonologueIcon(icon: .close, size: 10, color: secondaryTextColor)
                                .frame(width: 28, height: 28)
                                .background(primaryTextColor.opacity(0.08))
                                .clipShape(Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .zIndex(1)
            }
            .padding(.horizontal, DeviceLayout.isPad ? 20 : 14)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapWithHaptic {
                        withAnimation(MonologueAnimation.playerTransition) {
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

            ProgressBarView()
                .frame(height: 2.5)
                .padding(.horizontal, DeviceLayout.isPad ? 20 : 14)
                .padding(.bottom, 4)
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    /// 播放来源角标
    private func sourceIndicator(icon: MonologueIcon.IconType) -> some View {
        MonologueIcon(icon: icon, size: 12, color: .white, lineWidth: 1.6)
    }
}

struct ProgressBarView: View {
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 轨道
                Capsule()
                    .fill(trackColor)
                    .frame(height: 2.5)

                // 进度
                let progress = timePublisher.progress
                Capsule()
                    .fill(progressFill)
                    .frame(width: max(geometry.size.width * CGFloat(progress), 0), height: 2.5)
                    .animation(.linear(duration: 0.1), value: progress)
            }
        }
    }

    private var trackColor: Color {
        if MangaStyle.isActive {
            return MangaStyle.separator.opacity(0.6)
        } else if MujiStyle.isActive {
            return MujiStyle.separator.opacity(0.55)
        } else if NeumorphicStyle.isActive {
            return NeumorphicStyle.surfacePressed.opacity(0.9)
        }
        return Color.monologueTextPrimary.opacity(0.06)
    }

    private var progressFill: some ShapeStyle {
        if MangaStyle.isActive {
            return AnyShapeStyle(LinearGradient(colors: [MangaStyle.accentPink, MangaStyle.labelYellow], startPoint: .leading, endPoint: .trailing))
        } else if MujiStyle.isActive {
            return AnyShapeStyle(MujiStyle.accentGradient)
        } else if NeumorphicStyle.isActive {
            return AnyShapeStyle(LinearGradient(colors: [NeumorphicStyle.accent, NeumorphicStyle.sage], startPoint: .leading, endPoint: .trailing))
        }
        return AnyShapeStyle(LinearGradient(colors: [Color.monologueAccent.opacity(0.5), Color.monologueAccent.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
    }
}

// MARK: - Tab Icon Animation Values

private struct TabIconAnimValues {
    var scale: CGFloat = 1.0
    var rotation: Double = 0.0
    var offsetY: CGFloat = 0.0
}

// MARK: - Monologue TabBar

struct MonologueTabBar: View {
    @Binding var selectedIndex: Int
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Namespace private var tabNS
    @State private var animTrigger: Int = -1

    private let itemHeight: CGFloat = 48
    private let padding: CGFloat = 5

    private var selectedColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return MujiStyle.isActive ? MujiStyle.clay : .monologueTextPrimary
    }

    private var idleColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        return MujiStyle.isActive ? MujiStyle.inkMuted : .monologueTextPrimary.opacity(0.35)
    }

    private static let tabIcons: [(outline: MonologueIcon.IconType, filled: MonologueIcon.IconType)] = [
        (.home, .homeFilled),
        (.podcast, .podcastFilled),
        (.library, .libraryFilled),
        (.profile, .profileFilled),
    ]

    var body: some View {
        HStack(spacing: 0) {
            tabButton(index: 0, label: NSLocalizedString(Tab.home.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
            tabButton(index: 1, label: NSLocalizedString(Tab.podcast.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
            tabButton(index: 2, label: NSLocalizedString(Tab.library.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
            tabButton(index: 3, label: NSLocalizedString(Tab.profile.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, padding)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func tabButton(index: Int, label: String) -> some View {
        let isSelected = selectedIndex == index
        let icons = Self.tabIcons[index]

        Button {
            HapticManager.shared.light()
            animTrigger = index
            withAnimation(MonologueAnimation.tabSwitch) {
                selectedIndex = index
            }
        } label: {
            VStack(spacing: 2) {
                KeyframeAnimator(initialValue: TabIconAnimValues(), trigger: animTrigger == index ? animTrigger : -1) { values in
                    MonologueIcon(
                        icon: isSelected ? icons.filled : icons.outline,
                        size: 19,
                        color: isSelected ? selectedColor : idleColor
                    )
                    .contentTransition(.interpolate)
                    .scaleEffect(values.scale)
                    .rotationEffect(.degrees(values.rotation))
                    .offset(y: values.offsetY)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        SpringKeyframe(1.14, duration: 0.1, spring: .smooth)
                        SpringKeyframe(0.97, duration: 0.08, spring: .smooth)
                        SpringKeyframe(1.0, duration: 0.12, spring: .smooth)
                    }
                    KeyframeTrack(\.rotation) {
                        SpringKeyframe(-4, duration: 0.08, spring: .smooth)
                        SpringKeyframe(2, duration: 0.08, spring: .smooth)
                        SpringKeyframe(0, duration: 0.1, spring: .smooth)
                    }
                    KeyframeTrack(\.offsetY) {
                        SpringKeyframe(-2, duration: 0.1, spring: .smooth)
                        SpringKeyframe(0, duration: 0.12, spring: .smooth)
                    }
                }
                .animation(MonologueAnimation.tabSwitch, value: isSelected)

                Text(label)
                    .font(mangaOrMujiTabFont(isSelected: isSelected))
                    .foregroundColor(isSelected ? selectedColor : idleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: itemHeight, alignment: .center)
            .background {
                if isSelected {
                    Capsule()
                        .fill(mangaOrMujiHighlightColor)
                        .padding(.horizontal, 4)
                        .matchedGeometryEffect(id: "tabHighlight", in: tabNS)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func mangaOrMujiTabFont(isSelected: Bool) -> Font {
        if MangaStyle.isActive {
            return MangaStyle.labelFont(9, weight: isSelected ? .black : .bold)
        } else if MujiStyle.isActive {
            return MujiStyle.labelFont(9, weight: isSelected ? .semibold : .medium)
        } else if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(9, weight: isSelected ? .semibold : .medium)
        }
        return .system(size: 10, weight: isSelected ? .semibold : .medium)
    }

    private var mangaOrMujiHighlightColor: Color {
        if MangaStyle.isActive { return MangaStyle.accentPink.opacity(0.15) }
        if MujiStyle.isActive { return MujiStyle.clay.opacity(0.1) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent.opacity(0.14) }
        return Color.monologueTextPrimary.opacity(0.1)
    }
}

// MARK: - Unified Floating Bar

struct UnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var glassNS

    private var cornerRadius: CGFloat {
        MujiStyle.isActive ? 16 : 22
    }

    var body: some View {
        switch settings.globalThemeId {
        case .manga:
            MangaUnifiedFloatingBar(currentTab: $currentTab)
        case .muji:
            MujiUnifiedFloatingBar(currentTab: $currentTab)
        case .neumorphic:
            NeumorphicUnifiedFloatingBar(currentTab: $currentTab)
        case .default:
            defaultFloatingBar
        }
    }

    private var defaultFloatingBar: some View {
        MonologueGlassContainer(spacing: 0) {
            VStack(spacing: 0) {
                if let song = player.currentSong {
                    MiniPlayerSection(
                        song: song,
                        isPlaying: player.isPlaying,
                        togglePlayPause: { player.togglePlayPause() }
                    )
                    .swipeToSkip()
                    .monologueGlassID("miniPlayer", in: glassNS)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                    ))
                }

                MonologueTabBar(selectedIndex: Binding(
                    get: { Tab.allCases.firstIndex(of: currentTab) ?? 0 },
                    set: { currentTab = Tab.allCases[$0] }
                ))
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
                .monologueGlassID("tabBar", in: glassNS)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.monologueFloatingBarFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.12),
                        lineWidth: 0.75
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.16), radius: 18, x: 0, y: 8)
            .monologueGlass(cornerRadius: cornerRadius)
            .monologueGlassID("floatingBar", in: glassNS)
        }
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
    }

    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                if value.translation.width < 0 {
                    switchTab(direction: 1)
                } else if value.translation.width > 0 {
                    switchTab(direction: -1)
                }
            }
    }

    private func switchTab(direction: Int) {
        let allTabs = Tab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }

        let nextIndex = currentIndex + direction

        if nextIndex >= 0, nextIndex < allTabs.count {
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}

private struct MujiUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = PlayerManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if let song = player.currentSong {
                MujiMiniPlayerStrip(song: song)
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .bottom))
                    ))

                Rectangle()
                    .fill(MujiStyle.separator.opacity(0.76))
                    .frame(height: 0.6)
                    .padding(.horizontal, 12)
            }

            MujiDedicatedTabBar(currentTab: $currentTab)
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(MujiPaperCardBackground(cornerRadius: 18, elevated: true))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(colorScheme == .dark ? MujiStyle.hairline.opacity(0.56) : Color.black.opacity(0.1), lineWidth: 0.75)
                .padding(0.5)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.13), radius: 16, x: 0, y: 7)
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
    }

    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                if value.translation.width < 0 {
                    switchTab(direction: 1)
                } else if value.translation.width > 0 {
                    switchTab(direction: -1)
                }
            }
    }

    private func switchTab(direction: Int) {
        let allTabs = Tab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }

        let nextIndex = currentIndex + direction

        if nextIndex >= 0, nextIndex < allTabs.count {
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}

private struct NeumorphicUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = PlayerManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if let song = player.currentSong {
                NeumorphicMiniPlayerStrip(song: song)
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                    ))

                Capsule()
                    .fill(NeumorphicStyle.separator.opacity(0.42))
                    .frame(height: 1)
                    .padding(.horizontal, 12)
            }

            NeumorphicDedicatedTabBar(currentTab: $currentTab)
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    colorScheme == .dark
                        ? NeumorphicStyle.lightShadow(colorScheme, intensity: 0.9)
                        : NeumorphicStyle.darkShadow(colorScheme, intensity: 0.38),
                    lineWidth: 0.8
                )
                .padding(0.5)
        )
        .shadow(color: NeumorphicStyle.darkShadow(colorScheme, intensity: colorScheme == .dark ? 0.64 : 0.48), radius: 18, x: 0, y: 8)
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
        .themeRenderInteractiveLayer()
    }

    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                if value.translation.width < 0 {
                    switchTab(direction: 1)
                } else if value.translation.width > 0 {
                    switchTab(direction: -1)
                }
            }
    }

    private func switchTab(direction: Int) {
        let allTabs = Tab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }

        let nextIndex = currentIndex + direction

        if nextIndex >= 0, nextIndex < allTabs.count {
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}

private struct NeumorphicMiniPlayerStrip: View {
    let song: Song
    @State private var showPlaylist = false
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var lyricVM = LyricViewModel.shared

    private var subtitleText: String {
        if !player.isPlayingPodcast, lyricVM.hasLyrics, let text = lyricVM.currentLineText {
            return text
        }
        return song.artistName
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(NeumorphicStyle.surfacePressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .background(NeumorphicSurfaceBackground(cornerRadius: 12, elevated: true))
                .overlay(alignment: .bottomTrailing) {
                    if player.isPlaying {
                        PlayingVisualizerView(isAnimating: true, color: NeumorphicStyle.accent)
                            .frame(width: 14, height: 10)
                            .padding(3)
                            .background(NeumorphicStyle.surfaceRaised.opacity(0.9), in: Circle())
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: song.name,
                        font: NeumorphicStyle.labelFont(13, weight: .semibold),
                        color: NeumorphicStyle.ink,
                        speed: 25
                    )
                    .frame(height: 16)

                    Text(subtitleText)
                        .font(NeumorphicStyle.labelFont(11, weight: .regular))
                        .foregroundStyle(NeumorphicStyle.inkSoft)
                        .lineLimit(1)
                        .animation(.easeInOut(duration: 0.25), value: lyricVM.currentLineIndex)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 7) {
                    neumorphicControl(icon: player.isPlaying ? .pause : .play, tint: NeumorphicStyle.accent) {
                        player.togglePlayPause()
                    }

                    neumorphicControl(icon: .list, tint: NeumorphicStyle.inkSoft) {
                        showPlaylist.toggle()
                    }

                    if !player.isPlaying {
                        neumorphicControl(icon: .close, tint: NeumorphicStyle.inkMuted, size: 9) {
                            withAnimation(MonologueAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapWithHaptic { openPlayer() }
            }

            ProgressBarView()
                .frame(height: 2)
                .padding(.horizontal, 8)
                .padding(.bottom, 5)
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func neumorphicControl(
        icon: MonologueIcon.IconType,
        tint: Color,
        size: CGFloat = 14,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: size, color: tint, lineWidth: 1.7)
                .frame(width: 31, height: 31)
                .background(NeumorphicSurfaceBackground(cornerRadius: 12, elevated: true))
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
    }

    private func openPlayer() {
        withAnimation(MonologueAnimation.playerTransition) {
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

private struct NeumorphicDedicatedTabBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Namespace private var selectionNS

    private static let tabs: [(tab: Tab, outline: MonologueIcon.IconType, filled: MonologueIcon.IconType)] = [
        (.home, .home, .homeFilled),
        (.podcast, .podcast, .podcastFilled),
        (.library, .library, .libraryFilled),
        (.profile, .profile, .profileFilled),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< Self.tabs.count, id: \.self) { index in
                let item = Self.tabs[index]
                tabButton(tab: item.tab, index: index, outline: item.outline, filled: item.filled)
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 4)
        .frame(height: 50)
        .background(NeumorphicSurfaceBackground(cornerRadius: 18, elevated: false, pressed: true, lightweight: true))
    }

    private func tabButton(tab: Tab, index: Int, outline: MonologueIcon.IconType, filled: MonologueIcon.IconType) -> some View {
        let isSelected = currentTab == tab
        let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")
        let tint = tabTint(index)

        return Button {
            HapticManager.shared.light()
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = tab
            }
        } label: {
            HStack(spacing: isSelected ? 6 : 0) {
                MonologueIcon(
                    icon: isSelected ? filled : outline,
                    size: isSelected ? 17 : 16,
                    color: isSelected ? tint : NeumorphicStyle.inkMuted,
                    lineWidth: isSelected ? 1.8 : 1.5
                )
                .frame(width: 24, height: 22)

                if isSelected {
                    Text(label)
                        .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .background(NeumorphicSurfaceBackground(cornerRadius: 14, elevated: true, tint: tint.opacity(0.08)))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .matchedGeometryEffect(id: "neumorphicTabSelection", in: selectionNS)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tabTint(_ index: Int) -> Color {
        switch index {
        case 0: return NeumorphicStyle.accent
        case 1: return NeumorphicStyle.sage
        case 2: return NeumorphicStyle.warm
        default: return NeumorphicStyle.red
        }
    }
}

private struct MujiMiniPlayerStrip: View {
    let song: Song
    @State private var showPlaylist = false
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var lyricVM = LyricViewModel.shared

    private var subtitleText: String {
        if !player.isPlayingPodcast, lyricVM.hasLyrics, let text = lyricVM.currentLineText {
            return text
        }
        return song.artistName
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(MujiStyle.separator.opacity(0.45))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(MujiStyle.hairline.opacity(0.52), lineWidth: 0.6)
                )
                .overlay(alignment: .bottomTrailing) {
                    if player.isPlaying {
                        MujiNowPlayingIndicator(isAnimating: true)
                            .scaleEffect(0.68, anchor: .bottomTrailing)
                            .padding(3)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if player.playSource == .fm {
                        sourceIndicator(icon: .fm)
                    } else if player.isPlayingPodcast {
                        sourceIndicator(icon: .radio)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: song.name,
                        font: MujiStyle.labelFont(13, weight: .semibold),
                        color: MujiStyle.ink,
                        speed: 25
                    )
                    .frame(height: 16)

                    Text(subtitleText)
                        .font(MujiStyle.labelFont(11, weight: .regular))
                        .foregroundStyle(MujiStyle.inkSoft)
                        .lineLimit(1)
                        .animation(.easeInOut(duration: 0.25), value: lyricVM.currentLineIndex)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Button(action: { player.togglePlayPause() }) {
                        ZStack {
                            Circle()
                                .fill(MujiStyle.paperWarm.opacity(0.72))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(MujiStyle.hairline.opacity(0.44), lineWidth: 0.6))

                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: MujiStyle.clay))
                                    .scaleEffect(0.55)
                            } else {
                                MonologueIcon(
                                    icon: player.isPlaying ? .pause : .play,
                                    size: 14,
                                    color: MujiStyle.ink,
                                    lineWidth: 1.7
                                )
                            }
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    Button(action: { showPlaylist.toggle() }) {
                        MonologueIcon(icon: .list, size: 16, color: MujiStyle.inkSoft, lineWidth: 1.6)
                            .frame(width: 34, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    if !player.isPlaying {
                        Button(action: {
                            withAnimation(MonologueAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }) {
                            MonologueIcon(icon: .close, size: 10, color: MujiStyle.inkMuted, lineWidth: 1.6)
                                .frame(width: 28, height: 28)
                                .background(MujiStyle.ink.opacity(0.06), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapWithHaptic {
                        openPlayer()
                    }
            }

            ProgressBarView()
                .frame(height: 2)
                .padding(.horizontal, 8)
                .padding(.bottom, 5)
                .opacity(0.82)
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func sourceIndicator(icon: MonologueIcon.IconType) -> some View {
        MonologueIcon(icon: icon, size: 10, color: MujiStyle.onTint, lineWidth: 1.5)
            .frame(width: 18, height: 18)
            .background(MujiStyle.ink.opacity(0.52), in: Circle())
            .padding(3)
    }

    private func openPlayer() {
        withAnimation(MonologueAnimation.playerTransition) {
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

private struct MujiDedicatedTabBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Namespace private var selectionNS

    private static let tabs: [(tab: Tab, outline: MonologueIcon.IconType, filled: MonologueIcon.IconType)] = [
        (.home, .home, .homeFilled),
        (.podcast, .podcast, .podcastFilled),
        (.library, .library, .libraryFilled),
        (.profile, .profile, .profileFilled),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< Self.tabs.count, id: \.self) { index in
                let item = Self.tabs[index]
                tabButton(tab: item.tab, index: index, outline: item.outline, filled: item.filled)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .frame(height: 52)
    }

    private func tabButton(tab: Tab, index: Int, outline: MonologueIcon.IconType, filled: MonologueIcon.IconType) -> some View {
        let isSelected = currentTab == tab
        let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")

        return Button {
            HapticManager.shared.light()
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    MonologueIcon(
                        icon: isSelected ? filled : outline,
                        size: 18,
                        color: isSelected ? MujiStyle.ink : MujiStyle.inkMuted,
                        lineWidth: isSelected ? 1.8 : 1.55
                    )
                    .frame(width: 28, height: 22)

                    if isSelected {
                        Circle()
                            .fill(tabTint(index))
                            .frame(width: 4.5, height: 4.5)
                            .offset(x: 3, y: -1)
                    }
                }

                Text(label)
                    .font(MujiStyle.labelFont(9, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? MujiStyle.ink : MujiStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(MujiStyle.surface.opacity(0.78))
                        .overlay(
                            MujiPaperTexture(opacity: 0.08)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(MujiStyle.hairline.opacity(0.38), lineWidth: 0.6)
                        )
                        .matchedGeometryEffect(id: "mujiTabSelection", in: selectionNS)
                }
            }
            .overlay(alignment: .bottom) {
                if isSelected {
                    Capsule()
                        .fill(tabTint(index).opacity(0.78))
                        .frame(width: 18, height: 2)
                        .padding(.bottom, 3)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tabTint(_ index: Int) -> Color {
        switch index {
        case 0: return MujiStyle.clay
        case 1: return MujiStyle.tea
        case 2: return MujiStyle.indigo
        default: return MujiStyle.straw
        }
    }
}

// MARK: - 漫画风专用浮动栏

private struct MangaUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = PlayerManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if let song = player.currentSong {
                MangaMiniPlayerStrip(song: song)
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .bottom))
                    ))
            }

            MangaDedicatedTabBar(currentTab: $currentTab)
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
        }
        .padding(.horizontal, 7)
        .padding(.top, player.currentSong == nil ? 6 : 4)
        .padding(.bottom, 6)
        .background(mangaFloatingShell)
        .overlay(alignment: .topLeading) {
            Text("COMIC DOCK")
                .font(MangaStyle.labelFont(7, weight: .black))
                .foregroundStyle(MangaStyle.strokeInk)
                .tracking(0.6)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(MangaStyle.labelYellow, in: Capsule())
                .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: 1.0))
                .rotationEffect(.degrees(-5))
                .offset(x: 16, y: -8)
        }
        .overlay(alignment: .bottomTrailing) {
            MangaSectionMark(kind: .star, tint: MangaStyle.decoBlue, size: 14)
                .offset(x: -14, y: 6)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.36 : 0.16), radius: 14, x: 0, y: 7)
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
    }

    private var mangaFloatingShell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(MangaStyle.strokeInk)
                .offset(x: 3, y: 3)

            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            MangaStyle.bubbleWhite,
                            MangaStyle.paperWarm.opacity(0.92),
                            MangaStyle.paperCool.opacity(0.72),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            MangaDotsTexture(opacity: 0.026, gap: 11)
                .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))

            HStack(spacing: 0) {
                MangaStyle.accentPink.frame(width: 6)
                MangaStyle.labelYellow.frame(width: 6)
                MangaStyle.decoBlue.frame(width: 6)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))

            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(MangaStyle.strokeInk, lineWidth: 1.7)
        }
    }

    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                if value.translation.width < 0 {
                    switchTab(direction: 1)
                } else if value.translation.width > 0 {
                    switchTab(direction: -1)
                }
            }
    }

    private func switchTab(direction: Int) {
        let allTabs = Tab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }

        let nextIndex = currentIndex + direction

        if nextIndex >= 0, nextIndex < allTabs.count {
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}

private struct MangaMiniPlayerStrip: View {
    let song: Song
    @State private var showPlaylist = false
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var lyricVM = LyricViewModel.shared

    private var subtitleText: String {
        if !player.isPlayingPodcast, lyricVM.hasLyrics, let text = lyricVM.currentLineText {
            return text
        }
        return song.artistName
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(MangaStyle.paperCool)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(MangaStyle.strokeInk, lineWidth: 1.4)
                )
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(MangaStyle.strokeInk)
                        .offset(x: 1.1, y: 1.1)
                )
                .overlay(alignment: .bottomTrailing) {
                    if player.isPlaying {
                        MangaNowPlayingIndicator(isAnimating: true)
                            .scaleEffect(0.54, anchor: .bottomTrailing)
                            .padding(2)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if player.playSource == .fm {
                        mangaSourceIndicator(icon: .fm)
                    } else if player.isPlayingPodcast {
                        mangaSourceIndicator(icon: .radio)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: song.name,
                        font: MangaStyle.bodyFont(12, weight: .bold),
                        color: MangaStyle.ink,
                        speed: 25
                    )
                    .frame(height: 15)

                    Text(subtitleText)
                        .font(MangaStyle.bodyFont(10, weight: .medium))
                        .foregroundStyle(MangaStyle.inkSub)
                        .lineLimit(1)
                        .animation(.easeInOut(duration: 0.25), value: lyricVM.currentLineIndex)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Button(action: { player.togglePlayPause() }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(MangaStyle.labelYellow)
                                .frame(width: 29, height: 29)
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(MangaStyle.strokeInk, lineWidth: 1.4)
                                .frame(width: 29, height: 29)

                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: MangaStyle.accentPink))
                                    .scaleEffect(0.55)
                            } else {
                                MonologueIcon(
                                    icon: player.isPlaying ? .pause : .play,
                                    size: 13,
                                    color: MangaStyle.strokeInk,
                                    lineWidth: 1.8
                                )
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(MangaStyle.strokeInk)
                                .frame(width: 29, height: 29)
                                .offset(x: 1.1, y: 1.1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    // 列表
                    Button(action: { showPlaylist.toggle() }) {
                        MonologueIcon(icon: .list, size: 14, color: MangaStyle.inkSub, lineWidth: 1.8)
                            .frame(width: 29, height: 29)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    // 关闭
                    if !player.isPlaying {
                        Button(action: {
                            withAnimation(MonologueAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }) {
                            MonologueIcon(icon: .close, size: 10, color: MangaStyle.inkMuted, lineWidth: 1.8)
                                .frame(width: 25, height: 25)
                                .background(MangaStyle.strokeInk.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 0.9))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 7)
            .padding(.top, 4)
            .padding(.bottom, 3)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapWithHaptic {
                        openPlayer()
                    }
            }

            ProgressBarView()
                .frame(height: 2)
                .padding(.horizontal, 7)
                .padding(.bottom, 3)
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func mangaSourceIndicator(icon: MonologueIcon.IconType) -> some View {
        MonologueIcon(icon: icon, size: 10, color: MangaStyle.onStrokeInk, lineWidth: 1.5)
            .frame(width: 18, height: 18)
            .background(MangaStyle.strokeInk.opacity(0.86), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1))
            .padding(3)
    }

    private func openPlayer() {
        withAnimation(MonologueAnimation.playerTransition) {
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

private struct MangaDedicatedTabBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Namespace private var selectionNS

    private static let tabs: [(tab: Tab, outline: MonologueIcon.IconType, filled: MonologueIcon.IconType)] = [
        (.home, .home, .homeFilled),
        (.podcast, .podcast, .podcastFilled),
        (.library, .library, .libraryFilled),
        (.profile, .profile, .profileFilled),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< Self.tabs.count, id: \.self) { index in
                let item = Self.tabs[index]
                tabButton(tab: item.tab, index: index, outline: item.outline, filled: item.filled)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .frame(height: 48)
    }

    private func tabButton(tab: Tab, index: Int, outline: MonologueIcon.IconType, filled: MonologueIcon.IconType) -> some View {
        let isSelected = currentTab == tab
        let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")

        return Button {
            HapticManager.shared.light()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) {
                currentTab = tab
            }
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    MonologueIcon(
                        icon: isSelected ? filled : outline,
                        size: isSelected ? 17 : 15.5,
                        color: isSelected ? selectedForeground(index) : MangaStyle.inkMuted,
                        lineWidth: isSelected ? 1.8 : 1.45
                    )
                    .frame(width: 26, height: 19)
                    .scaleEffect(isSelected ? 1.05 : 1)

                    if isSelected {
                        MangaSectionMark(
                            kind: index == 3 ? .heart : .star,
                            tint: MangaStyle.bubbleWhite,
                            size: 11,
                            foreground: MangaStyle.ink
                        )
                        .offset(x: 13, y: -6)
                    }
                }

                Text(label)
                    .font(MangaStyle.labelFont(9, weight: isSelected ? .black : .bold))
                    .foregroundStyle(isSelected ? selectedForeground(index) : MangaStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 39)
            .background {
                if isSelected {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(MangaStyle.strokeInk)
                            .offset(x: 1.1, y: 1.1)

                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(tabTint(index).opacity(0.82))

                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(MangaStyle.strokeInk, lineWidth: 1.35)
                    }
                    .matchedGeometryEffect(id: "mangaTabSelection", in: selectionNS)
                }
            }
            .overlay(alignment: .bottom) {
                if isSelected {
                    Capsule()
                        .fill(selectedForeground(index))
                        .frame(width: 15, height: 2)
                        .padding(.bottom, 3)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tabTint(_ index: Int) -> Color {
        switch index {
        case 0: return MangaStyle.labelYellow
        case 1: return MangaStyle.bubbleBlue
        case 2: return MangaStyle.mint
        default: return MangaStyle.bubblePink
        }
    }

    private func selectedForeground(_ index: Int) -> Color {
        switch index {
        case 0, 2: return MangaStyle.strokeInk
        default: return MangaStyle.ink
        }
    }
}

// MARK: - Tab Enum Extension for Monologue Icons

extension Tab {
    var monologueIcon: MonologueIcon.IconType {
        switch self {
        case .home: return .home
        case .podcast: return .podcast
        case .library: return .library
        case .profile: return .profile
        }
    }
}
