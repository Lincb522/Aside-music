import SwiftUI

struct FullScreenPlayerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var player = PlayerManager.shared
    
    // UI State
    @State private var isDraggingSlider = false
    @State private var dragTimeValue: Double = 0
    @State private var showPlaylist = false
    @State private var showActionSheet = false
    @State private var showQualitySheet = false // Sound Quality Sheet
    @State private var showLyrics = false // Toggle for lyrics view
    @State private var showEQ = false // EQ Sheet
    
    // Settings
    @AppStorage("showTranslation") var showTranslation: Bool = true
    @AppStorage("enableKaraoke") var enableKaraoke: Bool = true
    
    // Constants
    private let spacing: CGFloat = 24
    
    // Dynamic Colors
    // Always use black for content (icons, text) as background is light/colorful
    // Lyrics view has its own overlay handling, but controls remain consistent
    private var contentColor: Color { .black }
    private var secondaryContentColor: Color { .gray }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Dynamic Background
                AsideBackground()
                    .ignoresSafeArea()
                
                // Lyrics Background Dimmer
                if showLyrics {
                    // Removed dark overlay to keep consistent light theme
                    // Just blur the background slightly more if needed
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
                
                // 2. Main Content
                VStack(spacing: 0) {
                    // Header
                    headerView
                        .padding(.top, DeviceLayout.headerTopPadding)
                        .padding(.bottom, 20)
                    
                    // Content Switcher (Art or Lyrics)
                    ZStack {
                        // Artwork
                        artworkView(size: geometry.size.width - 64)
                            .opacity(showLyrics ? 0 : 1)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showLyrics)
                            .gesture(
                                DragGesture()
                                    .onEnded { value in
                                        if value.translation.height > 100 {
                                            dismiss()
                                        }
                                    }
                            )
                        
                        // Lyrics
                        if let song = player.currentSong {
                            LyricsView(song: song, onBackgroundTap: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showLyrics.toggle()
                                }
                            })
                            .opacity(showLyrics ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showLyrics)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showLyrics.toggle()
                        }
                    }
                    
                    Spacer()
                    
                    // Song Info & Controls Container
                    VStack(spacing: 32) {
                        // Title & Artist & Like
                        if !showLyrics {
                            songInfoView
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            // Minimal Info for Lyrics Mode
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(player.currentSong?.name ?? "")
                                        .font(.rounded(size: 20, weight: .bold))
                                        .foregroundColor(contentColor)
                                        .lineLimit(1)
                                    Text(player.currentSong?.artistName ?? "")
                                        .font(.rounded(size: 14, weight: .medium))
                                        .foregroundColor(secondaryContentColor)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                // Karaoke Toggle
                                Button(action: {
                                    withAnimation { enableKaraoke.toggle() }
                                }) {
                                    AsideIcon(icon: .karaoke, size: 20, color: enableKaraoke ? contentColor : secondaryContentColor.opacity(0.3))
                                        .padding(8)
                                        .background(contentColor.opacity(0.05))
                                        .clipShape(Circle())
                                }
                                
                                // Translation Toggle
                                Button(action: {
                                    withAnimation { showTranslation.toggle() }
                                }) {
                                    AsideIcon(icon: .translate, size: 20, color: showTranslation ? contentColor : secondaryContentColor.opacity(0.3))
                                        .padding(8)
                                        .background(contentColor.opacity(0.05))
                                        .clipShape(Circle())
                                }
                                
                                // Like button
                                if let songId = player.currentSong?.id {
                                    LikeButton(songId: songId, size: 22, activeColor: .red, inactiveColor: contentColor)
                                        .padding(8)
                                        .background(contentColor.opacity(0.05))
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Progress Bar
                        progressSection
                            .padding(.vertical, 8)
                        
                        // Main Controls
                        controlsView
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            // Hide Floating Bar when full screen player appears
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                player.isTabBarHidden = true
            }
        }
        .onDisappear {
            // Show Floating Bar when full screen player dismisses
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    player.isTabBarHidden = false
                }
            }
        }
        .sheet(isPresented: $showPlaylist) {
            PlaylistPopupView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("音质选择", isPresented: $showQualitySheet, titleVisibility: .visible) {
            ForEach(SoundQuality.allCases.filter { $0 != .none }, id: \.self) { quality in
                Button(action: {
                    player.switchQuality(quality)
                }) {
                    HStack {
                        Text(quality.displayName)
                        if player.soundQuality == quality {
                            Text("(当前)")
                        }
                    }
                }
            }
            Button("取消", role: .cancel) { }
        }
        .confirmationDialog("更多操作", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("取消", role: .cancel) { }
        }
        .sheet(isPresented: $showEQ) {
            EQView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            AsideBackButton(style: .dismiss, isDarkBackground: false)
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(LocalizedStringKey("player_now_playing"))
                    .font(.rounded(size: 12, weight: .medium))
                    .foregroundColor(secondaryContentColor)
                    .tracking(1)
            }
            
            Spacer()
            
            Button(action: {
                showActionSheet = true
            }) {
                AsideIcon(icon: .more, size: 20, color: contentColor)
            }
            .buttonStyle(AsideBouncingButtonStyle())
            .frame(width: 44, height: 44)
            .background(contentColor.opacity(0.1))
            .clipShape(Circle())
        }
        .padding(.horizontal, 24)
    }
    
    private func artworkView(size: CGFloat) -> some View {
        let artSize = min(size, 360) // Max limit
        
        return ZStack {
            if let song = player.currentSong {
                CachedAsyncImage(url: song.coverUrl) {
                    Color.gray.opacity(0.2)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: artSize, height: artSize)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: artSize, height: artSize)
                    .overlay(
                        AsideIcon(icon: .musicNoteList, size: 80, color: .gray.opacity(0.3))
                    )
            }
        }
        .frame(maxHeight: .infinity) // Allow it to take available space
    }
    
    private var songInfoView: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(player.currentSong?.name ?? "Unknown Song")
                    .font(.rounded(size: 26, weight: .bold))
                    .foregroundColor(contentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(player.currentSong?.artistName ?? "Unknown Artist")
                    .font(.rounded(size: 18, weight: .medium))
                    .foregroundColor(secondaryContentColor)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Quality Switcher
            Button(action: {
                showQualitySheet = true
            }) {
                Text(player.soundQuality.buttonText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(contentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(contentColor.opacity(0.3), lineWidth: 1)
                    )
            }
            
            if let songId = player.currentSong?.id {
                LikeButton(songId: songId, size: 26, activeColor: .red, inactiveColor: contentColor)
            } else {
                AsideIcon(icon: .like, size: 26, color: contentColor)
            }
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 8) {
            // Waveform Progress Bar
            WaveformProgressBar(
                currentTime: Binding(
                    get: { isDraggingSlider ? dragTimeValue : player.currentTime },
                    set: { _ in } // Set handled by drag gesture
                ),
                duration: player.duration,
                color: contentColor,
                onSeek: { time in
                    isDraggingSlider = true
                    dragTimeValue = time
                },
                onCommit: { time in
                    isDraggingSlider = false
                    player.seek(to: time)
                }
            )
            .frame(height: 32)
            
            HStack {
                Text(formatTime(isDraggingSlider ? dragTimeValue : player.currentTime))
                Spacer()
                Text(formatTime(player.duration))
            }
            .font(.rounded(size: 12, weight: .medium))
            .foregroundColor(secondaryContentColor)
            .monospacedDigit()
        }
        .padding(.horizontal, 24) // Reduced width slightly for cleaner look
    }
    
    // MARK: - Waveform Component
    struct WaveformProgressBar: View {
        @Binding var currentTime: Double
        let duration: Double
        var color: Color = .black
        let onSeek: (Double) -> Void
        let onCommit: (Double) -> Void
        
        // Configuration
        let barCount = 40
        let barSpacing: CGFloat = 4
        let minHeight: CGFloat = 8
        
        // Use a consistent seed for randomness per view instance
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
                            
                            // 计算动态高度
                            let height = calculateBarHeight(
                                index: index,
                                isPlayed: isPlayed,
                                baseAmplitude: baseAmplitude,
                                phase: phase,
                                maxHeight: geometry.size.height
                            )
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isPlayed ? color : color.opacity(0.3))
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
                // 波浪动画效果
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
    
    private var controlsView: some View {
        VStack(spacing: 16) {
            // 主控制行
            HStack(spacing: 0) {
                // Mode
                Button(action: { player.switchMode() }) {
                    AsideIcon(icon: player.mode.asideIcon, size: 22, color: secondaryContentColor)
                }
                .frame(width: 44)
                
                Spacer()
                
                // Previous
                Button(action: { player.previous() }) {
                    AsideIcon(icon: .previous, size: 32, color: contentColor)
                }
                .buttonStyle(AsideBouncingButtonStyle())
                
                Spacer()
                
                // Play/Pause
                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(contentColor)
                            .frame(width: 72, height: 72)
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                        
                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        } else {
                            AsideIcon(icon: player.isPlaying ? .pause : .play, size: 32, color: .white)
                        }
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.9))
                
                Spacer()
                
                // Next
                Button(action: { player.next() }) {
                    AsideIcon(icon: .next, size: 32, color: contentColor)
                }
                .buttonStyle(AsideBouncingButtonStyle())
                
                Spacer()
                
                // Playlist
                Button(action: { showPlaylist = true }) {
                    AsideIcon(icon: .list, size: 22, color: secondaryContentColor)
                }
                .frame(width: 44)
            }
            
            // 副控制行 (EQ)
            HStack(spacing: 24) {
                Spacer()
                
                // EQ 按钮
                Button(action: { showEQ = true }) {
                    HStack(spacing: 6) {
                        AsideIcon(icon: .eq, size: 18, color: AudioEQManager.shared.isEnabled ? contentColor : secondaryContentColor)
                        Text("EQ")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AudioEQManager.shared.isEnabled ? contentColor : secondaryContentColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(contentColor.opacity(0.08))
                    .cornerRadius(16)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        
        let totalSeconds = Int(seconds)
        let min = totalSeconds / 60
        let sec = totalSeconds % 60
        return String(format: "%d:%02d", min, sec)
    }
}
