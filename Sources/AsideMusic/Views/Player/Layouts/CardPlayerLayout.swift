import SwiftUI

/// "The Stack" - 纯粹的卡片堆叠式播放器
/// 强调物理质感、层级关系与卡片交互
struct CardPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared
    
    // MARK: - State
    @State private var dominantColor: Color = .blue
    @State private var secondaryColor: Color = .purple
    @State private var isAppeared = false
    
    // 交互状态
    @State private var showLyrics = false
    @State private var dragOffset: CGSize = .zero
    @State private var rotationAngle: Double = 0
    
    // 弹窗状态
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showMoreMenu = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showComments = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. 纯净背景
                backgroundLayer
                
                VStack(spacing: -20) { // 负间距形成堆叠感
                    // 顶部占位 & 导航
                    topBar
                        .frame(height: 60)
                        .zIndex(10)
                        .padding(.top, DeviceLayout.safeAreaTop)
                    
                    Spacer()
                    
                    // 2. 视觉卡片 (Visual Card) - 封面/歌词
                    visualCard(geo: geo)
                        .zIndex(3) // 最上层
                    
                    // 3. 信息卡片 (Info Card) - 进度/信息
                    infoCard(geo: geo)
                        .zIndex(2)
                        .padding(.horizontal, 16)
                    
                    // 4. 控制卡片 (Control Card) - 按钮
                    controlCard(geo: geo)
                        .zIndex(1)
                        .padding(.horizontal, 32)
                        .padding(.bottom, DeviceLayout.safeAreaBottom + 20)
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
            setupLifecycle()
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
        extractColors()
        withAnimation(.easeOut(duration: 0.6)) { isAppeared = true }
        if let song = player.currentSong, lyricVM.currentSongId != song.id {
            lyricVM.fetchLyrics(for: song.id)
        }
    }
}

