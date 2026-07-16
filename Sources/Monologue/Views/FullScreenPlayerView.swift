import SwiftUI

/// 全屏播放器 - 路由层，根据主题切换不同布局
struct FullScreenPlayerView: View {
    @ObservedObject var player = PlayerManager.shared
    
    @ObservedObject private var themeManager = PlayerThemeManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var cinemaController = CinemaModeController.shared
    @Environment(\.colorScheme) private var envColorScheme

    var body: some View {
        ZStack {
            Group {
                if SettingsManager.shared.coverBgPlayer && !MinimalWhiteStyle.isActive {
                    PlaylistColorBackground(coverUrl: player.currentSong?.coverUrl?.sized(200))
                } else {
                    ThemedPageBackground()
                }
            }
            .ignoresSafeArea()

            Group {
                switch themeManager.currentTheme {
                case .classic:
                    if PetWhiteStyle.isActive {
                        PawcelainPlayerLayout()
                    } else {
                        ClassicPlayerLayout()
                    }
                case .vinyl:
                    VinylPlayerLayout()
                case .lyricFocus:
                    MinimalPlayerLayout()
                case .card:
                    CardPlayerLayout()
                case .neumorphic:
                    NeumorphicPlayerLayout()
                case .poster:
                    PosterPlayerLayout()
                        .compatFontDesign(nil)
                case .motoPager:
                    MotoPagerLayout()
                case .typewriter:
                    TypewriterPlayerLayout()
                case .pixel:
                    PixelPlayerLayout()
                        .compatFontDesign(nil)
                case .aqua:
                    AquaPlayerLayout()
                case .breathing:
                    BreathingPlayerLayout()
                case .cassette:
                    CassettePlayerLayout()
                case .radio:
                    RadioPlayerLayout()
                case .immersiveLyric:
                    ImmersiveLyricPlayerLayout()
                case .mangaChat:
                    MangaChatPlayerLayout()
                case .folk:
                    FolkPlayerLayout()
                case .game2048:
                    Game2048PlayerLayout()
                case .cinema:
                    // 沉浸模式已从主题体系移出（经右上角三点菜单进入），旧存档回退经典布局
                    ClassicPlayerLayout()
                }
            }
            .environment(\.colorScheme, MinimalWhiteStyle.isActive ? settings.nativeColorScheme : (themeManager.currentTheme.hasCustomBackground ? settings.nativeColorScheme : envColorScheme))

        }
        .compatFontDesign(nil)
        .monologueEdgeSwipeToDismiss()
        .fullScreenCover(isPresented: $cinemaController.isPresented) {
            AriaStageView()
        }
    }

    // MARK: - 播放器进度条组件（供默认播放器及共享布局复用）

    struct WaveformProgressBar: View {
        @Binding var currentTime: Double
        let duration: Double
        var color: Color = .monologueTextPrimary
        /// 未播放部分的不透明度（默认 0.2，越低越融入背景）
        var trackOpacity: Double = 0.2
        var isAnimating: Bool = true
        let onSeek: (Double) -> Void
        let onCommit: (Double) -> Void

        var body: some View {
            let progress = duration > 0 ? CGFloat(min(max(currentTime / duration, 0), 1)) : 0

            GlobalWaveformPlaybackProgressBar(
                progress: progress,
                isPlaying: isAnimating,
                color: color,
                trackOpacity: trackOpacity,
                fillColors: progressFillColors,
                onSeek: { p in onSeek(Double(p) * duration) },
                onCommit: { p in onCommit(Double(p) * duration) }
            )
        }

        private var progressFillColors: [Color] {
            if MinimalWhiteStyle.isActive { return [MinimalWhiteStyle.accent, MinimalWhiteStyle.accent] }
            if MangaStyle.isActive { return [MangaStyle.accentPink, MangaStyle.labelYellow] }
            if MujiStyle.isActive { return [MujiStyle.clay, MujiStyle.indigo.opacity(0.86)] }
            if NeumorphicStyle.isActive { return [NeumorphicStyle.accent, NeumorphicStyle.sage] }
            if CapsuleStyle.isActive { return CapsuleStyle.accentGradient }
            if SequoiaStyle.isActive { return [SequoiaStyle.accent, SequoiaStyle.aqua] }
            if LiquidGlassStyle.isActive { return [LiquidGlassStyle.accent, LiquidGlassStyle.cyan, LiquidGlassStyle.violet] }
            if ClayStyle.isActive { return [ClayStyle.sky, ClayStyle.peach] }
            if SignalStyle.isActive { return [SignalStyle.accent, SignalStyle.mint] }
            if BentoStyle.isActive { return [BentoStyle.tomato, BentoStyle.mustard] }
            return [color.opacity(0.66), color.opacity(0.96)]
        }
        
    }
}

/// 封面上的 AI 调音状态。进行中显示紧凑进度，完成后保留可展开的调音入口。
struct AIEqualizerArtworkStatusView: View {
    let accent: Color
    let isDarkArtwork: Bool

    @ObservedObject private var agent = AIEqualizerAgent.shared
    @ObservedObject private var player = PlayerManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var showTuningDetails = false

    private var foregroundColor: Color {
        isDarkArtwork ? .white : Color(hex: "111318")
    }

    private var tuningProgress: Double? {
        switch agent.phase {
        case let .sampling(progress):
            return min(0.72, max(0.02, progress * 0.72))
        case .requesting:
            switch agent.generationStage {
            case .preparing: return 0.76
            case .generating: return 0.84
            case .validating: return 0.92
            case .finalizing: return 0.97
            }
        case .applying:
            return 0.99
        case .idle, .ready, .failed:
            return nil
        }
    }

