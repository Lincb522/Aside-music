//
//  AriaStageView.swift
//  Monologue
//
//  全新沉浸模式 —— folia-major 舞台世界观的 SwiftUI 复刻：
//  VisualizerShell（流体背景 + 分频几何漂浮体 + 暗角）承载舞台氛围，
//  classic 渲染器负责歌词叙事，字幕层提供翻译 / 下一句。
//
//  Chrome 遵循 folia 播放页语言：屏幕上没有通栏工具条，
//  只有底部居中的悬浮玻璃胶囊（FloatingPlayerControls：播放时收起为细进度条，
//  暂停或触碰时展开为完整控制），以及右下角的统一面板（UnifiedPanel：
//  封面信息 / 歌架 / 舞台调校三个 tab）。左上角一枚极简圆钮负责退出。
//

import SwiftUI
import Combine

// MARK: - 歌词仓库：LyricViewModel → AriaLine 管线

@MainActor
final class AriaLyricStore: ObservableObject {
    @Published private(set) var lines: [AriaLine] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        LyricViewModel.shared.$lyrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lyrics in
                self?.lines = AriaLyricEngine.buildLines(from: lyrics)
                AriaLayoutCache.shared.clear()
            }
            .store(in: &cancellables)
    }
}

// MARK: - 沉浸舞台