// MARK: - 1. Background
extension CardPlayerLayout {
    var backgroundLayer: some View {
        ZStack {
            // 基础色
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            // 氛围光
            LinearGradient(
                colors: [dominantColor.opacity(0.3), secondaryColor.opacity(0.1), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
    
    var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 40, height: 40)
                    .background(Color(UIColor.systemBackground).opacity(0.5))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Button(action: { showQualitySheet = true }) {
                Text(player.soundQuality.buttonText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(UIColor.systemBackground).opacity(0.5))
                    .clipShape(Capsule())
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            Spacer()
            
            Button(action: { showMoreMenu.toggle() }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 40, height: 40)
                    .background(Color(UIColor.systemBackground).opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - 2. Visual Card (Top)
extension CardPlayerLayout {
    @ViewBuilder
    func visualCard(geo: GeometryProxy) -> some View {
        let width = geo.size.width - 40
        let height = width * 1.1
        
        ZStack {
            // Card Content
            ZStack {
                if showLyrics {
                    lyricsView
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else {
                    artworkView(size: CGSize(width: width, height: height))
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .frame(width: width, height: height)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            .rotationEffect(.degrees(Double(dragOffset.width / 15)))
            .offset(x: dragOffset.width, y: dragOffset.height)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        withAnimation(.interactiveSpring()) {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        let threshold = width * 0.4
                        if value.translation.width > threshold {
                            // Prev
                            withAnimation(.easeIn(duration: 0.25)) {
                                dragOffset.width = geo.size.width * 1.5
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                player.previous()
                                resetCardPosition(from: -geo.size.width * 1.5)
                            }
                        } else if value.translation.width < -threshold {
                            // Next
                            withAnimation(.easeIn(duration: 0.25)) {
                                dragOffset.width = -geo.size.width * 1.5
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                player.next()
                                resetCardPosition(from: geo.size.width * 1.5)
                            }
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showLyrics.toggle()
                }
            }
            
            // "Throw" Indicator
            if abs(dragOffset.width) > 50 {
                Image(systemName: dragOffset.width > 0 ? "backward.fill" : "forward.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .padding()
                    .background(Circle().fill(Color.black.opacity(0.5)))
                    .opacity(min(abs(dragOffset.width) / 150.0, 1.0))
            }
        }
    }
    
    private func resetCardPosition(from x: CGFloat) {
        dragOffset = CGSize(width: x, height: 0)
        showLyrics = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            dragOffset = .zero
        }
    }
    
    @ViewBuilder
    func artworkView(size: CGSize) -> some View {
        if let url = player.currentSong?.coverUrl {
            CachedAsyncImage(url: url) { Color.gray.opacity(0.1) }
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
        } else {
            ZStack {
                Color.gray.opacity(0.1)
                Image(systemName: "music.note")
                    .font(.system(size: 80))
                    .foregroundColor(.secondary.opacity(0.3))
            }
        }
    }
    
    var lyricsView: some View {
        VStack(spacing: 0) {
            Text("Lyrics")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.top, 20)
                .padding(.bottom, 10)
            
            if lyricVM.hasLyrics && !lyricVM.lyrics.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            Color.clear.frame(height: 20)
                            ForEach(Array(lyricVM.lyrics.enumerated()), id: \.offset) { index, line in
                                let isCurrent = index == lyricVM.currentLineIndex
                                Text(line.text)
                                    .font(.system(size: isCurrent ? 22 : 18, weight: isCurrent ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isCurrent ? .primary : .secondary.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .scaleEffect(isCurrent ? 1.05 : 1.0)
                                    .animation(.spring(), value: isCurrent)
                                    .id(index)
                                    .onTapGesture { player.seek(to: line.time) }
                            }
                            Color.clear.frame(height: 60)
                        }
                        .padding(.horizontal, 24)
                    }
                    .onChange(of: lyricVM.currentLineIndex) { _, newIndex in
                        withAnimation { proxy.scrollTo(newIndex, anchor: .center) }
                    }
                }
            } else {
                Spacer()
                Text("Pure Music")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
}

// MARK: - 3. Info Card (Middle)
extension CardPlayerLayout {
    @ViewBuilder
    func infoCard(geo: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            // Song Text
            VStack(spacing: 6) {
                Text(player.currentSong?.name ?? "Unknown Track")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(player.currentSong?.artistName ?? "Unknown Artist")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(dominantColor)
                    .lineLimit(1)
            }
            .padding(.top, 30) // Extra padding for overlap
            
            // Progress
            VStack(spacing: 8) {
                GeometryReader { barGeo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(dominantColor)
                            .frame(width: barGeo.size.width * (player.duration > 0 ? player.currentTime / player.duration : 0), height: 6)
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let percent = value.location.x / barGeo.size.width
                                player.seek(to: percent * player.duration)
                            }
                    )
                }
                .frame(height: 12)
                
                HStack {
                    Text(formatTime(player.currentTime))
                    Spacer()
                    Text(formatTime(player.duration))
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .frame(width: geo.size.width - 64)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 8)
    }
}

// MARK: - 4. Control Card (Bottom)
extension CardPlayerLayout {
    @ViewBuilder
    func controlCard(geo: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            Button(action: { player.switchMode() }) {
                AsideIcon(icon: player.mode.asideIcon, size: 20, color: .secondary)
                    .frame(width: 50, height: 60)
            }
            
            Spacer()
            
            Button(action: { player.previous() }) {
                AsideIcon(icon: .previous, size: 24, color: .primary)
                    .frame(width: 60, height: 60)
            }
            
            Spacer()
            
            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(dominantColor)
                        .frame(width: 56, height: 56)
                        .shadow(color: dominantColor.opacity(0.4), radius: 8, y: 4)
                    
                    AsideIcon(icon: player.isPlaying ? .pause : .play, size: 24, color: .white)
                        .offset(x: player.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            Spacer()
            
            Button(action: { player.next() }) {
                AsideIcon(icon: .next, size: 24, color: .primary)
                    .frame(width: 60, height: 60)
            }
            
            Spacer()
            
            Button(action: { showPlaylist = true }) {
                AsideIcon(icon: .list, size: 20, color: .secondary)
                    .frame(width: 50, height: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24) // Extra padding for overlap
        .padding(.bottom, 16)
        .frame(width: geo.size.width - 80)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Helpers
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
