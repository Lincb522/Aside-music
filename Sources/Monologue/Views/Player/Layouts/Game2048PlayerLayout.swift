import SwiftUI
import UIKit
import FFmpegSwiftSDK

// MARK: - 2048 游戏播放器主题

struct Game2048PlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject var lyricVM = LyricViewModel.shared
    @ObservedObject var downloadManager = DownloadManager.shared

    // MARK: - State

    @State private var showLyrics = false
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showMoreMenu = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showComments = false
    @State private var showArtistDetail = false
    @State private var showDownloadSheet = false
    @StateObject private var colorExtractor = CoverColorExtractor()

    // 动画
    @State private var tilesAppeared = false
    @State private var playPulse = false
    @State private var shimmerPhase: CGFloat = -0.5
    @State private var currentLayout: Int = 0
    @State private var merging = false      // 合并阶段：被吸收方块滑到吸收方块的格子
    @State private var animTick: Int = 0    // 动画触发器

    // MARK: - 棋盘布局系统

    /// 方块在 4×4 网格中的位置（列, 行）
    private struct GP: Equatable { let c: Int, r: Int }

    /// 一种完整的棋盘排列
    private struct BoardLayout: Equatable {
        let cover, lyrics, song, mode, like, prev, next, artist, quality: GP
    }

    /// 12 种预定义排列 —— 切歌时随机切换
    private static let layouts: [BoardLayout] = [
        // 0: 封面左上，歌词右下
        BoardLayout(cover: GP(c:0,r:0), lyrics: GP(c:2,r:2), song: GP(c:0,r:2),
                    mode: GP(c:2,r:0), like: GP(c:3,r:0), prev: GP(c:2,r:1), next: GP(c:3,r:1),
                    artist: GP(c:0,r:3), quality: GP(c:1,r:3)),
        // 1: 歌词左上，封面右下
        BoardLayout(cover: GP(c:2,r:2), lyrics: GP(c:0,r:0), song: GP(c:2,r:0),
                    mode: GP(c:0,r:2), like: GP(c:1,r:2), prev: GP(c:0,r:3), next: GP(c:1,r:3),
                    artist: GP(c:2,r:1), quality: GP(c:3,r:1)),
        // 2: 封面右上，歌词左下
        BoardLayout(cover: GP(c:2,r:0), lyrics: GP(c:0,r:2), song: GP(c:0,r:0),
                    mode: GP(c:0,r:1), like: GP(c:1,r:1), prev: GP(c:2,r:2), next: GP(c:3,r:2),
                    artist: GP(c:2,r:3), quality: GP(c:3,r:3)),
        // 3: 封面左下，歌词右上
        BoardLayout(cover: GP(c:0,r:2), lyrics: GP(c:2,r:0), song: GP(c:0,r:0),
                    mode: GP(c:0,r:1), like: GP(c:1,r:1), prev: GP(c:2,r:2), next: GP(c:3,r:2),
                    artist: GP(c:2,r:3), quality: GP(c:3,r:3)),
        // 4: 封面左上，歌词左下（纵向大块左列）
        BoardLayout(cover: GP(c:0,r:0), lyrics: GP(c:0,r:2), song: GP(c:2,r:0),
                    mode: GP(c:2,r:2), like: GP(c:3,r:2), prev: GP(c:2,r:3), next: GP(c:3,r:3),
                    artist: GP(c:2,r:1), quality: GP(c:3,r:1)),
        // 5: 歌词左上，封面右上（横向大块顶行）
        BoardLayout(cover: GP(c:2,r:0), lyrics: GP(c:0,r:0), song: GP(c:2,r:2),
                    mode: GP(c:0,r:2), like: GP(c:1,r:2), prev: GP(c:0,r:3), next: GP(c:1,r:3),
                    artist: GP(c:2,r:3), quality: GP(c:3,r:3)),
        // 6: 封面右上，歌词右下（纵向大块右列）
        BoardLayout(cover: GP(c:2,r:0), lyrics: GP(c:2,r:2), song: GP(c:0,r:0),
                    mode: GP(c:0,r:1), like: GP(c:1,r:1), prev: GP(c:0,r:2), next: GP(c:1,r:2),
                    artist: GP(c:0,r:3), quality: GP(c:1,r:3)),
        // 7: 封面左上，歌词右上（横向大块顶行）
        BoardLayout(cover: GP(c:0,r:0), lyrics: GP(c:2,r:0), song: GP(c:0,r:2),
                    mode: GP(c:2,r:2), like: GP(c:3,r:2), prev: GP(c:2,r:3), next: GP(c:3,r:3),
                    artist: GP(c:0,r:3), quality: GP(c:1,r:3)),
        // 8: 封面左下，歌词左上（纵向大块左列）
        BoardLayout(cover: GP(c:0,r:2), lyrics: GP(c:0,r:0), song: GP(c:2,r:0),
                    mode: GP(c:2,r:1), like: GP(c:3,r:1), prev: GP(c:2,r:2), next: GP(c:3,r:2),
                    artist: GP(c:2,r:3), quality: GP(c:3,r:3)),
        // 9: 封面右下，歌词左上（对角线）
        BoardLayout(cover: GP(c:2,r:2), lyrics: GP(c:0,r:0), song: GP(c:0,r:2),
                    mode: GP(c:2,r:0), like: GP(c:3,r:0), prev: GP(c:2,r:1), next: GP(c:3,r:1),
                    artist: GP(c:0,r:3), quality: GP(c:1,r:3)),
        // 10: 封面左下，歌词右下（横向大块底行）
        BoardLayout(cover: GP(c:0,r:2), lyrics: GP(c:2,r:2), song: GP(c:0,r:0),
                    mode: GP(c:2,r:0), like: GP(c:3,r:0), prev: GP(c:2,r:1), next: GP(c:3,r:1),
                    artist: GP(c:0,r:1), quality: GP(c:1,r:1)),
        // 11: 封面右下，歌词右上（纵向大块右列）
        BoardLayout(cover: GP(c:2,r:2), lyrics: GP(c:2,r:0), song: GP(c:0,r:0),
                    mode: GP(c:0,r:1), like: GP(c:1,r:1), prev: GP(c:0,r:2), next: GP(c:1,r:2),
                    artist: GP(c:0,r:3), quality: GP(c:1,r:3)),
    ]

    private var layout: BoardLayout {
        Self.layouts[currentLayout % Self.layouts.count]
    }

    /// 网格位置 → 像素偏移
    private func offset(_ pos: GP, cell: CGFloat) -> CGSize {
        CGSize(width: CGFloat(pos.c) * (cell + gap), height: CGFloat(pos.r) * (cell + gap))
    }

    /// 每个方块的滑动弹簧动画（带不同延迟）
    private func tileSlide(delay: Double) -> Animation {
        .spring(response: 0.45, dampingFraction: 0.72).delay(delay)
    }

    // MARK: - 封面取色

    private var hsb: (h1: Double, s1: Double, b1: Double, h2: Double, s2: Double, b2: Double) {
        var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0
        var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0
        UIColor(colorExtractor.dominantColor).getHue(&h1, saturation: &s1, brightness: &b1, alpha: nil)
        UIColor(colorExtractor.secondaryColor).getHue(&h2, saturation: &s2, brightness: &b2, alpha: nil)
        if s1 < 0.05 && s2 < 0.05 {
            h1 = 0.08; s1 = 0.25; b1 = 0.85; h2 = 0.06; s2 = 0.35; b2 = 0.75
        }
        if s2 < 0.05 {
            h2 = (h1 + 0.08).truncatingRemainder(dividingBy: 1.0); s2 = s1 * 0.8; b2 = b1 * 0.9
        }
        return (Double(h1), Double(s1), Double(b1), Double(h2), Double(s2), Double(b2))
    }

    private func tileColor(_ v: Int) -> Color {
        let c = hsb
        switch v {
        case 2:    return Color(hue: c.h1, saturation: c.s1 * 0.12, brightness: 0.93)
        case 4:    return Color(hue: c.h1, saturation: c.s1 * 0.22, brightness: 0.89)
        case 8:    return Color(hue: c.h2, saturation: max(c.s2, 0.4),  brightness: 0.82)
        case 16:   return Color(hue: c.h2, saturation: max(c.s2, 0.5),  brightness: 0.75)
        case 32:   return Color(hue: c.h1, saturation: max(c.s1, 0.45), brightness: 0.72)
        case 64:   return Color(hue: c.h1, saturation: max(c.s1, 0.55), brightness: 0.65)
        case 128:  return Color(hue: (c.h1+c.h2)/2, saturation: max((c.s1+c.s2)/2, 0.35), brightness: 0.83)
        case 256:  return Color(hue: c.h1, saturation: max(c.s1, 0.5), brightness: 0.8)
        case 512:  return Color(hue: c.h2, saturation: max(c.s2, 0.45), brightness: 0.78)
        case 1024: return Color(hue: c.h1, saturation: max(c.s1, 0.5), brightness: 0.78)
        case 2048: return colorExtractor.dominantColor
        default:   return Color(hue: c.h1, saturation: c.s1 * 0.5, brightness: 0.2)
        }
    }

    private func tileFg(_ v: Int) -> Color {
        v <= 4
            ? Color(hue: hsb.h1, saturation: hsb.s1 * 0.3, brightness: 0.35)
            : Color(hex: "F9F6F2")
    }

    private var gridBg: Color {
        let c = hsb
        return colorScheme == .dark
            ? Color(hue: c.h1, saturation: max(c.s1*0.2, 0.04), brightness: 0.2)
            : Color(hue: c.h1, saturation: max(c.s1*0.18, 0.04), brightness: 0.72)
    }
    private var boardBg: Color {
        let c = hsb
        return colorScheme == .dark
            ? Color(hue: c.h1, saturation: c.s1*0.08, brightness: 0.07)
            : Color(hue: c.h1, saturation: c.s1*0.05, brightness: 0.97)
    }
    private var emptyCell: Color {
        let c = hsb
        return colorScheme == .dark
            ? Color(hue: c.h1, saturation: c.s1*0.08, brightness: 0.16)
            : Color(hue: c.h1, saturation: c.s1*0.06, brightness: 0.82)
    }
    private var headerText: Color {
        colorScheme == .dark ? .white.opacity(0.88)
            : Color(hue: hsb.h1, saturation: hsb.s1*0.2, brightness: 0.38)
    }

    private let gap: CGFloat = 8
    private let gridPad: CGFloat = 8
    private let tileRadius: CGFloat = 6

    private var progress: Double {
        guard timePublisher.duration > 0 else { return 0 }
        return min(max(timePublisher.currentTime / timePublisher.duration, 0), 1)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let hPad: CGFloat = 16
            let innerW = w - hPad * 2 - gridPad * 2
            let cell = (innerW - gap * 3) / 4

            ZStack {
                boardBg.ignoresSafeArea()

                RadialGradient(
                    colors: [colorExtractor.dominantColor.opacity(0.1), .clear],
                    center: .init(x: 0.35, y: 0.38), startRadius: 40, endRadius: 320
                ).ignoresSafeArea().allowsHitTesting(false)

                VStack(spacing: 0) {
                    scoreHeader(cell: cell)
                        .padding(.horizontal, hPad)
                        .padding(.top, geo.safeAreaInsets.top > 0 ? 4 : 12)

                    Spacer(minLength: 10)

                    gameBoard(cell: cell)
                        .padding(.horizontal, hPad)
                        .gesture(
                            DragGesture(minimumDistance: 50)
                                .onEnded { value in
                                    let dx = value.translation.width
                                    let dy = value.translation.height
                                    if abs(dx) > abs(dy) {
                                        if dx > 0 { player.previous() } else { player.next() }
                                    } else if dy < 0 {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            showLyrics = true
                                        }
                                    }
                                }
                        )

                    Spacer(minLength: 10)

                    bottomBar.padding(.horizontal, hPad)
                        .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? 4 : 16)
                }

                if showMoreMenu {
                    PlayerMoreMenu(isPresented: $showMoreMenu, isDarkBackground: colorScheme == .dark,
                                   onEQ: { showEQSettings = true }, onTheme: { showThemePicker = true })
                }

                if showLyrics, let song = player.currentSong {
                    lyricsOverlay(song: song, geo: geo)
                }
            }
        }
        .compatFontDesign(nil)
        .onAppear {
            colorExtractor.extract(from: player.currentSong?.coverUrl?.absoluteString)
            currentLayout = Int.random(in: 0..<Self.layouts.count)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { tilesAppeared = true }
            playPulse = player.isPlaying
        }
        .onChange(of: player.currentSong) { _, newSong in
            colorExtractor.extract(from: newSong?.coverUrl?.absoluteString)
            shimmerPhase = -0.5

            // ── Phase 1: 合并 ──
            // 被吸收方块（mode/prev/artist）沿格子滑到吸收方块（like/next/quality）的位置
            merging = true
            animTick += 1

            // ── Phase 2: 分开 ──
            // 切换布局，所有方块从当前格子滑到新格子
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                var next: Int
                repeat { next = Int.random(in: 0..<Self.layouts.count) } while next == currentLayout
                currentLayout = next
                merging = false
                animTick += 1
                withAnimation(.easeInOut(duration: 1.0).delay(0.3)) { shimmerPhase = 1.5 }
            }
        }
        .onChange(of: player.isPlaying) { _, playing in playPulse = playing }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast { PodcastPlaylistPopupView() } else { PlaylistPopupView() }
        }
        .monologueSheet(isPresented: $showQualitySheet, preset: .standard) {
            SoundQualitySheet(
                currentQuality: player.soundQuality, currentQQQuality: player.qqMusicQuality,
                isQQMusic: player.currentSong?.isQQMusic == true,
                onSelectNetease: { q in player.switchQuality(q); showQualitySheet = false },
                onSelectQQ: { q in player.switchQQMusicQuality(q); showQualitySheet = false },
                songMid: player.currentSong?.qqMid, songId: player.currentSong?.id,
                isQishui: player.currentSong?.isQishui == true,
                qishuiTrackId: player.currentSong?.qishuiTrackId,
                onSelectQishui: { info in player.switchQishuiQuality(info); showQualitySheet = false }
            )
        }
        .fullScreenCover(isPresented: $showEQSettings) { NavigationStack { EQSettingsView() } }
        .monologueSheet(isPresented: $showThemePicker, preset: .themePicker) { PlayerThemePickerSheet() }
        .monologueSheet(isPresented: $showComments, preset: .large) {
            if let s = player.currentSong {
                CommentView(resourceId: s.id, resourceType: .song,
                           songName: s.name, artistName: s.artistName, coverUrl: s.coverUrl)
            }
        }
        .monologueSheet(isPresented: $showArtistDetail, preset: .detail) {
            if let s = player.currentSong {
                NavigationStack {
                    if s.isQQMusic, let mid = s.qqArtistMid {
                        QQMusicDetailView(detailType: .artist(mid: mid, name: s.artistName, coverUrl: nil))
                    } else if let aId = s.ar?.first?.id { ArtistDetailView(artistId: aId) }
                }
            }
        }
        .monologueSheet(isPresented: $showDownloadSheet, preset: .compact) {
            if let s = player.currentSong { DownloadQualitySheet(song: s) { showDownloadSheet = false } }
        }
    }
}

