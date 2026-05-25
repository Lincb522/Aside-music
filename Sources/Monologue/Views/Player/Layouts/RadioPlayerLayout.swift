import SwiftUI
import UIKit
import FFmpegSwiftSDK

/// 复古收音机播放器 — 封面取色 + 节奏球体 + LED 点阵
struct RadioPlayerLayout: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject private var downloadManager = DownloadManager.shared
    @ObservedObject private var lyricVM = LyricViewModel.shared

    @State private var colorEx = CoverColorExtractor()

    @State private var showPlaylist = false
    @State private var showMoreMenu = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showQualitySheet = false
    @State private var showComments = false
    @State private var showArtistDetail = false
    @State private var showDownloadSheet = false
    @State private var isDragging = false
    @State private var dragValue: Double = 0

    // MARK: - 轻拟物调色板 (Soft Skeuomorphic Palette)

    private var dominant: Color { colorEx.dominantColor }
    private var secondary: Color { colorEx.secondaryColor }
    private var isDarkCover: Bool { colorEx.isDark }

    /// 表面基色 — 从封面色生成的柔和中间调
    private var surface: Color { dominant.opacity(isDarkCover ? 0.28 : 0.35).blendedWith(.white, ratio: 0.45) }
    private var surfaceLight: Color { surface.blendedWith(.white, ratio: 0.15) }
    private var surfaceDark: Color { surface.blendedWith(.black, ratio: 0.12) }

    private var bgTop: Color { dominant.opacity(0.25).blendedWith(.white, ratio: 0.35) }
    private var bgBot: Color { secondary.opacity(0.20).blendedWith(.white, ratio: 0.30) }

    private var chassis: Color { surface }
    private var chassisHighlight: Color { Color.white.opacity(0.55) }
    private var chassisShadow: Color { Color.black.opacity(0.18) }

    private var ledBg: Color { surfaceDark.blendedWith(.black, ratio: 0.35) }
    private var ledDotOn: Color { .white }
    private var ledDotOff: Color { Color.black.opacity(0.3) }

    private var speakerFace: Color { surfaceDark.blendedWith(.black, ratio: 0.10) }
    private var infoCardBg: Color { surfaceLight }
    private var progressTrack: Color { surfaceDark }
    private var progressDot: Color { Color.white }
    private var textW: Color { isDarkCover ? .white : Color(white: 0.12) }
    private var textDim: Color { textW.opacity(0.55) }
    private var btnFg: Color { textW }

    private var currentTime: Double { isDragging ? dragValue : timePublisher.currentTime }
    private var progress: Double {
        guard timePublisher.duration > 0 else { return 0 }
        return min(max(currentTime / timePublisher.duration, 0), 1)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let isLand = geo.size.width > geo.size.height
            let safeL = geo.safeAreaInsets.leading
            let hPad: CGFloat = isLand ? max(safeL, 4) + 4 : 6
            let cardW = geo.size.width - hPad * 2
            let cardH = isLand
                ? geo.size.height - 16
                : geo.size.height - DeviceLayout.headerTopPadding - DeviceLayout.playerBottomPadding - 20

            ZStack {
                LinearGradient(colors: [bgTop, bgBot], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    radioCard(cardW: cardW, cardH: cardH, isLand: isLand)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, hPad)

                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        isDarkBackground: true,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
        }
        .onAppear {
            colorEx.extract(from: player.currentSong?.coverUrl?.absoluteString)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                OrientationManager.shared.enterLandscape()
            }
        }
        .onDisappear { OrientationManager.shared.exitLandscape() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                OrientationManager.shared.reapplyIfNeeded()
            }
        }
        .onChange(of: player.currentSong?.id) { _, _ in
            colorEx.extract(from: player.currentSong?.coverUrl?.absoluteString)
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) { PlaylistPopupView() }
        .monologueSheet(isPresented: $showQualitySheet, preset: .compact) {
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentQQQuality: player.qqMusicQuality,
                isQQMusic: player.currentSong?.isQQMusic == true,
                onSelectNetease: { player.switchQuality($0); showQualitySheet = false },
                onSelectQQ: { player.switchQQMusicQuality($0); showQualitySheet = false },
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
        .monologueSheet(isPresented: $showThemePicker, preset: .themePicker) { PlayerThemePickerSheet() }
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
                DownloadQualitySheet(song: song) { showDownloadSheet = false }
            }
        }
    }

    // MARK: - Radio Card (轻拟物机箱)

    private func radioCard(cardW: CGFloat, cardH: CGFloat, isLand: Bool) -> some View {
        let pad: CGFloat = isLand ? 12 : 14
        let spkW: CGFloat = isLand
            ? min(cardH - 110, cardW * 0.35)
            : min(cardW * 0.42, cardH * 0.4)
        let cr: CGFloat = 28

        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                skeuBtn(icon: .close, size: 32) { dismiss() }
                ledBanner.frame(maxWidth: .infinity)
                skeuBtn(icon: .more, size: 32) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { showMoreMenu.toggle() }
                }
            }
            .padding(.horizontal, pad)
            .padding(.top, pad)
            .padding(.bottom, 8)

            HStack(alignment: .top, spacing: isLand ? 14 : 12) {
                speakerBox(size: spkW)
                infoPanelCard(isLand: isLand)
                    .frame(height: spkW)
            }
            .padding(.horizontal, pad)

            Spacer(minLength: 4)

            transportStrip
                .padding(.horizontal, pad)
                .padding(.bottom, pad)
        }
        .frame(width: cardW, height: cardH)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(chassis)
                // 顶部内高光
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [chassisHighlight, .clear],
                            startPoint: .top, endPoint: .init(x: 0.5, y: 0.35)
                        )
                    )
                // 底部内阴影
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, chassisShadow],
                            startPoint: .init(x: 0.5, y: 0.7), endPoint: .bottom
                        )
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.6), Color.white.opacity(0.1), Color.black.opacity(0.12)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: chassisShadow, radius: 16, x: 0, y: 8)
        .shadow(color: Color.white.opacity(0.35), radius: 6, x: 0, y: -3)
    }

    // MARK: - LED Banner (凹陷内嵌)

    private var ledBanner: some View {
        let text = player.currentSong.map { "\($0.name)  ♪  \($0.artistName)" }
            ?? "MONO MUSIC  ♪  READY"

        return LEDDotMatrixBanner(
            text: text,
            onColor: ledDotOn,
            offColor: ledDotOff,
            bgColor: ledBg,
            speed: 35
        )
        .frame(height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.black.opacity(0.3), Color.clear, Color.white.opacity(0.15)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 2)
        .shadow(color: Color.white.opacity(0.2), radius: 1, x: 0, y: -1)
    }

    // MARK: - Speaker Box (轻拟物凹陷)

    private func speakerBox(size: CGFloat) -> some View {
        let cr: CGFloat = 20
        return ZStack {
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(speakerFace)

            // 凹陷内阴影效果
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.18), .clear, Color.white.opacity(0.06)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // 网罩孔洞 — 用 Canvas 画柔和圆点网格
            Canvas { ctx, sz in
                let gap: CGFloat = 10
                let dotR: CGFloat = 2.2
                let inset: CGFloat = 16
                for r in stride(from: inset, to: sz.height - inset, by: gap) {
                    let rowOffset: CGFloat = Int(r / gap) % 2 == 0 ? 0 : gap * 0.5
                    for c in stride(from: inset + rowOffset, to: sz.width - inset, by: gap) {
                        let rect = CGRect(x: c - dotR, y: r - dotR, width: dotR * 2, height: dotR * 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.25)))
                    }
                }
            }

            BouncingSpheres(isPlaying: player.isPlaying, accent: dominant, surface: surface)
                .frame(width: size * 0.55, height: size * 0.55)
                .offset(x: size * 0.08, y: size * 0.08)

            // 四角螺丝
            ForEach(0..<4, id: \.self) { i in
                let dx: CGFloat = (i % 2 == 0) ? -1 : 1
                let dy: CGFloat = (i / 2 == 0) ? -1 : 1
                screwDot.offset(x: dx * (size / 2 - 14), y: dy * (size / 2 - 14))
            }
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.black.opacity(0.2), Color.clear, Color.white.opacity(0.25)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 3)
        .shadow(color: Color.white.opacity(0.25), radius: 2, x: 0, y: -1)
    }

    private var screwDot: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.35), surfaceDark],
                        center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: 5
                    )
                )
            Circle()
                .stroke(Color.black.opacity(0.12), lineWidth: 0.5)
        }
        .frame(width: 8, height: 8)
        .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0.5, y: 0.5)
    }

    // MARK: - Info Panel Card (轻拟物微凸面板)

    private func infoPanelCard(isLand: Bool) -> some View {
        let cr: CGFloat = 20
        return VStack(alignment: .leading, spacing: isLand ? 10 : 8) {
            HStack(spacing: 10) {
                if let url = player.currentSong?.coverUrl?.sized(200) {
                    CachedAsyncImage(url: url) {
                        RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: isLand ? 52 : 48, height: isLand ? 52 : 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                    .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if lyricVM.hasLyrics, !lyricVM.lyrics.isEmpty {
                        let idx = lyricVM.currentLineIndex
                        let cur = lyricVM.lyrics[idx]
                        let nextIdx = idx + 1 < lyricVM.lyrics.count ? idx + 1 : nil

                        VStack(alignment: .leading, spacing: 4) {
                            Text(cur.text)
                                .font(.system(size: isLand ? 15 : 13, weight: .bold, design: .rounded))
                                .foregroundStyle(textW)
                                .lineLimit(2)

                            if let t = cur.translation, !t.isEmpty {
                                Text(t)
                                    .font(.system(size: isLand ? 11 : 10, weight: .medium))
                                    .foregroundStyle(textDim)
                                    .lineLimit(1)
                            }

                            if let ni = nextIdx {
                                Text(lyricVM.lyrics[ni].text)
                                    .font(.system(size: isLand ? 12 : 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(textW.opacity(0.45))
                                    .lineLimit(1)
                            }
                        }
                        .id(idx)
                        .transition(.asymmetric(
                            insertion: .push(from: .bottom),
                            removal: .push(from: .top)
                        ))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: idx)
                    } else {
                        Text(player.currentSong?.name ?? "Ready")
                            .font(.system(size: isLand ? 15 : 13, weight: .bold, design: .rounded))
                            .foregroundStyle(textW).lineLimit(1)
                        Button { showArtistDetail = true } label: {
                            Text(player.currentSong?.artistName ?? "—")
                                .font(.system(size: isLand ? 12 : 11, weight: .medium))
                                .foregroundStyle(textDim).lineLimit(1)
                        }
                        .buttonStyle(.plain).disabled(player.currentSong == nil)
                    }
                }
                Spacer(minLength: 0)
            }

            thickProgressBar.frame(height: isLand ? 32 : 28)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(fmtTime(currentTime))
                    .font(.system(size: isLand ? 40 : 34, weight: .bold, design: .rounded))
                    .foregroundStyle(textW).monospacedDigit()
                Text(fmtTime(timePublisher.duration))
                    .font(.system(size: isLand ? 18 : 15, weight: .medium, design: .rounded))
                    .foregroundStyle(textDim).monospacedDigit()

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    if let song = player.currentSong {
                        LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song,
                                   size: 16, activeColor: .red, inactiveColor: textDim)
                            .frame(width: 30, height: 30)
                    }
                    skeuBtn(icon: nil, size: 36, label: player.qualityButtonText) { showQualitySheet = true }
                        .playerQualitySelectionAvailability()
                }
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: cr, style: .continuous).fill(infoCardBg)
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), .clear],
                            startPoint: .top, endPoint: .init(x: 0.5, y: 0.4)
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.5), Color.black.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 4)
        .shadow(color: Color.white.opacity(0.3), radius: 3, x: 0, y: -2)
    }

    // MARK: - Progress Bar (轻拟物凹槽 + 凸滑块)

    private var thickProgressBar: some View {
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            let trackH: CGFloat = h * 0.35
            let knobD: CGFloat = h * 0.60

            ZStack(alignment: .leading) {
                // 凹槽轨道
                Capsule().fill(surfaceDark)
                    .frame(height: trackH)
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.black.opacity(0.15), Color.white.opacity(0.15)],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                    .frame(height: h)

                // 填充
                if progress > 0.01 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [dominant.opacity(0.5), dominant.opacity(0.35)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(trackH, w * progress), height: trackH)
                        .frame(height: h)
                }

                // 凸滑块
                let fillGradient = LinearGradient(
                    colors: [Color.white.opacity(0.95), surfaceLight],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                let strokeGradient = LinearGradient(
                    colors: [Color.white.opacity(0.6), Color.black.opacity(0.08)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                let strokeCircle = Circle()
                    .stroke(strokeGradient, lineWidth: 0.8)
                let knobBase = Circle()
                    .fill(fillGradient)
                    .frame(width: knobD, height: knobD)
                    .overlay(strokeCircle)
                let knobWithShadow = knobBase
                    .shadow(color: Color.black.opacity(0.18), radius: 3, x: 1, y: 2)
                    .shadow(color: Color.white.opacity(0.3), radius: 1, x: -0.5, y: -0.5)
                let knobView = knobWithShadow
                    .offset(x: max(knobD * 0.3, min(w * progress - knobD * 0.5, w - knobD * 0.7)))
                knobView
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        isDragging = true
                        dragValue = min(max(v.location.x / w, 0), 1) * timePublisher.duration
                    }
                    .onEnded { v in
                        player.seek(to: min(max(v.location.x / w, 0), 1) * timePublisher.duration)
                        isDragging = false
                    }
            )
        }
    }

    // MARK: - Transport Strip (轻拟物按钮)

    private var transportStrip: some View {
        HStack(spacing: 14) {
            skeuBtn(icon: player.mode.monologueIcon, size: 36) {
                HapticManager.shared.light(); player.switchMode()
            }
            skeuBtn(icon: .previous, size: 40) {
                HapticManager.shared.medium(); player.previous()
            }

            // 播放/暂停 — 大号凸按钮
            Button {
                HapticManager.shared.medium(); player.togglePlayPause()
            } label: {
                ZStack {
                    if player.isLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: btnFg)).scaleEffect(0.8)
                    } else {
                        MonologueIcon(icon: player.isPlaying ? .pause : .play, size: 22, color: btnFg)
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                }
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [surfaceLight, surface],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.6), Color.black.opacity(0.08)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: Color.black.opacity(0.18), radius: 5, x: 2, y: 3)
                .shadow(color: Color.white.opacity(0.35), radius: 3, x: -1, y: -2)
                .contentShape(Circle())
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))

            skeuBtn(icon: .next, size: 40) {
                HapticManager.shared.medium(); player.next()
            }
            skeuBtn(icon: .list, size: 36) {
                HapticManager.shared.light(); showPlaylist = true
            }
        }
        .padding(.vertical, 6).frame(maxWidth: .infinity)
    }

    // MARK: - 轻拟物通用按钮

    private func skeuBtn(icon: MonologueIcon.IconType?, size: CGFloat, label: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let icon {
                    MonologueIcon(icon: icon, size: size * 0.40, color: btnFg.opacity(0.8))
                } else if let label {
                    Text(label)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(btnFg)
                }
            }
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [surfaceLight, surface],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.5), Color.black.opacity(0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
            )
            .shadow(color: Color.black.opacity(0.14), radius: 3, x: 1, y: 2)
            .shadow(color: Color.white.opacity(0.30), radius: 2, x: -0.5, y: -1)
            .contentShape(Circle())
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
    }

    private func fmtTime(_ s: Double) -> String {
        guard !s.isNaN && !s.isInfinite else { return "0:00" }
        let t = Int(s); return String(format: "%d:%02d", t / 60, t % 60)
    }
}

