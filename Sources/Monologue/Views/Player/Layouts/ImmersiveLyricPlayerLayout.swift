import SwiftUI
import FFmpegSwiftSDK

/// 沉浸动态歌词版播放器布局 - Apple Music 风格 (大封面与歌词双状态)
struct ImmersiveLyricPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared

    @StateObject private var colorExtractor = CoverColorExtractor()
    @State private var showMoreMenu = false
    @State private var showQualitySheet = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showArtistDetail = false
    @State private var showComments = false
    @State private var showDownloadSheet = false
    
    // 双状态核心：是否跑在这套主题的主页面（歌词界面）
    @State private var showLyrics = true
    @Namespace private var animation
    
    // 控制底部悬浮播放栏的显示隐藏 (仅限歌词界面)
    @State private var isControlsVisible = false
    
    // 进度条控制
    @State private var isDraggingSlider = false
    @State private var dragTimeValue: Double = 0

    var body: some View {
        GeometryReader { geo in
            let sw = geo.size.width
            
            ZStack(alignment: .topLeading) {
                // 1. 弥散背景 (复用已有的播放器模糊变幻逻辑，双状态共享)
                PlaylistColorBackground(
                    coverUrl: player.currentSong?.coverUrl?.sized(200),
                    onBrightnessChanged: { _ in }
                )
                .frame(width: sw)
                .ignoresSafeArea()
                    
                if showLyrics {
                    // === 状态 B：歌词界面 ===
                    VStack(spacing: 0) {
                        // 2. 顶部小封面 + 信息栏
                        topNavBar
                            .padding(.top, DeviceLayout.headerTopPadding)
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                            .padding(.bottom, 12)
                        
                        // 3. 占据中间剩余所有空间的歌词瀑布流
                        if let song = player.currentSong {
                            OrganicLyricsView(song: song) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isControlsVisible.toggle()
                                }
                            }
                            .environment(\.colorScheme, .dark)
                        } else {
                            Spacer()
                        }
                    }
                    .frame(width: sw)
                } else {
                    // === 状态 A：常规大封面播放器 ===
                    standardPlayerContainer
                }
                
                // 4. 底部悬浮控制栏 (仅在歌词界面且唤出时显示)
                VStack {
                    Spacer()
                    if showLyrics && isControlsVisible {
                        bottomControlsBar
                            .padding(.bottom, 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(width: sw)
                .ignoresSafeArea(edges: .bottom)
                
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
        .monologueSheet(isPresented: $showEQSettings, preset: .large) {
            NavigationStack { EQSettingsView() }
        }
        .monologueSheet(isPresented: $showThemePicker, preset: .themePicker) {
            PlayerThemePickerSheet()
        }
        .monologueSheet(isPresented: $showQualitySheet, preset: .compact) {
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

// MARK: - 常规播放界面 (大封面状态)
extension ImmersiveLyricPlayerLayout {
    var standardPlayerContainer: some View {
        VStack {
            // 顶部下拉与更多菜单
            HStack {
                Button(action: { dismiss() }) {
                    MonologueIcon(icon: .back, size: 24, color: .white)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                
                Spacer()
                
                Button(action: { showMoreMenu = true }) {
                    MonologueIcon(icon: .more, size: 24, color: .white)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
            .padding(.top, DeviceLayout.headerTopPadding)
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            
            Spacer()
            
            // 巨幅封面，支持点击展开全屏歌词
            if let song = player.currentSong, let url = song.coverUrl?.sized(500) {
                CachedAsyncImage(url: url) {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
                .aspectRatio(1.0, contentMode: .fill)
                // 强制锁定绝对宽高，避免外部 VStack 切换时的尺寸挤压塌缩现象
                .frame(width: UIScreen.main.bounds.width - 64, height: UIScreen.main.bounds.width - 64)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                // 核心解法：无中生有的展开动画！以自己的左上角为奇点“喷射展开”和“收缩归位”
                // 彻底抛弃 matchedGeometryEffect 导致的游离飞行感
                .transition(.scale(scale: 0.15, anchor: .topLeading).combined(with: .opacity))
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        showLyrics = true
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(1.0, contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width - 64, height: UIScreen.main.bounds.width - 64)
                    .overlay(MonologueIcon(icon: .musicNote, size: 60, color: .white.opacity(0.7)))
                    .transition(.scale(scale: 0.15, anchor: .topLeading).combined(with: .opacity))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            showLyrics = true
                        }
                    }
            }
            
            Spacer()
            
            // 歌曲标题与操作
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(player.currentSong?.name ?? "No Title")
                        .monologuePlayerDisplayFont(
                            size: 24,
                            weight: .bold,
                            fallback: .system(size: 24, weight: .bold, design: .rounded)
                        )
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Button(action: { showArtistDetail = true }) {
                        Text(player.currentSong?.artistName ?? "Unknown Artist")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let song = player.currentSong {
                    LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 28, activeColor: .red, inactiveColor: .white.opacity(0.8))
                }
            }
            .padding(.horizontal, 32)
            
            // 进度条
            PlayerProgressSection(
                isDragging: $isDraggingSlider,
                dragValue: $dragTimeValue,
                contentColor: .white
            )
            .padding(.horizontal, 32)
            .padding(.top, 24)
            
            // 大面积底栏控件
            HStack {
                Button(action: { player.switchMode() }) {
                    MonologueIcon(icon: player.mode.monologueIcon, size: 24, color: .white.opacity(0.8))
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                
                Spacer()
                
                Button(action: { player.previous() }) {
                    MonologueIcon(icon: .previous, size: 28, color: .white)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                
                Spacer()
                
                Button(action: { player.togglePlayPause() }) {
                    if player.isLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 44, height: 44)
                    } else {
                        MonologueIcon(icon: player.isPlaying ? .pause : .play, size: 44, color: .white)
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                
                Spacer()
                
                Button(action: { player.next() }) {
                    MonologueIcon(icon: .next, size: 28, color: .white)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                
                Spacer()
                
                Button(action: { showComments = true }) {
                    MonologueIcon(icon: .comment, size: 24, color: .white.opacity(0.8))
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            
            Spacer()
        }
    }
}

// MARK: - 歌词界面顶部栏 (小封面状态)
extension ImmersiveLyricPlayerLayout {
    var topNavBar: some View {
        HStack(spacing: 12) {
            // 下拉直接关掉整个播放器
            Button(action: { dismiss() }) {
                MonologueIcon(icon: .back, size: 20, color: .white)
            }
            .buttonStyle(MonologueBouncingButtonStyle())
            
            // 小封面 —— 点击平滑还原为大封面 (`showLyrics = false`)
            if let song = player.currentSong, let url = song.coverUrl?.sized(100) {
                CachedAsyncImage(url: url) {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
                .aspectRatio(1.0, contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                .transition(.opacity) // 只淡入淡出，不飞行动画
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        showLyrics = false
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(1.0, contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .overlay(MonologueIcon(icon: .musicNote, size: 20, color: .white.opacity(0.7)))
                    .transition(.opacity) // 只淡入淡出，不飞行动画
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            showLyrics = false
                        }
                    }
            }
            
            // 歌曲信息
            VStack(alignment: .leading, spacing: 2) {
                Text(player.currentSong?.name ?? "No Title")
                    .monologuePlayerDisplayFont(
                        size: 16,
                        weight: .bold,
                        fallback: .system(size: 16, weight: .bold, design: .rounded)
                    )
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Button(action: { showArtistDetail = true }) {
                    Text(player.currentSong?.artistName ?? "Unknown Artist")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 收藏与更多
            HStack(spacing: 16) {
                if let song = player.currentSong {
                    LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 20, activeColor: .red, inactiveColor: .white)
                }
                
                Button(action: { showMoreMenu = true }) {
                    MonologueIcon(icon: .more, size: 20, color: .white)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
        }
        .padding(.top, DeviceLayout.headerTopPadding) // 补充一下基础的安全边际
    }
}

// MARK: - 底部控件栏 (仅在歌词悬浮浮动界面使用)
extension ImmersiveLyricPlayerLayout {
    var bottomControlsBar: some View {
        VStack(spacing: 20) {
            // 进度条
            PlayerProgressSection(
                isDragging: $isDraggingSlider,
                dragValue: $dragTimeValue,
                contentColor: .white
            )
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            
            // 按钮栏
            HStack(spacing: 30) {
                Button(action: { showComments = true }) {
                    MonologueIcon(icon: .comment, size: 24, color: .white)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                
                Spacer()
                
                Button(action: { player.previous() }) {
                    MonologueIcon(icon: .previous, size: 24, color: .white, lineWidth: 2)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                
                Button(action: { player.togglePlayPause() }) {
                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 44, height: 44)
                    } else {
                        MonologueIcon(icon: player.isPlaying ? .pause : .play, size: 40, color: .white, lineWidth: 2.5)
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                
                Button(action: { player.next() }) {
                    MonologueIcon(icon: .next, size: 24, color: .white, lineWidth: 2)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                
                Spacer()
                
                Button(action: { player.switchMode() }) {
                    MonologueIcon(icon: player.mode.monologueIcon, size: 24, color: .white)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding + 10)
        }
        .padding(.vertical, 20)
        .background(
            MonologueGlassContainer { Color.clear }
                .opacity(0.8)
                .clipShape(RoundedRectangle(cornerRadius: 24))
        )
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}
