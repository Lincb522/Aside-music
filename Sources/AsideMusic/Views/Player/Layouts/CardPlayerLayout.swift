import SwiftUI

/// 卡片布局 - 全屏白色卡片 + 大圆形封面 + 渐变背景 + 内嵌歌词 + 渐变圆环播放按钮
struct CardPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared

    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showComments = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showMoreMenu = false

    // 封面提取颜色
    @State private var dominantColor: Color = .pink.opacity(0.7)
    @State private var secondaryBgColor: Color = .purple.opacity(0.6)
    @State private var isAppeared = false

    @Environment(\.colorScheme) private var colorScheme

    // 卡片内颜色 — 自适应深浅色
    private var cardText: Color {
        colorScheme == .dark ? .white : Color(hex: "1E1E2E")
    }
    private var cardTextSub: Color {
        cardText.opacity(0.5)
    }
    private var cardTextMuted: Color {
        cardText.opacity(0.28)
    }
    /// 卡片填充色
    private var cardFill: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E").opacity(0.94) : .white.opacity(0.94)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 渐变背景（卡片外）
                buildBackground(geo: geo)

                // 全屏白色卡片
                fullCard(geo: geo)
                    .padding(.horizontal, 16)
                    .padding(.top, DeviceLayout.hasNotch ? 54 : 40)
                    .padding(.bottom, DeviceLayout.hasNotch ? 34 : 16)
                    .opacity(isAppeared ? 1 : 0)
                    .scaleEffect(isAppeared ? 1 : 0.95)

                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        isDarkBackground: colorScheme == .dark,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
        }
        .onAppear {
            extractColors()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                isAppeared = true
            }
        }
        .onChange(of: player.currentSong?.id) { _, _ in extractColors() }
        .sheet(isPresented: $showPlaylist) {
            PlaylistPopupView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQualitySheet) {
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentKugouQuality: player.kugouQuality,
                isUnblocked: player.isCurrentSongUnblocked,
                onSelectNetease: { q in player.switchQuality(q); showQualitySheet = false },
                onSelectKugou: { q in player.switchKugouQuality(q); showQualitySheet = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEQSettings) {
            NavigationStack { EQSettingsView() }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showThemePicker) {
            PlayerThemePickerSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showComments) {
            if let song = player.currentSong {
                CommentView(resourceId: song.id, resourceType: .song,
                           songName: song.name, artistName: song.artistName, coverUrl: song.coverUrl)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
    }
}

// MARK: - 渐变背景
extension CardPlayerLayout {

    @ViewBuilder
    func buildBackground(geo: GeometryProxy) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    dominantColor,
                    secondaryBgColor,
                    dominantColor.opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // 柔和光斑
            Circle()
                .fill(dominantColor.opacity(0.35))
                .frame(width: geo.size.width * 0.7)
                .blur(radius: 80)
                .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.15)

            Circle()
                .fill(secondaryBgColor.opacity(0.3))
                .frame(width: geo.size.width * 0.5)
                .blur(radius: 60)
                .offset(x: geo.size.width * 0.2, y: geo.size.height * 0.2)
        }
    }
}

// MARK: - 全屏白色卡片
extension CardPlayerLayout {

    @ViewBuilder
    func fullCard(geo: GeometryProxy) -> some View {
        let coverSize = min(geo.size.width * 0.58, 240)

        VStack(spacing: 0) {
            // 卡片内顶栏
            cardHeader
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            // 大圆形封面
            coverSection(size: coverSize)
                .padding(.bottom, 16)

            // 歌曲信息 + 喜欢按钮
            songInfoSection
                .padding(.horizontal, 28)
                .padding(.bottom, 10)

            // 歌词区域
            lyricsSection
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 20)

            // 渐变进度条
            gradientProgressBar
                .padding(.horizontal, 28)
                .padding(.bottom, 12)

            // 控制按钮（全部在卡片内）
            controlsInCard
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(cardFill)
                .shadow(color: Color.black.opacity(0.12), radius: 30, x: 0, y: 15)
                .shadow(color: dominantColor.opacity(0.2), radius: 50, x: 0, y: 25)
        )
        .clipShape(RoundedRectangle(cornerRadius: 32))
    }
}

// MARK: - 卡片内顶栏
extension CardPlayerLayout {

    var cardHeader: some View {
        HStack {
            // 返回按钮
            Button(action: { dismiss() }) {
                AsideIcon(icon: .chevronRight, size: 18, color: cardText.opacity(0.6))
                    .rotationEffect(.degrees(90))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(cardText.opacity(0.05))
                    )
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            // 音质标签
            Button(action: { showQualitySheet = true }) {
                Text(player.soundQuality.buttonText)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(cardTextSub)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(cardText.opacity(0.05))
                    )
            }

            // 更多菜单
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    showMoreMenu.toggle()
                }
            }) {
                AsideIcon(icon: .more, size: 18, color: cardText.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(cardText.opacity(0.05))
                    )
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
    }
}