// MARK: - Bouncing Spheres (节奏跳动金属球)

private struct BouncingSpheres: View {
    let isPlaying: Bool
    let accent: Color
    let surface: Color

    private struct Sphere: Identifiable {
        let id: Int
        let relSize: CGFloat
        let baseX: CGFloat
        let baseY: CGFloat
        let phaseX: Double
        let phaseY: Double
        let freqX: Double
        let freqY: Double
    }

    private let spheres: [Sphere] = [
        Sphere(id: 0, relSize: 0.40, baseX:  0.0,  baseY:  0.15, phaseX: 0,   phaseY: 0.5, freqX: 2.6, freqY: 3.0),
        Sphere(id: 1, relSize: 0.26, baseX: -0.52, baseY: -0.40, phaseX: 1.2, phaseY: 0.8, freqX: 3.4, freqY: 2.2),
        Sphere(id: 2, relSize: 0.20, baseX:  0.48, baseY: -0.30, phaseX: 2.4, phaseY: 1.6, freqX: 2.8, freqY: 3.6),
    ]

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(paused: !isPlaying)) { timeline in
            let t = isPlaying ? timeline.date.timeIntervalSinceReferenceDate : 0

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    ForEach(spheres) { s in
                        let amp: CGFloat = isPlaying ? 0.10 : 0
                        let dx = CGFloat(sin(t * s.freqX + s.phaseX)) * amp * w
                        let dy = CGFloat(sin(t * s.freqY + s.phaseY)) * amp * h
                        let pulse = isPlaying
                            ? 1.0 + 0.06 * CGFloat(sin(t * (s.freqX + s.freqY) * 0.5 + s.phaseX))
                            : 1.0
                        let d = s.relSize * min(w, h)

                        softBall(diameter: d)
                            .offset(
                                x: s.baseX * w * 0.35 + dx,
                                y: s.baseY * h * 0.35 + dy
                            )
                            .scaleEffect(pulse)
                    }
                }
                .frame(width: w, height: h)
            }
        }
    }

    /// 轻拟物柔球 — 磨砂质感、柔高光、柔阴影
    private func softBall(diameter: CGFloat) -> some View {
        let d = diameter
        let base = surface.blendedWith(accent, ratio: 0.2)
        return ZStack {
            // 主体 — 柔和径向渐变
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            base.blendedWith(.white, ratio: 0.40),
                            base.blendedWith(.white, ratio: 0.15),
                            base.blendedWith(.black, ratio: 0.10)
                        ],
                        center: .init(x: 0.38, y: 0.32),
                        startRadius: d * 0.02,
                        endRadius: d * 0.55
                    )
                )
                .frame(width: d, height: d)

            // 顶部柔高光
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.70), Color.white.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: d * 0.55, height: d * 0.35)
                .offset(x: -d * 0.05, y: -d * 0.18)

            // 边缘描边
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.5), Color.black.opacity(0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
                .frame(width: d, height: d)
        }
        .shadow(color: Color.black.opacity(0.20), radius: d * 0.12, x: d * 0.04, y: d * 0.08)
        .shadow(color: Color.white.opacity(0.35), radius: d * 0.06, x: -d * 0.02, y: -d * 0.04)
    }
}