// MARK: - 记分板

extension Game2048PlayerLayout {
    private func scoreHeader(cell: CGFloat) -> some View {
        HStack(alignment: .top) {
            Button { dismiss() } label: {
                MonologueSymbolIcon(name: "chevron.down", size: 15, color: headerText.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(gridBg.opacity(0.5)))
            }.buttonStyle(MonologueBouncingButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text("2048").font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [colorExtractor.dominantColor, colorExtractor.secondaryColor],
                        startPoint: .leading, endPoint: .trailing))
                Text("play the music").font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(headerText.opacity(0.4))
            }

            Spacer()

            HStack(spacing: 6) {
                scoreBox(label: "SCORE", value: "\(Int(timePublisher.currentTime))")
                scoreBox(label: "BEST", value: formatTime(timePublisher.duration))
            }

            Button { showMoreMenu.toggle() } label: {
                MonologueIcon(icon: .more, size: 15, color: headerText.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(gridBg.opacity(0.5)))
            }.buttonStyle(MonologueBouncingButtonStyle())
        }
    }

    private func scoreBox(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6)).tracking(0.5)
            Text(value).font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(gridBg))
    }
}

// MARK: - 棋盘（ZStack + offset 定位，支持动态重排）

extension Game2048PlayerLayout {

    private func gameBoard(cell: CGFloat) -> some View {
        let dbl = cell * 2 + gap
        let gridSize = cell * 4 + gap * 3
        let L = layout

        return VStack(spacing: gap) {
            ZStack(alignment: .topLeading) {
                // 空格子底板
                ForEach(0..<4, id: \.self) { row in
                    ForEach(0..<4, id: \.self) { col in
                        RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
                            .fill(emptyCell)
                            .frame(width: cell, height: cell)
                            .offset(x: CGFloat(col) * (cell + gap), y: CGFloat(row) * (cell + gap))
                    }
                }

                // ═══ 模式(2) + 收藏(4) 合并对 ═══
                // 模式：合并时滑到收藏的格子 → 分开时滑到新位置
                modeTile(cell: cell)
                    .offset(offset(merging ? L.like : L.mode, cell: cell))
                    .scaleEffect(merging ? 0.65 : 1.0)
                    .opacity(merging ? 0.4 : 1.0)
                    .zIndex(0)
                    .animation(tileSlide(delay: 0), value: animTick)
                    .tilePopIn(tilesAppeared, delay: 0.04)

                // 收藏：合并时原地脉冲 → 分开时滑到新位置
                likeTile(cell: cell)
                    .offset(offset(L.like, cell: cell))
                    .scaleEffect(merging ? 1.15 : 1.0)
                    .zIndex(1)
                    .animation(tileSlide(delay: 0.03), value: animTick)
                    .tilePopIn(tilesAppeared, delay: 0.08)

                // ═══ 上一首(8) + 下一首(16) 合并对 ═══
                prevTile(cell: cell)
                    .offset(offset(merging ? L.next : L.prev, cell: cell))
                    .scaleEffect(merging ? 0.65 : 1.0)
                    .opacity(merging ? 0.4 : 1.0)
                    .zIndex(0)
                    .animation(tileSlide(delay: 0.06), value: animTick)
                    .tilePopIn(tilesAppeared, delay: 0.12)

                nextTile(cell: cell)
                    .offset(offset(L.next, cell: cell))
                    .scaleEffect(merging ? 1.15 : 1.0)
                    .zIndex(1)
                    .animation(tileSlide(delay: 0.08), value: animTick)
                    .tilePopIn(tilesAppeared, delay: 0.16)

                // ═══ 歌手(32) + 音质(64) 合并对 ═══
                artistTile(cell: cell)
                    .offset(offset(merging ? L.quality : L.artist, cell: cell))
                    .scaleEffect(merging ? 0.65 : 1.0)
                    .opacity(merging ? 0.4 : 1.0)
                    .zIndex(0)
                    .animation(tileSlide(delay: 0.10), value: animTick)
                    .tilePopIn(tilesAppeared, delay: 0.28)

                qualityTile(cell: cell)
                    .offset(offset(L.quality, cell: cell))
                    .scaleEffect(merging ? 1.15 : 1.0)
                    .zIndex(1)
                    .animation(tileSlide(delay: 0.12), value: animTick)
                    .tilePopIn(tilesAppeared, delay: 0.32)

                // ═══ 大方块：合并时不动，分开时滑到新位置 ═══
                songNameTile(w: dbl, h: cell)
                    .offset(offset(L.song, cell: cell))
                    .animation(tileSlide(delay: 0.15), value: animTick)
                    .tilePopIn(tilesAppeared, delay: 0.20)

                lyricsTile(size: dbl)
                    .offset(offset(L.lyrics, cell: cell))
                    .animation(tileSlide(delay: 0.18), value: animTick)
                    .tilePopIn(tilesAppeared, delay: 0.24)

                coverTile(size: dbl)
                    .offset(offset(L.cover, cell: cell))
                    .animation(tileSlide(delay: 0.20), value: animTick)
                    .zIndex(3)
                    .tilePopIn(tilesAppeared, delay: 0)
            }
            .frame(width: gridSize, height: gridSize, alignment: .topLeading)
            .clipped()

            // 进度条
            progressRow(cellW: cell).tilePopIn(tilesAppeared, delay: 0.36)
        }
        .padding(gridPad)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(gridBg))
    }
}