struct AriaStageView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared

    @StateObject private var lyricStore = AriaLyricStore()
    @StateObject private var audioPulse = CinemaAudioPulse()
    @StateObject private var stageColors = CoverColorExtractor()

    @AppStorage("ariaIntensity") private var intensityRaw = AriaIntensity.normal.rawValue
    @AppStorage("ariaShowTranslation") private var showTranslation = true
    @AppStorage("ariaGeometricBackground") private var geometricBackground = true
    @AppStorage("ariaWordRotation") private var wordRotation = true
    @AppStorage("ariaLyricsFontScale") private var fontScale = 1.0
    @AppStorage("ariaWordSpacing") private var wordSpacing = 0.7
    @AppStorage("ariaBreathing") private var breathingMultiplier = 1.0
    @AppStorage("ariaBackgroundOpacity") private var backgroundOpacity = 0.75

    @State private var showPanel = false
    @State private var panelTab: AriaPanelTab = .cover
    /// folia 首页歌架墙：全屏惯性封面长廊
    @State private var showShelfWall = false
    /// 胶囊展开态：暂停时或触碰后展开，播放中静置自动收起为细进度条
    @State private var capsuleExpanded = true
    @State private var chromeHidden = false
    /// 入场揭幕：背景先亮、歌词随后聚焦
    @State private var stageRevealed = false
    @State private var isDraggingSlider = false
    @State private var dragTimeValue: Double = 0
    @State private var lastInteractionAt = Date()

    private let idleTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    /// folia：播放中悬浮胶囊静置后收起为一条细进度
    private let capsuleCollapseDelay: TimeInterval = 4

    private var intensity: AriaIntensity {
        AriaIntensity(rawValue: intensityRaw) ?? .normal
    }

    private var palette: AriaPalette {
        AriaPalette.derive(
            dominant: stageColors.dominantColor,
            secondary: stageColors.secondaryColor
        )
    }

    private var stageSeed: Double {
        Double(abs((player.currentSong?.id ?? 1) % 100_000))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 舞台底座：流体背景 + 几何漂浮体 + 暗角
                AriaStageShell(
                    coverUrl: player.currentSong?.coverUrl?.sized(500),
                    palette: palette,
                    pulse: audioPulse,
                    isPlaying: player.isPlaying,
                    seed: stageSeed,
                    backgroundOpacity: backgroundOpacity,
                    reduceMotion: !geometricBackground
                )

                // 歌词舞台 + 字幕层：同一条时间轴逐帧驱动
                Group {
                    if lyricStore.lines.isEmpty {
                        emptyLyricsState
                    } else {
                        TimelineView(AppFrameRate.animationTimeline(
                            maximumFramesPerSecond: player.isPlaying ? 60 : 30,
                            paused: false
                        )) { _ in
                            let time = currentPlaybackTime

                            ZStack {
                                AriaClassicLyricStage(
                                    lines: lyricStore.lines,
                                    palette: palette,
                                    intensity: intensity,
                                    enableRotation: wordRotation,
                                    wordSpacing: wordSpacing,
                                    breathingMultiplier: breathingMultiplier,
                                    fontScale: fontScale,
                                    time: time,
                                    stageSize: geo.size
                                )
                                .frame(width: geo.size.width, height: geo.size.height * 0.7)
                                .frame(width: geo.size.width, height: geo.size.height)

                                VStack {
                                    Spacer()
                                    AriaSubtitleOverlay(
                                        lines: lyricStore.lines,
                                        palette: palette,
                                        time: time,
                                        showTranslation: showTranslation,
                                        chromeHidden: chromeHidden
                                    )
                                }
                            }
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .onTapGesture { handleStageTap() }
                // 入场揭幕：歌词层从轻微缩小 + 模糊中聚焦
                .opacity(stageRevealed ? 1 : 0)
                .scaleEffect(stageRevealed ? 1 : 0.94)
                .blur(radius: stageRevealed ? 0 : 8)

                // 左上角退出（folia 封面悬浮小圆钮语言：黑玻璃 + 白描边）
                VStack {
                    HStack {
                        exitButton
                        Spacer()
                    }
                    .padding(.top, DeviceLayout.headerTopPadding)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    Spacer()
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .opacity(chromeHidden ? 0 : 1)
                .allowsHitTesting(!chromeHidden)

                // 底部居中悬浮胶囊（folia FloatingPlayerControls）
                VStack {
                    Spacer()
                    AriaControlCapsule(
                        palette: palette,
                        expanded: capsuleExpanded,
                        isDragging: $isDraggingSlider,
                        dragValue: $dragTimeValue,
                        onExpand: {
                            markInteraction()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                capsuleExpanded = true
                            }
                        },
                        onInteract: { markInteraction() },
                        onToggleShelf: {
                            markInteraction()
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                                showShelfWall.toggle()
                            }
                        },
                        onTogglePanel: {
                            markInteraction()
                            panelTab = .cover
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                                showPanel.toggle()
                            }
                        }
                    )
                    .padding(.bottom, 22)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .opacity(chromeHidden ? 0 : 1)
                .offset(y: chromeHidden ? 24 : 0)
                .scaleEffect(chromeHidden ? 0.97 : 1)
                .allowsHitTesting(!chromeHidden)
                .animation(.easeOut(duration: 0.26), value: chromeHidden)

                // 右下统一面板（folia UnifiedPanel：从右下角生长出的玻璃卡片）
                if showPanel {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            AriaUnifiedPanel(
                                isOpen: $showPanel,
                                tab: $panelTab,
                                palette: palette,
                                maxHeight: geo.size.height - 56
                            )
                            .padding(.trailing, 16)
                            .padding(.bottom, 24)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .transition(
                        .scale(scale: 0.9, anchor: .bottomTrailing)
                            .combined(with: .opacity)
                    )
                }

                // 歌架墙（folia 首页 Grid3DSlider：全屏惯性封面长廊）
                if showShelfWall {
                    AriaShelfWall(isOpen: $showShelfWall, palette: palette)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                        .zIndex(10)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            audioPulse.start()
            OrientationManager.shared.enterLandscape()
            stageColors.extract(from: player.currentSong?.coverUrl?.sized(200).absoluteString)
            withAnimation(.easeOut(duration: 0.7).delay(0.15)) {
                stageRevealed = true
            }
        }
        .onDisappear {
            audioPulse.stop()
            OrientationManager.shared.exitLandscape()
        }
        .onReceive(idleTicker) { _ in
            audioPulse.reattachIfNeeded()
            guard capsuleExpanded, player.isPlaying, !isDraggingSlider, !showPanel, !showShelfWall else { return }
            if Date().timeIntervalSince(lastInteractionAt) >= capsuleCollapseDelay {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    capsuleExpanded = false
                }
            }
        }
        .onChange(of: player.currentSong?.id) { _, _ in
            markInteraction()
            audioPulse.resetForNewTrack()
        }
        .onChange(of: player.isPlaying) { _, playing in
            // folia：暂停时胶囊常驻展开
            if !playing {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    capsuleExpanded = true
                }
            }
            markInteraction()
        }
        .onChange(of: isDraggingSlider) { _, _ in markInteraction() }
        .task(id: player.currentSong?.coverUrl?.absoluteString) {
            stageColors.extract(from: player.currentSong?.coverUrl?.sized(200).absoluteString)
        }
    }

    // MARK: 空态

    @ViewBuilder
    private var emptyLyricsState: some View {
        if LyricViewModel.shared.isLoading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.7)))
        } else {
            Text(String(localized: "暂无歌词"))
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(palette.secondary)
                .opacity(0.5)
        }
    }

    // MARK: 时间源

    private var currentPlaybackTime: Double {
        if isDraggingSlider { return dragTimeValue }
        let raw = player.streamPlayer.currentTime
        if raw.isFinite && !raw.isNaN && raw >= 0 { return raw }
        return timePublisher.currentTime
    }

    // MARK: 交互

    private func markInteraction() {
        lastInteractionAt = Date()
    }

    private func handleStageTap() {
        // 面板开着时，点空白先收面板
        if showPanel {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) { showPanel = false }
            markInteraction()
            return
        }
        if chromeHidden {
            chromeHidden = false
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { capsuleExpanded = true }
        } else {
            chromeHidden = true
        }
        markInteraction()
    }

    // MARK: 退出钮

    private var exitButton: some View {
        Button {
            dismiss()
        } label: {
            MonologueIcon(icon: .back, size: 18, color: .white.opacity(0.9))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().fill(Color.black.opacity(0.25)))
                )
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }
}