// MARK: - LED Dot Matrix Banner (预渲染 CGImage，每帧仅合成两张图)

private struct LEDDotMatrixBanner: View {
    let text: String
    let onColor: Color
    let offColor: Color
    let bgColor: Color
    let speed: Double

    /// 纵向格数略提高可让点阵更细；每帧仍只 draw 两张 CGImage，成本不变。
    private static let res = 40
    private static let rasterizer = LEDRasterizer()
    private static let imageCache = LEDImageCache()

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline()) { timeline in
            Canvas { ctx, size in
                let rows = Self.res
                let cell = size.height / CGFloat(rows)
                let dotR = cell * 0.38

                // 1) 背景色填充
                let bgPath = RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .path(in: CGRect(origin: .zero, size: size))
                ctx.fill(bgPath, with: .color(bgColor))

                // 2) Off-dot 背景 — 预渲染为 CGImage（尺寸变化时才重建）
                let scaleTag = Int(max(2, UIScreen.main.scale) * 100)
                let bgKey = "\(Int(size.width))x\(Int(size.height))_\(scaleTag)"
                let bgImg = Self.imageCache.offDotImage(key: bgKey, size: size, rows: rows, dotR: dotR, color: offColor)
                ctx.draw(Image(decorative: bgImg, scale: 1), in: CGRect(origin: .zero, size: size))

                // 3) 文字条带 — 预渲染为 CGImage（文字变化时才重建）
                let grid = Self.rasterizer.rasterize(text, resolution: rows)
                let totalCols = grid.first?.count ?? 0
                guard totalCols > 0 else { return }

                let stripKey = "\(text)|\(rows)|\(Int(size.height))_\(scaleTag)"
                let (stripImg, stripW) = Self.imageCache.textStripImage(
                    key: stripKey, grid: grid, rows: rows, totalCols: totalCols,
                    cellSize: cell, dotR: dotR, color: onColor, height: size.height
                )

                // 4) 滚动偏移 — 每帧只做一次图片绘制
                let loopLen = stripW + size.width
                let t = timeline.date.timeIntervalSinceReferenceDate
                let scroll = CGFloat(t * speed).truncatingRemainder(dividingBy: loopLen)
                let xOff = size.width - scroll

                ctx.draw(
                    Image(decorative: stripImg, scale: 1),
                    in: CGRect(x: xOff, y: 0, width: stripW, height: size.height)
                )
            }
        }
    }
}

