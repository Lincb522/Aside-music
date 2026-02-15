import SwiftUI

/// 全新重构的卡片式播放界面
/// 采用现代 Glassmorphism 设计风格，强调沉浸感与交互体验
struct CardPlayerLayout_Old: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared

    // MARK: - State
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showComments = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showMoreMenu = false
    @State private var isAppeared = false
    
    // 界面状态
    @State private var showLyrics = false
    @State private var cardScale: CGFloat = 1.0
    
    // 颜色提取
    @State private var dominantColor: Color = .purple
    @State private var secondaryColor: Color = .purple.opacity(0.6)
    
    // 频谱数据
    @State private var spectrumData: [Float] = Array(repeating: 0, count: 20)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. 沉浸式背景
                backgroundView(geo: geo)
                
                // 2. 主内容区域
                VStack(spacing: 0) {
                    // 顶部导航栏
                    topBar
                        .zIndex(10)
                    
                    Spacer()
                    
                    // 核心卡片交互区
                    mainCardView(geo: geo)
                        .scaleEffect(cardScale)
                        .zIndex(5)
                    
                    Spacer()
                    
                    // 底部控制区
                    bottomControlsView
                        .padding(.bottom, DeviceLayout.safeAreaBottom + 20)
                        .zIndex(10)
                }
            }
            .opacity(isAppeared ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear {
            setupLifecycle()
        }
        .onDisappear {
            player.spectrumAnalyzer.isEnabled = false
        }
        .onChange(of: player.currentSong?.id) { _, _ in extractColors() }
        .sheet(isPresented: $showPlaylist) {
            PlaylistPopupView().presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQualitySheet) {
            SoundQualitySheet(
                currentQuality: player.soundQuality, currentKugouQuality: player.kugouQuality,
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
    
    private func setupLifecycle() {
        setupSpectrumAnalyzer()
        extractColors()
        withAnimation(.easeOut(duration: 0.6)) { isAppeared = true }
        if let song = player.currentSong, lyricVM.currentSongId != song.id {
            lyricVM.fetchLyrics(for: song.id)
        }
    }
}

// MARK: - 1. 背景视图 (Background)
extension CardPlayerLayout_Old {
    @ViewBuilder
    func backgroundView(geo: GeometryProxy) -> some View {
        ZStack {
            // 基础背景
            AsideBackground()
            
            // 动态模糊封面背景
            if let url = player.currentSong?.coverUrl {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .blur(radius: 60)
                            .overlay(Color.black.opacity(0.4)) // 遮罩层，保证文字可读性
                            .transition(.opacity.animation(.easeInOut(duration: 1.0)))
                    default:
                        Color.clear
                    }
                }
                .id(player.currentSong?.id) // 强制刷新
            }
            
            // 渐变叠加，增强层次感
            LinearGradient(
                colors: [
                    dominantColor.opacity(0.3),
                    .black.opacity(0.6),
                    .black.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - 2. 核心卡片 (Main Card)
extension CardPlayerLayout_Old {
    @ViewBuilder
    func mainCardView(geo: GeometryProxy) -> some View {
        let cardWidth = geo.size.width - 48
        // 动态计算高度，保持黄金比例或适配屏幕
        let cardHeight = min(geo.size.height * 0.55, cardWidth * 1.4)
        
        ZStack {
            // 卡片背景容器
            RoundedRectangle(cornerRadius: 32)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(
                            LinearGradient(
                                colors: [
                                    dominantColor.opacity(0.2),
                                    secondaryColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 15)
            
            // 卡片内容：封面 vs 歌词
            ZStack {
                if showLyrics {
                    lyricsView
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.95)), removal: .opacity.combined(with: .scale(scale: 1.05))))
                } else {
                    artworkView(size: CGSize(width: cardWidth, height: cardHeight))
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.95)), removal: .opacity.combined(with: .scale(scale: 1.05))))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32))
            
            // 频谱装饰 (仅在封面模式显示)
            if !showLyrics {
                VStack {
                    Spacer()
                    spectrumVisualizer(width: cardWidth - 60)
                        .frame(height: 40)
                        .padding(.bottom, 30)
                }
                .transition(.opacity)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showLyrics.toggle()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.interactiveSpring()) { cardScale = 0.97 }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { cardScale = 1.0 }
                }
        )
    }
    
    // 封面视图
    @ViewBuilder
    func artworkView(size: CGSize) -> some View {
        GeometryReader { proxy in
            if let url = player.currentSong?.coverUrl {
                CachedAsyncImage(url: url) { Color.white.opacity(0.1) }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                ZStack {
                    Color.white.opacity(0.05)
                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.2))
                }
            }
        }
    }
    
    // 歌词视图
    var lyricsView: some View {
        VStack(spacing: 0) {
            // 顶部提示
            Text("Lyrics")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 24)
                .padding(.bottom, 12)
            
            if lyricVM.hasLyrics && !lyricVM.lyrics.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .center, spacing: 20) {
                            Color.clear.frame(height: 20) // Top spacing
                            
                            ForEach(Array(lyricVM.lyrics.enumerated()), id: \.offset) { index, line in
                                let isCurrent = index == lyricVM.currentLineIndex
                                VStack(spacing: 6) {
                                    Text(line.text)
                                        .font(.system(size: isCurrent ? 20 : 16, weight: isCurrent ? .bold : .medium, design: .rounded))
                                        .foregroundColor(isCurrent ? .white : .white.opacity(0.4))
                                        .multilineTextAlignment(.center)
                                        .scaleEffect(isCurrent ? 1.05 : 1.0)
                                        .animation(.spring(response: 0.3), value: isCurrent)
                                    
                                    if let trans = line.translation, !trans.isEmpty, isCurrent {
                                        Text(trans)
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                                .id(index)
                                .onTapGesture {
                                    player.seek(to: line.time)
                                }
                            }
                            
                            Color.clear.frame(height: 60) // Bottom spacing
                        }
                        .padding(.horizontal, 24)
                    }
                    .mask(
                        LinearGradient(colors: [.clear, .black, .black, .clear], startPoint: .top, endPoint: .bottom)
                    )
                    .onChange(of: lyricVM.currentLineIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "music.mic")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.bottom, 16)
                    Text("纯音乐，无歌词")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }
            }
        }
    }
}