// MARK: - 方块组件

extension Game2048PlayerLayout {

    // ─── 封面 2048 ───

    private func coverTile(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: tileRadius, style: .continuous).fill(tileColor(2048))

            if let url = player.currentSong?.coverUrl?.sized(400) {
                CachedAsyncImage(url: url) { tileColor(2048) }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size - 8, height: size - 8)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            // 半透明播放/暂停按钮
            MonologueIcon(icon: player.isPlaying ? .pause : .play, size: 27, color: .white.opacity(0.85), lineWidth: 2)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

            VStack { Spacer(); HStack { Spacer()
                Text("2048").font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.35)).padding(4)
            }}

            // 切歌闪光
            GeometryReader { geo in
                Rectangle().fill(LinearGradient(
                    stops: [.init(color: .clear, location: 0), .init(color: .white.opacity(0.06), location: 0.35),
                            .init(color: .white.opacity(0.18), location: 0.5),
                            .init(color: .white.opacity(0.06), location: 0.65), .init(color: .clear, location: 1)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 45).rotationEffect(.degrees(25))
                .offset(x: shimmerPhase * geo.size.width * 1.5 - geo.size.width * 0.3)
            }
            .clipShape(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))
            .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .frame(width: size, height: size)
        .shadow(color: tileColor(2048).opacity(0.35), radius: 10)
        .onTapGesture { player.togglePlayPause() }
    }

    // ─── 歌词 256 ───

    private func lyricsTile(size: CGFloat) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showLyrics = true }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: tileRadius, style: .continuous).fill(tileColor(256))

                VStack { HStack {
                    Text("256").font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(tileFg(256).opacity(0.2)).padding(5)
                    Spacer()
                }; Spacer() }

                if let text = lyricVM.currentLineText, !text.isEmpty {
                    Text(text.monologueLyricDisplayText)
                        .font(
                            MonologuePlayerFont.activeFont(
                                size: 14,
                                weight: .bold,
                                fallback: .system(size: 14, weight: .bold, design: .rounded)
                            )
                        )
                        .foregroundColor(tileFg(256)).multilineTextAlignment(.center)
                        .lineLimit(4).padding(10)
                        .id(lyricVM.currentLineIndex)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity), removal: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: lyricVM.currentLineIndex)
                } else {
                    VStack(spacing: 4) {
                        MonologueSymbolIcon(name: "text.quote", size: 21, color: tileFg(256).opacity(0.4))
                        Text("歌词").font(.system(size: 11, weight: .semibold, design: .rounded))
                    }.foregroundColor(tileFg(256).opacity(0.4))
                }

                RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .frame(width: size, height: size)
            .shadow(color: tileColor(256).opacity(0.2), radius: 6)
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }

    // ─── 模式 2 ───
    private func modeTile(cell: CGFloat) -> some View {
        Button(action: { player.switchMode() }) {
            gameTile(value: 2, cell: cell) {
                MonologueIcon(icon: player.mode.monologueIcon, size: 14, color: tileFg(2))
            }
        }.buttonStyle(MonologueBouncingButtonStyle())
    }

    // ─── 收藏 4 ───
    private func likeTile(cell: CGFloat) -> some View {
        let isLiked = player.currentSong.map {
            LikeManager.shared.isLiked(id: $0.id, isQQMusic: $0.isQQMusic)
        } ?? false
        return Button {
            guard let s = player.currentSong else { return }
            HapticManager.shared.medium()
            LikeManager.shared.toggleLike(songId: s.id, isQQMusic: s.isQQMusic, song: s)
        } label: {
            gameTile(value: 4, cell: cell) {
                MonologueIcon(icon: isLiked ? .liked : .like, size: 17, color: isLiked ? .red : tileFg(4), lineWidth: 1.8)
                    .compatSymbolBounce(value: isLiked)
            }
        }.buttonStyle(MonologueBouncingButtonStyle())
    }

    // ─── 上一首 8 ───
    private func prevTile(cell: CGFloat) -> some View {
        Button(action: { player.previous() }) {
            gameTile(value: 8, cell: cell) {
                MonologueIcon(icon: .previous, size: 17, color: tileFg(8), lineWidth: 1.8)
            }
        }.buttonStyle(MonologueBouncingButtonStyle())
    }

    // ─── 下一首 16 ───
    private func nextTile(cell: CGFloat) -> some View {
        Button(action: { player.next() }) {
            gameTile(value: 16, cell: cell) {
                MonologueIcon(icon: .next, size: 17, color: tileFg(16), lineWidth: 1.8)
            }
        }.buttonStyle(MonologueBouncingButtonStyle())
    }

    // ─── 歌名 1024 ───
    private func songNameTile(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: tileRadius, style: .continuous).fill(tileColor(1024))
            Text("1024").font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(tileFg(1024).opacity(0.25)).padding(5)
            Text(player.currentSong?.name ?? "")
                .monologuePlayerDisplayFont(
                    size: 15,
                    weight: .heavy,
                    fallback: .system(size: 15, weight: .heavy, design: .rounded)
                )
                .foregroundColor(tileFg(1024)).lineLimit(2).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 8)
            RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }.frame(width: w, height: h).shadow(color: tileColor(1024).opacity(0.2), radius: 5)
    }

    // ─── 歌手 32 ───
    private func artistTile(cell: CGFloat) -> some View {
        Button { showArtistDetail = true } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: tileRadius, style: .continuous).fill(tileColor(32))
                Text("32").font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(tileFg(32).opacity(0.25)).padding(4)
                Text(player.currentSong?.artistName ?? "")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(tileFg(32)).lineLimit(2).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).padding(4)
            }.frame(width: cell, height: cell)
        }.buttonStyle(MonologueBouncingButtonStyle())
    }

    // ─── 音质 64 ───
    private func qualityTile(cell: CGFloat) -> some View {
        Button { showQualitySheet = true } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: tileRadius, style: .continuous).fill(tileColor(64))
                Text("64").font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(tileFg(64).opacity(0.25)).padding(4)
                VStack(spacing: 2) {
                    MonologueIcon(icon: .waveform, size: 15, color: tileFg(64), lineWidth: 1.8)
                    Text(player.qualityButtonText).font(.system(size: 9, weight: .heavy, design: .rounded))
                }.foregroundColor(tileFg(64)).frame(maxWidth: .infinity, maxHeight: .infinity)
            }.frame(width: cell, height: cell)
        }.buttonStyle(MonologueBouncingButtonStyle())
        .playerQualitySelectionAvailability()
    }

    // ─── 通用方块模板 ───
    private func gameTile<Content: View>(value: Int, cell: CGFloat,
                                          @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: tileRadius, style: .continuous).fill(tileColor(value))
            Text("\(value)").font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundColor(tileFg(value).opacity(0.3)).padding(4)
            content().frame(maxWidth: .infinity, maxHeight: .infinity)
        }.frame(width: cell, height: cell)
    }
}