// MARK: - 悬浮控制胶囊（folia FloatingPlayerControls）
//
//  收起态：60% 宽的细玻璃条，只剩进度与时间；
//  展开态：白色圆形播放键 + 歌名 + 进度 + 上一首/下一首/歌架。

private struct AriaControlCapsule: View {
    let palette: AriaPalette
    let expanded: Bool
    @Binding var isDragging: Bool
    @Binding var dragValue: Double
    let onExpand: () -> Void
    let onInteract: () -> Void
    let onToggleShelf: () -> Void
    let onTogglePanel: () -> Void

    @ObservedObject private var player = PlayerManager.shared

    private let maxWidth: CGFloat = 520

    var body: some View {
        ZStack {
            if expanded {
                expandedView
                    .padding(12)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                collapsedView
                    .padding(.horizontal, 18)
                    .frame(height: 38)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: expanded ? maxWidth : maxWidth * 0.62)
        .background(capsuleGlass(strong: expanded))
        .contentShape(Capsule())
        .onTapGesture { if !expanded { onExpand() } }
        .padding(.horizontal, 24)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: expanded)
    }

    // folia 玻璃：展开 black/40，收起 black/20，白 5% 描边
    private func capsuleGlass(strong: Bool) -> some View {
        Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(strong ? 0.30 : 0.16))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
    }

    // MARK: 展开态

    private var expandedView: some View {
        HStack(spacing: 12) {
            playButton

            VStack(spacing: 7) {
                Text(player.currentSong?.name ?? String(localized: "未在播放"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                AriaCapsuleProgressBar(
                    isDragging: $isDragging,
                    dragValue: $dragValue,
                    onInteract: onInteract
                )
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                smallButton(icon: .previous, size: 17) {
                    onInteract()
                    player.previous()
                }
                smallButton(icon: .next, size: 17) {
                    onInteract()
                    player.next()
                }
                smallButton(icon: .list, size: 16) {
                    onToggleShelf()
                }
                smallButton(icon: .settings, size: 16) {
                    onTogglePanel()
                }
            }
        }
    }

    /// folia：白底反色圆形播放键（primary 填充 / 背景色 icon）
    private var playButton: some View {
        Button {
            onInteract()
            player.togglePlayPause()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 48, height: 48)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 3)

                if player.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black.opacity(0.8)))
                } else {
                    MonologueIcon(
                        icon: player.isPlaying ? .pause : .play,
                        size: 20,
                        color: .black.opacity(0.85)
                    )
                    .offset(x: player.isPlaying ? 0 : 1)
                }
            }
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }

    private func smallButton(icon: MonologueIcon.IconType, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: size, color: .white)
                .opacity(0.55)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }

    // MARK: 收起态

    private var collapsedView: some View {
        AriaCapsuleProgressBar(
            isDragging: $isDragging,
            dragValue: $dragValue,
            onInteract: onInteract
        )
    }
}

// MARK: - 进度条（folia ProgressBar：1.5pt 级细条 + 等宽小字时间）

private struct AriaCapsuleProgressBar: View {
    @Binding var isDragging: Bool
    @Binding var dragValue: Double
    let onInteract: () -> Void

    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared

    var body: some View {
        HStack(spacing: 10) {
            Text(formatTime(isDragging ? dragValue : timePublisher.currentTime))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 34, alignment: .trailing)

            GeometryReader { geo in
                let duration = timePublisher.duration
                let progress: Double = duration > 0
                    ? min(max((isDragging ? dragValue : timePublisher.currentTime) / duration, 0), 1)
                    : 0
                let barHeight: CGFloat = isDragging ? 8 : 5
                let fillWidth: CGFloat = geo.size.width * CGFloat(progress)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: barHeight)

                    Capsule()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: max(fillWidth, barHeight), height: barHeight)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .animation(.easeInOut(duration: 0.15), value: isDragging)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard duration > 0 else { return }
                            isDragging = true
                            let p = min(max(value.location.x / geo.size.width, 0), 1)
                            dragValue = p * duration
                        }
                        .onEnded { value in
                            onInteract()
                            guard duration > 0 else { isDragging = false; return }
                            let p = min(max(value.location.x / geo.size.width, 0), 1)
                            isDragging = false
                            player.seek(to: p * duration)
                        }
                )
            }
            .frame(height: 24)

            Text(formatTime(timePublisher.duration))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 34, alignment: .leading)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "00:00" }
        let total = Int(max(0, seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
