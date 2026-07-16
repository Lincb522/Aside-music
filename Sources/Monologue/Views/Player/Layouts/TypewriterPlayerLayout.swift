import SwiftUI
import FFmpegSwiftSDK

// MARK: - Typewriter Key Button Style

/// 模拟真实打字机按键的物理下沉 — 按下时 key 下移 + 阴影缩减
private struct TypewriterKeyStyle: ButtonStyle {
    var depth: CGFloat = 3

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? depth : 0)
            .animation(.spring(response: 0.1, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

// MARK: - Typewriter Lyrics View

/// 核心灵魂：歌词像被打字机一个字一个字敲上纸页，纸张卷轴式滚动
/// - 纸张固定高度，歌词通过 ScrollView 卷轴式滚入/滚出
/// - 当前行逐字显示，带闪烁光标
/// - 已过行完整显示，墨色渐淡，滚出顶部（卷入滚轴）
/// - 换行时纸张进纸抖动 + 自动滚动
/// - 顶部渐隐遮罩模拟纸张卷入滚轴
private struct TypewriterLyricsView: View {
    @ObservedObject private var vm = LyricViewModel.shared
    @ObservedObject private var player = PlayerManager.shared

    let ink: Color
    let inkFaded: Color
    let ribbon: Color
    let paper: Color

    @State private var paperFeedOffset: CGFloat = 0
    @State private var prevIndex: Int = -1
    @State private var carriageX: CGFloat = 0

    var body: some View {
        Group {
            if vm.isLoading {
                typingPlaceholder("LOADING RIBBON…", sub: String(localized: "正在装入色带"))
            } else if !vm.hasLyrics {
                typingPlaceholder("NO TRANSCRIPT", sub: String(localized: "纯音乐，请欣赏"))
            } else {
                lyricsScroller
            }
        }
        .onChange(of: vm.currentLineIndex) { _, newIdx in
            guard newIdx != prevIndex else { return }
            let forward = newIdx > prevIndex
            prevIndex = newIdx
            if forward {
                carriageX = 4
                withAnimation(.easeOut(duration: 0.05)) { paperFeedOffset = -5 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        paperFeedOffset = 0
                        carriageX = 0
                    }
                }
                HapticManager.shared.light()
            }
        }
    }

    // MARK: - Lyrics Scroller (卷轴)

    private var lyricsScroller: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(vm.lyrics.enumerated()), id: \.offset) { i, line in
                        lyricRow(i: i, line: line)
                            .id(i)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDisabled(true)
            .onChange(of: vm.currentLineIndex) { _, newIdx in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    proxy.scrollTo(newIdx, anchor: .top)
                }
            }
            .onAppear {
                if vm.currentLineIndex > 0 {
                    proxy.monologueRestoreLyricPosition(anchor: .top) { vm.currentLineIndex }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 8)
                Rectangle().fill(Color.black)
                LinearGradient(colors: [.black, .black.opacity(0.3), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 18)
            }
        )
    }

    @ViewBuilder
    private func lyricRow(i: Int, line: LyricLine) -> some View {
        let idx = vm.currentLineIndex
        if i == idx {
            TimelineView(AppFrameRate.throttledTimeline(maximumFramesPerSecond: 60, paused: !player.isPlaying)) { _ in
                let rawT = player.streamPlayer.currentTime
                let t = (rawT.isFinite && !rawT.isNaN && rawT >= 0) ? rawT : 0
                currentLine(line, realTime: t)
                    .offset(x: carriageX, y: paperFeedOffset)
            }
        } else if i < idx {
            historyLine(line, opacity: historyOpacity(age: idx - i))
        } else {
            previewLine(line)
        }
    }

    private func historyOpacity(age: Int) -> Double {
        max(0.2, 1.0 - Double(age) * 0.13)
    }

    // MARK: - Placeholder

    private func typingPlaceholder(_ title: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(ink.opacity(0.5))
                cursorView
            }
            Text(sub)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(inkFaded)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - History Line

    private func historyLine(_ line: LyricLine, opacity: Double) -> some View {
        Button { PlayerManager.shared.seek(to: line.time) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(line.text.monologueLyricDisplayText)
                    .font(
                        MonologuePlayerFont.activeFont(
                            size: 14,
                            weight: .regular,
                            fallback: .system(size: 14, weight: .regular, design: .monospaced)
                        )
                    )
                    .foregroundStyle(inkFaded.opacity(opacity))

                if let trans = line.translation {
                    Text(trans.monologueLyricDisplayText)
                        .font(
                            MonologuePlayerFont.activeFont(
                                size: 11,
                                weight: .regular,
                                fallback: .system(size: 11, weight: .regular, design: .serif)
                            )
                        )
                        .foregroundStyle(inkFaded.opacity(opacity * 0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Current Typing Line

    private func currentLine(_ line: LyricLine, realTime: TimeInterval) -> some View {
        let displayText = line.text.monologueLyricDisplayText
        let total = displayText.count
        let visible = typedCharCount(line: line, realTime: realTime)
        let clamped = min(visible, total)
        let typed = String(displayText.prefix(clamped))
        let finished = clamped >= total

        return VStack(alignment: .leading, spacing: 3) {
            ZStack(alignment: .bottomTrailing) {
                Text(typed)
                    .font(
                        MonologuePlayerFont.activeFont(
                            size: 17,
                            weight: .semibold,
                            fallback: .system(size: 17, weight: .semibold, design: .monospaced)
                        )
                    )
                    .foregroundStyle(ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !finished {
                    cursorView
                        .alignmentGuide(.trailing) { d in d[.trailing] }
                        .alignmentGuide(.bottom) { d in d[.bottom] }
                }
            }

            if let rawTranslation = line.translation {
                let trans = rawTranslation.monologueLyricDisplayText
                let tTotal = trans.count
                let tVisible = total > 0 ? Int(ceil(Double(clamped) / Double(total) * Double(tTotal))) : 0
                Text(String(trans.prefix(max(0, min(tVisible, tTotal)))))
                    .font(
                        MonologuePlayerFont.activeFont(
                            size: 12,
                            weight: .regular,
                            fallback: .system(size: 12, weight: .regular, design: .serif)
                        )
                    )
                    .foregroundStyle(inkFaded.opacity(0.75))
            }
        }
        .padding(.vertical, 6)
    }

    private func typedCharCount(line: LyricLine, realTime: TimeInterval) -> Int {
        let total = line.text.count
        guard total > 0 else { return 0 }

        if !line.words.isEmpty {
            var count = 0
            for word in line.words {
                let wordEnd = word.startTime + word.duration
                if realTime >= wordEnd {
                    count += word.text.count
                } else if realTime >= word.startTime {
                    let wp = (realTime - word.startTime) / max(word.duration, 0.03)
                    count += max(1, Int(ceil(wp * Double(word.text.count))))
                    break
                } else {
                    break
                }
            }
            return count
        }

        let progress = vm.currentLineProgress
        return Int(ceil(progress * Double(total)))
    }

    // MARK: - Preview Line

    private func previewLine(_ line: LyricLine) -> some View {
        Button { PlayerManager.shared.seek(to: line.time) } label: {
            Text(line.text.monologueLyricDisplayText)
                .font(
                    MonologuePlayerFont.activeFont(
                        size: 13,
                        weight: .light,
                        fallback: .system(size: 13, weight: .light, design: .monospaced)
                    )
                )
                .foregroundStyle(inkFaded.opacity(0.12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cursor

    private var cursorView: some View {
        Text("▌")
            .font(.system(size: 17, weight: .semibold, design: .monospaced))
            .foregroundStyle(ribbon)
            .compatBlink(dimOpacity: 0.1, duration: 0.45)
    }
}

// MARK: - Main Layout

struct TypewriterPlayerLayout: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject private var downloadManager = DownloadManager.shared

    @State private var showPlaylist = false
    @State private var showMoreMenu = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showQualitySheet = false
    @State private var showComments = false
    @State private var showArtistDetail = false
    @State private var showDownloadSheet = false
    @State private var isDragging = false
    @State private var dragTimeValue: Double = 0
    @State private var playBounce = false

    // MARK: - Palette

    private var desk: Color { colorScheme == .dark ? Color(hex: "1C1612") : Color(hex: "8B6E4E") }
    private var deskDeep: Color { colorScheme == .dark ? Color(hex: "0F0B08") : Color(hex: "5C432D") }
    private var metal: Color { colorScheme == .dark ? Color(hex: "3C342E") : Color(hex: "5E5248") }
    private var metalLight: Color { colorScheme == .dark ? Color(hex: "504740") : Color(hex: "7A6E62") }
    private var metalDark: Color { colorScheme == .dark ? Color(hex: "28221D") : Color(hex: "3E3530") }
    private var paper: Color { colorScheme == .dark ? Color(hex: "DED0B6") : Color(hex: "FBF5E6") }
    private var paperEdge: Color { colorScheme == .dark ? Color(hex: "C5B79E") : Color(hex: "E8DFC8") }
    private var ink: Color { colorScheme == .dark ? Color(hex: "221A14") : Color(hex: "2C2118") }
    private var inkFaded: Color { colorScheme == .dark ? Color(hex: "6D5E50") : Color(hex: "8A7A6A") }
    private var ribbon: Color { colorScheme == .dark ? Color(hex: "A44E38") : Color(hex: "8C3A26") }
    private var brass: Color { colorScheme == .dark ? Color(hex: "C4A45C") : Color(hex: "B8923E") }
    private var keyFace: Color { colorScheme == .dark ? Color(hex: "F0E8D8") : Color(hex: "F8F2E4") }
    private var keyRim: Color { colorScheme == .dark ? Color(hex: "6A5E52") : Color(hex: "C4B8A8") }
    private var keyText: Color { colorScheme == .dark ? Color(hex: "2C2218") : Color(hex: "2C2218") }
    private var topBtnFg: Color { colorScheme == .dark ? Color(hex: "C0B8A8") : Color(hex: "4A3E32") }

    private var currentTime: Double { isDragging ? dragTimeValue : timePublisher.currentTime }
    private var progress: Double {
        guard timePublisher.duration > 0 else { return 0 }
        return min(max(currentTime / timePublisher.duration, 0), 1)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let m = metrics(for: proxy)

            ZStack {
                deskBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.top, DeviceLayout.headerTopPadding)

                    Spacer(minLength: m.topGap)

                    mainStage(m: m)
                        .scaleEffect(m.scale, anchor: .top)
                        .frame(width: m.scaledW, height: m.scaledH, alignment: .top)
                        .frame(maxWidth: .infinity)

                    Spacer(minLength: m.bottomGap)
                }

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
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) { PlaylistPopupView() }
        .monologueSheet(isPresented: $showQualitySheet, preset: .standard) {
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
        .fullScreenCover(isPresented: $showEQSettings) {
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
                DownloadQualitySheet(song: song) { showDownloadSheet = false }
            }
        }
    }

    // MARK: - Metrics

    private struct M {
        let baseW: CGFloat
        let baseH: CGFloat
        let paperH: CGFloat
        let scale: CGFloat
        let scaledW: CGFloat
        let scaledH: CGFloat
        let topGap: CGFloat
        let bottomGap: CGFloat
    }

    private func metrics(for proxy: GeometryProxy) -> M {
        let landscape = !DeviceLayout.isPad && proxy.size.width > proxy.size.height
        let baseW: CGFloat = DeviceLayout.isPad ? 480 : (landscape ? 340 : 370)
        let paperH: CGFloat = DeviceLayout.isPad ? 360 : (landscape ? 180 : 340)
        let deckH: CGFloat = DeviceLayout.isPad ? 190 : (landscape ? 130 : 170)
        let baseH = paperH + deckH + 20

        let hPad: CGFloat = DeviceLayout.isPad ? 40 : (landscape ? 20 : 18)
        let availW = max(240, proxy.size.width - hPad * 2)
        let availH = max(260, proxy.size.height - DeviceLayout.headerTopPadding - DeviceLayout.playerBottomPadding - 80)
        let s = min(max(min(availW / baseW, availH / baseH), 0.72), DeviceLayout.isPad ? 1.5 : (landscape ? 1.0 : 1.1))

        return M(
            baseW: baseW, baseH: baseH, paperH: paperH,
            scale: s, scaledW: baseW * s, scaledH: baseH * s,
            topGap: landscape ? 4 : 10,
            bottomGap: max(DeviceLayout.playerBottomPadding, proxy.safeAreaInsets.bottom + 10)
        )
    }

    // MARK: - Main Stage

    private func mainStage(m: M) -> some View {
        VStack(spacing: 0) {
            rollerBar(width: m.baseW * 0.88)
                .padding(.bottom, -6)
                .zIndex(3)

            paperArea(width: m.baseW * 0.88, height: m.paperH)
                .zIndex(2)

            machineDeck(width: m.baseW)
                .offset(y: -18)
                .padding(.bottom, -18)
                .zIndex(1)
        }
    }

    // MARK: - Roller Bar (旋转旋钮)

    private func rollerBar(width: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(colors: [metalLight, metal, metalDark], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: width, height: 14)
                .overlay(Capsule().stroke(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.2), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 3)

            HStack {
                brassKnob(size: 22, rotation: progress * 1080)
                Spacer()
                brassKnob(size: 22, rotation: progress * 1080)
            }
            .frame(width: width + 28)

            HStack {
                Spacer()
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(metalDark)
                        .frame(width: 5, height: 24)
                    brassKnob(size: 16, rotation: progress * -720)
                }
                .offset(y: 6)
            }
            .frame(width: width + 56)
        }
    }

    private func brassKnob(size: CGFloat, rotation: Double = 0) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [brass.opacity(0.95), brass.opacity(0.65)],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )

            Capsule()
                .fill(brass.opacity(0.35))
                .frame(width: 2, height: size * 0.45)
                .offset(y: -size * 0.1)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotation))
        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.8))
        .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 2)
        .animation(.linear(duration: 0.3), value: rotation)
    }

    // MARK: - Paper Area

    private func paperArea(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(paperEdge, lineWidth: 1)
                )

            Canvas { ctx, size in
                let startY: CGFloat = 88
                let spacing: CGFloat = 22
                var y = startY
                while y < size.height - 12 {
                    var line = Path()
                    line.move(to: CGPoint(x: 14, y: y))
                    line.addLine(to: CGPoint(x: size.width - 14, y: y))
                    ctx.stroke(line, with: .color(inkFaded.opacity(0.18)), lineWidth: 0.8)
                    y += spacing
                }

                var margin = Path()
                margin.move(to: CGPoint(x: 24, y: 12))
                margin.addLine(to: CGPoint(x: 24, y: size.height - 12))
                ctx.stroke(margin, with: .color(ribbon.opacity(0.28)), lineWidth: 1.5)
            }
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 6) {
                paperHeader

                ribbonProgressBar

                HStack {
                    Text(formatTime(currentTime))
                    Spacer()
                    Text(formatTime(timePublisher.duration))
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(inkFaded)
                .monospacedDigit()

                Rectangle().fill(ink.opacity(0.1)).frame(height: 1)

                if player.currentSong != nil {
                    TypewriterLyricsView(
                        ink: ink,
                        inkFaded: inkFaded,
                        ribbon: ribbon,
                        paper: paper
                    )
                } else {
                    emptyPaperPlaceholder
                }
            }
            .padding(.top, 12)
            .padding(.leading, 34)
            .padding(.trailing, 16)
            .padding(.bottom, 30)
        }
        .frame(width: width, height: height)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.14), radius: 12, x: 2, y: 8)
    }

    private var paperHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(player.isPlaying ? ribbon : inkFaded.opacity(0.4))
                        .frame(width: 6, height: 6)
                    Text(player.isPlaying ? "TYPING" : "READY")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(inkFaded)
                        .tracking(2)
                }

                MarqueeText(
                    text: player.currentSong?.name ?? "Insert Record",
                    font: MonologuePlayerFont.activeFont(
                        size: 22,
                        weight: .bold,
                        fallback: .system(size: 22, weight: .bold, design: .serif)
                    ),
                    color: ink,
                    speed: 26,
                    delayBeforeScroll: 1.6,
                    alignment: .leading
                )
                .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)

                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? "—")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(inkFaded)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .disabled(player.currentSong == nil)

                if let info = player.streamInfo {
                    Text(streamInfoText(info))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(inkFaded.opacity(0.8))
                }
            }

            coverStamp
        }
    }

    private var coverStamp: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "DCC8A0"), Color(hex: "B89060")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)

            if let url = player.currentSong?.coverUrl?.sized(300) {
                CachedAsyncImage(url: url) { Color.black.opacity(0.06) }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                MonologueIcon(icon: .musicNote, size: 20, color: ink.opacity(0.4))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
        )
        .rotationEffect(.degrees(3))
        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 3)
    }

    private var ribbonProgressBar: some View {
        FullScreenPlayerView.WaveformProgressBar(
            currentTime: Binding(get: { currentTime }, set: { _ in }),
            duration: timePublisher.duration,
            color: ink.opacity(0.85),
            trackOpacity: 0.1,
            isAnimating: player.isPlaying,
            onSeek: { isDragging = true; dragTimeValue = $0 },
            onCommit: { isDragging = false; player.seek(to: $0) }
        )
        .frame(height: 16)
    }

    private var emptyPaperPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INSERT RECORD")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(ink)
            Text("等待歌曲开始播放…")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(inkFaded)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 6)
    }

    // MARK: - Machine Deck

    private func machineDeck(width: CGFloat) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                qualityBadge

                Capsule()
                    .fill(metalLight.opacity(0.5))
                    .frame(width: 1, height: 16)

                Text(player.isPlaying ? "ROLLING" : (player.isLoading ? "INKING…" : "READY"))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(keyFace.opacity(0.7))
                    .tracking(1.5)

                Spacer()

                if let song = player.currentSong {
                    LikeButton(
                        songId: song.id,
                        isQQMusic: song.isQQMusic,
                        song: song,
                        size: 16,
                        activeColor: ribbon,
                        inactiveColor: keyFace.opacity(0.6)
                    )
                    .frame(width: 36, height: 36)
                    .background(roundKeycap(size: 36))
                }
            }
            .padding(.horizontal, 6)

            HStack(spacing: DeviceLayout.isPad ? 14 : 10) {
                roundKey(icon: player.mode.monologueIcon, size: 40) {
                    HapticManager.shared.light()
                    player.switchMode()
                }
                roundKey(icon: .previous, size: 44) {
                    HapticManager.shared.medium()
                    player.previous()
                }
                playKey
                roundKey(icon: .next, size: 44) {
                    HapticManager.shared.medium()
                    player.next()
                }
                roundKey(icon: .list, size: 40) {
                    HapticManager.shared.light()
                    showPlaylist = true
                }
            }

            if player.currentSong != nil {
                HStack(spacing: 8) {
                    labelKey(text: "NOTE", icon: .comment) {
                        HapticManager.shared.light()
                        showComments = true
                    }

                    if AppConfig.Features.downloadEnabled {
                        // 下载按键（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
                        let saved = player.currentSong.map {
                            downloadManager.isDownloaded(songId: $0.id, isQQ: $0.isQQMusic)
                        } ?? false
                        labelKey(
                            text: saved ? "SAVED" : "SAVE",
                            icon: .playerDownload,
                            disabled: saved
                        ) {
                            if !saved {
                                HapticManager.shared.light()
                                showDownloadSheet = true
                            }
                        }
                    } else {
                        // 沉浸模式按键 — 占用原下载按键的位置
                        labelKey(text: "CINEMA", icon: .immersive) {
                            HapticManager.shared.light()
                            CinemaModeController.shared.present()
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 6)
            }
        }
        .frame(width: width)
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(colors: [metal, metalDark], startPoint: .top, endPoint: .bottom)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(colorScheme == .dark ? 0.06 : 0.15), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.18), radius: 16, x: 0, y: 10)
    }

    // MARK: - Round Keycaps (物理 3D 按键)

    private func roundKeycap(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [keyRim, keyRim.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: size, height: size)

            Circle()
                .fill(
                    LinearGradient(colors: [keyFace, keyFace.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: size - 5, height: size - 5)
        }
    }

    private func roundKey(icon: MonologueIcon.IconType, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                roundKeycap(size: size)
                MonologueIcon(icon: icon, size: size * 0.4, color: keyText)
            }
            .contentShape(Circle())
        }
        .buttonStyle(TypewriterKeyStyle(depth: 3))
    }

    private var playKey: some View {
        Button {
            HapticManager.shared.medium()
            withAnimation(.spring(response: 0.1, dampingFraction: 0.4)) { playBounce = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { playBounce = false }
            }
            player.togglePlayPause()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [ribbon, ribbon.opacity(0.78)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 60, height: 60)
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))

                if player.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    MonologueIcon(
                        icon: player.isPlaying ? .pause : .play,
                        size: 24, color: .white
                    )
                    .offset(x: player.isPlaying ? 0 : 2)
                }
            }
            .scaleEffect(playBounce ? 0.88 : 1.0)
            .offset(y: playBounce ? 3 : 0)
            .contentShape(Circle())
        }
        .buttonStyle(TypewriterKeyStyle(depth: 4))
    }

    private var qualityBadge: some View {
        Button {
            HapticManager.shared.light()
            showQualitySheet = true
        } label: {
            Text(player.qualityButtonText)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(keyText)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    Capsule()
                        .fill(keyFace)
                )
        }
        .buttonStyle(TypewriterKeyStyle(depth: 2))
        .playerQualitySelectionAvailability()
    }

    private func labelKey(text: String, icon: MonologueIcon.IconType, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                MonologueIcon(icon: icon, size: 13, color: disabled ? keyText.opacity(0.3) : keyText)
                Text(text)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(disabled ? keyText.opacity(0.3) : keyText)
                    .tracking(0.8)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(colors: [keyFace, keyFace.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(Capsule().stroke(keyRim, lineWidth: 1))
            )
        }
        .buttonStyle(TypewriterKeyStyle(depth: 2))
        .disabled(disabled)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                MonologueIcon(icon: .close, size: 20, color: topBtnFg)
                    .frame(width: 44, height: 44)
                    .monologueGlassCircle()
                    .contentShape(Circle())
            }
            .buttonStyle(MonologueBouncingButtonStyle())

            Spacer()

            VStack(spacing: 2) {
                Text("TYPEWRITER")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(topBtnFg)
                    .tracking(3)

                if let name = player.currentSong?.name {
                    MarqueeText(
                        text: name,
                        font: MonologuePlayerFont.activeFont(
                            size: 10,
                            weight: .medium,
                            fallback: .system(size: 10, weight: .medium, design: .monospaced)
                        ),
                        color: topBtnFg.opacity(0.7),
                        speed: 24,
                        delayBeforeScroll: 1.8,
                        alignment: .center
                    )
                    .frame(maxWidth: 160)
                }
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { showMoreMenu.toggle() }
            } label: {
                MonologueIcon(icon: .more, size: 20, color: topBtnFg)
                    .frame(width: 44, height: 44)
                    .monologueGlassCircle()
                    .contentShape(Circle())
            }
            .buttonStyle(MonologueBouncingButtonStyle())
        }
        .padding(.horizontal, DeviceLayout.isPad ? 28 : 20)
    }

    // MARK: - Desk Background

    private var deskBackground: some View {
        ZStack {
            LinearGradient(colors: [desk, deskDeep], startPoint: .top, endPoint: .bottom)

            Canvas { ctx, size in
                for i in 0...Int(size.height / 6) {
                    let y = CGFloat(i) * 6
                    let op = 0.025 + abs(sin(CGFloat(i) * 0.18)) * 0.04
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y + sin(CGFloat(i) * 0.35) * 1.5))
                    ctx.stroke(p, with: .color(Color.black.opacity(op)), lineWidth: 0.8)
                }

                for i in 0...Int(size.width / 80) {
                    let x = CGFloat(i) * 80
                    ctx.fill(
                        Path(CGRect(x: x, y: 0, width: 16, height: size.height)),
                        with: .color(Color.white.opacity(colorScheme == .dark ? 0.012 : 0.018))
                    )
                }
            }

            LinearGradient(
                colors: [Color.black.opacity(0.14), .clear, Color.black.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Helpers

    private func formatTime(_ s: Double) -> String {
        guard !s.isNaN && !s.isInfinite else { return "0:00" }
        let t = Int(s)
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    private func streamInfoText(_ info: StreamInfo) -> String {
        var parts: [String] = []
        if let codec = info.audioCodec { parts.append(codec.uppercased()) }
        if let sr = info.sampleRate {
            if sr >= 1000 {
                let k = Double(sr) / 1000.0
                parts.append(k == k.rounded() ? "\(Int(k))kHz" : String(format: "%.1fkHz", k))
            } else { parts.append("\(sr)Hz") }
        }
        if let bd = info.bitDepth, bd > 0 { parts.append("\(bd)bit") }
        return parts.joined(separator: " · ")
    }
}
