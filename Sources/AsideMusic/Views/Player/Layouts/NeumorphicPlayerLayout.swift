//
//  NeumorphicPlayerLayout.swift
//  AsideMusic
//
//  新拟物化播放器布局
//  使用通用 AsideBackground 弥散背景 + 半透明新拟物控件
//

import SwiftUI
import FFmpegSwiftSDK

struct NeumorphicPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared
    
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showLyrics = false
    @State private var showComments = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showMoreMenu = false
    @State private var isAppeared = false
    
    // 新拟物配色 — 适配弥散背景的半透明色
    private var surfaceColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.white.opacity(0.55)
    }
    private var raisedColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.09)
            : Color.white.opacity(0.7)
    }
    private var darkShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.12)
    }
    private var lightShadow: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.7)
    }
    private var textColor: Color { .asideTextPrimary }
    private var secondaryTextColor: Color { .asideTextSecondary }
    
    var body: some View {
        GeometryReader { geo in
            let coverSize = min(geo.size.width * 0.65, 280)
            
            ZStack {
                // 通用弥散背景
                AsideBackground().ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 顶部导航
                    headerBar
                        .padding(.top, DeviceLayout.headerTopPadding)
                        .padding(.bottom, 24)
                    
                    // 中间区域
                    ZStack {
                        // 歌词视图
                        if let song = player.currentSong {
                            LyricsView(song: song, onBackgroundTap: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showLyrics = false
                                }
                            })
                            .opacity(showLyrics ? 1 : 0)
                        }

                        // 封面 + 歌曲信息
                        VStack(spacing: 32) {
                            Spacer()
                            neumorphicCover(size: coverSize)
                            songInfoSection
                            Spacer()
                        }
                        .opacity(showLyrics ? 0 : 1)
                        .onTapWithHaptic {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showLyrics = true
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showLyrics)
                    
                    // 底部控制区域
                    VStack(spacing: 24) {
                        neumorphicProgressBar
                        controlsSection
                        additionalButtons
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
                    .padding(.bottom, DeviceLayout.playerBottomPadding)
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
            .scaleEffect(isAppeared ? 1 : 0.96)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { isAppeared = true }
            if let song = player.currentSong, lyricVM.currentSongId != song.id {
                if song.isQQMusic, let mid = song.qqMid {
                    lyricVM.fetchQQLyrics(mid: mid, songId: song.id)
                } else {
                    lyricVM.fetchLyrics(for: song.id)
                }
            }
        }
        .sheet(isPresented: $showPlaylist) {
            PlaylistPopupView().presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQualitySheet) {
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentKugouQuality: player.kugouQuality,
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

// MARK: - 新拟物化组件（适配弥散背景）
extension NeumorphicPlayerLayout {
    
    // MARK: 顶部导航
    private var headerBar: some View {
        HStack {
            neumorphicButton(size: 44) {
                dismiss()
            } content: {
                AsideIcon(icon: .chevronRight, size: 16, color: secondaryTextColor)
                    .rotationEffect(.degrees(90))
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(LocalizedStringKey("player_now_playing"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(secondaryTextColor)
                    .tracking(1)
                
                if let info = player.streamInfo {
                    Text(streamInfoText(info))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(secondaryTextColor.opacity(0.6))
                }
            }
            
            Spacer()
            
            neumorphicButton(size: 44) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { showMoreMenu.toggle() }
            } content: {
                AsideIcon(icon: .more, size: 18, color: secondaryTextColor)
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: 凸起封面 — 半透明材质容器
    private func neumorphicCover(size: CGFloat) -> some View {
        ZStack {
            // 外层凸起容器
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.clear)
                .asideGlass(cornerRadius: 32)
                .frame(width: size + 24, height: size + 24)
                .shadow(color: darkShadow, radius: 15, x: 10, y: 10)
                .shadow(color: lightShadow, radius: 15, x: -10, y: -10)
            
            // 内层凹陷区域
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.clear)
                .asideGlass(cornerRadius: 24)
                .frame(width: size + 8, height: size + 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: colorScheme == .dark
                                    ? [Color.white.opacity(0.08), Color.black.opacity(0.2)]
                                    : [Color.white.opacity(0.8), Color.black.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: darkShadow, radius: 6, x: 4, y: 4)
                .shadow(color: lightShadow, radius: 6, x: -4, y: -4)
            
            // 封面图片
            if let song = player.currentSong {
                CachedAsyncImage(url: song.coverUrl?.sized(800)) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(surfaceColor)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(surfaceColor)
                    .frame(width: size, height: size)
                    .overlay(
                        AsideIcon(icon: .musicNote, size: 60, color: secondaryTextColor)
                    )
            }
        }
    }
    
    // MARK: 歌曲信息
    private var songInfoSection: some View {
        VStack(spacing: 8) {
            Text(player.currentSong?.name ?? "")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
                .lineLimit(1)
            
            HStack(spacing: 12) {
                Text(player.currentSong?.artistName ?? "")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(secondaryTextColor)
                    .lineLimit(1)
                
                Button(action: { showQualitySheet = true }) {
                    Text(player.qualityButtonText)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(secondaryTextColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(surfaceColor)
                                .shadow(color: darkShadow, radius: 2, x: 1, y: 1)
                                .shadow(color: lightShadow, radius: 2, x: -1, y: -1)
                        )
                }
            }
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: 凹陷进度条
    private var neumorphicProgressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let progress = player.duration > 0 ? (isDragging ? dragValue : player.currentTime) / player.duration : 0
                
                ZStack(alignment: .leading) {
                    // 凹陷轨道 — 半透明
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.clear)
                        .asideGlass(cornerRadius: 6)
                        .frame(height: 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    LinearGradient(
                                        colors: colorScheme == .dark
                                            ? [Color.black.opacity(0.4), Color.white.opacity(0.04)]
                                            : [Color.black.opacity(0.08), Color.white.opacity(0.5)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    // 进度填充
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [textColor.opacity(0.35), textColor.opacity(0.15)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(12, geo.size.width * CGFloat(min(max(progress, 0), 1))), height: 10)
                        .padding(.horizontal, 1)
                    
                    // 拖动手柄（凸起）
                    Circle()
                        .fill(Color.clear)
                        .asideGlassCircle()
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle().stroke(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.1)
                                    : Color.white.opacity(0.8),
                                lineWidth: 0.5
                            )
                        )
                        .shadow(color: darkShadow, radius: 4, x: 3, y: 3)
                        .shadow(color: lightShadow, radius: 4, x: -3, y: -3)
                        .offset(x: max(0, min(geo.size.width - 20, geo.size.width * CGFloat(progress) - 10)))
                }
                .contentShape(Rectangle())
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
            .frame(height: 20)
            
            HStack {
                Text(formatTime(isDragging ? dragValue : player.currentTime))
                Spacer()
                Text(formatTime(player.duration))
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(secondaryTextColor)
        }
    }
    
    // MARK: 控制按钮
    private var controlsSection: some View {
        HStack(spacing: 0) {
            neumorphicButton(size: 44) {
                player.switchMode()
            } content: {
                AsideIcon(icon: player.mode.asideIcon, size: 20, color: secondaryTextColor)
            }
            
            Spacer()
            
            neumorphicButton(size: 56) {
                player.previous()
            } content: {
                AsideIcon(icon: .previous, size: 26, color: textColor)
            }
            
            Spacer()
            
            neumorphicPlayButton
            
            Spacer()
            
            neumorphicButton(size: 56) {
                player.next()
            } content: {
                AsideIcon(icon: .next, size: 26, color: textColor)
            }
            
            Spacer()
            
            neumorphicButton(size: 44) {
                showPlaylist = true
            } content: {
                AsideIcon(icon: .list, size: 20, color: secondaryTextColor)
            }
        }
    }
    
    // MARK: 播放按钮
    private var neumorphicPlayButton: some View {
        Button(action: { player.togglePlayPause() }) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .asideGlassCircle()
                    .frame(width: 76, height: 76)
                    .shadow(color: darkShadow, radius: 10, x: 8, y: 8)
                    .shadow(color: lightShadow, radius: 10, x: -8, y: -8)
                
                Circle()
                    .fill(Color.clear)
                    .asideGlassCircle()
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: colorScheme == .dark
                                        ? [Color.white.opacity(0.1), Color.black.opacity(0.3)]
                                        : [Color.white.opacity(0.8), Color.black.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                if player.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(1.2)
                } else {
                    AsideIcon(icon: player.isPlaying ? .pause : .play, size: 30, color: textColor)
                }
            }
        }
        .buttonStyle(NeumorphicButtonStyle(bgColor: raisedColor, darkShadow: darkShadow, lightShadow: lightShadow))
    }
    
    // MARK: 附加按钮
    private var additionalButtons: some View {
        HStack(spacing: 0) {
            if let song = player.currentSong {
                LikeButton(songId: song.id, isQQMusic: song.isQQMusic, size: 22, activeColor: .red, inactiveColor: secondaryTextColor)
                    .frame(width: 44)
            } else {
                Color.clear.frame(width: 44)
            }
            
            Spacer()
            
            neumorphicButton(size: 40) {
                showComments = true
            } content: {
                AsideIcon(icon: .comment, size: 18, color: secondaryTextColor, lineWidth: 1.4)
            }
            
            Spacer()
            
            if let song = player.currentSong {
                neumorphicButton(size: 40) {
                    if !downloadManager.isDownloaded(songId: song.id) {
                        if song.isQQMusic {
                            downloadManager.downloadQQ(song: song, quality: player.qqMusicQuality)
                        } else {
                            downloadManager.download(song: song, quality: player.soundQuality)
                        }
                    }
                } content: {
                    AsideIcon(
                        icon: .playerDownload, size: 18,
                        color: downloadManager.isDownloaded(songId: song.id) ? textColor : secondaryTextColor,
                        lineWidth: 1.4
                    )
                }
                .disabled(downloadManager.isDownloaded(songId: song.id))
            }
            
            Spacer()
            
            Color.clear.frame(width: 44)
        }
    }
    
    // MARK: 通用凸起按钮 — 半透明材质
    private func neumorphicButton<Content: View>(
        size: CGFloat,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .asideGlassCircle()
                    .frame(width: size, height: size)
                    .overlay(
                        Circle().stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.06)
                                : Color.white.opacity(0.6),
                            lineWidth: 0.5
                        )
                    )
                    .shadow(color: darkShadow, radius: size * 0.12, x: size * 0.08, y: size * 0.08)
                    .shadow(color: lightShadow, radius: size * 0.12, x: -size * 0.08, y: -size * 0.08)
                
                content()
            }
            .contentShape(Circle())
        }
        .buttonStyle(NeumorphicButtonStyle(bgColor: raisedColor, darkShadow: darkShadow, lightShadow: lightShadow))
    }
}

// MARK: - 辅助方法
extension NeumorphicPlayerLayout {
    
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

// MARK: - 新拟物化按钮样式
struct NeumorphicButtonStyle: ButtonStyle {
    let bgColor: Color
    let darkShadow: Color
    let lightShadow: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
