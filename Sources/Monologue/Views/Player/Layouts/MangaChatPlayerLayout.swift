//
//  MangaChatPlayerLayout.swift
//  Monologue
//
//  漫画聊天播放器 — 歌词以两人对话气泡形式展示
//  灵感来自漫画小组件的视觉风格
//

import SwiftUI

struct MangaChatPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject var lyricVM = LyricViewModel.shared
    @ObservedObject var downloadManager = DownloadManager.shared

    // MARK: - Colors
    private var ink: Color { colorScheme == .dark ? Color(hex: "E8E8EF") : Color(hex: "2D2D3A") }
    private var inkSub: Color { colorScheme == .dark ? Color(hex: "8A8A9E") : Color(hex: "8888A0") }
    private var accentPink: Color { colorScheme == .dark ? Color(hex: "D86782") : Color(hex: "FF8FAB") }
    private var labelYellow: Color { colorScheme == .dark ? Color(hex: "E6BD76") : Color(hex: "FFE4B5") }
    private var decoBlue: Color { colorScheme == .dark ? Color(hex: "6A98BD") : Color(hex: "B8D4F0") }
    private var bubbleWhite: Color { colorScheme == .dark ? Color(hex: "1F1F2A") : Color(hex: "FFFFFF") }
    private var bubblePink: Color { colorScheme == .dark ? Color(hex: "2E1D25") : Color(hex: "FFE8F0") }
    private var bubbleBlue: Color { colorScheme == .dark ? Color(hex: "1E2530") : Color(hex: "E8F0FF") }

    // MARK: - State
    @State private var isAppeared = false
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showMoreMenu = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showComments = false
    @State private var showArtistDetail = false
    @State private var showDownloadSheet = false
    @State private var userAvatarUrl: String? = nil
    @StateObject private var colorExtractor = CoverColorExtractor()
    @ObservedObject private var homeVM = HomeViewModel.shared

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                // 漫画网点背景 + 随机飘动装饰
                ZStack {
                    mangaBackground(size: size)
                    FloatingMangaDecorations(size: size, colorScheme: colorScheme).equatable()
                        .allowsHitTesting(false)
                }
                .clipped()
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 顶部导航栏
                    topBar
                        .padding(.top, 4)
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                    // 歌曲信息头
                    songInfoHeader
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 8)

                    // 聊天歌词区域
                    chatLyricsArea
                        .padding(.top, 8)

                    // 底部控制栏
                    controlBar(geo: geo)
                }
                .frame(width: size.width, height: size.height, alignment: .center)

                // 更多菜单
                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        isDarkBackground: colorScheme == .dark,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                    .frame(width: size.width, height: size.height, alignment: .center)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .center)
            .opacity(isAppeared ? 1 : 0)
        }
        .onAppear {
            if let profile = homeVM.userProfile {
                userAvatarUrl = profile.avatarUrl
            } else if let profile = OptimizedCacheManager.shared.getObject(forKey: "user_profile_detail", type: UserProfile.self) {
                userAvatarUrl = profile.avatarUrl
            }
            colorExtractor.extract(from: player.currentSong?.coverUrl?.absoluteString)
            withAnimation(.easeOut(duration: 0.5)) { isAppeared = true }
        }
        .onChange(of: homeVM.userProfile?.avatarUrl) { _, newUrl in
            if let url = newUrl {
                userAvatarUrl = url
            }
        }
        .onChange(of: player.currentSong) { _, newSong in
            colorExtractor.extract(from: newSong?.coverUrl?.absoluteString)
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            PlaylistPopupView()
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
        .monologueSheet(isPresented: $showEQSettings, preset: .large) {
            NavigationStack { EQSettingsView() }
        }
        .monologueSheet(isPresented: $showThemePicker, preset: .themePicker) {
            PlayerThemePickerSheet()
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
        .monologueSheet(isPresented: $showDownloadSheet, preset: .compact) {
            if let song = player.currentSong {
                DownloadQualitySheet(song: song) {
                    showDownloadSheet = false
                }
            }
        }
    }
}

