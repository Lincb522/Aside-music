import SwiftUI
import Combine

struct PersonalFMView: View {
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var fmSongs: [Song] = []
    @State private var currentFMSong: Song?
    @State private var isLoading = false
    @State private var showControls = true
    @State private var fmLoadTask: Task<Void, Never>?
    @State private var trashTask: Task<Void, Never>?

    private struct Theme {
        static var background: Color { .clear }
        static var text: Color {
            if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
            if SequoiaStyle.isActive { return SequoiaStyle.ink }
            if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
            return Color.monologueTextPrimary
        }

        static var secondaryText: Color {
            if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
            if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
            if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
            return Color.monologueTextSecondary
        }

        static var accent: Color {
            if PetWhiteStyle.isActive { return PetWhiteStyle.accent }
            if SequoiaStyle.isActive { return SequoiaStyle.accent }
            if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
            return Color.monologueTextPrimary
        }

        static var accentForeground: Color {
            if PetWhiteStyle.isActive { return PetWhiteStyle.onAccent }
            if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
            if NeumorphicStyle.isActive { return Color(light: .white, dark: .black) }
            return Color.monologueIconForeground
        }

        static var cardBackground: Color {
            if PetWhiteStyle.isActive { return PetWhiteStyle.surfaceRaised }
            if SequoiaStyle.isActive { return SequoiaStyle.materialRaised }
            if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
            return Color.monologueGlassTint.opacity(0.8)
        }

        static var pressedBackground: Color {
            if PetWhiteStyle.isActive { return PetWhiteStyle.surfacePressed }
            if SequoiaStyle.isActive { return SequoiaStyle.materialPressed }
            if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
            return Color.monologueGlassTint
        }

        static var iconWash: Color {
            if PetWhiteStyle.isActive { return PetWhiteStyle.butter.opacity(0.74) }
            if SequoiaStyle.isActive { return SequoiaStyle.selectedWash }
            return pressedBackground
        }

        static var titleFont: Font {
            if PetWhiteStyle.isActive { return PetWhiteStyle.titleFont(24, weight: .black) }
            return SequoiaStyle.isActive ? SequoiaStyle.titleFont(24, weight: .semibold) : .rounded(size: 24, weight: .bold)
        }

        static var artistFont: Font {
            if PetWhiteStyle.isActive { return PetWhiteStyle.bodyFont(17, weight: .semibold) }
            return SequoiaStyle.isActive ? SequoiaStyle.bodyFont(17, weight: .medium) : .rounded(size: 17, weight: .medium)
        }
    }

    // MARK: - Waveform Component

    struct WaveformProgressBar: View {
        var currentTime: Double
        let duration: Double
        var isPlaying: Bool = false
        var color: Color = .monologueTextPrimary
        let onSeek: (Double) -> Void
        let onCommit: (Double) -> Void

        var body: some View {
            let progress = duration > 0 ? CGFloat(min(max(currentTime / duration, 0), 1)) : 0

            GlobalWaveformPlaybackProgressBar(
                progress: progress,
                isPlaying: isPlaying,
                color: color,
                trackOpacity: 0.12,
                fillColors: progressFillColors,
                onSeek: { p in onSeek(Double(p) * duration) },
                onCommit: { p in onCommit(Double(p) * duration) }
            )
        }

        private var progressFillColors: [Color] {
            if MangaStyle.isActive { return [MangaStyle.accentPink, MangaStyle.labelYellow] }
            if MujiStyle.isActive { return [MujiStyle.clay, MujiStyle.indigo.opacity(0.86)] }
            if NeumorphicStyle.isActive { return [NeumorphicStyle.accent, NeumorphicStyle.sage] }
            if CapsuleStyle.isActive { return CapsuleStyle.accentGradient }
            if SequoiaStyle.isActive { return [SequoiaStyle.accent, SequoiaStyle.aqua] }
            if LiquidGlassStyle.isActive { return [LiquidGlassStyle.accent, LiquidGlassStyle.cyan, LiquidGlassStyle.violet] }
            if ClayStyle.isActive { return [ClayStyle.sky, ClayStyle.peach] }
            if SignalStyle.isActive { return [SignalStyle.accent, SignalStyle.mint] }
            if BentoStyle.isActive { return [BentoStyle.tomato, BentoStyle.mustard] }
            return [color.opacity(0.66), color.opacity(0.96)]
        }

    }

