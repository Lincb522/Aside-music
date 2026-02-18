//
//  PosterPlayerLayout.swift
//  AsideMusic
//
//  大字报风格播放器 — Brutalism + Exaggerated Minimalism
//  核心：巨型文字铺满屏幕、粗野主义排版、控制融入文字间
//  无封面、无圆角、无渐变、纯黑白+红色强调、极端留白
//  设计系统：font-weight 900, letter-spacing 紧凑, 0px圆角, 粗边框
//

import SwiftUI
import FFmpegSwiftSDK

struct PosterPlayerLayout: View {
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
    @State private var showLyrics = false
    @State private var isAppeared = false
    
    // 粗野主义配色 — 纯黑白 + 单一红色强调
    private var bg: Color { colorScheme == .dark ? .black : .white }
    private var fg: Color { colorScheme == .dark ? .white : .black }
    private var accent: Color { Color(hex: "FF0000") }
    private var muted: Color { fg.opacity(0.25) }
    private var border: Color { fg.opacity(0.15) }
    
    // 字魂半天云魅黑手书字体
    private let posterFont = "zihunbantianyunmeiheishoushu"
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                bg.ignoresSafeArea()
                
                if showLyrics {
                    // 歌词模式 — 点击返回大字报
                    VStack(spacing: 0) {
                        lyricsTopBar
                            .padding(.top, DeviceLayout.headerTopPadding)
                            .zIndex(1)
                        
                        lyricsBody
                            .frame(maxHeight: .infinity)
                        
                        progressLine(width: geo.size.width)
                    }
                    .transition(.opacity)
                } else {
                    // 大字报主体
                    VStack(spacing: 0) {
                        posterTopBar
                            .padding(.top, DeviceLayout.headerTopPadding)
                            .zIndex(1)
                        
                        bigTitleArea(geo: geo)
                            .frame(maxHeight: .infinity)
                        
                        controlStrip
                            .zIndex(1)
                        
                        progressLine(width: geo.size.width)
                            .padding(.bottom, DeviceLayout.playerBottomPadding)
                    }
                    .transition(.opacity)
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
            .animation(.easeInOut(duration: 0.15), value: showLyrics)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) { isAppeared = true }
            if let song = player.currentSong, lyricVM.currentSongId != song.id {
                lyricVM.fetchLyrics(for: song.id)
            }
        }
        .sheet(isPresented: $showPlaylist) {
            PlaylistPopupView().presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQualitySheet) {
            SoundQualitySheet(
                currentQuality: player.soundQuality, currentKugouQuality: player.kugouQuality,
                currentQQQuality: player.qqMusicQuality,
                isUnblocked: player.isCurrentSongUnblocked,
                isQQMusic: player.currentSong?.isQQMusic == true,
                onSelectNetease: { q in player.switchQuality(q); showQualitySheet = false },
                onSelectKugou: { q in player.switchKugouQuality(q); showQualitySheet = false },
                onSelectQQ: { q in player.switchQQMusicQuality(q); showQualitySheet = false }
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

// MARK: - 大字报顶栏
extension PosterPlayerLayout {
    
    /// 顶栏 — 无边框，纯文字风格
    private var posterTopBar: some View {
        HStack(spacing: 0) {
            // 返回 — 纯文字
            Button(action: { dismiss() }) {
                Text("返回")
                    .font(.custom(posterFont, size: 16))
                    .foregroundColor(fg)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            Spacer()
            
            // 音质 — 使用字魂字体
            Button(action: { showQualitySheet = true }) {
                Text(player.qualityButtonText)
                    .font(.custom(posterFont, size: 12))
                    .foregroundColor(bg)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(fg)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            if let info = player.streamInfo {
                Text(streamInfoText(info))
                    .font(.custom(posterFont, size: 10))
                    .foregroundColor(muted)
                    .padding(.leading, 8)
            }
            
            Spacer()
            
            // 更多 — 纯文字
            Button(action: {
                withAnimation(.easeInOut(duration: 0.1)) { showMoreMenu.toggle() }
            }) {
                Text("更多")
                    .font(.custom(posterFont, size: 16))
                    .foregroundColor(fg)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - 大字报主体 — 巨型文字铺满
extension PosterPlayerLayout {
    
    /// 歌名巨型排版 — 每个字尽可能大，撑满可用空间
    private func bigTitleArea(geo: GeometryProxy) -> some View {
        let songName = player.currentSong?.name ?? "—"
        let artistName = player.currentSong?.artistName ?? ""
        let availW = geo.size.width - 32
        
        return VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) { showLyrics = true }
                }
            
            // 巨型歌名 — 使用字魂半天云魅黑手书字体（点击切换歌词）
            Text(songName)
                .font(.custom(posterFont, size: 72))
                .foregroundColor(fg)
                .tracking(-3)
                .lineSpacing(-8)
                .minimumScaleFactor(0.3)
                .lineLimit(5)
                .frame(maxWidth: availW, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) { showLyrics = true }
                }
            
            // 分隔粗线 — 手写风格，更粗更有力
            Rectangle()
                .fill(accent)
                .frame(height: 6)
                .frame(maxWidth: availW)
                .padding(.vertical, 12)
            
            // 歌手名 — 使用字魂字体，点击切换歌词
            Text(artistName.uppercased())
                .font(.custom(posterFont, size: 24))
                .foregroundColor(muted)
                .tracking(6)
                .lineLimit(1)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) { showLyrics = true }
                }
            
            // 播放/暂停 — 嵌在文字区域内，用文字表达
            HStack(spacing: 16) {
                Button(action: { player.togglePlayPause() }) {
                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: fg))
                            .frame(width: 44, height: 40)
                    } else {
                        Text(player.isPlaying ? "暂停" : "播放")
                            .font(.custom(posterFont, size: 14))
                            .foregroundColor(bg)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(accent)
                            .contentShape(Rectangle())
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle())
                
                // 时间
                Text(formatTime(isDragging ? dragValue : player.currentTime))
                    .font(.custom(posterFont, size: 32))
                    .foregroundColor(fg)
                +
                Text(" / " + formatTime(player.duration))
                    .font(.custom(posterFont, size: 16))
                    .foregroundColor(muted)
            }
            .padding(.top, 20)
            
            Spacer()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) { showLyrics = true }
                }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - 控制条 — 无边框风格
extension PosterPlayerLayout {
    
    /// 底部控制 — 一行图标，无边框
    private var controlStrip: some View {
        HStack(spacing: 24) {
            // 播放模式
            Button(action: { player.switchMode() }) {
                AsideIcon(icon: player.mode.asideIcon, size: 22, color: fg)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            // 上一首
            Button(action: { player.previous() }) {
                AsideIcon(icon: .previous, size: 24, color: fg)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            // 喜欢
            if let songId = player.currentSong?.id {
                LikeButton(songId: songId, size: 22, activeColor: accent, inactiveColor: fg)
            }
            
            // 下一首
            Button(action: { player.next() }) {
                AsideIcon(icon: .next, size: 24, color: fg)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            // 评论
            Button(action: { showComments = true }) {
                AsideIcon(icon: .comment, size: 22, color: fg, lineWidth: 1.5)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            // 下载
            if let song = player.currentSong {
                Button(action: {
                    if !downloadManager.isDownloaded(songId: song.id) {
                        if song.isQQMusic {
                            downloadManager.downloadQQ(song: song, quality: player.qqMusicQuality)
                        } else {
                            downloadManager.download(song: song, quality: player.soundQuality)
                        }
                    }
                }) {
                    AsideIcon(
                        icon: .playerDownload, size: 22,
                        color: downloadManager.isDownloaded(songId: song.id) ? accent : fg,
                        lineWidth: 1.5
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .disabled(downloadManager.isDownloaded(songId: song.id))
                .buttonStyle(AsideBouncingButtonStyle())
            }
            
            // 播放列表
            Button(action: { showPlaylist = true }) {
                AsideIcon(icon: .list, size: 22, color: fg)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .frame(height: 48)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - 进度线
extension PosterPlayerLayout {
    
    /// 底部进度线 — 更粗，贴合手写风格
    private func progressLine(width: CGFloat) -> some View {
        let progress = player.duration > 0
            ? (isDragging ? dragValue : player.currentTime) / player.duration
            : 0
        
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(border)
                    .frame(height: 6)
                
                Rectangle()
                    .fill(accent)
                    .frame(width: max(6, geo.size.width * CGFloat(min(max(progress, 0), 1))), height: 6)
            }
            .contentShape(Rectangle().inset(by: -20))
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
        .frame(height: 6)
        .padding(.horizontal, 16)
    }
}

// MARK: - 歌词模式
extension PosterPlayerLayout {
    
    /// 歌词顶栏 — 无边框，纯文字风格
    private var lyricsTopBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Text("返回")
                    .font(.custom(posterFont, size: 16))
                    .foregroundColor(fg)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            Spacer()
            
            // 歌名 — 使用字魂字体
            Text(player.currentSong?.name ?? "")
                .font(.custom(posterFont, size: 14))
                .foregroundColor(fg)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.1)) { showMoreMenu.toggle() }
            }) {
                Text("更多")
                    .font(.custom(posterFont, size: 16))
                    .foregroundColor(fg)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    /// 歌词主体
    private var lyricsBody: some View {
        ZStack {
            if let song = player.currentSong {
                LyricsView(song: song, onBackgroundTap: {
                    withAnimation(.easeInOut(duration: 0.15)) { showLyrics = false }
                })
            } else {
                Text("暂无歌词")
                    .font(.custom(posterFont, size: 48))
                    .foregroundColor(muted)
            }
        }
    }
}

// MARK: - 辅助方法
extension PosterPlayerLayout {
    
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
