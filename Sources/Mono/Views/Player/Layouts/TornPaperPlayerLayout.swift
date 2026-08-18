// THESIS: 用封面中被真正提取出的主体撕开播放器平面，拒绝把撕纸纹理贴在常规播放器骨架上。
// OWN-WORLD: 冷灰底纸、暖白撕页、封面原色油墨、锯齿纸边与少量胶带标记；不堆卡片。
// STORY: 用户先看见从封面跃出的主体，再沿撕口读到歌名、当前歌词、真实进度和播放控制。
// FIRST VIEWPORT: 上半屏是一张倾斜撕开的封面，主体越过撕口；下半屏是一整张连续纸页承载信息与控制。
// FORM: 撕纸拼贴播放器；精确方向由用户指定。FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md

import SwiftUI

struct TornPaperPlayerLayout: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject private var lyricVM = LyricViewModel.shared
    @ObservedObject private var likeManager = LikeManager.shared
    @StateObject private var colorExtractor = CoverColorExtractor(minimumColorCount: 3)

    @State private var cutoutImage: UIImage?
    @State private var cutoutBackdropImage: UIImage?
    @State private var isCutoutLoading = false
    @State private var isPresented = false
    @State private var isSeeking = false
    @State private var seekTime: Double = 0
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showMoreMenu = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false

    private var paper: Color {
        colorScheme == .dark ? Color(hex: "22201D") : Color(hex: "F4F0E7")
    }

    private var paperRaised: Color {
        colorScheme == .dark ? Color(hex: "302D28") : Color(hex: "FFFDF7")
    }

    private var ink: Color {
        colorScheme == .dark ? Color(hex: "F1EEE6") : Color(hex: "181716")
    }

    private var mutedInk: Color {
        colorScheme == .dark ? Color(hex: "A9A39A") : Color(hex: "726D65")
    }

    private var accent: Color {
        colorExtractor.resolvedURL == coverIdentity
            ? colorExtractor.dominantColor
            : Color(hex: "D96850")
    }

    private var coverURL: URL? {
        player.currentSong?.coverUrl?.sized(1_000)
    }

    private var coverIdentity: String? {
        coverURL?.absoluteString
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                collageBackground

                TornPaperShape(variant: 0)
                    .fill(paper)
                    .overlay(
                        TornPaperTexture(ink: ink.opacity(0.055))
                            .mask(TornPaperShape(variant: 0))
                    )
                    .padding(.horizontal, 5)
                    .padding(.top, proxy.safeAreaInsets.top > 0 ? 18 : 34)
                    .padding(.bottom, -18)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.42 : 0.18), radius: 18, y: 9)

                VStack(spacing: 0) {
                    header
                        .padding(.top, proxy.safeAreaInsets.top > 0 ? 4 : 10)
                        .padding(.horizontal, 18)

                    artworkStage(height: artworkHeight(for: proxy.size))
                        .padding(.top, 2)

                    songIdentity
                        .padding(.horizontal, 24)
                        .padding(.top, 7)

                    lyricStrip
                        .padding(.horizontal, 21)
                        .padding(.top, 12)

                    Spacer(minLength: 8)

                    progressSection
                        .padding(.horizontal, 24)

                    playbackControls
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .padding(.bottom, max(16, proxy.safeAreaInsets.bottom + 8))
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        anchorFrame: moreMenuAnchorFrame(in: proxy),
                        isDarkBackground: colorScheme == .dark,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: .topLeading
                    )
                    .zIndex(30)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .opacity(isPresented ? 1 : 0)
            .scaleEffect(isPresented ? 1 : 0.992)
        }
        .onAppear {
            colorExtractor.extract(from: coverIdentity)
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) {
                isPresented = true
            }
        }
        .onChange(of: coverIdentity) { _, newValue in
            colorExtractor.extract(from: newValue)
        }
        .task(id: coverIdentity) {
            await loadSubjectCutout()
        }
        .monoSheet(isPresented: $showPlaylist, preset: .standard) {
            PlaylistPopupView()
        }
        .monoSheet(isPresented: $showQualitySheet, preset: .standard) {
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentQQQuality: player.qqMusicQuality,
                isQQMusic: player.currentSong?.isQQMusic == true,
                onSelectNetease: { quality in
                    player.switchQuality(quality)
                    showQualitySheet = false
                },
                onSelectQQ: { quality in
                    player.switchQQMusicQuality(quality)
                    showQualitySheet = false
                },
                songMid: player.currentSong?.qqMid,
                songId: player.currentSong?.id,
                isQishui: player.currentSong?.isQishui == true,
                qishuiTrackId: player.currentSong?.qishuiTrackId,
                onSelectQishui: { info in
                    player.switchQishuiQuality(info)
                    showQualitySheet = false
                }
            )
        }
        .fullScreenCover(isPresented: $showEQSettings) {
            NavigationStack { MonoAudioCenterView() }
        }
        .monoSheet(isPresented: $showThemePicker, preset: .themePicker) {
            PlayerThemePickerSheet()
        }
    }
}

