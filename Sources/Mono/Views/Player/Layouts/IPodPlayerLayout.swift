import SwiftUI

/// iPod 播放器主题 — 以第五代 iPod 的白色塑料机身、黑色屏幕边框和实体 Click Wheel 为核心。
struct IPodPlayerLayout: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject private var lyricVM = LyricViewModel.shared

    @State private var showMoreMenu = false
    @State private var showQualitySheet = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showLyrics = false
    @State private var showQueueOnScreen = false
    @State private var queueSelectionIndex = 0
    @State private var isSeeking = false
    @State private var seekValue = 0.0
    @State private var centerBallOffset: CGSize = .zero
    @State private var centerBallDirectionLock = 0
    @State private var centerBallLastTriggerProjection: CGFloat = 0
    @State private var isWheelDragging = false

    private var isDark: Bool { colorScheme == .dark }
    private var bodyTop: Color { isDark ? Color(hex: "3B4046") : Color(hex: "F8F9FA") }
    private var bodyBottom: Color { isDark ? Color(hex: "1F2328") : Color(hex: "D6DBDF") }
    private var bodyInk: Color { isDark ? .white.opacity(0.88) : Color(hex: "2E3338") }
    private var wheelBase: Color { isDark ? Color(hex: "282D33") : Color(hex: "E6E9EB") }
    private var wheelInk: Color { isDark ? .white.opacity(0.73) : Color(hex: "687079") }
    private var screenBase: Color { Color(hex: "F1F4F7") }
    private var screenInk: Color { Color(hex: "202932") }
    private var screenMutedInk: Color { Color(hex: "65717D") }
    private var screenAccent: Color { Color(hex: "3478C7") }
    private var screenHeaderInk: Color { .white }
    private var currentTime: Double { isSeeking ? seekValue : timePublisher.currentTime }
    private var deviceBackground: Color {
        isDark ? .black : Color(hex: "B9C0C6")
    }

    var body: some View {
        GeometryReader { geometry in
            let toolbarTopInset = DeviceLayout.playerHeaderTopPadding
            let bottomInset = max(DeviceLayout.safeAreaBottom + 8, 16)
            let deviceWidth = min(geometry.size.width - 30, 410)
            let deviceHeight = min(
                max(320, geometry.size.height - toolbarTopInset - bottomInset),
                760
            )

            ZStack {
                deviceBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    iPodBody
                        .frame(width: deviceWidth, height: deviceHeight)
                    Spacer(minLength: 0)
                }
                .padding(.top, toolbarTopInset)
                .padding(.bottom, bottomInset)
            }
            .playerMoreMenuOverlay { anchorFrame in
                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        anchorFrame: anchorFrame,
                        onQuality: { showQualitySheet = true },
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
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
        .onAppear {
            syncQueueSelection()
        }
        .onChange(of: player.currentSong?.id) { _, _ in
            syncQueueSelection()
        }
    }

    private var queueSongs: [Song] {
        player.currentContextList.filter { $0.podcastRadioId == nil }
    }

    private func syncQueueSelection() {
        guard !queueSongs.isEmpty else {
            queueSelectionIndex = 0
            return
        }
        if let current = player.currentSong,
           let index = queueSongs.firstIndex(where: { $0.id == current.id }) {
            queueSelectionIndex = index
        } else {
            queueSelectionIndex = min(queueSelectionIndex, queueSongs.count - 1)
        }
    }

    private func moveQueueSelection(by offset: Int) {
        guard !queueSongs.isEmpty else { return }
        let next = min(max(queueSelectionIndex + offset, 0), queueSongs.count - 1)
        guard next != queueSelectionIndex else { return }
        queueSelectionIndex = next
        HapticManager.shared.light()
    }

    private func selectQueueItem() {
        guard queueSongs.indices.contains(queueSelectionIndex) else { return }
        HapticManager.shared.light()
        player.playFromQueue(song: queueSongs[queueSelectionIndex])
        showQueueOnScreen = false
    }

    private var iPodBody: some View {
        VStack(spacing: 0) {
            topHardware
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 14)

            screenBezel
                .padding(.horizontal, 18)

            Color.clear
                .frame(height: 18)

            clickWheel
                .frame(width: 210, height: 210)
                .padding(.bottom, 22)
        }
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [bodyTop, bodyBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(isDark ? 0.08 : 0.7), lineWidth: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 31, style: .continuous)
                .stroke(Color.black.opacity(isDark ? 0.35 : 0.10), lineWidth: 1)
                .padding(3)
        }
        .shadow(color: .black.opacity(isDark ? 0.48 : 0.25), radius: 30, y: 20)
    }

    private var topHardware: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                sfIcon("chevron.left", size: 18, color: bodyInk.opacity(0.78))
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "common_back"))

            Text("iPod")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(bodyInk.opacity(0.9))

            Spacer(minLength: 0)

            Text("MONO")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(bodyInk.opacity(0.36))

            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    showMoreMenu = true
                }
            } label: {
                sfIcon("ellipsis", size: 18, color: bodyInk.opacity(0.78))
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "player_more_title"))
            .playerMoreMenuAnchor()
        }
    }

    private var screenBezel: some View {
        VStack(spacing: 0) {
            ZStack {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(clockText(context.date))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                HStack(spacing: 6) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if showQueueOnScreen {
                                showQueueOnScreen = false
                            } else {
                                showLyrics.toggle()
                            }
                        }
                    } label: {
                        Text(showQueueOnScreen ? "MUSIC" : (showLyrics ? "LYRICS" : "NOW PLAYING"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    Text(player.isPlaying ? "▶" : "Ⅱ")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))

                    batteryIndicator
                }
            }
            .foregroundColor(screenHeaderInk.opacity(0.96))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "AFC5DB"),
                        Color(hex: "7693B0"),
                        Color(hex: "5B7897")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.55))
                    .frame(height: 0.7)
            }
            .shadow(color: .black.opacity(0.22), radius: 1, y: 1)

            Rectangle()
                .fill(Color(hex: "455E78").opacity(0.8))
                .frame(height: 1)

            if showQueueOnScreen {
                ipodQueueView
            } else if showLyrics {
                ipodLyricsView
            } else {
                trackInfoView
            }

            Slider(
                value: Binding(
                    get: { timePublisher.duration > 0 ? currentTime / timePublisher.duration : 0 },
                    set: { seekValue = $0 * timePublisher.duration }
                ),
                onEditingChanged: { editing in
                    isSeeking = editing
                    if !editing { player.seek(to: seekValue) }
                }
            )
            .tint(screenAccent)
            .padding(.horizontal, 9)

            HStack {
                Text(formatTime(currentTime))
                Spacer(minLength: 0)
                Text(formatTime(timePublisher.duration))
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(screenMutedInk)
            .padding(.horizontal, 10)
            .padding(.top, 1)
            .padding(.bottom, 8)
        }
        .background(screenBase)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(isDark ? 0.8 : 0.35), lineWidth: 3)
        )
        .overlay {
            screenTexture
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(isDark ? 0.5 : 0.22), radius: 4, y: 3)
    }

    private var screenTexture: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(isDark ? 0.035 : 0.06),
                    Color.clear,
                    Color.black.opacity(isDark ? 0.07 : 0.035)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                let lineColor = Color.black.opacity(0.025)
                for y in stride(from: 3, through: size.height, by: 4) {
                    context.fill(
                        Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)),
                        with: .color(lineColor)
                    )
                }
            }
        }
        .blendMode(.multiply)
        .opacity(0.55)
    }

    private var trackInfoView: some View {
        HStack(spacing: 12) {
            ZStack {
                CachedAsyncImage(url: player.currentSong?.coverUrl?.sized(500)) {
                    ZStack {
                        Color.black.opacity(0.05)
                        sfIcon("music.note", size: 24, color: screenMutedInk.opacity(0.7))
                    }
                }
                .aspectRatio(1, contentMode: .fill)

                DynamicArtworkOverlay(cornerRadius: 2)
            }
            .frame(width: 106, height: 106)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Color.black.opacity(0.2), lineWidth: 0.7)
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(player.currentSong?.name ?? String(localized: "暂无歌曲"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(screenInk)
                    .lineLimit(2)

                Text(player.currentSong?.artistName ?? String(localized: "未知歌手"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(screenMutedInk)
                    .lineLimit(1)

                Text(player.currentSong?.al?.name ?? "")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(screenMutedInk.opacity(0.78))
                    .lineLimit(1)

                if let lyric = lyricVM.currentLineText, !lyric.isEmpty {
                    Text(lyric)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(screenAccent.opacity(0.92))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
    }

    private var ipodLyricsView: some View {
        VStack(spacing: 6) {
            if lyricVM.isLoading {
                ProgressView()
                    .tint(screenAccent)
                    .frame(maxWidth: .infinity, minHeight: 106)
            } else if !lyricVM.hasLyrics {
                Text("No Lyrics Available")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(screenMutedInk)
                    .frame(maxWidth: .infinity, minHeight: 106)
            } else {
                let index = lyricVM.currentLineIndex
                let lines = lyricVM.lyrics
                let previous = index > 0 ? lines[index - 1].text : ""
                let current = lyricVM.currentLineSafely?.text ?? ""
                let next = index + 1 < lines.count ? lines[index + 1].text : ""

                Text(previous)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(screenMutedInk.opacity(0.46))
                    .lineLimit(1)

                Text(current)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(screenAccent)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let translation = lyricVM.currentLineSafely?.translation, !translation.isEmpty {
                    Text(translation)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(screenMutedInk)
                        .lineLimit(1)
                }

                Text(next)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(screenMutedInk.opacity(0.46))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 128)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private var ipodQueueView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if queueSongs.isEmpty {
                        Text("队列为空")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(screenMutedInk)
                            .frame(maxWidth: .infinity, minHeight: 126)
                    } else {
                        ForEach(Array(queueSongs.enumerated()), id: \.offset) { index, song in
                            Button {
                                queueSelectionIndex = index
                                selectQueueItem()
                            } label: {
                                HStack(spacing: 8) {
                                    Text(String(format: "%02d", index + 1))
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(
                                            index == queueSelectionIndex
                                                ? .white.opacity(0.86)
                                                : screenMutedInk.opacity(0.72)
                                        )
                                        .frame(width: 22, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(song.name)
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(
                                                index == queueSelectionIndex
                                                    ? .white
                                                    : screenInk.opacity(0.88)
                                            )
                                            .lineLimit(1)

                                        Text(song.artistName)
                                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                            .foregroundColor(
                                                index == queueSelectionIndex
                                                    ? .white.opacity(0.72)
                                                    : screenMutedInk.opacity(0.8)
                                            )
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 0)

                                    if song.id == player.currentSong?.id {
                                        sfIcon(
                                            player.isPlaying ? "waveform" : "pause.fill",
                                            size: 10,
                                            color: index == queueSelectionIndex ? .white : screenAccent
                                        )
                                    }
                                }
                                .padding(.horizontal, 9)
                                .frame(maxWidth: .infinity, minHeight: 29)
                                .background {
                                    if index == queueSelectionIndex {
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(hex: "68A7E7"),
                                                        Color(hex: "3478C7"),
                                                        Color(hex: "2863A5")
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .overlay(alignment: .top) {
                                                Rectangle()
                                                    .fill(Color.white.opacity(0.36))
                                                    .frame(height: 0.6)
                                                    .clipShape(
                                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                    )
                                            }
                                    } else {
                                        Color.clear
                                    }
                                }
                                .overlay(alignment: .bottom) {
                                    if index != queueSelectionIndex {
                                        Rectangle()
                                            .fill(Color.black.opacity(0.08))
                                            .frame(height: 0.5)
                                            .padding(.leading, 30)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(IPodWheelButtonStyle())
                            .id(index)
                        }
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 7)
            }
            .scrollIndicators(.hidden)
            .frame(height: 138)
            .onChange(of: queueSelectionIndex) { _, index in
                withAnimation(.easeOut(duration: 0.16)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(queueSelectionIndex, anchor: .center)
            }
        }
    }

    private var clickWheel: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            wheelBase.opacity(isDark ? 0.96 : 1),
                            wheelBase.opacity(isDark ? 0.74 : 0.88),
                            wheelBase.opacity(isDark ? 0.92 : 0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(isDark ? 0.06 : 0.72), lineWidth: 1)
                }
                .overlay {
                    Circle()
                        .stroke(Color.black.opacity(isDark ? 0.35 : 0.10), lineWidth: 1)
                        .padding(3)
                }
                .shadow(color: .black.opacity(isDark ? 0.42 : 0.17), radius: 12, y: 8)

            Circle()
                .stroke(wheelInk.opacity(isDark ? 0.18 : 0.13), lineWidth: 1)
                .padding(24)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            wheelBase.opacity(isDark ? 0.86 : 0.96),
                            wheelBase.opacity(isDark ? 0.52 : 0.78)
                        ],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 64
                    )
                )
                .frame(width: 84, height: 84)
                .overlay {
                    Circle()
                        .stroke(wheelInk.opacity(isDark ? 0.2 : 0.15), lineWidth: 1)
                }
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(isDark ? 0.04 : 0.55), lineWidth: 1)
                        .padding(3)
                }
                .shadow(color: .black.opacity(isDark ? 0.18 : 0.08), radius: 4, y: 2)

            Button {
                if showQueueOnScreen {
                    moveQueueSelection(by: -1)
                } else {
                    HapticManager.shared.light()
                    player.previous()
                }
            } label: {
                sfIcon("backward.fill", size: 19, color: wheelInk)
                    .frame(width: 64, height: 54)
                    .contentShape(Rectangle())
            }
            .buttonStyle(IPodWheelButtonStyle())
            .offset(x: -70)
            .accessibilityLabel(String(localized: "上一首"))

            Button {
                if showQueueOnScreen {
                    moveQueueSelection(by: 1)
                } else {
                    HapticManager.shared.light()
                    player.next()
                }
            } label: {
                sfIcon("forward.fill", size: 19, color: wheelInk)
                    .frame(width: 64, height: 54)
                    .contentShape(Rectangle())
            }
            .buttonStyle(IPodWheelButtonStyle())
            .offset(x: 70)
            .accessibilityLabel(String(localized: "playback_next_track"))

            Button {
                HapticManager.shared.light()
                withAnimation(.easeInOut(duration: 0.2)) {
                    showQueueOnScreen.toggle()
                    if showQueueOnScreen {
                        syncQueueSelection()
                    }
                }
            } label: {
                Text("MENU")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(wheelInk)
                    .frame(width: 74, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(IPodWheelButtonStyle())
            .offset(y: -70)
            .accessibilityLabel(String(localized: "player_queue"))

            Button {
                guard !isWheelDragging else { return }
                if showQueueOnScreen {
                    selectQueueItem()
                } else {
                    HapticManager.shared.light()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showQueueOnScreen = true
                        syncQueueSelection()
                    }
                }
            } label: {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                bodyTop.opacity(isDark ? 0.72 : 1),
                                bodyBottom.opacity(isDark ? 0.86 : 0.90),
                                bodyBottom.opacity(isDark ? 1 : 0.76)
                            ],
                            center: UnitPoint(
                                x: 0.36 - centerBallOffset.width / 180,
                                y: 0.30 - centerBallOffset.height / 180
                            ),
                            startRadius: 1,
                            endRadius: 48
                        )
                    )
                    .frame(width: 68, height: 68)
                    .overlay {
                        Circle()
                            .stroke(wheelInk.opacity(isDark ? 0.34 : 0.22), lineWidth: 1.2)
                    }
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(isDark ? 0.08 : 0.34), lineWidth: 1)
                            .padding(5)
                    }
                    .overlay {
                        Ellipse()
                            .fill(Color.white.opacity(isDark ? 0.07 : 0.22))
                            .frame(width: 25, height: 9)
                            .blur(radius: 4)
                            .offset(
                                x: -7 - centerBallOffset.width * 0.14,
                                y: -16 - centerBallOffset.height * 0.14
                            )
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(IPodCenterBallButtonStyle(isDragging: isWheelDragging))
            .offset(centerBallOffset)
            .shadow(
                color: .black.opacity(isDark ? 0.28 : 0.18),
                radius: 4 + abs(centerBallOffset.width) * 0.08,
                x: -centerBallOffset.width * 0.22,
                y: 2.5 - centerBallOffset.height * 0.18
            )
            .animation(
                .interactiveSpring(response: 0.08, dampingFraction: 0.9),
                value: centerBallOffset
            )
            .simultaneousGesture(centerBallJoystickGesture)
            .accessibilityLabel(showQueueOnScreen ? "选择歌曲" : "打开播放列表")

            Button {
                HapticManager.shared.light()
                player.togglePlayPause()
            } label: {
                sfIcon(player.isPlaying ? "pause.fill" : "play.fill", size: 18, color: wheelInk)
                    .frame(width: 64, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(IPodWheelButtonStyle())
            .offset(y: 73)
            .accessibilityLabel(player.isPlaying ? String(localized: "暂停") : String(localized: "action_play"))
        }
        .frame(width: 210, height: 210)
    }

    private var centerBallJoystickGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let translation = value.translation
                let distance = hypot(translation.width, translation.height)
                guard distance > 0 else { return }

                // 中心球直径 68、内圈直径 84，最大位移限制为 8，
                // 确保球体边缘始终留在内圈边界以内。
                let maximumTravel: CGFloat = 8
                let resistedDistance = min(maximumTravel, distance * 0.54)
                let directionX = translation.width / distance
                let directionY = translation.height / distance

                isWheelDragging = true
                centerBallOffset = CGSize(
                    width: directionX * resistedDistance,
                    height: directionY * resistedDistance
                )

                if distance < 10 {
                    centerBallDirectionLock = 0
                    centerBallLastTriggerProjection = 0
                } else {
                    // 队列是线性列表，因此把 360° 方向映射到上下移动：
                    // 横向取左右，纵向取上下；斜向也会稳定地产生一次移动。
                    let direction: Int
                    let isHorizontal = abs(translation.width) >= abs(translation.height)
                    let projection = isHorizontal ? translation.width : translation.height
                    if isHorizontal {
                        direction = translation.width > 0 ? 1 : -1
                    } else {
                        direction = translation.height > 0 ? 1 : -1
                    }

                    if centerBallDirectionLock != direction {
                        centerBallDirectionLock = direction
                        centerBallLastTriggerProjection = 0
                    }

                    // 手指继续向同一方向拖动时，每跨过一个步进距离就继续移动，
                    // 不再只能在当前歌曲和下一首之间触发一次。
                    let stepDistance: CGFloat = 20
                    let travelled = CGFloat(direction) * (projection - centerBallLastTriggerProjection)
                    if travelled >= stepDistance {
                        let steps = max(1, Int(travelled / stepDistance))
                        for _ in 0..<steps {
                            performJoystickStep(direction: direction, isHorizontal: isHorizontal)
                        }
                        centerBallLastTriggerProjection += CGFloat(direction * steps) * stepDistance
                    }
                }
            }
            .onEnded { _ in
                centerBallDirectionLock = 0
                centerBallLastTriggerProjection = 0
                withAnimation(.spring(response: 0.36, dampingFraction: 0.58)) {
                    centerBallOffset = .zero
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    isWheelDragging = false
                }
            }
    }

    private func performJoystickStep(direction: Int, isHorizontal: Bool) {
        if showQueueOnScreen {
            moveQueueSelection(by: direction)
        } else if isHorizontal {
            HapticManager.shared.light()
            if direction > 0 {
                player.next()
            } else {
                player.previous()
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }

    private var batteryIndicator: some View {
        HStack(spacing: 1.5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(Color.white.opacity(0.92), lineWidth: 1)
                .frame(width: 22, height: 10)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Color(hex: "41C95A"))
                        .frame(width: 17, height: 6)
                        .padding(.leading, 2)
                }

            Capsule()
                .fill(Color.white.opacity(0.9))
                .frame(width: 2, height: 5)
        }
        .accessibilityLabel("电池电量")
    }

    private func clockText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func sfIcon(_ name: String, size: CGFloat, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(color)
            .symbolRenderingMode(.monochrome)
    }
}

private struct IPodWheelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .opacity(configuration.isPressed ? 0.68 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct IPodCenterBallButtonStyle: ButtonStyle {
    let isDragging: Bool

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed && !isDragging

        configuration.label
            .scaleEffect(isPressed ? 0.975 : 1)
            .offset(y: isPressed ? 1.5 : 0)
            .brightness(isPressed ? -0.035 : 0)
            .shadow(
                color: .black.opacity(isPressed ? 0.08 : 0.16),
                radius: isPressed ? 1.5 : 3.5,
                y: isPressed ? 1 : 2.5
            )
            .animation(.easeOut(duration: 0.1), value: isPressed)
    }
}
