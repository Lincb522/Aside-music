//  大字报风格播放器 — Brutalism + Exaggerated Minimalism
//  核心：巨型文字铺满屏幕、粗野主义排版、控制融入文字间
//  无封面、无圆角、无渐变、纯黑白+红色强调、极端留白
//  设计系统：font-weight 900, letter-spacing 紧凑, 0px圆角, 粗边框

import SwiftUI
import FFmpegSwiftSDK

struct PosterPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var player = PlayerManager.shared
    private let timePublisher = PlaybackTimePublisher.shared
    
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showComments = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showMoreMenu = false
    @State private var showArtistDetail = false
    @State private var showLyrics = false
    @State private var isAppeared = false
    
    // 粗野主义配色 — 近黑/纯白 + 单一红色强调
    private var bg: Color { colorScheme == .dark ? Color(hex: "0A0A0E") : .white }
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
                            .padding(.top, DeviceLayout.playerHeaderTopPadding)
                            .zIndex(1)
                        
                        lyricsBody
                            .frame(maxHeight: .infinity)
                        
                        progressLine(width: geo.size.width)
                    }
                    .frame(width: geo.size.width, alignment: .center)
                    .transition(.opacity)
                } else {
                    // 大字报主体
                    VStack(spacing: 0) {
                        posterTopBar
                            .padding(.top, DeviceLayout.playerHeaderTopPadding)
                            .zIndex(1)
                        
                        bigTitleArea(geo: geo)
                            .frame(maxHeight: .infinity)
                        
                        controlStrip
                            .zIndex(1)
                        
                        progressLine(width: geo.size.width)
                            .padding(.bottom, DeviceLayout.playerBottomPadding)
                    }
                    .frame(width: geo.size.width, alignment: .center)
                    .transition(.opacity)
                }
            }
            .playerMoreMenuOverlay { anchorFrame in
                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        anchorFrame: anchorFrame,
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
        }
        .monoSheet(isPresented: $showPlaylist, preset: .standard){
            PlaylistPopupView()
        }
        .monoSheet(isPresented: $showQualitySheet, preset: .standard){
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
        .fullScreenCover(isPresented: $showEQSettings) {
            NavigationStack { MonoAudioCenterView() }
        }
        .monoSheet(isPresented: $showThemePicker, preset: .themePicker){
            PlayerThemePickerSheet()
        }
        .monoSheet(isPresented: $showComments, preset: .large){
            if let song = player.currentSong {
                CommentView(song: song)
                
            }
        }
        .monoSheet(isPresented: $showArtistDetail, preset: .detail){
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

// MARK: - 大字报顶栏
extension PosterPlayerLayout {
    
    /// 顶栏 — 无边框，纯文字风格，左中右固定三栏布局
    private var posterTopBar: some View {
        ZStack {
            // 中间 — 音质 + 流信息，绝对居中
            HStack(spacing: 8) {
                Button(action: { showQualitySheet = true }) {
                    Text(player.qualityButtonText)
                        .font(.custom(posterFont, size: 12))
                        .foregroundColor(fg)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .monoGlass(cornerRadius: 0)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MonoBouncingButtonStyle())
                .playerQualitySelectionAvailability()
                
                if let info = player.streamInfo {
                    Text(streamInfoText(info))
                        .font(.custom(posterFont, size: 10))
                        .foregroundColor(muted)
                }
            }
            
            // 左右两侧 — 固定在两端
            HStack {
                Button(action: { dismiss() }) {
                    Text("返回")
                        .font(.custom(posterFont, size: 16))
                        .foregroundColor(fg)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MonoBouncingButtonStyle())
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.1)) { showMoreMenu.toggle() }
                }) {
                    Text("更多")
                        .font(.custom(posterFont, size: 16))
                        .foregroundColor(fg)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MonoBouncingButtonStyle())
                .playerMoreMenuAnchor()
            }
        }
        .padding(.horizontal, DeviceLayout.usesExpandedLayout ? 24 : 16)
        .padding(.bottom, 8)
    }
}

// MARK: - 大字报主体 — 巨型文字铺满
extension PosterPlayerLayout {
    