// MARK: - Background

extension MangaChatPlayerLayout {

    func mangaBackground(size: CGSize) -> some View {
        ZStack {
            // 柔和渐变底色
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: "0B0E17"), Color(hex: "121828"), Color(hex: "16243A")]
                : [Color(hex: "FFF8EC"), Color(hex: "FDE8F0"), Color(hex: "E8F4FD")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 网点图案
            Canvas { context, sz in
                let gap: CGFloat = 14
                let dotR: CGFloat = 0.8
                var y: CGFloat = gap / 2
                var isEven = true
                while y < sz.height + gap {
                    var x: CGFloat = isEven ? gap / 2 : gap
                    while x < sz.width + gap {
                        let rect = CGRect(x: x - dotR, y: y - dotR, width: dotR * 2, height: dotR * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(ink.opacity(0.08)))
                        x += gap
                    }
                    y += gap
                    isEven.toggle()
                }
            }
        }
    }

// Floating decorations are handled by FloatingMangaDecorations
}

// MARK: - Top Bar

extension MangaChatPlayerLayout {

    var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                MonologueSymbolIcon(name: "chevron.down", size: 16, color: ink)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(bubbleWhite)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(ink, lineWidth: 2.0)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ink)
                            .offset(x: 2.0, y: 2.0)
                    )
            }
            .buttonStyle(MonologueBouncingButtonStyle())

            Spacer()

            // NOW PLAYING 标签
            HStack(spacing: 3) {
                MonologueIcon(icon: .comment, size: 10, color: ink, lineWidth: 1.8)
                Text("CHAT")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1)
            }
            .foregroundStyle(ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(labelYellow))
            .overlay(Capsule().stroke(ink, lineWidth: 2.0))
            .background(Capsule().fill(ink).offset(x: 2, y: 2))

            Spacer()

            Button(action: { showMoreMenu.toggle() }) {
                MonologueIcon(icon: .more, size: 16, color: ink, lineWidth: 1.8)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(bubbleWhite)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(ink, lineWidth: 2.0)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ink)
                            .offset(x: 2.0, y: 2.0)
                    )
            }
            .buttonStyle(MonologueBouncingButtonStyle())
        }
    }
}

// MARK: - Song Info Header

extension MangaChatPlayerLayout {

    var songInfoHeader: some View {
        HStack(spacing: 12) {
            // 封面头像
            mangaAvatar(size: 50)

            VStack(alignment: .leading, spacing: 2) {
                Text(player.currentSong?.name ?? NSLocalizedString("not_playing", comment: "未在播放"))
                    .monologuePlayerDisplayFont(
                        size: 18,
                        weight: .heavy,
                        fallback: .system(size: 18, weight: .heavy, design: .rounded)
                    )
                    .foregroundColor(ink)
                    .lineLimit(1)

                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? "暂无歌曲信息")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(inkSub)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // 红心收藏（漫画标签风格）
            if let song = player.currentSong {
                mangaLikeButton(song: song)
            }

            // 音质标签
            Button { showQualitySheet = true } label: {
                Text(player.qualityButtonText)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(decoBlue))
                    .overlay(Capsule().stroke(ink, lineWidth: 2))
                    .background(Capsule().fill(ink).offset(x: 2, y: 2))
            }
            .buttonStyle(MonologueBouncingButtonStyle())
            .playerQualitySelectionAvailability()
        }
    }
    func mangaLikeButton(song: Song) -> some View {
        let isLiked = LikeManager.shared.isLiked(id: song.id, isQQMusic: song.isQQMusic)
        return Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            LikeManager.shared.toggleLike(songId: song.id, isQQMusic: song.isQQMusic, song: song)
        } label: {
            MangaHeart()
                .fill(isLiked ? accentPink : decoBlue)
                .overlay(MangaHeart().stroke(ink, lineWidth: 1.2))
                .frame(width: 14, height: 12)
                .background(
                    MangaHeart()
                        .fill(ink)
                        .frame(width: 14, height: 12)
                        .offset(x: 1.5, y: 1.5)
                )
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }

    func mangaAvatar(size: CGFloat) -> some View {
        Group {
            if let url = player.currentSong?.coverUrl?.sized(200) {
                CachedAsyncImage(url: url) {
                    Color(hex: "FFE4B5").opacity(0.4)
                }
                .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    labelYellow.opacity(0.4)
                    MonologueIcon(icon: .musicNote, size: size * 0.35, color: inkSub.opacity(0.5), lineWidth: 1.8)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .stroke(ink, lineWidth: 2.5)
        )
        .background(
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(ink)
                .offset(x: 3, y: 3)
        )
    }
}

