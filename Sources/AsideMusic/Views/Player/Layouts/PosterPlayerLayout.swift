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
    
    /// 顶栏 — 粗野主义：粗边框按钮、无圆角
    private var posterTopBar: some View {
        HStack(spacing: 0) {
            // 返回
            Button(action: { dismiss() }) {
                Rectangle()
                    .stroke(fg, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .overlay(
                        AsideIcon(icon: .chevronRight, size: 18, color: fg)
                            .rotationEffect(.degrees(90))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            Spacer()
            
            // 音质 — 粗体标签
            Button(action: { showQualitySheet = true }) {
                Text(player.qualityButtonText)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(bg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(fg)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            if let info = player.streamInfo {
                Text(streamInfoText(info))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(muted)
                    .padding(.leading, 8)
            }
            
            Spacer()
            
            // 更多
            Button(action: {
                withAnimation(.easeInOut(duration: 0.1)) { showMoreMenu.toggle() }
            }) {
                Rectangle()
                    .stroke(fg, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .overlay(
                        AsideIcon(icon: .more, size: 18, color: fg)
                    )
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
            
            // 巨型歌名 — 自适应字号撑满宽度（点击切换歌词）
            Text(songName)
                .font(.system(size: 72, weight: .black, design: .default))
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
            
            // 分隔粗线
            Rectangle()
                .fill(accent)
                .frame(height: 4)
                .frame(maxWidth: availW)
                .padding(.vertical, 16)
            
            // 歌手名 — 点击切换歌词
            Text(artistName.uppercased())
                .font(.system(size: 24, weight: .bold, design: .monospaced))
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
                        Text(player.isPlaying ? "PAUSE" : "PLAY")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
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
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(fg)
                +
                Text(" / " + formatTime(player.duration))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
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

// MARK: - 控制条 — 粗野主义风格
extension PosterPlayerLayout {
    
    /// 底部控制 — 一行图标，粗边框分隔
    private var controlStrip: some View {
        HStack(spacing: 0) {
            // 播放模式
            controlCell {
                Button(action: { player.switchMode() }) {
                    AsideIcon(icon: player.mode.asideIcon, size: 18, color: fg)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
            
            divider
            
            // 上一首
            controlCell {
                Button(action: { player.previous() }) {
                    AsideIcon(icon: .previous, size: 22, color: fg)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
            
            divider
            
            // 喜欢
            controlCell {
                if let songId = player.currentSong?.id {
                    LikeButton(songId: songId, size: 20, activeColor: accent, inactiveColor: fg)
                }
            }
            
            divider
            
            // 下一首
            controlCell {
                Button(action: { player.next() }) {
                    AsideIcon(icon: .next, size: 22, color: fg)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
            
            divider
            
            // 评论
            controlCell {
                Button(action: { showComments = true }) {
                    AsideIcon(icon: .comment, size: 18, color: fg, lineWidth: 1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
            
            divider
            
            // 下载
            controlCell {
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
                            icon: .playerDownload, size: 18,
                            color: downloadManager.isDownloaded(songId: song.id) ? accent : fg,
                            lineWidth: 1.5
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .disabled(downloadManager.isDownloaded(songId: song.id))
                    .buttonStyle(AsideBouncingButtonStyle())
                }
            }
            
            divider
            
            // 播放列表
            controlCell {
                Button(action: { showPlaylist = true }) {
                    AsideIcon(icon: .list, size: 18, color: fg)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
        }
        .frame(height: 48)
        .overlay(
            Rectangle().stroke(fg, lineWidth: 2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    /// 单个控制格子
    private func controlCell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// 竖线分隔
    private var divider: some View {
        Rectangle()
            .fill(fg)
            .frame(width: 2)
    }
}

// MARK: - 进度线
extension PosterPlayerLayout {
    
    /// 底部进度线 — 全宽细线，红色已播放
    private func progressLine(width: CGFloat) -> some View {
        let progress = player.duration > 0
            ? (isDragging ? dragValue : player.currentTime) / player.duration
            : 0
        
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(border)
                    .frame(height: 3)
                
                Rectangle()
                    .fill(accent)
                    .frame(width: max(3, geo.size.width * CGFloat(min(max(progress, 0), 1))), height: 3)
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
        .frame(height: 3)
        .padding(.horizontal, 16)
    }
}

// MARK: - 歌词模式
extension PosterPlayerLayout {
    
    /// 歌词顶栏
    private var lyricsTopBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Rectangle()
                    .stroke(fg, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .overlay(
                        AsideIcon(icon: .chevronRight, size: 18, color: fg)
                            .rotationEffect(.degrees(90))
                    )
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            Spacer()
            
            // 歌名 — 粗体
            Text(player.currentSong?.name ?? "")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(fg)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.1)) { showMoreMenu.toggle() }
            }) {
                Rectangle()
                    .stroke(fg, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .overlay(
                        AsideIcon(icon: .more, size: 18, color: fg)
                    )
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
                Text("NO LYRICS")
                    .font(.system(size: 48, weight: .black, design: .monospaced))
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
