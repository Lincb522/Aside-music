import SwiftUI

struct SignalUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            if let song = player.currentSong {
                SignalMiniPlayerStrip(song: song)
                    .swipeToSkip()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            SignalUnifiedTabRail(currentTab: $currentTab)
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
        }
        .background(SignalStyle.paper.opacity(0.985))
        .overlay {
            RoundedRectangle(cornerRadius: SignalStyle.cardRadius, style: .continuous)
                .stroke(SignalStyle.separator.opacity(0.82), lineWidth: 0.7)
        }
        .clipShape(RoundedRectangle(cornerRadius: SignalStyle.cardRadius, style: .continuous))
        .shadow(color: SignalStyle.accent.opacity(0.045), radius: 18, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.28), radius: 14, x: 0, y: 7)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: player.currentSong != nil)
        .themeRenderInteractiveLayer()
    }

    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                switchTab(direction: value.translation.width < 0 ? 1 : -1)
            }
    }

    private func switchTab(direction: Int) {
        let allTabs = Tab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }
        let nextIndex = currentIndex + direction
        guard allTabs.indices.contains(nextIndex) else { return }

        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            currentTab = allTabs[nextIndex]
        }
    }
}

private struct SignalUnifiedTabRail: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionHighlight

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let selected = currentTab == tab
                let label = tabLabel(tab)

                Button {
                    HapticManager.shared.light()
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
                        currentTab = tab
                    }
                } label: {
                    ZStack {
                        if selected {
                            RoundedRectangle(cornerRadius: SignalStyle.buttonRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            SignalStyle.accent.opacity(0.12),
                                            SignalStyle.controlPressed,
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: SignalStyle.buttonRadius, style: .continuous)
                                        .stroke(SignalStyle.accent.opacity(0.22), lineWidth: 0.75)
                                }
                                .matchedGeometryEffect(id: "signal-tab-selection", in: selectionHighlight)
                        }

                        VStack(spacing: 4) {
                            MonoIcon(
                                icon: selected ? tab.icon : tab.monoIcon,
                                size: 15,
                                color: selected ? SignalStyle.accent : SignalStyle.inkMuted,
                                lineWidth: selected ? 1.85 : 1.5
                            )

                            Text(label)
                                .font(SignalStyle.labelFont(9.5, weight: selected ? .semibold : .medium))
                                .foregroundStyle(selected ? SignalStyle.ink : SignalStyle.inkMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .contentShape(RoundedRectangle(cornerRadius: SignalStyle.buttonRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .signalHoverExpansionDisabled()
                .accessibilityLabel(label)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .frame(height: 58)
    }

    private func tabLabel(_ tab: Tab) -> String {
        NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")
    }
}

struct SignalClassicFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var safeBottomInset: CGFloat {
        min(max(DeviceLayout.safeAreaBottom, 0) * 0.42, DeviceLayout.isPad ? 12 : 15)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                if let song = player.currentSong {
                    SignalMiniPlayerStrip(song: song)
                        .swipeToSkip()
                }

                SignalClassicTabRail(currentTab: $currentTab)
            }
            .padding(.bottom, safeBottomInset)
            .background(SignalStyle.paper.opacity(0.995))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(SignalStyle.separator.opacity(0.94))
                    .frame(height: 0.7)
            }
            .themeRenderInteractiveLayer()
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: player.currentSong != nil)
    }
}