// MARK: - Chat Lyrics Area

extension MangaChatPlayerLayout {

    var chatLyricsArea: some View {
        Group {
            if lyricVM.hasLyrics && !lyricVM.lyrics.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            Color.clear.frame(height: 8)

                            ForEach(Array(lyricVM.lyrics.enumerated()), id: \.element.id) { index, line in
                                if !line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    let isCurrent = index == lyricVM.currentLineIndex
                                    let isLeft = index % 2 == 0

                                    // 仅显示已经播放到或正在播放的歌词（类似聊天时逐条出现）
                                    if index <= lyricVM.currentLineIndex {
                                        chatBubble(
                                            text: line.text.monologueLyricDisplayText,
                                            translation: line.translation?.monologueLyricDisplayText,
                                            isLeft: isLeft,
                                            isCurrent: isCurrent,
                                            index: index
                                        )
                                        .id(index)
                                        .onTapWithHaptic { player.seek(to: line.time) }
                                        .transition(.asymmetric(
                                            insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .offset(y: 20)),
                                            removal: .opacity
                                        ))
                                    }
                                }
                            }

                            Color.clear.frame(height: 80)
                        }
                        .padding(.leading, 20)
                        .padding(.trailing, 26)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: lyricVM.currentLineIndex) { _, newIndex in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(lyricVM.currentLineIndex, anchor: .center)
                    }
                }
            } else {
                // 无歌词 - 显示漫画风占位
                VStack(spacing: 16) {
                    Spacer()

                    // 中央对话泡
                    VStack(spacing: 12) {
                        MonologueIcon(icon: .comment, size: 50, color: inkSub.opacity(0.25), lineWidth: 1.8)

                        Text("纯音乐，无歌词")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(inkSub.opacity(0.5))
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(bubbleWhite.opacity(0.8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(ink.opacity(0.15), lineWidth: 2)
                    )

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    func chatBubble(text: String, translation: String?, isLeft: Bool, isCurrent: Bool, index: Int) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isLeft {
                // 左侧：歌手头像（小封面）
                miniAvatar(isLeft: true)
                leftBubbleContent(text: text, translation: translation, isCurrent: isCurrent)
                Spacer(minLength: 20)
            } else {
                Spacer(minLength: 20)
                rightBubbleContent(text: text, translation: translation, isCurrent: isCurrent)
                // 右侧：音乐头像
                miniAvatar(isLeft: false)
            }
        }
        .scaleEffect(isCurrent ? 1.0 : 0.95)
        .opacity(isCurrent ? 1.0 : 0.55)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isCurrent)
    }

    func miniAvatar(isLeft: Bool) -> some View {
        Group {
            if isLeft {
                // 封面缩略图
                if let url = player.currentSong?.coverUrl?.sized(100) {
                    CachedAsyncImage(url: url) {
                        labelYellow.opacity(0.4)
                    }
                    .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        labelYellow.opacity(0.4)
                        MonologueIcon(icon: .microphone, size: 13, color: inkSub, lineWidth: 1.7)
                    }
                }
            } else {
                if let avatarStr = userAvatarUrl, let url = URL(string: avatarStr) {
                    CachedAsyncImage(url: url) {
                        decoBlue.opacity(0.5)
                    }
                    .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        decoBlue.opacity(0.5)
                        MonologueIcon(icon: .profileFilled, size: 17, color: ink.opacity(0.5), lineWidth: 1.7)
                    }
                }
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ink, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ink)
                .offset(x: 2, y: 2)
        )
    }

    func leftBubbleContent(text: String, translation: String?, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(
                    MonologuePlayerFont.activeFont(
                        size: isCurrent ? 17 : 15,
                        weight: isCurrent ? .heavy : .bold,
                        fallback: .system(
                            size: isCurrent ? 17 : 15,
                            weight: isCurrent ? .heavy : .bold,
                            design: .rounded
                        )
                    )
                )
                .foregroundColor(ink)
                .multilineTextAlignment(.leading)

            if let trans = translation, !trans.isEmpty {
                Text(trans)
                    .font(
                        MonologuePlayerFont.activeFont(
                            size: 12,
                            weight: .medium,
                            fallback: .system(size: 12, weight: .medium, design: .rounded)
                        )
                    )
                    .foregroundColor(inkSub)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 6, bottomTrailingRadius: 18, topTrailingRadius: 18, style: .continuous)
                .fill(isCurrent ? bubblePink : bubbleWhite)
        )
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 6, bottomTrailingRadius: 18, topTrailingRadius: 18, style: .continuous)
                .stroke(ink, lineWidth: isCurrent ? 3 : 2)
        )
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 6, bottomTrailingRadius: 18, topTrailingRadius: 18, style: .continuous)
                .fill(ink)
                .offset(x: 3, y: 3)
        )
    }

    func rightBubbleContent(text: String, translation: String?, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(
                    MonologuePlayerFont.activeFont(
                        size: isCurrent ? 17 : 15,
                        weight: isCurrent ? .heavy : .bold,
                        fallback: .system(
                            size: isCurrent ? 17 : 15,
                            weight: isCurrent ? .heavy : .bold,
                            design: .rounded
                        )
                    )
                )
                .foregroundColor(ink)
                .multilineTextAlignment(.leading)

            if let trans = translation, !trans.isEmpty {
                Text(trans)
                    .font(
                        MonologuePlayerFont.activeFont(
                            size: 12,
                            weight: .medium,
                            fallback: .system(size: 12, weight: .medium, design: .rounded)
                        )
                    )
                    .foregroundColor(inkSub)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 6, topTrailingRadius: 18, style: .continuous)
                .fill(isCurrent ? bubbleBlue : bubbleWhite)
        )
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 6, topTrailingRadius: 18, style: .continuous)
                .stroke(ink, lineWidth: isCurrent ? 3 : 2)
        )
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 6, topTrailingRadius: 18, style: .continuous)
                .fill(ink)
                .offset(x: -3, y: 3)
        )
    }
}