// MARK: - 进度条

extension Game2048PlayerLayout {
    private func progressRow(cellW: CGFloat) -> some View {
        let fullW = cellW * 4 + gap * 3
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(emptyCell)
                .frame(width: fullW, height: 24)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(colors: [colorExtractor.secondaryColor, colorExtractor.dominantColor],
                                      startPoint: .leading, endPoint: .trailing))
                .frame(width: max(8, fullW * CGFloat(progress)), height: 24)
                .animation(.linear(duration: 0.3), value: progress)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.15)).frame(height: 6)
                        .padding(.horizontal, 4).offset(y: 2)
                }
            HStack {
                Text(formatTime(timePublisher.currentTime)); Spacer()
                Text("512").opacity(0.3); Spacer()
                Text(formatTime(timePublisher.duration))
            }
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundColor(.white).padding(.horizontal, 8).frame(width: fullW)
        }
        .frame(width: fullW, height: 24).contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
            player.seek(to: min(max(v.location.x / fullW, 0), 1) * timePublisher.duration)
        })
    }
}

// MARK: - 底部工具栏

extension Game2048PlayerLayout {
    private var bottomBar: some View {
        HStack(spacing: 10) {
            bottomBtn(icon: "bubble.left", label: "128") { showComments = true }
            if let s = player.currentSong {
                if AppConfig.Features.downloadEnabled {
                    // 下载按钮（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
                    let done = downloadManager.isDownloaded(songId: s.id)
                    bottomBtn(icon: done ? "checkmark.circle.fill" : "arrow.down.circle",
                              label: "64", dim: done) { if !done { showDownloadSheet = true } }.disabled(done)
                } else {
                    // 沉浸模式按钮 — 占用原下载按钮的位置
                    bottomBtn(icon: "tv", label: "64") { CinemaModeController.shared.present() }
                }
            }
            bottomBtn(icon: "list.bullet", label: "32") { showPlaylist = true }
            bottomBtn(icon: "paintpalette", label: "16") { showThemePicker = true }
            Spacer()
            HStack(spacing: 3) {
                MonologueSymbolIcon(name: "hand.draw", size: 11, color: headerText.opacity(0.25))
                Text("滑动切歌").font(.system(size: 10, weight: .medium, design: .rounded))
            }.foregroundColor(headerText.opacity(0.25))
        }
    }