private extension TornPaperPlayerLayout {
    var collageBackground: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color(hex: "CBC6BC"))

            if let coverURL {
                CachedAsyncImage(url: coverURL, width: 420, height: 820) {
                    Color.clear
                }
                .scaledToFill()
                .blur(radius: 34)
                .saturation(0.72)
                .opacity(colorScheme == .dark ? 0.42 : 0.32)
                .scaleEffect(1.15)
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(colorScheme == .dark ? 0.1 : 0.02),
                    Color.black.opacity(colorScheme == .dark ? 0.52 : 0.16),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            DynamicCoverPaletteLayer(colors: colorExtractor.palette, opacity: colorScheme == .dark ? 0.34 : 0.18)
        }
        .ignoresSafeArea()
    }

    var header: some View {
        HStack(spacing: 8) {
            paperIconButton(icon: .close, accessibilityLabel: String(localized: "关闭")) {
                dismiss()
            }

            Spacer(minLength: 8)

            Button {
                showQualitySheet = true
            } label: {
                Text(player.qualityButtonText)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(ink)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 40)
                    .background(
                        TornPaperShape(variant: 3)
                            .fill(paperRaised)
                            .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                    )
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .playerQualitySelectionAvailability()

            paperIconButton(icon: .more, accessibilityLabel: String(localized: "更多")) {
                showMoreMenu.toggle()
            }
        }
    }

    func moreMenuAnchorFrame(in proxy: GeometryProxy) -> CGRect {
        let buttonWidth: CGFloat = 43
        let buttonHeight: CGFloat = 41
        let topPadding: CGFloat = proxy.safeAreaInsets.top > 0 ? 4 : 10
        return CGRect(
            x: max(12, proxy.size.width - 18 - buttonWidth),
            y: topPadding,
            width: buttonWidth,
            height: buttonHeight
        )
    }

    func artworkHeight(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.43, 292), 390)
    }

    func artworkStage(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(accent.opacity(colorScheme == .dark ? 0.2 : 0.14))
                .frame(width: height * 0.78, height: height * 0.54)
                .blur(radius: 24)
                .offset(y: -height * 0.08)
                .allowsHitTesting(false)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(accent.opacity(0.9))
                    .frame(width: 12)
                Spacer(minLength: 0)
            }
            .frame(height: height * 0.58)
            .rotationEffect(.degrees(2.2))
            .offset(y: 12)

            if let coverURL {
                Group {
                    if let cutoutBackdropImage {
                        Image(uiImage: cutoutBackdropImage)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                    } else {
                        CachedAsyncImage(url: coverURL, width: 760, height: 760) {
                            paperRaised
                        }
                        .scaledToFill()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: height * 0.71)
                .clipShape(TornPaperShape(variant: 1))
                .overlay(
                    TornPaperShape(variant: 1)
                        .stroke(paperRaised.opacity(0.88), lineWidth: 2.6)
                )
                .rotationEffect(.degrees(-1.4))
                .padding(.horizontal, 30)
                .offset(y: 8)
                .shadow(color: .black.opacity(0.24), radius: 12, y: 7)
            } else {
                TornPaperShape(variant: 1)
                    .fill(paperRaised)
                    .overlay(MonoIcon(icon: .musicNote, size: 54, color: mutedInk.opacity(0.42)))
                    .rotationEffect(.degrees(-1.4))
                    .padding(.horizontal, 30)
                    .frame(height: height * 0.71)
                    .offset(y: 8)
            }

            if let cutoutImage {
                Image(uiImage: cutoutImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: height * 0.71)
                    .rotationEffect(.degrees(-0.5))
                    .padding(.horizontal, 30)
                    .shadow(color: paperRaised.opacity(colorScheme == .dark ? 0.34 : 0.62), radius: 2)
                    .shadow(color: .black.opacity(0.31), radius: 11, y: 8)
                    .offset(y: 2)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .offset(y: 7))
                    )
            } else if isCutoutLoading {
                ProgressView()
                    .tint(ink.opacity(0.65))
                    .frame(width: 30, height: 30)
                    .padding(11)
                    .background(Circle().fill(paperRaised.opacity(0.9)))
                    .offset(y: 7)
            }

        }
        .frame(height: height)
        .clipped()
    }

    var songIdentity: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .bottomLeading) {
                TornPaperShape(variant: 9)
                    .fill(accent.opacity(colorScheme == .dark ? 0.42 : 0.3))
                    .frame(width: 92, height: 11)
                    .rotationEffect(.degrees(-1.5))
                    .offset(x: 3, y: -1)

                Text(player.currentSong?.name ?? String(localized: "暂无歌曲"))
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .tracking(-0.65)
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }

            Text(songMetadata)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(mutedInk)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var songMetadata: String {
        let artist = player.currentSong?.artistName ?? String(localized: "未知歌手")
        let album = player.currentSong?.al?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return album.isEmpty ? artist : "\(artist)  /  \(album)"
    }

    var lyricStrip: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .leading) {
                TornPaperShape(variant: 4)
                    .fill(accent.opacity(colorScheme == .dark ? 0.48 : 0.34))
                    .frame(height: 9)
                    .rotationEffect(.degrees(-1.2))
                    .offset(y: 8)

                Text(currentLyric)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .id(lyricVM.currentLineIndex)
                    .transition(.opacity.combined(with: .offset(y: 5)))
            }

            if let translation = lyricVM.currentLineSafely?.translation,
               !translation.isEmpty {
                Text(translation.monoLyricDisplayText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(mutedInk)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: lyricVM.currentLineIndex)
    }

    var currentLyric: String {
        let lyric = lyricVM.currentLineText?.monoLyricDisplayText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return lyric.isEmpty ? String(localized: "暂无歌词") : lyric
    }

    var progressSection: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let duration = max(timePublisher.duration, 0)
                let shownTime = isSeeking ? seekTime : timePublisher.currentTime
                let progress = duration > 0 ? min(max(shownTime / duration, 0), 1) : 0

                ZStack(alignment: .leading) {
                    TornProgressStrip(progress: 1)
                        .fill(mutedInk.opacity(0.19))

                    TornProgressStrip(progress: progress)
                        .fill(accent)

                    Circle()
                        .fill(paperRaised)
                        .overlay(Circle().stroke(ink.opacity(0.24), lineWidth: 0.8))
                        .frame(width: 13, height: 13)
                        .offset(x: max(0, geometry.size.width * progress - 6.5))
                }
                .contentShape(Rectangle().inset(by: -10))
                .gesture(seekGesture(width: geometry.size.width, duration: duration))
            }
            .frame(height: 14)

            HStack {
                Text(formatTime(isSeeking ? seekTime : timePublisher.currentTime))
                Spacer()
                Text(formatTime(timePublisher.duration))
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(mutedInk)
            .monospacedDigit()
        }
    }

    var playbackControls: some View {
        HStack(spacing: 12) {
            Button {
                toggleLike()
            } label: {
                MonoIcon(
                    icon: isCurrentSongLiked ? .liked : .like,
                    size: 19,
                    color: isCurrentSongLiked ? accent : ink
                )
                .frame(width: 42, height: 42)
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .accessibilityLabel(String(localized: "收藏"))

            Spacer(minLength: 0)

            Button { player.previous() } label: {
                MonoIcon(icon: .previous, size: 21, color: ink)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .accessibilityLabel(String(localized: "上一首"))

            Button { player.togglePlayPause() } label: {
                TornPaperShape(variant: 5)
                    .fill(ink)
                    .frame(width: 62, height: 58)
                    .overlay(
                        MonoIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 23,
                            color: paperRaised
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .accessibilityLabel(player.isPlaying ? String(localized: "暂停") : String(localized: "播放"))

            Button { player.next() } label: {
                MonoIcon(icon: .next, size: 21, color: ink)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .accessibilityLabel(String(localized: "下一首"))

            Spacer(minLength: 0)

            Button { showPlaylist = true } label: {
                MonoIcon(icon: .list, size: 19, color: ink)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .accessibilityLabel(String(localized: "播放列表"))
        }
    }

    func paperIconButton(
        icon: MonoIcon.IconType,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            TornPaperShape(variant: 7)
                .fill(paperRaised)
                .frame(width: 43, height: 41)
                .overlay(MonoIcon(icon: icon, size: 16, color: ink))
                .shadow(color: .black.opacity(0.13), radius: 3, y: 2)
        }
        .buttonStyle(MonoBouncingButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    func seekGesture(width: CGFloat, duration: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard width > 0, duration > 0 else { return }
                isSeeking = true
                let progress = min(max(value.location.x / width, 0), 1)
                seekTime = progress * duration
            }
            .onEnded { value in
                guard width > 0, duration > 0 else {
                    isSeeking = false
                    return
                }
                let progress = min(max(value.location.x / width, 0), 1)
                let target = progress * duration
                isSeeking = false
                player.seek(to: target)
            }
    }

    var isCurrentSongLiked: Bool {
        guard let song = player.currentSong else { return false }
        return likeManager.isLiked(id: song.id, isQQMusic: song.isQQMusic)
    }

    func toggleLike() {
        guard let song = player.currentSong else { return }
        likeManager.toggleLike(songId: song.id, isQQMusic: song.isQQMusic, song: song)
    }

    func loadSubjectCutout() async {
        cutoutImage = nil
        cutoutBackdropImage = nil
        guard let coverURL, let coverIdentity else {
            isCutoutLoading = false
            return
        }

        isCutoutLoading = true
        guard let image = await ImageLoadCoordinator.shared.loadImage(url: coverURL, maxSize: 760),
              !Task.isCancelled else {
            isCutoutLoading = false
            return
        }

        let composition = await NativeSubjectCutoutEngine.shared.cutoutComposition(
            from: image,
            cacheKey: coverIdentity
        )
        guard !Task.isCancelled, self.coverIdentity == coverIdentity else { return }

        withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.86)) {
            cutoutImage = composition?.sticker
            cutoutBackdropImage = composition?.backdrop
            isCutoutLoading = false
        }
    }

    func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct TornPaperShape: Shape {
    let variant: Int

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        let horizontalSteps = max(8, Int(rect.width / 20))
        let verticalSteps = max(6, Int(rect.height / 18))
        let amplitude = min(7, max(2.2, min(rect.width, rect.height) * 0.055))

        return Path { path in
            path.move(to: CGPoint(x: rect.minX + jitter(0, amplitude), y: rect.minY + jitter(13, amplitude)))

            for index in 1...horizontalSteps {
                let progress = CGFloat(index) / CGFloat(horizontalSteps)
                path.addLine(to: CGPoint(
                    x: rect.minX + rect.width * progress,
                    y: rect.minY + jitter(index, amplitude)
                ))
            }
            for index in 1...verticalSteps {
                let progress = CGFloat(index) / CGFloat(verticalSteps)
                path.addLine(to: CGPoint(
                    x: rect.maxX + jitter(index + 31, amplitude),
                    y: rect.minY + rect.height * progress
                ))
            }
            for index in 1...horizontalSteps {
                let progress = CGFloat(index) / CGFloat(horizontalSteps)
                path.addLine(to: CGPoint(
                    x: rect.maxX - rect.width * progress,
                    y: rect.maxY + jitter(index + 67, amplitude)
                ))
            }
            for index in 1...verticalSteps {
                let progress = CGFloat(index) / CGFloat(verticalSteps)
                path.addLine(to: CGPoint(
                    x: rect.minX + jitter(index + 101, amplitude),
                    y: rect.maxY - rect.height * progress
                ))
            }
            path.closeSubpath()
        }
    }

    private func jitter(_ index: Int, _ amplitude: CGFloat) -> CGFloat {
        let value = sin(Double(index * 47 + variant * 83) * 0.73)
            + sin(Double(index * 19 + variant * 29) * 1.31) * 0.46
        return CGFloat(value) * amplitude * 0.58
    }
}

private struct TornProgressStrip: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        let width = rect.width * CGFloat(min(max(progress, 0), 1))
        guard width > 0 else { return Path() }
        let target = CGRect(x: rect.minX, y: rect.midY - 2.5, width: width, height: 5)
        return TornPaperShape(variant: 8).path(in: target)
    }
}

private struct TornPaperTexture: View {
    let ink: Color

    var body: some View {
        Canvas { context, size in
            for index in 0..<34 {
                let y = size.height * CGFloat(index + 1) / 35
                let inset = CGFloat((index * 37) % 29)
                var line = Path()
                line.move(to: CGPoint(x: inset, y: y))
                line.addLine(to: CGPoint(x: max(inset, size.width - inset * 0.55), y: y + CGFloat(index % 3 - 1)))
                context.stroke(line, with: .color(ink), lineWidth: 0.35)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