// MARK: - 封面
extension CardPlayerLayout {

    @ViewBuilder
    func coverSection(size: CGFloat) -> some View {
        ZStack {
            // 封面阴影
            Circle()
                .fill(dominantColor.opacity(0.25))
                .frame(width: size * 0.9, height: size * 0.9)
                .blur(radius: 30)
                .offset(y: 15)

            if let song = player.currentSong {
                CachedAsyncImage(url: song.coverUrl) { Color.gray.opacity(0.1) }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: dominantColor.opacity(0.35), radius: 20, x: 0, y: 10)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.08))
                    .frame(width: size, height: size)
                    .overlay(
                        AsideIcon(icon: .musicNoteList, size: 50, color: .gray.opacity(0.25))
                    )
            }
        }
    }
}

// MARK: - 歌曲信息
extension CardPlayerLayout {

    var songInfoSection: some View {
        VStack(spacing: 5) {
            // 歌名 + 喜欢
            HStack(spacing: 10) {
                Spacer()

                Text(player.currentSong?.name ?? "")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(cardText)
                    .lineLimit(1)

                if let songId = player.currentSong?.id {
                    LikeButton(songId: songId, size: 22, activeColor: .red, inactiveColor: cardTextMuted)
                }

                Spacer()
            }

            // 歌手
            Text(player.currentSong?.artistName ?? "")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(cardTextSub)
                .lineLimit(1)

            // 专辑名
            if let album = player.currentSong?.album,
               let albumName = album.name as String?,
               !albumName.isEmpty {
                Text(albumName)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(cardTextMuted)
                    .lineLimit(1)
                    .padding(.top, 1)
            }
        }
    }
}

// MARK: - 歌词
extension CardPlayerLayout {

    @ViewBuilder
    var lyricsSection: some View {
        if let song = player.currentSong {
            ZStack {
                LyricsView(song: song, onBackgroundTap: {})
                    .allowsHitTesting(false)

                // 上下渐隐遮罩
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [cardFill, cardFill.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 24)

                    Spacer()

                    LinearGradient(
                        colors: [cardFill.opacity(0), cardFill],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 32)
                }
            }
            .clipped()
        } else {
            VStack {
                Spacer()
                Text("暂无歌词")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(cardTextMuted)
                Spacer()
            }
        }
    }
}

// MARK: - 渐变进度条
extension CardPlayerLayout {

    var gradientProgressBar: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                let progress = player.duration > 0
                    ? (isDragging ? dragValue : player.currentTime) / player.duration
                    : 0

                ZStack(alignment: .leading) {
                    // 背景轨道
                    Capsule()
                        .fill(cardText.opacity(0.06))
                        .frame(height: 4)

                    // 渐变填充
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [dominantColor, secondaryBgColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * CGFloat(min(max(progress, 0), 1)),
                            height: 4
                        )
                }
                .contentShape(Rectangle().inset(by: -12))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let p = min(max(value.location.x / geo.size.width, 0), 1)
                            dragValue = p * player.duration
                        }
                        .onEnded { value in
                            isDragging = false
                            let p = min(max(value.location.x / geo.size.width, 0), 1)
                            player.seek(to: p * player.duration)
                        }
                )
            }
            .frame(height: 20)

            HStack {
                Text(formatTime(isDragging ? dragValue : player.currentTime))
                Spacer()
                Text(formatTime(player.duration))
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(cardTextMuted)
        }
    }
}

// MARK: - 卡片内控制按钮
extension CardPlayerLayout {

    var controlsInCard: some View {
        HStack(spacing: 0) {
            // 评论
            Button(action: { showComments = true }) {
                AsideIcon(icon: .comment, size: 20, color: cardTextSub, lineWidth: 1.4)
            }
            .frame(width: 40)

            Spacer()

            // 上一首
            Button(action: { player.previous() }) {
                AsideIcon(icon: .previous, size: 28, color: cardText.opacity(0.7))
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            // 播放按钮 — 渐变圆环
            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    // 渐变圆环
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [dominantColor, secondaryBgColor, dominantColor.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 62, height: 62)

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: dominantColor))
                            .scaleEffect(1.1)
                    } else {
                        AsideIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 26,
                            color: dominantColor
                        )
                    }
                }
            }
            .buttonStyle(AsideBouncingButtonStyle(scale: 0.9))

            Spacer()

            // 下一首
            Button(action: { player.next() }) {
                AsideIcon(icon: .next, size: 28, color: cardText.opacity(0.7))
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            // 更多（播放列表）
            Button(action: { showPlaylist = true }) {
                AsideIcon(icon: .more, size: 20, color: cardTextSub)
            }
            .frame(width: 40)
        }
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
                    withAnimation(.easeOut(duration: 0.8)) {
                        dominantColor = colors.dominant
                        secondaryBgColor = colors.secondary
                    }
                }
            } catch {}
        }
    }

    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
