import SwiftUI
import Combine
import LiquidGlassEffect

struct PersonalFMView: View {
    @ObservedObject var player = PlayerManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var fmSongs: [Song] = []
    @State private var currentFMSong: Song?
    @State private var isLoading = false
    @State private var showControls = true
    @State private var cancellables = Set<AnyCancellable>()
    
    // Theme Reference (Strict Black & White)
    private struct Theme {
        static let background = Color.clear // Was Color.white
        static let text = Color.black
        static let secondaryText = Color.gray
        static let accent = Color.black
        static let cardBackground = Color.white.opacity(0.8) // Slight transparency for glass effect
    }

    // MARK: - Waveform Component (Copied & Adapted from FullScreenPlayerView)
    struct WaveformProgressBar: View {
        @Binding var currentTime: Double
        let duration: Double
        var color: Color = .black
        let onSeek: (Double) -> Void
        let onCommit: (Double) -> Void
        
        // Configuration
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
            .onChange(of: duration) { _ in
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
    
    // Animation States
    @State private var dragOffset: CGSize = .zero
    @State private var cardScale: CGFloat = 1.0
    @State private var isDraggingSlider = false
    @State private var dragTimeValue: Double = 0
    
    var body: some View {
        ZStack {
            // 1. Aside Background
            AsideBackground()
            
            // 2. Content Layer
            VStack(spacing: 0) {
                // Header Space
                Spacer()
                    .frame(height: 60)
                
                Spacer()
                
                // Card Stack Section
                ZStack {
                    if let song = currentFMSong {
                        VStack(spacing: 0) {
                            // Cover Art Card (Monochrome Shadow)
                            ZStack {
                                RoundedRectangle(cornerRadius: 32)
                                    .fill(Theme.cardBackground)
                                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                                    .background(LiquidGlassMetalView(cornerRadius: 32, backgroundCaptureFrameRate: 20))
                                
                                CachedAsyncImage(url: song.coverUrl) {
                                    Color.gray.opacity(0.05).overlay(
                                        AsideIcon(icon: .fm, size: 80, color: .black.opacity(0.1))
                                    )
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 280, height: 280)
                                .cornerRadius(24)
                                .padding(12)
                            }
                            .frame(width: 304, height: 304)
                            .padding(.bottom, 40)
                        
                        // Progress Bar (Waveform)
                        WaveformProgressBar(
                            currentTime: Binding(
                                get: { isDraggingSlider ? dragTimeValue : player.currentTime },
                                set: { _ in } // Set handled by drag gesture
                            ),
                            duration: player.duration,
                            color: .black,
                            onSeek: { time in
                                isDraggingSlider = true
                                dragTimeValue = time
                            },
                            onCommit: { time in
                                isDraggingSlider = false
                                player.seek(to: time)
                            }
                        )
                        .frame(width: 200, height: 32)
                        .padding(.bottom, 12)
                        .opacity(dragOffset == .zero ? 1 : 0) // Hide when dragging
                        .animation(.easeInOut(duration: 0.2), value: dragOffset == .zero)
                        
                        // Song Info
                            VStack(spacing: 8) {
                                Text(song.name)
                                    .font(.rounded(size: 24, weight: .bold))
                                    .foregroundColor(Theme.text)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .padding(.horizontal, 40)
                                    .id("title-\(song.id)") // Force refresh for transition
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                
                                Text(song.artistName)
                                    .font(.rounded(size: 17, weight: .medium))
                                    .foregroundColor(Theme.secondaryText)
                                    .padding(.horizontal, 40)
                                    .id("artist-\(song.id)")
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }
                        .offset(x: dragOffset.width, y: dragOffset.height * 0.1)
                        .rotationEffect(.degrees(Double(dragOffset.width / 20)))
                        .scaleEffect(cardScale)
                        // Trash Overlay (Left Drag)
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
                            .offset(x: 60) // Positioned relative to card center, moves with card
                            , alignment: .trailing
                        )
                        // Like Overlay (Right Drag)
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
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        cardScale = 1.0
                                        
                                        // Left Swipe -> Trash
                                        if value.translation.width < -120 {
                                            // Animate away
                                            dragOffset = CGSize(width: -600, height: 200) // Fall down
                                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                            
                                            // Perform Action
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                trashCurrentSong()
                                                // Reset Position (hidden)
                                                dragOffset = .zero
                                            }
                                        } 
                                        // Right Swipe -> Like & Next
                                        else if value.translation.width > 120 {
                                            dragOffset = CGSize(width: 600, height: 0)
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            
                                            // Like Action
                                            if let id = currentFMSong?.id {
                                                LikeManager.shared.toggleLike(songId: id)
                                            }
                                            
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                nextSong()
                                                dragOffset = .zero
                                            }
                                        }
                                        // Reset
                                        else {
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
                
                // 3. Bottom Controls (Strict Monochrome)
                HStack(spacing: 40) {
                    // Heart
                    if let songId = currentFMSong?.id {
                        LikeButton(songId: songId, size: 24, activeColor: .red, inactiveColor: .black)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(Color.white))
                            .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
                    } else {
                        Button(action: {}) {
                            AsideIcon(icon: .like, size: 24, color: .black)
                                .frame(width: 50, height: 50)
                                .background(Circle().fill(Color.white))
                                .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
                        }
                    }
                    
                    // Main Play/Pause (Solid Black)
                    Button(action: {
                        UISelectionFeedbackGenerator().selectionChanged()
                        PlayerManager.shared.togglePlayPause()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 72, height: 72)
                                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                            
                            AsideIcon(icon: PlayerManager.shared.isPlaying ? .pause : .play, size: 26, color: .white)
                                .offset(x: PlayerManager.shared.isPlaying ? 0 : 2)
                        }
                    }
                    .scaleEffect(player.isPlaying ? 1.0 : 0.95)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: player.isPlaying)
                    
                    // Next Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        nextSong()
                    }) {
                        AsideIcon(icon: .next, size: 24, color: .black)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(Color.white))
                            .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
                    }
                }
                .padding(.bottom, 50)
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(
            // Header Layer (Absolute)
            VStack {
                HStack(alignment: .center) {
                    AsideBackButton(style: .dismiss, isDarkBackground: false)
                    
                    Spacer()
                    
                    Text(LocalizedStringKey("player_private_fm"))
                        .font(.rounded(size: 16, weight: .black))
                        .foregroundColor(.black)
                        .tracking(1.5)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    // 占位元素，与左边按钮宽度相同，保持标题居中
                    Color.clear
                        .frame(width: 44, height: 44)
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
        .onChange(of: player.currentSong?.id) { _ in syncPlayerState() }
    }
    
    // MARK: - Logic
    
    private func setupFM() {
        PlayerManager.shared.isTabBarHidden = true
        
        // Logical check: Is FM already playing in PlayerManager?
        if PlayerManager.shared.isPlayingFM && !PlayerManager.shared.context.isEmpty {
            // Restore state from PlayerManager to avoid interruption
            self.fmSongs = PlayerManager.shared.context
            self.currentFMSong = PlayerManager.shared.currentSong
            print("Personal FM: Resuming existing FM session")
        } else {
            // No FM session found, load fresh
            print("Personal FM: Starting fresh session")
            loadFMData()
        }
    }
    
    private func teardownFM() {
        PlayerManager.shared.isTabBarHidden = false
    }
    
    private func syncPlayerState() {
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
        
        APIService.shared.fetchPersonalFM()
            .sink(receiveCompletion: { completion in
                DispatchQueue.main.async {
                    if !append { self.isLoading = false }
                    if case .failure(let error) = completion {
                        print("FM Load Error: \(error)")
                    }
                }
            }, receiveValue: { songs in
                DispatchQueue.main.async {
                    if append {
                        self.fmSongs.append(contentsOf: songs)
                        PlayerManager.shared.appendContext(songs: songs)
                    } else {
                        self.fmSongs = songs
                        if let first = songs.first {
                            self.currentFMSong = first
                            // Don't auto play when entering FM
                            PlayerManager.shared.playFM(song: first, in: songs, autoPlay: false)
                        }
                    }
                }
            })
            .store(in: &cancellables)
    }
    
    private func nextSong() {
        PlayerManager.shared.next()
    }
    
    private func trashCurrentSong() {
        guard let song = currentFMSong else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let currentTime = Int(PlayerManager.shared.currentTime)
        APIService.shared.trashFM(id: song.id, time: currentTime)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
        PlayerManager.shared.next()
    }
    
    private func emptyStateView() -> some View {
        VStack(spacing: 24) {
            AsideIcon(icon: .fm, size: 40, color: .black.opacity(0.15))
            
            VStack(spacing: 8) {
                Text(LocalizedStringKey("fm_offline"))
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundColor(.black)
                
                Text(LocalizedStringKey("fm_offline_desc"))
                    .font(.rounded(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { loadFMData() }) {
                Text(LocalizedStringKey("action_retry"))
                    .font(.rounded(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black))
            }
        }
    }
}