    private var appliedProfileName: String? {
        guard agent.isCurrentProposalApplied else { return nil }
        let name = agent.proposal?.profileName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }

    private var compactProfileName: String? {
        guard let name = appliedProfileName else { return nil }
        let characterLimit = 8
        guard name.count > characterLimit else { return name }
        return String(name.prefix(characterLimit)) + "…"
    }

    private var isVisible: Bool {
        tuningProgress != nil || appliedProfileName != nil
    }

    var body: some View {
        Group {
            if agent.showsPlayerTuningStatus, isVisible {
                Button(action: toggleProfileName) {
                    HStack(spacing: 5) {
                        if let name = compactProfileName, isExpanded {
                            Text(name)
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(foregroundColor)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .transition(
                                    .opacity.combined(
                                        with: .scale(scale: 0.96, anchor: .trailing)
                                    )
                                )
                        }

                        if let progress = tuningProgress {
                            Text("\(Int((progress * 100).rounded()))%")
                                .font(.system(size: 9, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(foregroundColor)
                                .contentTransition(.numericText())
                        }

                        AIEqualizerArtworkStatusGlyph(
                            progress: tuningProgress,
                            isComplete: appliedProfileName != nil,
                            reduceMotion: reduceMotion,
                            foregroundColor: foregroundColor
                        )
                    }
                    .padding(.leading, tuningProgress == nil && !isExpanded ? 3 : 8)
                    .padding(.trailing, 3)
                    .frame(height: 29)
                    .background {
                        AIEqualizerStatusGlassBackground(
                            accent: accent,
                            isDarkArtwork: isDarkArtwork
                        )
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(
                                foregroundColor.opacity(isDarkArtwork ? 0.24 : 0.18),
                                lineWidth: 0.6
                            )
                    }
                    .contentShape(Capsule(style: .continuous))
                    .fixedSize(horizontal: true, vertical: true)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                .accessibilityLabel(accessibilityText)
                .accessibilityHint(isExpanded ? String(localized: "ai_tuning_open_details") : "")
                .transition(.scale(scale: 0.92, anchor: .bottomTrailing).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $showTuningDetails, onDismiss: {
            isExpanded = false
        }) {
            NavigationStack {
                AIEqualizerLabView()
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: tuningProgress
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.18),
            value: isExpanded
        )
        .onChange(of: player.currentSong?.id) { _, _ in
            isExpanded = false
        }
        .onChange(of: agent.phase) { _, newPhase in
            if newPhase.isWorking {
                isExpanded = false
            }
        }
    }

    private var accessibilityText: String {
        if let name = appliedProfileName {
            return String(format: String(localized: "ai_tuning_player_notice"), name)
        }
        return agent.samplingStage.title
    }

    private func toggleProfileName() {
        guard appliedProfileName != nil else { return }
        if isExpanded {
            showTuningDetails = true
            return
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            isExpanded = true
        }
    }
}

private struct AIEqualizerStatusGlassBackground: View {
    let accent: Color
    let isDarkArtwork: Bool

    private var adaptiveWash: Color {
        isDarkArtwork ? Color.black.opacity(0.48) : Color.white.opacity(0.76)
    }

    var body: some View {
        if #available(iOS 26, *) {
            Capsule(style: .continuous)
                .fill(adaptiveWash)
                .glassEffect(.regular, in: .capsule)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(accent.opacity(isDarkArtwork ? 0.13 : 0.07))
                }
        } else {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(adaptiveWash)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .fill(accent.opacity(isDarkArtwork ? 0.13 : 0.07))
                }
        }
    }
}

private struct AIEqualizerArtworkStatusGlyph: View {
    let progress: Double?
    let isComplete: Bool
    let reduceMotion: Bool
    let foregroundColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(foregroundColor.opacity(isComplete ? 0.1 : 0.08))

            if let progress {
                Circle()
                    .stroke(foregroundColor.opacity(0.2), lineWidth: 1.1)

                Circle()
                    .trim(from: 0, to: min(1, max(0.02, progress)))
                    .stroke(
                        foregroundColor,
                        style: StrokeStyle(lineWidth: 1.35, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                TimelineView(
                    AppFrameRate.throttledTimeline(
                        maximumFramesPerSecond: 16,
                        paused: reduceMotion
                    )
                ) { timeline in
                    Canvas { context, size in
                        drawBars(
                            in: &context,
                            size: size,
                            time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                        )
                    }
                    .padding(5.5)
                }
            } else if isComplete {
                MonologueIcon(icon: .sparkle, size: 11, color: foregroundColor)
            }
        }
        .frame(width: 23, height: 23)
        .animation(.easeOut(duration: 0.2), value: progress)
    }

    private func drawBars(
        in context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        let amplitudes = [0.58, 0.92, 0.7]
        let barWidth = max(1.5, size.width * 0.16)
        let gap = max(1.3, size.width * 0.1)
        let totalWidth = barWidth * 3 + gap * 2
        let startX = (size.width - totalWidth) * 0.5

        for index in 0..<3 {
            let motion = reduceMotion ? 0.72 : 0.58 + 0.42 * abs(sin(time * 2.5 + Double(index) * 1.15))
            let height = max(2.2, size.height * amplitudes[index] * motion)
            let rect = CGRect(
                x: startX + CGFloat(index) * (barWidth + gap),
                y: (size.height - height) * 0.5,
                width: barWidth,
                height: height
            )
            context.fill(
                Path(roundedRect: rect, cornerRadius: barWidth * 0.5),
                with: .color(foregroundColor)
            )
        }
    }
}