    // MARK: - FM 播放状态分离

    /// 当前 player 是否正在播放 FM 内容
    private var isOwnFMContent: Bool {
        player.playSource == .fm
    }

    /// FM 是否正在播放（只有播放源匹配时才为 true）
    private var isFMPlaying: Bool {
        isOwnFMContent && player.isPlaying
    }

    @ObservedObject private var timePub = PlaybackTimePublisher.shared
    @ObservedObject private var lyricVM = LyricViewModel.shared
    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero
    @State private var cardScale: CGFloat = 1.0
    @State private var isDraggingSlider = false
    @State private var dragTimeValue: Double = 0
    @State private var currentFMMode: String = "DEFAULT"
    @State private var showFMModePicker = false

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedPageBackground()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                Spacer()

                ZStack {
                    if let song = currentFMSong {
                        VStack(spacing: 0) {
                            ZStack {
                                CachedAsyncImage(url: song.coverUrl) {
                                    Theme.pressedBackground.opacity(0.72).overlay(
                                        MonologueIcon(icon: .fm, size: 80, color: Theme.accent.opacity(0.12))
                                    )
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: DeviceLayout.isPad ? 400 : 300, height: DeviceLayout.isPad ? 400 : 300)
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                                .opacity(isFlipped ? 0 : 1)
                                
                                fmLyricsBackView(song: song)
                                    .frame(width: DeviceLayout.isPad ? 400 : 300, height: DeviceLayout.isPad ? 400 : 300)
                                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                                    .opacity(isFlipped ? 1 : 0)
                            }
                            .rotation3DEffect(
                                .degrees(isFlipped ? 180 : 0),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.5
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    isFlipped.toggle()
                                }
                            }
                            .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 10)
                            .overlay {
                                if SequoiaStyle.isActive {
                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .stroke(SequoiaStyle.luminousSeparator.opacity(0.44), lineWidth: 0.7)
                                }
                            }
                            .padding(.bottom, 40)

                        fmProgressBar
                        .padding(.bottom, 12)
                        .opacity(dragOffset == .zero ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: dragOffset == .zero)

                            VStack(spacing: 8) {
                                Text(song.name)
                                    .font(Theme.titleFont)
                                    .foregroundColor(Theme.text)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.82)
                                    .padding(.horizontal, DeviceLayout.isPad ? 60 : 40)
                                    .id("title-\(song.id)")
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

                                Text(song.artistName)
                                    .font(Theme.artistFont)
                                    .foregroundColor(Theme.secondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.84)
                                    .padding(.horizontal, DeviceLayout.isPad ? 60 : 40)
                                    .id("artist-\(song.id)")
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }
                        .compositingGroup()
                        .scaleEffect(cardScale)
                        .offset(x: dragOffset.width, y: dragOffset.height * 0.1)
                        .rotationEffect(.degrees(Double(dragOffset.width / 20)))
                        .overlay(
                            ZStack {
                                if dragOffset.width < -50 {
                                    Circle()
                                        .fill(Color.black.opacity(0.8))
                                        .frame(width: 80, height: 80)

                                    MonologueIcon(icon: .trash, size: 32, color: .white)
                                }
                            }
                            .opacity(Double(min(abs(dragOffset.width) / 150, 1.0)))
                            .offset(x: 60)
                            , alignment: .trailing
                        )
                        .overlay(
                            ZStack {
                                if dragOffset.width > 50 {
                                    Circle()
                                        .fill(Color.red.opacity(0.9))
                                        .frame(width: 80, height: 80)

                                    MonologueIcon(icon: .like, size: 32, color: .white)
                                }
                            }
                            .opacity(Double(min(abs(dragOffset.width) / 150, 1.0)))
                            .offset(x: -60)
                            , alignment: .leading
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation
                                    withAnimation(.interactiveSpring()) {
                                        cardScale = 0.96
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.width < -120 {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            dragOffset = CGSize(width: -600, height: 200)
                                        }
                                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            trashCurrentSong()
                                            cardScale = 1.0
                                            dragOffset = .zero
                                        }
                                    }
                                    else if value.translation.width > 120 {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            dragOffset = CGSize(width: 600, height: 0)
                                        }
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                                        if let id = currentFMSong?.id {
                                            LikeManager.shared.toggleLike(songId: id)
                                        }

                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            nextSong()
                                            cardScale = 1.0
                                            dragOffset = .zero
                                        }
                                    }
                                    else {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            cardScale = 1.0
                                            dragOffset = .zero
                                        }
                                    }
                                }
                        )
                    } else if isLoading {
                        MonologueLoadingView(text: "LOADING STATIONS")
                    } else {
                        emptyStateView()
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer()

                fmControlsBar
                    .padding(.bottom, 50)
            }
            .frame(maxWidth: .infinity)
            .iPadContentWidth()
        }
        .overlay(
            VStack {
                HStack(alignment: .center) {
                    if PetWhiteStyle.isActive {
                        Button(action: { dismiss() }) {
                            PetWhiteChevronIcon(
                                direction: .down,
                                size: 20,
                                fallbackColor: PetWhiteStyle.ink
                            )
                            .frame(width: 44, height: 44)
                            .background(
                                PetWhiteClayPuck(shape: Circle(), tint: PetWhiteStyle.surfaceRaised)
                            )
                            .contentShape(Circle())
                        }
                        .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.88))
                    } else {
                        MonologueBackButton(style: .dismiss, isDarkBackground: false)
                    }

                    Spacer()

                    Text(LocalizedStringKey("player_private_fm"))
                        .font(PetWhiteStyle.isActive
                              ? PetWhiteStyle.labelFont(15, weight: .black)
                              : .rounded(size: 16, weight: .black))
                        .foregroundColor(Theme.text)
                        .tracking(PetWhiteStyle.isActive ? 1.1 : 1.5)
                        .textCase(.uppercase)

                    Spacer()

                    // FM 模式切换按钮
                    if PetWhiteStyle.isActive {
                        Button(action: { showFMModePicker = true }) {
                            PetWhitePackIcon(
                                icon: .fmMode,
                                size: 18,
                                visualScale: 1.04,
                                fallbackColor: PetWhiteStyle.ink,
                                lineWidth: 1.9
                            )
                            .frame(width: 44, height: 44)
                            .background(
                                PetWhiteClayPuck(shape: Circle(), tint: PetWhiteStyle.surfaceRaised)
                            )
                        }
                        .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.88))
                    } else {
                        Button(action: { showFMModePicker = true }) {
                            MonologueIcon(icon: .fmMode, size: 20, color: Theme.accent)
                                .frame(width: 44, height: 44)
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.top, 12)
                Spacer()
            }
        )
        .statusBar(hidden: false)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .onAppear { setupFM() }
        .onDisappear { teardownFM() }
        .onChange(of: player.currentSong?.id) {
            syncPlayerState()
            withAnimation(.spring(response: 0.4)) {
                isFlipped = false
            }
        }
        .confirmationDialog(
            NSLocalizedString("fm_mode_title", comment: ""),
            isPresented: $showFMModePicker,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("fm_mode_default", comment: "")) { switchFMMode("DEFAULT") }
            Button(NSLocalizedString("fm_mode_familiar", comment: "")) { switchFMMode("FAMILIAR") }
            Button(NSLocalizedString("fm_mode_explore", comment: "")) { switchFMMode("EXPLORE") }
            Button(NSLocalizedString("alert_cancel", comment: ""), role: .cancel) {}
        }
    }

    // MARK: - Progress Bar

    /// FM 卡片下方的进度条；paw 主题下复用全局播放器的 PawPlaybackProgressBar，
    /// 其他主题维持现有的 WaveformProgressBar，避免视觉错配。
    @ViewBuilder
    private var fmProgressBar: some View {
        if PetWhiteStyle.isActive {
            PawPlaybackProgressBar(
                isDragging: $isDraggingSlider,
                dragValue: $dragTimeValue,
                showsTimeLabels: false,
                railHeight: 32,
                hasContainer: false,
                onSeek: { time in
                    // 只有 FM 播放源时才执行 seek，保持与原 WaveformProgressBar 一致语义
                    if isOwnFMContent {
                        player.seek(to: time)
                    }
                }
            )
            .frame(width: DeviceLayout.isPad ? 320 : 260)
            .opacity(isOwnFMContent ? 1 : 0.45)
        } else {
            WaveformProgressBar(
                currentTime: isDraggingSlider ? dragTimeValue : (isOwnFMContent ? timePub.currentTime : 0),
                duration: isOwnFMContent ? timePub.duration : 0,
                isPlaying: isFMPlaying,
                color: Theme.accent,
                onSeek: { time in
                    isDraggingSlider = true
                    dragTimeValue = time
                },
                onCommit: { time in
                    isDraggingSlider = false
                    if isOwnFMContent {
                        player.seek(to: time)
                    }
                }
            )
            .frame(width: DeviceLayout.isPad ? 300 : 246, height: 30)
        }
    }

    // MARK: - Controls Bar

    /// 卡片下方的播放控件条；paw 主题下完整切换到 paw 圆形按钮 + 掌印/狗头吉祥物，
    /// 其他主题保持原毛玻璃圆形按钮。
    @ViewBuilder
    private var fmControlsBar: some View {
        if PetWhiteStyle.isActive {
            pawFMControlsBar
        } else {
            defaultFMControlsBar
        }
    }

    private var pawFMControlsBar: some View {
        HStack(spacing: 28) {
            pawFMSideButton {
                Group {
                    if let song = currentFMSong {
                        LikeButton(
                            songId: song.id,
                            isQQMusic: song.isQQMusic,
                            song: song,
                            size: 22,
                            activeColor: PetWhiteStyle.blush,
                            inactiveColor: PetWhiteStyle.stroke
                        )
                    } else {
                        PetWhitePackIcon(
                            icon: .like,
                            size: 22,
                            visualScale: 1.04,
                            fallbackColor: PetWhiteStyle.ink,
                            lineWidth: 2.0
                        )
                    }
                }
            }

            Button(action: {
                UISelectionFeedbackGenerator().selectionChanged()
                if !isFMPlaying, let song = currentFMSong {
                    PlayerManager.shared.playFM(song: song, in: fmSongs, autoPlay: true)
                } else {
                    PlayerManager.shared.togglePlayPause()
                }
            }) {
                ZStack {
                    PetWhiteClayPuck(shape: Circle(), tint: PetWhiteStyle.dogOrange)
                        .frame(width: 78, height: 78)

                    PetWhitePackIcon(
                        icon: isFMPlaying ? .pause : .play,
                        size: 30,
                        visualScale: 1.04,
                        fallbackColor: PetWhiteStyle.onAccent,
                        lineWidth: 2.4
                    )
                    .offset(x: isFMPlaying ? 0 : 2)
                }
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
            .scaleEffect(isFMPlaying ? 1.0 : 0.96)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFMPlaying)

            pawFMSideButton {
                PetWhitePackIcon(
                    icon: .next,
                    size: 22,
                    visualScale: 1.04,
                    fallbackColor: PetWhiteStyle.ink,
                    lineWidth: 2.0
                )
            } action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                nextSong()
            }
        }
    }

    private var defaultFMControlsBar: some View {
        HStack(spacing: 40) {
            if let song = currentFMSong {
                LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 24, activeColor: .red, inactiveColor: Theme.accent)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Theme.pressedBackground))
                    .monologueGlassCircle()
            } else {
                Button(action: {}) {
                    MonologueIcon(icon: .like, size: 24, color: Theme.accent)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Theme.pressedBackground))
                        .monologueGlassCircle()
                }
            }

            Button(action: {
                UISelectionFeedbackGenerator().selectionChanged()
                if !isFMPlaying, let song = currentFMSong {
                    PlayerManager.shared.playFM(song: song, in: fmSongs, autoPlay: true)
                } else {
                    PlayerManager.shared.togglePlayPause()
                }
            }) {
                ZStack {
                    Circle()
                        .fill((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? Theme.accent : Color.monologueGlassTint)
                        .frame(width: 72, height: 72)
                        .monologueGlassCircle()
                        .shadow(color: Color.black.opacity(SequoiaStyle.isActive ? 0.08 : 0.15), radius: SequoiaStyle.isActive ? 14 : 10, x: 0, y: 5)

                    MonologueIcon(icon: isFMPlaying ? .pause : .play, size: 26, color: (NeumorphicStyle.isActive || SequoiaStyle.isActive) ? Theme.accentForeground : Theme.accent)
                        .offset(x: isFMPlaying ? 0 : 2)
                }
            }
            .scaleEffect(isFMPlaying ? 1.0 : 0.95)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFMPlaying)

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                nextSong()
            }) {
                MonologueIcon(icon: .next, size: 24, color: Theme.accent)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Theme.pressedBackground))
                    .monologueGlassCircle()
            }
        }
    }

    private func pawFMSideButton<Label: View>(
        @ViewBuilder label: () -> Label,
        action: (() -> Void)? = nil
    ) -> some View {
        let content = label()
            .frame(width: 56, height: 56)
            .background(
                PetWhiteClayPuck(shape: Circle(), tint: PetWhiteStyle.surfaceRaised)
            )

        return Group {
            if let action {
                Button(action: action) { content }
                    .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.88))
            } else {
                content
            }
        }
    }

    // MARK: - Lyrics Back View
    
    private func fmLyricsBackView(song: Song) -> some View {
        ZStack {
            if PetWhiteStyle.isActive {
                PetWhiteSurfaceBackground(
                    cornerRadius: 28,
                    elevated: true,
                    tint: PetWhiteStyle.surfaceRaised,
                    accent: PetWhiteStyle.sky
                )
            } else {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Theme.cardBackground)
                    .overlay {
                        if SequoiaStyle.isActive {
                            SequoiaSurfaceBackground(cornerRadius: 28, elevated: true, role: .content)
                        }
                    }
            }
            
            // 只有当播放源是 FM 且歌词对应当前 FM 歌曲时才显示歌词
            if isOwnFMContent && lyricVM.currentSongId == song.id && lyricVM.hasLyrics && !lyricVM.lyrics.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            Spacer().frame(height: 40)
                            ForEach(Array(lyricVM.lyrics.enumerated()), id: \.offset) { index, line in
                                let isCurrent = index == lyricVM.currentLineIndex
                                Text(line.text)
                                    .font(.system(size: isCurrent ? 18 : 15, weight: isCurrent ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isCurrent ? Theme.text : Theme.secondaryText.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 20)
                                    .id(index)
                                    .onTapGesture {
                                        if isOwnFMContent {
                                            player.seek(to: line.time)
                                        }
                                    }
                            }
                            Spacer().frame(height: 40)
                        }
                    }
                    .onChange(of: lyricVM.currentLineIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    MonologueIcon(icon: .musicNote, size: 40, color: Theme.secondaryText.opacity(0.3))
                    Text("暂无歌词")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.secondaryText)
                }
            }
        }
    }
    
    // MARK: - Logic

    private func setupFM() {
        if PlayerManager.shared.isPlayingFM && !PlayerManager.shared.context.isEmpty {
            self.fmSongs = PlayerManager.shared.context
            self.currentFMSong = PlayerManager.shared.currentSong
            AppLogger.debug("Personal FM: Resuming existing FM session")
        } else {
            AppLogger.debug("Personal FM: Starting fresh session")
            loadFMData()
        }
    }

    private func teardownFM() {
    }

    private func syncPlayerState() {
        // 只有当播放源是 FM 时才同步状态
        guard isOwnFMContent else { return }

        if let playerSong = player.currentSong {
            if self.currentFMSong?.id != playerSong.id {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    self.currentFMSong = playerSong
                }
            }

            if let index = fmSongs.firstIndex(where: { $0.id == playerSong.id }),
               index >= fmSongs.count - 2 {
                loadFMData(append: true)
            }
        }
    }

    private func loadFMData(append: Bool = false) {
        if !append {
            guard !isLoading else { return }
            isLoading = true
        }

        fmLoadTask?.cancel()
        fmLoadTask = Task {
            do {
                let songs = try await APIService.shared.fetchPersonalFM().async()
                guard !Task.isCancelled else { return }
                if append {
                    self.fmSongs.append(contentsOf: songs)
                    if PlayerManager.shared.isPlayingFM {
                        PlayerManager.shared.appendContext(songs: songs)
                    }
                } else {
                    self.fmSongs = songs
                    if let first = songs.first {
                        self.currentFMSong = first
                        if PlayerManager.shared.isPlaying && !PlayerManager.shared.isPlayingFM {
                            // 正在播放非 FM 内容，仅展示 FM 界面，不切换播放
                        } else if PlayerManager.shared.isPlayingFM {
                            // 已经在播放 FM，不重新开始
                        } else {
                            // 没有在播放任何东西，只预设 FM 上下文，不自动播放
                            PlayerManager.shared.prepareFM(song: first, in: songs)
                        }
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.error("FM Load Error: \(error)")
            }
            if !append { self.isLoading = false }
        }
    }

    private func nextSong() {
        // 如果当前不是 FM 播放源，先切换到 FM 模式
        if !PlayerManager.shared.isPlayingFM {
            // 找到当前 FM 歌曲在列表中的下一首
            if let current = currentFMSong,
               let currentIndex = fmSongs.firstIndex(where: { $0.id == current.id }),
               currentIndex + 1 < fmSongs.count {
                let next = fmSongs[currentIndex + 1]
                PlayerManager.shared.playFM(song: next, in: fmSongs, autoPlay: true)
            } else if let first = fmSongs.first {
                PlayerManager.shared.playFM(song: first, in: fmSongs, autoPlay: true)
            }
            return
        }
        
        // 已经是 FM 播放源，直接用 playFM 播放下一首，确保 index 正确
        if let current = currentFMSong,
           let currentIndex = fmSongs.firstIndex(where: { $0.id == current.id }),
           currentIndex + 1 < fmSongs.count {
            let next = fmSongs[currentIndex + 1]
            PlayerManager.shared.playFM(song: next, in: fmSongs, autoPlay: true)
        } else {
            // 兜底：用 PlayerManager 的 next
            PlayerManager.shared.next()
        }
    }

    private func trashCurrentSong() {
        guard let song = currentFMSong else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        // 只有 FM 播放源时才读取真实播放时间
        let currentTime = isOwnFMContent ? Int(PlayerManager.shared.currentTime) : 0
        trashTask = Task {
            do {
                _ = try await APIService.shared.trashFM(id: song.id, time: currentTime).async()
            } catch {
                AppLogger.error("Trash FM error: \(error)")
            }
        }
        nextSong()
    }

    @ViewBuilder
    private func emptyStateView() -> some View {
        if PetWhiteStyle.isActive {
            pawEmptyStateView
        } else {
            defaultEmptyStateView
        }
    }

    private var pawEmptyStateView: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(PetWhiteStyle.butter.opacity(0.74))
                    .frame(width: 96, height: 96)
                    .overlay(Circle().stroke(PetWhiteStyle.stroke.opacity(0.55), lineWidth: 1.4))
                PetWhitePackIcon(icon: .fm, size: 38, visualScale: 1.04, fallbackColor: PetWhiteStyle.ink, lineWidth: 2.4)
            }

            VStack(spacing: 6) {
                Text(LocalizedStringKey("fm_offline"))
                    .font(PetWhiteStyle.titleFont(20, weight: .black))
                    .foregroundColor(PetWhiteStyle.ink)

                Text(LocalizedStringKey("fm_offline_desc"))
                    .font(PetWhiteStyle.bodyFont(13, weight: .semibold))
                    .foregroundColor(PetWhiteStyle.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            Button(action: { loadFMData() }) {
                HStack(spacing: 7) {
                    PetWhitePackIcon(icon: .refresh, size: 14, visualScale: 1.04, fallbackColor: PetWhiteStyle.onAccent, lineWidth: 2.0)
                    Text(LocalizedStringKey("action_retry"))
                        .font(PetWhiteStyle.labelFont(12, weight: .black))
                }
                .foregroundStyle(PetWhiteStyle.onAccent)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(PetWhiteStyle.accent, in: Capsule())
                .overlay(Capsule().stroke(PetWhiteStyle.stroke, lineWidth: 1))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
        }
    }

    private var defaultEmptyStateView: some View {
        VStack(spacing: 24) {
            MonologueIcon(icon: .fm, size: 40, color: Theme.accent.opacity(0.18))

            VStack(spacing: 8) {
                Text(LocalizedStringKey("fm_offline"))
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundColor(Theme.text)

                Text(LocalizedStringKey("fm_offline_desc"))
                    .font(.rounded(size: 15))
                    .foregroundColor(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Button(action: { loadFMData() }) {
                Text(LocalizedStringKey("action_retry"))
                    .font(.rounded(size: 16, weight: .bold))
                    .foregroundColor((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? Theme.accentForeground : .white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? Theme.accent : Color.monologueIconBackground))
            }
        }
    }

    private func switchFMMode(_ mode: String) {
        currentFMMode = mode
        Task {
            do {
                _ = try await APIService.shared.setPersonalFmMode(mode: mode).async()
                AppLogger.info("FM 模式切换: \(mode)")
                // 切换模式后重新加载 FM 数据
                loadFMData()
            } catch {
                AppLogger.error("FM 模式切换失败: \(error)")
            }
        }
    }
}