/// 预渲染图像缓存 — 避免每帧重绘万级圆点（位图按屏 scale 生成，避免糊边且不增加每帧开销）
private final class LEDImageCache: @unchecked Sendable {
    private var offDots: [String: CGImage] = [:]
    private var strips: [String: (CGImage, CGFloat)] = [:]
    private let lock = NSLock()

    private static var pixelScale: CGFloat {
        MainActor.assumeIsolated {
            max(2, UIScreen.main.scale)
        }
    }

    func offDotImage(key: String, size: CGSize, rows: Int, dotR: CGFloat, color: Color) -> CGImage {
        lock.lock()
        if let cached = offDots[key] { lock.unlock(); return cached }
        lock.unlock()

        let scale = Self.pixelScale
        let w = Int(size.width * scale), h = Int(size.height * scale)
        let cell = size.height / CGFloat(rows)

        guard let cgCtx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return createFallback() }

        cgCtx.scaleBy(x: scale, y: scale)
        cgCtx.translateBy(x: 0, y: size.height)
        cgCtx.scaleBy(x: 1, y: -1)
        let uiColor = UIColor(color)
        cgCtx.setFillColor(uiColor.cgColor)

        let visCols = Int(ceil(size.width / cell)) + 1
        for c in 0..<visCols {
            let cx = (CGFloat(c) + 0.5) * cell
            for r in 0..<rows {
                let cy = (CGFloat(r) + 0.5) * cell
                cgCtx.fillEllipse(in: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2))
            }
        }

        let img = cgCtx.makeImage() ?? createFallback()
        lock.lock()
        offDots[key] = img
        lock.unlock()
        return img
    }

    func textStripImage(
        key: String, grid: [[Bool]], rows: Int, totalCols: Int,
        cellSize: CGFloat, dotR: CGFloat, color: Color, height: CGFloat
    ) -> (CGImage, CGFloat) {
        lock.lock()
        if let cached = strips[key] { lock.unlock(); return cached }
        lock.unlock()

        let stripW = CGFloat(totalCols) * cellSize
        let scale = Self.pixelScale
        let w = Int(stripW * scale), h = Int(height * scale)
        guard w > 0 else { return (createFallback(), 0) }

        guard let cgCtx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return (createFallback(), stripW) }

        cgCtx.scaleBy(x: scale, y: scale)
        cgCtx.translateBy(x: 0, y: height)
        cgCtx.scaleBy(x: 1, y: -1)
        let uiColor = UIColor(color)
        cgCtx.setFillColor(uiColor.cgColor)

        for c in 0..<totalCols {
            let cx = (CGFloat(c) + 0.5) * cellSize
            for r in 0..<rows {
                guard grid[r][c] else { continue }
                let cy = (CGFloat(r) + 0.5) * cellSize
                cgCtx.fillEllipse(in: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2))
            }
        }

        let img = cgCtx.makeImage() ?? createFallback()
        lock.lock()
        strips[key] = (img, stripW)
        lock.unlock()
        return (img, stripW)
    }

    private func createFallback() -> CGImage {
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                           space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }
}

