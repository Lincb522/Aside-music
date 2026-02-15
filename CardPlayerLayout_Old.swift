import SwiftUI

/// 卡片布局 — 歌词卡片风格
/// 顶部大色块歌词区域，底部歌曲信息和控制
/// 底部像素装饰跟随真实音频频谱跳动
struct CardPlayerLayout_Old: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared

    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showComments = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showMoreMenu = false
    @State private var isAppeared = false

    // 封面提取颜色
    @State private var dominantColor: Color = .purple
    @State private var secondaryColor: Color = .purple.opacity(0.6)
    
    // 频谱数据
    @State private var spectrumData: [Float] = Array(repeating: 0, count: 16)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 背景
                backgroundView(geo: geo)

                VStack(spacing: 0) {
                    // 顶部导航
                    topBar

                    // 歌词卡片
                    lyricCard(geo: geo)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    Spacer(minLength: 12)

                    // 歌曲信息
                    songInfo
                        .padding(.horizontal, 24)

                    Spacer(minLength: 14)

                    // 控制按钮
                    controlButtons
                        .padding(.horizontal, 20)

                    Spacer(minLength: 10)

                    // 进度条
                    progressBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, DeviceLayout.safeAreaBottom + 8)
                }

                // 更多菜单
                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        isDarkBackground: colorScheme == .dark,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
            .opacity(isAppeared ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear {
            setupSpectrumAnalyzer()
            extractColors()
            withAnimation(.easeOut(duration: 0.4)) { isAppeared = true }
            if let song = player.currentSong, lyricVM.currentSongId != song.id {
                lyricVM.fetchLyrics(for: song.id)
            }
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
}

// MARK: - 背景
extension CardPlayerLayout_Old {
    @ViewBuilder
    func backgroundView(geo: GeometryProxy) -> some View {
        ZStack {
            AsideBackground()

            // 像素频谱装饰（底部）
            VStack {
                Spacer()
                pixelSpectrumView(geo: geo)
            }
        }
    }

    /// 像素频谱可视化
    @ViewBuilder
    func pixelSpectrumView(geo: GeometryProxy) -> some View {
        let cols = 16
        let maxRows = 8
        let spacing: CGFloat = 5
        let totalSpacing = CGFloat(cols - 1) * spacing + 16
        let blockSize = (geo.size.width - totalSpacing) / CGFloat(cols)
        
        TimelineView(.animation(minimumInterval: 0.05, paused: !player.isPlaying)) { _ in
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(0..<cols, id: \.self) { col in
                    let amplitude = col < spectrumData.count ? spectrumData[col] : 0
                    let activeRows = max(1, Int(CGFloat(amplitude) * CGFloat(maxRows)))
                    
                    VStack(spacing: spacing) {
                        ForEach(0..<activeRows, id: \.self) { row in
                            let brightness = Double(row + 1) / Double(activeRows)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(dominantColor.opacity(0.15 + brightness * 0.5))
                                .frame(width: blockSize, height: blockSize)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
    }
    
    private func setupSpectrumAnalyzer() {
        player.spectrumAnalyzer.isEnabled = true
        player.spectrumAnalyzer.smoothing = 0.7
        player.spectrumAnalyzer.onSpectrum = { magnitudes in
            DispatchQueue.main.async {
                let bandCount = magnitudes.count
                var newData: [Float] = []
                let bandsPerColumn = max(1, bandCount / 16)
                
                for col in 0..<16 {
                    let startIdx = col * bandsPerColumn
                    let endIdx = min(startIdx + bandsPerColumn, bandCount)
                    if startIdx < bandCount {
                        let slice = magnitudes[startIdx..<endIdx]
                        let avg = slice.reduce(0, +) / Float(slice.count)
                        let boost: Float = col < 4 ? 1.5 : (col < 8 ? 1.2 : 1.0)
                        newData.append(min(avg * boost * 2, 1.0))
                    } else {
                        newData.append(0)
                    }
                }
                self.spectrumData = newData
            }
        }
    }
}

// MARK: - 顶部导航
extension CardPlayerLayout_Old {
    // 深色模式下按钮背景色
    private var buttonBgColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }
    
    var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(buttonBgColor)
                        .frame(width: 40, height: 40)
                    AsideIcon(icon: .chevronRight, size: 18, color: .asideTextPrimary)
                        .rotationEffect(.degrees(180))
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()
            
            // 音质标签
            Button(action: { showQualitySheet = true }) {
                Text(player.soundQuality.buttonText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(colorScheme == .dark ? dominantColor.opacity(0.9) : dominantColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(dominantColor.opacity(colorScheme == .dark ? 0.2 : 0.12))
                    )
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            Button(action: { showMoreMenu.toggle() }) {
                ZStack {
                    Circle()
                        .fill(buttonBgColor)
                        .frame(width: 40, height: 40)
                    AsideIcon(icon: .more, size: 18, color: .asideTextPrimary)
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, DeviceLayout.safeAreaTop + 4)
    }
}

// MARK: - 歌词卡片
extension CardPlayerLayout_Old {
    @ViewBuilder
    func lyricCard(geo: GeometryProxy) -> some View {
        let cardHeight = geo.size.height * 0.42

        ZStack {
            // 卡片背景 - 深色模式下更鲜艳
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark 
                            ? [dominantColor, secondaryColor.opacity(0.9)]
                            : [dominantColor.opacity(0.95), secondaryColor.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: dominantColor.opacity(colorScheme == .dark ? 0.4 : 0.25), radius: 24, y: 12)

            VStack(alignment: .leading, spacing: 0) {
                // 标题栏
                HStack(alignment: .center) {
                    // 左侧标题
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 3, height: 16)
                        
                        Text("Lyric")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // 时间显示
                    Text(timeDisplay)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // 歌词内容
                if lyricVM.hasLyrics && !lyricVM.lyrics.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(Array(lyricVM.lyrics.enumerated()), id: \.offset) { index, line in
                                    lyricLine(line: line, index: index, isCurrent: index == lyricVM.currentLineIndex)
                                        .id(index)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                        .mask(
                            VStack(spacing: 0) {
                                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                                    .frame(height: 16)
                                Rectangle().fill(Color.black)
                                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                    .frame(height: 24)
                            }
                        )
                        .onChange(of: lyricVM.currentLineIndex) { _, newIndex in
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                        .onAppear {
                            proxy.scrollTo(lyricVM.currentLineIndex, anchor: .center)
                        }
                    }
                } else {
                    // 无歌词 - 显示封面缩略图
                    VStack(spacing: 12) {
                        Spacer()
                        if let url = player.currentSong?.coverUrl {
                            CachedAsyncImage(url: url) { Color.white.opacity(0.1) }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .opacity(0.6)
                        }
                        Text("纯音乐，无歌词")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: cardHeight)
    }

    @ViewBuilder
    func lyricLine(line: LyricLine, index: Int, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(line.text)
                .font(.system(size: isCurrent ? 17 : 14, weight: isCurrent ? .bold : .regular))
                .foregroundColor(isCurrent ? .white : .white.opacity(0.35))
                .lineSpacing(4)
                .scaleEffect(isCurrent ? 1.0 : 0.98, anchor: .leading)

            if let trans = line.translation, !trans.isEmpty, isCurrent {
                Text(trans)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.top, 2)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isCurrent)
    }

    var timeDisplay: String {
        let current = formatTime(player.currentTime)
        let total = formatTime(player.duration)
        return "\(current) / \(total)"
    }
}

// MARK: - 歌曲信息
extension CardPlayerLayout_Old {
    var songInfo: some View {
        VStack(spacing: 8) {
            Text(player.currentSong?.name ?? "未知歌曲")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
                .lineLimit(1)

            Text(player.currentSong?.artistName ?? "未知艺术家")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.asideTextSecondary)
                .lineLimit(1)
        }
    }
}


// MARK: - 控制按钮
extension CardPlayerLayout {
    // 控制按钮背景色
    private var controlBgColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }
    
    var controlButtons: some View {
        HStack(spacing: 0) {
            // 喜欢按钮
            if let songId = player.currentSong?.id {
                LikeButton(songId: songId, size: 20, activeColor: dominantColor, inactiveColor: .asideTextSecondary)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(controlBgColor))
            } else {
                Circle().fill(Color.clear).frame(width: 46, height: 46)
            }

            Spacer()

            // 上一首
            Button(action: { player.previous() }) {
                AsideIcon(icon: .previous, size: 22, color: .asideTextPrimary)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(controlBgColor))
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            // 播放/暂停（主按钮）
            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    // 外圈光晕 - 深色模式更明显
                    Circle()
                        .fill(dominantColor.opacity(colorScheme == .dark ? 0.25 : 0.15))
                        .frame(width: 76, height: 76)
                    
                    // 主按钮
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [dominantColor, dominantColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: dominantColor.opacity(colorScheme == .dark ? 0.5 : 0.35), radius: 12, y: 6)

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.1)
                    } else {
                        AsideIcon(icon: player.isPlaying ? .pause : .play, size: 26, color: .white)
                    }
                }
            }
            .buttonStyle(AsideBouncingButtonStyle(scale: 0.92))

            Spacer()

            // 下一首
            Button(action: { player.next() }) {
                AsideIcon(icon: .next, size: 22, color: .asideTextPrimary)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(controlBgColor))
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            // 播放列表
            Button(action: { showPlaylist = true }) {
                AsideIcon(icon: .list, size: 20, color: .asideTextSecondary)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(controlBgColor))
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
    }
}

// MARK: - 进度条
extension CardPlayerLayout {
    var progressBar: some View {
        VStack(spacing: 10) {
            // 进度滑块
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 轨道背景 - 深色模式更明显
                    Capsule()
                        .fill(Color.asideTextSecondary.opacity(colorScheme == .dark ? 0.2 : 0.15))
                        .frame(height: 5)

                    // 进度填充
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [dominantColor, dominantColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progressPercent, height: 5)

                    // 拖动指示器
                    Circle()
                        .fill(dominantColor)
                        .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                        .shadow(color: dominantColor.opacity(colorScheme == .dark ? 0.6 : 0.4), radius: isDragging ? 6 : 3)
                        .offset(x: geo.size.width * progressPercent - (isDragging ? 8 : 6))
                        .animation(.spring(response: 0.25), value: isDragging)
                }
                .contentShape(Rectangle().inset(by: -15))
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
            .frame(height: 24)

            // 时间 + 功能按钮
            HStack {
                Text(formatTime(isDragging ? dragValue : player.currentTime))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.asideTextSecondary)
                    .frame(width: 45, alignment: .leading)

                Spacer()

                // 功能按钮组 - 深色模式图标更亮
                HStack(spacing: 20) {
                    Button(action: { showComments = true }) {
                        AsideIcon(icon: .comment, size: 17, color: colorScheme == .dark ? .asideTextSecondary.opacity(1.2) : .asideTextSecondary, lineWidth: 1.4)
                    }
                    .buttonStyle(AsideBouncingButtonStyle())

                    Button(action: { player.switchMode() }) {
                        AsideIcon(icon: player.mode.asideIcon, size: 17, color: colorScheme == .dark ? .asideTextSecondary.opacity(1.2) : .asideTextSecondary)
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    
                    Button(action: { showEQSettings = true }) {
                        AsideIcon(icon: .equalizer, size: 17, color: colorScheme == .dark ? .asideTextSecondary.opacity(1.2) : .asideTextSecondary)
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                }

                Spacer()

                Text(formatTime(player.duration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.asideTextSecondary)
                    .frame(width: 45, alignment: .trailing)
            }
        }
    }

    var progressPercent: CGFloat {
        guard player.duration > 0 else { return 0 }
        let time = isDragging ? dragValue : player.currentTime
        return CGFloat(min(max(time / player.duration, 0), 1))
    }
}

// MARK: - 辅助
extension CardPlayerLayout {
    func extractColors() {
        guard let url = player.currentSong?.coverUrl else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return }
                let colors = image.extractColors()
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.5)) {
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
