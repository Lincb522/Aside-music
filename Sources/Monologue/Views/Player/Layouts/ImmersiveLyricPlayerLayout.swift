import SwiftUI
import FFmpegSwiftSDK

/// 沉浸动态歌词版播放器布局 — Apple Music 风格重构
///
/// 版式完全对齐 Apple Music「正在播放」：
/// · 播放态：顶部把手 → 居中巨幅封面（播放放大 / 暂停缩小的呼吸感）→ 标题行（左标题右操作）
///   → 细进度条 → 三键走带 → 底部功能排（歌词 / 评论 / 沉浸 / 队列）。
/// · 歌词态：小封面顶栏 + 全屏歌词瀑布，没有底部控制栏——歌词一铺到底；
///   点歌词区域收起 / 唤回顶栏，点小封面或底部歌词键飞回播放态。
/// · 两个状态共享同一张封面（matchedGeometryEffect），切换时封面在
///   「舞台中央 ⇄ 顶栏角落」之间真实飞行。
struct ImmersiveLyricPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var player = PlayerManager.shared

    @State private var showMoreMenu = false
    @State private var showQualitySheet = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showArtistDetail = false
    @State private var showComments = false
    @State private var showPlaylist = false

    // 双状态核心：是否处于歌词态
    @State private var showLyrics = false
    @Namespace private var animation

    // 歌词态顶栏显隐；点歌词区域整体收起进入纯歌词全沉浸
    @State private var isChromeVisible = true

    // 进度条控制
    @State private var isDraggingSlider = false
    @State private var dragTimeValue: Double = 0

    /// 双状态切换共用的弹簧
    private var stateSpring: Animation { .spring(response: 0.5, dampingFraction: 0.86) }

    private func toggleLyrics() {
        withAnimation(stateSpring) {
            showLyrics.toggle()
            // 每次进入歌词态都先带出顶栏，避免「进来不知道怎么回去」
            if showLyrics { isChromeVisible = true }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let sw = geo.size.width

            ZStack(alignment: .top) {
                // 弥散封面背景（双状态共享）
                PlaylistColorBackground(
                    coverUrl: player.currentSong?.coverUrl?.sized(200),
                    onBrightnessChanged: { _ in }
                )
                .frame(width: sw)
                .ignoresSafeArea()

                if showLyrics {
                    lyricStage(size: geo.size)
                } else {
                    playerStage(size: geo.size)
                }

                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        onQuality: { showQualitySheet = true },
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .environment(\.colorScheme, .dark)
        // Sheets
        .fullScreenCover(isPresented: $showEQSettings) {
            NavigationStack { MonoAudioCenterView() }
        }
        .monologueSheet(isPresented: $showThemePicker, preset: .themePicker) {
            PlayerThemePickerSheet()
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast { PodcastPlaylistPopupView() } else { PlaylistPopupView() }
        }
        .monologueSheet(isPresented: $showQualitySheet, preset: .standard) {
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentQQQuality: player.qqMusicQuality,
                isQQMusic: player.currentSong?.isQQMusic == true,
                onSelectNetease: { q in player.switchQuality(q); showQualitySheet = false },
                onSelectQQ: { q in player.switchQQMusicQuality(q); showQualitySheet = false },
                songMid: player.currentSong?.qqMid,
                songId: player.currentSong?.id,
                isQishui: player.currentSong?.isQishui == true,
                qishuiTrackId: player.currentSong?.qishuiTrackId,
                onSelectQishui: { info in player.switchQishuiQuality(info); showQualitySheet = false }
            )
        }
        .monologueSheet(isPresented: $showComments, preset: .large) {
            if let song = player.currentSong {
                CommentView(resourceId: song.id, resourceType: .song,
                            songName: song.name, artistName: song.artistName, coverUrl: song.coverUrl)
            }
        }
        .monologueSheet(isPresented: $showArtistDetail, preset: .detail) {
            if let song = player.currentSong {
                NavigationStack {
                    if song.isQQMusic, let mid = song.qqArtistMid {
                        QQMusicDetailView(detailType: .artist(mid: mid, name: song.artistName, coverUrl: nil))
                    } else if let artistId = song.ar?.first?.id {
                        ArtistDetailView(artistId: artistId)
                    }
                }
            }
        }
    }
}

