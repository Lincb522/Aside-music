//
//  WavePlayerLayout.swift
//  AsideMusic
//
//  Wave 播放器布局
//  特点：封面模糊背景 + 圆形封面 + 环绕频谱 + 底部毛玻璃控制卡片
//

import SwiftUI
import FFmpegSwiftSDK

struct WavePlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared
    
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showLyrics = false
    @State private var showComments = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showMoreMenu = false
    @State private var isAppeared = false
    @State private var spectrumData: [Float] = Array(repeating: 0, count: 48)
    @State private var dominantColor: Color = .blue.opacity(0.6)
    @State private var secondaryBgColor: Color = .purple.opacity(0.5)
    
    var body: some View {
        GeometryReader { geo in
            let coverSize = min(geo.size.width * 0.55, 220)
            
            ZStack {
                coverBlurBackground
                
                VStack(spacing: 0) {
                    headerBar
                        .padding(.top, DeviceLayout.headerTopPadding)
                        .padding(.bottom, 16)
                    
                    ZStack {
                        if showLyrics {
                            if let song = player.currentSong {
                                LyricsView(song: song, onBackgroundTap: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showLyrics = false
                                    }
                                })
                            }
                        } else {
                            VStack(spacing: 24) {
                                Spacer()
                                ZStack {
                                    spectrumRing(radius: coverSize / 2 + 24)
                                    coverView(size: coverSize)
                                }
                                .frame(width: coverSize + 80, height: coverSize + 80)
                                songInfoCenter
                                Spacer()
                            }
                            .onTapGesture {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showLyrics = true
                                }
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showLyrics)
                    
                    bottomControlCard
                        .padding(.horizontal, 16)
                        .padding(.bottom, DeviceLayout.playerBottomPadding)
                }
                
                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
            .opacity(isAppeared ? 1 : 0)
            .scaleEffect(isAppeared ? 1 : 0.96)
        }
        .onAppear {
            setupSpectrumAnalyzer()
            extractColors()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { isAppeared = true }
            if let song = player.currentSong, lyricVM.currentSongId != song.id {
                lyricVM.fetchLyrics(for: song.id)
            }
        }
        .onDisappear { player.spectrumAnalyzer.isEnabled = false }
        .onChange(of: player.currentSong?.id) { _, _ in extractColors() }
        .sheet(isPresented: $showPlaylist) {
            PlaylistPopupView().presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQualitySheet) {
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentKugouQuality: player.kugouQuality,
                isUnblocked: player.isCurrentSongUnblocked,
                onSelectNetease: { q in player.switchQuality(q); showQualitySheet = false },
                onSelectKugou: { q in player.switchKugouQuality(q); showQualitySheet = false }
            ).presentationDetents([.medium]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEQSettings) {
            NavigationStack { EQSettingsView() }.presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showThemePicker) {
            PlayerThemePickerSheet().presentationDetents([.medium]).presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showComments) {
            if let song = player.currentSong {
                CommentView(resourceId: song.id, resourceType: .song,
                           songName: song.name, artistName: song.artistName, coverUrl: song.coverUrl)
                .presentationDetents([.large]).presentationDragIndicator(.hidden)
            }
        }
    }
}


// MARK: - 子视图
extension WavePlayerLayout {
    