    private func bottomBtn(icon: String, label: String, dim: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                MonologueSymbolIcon(name: icon, size: 14, color: dim ? headerText.opacity(0.2) : headerText.opacity(0.6))
                Text(label).font(.system(size: 8, weight: .heavy, design: .rounded)).opacity(0.45)
            }
            .foregroundColor(dim ? headerText.opacity(0.2) : headerText.opacity(0.6))
            .frame(width: 40, height: 40)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(gridBg.opacity(0.35)))
        }.buttonStyle(MonologueBouncingButtonStyle())
    }
}

// MARK: - 歌词覆盖层 8192

extension Game2048PlayerLayout {
    private func lyricsOverlay(song: Song, geo: GeometryProxy) -> some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showLyrics = false }
                }

            VStack(spacing: 0) {
                HStack {
                    Text("8192").font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "F9F6F2").opacity(0.55))
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showLyrics = false }
                    } label: {
                        MonologueIcon(icon: .close, size: 14, color: .white.opacity(0.6), lineWidth: 1.6)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)

                LyricsView(song: song) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showLyrics = false }
                }
            }
            .frame(maxWidth: geo.size.width - 32).frame(maxHeight: geo.size.height * 0.55)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hue: hsb.h1, saturation: hsb.s1 * 0.25, brightness: 0.13))
                    .shadow(color: colorExtractor.dominantColor.opacity(0.15), radius: 16)
            )
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(colorExtractor.dominantColor.opacity(0.2), lineWidth: 1.5))
            .transition(.scale(scale: 0.3, anchor: .center).combined(with: .opacity))
        }
    }
}

// MARK: - 工具

extension Game2048PlayerLayout {
    private func formatTime(_ s: Double) -> String {
        guard !s.isNaN && !s.isInfinite else { return "00:00" }
        let t = Int(s); return String(format: "%02d:%02d", t / 60, t % 60)
    }
}

private extension View {
    func tilePopIn(_ appeared: Bool, delay: Double) -> some View {
        self.scaleEffect(appeared ? 1 : 0.01).opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.65).delay(delay), value: appeared)
    }
}