private struct SignalClassicTabRail: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let selected = currentTab == tab
                let label = tabLabel(tab)

                Button {
                    HapticManager.shared.light()
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        currentTab = tab
                    }
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            MonoIcon(
                                icon: selected ? tab.icon : tab.monoIcon,
                                size: 17,
                                color: selected ? SignalStyle.accent : SignalStyle.inkMuted,
                                lineWidth: selected ? 1.85 : 1.45
                            )

                            RoundedRectangle(cornerRadius: 1, style: .continuous)
                                .fill(selected ? SignalStyle.accent : Color.clear)
                                .frame(width: 4, height: 4)
                                .rotationEffect(.degrees(45))
                                .offset(y: -17)
                        }
                        .frame(height: 22)

                        Text(label)
                            .font(SignalStyle.labelFont(9.5, weight: selected ? .semibold : .medium))
                            .foregroundStyle(selected ? SignalStyle.ink : SignalStyle.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        selected ? SignalStyle.controlPressed.opacity(0.9) : Color.clear,
                        in: RoundedRectangle(cornerRadius: SignalStyle.compactRadius, style: .continuous)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: SignalStyle.compactRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .signalHoverExpansionDisabled()
                .accessibilityLabel(label)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, DeviceLayout.isPad ? 40 : 10)
        .frame(height: 58)
    }

    private func tabLabel(_ tab: Tab) -> String {
        NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")
    }
}