    private var coverBlurBackground: some View {
        ZStack {
            if let song = player.currentSong {
                CachedAsyncImage(url: song.coverUrl) { Color.black }
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: 80)
                    .scaleEffect(1.3)
                    .clipped()
            }
            Color.black.opacity(colorScheme == .dark ? 0.5 : 0.3)
            LinearGradient(
                colors: [dominantColor.opacity(0.3), .clear, secondaryBgColor.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
    
    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.15)).frame(width: 40, height: 40)
                    AsideIcon(icon: .chevronRight, size: 16, color: .white.opacity(0.8))
                        .rotationEffect(.degrees(90))
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            Spacer()
            
            if let info = player.streamInfo {
                Text(streamInfoText(info))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { showMoreMenu.toggle() }
            }) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.15)).frame(width: 40, height: 40)
                    AsideIcon(icon: .more, size: 18, color: .white.opacity(0.8))
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 20)
    }
    
    private func spectrumRing(radius: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 0.033, paused: !player.isPlaying)) { _ in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let barCount = spectrumData.count
                
                for i in 0..<barCount {
                    let angle = (Double(i) / Double(barCount)) * 2 * .pi - .pi / 2
                    let amplitude = CGFloat(spectrumData[i])
                    let barHeight = 8 + amplitude * 30
                    let barWidth: CGFloat = 4
                    
                    let x = center.x + cos(angle) * radius
                    let y = center.y + sin(angle) * radius
                    
                    var transform = CGAffineTransform.identity
                    transform = transform.translatedBy(x: x, y: y)
                    transform = transform.rotated(by: angle + .pi / 2)
                    
                    let rect = CGRect(x: -barWidth / 2, y: 0, width: barWidth, height: barHeight)
                    let path = Path(roundedRect: rect, cornerRadius: barWidth / 2).applying(transform)
                    
                    let opacity = 0.3 + Double(amplitude) * 0.5
                    context.fill(path, with: .color(.white.opacity(opacity)))
                }
            }
        }
        .frame(width: radius * 2 + 80, height: radius * 2 + 80)
    }
    
    private func coverView(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(dominantColor.opacity(0.4))
                .frame(width: size * 0.9, height: size * 0.9)
                .blur(radius: 30)
                .offset(y: 10)
            
            if let song = player.currentSong {
                CachedAsyncImage(url: song.coverUrl) { Circle().fill(Color.gray.opacity(0.3)) }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 2))
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(AsideIcon(icon: .musicNote, size: 50, color: .white.opacity(0.3)))
            }
        }
    }
    
    private var songInfoCenter: some View {
        VStack(spacing: 8) {
            Text(player.currentSong?.name ?? "")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(player.currentSong?.artistName ?? "")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
        }
        .padding(.horizontal, 32)
    }
    
    private var bottomControlCard: some View {
        VStack(spacing: 16) {
            progressSection
            controlsSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
    }
    
    private var progressSection: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let progress = player.duration > 0 ? (isDragging ? dragValue : player.currentTime) / player.duration : 0
                
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15)).frame(height: 4)
                    Capsule().fill(Color.white.opacity(0.8))
                        .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)), height: 4)
                }
                .contentShape(Rectangle().inset(by: -12))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dragValue = min(max(value.location.x / geo.size.width, 0), 1) * player.duration
                        }
                        .onEnded { value in
                            isDragging = false
                            player.seek(to: min(max(value.location.x / geo.size.width, 0), 1) * player.duration)
                        }
                )
            }
            .frame(height: 20)
            
            HStack {
                Text(formatTime(isDragging ? dragValue : player.currentTime))
                Spacer()
                Text(formatTime(player.duration))
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.5))
        }
    }
    
    private var controlsSection: some View {
        HStack(spacing: 0) {
            if let songId = player.currentSong?.id {
                LikeButton(songId: songId, size: 22, activeColor: .red, inactiveColor: .white.opacity(0.6))
                    .frame(width: 44)
            } else {
                Color.clear.frame(width: 44)
            }
            
            Spacer()
            
            Button(action: { player.previous() }) {
                AsideIcon(icon: .previous, size: 28, color: .white.opacity(0.9))
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            Spacer()
            
            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Circle().fill(Color.white).frame(width: 60, height: 60)
                    if player.isLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black)).scaleEffect(1.1)
                    } else {
                        AsideIcon(icon: player.isPlaying ? .pause : .play, size: 26, color: .black)
                    }
                }
            }
            .buttonStyle(AsideBouncingButtonStyle(scale: 0.9))
            
            Spacer()
            
            Button(action: { player.next() }) {
                AsideIcon(icon: .next, size: 28, color: .white.opacity(0.9))
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            Spacer()
            
            Button(action: { showPlaylist = true }) {
                AsideIcon(icon: .list, size: 22, color: .white.opacity(0.6))
            }
            .frame(width: 44)
        }
    }
}

// MARK: - 辅助方法
extension WavePlayerLayout {
    
    private func setupSpectrumAnalyzer() {
        player.spectrumAnalyzer.isEnabled = true
        player.spectrumAnalyzer.smoothing = 0.65
        player.spectrumAnalyzer.onSpectrum = { magnitudes in
            DispatchQueue.main.async {
                self.spectrumData = Array(magnitudes.prefix(48))
            }
        }
    }
    
    private func extractColors() {
        guard let url = player.currentSong?.coverUrl else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return }
                let colors = image.extractColors()
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.8)) {
                        dominantColor = colors.dominant
                        secondaryBgColor = colors.secondary
                    }
                }
            } catch {}
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
    
    private func streamInfoText(_ info: StreamInfo) -> String {
        var parts: [String] = []
        if let codec = info.audioCodec { parts.append(codec.uppercased()) }
        if let sr = info.sampleRate {
            if sr >= 1000 {
                let khz = Double(sr) / 1000.0
                parts.append(khz == khz.rounded() ? "\(Int(khz))kHz" : String(format: "%.1fkHz", khz))
            } else { parts.append("\(sr)Hz") }
        }
        if let bd = info.bitDepth, bd > 0 { parts.append("\(bd)bit") }
        if let ch = info.channelCount, ch > 2 { parts.append("\(ch)ch") }
        return parts.joined(separator: " · ")
    }
}