    /// 歌名巨型排版 — 每个字尽可能大，撑满可用空间
    private func bigTitleArea(geo: GeometryProxy) -> some View {
        let songName = player.currentSong?.name ?? "—"
        let artistName = player.currentSong?.artistName ?? ""
        
        return VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapWithHaptic {
                    withAnimation(.easeInOut(duration: 0.15)) { showLyrics = true }
                }
            
            // 巨型歌名
            Text(songName)
                .monoPlayerDisplayFont(
                    size: 72,
                    weight: .bold,
                    fallback: .custom(posterFont, size: 72)
                )
                .foregroundColor(fg)
                .tracking(-3)
                .lineSpacing(-8)
                .minimumScaleFactor(0.3)
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapWithHaptic {
                    withAnimation(.easeInOut(duration: 0.15)) { showLyrics = true }
                }
            
            // 分隔粗线
            Rectangle()
                .fill(accent)
                .frame(height: 6)
                .padding(.vertical, 12)
            
            // 歌手名
            Button { showArtistDetail = true } label: {
                Text(artistName.uppercased())
                    .font(.custom(posterFont, size: 24))
                    .foregroundColor(muted)
                    .tracking(6)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // 播放/暂停
            HStack(spacing: 16) {
                Button(action: { player.togglePlayPause() }) {
                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: fg))
                            .frame(width: 44, height: 40)
                    } else {
                        Text(player.isPlaying ? String(localized: "暂停") : String(localized: "播放"))
                            .font(.custom(posterFont, size: 14))
                            .foregroundColor(bg)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(accent)
                            .contentShape(Rectangle())
                    }
                }
                .buttonStyle(MonoBouncingButtonStyle())
                
                // 时间
                PlaybackTimeReader { _, _ in
                    Text("\(Text(formatTime(isDragging ? dragValue : timePublisher.currentTime)).font(.custom(posterFont, size: 32)).foregroundColor(fg))\(Text(" / " + formatTime(timePublisher.duration)).font(.custom(posterFont, size: 16)).foregroundColor(muted))")
                }
            }
            .padding(.top, 20)
            
            Spacer()
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapWithHaptic {
                    withAnimation(.easeInOut(duration: 0.15)) { showLyrics = true }
                }
        }
        .padding(.horizontal, DeviceLayout.usesExpandedLayout ? 24 : 16)
        .background {
            if player.dynamicCoverUrl?.isEmpty == false {
                ZStack {
                    DynamicArtworkOverlay(cornerRadius: 0)
                        .opacity(colorScheme == .dark ? 0.28 : 0.16)
                    bg.opacity(colorScheme == .dark ? 0.58 : 0.72)
                }
                .clipped()
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - 控制条 — 无边框风格
extension PosterPlayerLayout {
    
    /// 底部控制 — 精简五个核心按钮，均匀分布
    private var controlStrip: some View {
        HStack {
            // 播放模式
            Button(action: { player.switchMode() }) {
                MonoIcon(icon: player.mode.monoIcon, size: 22, color: fg)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MonoBouncingButtonStyle())
            
            Spacer()
            
            // 上一首
            Button(action: { player.previous() }) {
                MonoIcon(icon: .previous, size: 24, color: fg)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MonoBouncingButtonStyle())
            
            Spacer()
            
            // 喜欢
            if let song = player.currentSong {
                LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 22, activeColor: accent, inactiveColor: fg)
            }
            
            Spacer()
            
            // 下一首
            Button(action: { player.next() }) {
                MonoIcon(icon: .next, size: 24, color: fg)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MonoBouncingButtonStyle())
            
            Spacer()
            
            // 播放列表
            Button(action: { showPlaylist = true }) {
                MonoIcon(icon: .list, size: 22, color: fg)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MonoBouncingButtonStyle())
        }
        .frame(height: 48)
        .padding(.horizontal, DeviceLayout.usesExpandedLayout ? 24 : 16)
        .padding(.bottom, 8)
    }
}

// MARK: - 进度线
extension PosterPlayerLayout {
    
    /// 底部进度线 — 更粗，贴合手写风格
    private func progressLine(width: CGFloat) -> some View {
        PlaybackTimeReader { _, _ in
            let progress = timePublisher.duration > 0
                ? (isDragging ? dragValue : timePublisher.currentTime) / timePublisher.duration
                : 0

            return GeometryReader { barGeo in
                let barWidth = barGeo.size.width
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(border)
                        .frame(height: 6)

                    Rectangle()
                        .fill(accent)
                        .frame(width: max(6, barWidth * CGFloat(min(max(progress, 0), 1))), height: 6)
                }
                .contentShape(Rectangle().inset(by: -20))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dragValue = min(max(value.location.x / barWidth, 0), 1) * timePublisher.duration
                        }
                        .onEnded { value in
                            isDragging = false
                            player.seek(to: min(max(value.location.x / barWidth, 0), 1) * timePublisher.duration)
                        }
                )
            }
            .frame(height: 6)
            .padding(.horizontal, DeviceLayout.usesExpandedLayout ? 24 : 16)
        }
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
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MonoBouncingButtonStyle())
            
            Spacer()
            
            // 歌名 — 使用字魂字体
            Text(player.currentSong?.name ?? "")
                .monoPlayerDisplayFont(
                    size: 14,
                    weight: .semibold,
                    fallback: .custom(posterFont, size: 14)
                )
                .foregroundColor(fg)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.1)) { showMoreMenu.toggle() }
            }) {
                Text("更多")
                    .font(.custom(posterFont, size: 16))
                    .foregroundColor(fg)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .playerMoreMenuAnchor()
        }
        .padding(.horizontal, DeviceLayout.usesExpandedLayout ? 24 : 16)
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