// MARK: - 3. 底部控制区 (Bottom Controls)
extension CardPlayerLayout_Old {
    var bottomControlsView: some View {
        VStack(spacing: 24) {
            // 歌曲信息
            VStack(spacing: 6) {
                HStack(alignment: .center, spacing: 12) {
                    Text(player.currentSong?.name ?? "未知歌曲")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let songId = player.currentSong?.id {
                        LikeButton(songId: songId, size: 22, activeColor: .pink, inactiveColor: .white.opacity(0.6))
                    }
                }
                
                Text(player.currentSong?.artistName ?? "未知艺术家")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(.horizontal, 32)
            
            // 进度条
            progressBar
                .padding(.horizontal, 32)
            
            // 播放控制按钮
            HStack(spacing: 30) {
                // 播放模式
                Button(action: { player.switchMode() }) {
                    AsideIcon(icon: player.mode.asideIcon, size: 20, color: .white.opacity(0.7))
                }
                .buttonStyle(AsideBouncingButtonStyle())
                
                // 上一首
                Button(action: { player.previous() }) {
                    AsideIcon(icon: .previous, size: 28, color: .white)
                }
                .buttonStyle(AsideBouncingButtonStyle())
                
                // 播放/暂停 (主按钮)
                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)
                            .shadow(color: .white.opacity(0.3), radius: 15, x: 0, y: 5)
                        
                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            AsideIcon(icon: player.isPlaying ? .pause : .play, size: 30, color: .black)
                                .offset(x: player.isPlaying ? 0 : 2) // Visual correction for play icon
                        }
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.9))
                
                // 下一首
                Button(action: { player.next() }) {
                    AsideIcon(icon: .next, size: 28, color: .white)
                }
                .buttonStyle(AsideBouncingButtonStyle())
                
                // 播放列表
                Button(action: { showPlaylist = true }) {
                    AsideIcon(icon: .list, size: 20, color: .white.opacity(0.7))
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
        }
    }
    
    // 进度条组件
    var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 轨道
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)
                    
                    // 进度
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [dominantColor, secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progressPercent, height: 4)
                    
                    // 拖动手柄
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.2), radius: 4)
                        .offset(x: geo.size.width * progressPercent - 7)
                        .scaleEffect(isDragging ? 1.5 : 1.0)
                        .animation(.spring(response: 0.2), value: isDragging)
                }
                .contentShape(Rectangle().inset(by: -10))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let percent = min(max(value.location.x / geo.size.width, 0), 1)
                            dragValue = percent * player.duration
                        }
                        .onEnded { value in
                            isDragging = false
                            let percent = min(max(value.location.x / geo.size.width, 0), 1)
                            player.seek(to: percent * player.duration)
                        }
                )
            }
            .frame(height: 20)
            
            // 时间标签
            HStack {
                Text(formatTime(isDragging ? dragValue : player.currentTime))
                Spacer()
                Text(formatTime(player.duration))
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.5))
        }
    }
    
    var progressPercent: CGFloat {
        guard player.duration > 0 else { return 0 }
        let time = isDragging ? dragValue : player.currentTime
        return CGFloat(min(max(time / player.duration, 0), 1))
    }
}

// MARK: - 4. 顶部导航 (Top Bar)
extension CardPlayerLayout_Old {
    var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            Spacer()
            
            // 音质切换
            Button(action: { showQualitySheet = true }) {
                Text(player.soundQuality.buttonText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                    )
            }
            
            Spacer()
            
            Button(action: { showMoreMenu = true }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, DeviceLayout.safeAreaTop + 10)
    }
}

// MARK: - 5. 频谱可视化 (Spectrum)
extension CardPlayerLayout_Old {
    @ViewBuilder
    func spectrumVisualizer(width: CGFloat) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { index in
                let height = CGFloat(spectrumData[index]) * 30 + 4
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.6))
                    .frame(width: (width - 19 * 4) / 20, height: height)
                    .animation(.easeInOut(duration: 0.1), value: height)
            }
        }
    }
    
    private func setupSpectrumAnalyzer() {
        player.spectrumAnalyzer.isEnabled = true
        player.spectrumAnalyzer.smoothing = 0.5
        player.spectrumAnalyzer.onSpectrum = { magnitudes in
            DispatchQueue.main.async {
                let bandCount = magnitudes.count
                var newData: [Float] = []
                let targetCount = 20
                let bandsPerBar = max(1, bandCount / targetCount)
                
                for i in 0..<targetCount {
                    let start = i * bandsPerBar
                    let end = min(start + bandsPerBar, bandCount)
                    if start < bandCount {
                        let slice = magnitudes[start..<end]
                        let avg = slice.reduce(0, +) / Float(slice.count)
                        newData.append(min(avg * 2.5, 1.0)) // Boost signal
                    } else {
                        newData.append(0)
                    }
                }
                self.spectrumData = newData
            }
        }
    }
}

// MARK: - Helpers
extension CardPlayerLayout_Old {
    func extractColors() {
        guard let url = player.currentSong?.coverUrl else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return }
                let colors = image.extractColors()
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.8)) {
                        dominantColor = colors.dominant
                        secondaryColor = colors.secondary
                    }
                }
            } catch {}
        }
    }
    
    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "00:00" }
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