// MARK: - Control Bar

extension MangaChatPlayerLayout {

    func controlBar(geo: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            // 进度条
            mangaProgressBar

            // 控制按钮
            HStack(spacing: 0) {
                // 播放模式
                Button(action: { player.switchMode() }) {
                    MonologueIcon(icon: player.mode.monologueIcon, size: 16, color: inkSub)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(MonologueBouncingButtonStyle())

                Spacer()

                // 评论
                Button { showComments = true } label: {
                    mangaControlIcon(symbolName: "bubble.left.fill", size: 16)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(MonologueBouncingButtonStyle())

                Spacer()

                // 上一首
                Button(action: { player.previous() }) {
                    mangaButton(symbolName: "backward.fill", w: 38, h: 32, isPlay: false)
                }
                .buttonStyle(MonologueBouncingButtonStyle())

                Spacer()

                // 播放/暂停
                Button(action: { player.togglePlayPause() }) {
                    mangaButton(symbolName: player.isPlaying ? "pause.fill" : "play.fill", w: 46, h: 46, isPlay: true)
                }
                .buttonStyle(MonologueBouncingButtonStyle())

                Spacer()

                // 下一首
                Button(action: { player.next() }) {
                    mangaButton(symbolName: "forward.fill", w: 38, h: 32, isPlay: false)
                }
                .buttonStyle(MonologueBouncingButtonStyle())

                Spacer()

                // 下载（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled；隐藏期间该位置显示沉浸模式按钮）
                if player.currentSong != nil {
                    if AppConfig.Features.downloadEnabled, let song = player.currentSong {
                        Button {
                            if !downloadManager.isDownloaded(songId: song.id) {
                                showDownloadSheet = true
                            }
                        } label: {
                            mangaControlIcon(symbolName: "arrow.down.circle.fill", size: 16,
                                            dimmed: downloadManager.isDownloaded(songId: song.id))
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .disabled(downloadManager.isDownloaded(songId: song.id))
                    } else {
                        // 沉浸模式按钮 — 占用原下载按钮的位置
                        Button {
                            CinemaModeController.shared.present()
                        } label: {
                            MonologueIcon(icon: .immersive, size: 16, color: inkSub)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                    }
                } else {
                    Color.clear.frame(width: 36)
                }

                Spacer()

                // 播放列表
                Button(action: { showPlaylist = true }) {
                    mangaControlIcon(symbolName: "list.bullet", size: 16)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(bubbleWhite.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(ink, lineWidth: 2.5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 0)
    }

    var mangaProgressBar: some View {
        VStack(spacing: 4) {
            GeometryReader { barGeo in
                let progress = timePublisher.duration > 0
                    ? min(max(timePublisher.currentTime / timePublisher.duration, 0), 1)
                    : 0.0

                ZStack(alignment: .leading) {
                    // 轨道
                    Capsule()
                        .fill(ink.opacity(0.1))
                        .frame(height: 8)
                        .overlay(
                            Capsule().stroke(ink, lineWidth: 2)
                        )

                    // 已播放
                    Capsule()
                        .fill(colorExtractor.dominantColor)
                        .frame(width: max(8, barGeo.size.width * CGFloat(progress)), height: 8)
                        .overlay(
                            Capsule().stroke(ink, lineWidth: 2)
                        )
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let p = min(max(value.location.x / barGeo.size.width, 0), 1)
                            player.seek(to: p * timePublisher.duration)
                        }
                )
            }
            .frame(height: 10)

            HStack {
                Text(formatTime(timePublisher.currentTime))
                Spacer()
                Text(formatTime(timePublisher.duration))
            }
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .foregroundColor(inkSub)
        }
        .padding(.horizontal, 10)
    }

    func mangaButton(symbolName: String, w: CGFloat, h: CGFloat, isPlay: Bool) -> some View {
        MonologueSymbolIcon(name: symbolName, size: min(w, h) * 0.44, color: isPlay ? .white : ink)
            .frame(width: w, height: h)
            .background(
                RoundedRectangle(cornerRadius: min(w, h) * 0.32, style: .continuous)
                    .fill(isPlay ? colorExtractor.dominantColor : bubbleWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: min(w, h) * 0.32, style: .continuous)
                    .stroke(ink, lineWidth: 2.5)
            )
            .background(
                RoundedRectangle(cornerRadius: min(w, h) * 0.32, style: .continuous)
                    .fill(ink)
                    .offset(x: 3, y: 3)
            )
    }

    @ViewBuilder
    func mangaControlIcon(symbolName: String, size: CGFloat, dimmed: Bool = false) -> some View {
        MonologueSymbolIcon(name: symbolName, size: size, color: dimmed ? inkSub.opacity(0.3) : inkSub)
    }

    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "00:00" }
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

// Shapes removed


// MARK: - Manga Decorative Shapes

struct MangaSparkle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX, cy = rect.midY
        let w = rect.width / 2, h = rect.height / 2
        let inset: CGFloat = 0.3

        path.move(to: CGPoint(x: cx, y: cy - h))
        path.addLine(to: CGPoint(x: cx + w * inset, y: cy - h * inset))
        path.addLine(to: CGPoint(x: cx + w, y: cy))
        path.addLine(to: CGPoint(x: cx + w * inset, y: cy + h * inset))
        path.addLine(to: CGPoint(x: cx, y: cy + h))
        path.addLine(to: CGPoint(x: cx - w * inset, y: cy + h * inset))
        path.addLine(to: CGPoint(x: cx - w, y: cy))
        path.addLine(to: CGPoint(x: cx - w * inset, y: cy - h * inset))
        path.closeSubpath()
        return path
    }
}

struct MangaStar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX, cy = rect.midY
        let outerR = min(rect.width, rect.height) / 2
        let innerR = outerR * 0.4
        let points = 5

        for i in 0..<(points * 2) {
            let angle = (Double(i) * .pi / Double(points)) - .pi / 2
            let r = i % 2 == 0 ? outerR : innerR
            let pt = CGPoint(x: cx + CGFloat(cos(angle)) * r, y: cy + CGFloat(sin(angle)) * r)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

struct MangaHeart: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height

        path.move(to: CGPoint(x: w * 0.5, y: h))
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.35),
            control1: CGPoint(x: w * 0.15, y: h * 0.8),
            control2: CGPoint(x: 0, y: h * 0.55)
        )
        path.addArc(
            center: CGPoint(x: w * 0.25, y: h * 0.25),
            radius: w * 0.25,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addArc(
            center: CGPoint(x: w * 0.75, y: h * 0.25),
            radius: w * 0.25,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control1: CGPoint(x: w, y: h * 0.55),
            control2: CGPoint(x: w * 0.85, y: h * 0.8)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Floating Decorations System

struct FloatingMangaDecorations: View, Equatable {
    let size: CGSize
    let colorScheme: ColorScheme
    
    nonisolated static func == (lhs: FloatingMangaDecorations, rhs: FloatingMangaDecorations) -> Bool {
        lhs.size == rhs.size && lhs.colorScheme == rhs.colorScheme
    }
    
    enum DecoType { case sparkle, star, heart, dot, meteor }
    
    struct Floater: Identifiable, Equatable {
        let id = UUID()
        let type: DecoType
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
        var rotation: Double
        var speed: CGFloat
        var vx: CGFloat = 0
    }
    
    @State private var floaters: [Floater] = []
    let timer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
    
    private var ink: Color { colorScheme == .dark ? Color(hex: "E8E8EF") : Color(hex: "2D2D3A") }
    private var accentPink: Color { colorScheme == .dark ? Color(hex: "D86782") : Color(hex: "FF8FAB") }
    private var labelYellow: Color { colorScheme == .dark ? Color(hex: "E6BD76") : Color(hex: "FFE4B5") }
    private var decoBlue: Color { colorScheme == .dark ? Color(hex: "6A98BD") : Color(hex: "B8D4F0") }
    
    var body: some View {
        ZStack {
            ForEach(floaters) { floater in
                if floater.type == .meteor {
                    MangaFluidMeteor(ink: ink, fill: labelYellow, initialX: floater.x, initialY: floater.y, size: size, speed: floater.speed, rotation: floater.rotation)
                } else {
                    decoView(for: floater.type, floater: floater)
                        .scaleEffect(floater.scale)
                        .rotationEffect(.degrees(floater.rotation))
                        .position(x: floater.x, y: floater.y)
                        .animation(colorScheme == .dark ? nil : .linear(duration: 0.8), value: floater)
                        .transition(.opacity.combined(with: .scale(scale: 0.1)))
                }
            }
        }
        .onReceive(timer) { _ in
            updateFloaters()
        }
        .onAppear {
            for _ in 0..<8 { spawnFloater(initial: true) }
        }
        .onChange(of: colorScheme) { _, _ in
            floaters.removeAll()
            for _ in 0..<12 { spawnFloater(initial: true) }
        }
    }
    
    @ViewBuilder
    func decoView(for type: DecoType, floater: Floater) -> some View {
        switch type {
        case .sparkle:
            MangaSparkle()
                .fill(accentPink)
                .overlay(MangaSparkle().stroke(ink, lineWidth: 1.5))
                .frame(width: 16, height: 16)
        case .star:
            if colorScheme == .dark {
                MangaBreathingStar(ink: ink, fill: labelYellow)
            } else {
                MangaStar()
                    .fill(labelYellow)
                    .overlay(MangaStar().stroke(ink, lineWidth: 1.5))
                    .frame(width: 18, height: 18)
            }
        case .heart:
            MangaHeart()
                .fill(accentPink)
                .overlay(MangaHeart().stroke(ink, lineWidth: 1.2))
                .frame(width: 14, height: 12)
        case .dot:
            Circle()
                .fill(decoBlue)
                .overlay(Circle().stroke(ink, lineWidth: 1.2))
                .frame(width: 10, height: 10)
        case .meteor:
            EmptyView() // Handled externally by MangaFluidMeteor
        }
    }
    
    private func updateFloaters() {
        var active: [Floater] = []
        var meteorCount = 0
        var staticCount = 0

        for var f in floaters {
            if colorScheme == .dark && f.type != .meteor {
                // 深色模式下星星静止并在自身视图里呼吸，不用更新轨迹
                active.append(f)
                staticCount += 1
            } else if f.type == .meteor {
                // 流星由 MangaFluidMeteor 自己管理运动，我们只需保持他的寿命并在一定时间后剔除
                f.vx += 1 // 借用 vx 存储存活的心跳次数
                if f.vx < 8 { // 存活 8 次心跳 = 6.4秒
                    active.append(f)
                    meteorCount += 1
                }
            } else {
                // 浅色模式往上飘
                f.y -= f.speed
                f.rotation += Double.random(in: -15...15)
                f.x += CGFloat.random(in: -10...10)
                if f.y > -100 && f.x > -100 && f.x < size.width + 100 {
                    active.append(f)
                    staticCount += 1
                }
            }
        }
        
        let isDark = colorScheme == .dark
        let maxCount = isDark ? 15 : 12
        
        // 维持常规装饰物（星星/上浮气泡）数量
        if staticCount < maxCount && Bool.random() {
            spawnInto(&active, initial: false, forceMeteor: false)
        }
        
        // 流星独立生成逻辑（不受星星数量占满的影响，允许同屏有多颗）
        if isDark && meteorCount < 5 {
            // 每隔一段随机时间（1/12概率）
            if Int.random(in: 0...12) == 0 {
                // 极大幅度提高群落概率，最高可一次生成 5 颗
                let roll = Int.random(in: 1...100)
                let spawnQuantity: Int
                switch roll {
                case 1...10: spawnQuantity = 1   // 1颗 (10%)
                case 11...40: spawnQuantity = 2  // 2颗 (30%)
                case 41...70: spawnQuantity = 3  // 3颗 (30%)
                case 71...90: spawnQuantity = 4  // 4颗 (20%)
                default: spawnQuantity = 5       // 5颗 (10%)
                }
                for _ in 0..<spawnQuantity {
                    // 确保不要超出我们在上层定下的同屏最大流星数 5
                    if meteorCount < 5 {
                        spawnInto(&active, initial: false, forceMeteor: true)
                        meteorCount += 1
                    }
                }
            }
        }
        
        floaters = active
    }
    
    private func spawnFloater(initial: Bool) {
        spawnInto(&floaters, initial: initial, forceMeteor: false)
    }
    
    private func spawnInto(_ array: inout [Floater], initial: Bool, forceMeteor: Bool) {
        // guard: size 尚未确定（GeometryReader 首次 pass 可能为 0）时直接跳过，
        // 否则 CGFloat.random(in: 20...(size.width-20)) 会出现 lowerBound>upperBound 的崩溃。
        guard size.width > 60, size.height > 120 else { return }

        let isDark = colorScheme == .dark

        let type: DecoType
        if forceMeteor {
            type = .meteor
        } else {
            let types: [DecoType] = isDark ? [.star] : [.sparkle, .star, .heart, .dot, .dot]
            type = types.randomElement()!
        }

        let isMeteor = type == .meteor
        // 对流星来说，vx 现在用来当生命周期 tick 计数器，初始化为 0
        let vx: CGFloat = 0
        // 流星严格从屏幕左上方视野外随机范围内生成，配合延迟和多角度，绝对不会并排同频
        let meteorXUpper = max(-280, size.width * 0.2)
        let startX = isMeteor
            ? CGFloat.random(in: -300...meteorXUpper)
            : CGFloat.random(in: 20...max(21, size.width - 20))
        let startY: CGFloat
        if initial {
            startY = CGFloat.random(in: 50...max(51, size.height - 50))
        } else if isMeteor {
            startY = CGFloat.random(in: -300 ... -50)
        } else if isDark {
            startY = CGFloat.random(in: 50...max(51, size.height - 50))
        } else {
            startY = size.height + 20
        }
        
        // 当深色模式生成星空时，初始就给星星赋予随机位置
        let f = Floater(
            type: type,
            x: startX,
            y: startY,
            scale: CGFloat.random(in: 0.7...1.3),
            rotation: isMeteor ? Double.random(in: 35...65) : Double.random(in: -30...30), // 流星倾角在35~65度之间随机发散
            speed: isMeteor ? CGFloat.random(in: 60...100) : CGFloat.random(in: 20...40),
            vx: vx
        )
        array.append(f)
    }
}

// 独立的深色呼吸星星
struct MangaBreathingStar: View {
    let ink: Color
    let fill: Color
    let duration: Double = Double.random(in: 1.5...3.5)
    
    @State private var phase = false
    
    var body: some View {
        MangaStar()
            .fill(fill)
            .overlay(MangaStar().stroke(ink, lineWidth: 1.5))
            .frame(width: 12, height: 12)  // 缩小静态星星尺寸
            .scaleEffect(phase ? 1.1 : 0.7)
            .opacity(phase ? 1.0 : 0.3)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    phase.toggle()
                }
            }
    }
}

// 独立的流星视图（完全脱离 Timer 更新，依靠一次性的 SwiftUI fluid 动画执行）
struct MangaFluidMeteor: View {
    let ink: Color
    let fill: Color
    let initialX: CGFloat
    let initialY: CGFloat
    let size: CGSize
    let speed: CGFloat
    let rotation: Double
    
    @State private var posX: CGFloat = 0
    @State private var posY: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .leading) {
            // 拖尾（方向向左延伸尾巴）
            Capsule()
                .fill(
                    LinearGradient(colors: [.clear, fill.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: 80, height: 2)
                .offset(x: -76)
            
            // 星星头部
            MangaStar()
                .fill(fill)
                .overlay(MangaStar().stroke(ink, lineWidth: 1.5))
                .frame(width: 12, height: 12)
        }
        .rotationEffect(.degrees(rotation))
        .position(x: posX, y: posY)
        .onAppear {
            posX = initialX
            posY = initialY
            
            // 大幅拉长跑动距离 (speed * 35)，同时增加 duration 抵消增加的距离带来的加速感，确保无论角度如何都肯定能飞出屏幕再停下
            let radian = rotation * .pi / 180
            withAnimation(.linear(duration: Double.random(in: 5.0...8.0)).delay(Double.random(in: 0...0.8))) {
                posX = initialX + (speed * 35) * CGFloat(cos(radian))
                posY = initialY + (speed * 35) * CGFloat(sin(radian))
            }
        }
    }
}