// MARK: - 播放态（Apple Music 正在播放版式）
extension ImmersiveLyricPlayerLayout {
    @ViewBuilder
    func playerStage(size: CGSize) -> some View {
        let coverSize = min(size.width - 56, size.height * 0.42)

        VStack(spacing: 0) {
            grabHandle
                .padding(.top, 10)

            Spacer(minLength: 12)

            // 巨幅封面：播放时满幅，暂停时缩回 —— Apple Music 的呼吸手势
            coverArtwork(size: coverSize, cornerRadius: 12)
                .scaleEffect(player.isPlaying ? 1.0 : 0.82)
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: player.isPlaying)
                .contentShape(Rectangle())
                .onTapGesture { toggleLyrics() }

            Spacer(minLength: 12)

            VStack(spacing: 22) {
                titleRow
                PlayerProgressSection(
                    isDragging: $isDraggingSlider,
                    dragValue: $dragTimeValue,
                    contentColor: .white,
                    secondaryColor: .white.opacity(0.55),
                    useWaveform: false
                )
                transportRow
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 18)

            utilityRow
                .padding(.horizontal, 44)
                .padding(.bottom, 14)
        }
        .frame(width: size.width, height: size.height)
        .transition(.opacity)
    }

    /// 顶部把手：Apple Music 式的下拉捏手，点按收起播放器
    var grabHandle: some View {
        Button(action: { dismiss() }) {
            Capsule()
                .fill(Color.white.opacity(0.4))
                .frame(width: 38, height: 5)
                .padding(.vertical, 8)
                .padding(.horizontal, 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 标题行：左侧曲名 / 歌手，右侧收藏 + 更多（对齐 AM 的「标题旁挂操作」）
    var titleRow: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(player.currentSong?.name ?? "No Title")
                    .monologuePlayerDisplayFont(
                        size: 21,
                        weight: .bold,
                        fallback: .system(size: 21, weight: .bold, design: .rounded)
                    )
                    .foregroundColor(.white)
                    .lineLimit(1)

                Button(action: { showArtistDetail = true }) {
                    Text(player.currentSong?.artistName ?? "Unknown Artist")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            if let song = player.currentSong {
                LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song,
                           size: 21, activeColor: .red, inactiveColor: .white.opacity(0.85))
            }

            Button(action: { showMoreMenu = true }) {
                MonologueIcon(icon: .more, size: 17, color: .white.opacity(0.9))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.14)))
            }
            .buttonStyle(MonologueBouncingButtonStyle())
        }
    }

    /// 三键走带：AM 式的大间距居中排布
    var transportRow: some View {
        HStack {
            Spacer()

            Button(action: { player.previous() }) {
                MonologueIcon(icon: .previous, size: 30, color: .white)
            }
            .buttonStyle(MonologueBouncingButtonStyle())

            Spacer()

            Button(action: { player.togglePlayPause() }) {
                if player.isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 48, height: 48)
                } else {
                    MonologueIcon(icon: player.isPlaying ? .pause : .play, size: 48, color: .white)
                }
            }
            .buttonStyle(MonologueBouncingButtonStyle())

            Spacer()

            Button(action: { player.next() }) {
                MonologueIcon(icon: .next, size: 30, color: .white)
            }
            .buttonStyle(MonologueBouncingButtonStyle())

            Spacer()
        }
    }

    /// 底部功能排：歌词 / 评论 / 沉浸 / 队列（对应 AM 底部的歌词·AirPlay·队列排）
    var utilityRow: some View {
        HStack {
            utilityButton(icon: .musicNoteList, active: showLyrics) { toggleLyrics() }
            Spacer()
            utilityButton(icon: .comment) { showComments = true }
            Spacer()
            utilityButton(icon: .immersive) { ImmersiveModeController.shared.present() }
            Spacer()
            utilityButton(icon: .list) { showPlaylist = true }
        }
    }

    @ViewBuilder
    func utilityButton(icon: MonologueIcon.IconType, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: 19, color: active ? .black : .white.opacity(0.78))
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(active ? Color.white.opacity(0.9) : Color.white.opacity(0.001))
                )
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }
}

// MARK: - 歌词态（全屏歌词，无控制栏）
extension ImmersiveLyricPlayerLayout {
    @ViewBuilder
    func lyricStage(size: CGSize) -> some View {
        VStack(spacing: 0) {
            // 顶部小封面信息栏（点歌词整体收起后隐藏，歌词铺满全屏）
            if isChromeVisible {
                lyricTopBar
                    .padding(.top, DeviceLayout.headerTopPadding)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 歌词一铺到底：没有底部控制栏
            if let song = player.currentSong {
                OrganicLyricsView(song: song) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isChromeVisible.toggle()
                    }
                }
                .environment(\.colorScheme, .dark)
            } else {
                Spacer()
            }
        }
        .frame(width: size.width)
        .transition(.opacity)
    }

    var lyricTopBar: some View {
        HStack(spacing: 12) {
            // 小封面 + 歌曲信息 —— 整块点按飞回播放态
            HStack(spacing: 12) {
                coverArtwork(size: 46, cornerRadius: 9)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentSong?.name ?? "No Title")
                        .monologuePlayerDisplayFont(
                            size: 16,
                            weight: .bold,
                            fallback: .system(size: 16, weight: .bold, design: .rounded)
                        )
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(player.currentSong?.artistName ?? "Unknown Artist")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { toggleLyrics() }

            Spacer(minLength: 12)

            if let song = player.currentSong {
                LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song,
                           size: 19, activeColor: .red, inactiveColor: .white.opacity(0.85))
            }

            // 与播放态同款的收起入口：点按回到封面
            Button(action: { toggleLyrics() }) {
                MonologueIcon(icon: .chevronDown, size: 16, color: .white.opacity(0.9))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.14)))
            }
            .buttonStyle(MonologueBouncingButtonStyle())
        }
    }
}

// MARK: - 封面（双状态共享）
extension ImmersiveLyricPlayerLayout {
    /// 大小两个状态共用的封面视图：同一个 matchedGeometry id，
    /// 切换时封面在「舞台中央 ⇄ 顶栏角落」之间真实飞行缩放。
    @ViewBuilder
    func coverArtwork(size: CGFloat, cornerRadius: CGFloat) -> some View {
        Group {
            if let song = player.currentSong, let url = song.coverUrl?.sized(size > 100 ? 500 : 100) {
                CachedAsyncImage(url: url) {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
                .aspectRatio(1.0, contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        MonologueIcon(icon: .musicNote, size: size * 0.24, color: .white.opacity(0.7))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(size > 100 ? 0.35 : 0.2),
                radius: size > 100 ? 26 : 5,
                x: 0, y: size > 100 ? 14 : 2)
        .matchedGeometryEffect(id: "immersiveLyricCover", in: animation)
    }
}
