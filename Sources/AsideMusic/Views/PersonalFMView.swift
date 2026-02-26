import SwiftUI
import Combine

struct PersonalFMView: View {
    @ObservedObject var player = PlayerManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var fmSongs: [Song] = []
    @State private var currentFMSong: Song?
    @State private var isLoading = false
    @State private var showControls = true
    @State private var fmLoadTask: Task<Void, Never>?
    @State private var trashTask: Task<Void, Never>?

    private struct Theme {
        static let background = Color.clear
        static let text = Color.asideTextPrimary
        static let secondaryText = Color.asideTextSecondary
        static let accent = Color.asideTextPrimary
        static let cardBackground = Color.asideGlassTint.opacity(0.8)
    }

    // MARK: - Waveform Component

    struct WaveformProgressBar: View {
        @Binding var currentTime: Double
        let duration: Double
        var color: Color = .asideTextPrimary
        let onSeek: (Double) -> Void
        let onCommit: (Double) -> Void

        let barCount = 30
        let barSpacing: CGFloat = 3
        let minHeight: CGFloat = 6

        @State private var amplitudes: [CGFloat] = []

        var body: some View {
            TimelineView(.animation(minimumInterval: 0.1)) { timeline in
                GeometryReader { geometry in
                    let totalWidth = geometry.size.width
                    let barWidth = (totalWidth - (CGFloat(barCount - 1) * barSpacing)) / CGFloat(barCount)
                    let progress = duration > 0 ? currentTime / duration : 0
                    let phase = timeline.date.timeIntervalSinceReferenceDate * 2

                    HStack(alignment: .center, spacing: barSpacing) {
                        ForEach(0..<barCount, id: \.self) { index in
                            let barProgress = Double(index) / Double(barCount - 1)
                            let isPlayed = barProgress <= progress
                            let baseAmplitude = index < amplitudes.count ? amplitudes[index] : 0.5

                            let height = calculateBarHeight(
                                index: index,
                                isPlayed: isPlayed,
                                baseAmplitude: baseAmplitude,
                                phase: phase,
                                maxHeight: geometry.size.height
                            )

                            RoundedRectangle(cornerRadius: 2)
                                .fill(isPlayed ? color : color.opacity(0.15))
                                .frame(width: max(2, barWidth), height: height)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let progress = min(max(value.location.x / totalWidth, 0), 1)
                                let time = progress * duration
                                onSeek(time)
                            }
                            .onEnded { value in
                                let progress = min(max(value.location.x / totalWidth, 0), 1)
                                let time = progress * duration
                                onCommit(time)
                            }
                    )
                }
            }
            .onAppear {
                generateAmplitudes()
            }
            .onChange(of: duration) {
                generateAmplitudes()
            }
        }

        private func calculateBarHeight(index: Int, isPlayed: Bool, baseAmplitude: CGFloat, phase: Double, maxHeight: CGFloat) -> CGFloat {
            var dynamicFactor: CGFloat = 1.0
            if isPlayed {
                let wave = sin(Double(index) * 0.5 + phase)
                dynamicFactor = 1.0 + CGFloat(wave) * 0.35
            }

            let finalAmplitude = baseAmplitude * dynamicFactor
            let safeAmplitude = min(max(finalAmplitude, 0), 1.0)

            return minHeight + safeAmplitude * (maxHeight - minHeight)
        }