/// CoreGraphics 高分辨率点阵光栅器 — 超采样 + 区域均值降采样（仅文本/分辨率变化时重算，已缓存）
private final class LEDRasterizer: @unchecked Sendable {
    private var cache: [String: [[Bool]]] = [:]
    private let lock = NSLock()

    /// 字符内部超采样倍数；略高于 5 可减轻字形边缘锯齿，且只发生在缓存未命中时。
    private static let charSupersample = 6

    func rasterize(_ text: String, resolution: Int) -> [[Bool]] {
        let key = "\(text)|\(resolution)"
        lock.lock()
        if let c = cache[key] { lock.unlock(); return c }
        lock.unlock()

        let n = resolution
        var allCols: [[Bool]] = Array(repeating: [], count: n)

        for ch in text {
            let charGrid = rasterizeChar(ch, n: n)
            for r in 0..<n {
                allCols[r].append(contentsOf: charGrid[r])
                allCols[r].append(false)
            }
        }
        let blank = max(n * 2, 40)
        for r in 0..<n { allCols[r].append(contentsOf: [Bool](repeating: false, count: blank)) }

        lock.lock()
        cache[key] = allCols
        lock.unlock()
        return allCols
    }

    private func rasterizeChar(_ ch: Character, n: Int) -> [[Bool]] {
        let isWide = ch.unicodeScalars.first.map { $0.value > 0x7F } ?? false
        let charW = isWide ? n : max(n / 2 + 4, 14)

        let scale = Self.charSupersample
        let bw = charW * scale
        let bh = n * scale

        let fontSize = CGFloat(bh) * 0.78
        let font = UIFont.systemFont(ofSize: fontSize, weight: .heavy)

        guard let cgCtx = CGContext(
            data: nil, width: bw, height: bh,
            bitsPerComponent: 8, bytesPerRow: bw,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return Array(repeating: [Bool](repeating: false, count: charW), count: n) }

        cgCtx.setFillColor(gray: 0, alpha: 1)
        cgCtx.fill(CGRect(x: 0, y: 0, width: bw, height: bh))
        cgCtx.setShouldAntialias(true)

        UIGraphicsPushContext(cgCtx)
        let str = String(ch) as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
        let sz = str.size(withAttributes: attrs)
        let xOff = (CGFloat(bw) - sz.width) / 2
        let yOff = (CGFloat(bh) - sz.height) / 2
        str.draw(at: CGPoint(x: max(0, xOff), y: max(0, yOff)), withAttributes: attrs)
        UIGraphicsPopContext()

        guard let data = cgCtx.data else {
            return Array(repeating: [Bool](repeating: false, count: charW), count: n)
        }
        let ptr = data.bindMemory(to: UInt8.self, capacity: bw * bh)

        var grid = Array(repeating: [Bool](repeating: false, count: charW), count: n)

        for r in 0..<n {
            for c in 0..<charW {
                // Area-average over the entire scale×scale cell
                var sum = 0
                let baseY = (n - 1 - r) * scale
                let baseX = c * scale
                for dy in 0..<scale {
                    for dx in 0..<scale {
                        let py = min(baseY + dy, bh - 1)
                        let px = min(baseX + dx, bw - 1)
                        sum += Int(ptr[py * bw + px])
                    }
                }
                let avg = sum / (scale * scale)
                grid[r][c] = avg > 100
            }
        }
        return grid
    }
}

// MARK: - Color Blend Extension

private extension Color {
    func blendedWith(_ other: Color, ratio: CGFloat) -> Color {
        let r = min(max(ratio, 0), 1)
        let c1 = UIColor(self)
        let c2 = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red: Double(r1 * (1 - r) + r2 * r),
            green: Double(g1 * (1 - r) + g2 * r),
            blue: Double(b1 * (1 - r) + b2 * r),
            opacity: Double(a1 * (1 - r) + a2 * r)
        )
    }
}