struct SignalMinimalFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsTabs = false
    @State private var showsQueue = false

    var body: some View {
        VStack {
            Spacer()

            Group {
                if showsTabs {
                    tabChooser
                } else if let song = player.currentSong {
                    playerCommand(song: song)
                } else {
                    navigationCommand
                }
            }
            .frame(height: 50)
            .padding(.horizontal, 6)
            .background(SignalStyle.paper.opacity(0.99))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(SignalStyle.separator.opacity(0.9))
                    .frame(height: 0.7)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(SignalStyle.separator.opacity(0.48))
                    .frame(height: 0.65)
            }
            .clipShape(RoundedRectangle(cornerRadius: SignalStyle.cardRadius, style: .continuous))
            .iPadContentWidth(600)
            .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
            .padding(.bottom, 8)
            .themeRenderInteractiveLayer()
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: showsTabs)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: player.currentSong != nil)
        .monoSheet(isPresented: $showsQueue, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private var navigationCommand: some View {
        HStack(spacing: 10) {
            activeTabButton

            Spacer(minLength: 8)

            Button {
                HapticManager.shared.light()
                showsTabs = true
            } label: {
                MonoIcon(icon: .layers, size: 14, color: SignalStyle.accent, lineWidth: 1.7)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .signalHoverExpansionDisabled()
            .accessibilityLabel(NSLocalizedString("floating_bar_minimal", comment: ""))
        }
    }

    private var activeTabButton: some View {
        Button {
            HapticManager.shared.light()
            showsTabs = true
        } label: {
            HStack(spacing: 9) {
                MonoIcon(icon: currentTab.icon, size: 16, color: SignalStyle.accent, lineWidth: 1.8)

                Text(tabLabel(currentTab))
                    .font(SignalStyle.monoFont(11, weight: .semibold))
                    .foregroundStyle(SignalStyle.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(height: 40)
            .background(
                SignalStyle.screen,
                in: RoundedRectangle(cornerRadius: SignalStyle.compactRadius, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: SignalStyle.compactRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .signalHoverExpansionDisabled()
    }

    private var tabChooser: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let selected = currentTab == tab
                let label = tabLabel(tab)

                Button {
                    HapticManager.shared.light()
                    currentTab = tab
                    showsTabs = false
                } label: {
                    HStack(spacing: 6) {
                        MonoIcon(
                            icon: selected ? tab.icon : tab.monoIcon,
                            size: 15,
                            color: selected ? SignalStyle.accent : SignalStyle.inkMuted,
                            lineWidth: selected ? 1.8 : 1.45
                        )

                        if selected {
                            Text(label)
                                .font(SignalStyle.monoFont(9.5, weight: .semibold))
                                .foregroundStyle(SignalStyle.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    .frame(minWidth: selected ? 80 : 42, maxWidth: selected ? .infinity : 42, minHeight: 40)
                    .background(
                        selected ? SignalStyle.screen : Color.clear,
                        in: RoundedRectangle(cornerRadius: SignalStyle.compactRadius, style: .continuous)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: SignalStyle.compactRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .signalHoverExpansionDisabled()
                .accessibilityLabel(label)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func playerCommand(song: Song) -> some View {
        HStack(spacing: 9) {
            Button {
                HapticManager.shared.light()
                showsTabs = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: song.coverUrl, width: 34, height: 34) {
                        SignalStyle.controlPressed
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: SignalStyle.compactRadius, style: .continuous))

                    Circle()
                        .fill(SignalStyle.accent)
                        .frame(width: 5, height: 5)
                        .overlay(Circle().stroke(SignalStyle.paper, lineWidth: 1))
                        .offset(x: 2, y: 2)
                }
            }
            .buttonStyle(.plain)
            .signalHoverExpansionDisabled()
            .accessibilityLabel(tabLabel(currentTab))

            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(
                    text: song.name,
                    font: SignalStyle.labelFont(12.5, weight: .semibold),
                    color: SignalStyle.ink,
                    speed: 24
                )
                .frame(height: 15)

                MarqueeText(
                    text: player.lyricLineText ?? song.artistName,
                    font: SignalStyle.labelFont(10, weight: .regular),
                    color: SignalStyle.inkMuted,
                    speed: 22
                )
                .frame(height: 13)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .swipeSkipTextMotion()
            .contentShape(Rectangle())
            .onTapWithHaptic { openPlayer() }

            Button(action: { player.togglePlayPause() }) {
                MonoIcon(
                    icon: player.isPlaying ? .pause : .play,
                    size: 14,
                    color: SignalStyle.accent,
                    lineWidth: 1.8
                )
                .frame(width: 34, height: 40)
            }
            .buttonStyle(.plain)
            .signalHoverExpansionDisabled()

            Button(action: { showsQueue = true }) {
                MonoIcon(icon: .list, size: 13, color: SignalStyle.inkSoft, lineWidth: 1.6)
                    .frame(width: 34, height: 40)
            }
            .buttonStyle(.plain)
            .signalHoverExpansionDisabled()
        }
        .swipeToSkip()
    }

    private func tabLabel(_ tab: Tab) -> String {
        NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")
    }

    private func openPlayer() {
        guard player.currentSong != nil else { return }
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

struct SignalFloatingBallBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var pulse = false

    var body: some View {
        GeometryReader { _ in
            VStack {
                Spacer()

                HStack(spacing: 10) {
                    Spacer(minLength: 12)

                    if isExpanded {
                        satelliteRail
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }

                    floatingNode
                }
                .padding(.trailing, DeviceLayout.isPad ? 40 : 18)
                .padding(.bottom, max(18, DeviceLayout.safeAreaBottom + 8))
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var floatingNode: some View {
        Button {
            HapticManager.shared.light()
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(SignalStyle.accent.opacity(pulse ? 0.08 : 0.34), lineWidth: 0.8)
                    .scaleEffect(pulse ? 1.28 : 1.02)

                Circle()
                    .stroke(SignalStyle.accent.opacity(pulse ? 0.3 : 0.08), lineWidth: 0.7)
                    .scaleEffect(pulse ? 1.12 : 0.92)

                Circle()
                    .fill(SignalStyle.paper.opacity(0.99))
                    .overlay(Circle().stroke(SignalStyle.separator.opacity(0.9), lineWidth: 0.8))

                if let song = player.currentSong {
                    CachedAsyncImage(url: song.coverUrl, width: 42, height: 42) {
                        SignalStyle.controlPressed
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                    .opacity(isExpanded ? 0.26 : 0.88)
                }

                MonoIcon(
                    icon: isExpanded ? .close : .layers,
                    size: isExpanded ? 10 : 13,
                    color: isExpanded ? SignalStyle.ink : SignalStyle.accent,
                    lineWidth: 1.8
                )
                .frame(width: 25, height: 25)
                .background(SignalStyle.paper.opacity(0.92), in: Circle())
            }
            .frame(width: 56, height: 56)
            .shadow(color: Color.black.opacity(0.28), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .signalHoverExpansionDisabled()
        .accessibilityLabel(NSLocalizedString("floating_bar_ball", comment: ""))
        .onLongPressGesture(minimumDuration: 0.45) {
            openPlayer()
        }
    }

    private var satelliteRail: some View {
        HStack(spacing: 9) {
            ForEach(Tab.allCases, id: \.self) { tab in
                satelliteButton(tab)
            }

            if player.currentSong != nil {
                Button(action: { player.togglePlayPause() }) {
                    MonoIcon(
                        icon: player.isPlaying ? .pause : .play,
                        size: 13,
                        color: SignalStyle.accent,
                        lineWidth: 1.8
                    )
                    .frame(width: 44, height: 44)
                    .background(SignalStyle.paper.opacity(0.99), in: Circle())
                    .overlay(Circle().stroke(SignalStyle.separator.opacity(0.84), lineWidth: 0.7))
                }
                .buttonStyle(.plain)
                .signalHoverExpansionDisabled()
            }
        }
        .themeRenderInteractiveLayer()
    }

    private func satelliteButton(_ tab: Tab) -> some View {
        let selected = currentTab == tab
        let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")

        return Button {
            HapticManager.shared.light()
            currentTab = tab
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                isExpanded = false
            }
        } label: {
            ZStack {
                Circle()
                    .fill(SignalStyle.paper.opacity(0.99))

                Circle()
                    .stroke(selected ? SignalStyle.accent : SignalStyle.separator.opacity(0.84), lineWidth: selected ? 1.2 : 0.7)

                MonoIcon(
                    icon: selected ? tab.icon : tab.monoIcon,
                    size: 15,
                    color: selected ? SignalStyle.accent : SignalStyle.inkMuted,
                    lineWidth: selected ? 1.8 : 1.45
                )

                Circle()
                    .fill(selected ? SignalStyle.accent : Color.clear)
                    .frame(width: 4, height: 4)
                    .offset(y: 14)
            }
            .frame(width: 44, height: 44)
            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .signalHoverExpansionDisabled()
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func openPlayer() {
        guard player.currentSong != nil else { return }
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

struct SignalMiniPlayerStrip: View {
    let song: Song
    @State private var showPlaylist = false
    @ObservedObject private var player = FloatingBarPlaybackModel.shared

    private var subtitleText: String {
        player.lyricLineText ?? song.artistName
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 10) {
                CachedAsyncImage(url: song.coverUrl) {
                    SignalStyle.controlPressed
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: SignalStyle.compactRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: song.name,
                        font: SignalStyle.labelFont(13, weight: .semibold),
                        color: SignalStyle.ink,
                        speed: 25
                    )
                    .frame(height: 16)

                    MarqueeText(
                        text: subtitleText,
                        font: SignalStyle.labelFont(11, weight: .medium),
                        color: SignalStyle.inkSoft,
                        speed: 22
                    )
                    .frame(height: 14)
                    .animation(.easeInOut(duration: 0.25), value: player.lyricLineText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                HStack(spacing: 6) {
                    signalControl(icon: player.isPlaying ? .pause : .play, tint: SignalStyle.accent) {
                        player.togglePlayPause()
                    }

                    signalControl(icon: .list, tint: SignalStyle.inkSoft) {
                        showPlaylist.toggle()
                    }

                    if !player.isPlaying {
                        signalControl(icon: .close, tint: SignalStyle.inkMuted, size: 9) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 9)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapWithHaptic { openPlayer() }
            }

            ProgressBarView()
                .frame(height: 2.3)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .background(SignalStyle.screen.opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SignalStyle.separator.opacity(0.62))
                .frame(height: 0.65)
        }
        .monoSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func signalControl(
        icon: MonoIcon.IconType,
        tint: Color,
        size: CGFloat = 14,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: size, color: tint, lineWidth: 1.75)
                .frame(width: 32, height: 32)
                .background(
                    SignalStyle.controlPressed,
                    in: RoundedRectangle(cornerRadius: SignalStyle.compactRadius, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: SignalStyle.compactRadius, style: .continuous))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
        .signalHoverExpansionDisabled()
    }

    private func openPlayer() {
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

extension View {
    @ViewBuilder
    func signalHoverExpansionDisabled() -> some View {
        if #available(iOS 17.0, *) {
            hoverEffectDisabled()
        } else {
            self
        }
    }
}