        private func generateAmplitudes() {
            amplitudes = (0..<barCount).map { index in
                let normalizedIndex = Double(index) / Double(barCount - 1)
                let envelope = sin(normalizedIndex * .pi)
                let randomFactor = Double.random(in: 0.3...1.0)
                return CGFloat(envelope * randomFactor)
            }
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

    @State private var dragOffset: CGSize = .zero
    @State private var cardScale: CGFloat = 1.0
    @State private var isDraggingSlider = false
    @State private var dragTimeValue: Double = 0
    @State private var currentFMMode: String = "DEFAULT"
    @State private var showFMModePicker = false

    var body: some View {
        ZStack {
            AsideBackground()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                Spacer()

                ZStack {
                    if let song = currentFMSong {
                        VStack(spacing: 0) {
                            CachedAsyncImage(url: song.coverUrl) {
                                Color.gray.opacity(0.05).overlay(
                                    AsideIcon(icon: .fm, size: 80, color: .asideTextPrimary.opacity(0.1))
                                )
                            }
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 300, height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 10)
                            .padding(.bottom, 40)

                        WaveformProgressBar(
                            currentTime: Binding(
                                get: { isDraggingSlider ? dragTimeValue : (isOwnFMContent ? player.currentTime : 0) },
                                set: { _ in }
                            ),
                            duration: isOwnFMContent ? player.duration : 0,
                            color: .asideTextPrimary,
                            onSeek: { time in
                                isDraggingSlider = true
                                dragTimeValue = time
                            },
                            onCommit: { time in
                                isDraggingSlider = false
                                // 只有 FM 播放源时才执行 seek
                                if isOwnFMContent {
                                    player.seek(to: time)
                                }
                            }
                        )
                        .frame(width: 200, height: 32)
                        .padding(.bottom, 12)
                        .opacity(dragOffset == .zero ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: dragOffset == .zero)

                            VStack(spacing: 8) {
                                Text(song.name)
                                    .font(.rounded(size: 24, weight: .bold))
                                    .foregroundColor(Theme.text)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .padding(.horizontal, 40)
                                    .id("title-\(song.id)")
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

                                Text(song.artistName)
                                    .font(.rounded(size: 17, weight: .medium))
                                    .foregroundColor(Theme.secondaryText)
                                    .padding(.horizontal, 40)
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

                                    AsideIcon(icon: .trash, size: 32, color: .white)
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

                                    AsideIcon(icon: .like, size: 32, color: .white)
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
                        AsideLoadingView(text: "LOADING STATIONS")
                    } else {
                        emptyStateView()
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer()

                HStack(spacing: 40) {
                    if let song = currentFMSong {
                        LikeButton(songId: song.id, isQQMusic: song.isQQMusic, size: 24, activeColor: .red, inactiveColor: .asideTextPrimary)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(Color.asideGlassTint))
                            .glassEffect(.regular, in: .circle)
                    } else {
                        Button(action: {}) {
                            AsideIcon(icon: .like, size: 24, color: .asideTextPrimary)
                                .frame(width: 50, height: 50)
                                .background(Circle().fill(Color.asideGlassTint))
                                .glassEffect(.regular, in: .circle)
                        }
                    }

                    Button(action: {
                        UISelectionFeedbackGenerator().selectionChanged()
                        // 如果 FM 没有在实际播放中（包括 prepareFM 预设状态），用 playFM 开始播放
                        if !isFMPlaying, let song = currentFMSong {
                            PlayerManager.shared.playFM(song: song, in: fmSongs, autoPlay: true)
                        } else {
                            PlayerManager.shared.togglePlayPause()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.asideGlassTint)
                                .frame(width: 72, height: 72)
                                .glassEffect(.regular, in: .circle)
                                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)

                            AsideIcon(icon: isFMPlaying ? .pause : .play, size: 26, color: .asideTextPrimary)
                                .offset(x: isFMPlaying ? 0 : 2)
                        }
                    }
                    .scaleEffect(isFMPlaying ? 1.0 : 0.95)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFMPlaying)

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        nextSong()
                    }) {
                        AsideIcon(icon: .next, size: 24, color: .asideTextPrimary)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(Color.asideGlassTint))
                            .glassEffect(.regular, in: .circle)
                    }
                }
                .padding(.bottom, 50)
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(
            VStack {
                HStack(alignment: .center) {
                    AsideBackButton(style: .dismiss, isDarkBackground: false)

                    Spacer()

                    Text(LocalizedStringKey("player_private_fm"))
                        .font(.rounded(size: 16, weight: .black))
                        .foregroundColor(.asideTextPrimary)
                        .tracking(1.5)
                        .textCase(.uppercase)

                    Spacer()

                    // FM 模式切换按钮
                    Button(action: { showFMModePicker = true }) {
                        AsideIcon(icon: .fmMode, size: 20, color: .asideTextPrimary)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                Spacer()
            }
        )
        .statusBar(hidden: false)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .onAppear { setupFM() }
        .onDisappear { teardownFM() }
        .onChange(of: player.currentSong?.id) { syncPlayerState() }
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

    // MARK: - Logic

    private func setupFM() {
        PlayerManager.shared.isTabBarHidden = true

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
        PlayerManager.shared.isTabBarHidden = false
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

    private func emptyStateView() -> some View {
        VStack(spacing: 24) {
            AsideIcon(icon: .fm, size: 40, color: .asideTextPrimary.opacity(0.15))

            VStack(spacing: 8) {
                Text(LocalizedStringKey("fm_offline"))
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundColor(.asideTextPrimary)

                Text(LocalizedStringKey("fm_offline_desc"))
                    .font(.rounded(size: 15))
                    .foregroundColor(.asideTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { loadFMData() }) {
                Text(LocalizedStringKey("action_retry"))
                    .font(.rounded(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.asideIconBackground))
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
