//
//  AriaStageView.swift
//  Monologue
//
//  全新沉浸模式 —— folia-major 舞台世界观的 SwiftUI 复刻：
//  VisualizerShell（封面流体 + 音频光场 + 景深纹理）承载舞台氛围，
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
    private var sourceLyrics: [LyricLine] = []

    init() {
        LyricViewModel.shared.$lyrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lyrics in
                guard let self else { return }
                sourceLyrics = lyrics
                lines = AriaLyricEngine.buildLines(
                    from: lyrics,
                    forceUppercaseEnglish: UserDefaults.standard.bool(
                        forKey: "lyricsForceUppercaseEnglish"
                    )
                )
                AriaFoliaTokenCache.clear()
            }
            .store(in: &cancellables)
    }

    func rebuild(forceUppercaseEnglish: Bool) {
        lines = AriaLyricEngine.buildLines(
            from: sourceLyrics,
            forceUppercaseEnglish: forceUppercaseEnglish
        )
        AriaFoliaTokenCache.clear()
    }
}

// MARK: - 沉浸舞台

struct AriaStageView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var player = PlayerManager.shared
    /// 刻意不做 @ObservedObject：歌词由 TimelineView 逐帧驱动，
    /// 再订阅时间发布器会让整个舞台 body 每个时间 tick 重算一遍（双重驱动白耗 CPU）
    private let timePublisher = PlaybackTimePublisher.shared
    @ObservedObject private var bgManager = ImmersiveBackgroundManager.shared

    @StateObject private var lyricStore = AriaLyricStore()
    @StateObject private var audioPulse = CinemaAudioPulse()
    @StateObject private var stageColors = CoverColorExtractor()
    @ObservedObject private var perf = CinemaPerformanceGovernor.shared

    @AppStorage("ariaShowTranslation") private var showTranslation = true
    @AppStorage("ariaGeometricBackground") private var ambientMotion = true
    @AppStorage("ariaLyricsFontScale") private var fontScale = 1.0
    @AppStorage("ariaBackgroundOpacity") private var backgroundOpacity = 0.75
    @AppStorage("ariaLyricEffect") private var lyricEffectRaw = AriaLyricEffect.classic.rawValue
    @AppStorage("ariaLyricFont") private var lyricFontRaw = AriaLyricFontChoice.system.rawValue
    @AppStorage("ariaLyricAutoColor") private var lyricAutoColor = true
    @AppStorage("ariaLyricColorHex") private var lyricColorHex = "FFFFFF"
    @AppStorage("ariaLyricLayout") private var lyricLayoutRaw = AriaLyricLayoutChoice.center.rawValue
    @AppStorage("ariaLyricMaterialStyle") private var lyricMaterialStyleRaw = AriaLyricMaterialStyle.solid.rawValue
    @AppStorage("ariaLyricOpacity") private var lyricOpacity = 1.0
    @AppStorage("ariaLyricGlowStrength") private var lyricGlowStrength = 0.0
    @AppStorage("ariaLyricParticleDensity") private var particleDensity = 0.58
    @AppStorage("ariaLyricParticleSize") private var particleSize = 1.15
    @AppStorage("ariaLyricParticleMotion") private var particleMotion = true
    @AppStorage("ariaLyricGlassIntensity") private var glassIntensity = 0.64
    @AppStorage("ariaCustomLyricFontID") private var customFontID = ""
    @AppStorage("ariaForeignLyricFont") private var foreignLyricFontRaw = MonologuePlayerFont.followThemeRawValue
    @AppStorage("ariaForeignCustomLyricFontID") private var foreignCustomFontID = ""
    @AppStorage("lyricsForceUppercaseEnglish") private var forceUppercaseEnglish = false
    @AppStorage("ariaLyricDepthIntensity") private var lyricDepthIntensity = 0.68
    @AppStorage("ariaLyricEmboss") private var lyricEmbossEnabled = true
    @AppStorage("ariaCanopyCaptionTranslation") private var canopyCaptionTranslation = false

    @State private var showPanel = false
    @State private var panelTab: AriaPanelTab = .cover
    @State private var showLandscapeSettings = false
    @State private var showVideoSheet = false
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

    private var palette: AriaPalette {
        AriaPalette.derive(colors: stageColors.palette)
    }

    private var stageSeed: Double {
        Double(abs((player.currentSong?.id ?? 1) % 100_000))
    }

    private var lyricEffect: AriaLyricEffect {
        AriaLyricEffect.resolveStored(lyricEffectRaw)
    }

    private var lyricFont: AriaLyricFontChoice {
        AriaLyricFontChoice(rawValue: lyricFontRaw) ?? .system
    }

    /// 外语歌的独立字体；「复用中文字体」或中文歌一律回落到主歌词字体。
    /// 中文歌里夹带的英文因此始终使用中文字体自带的拉丁字形。
    private func effectiveLyricFont(
        for language: AriaLyricLanguage
    ) -> AriaLyricFontChoice {
        guard language == .foreign,
              foreignLyricFontRaw != MonologuePlayerFont.followThemeRawValue,
              let choice = AriaLyricFontChoice(rawValue: foreignLyricFontRaw) else {
            AriaLyricFontChoice.customFontIDOverride = nil
            return lyricFont
        }
        AriaLyricFontChoice.customFontIDOverride =
            choice == .custom ? foreignCustomFontID : nil
        return choice
    }

    private var lyricLayout: AriaLyricLayoutChoice {
        AriaLyricLayoutChoice(rawValue: lyricLayoutRaw) ?? .center
    }

    private var lyricMaterialStyle: AriaLyricMaterialStyle {
        AriaLyricMaterialStyle.resolveStored(lyricMaterialStyleRaw)
    }

    private var lyricTypography: AriaLyricTypographyConfiguration {
        AriaLyricTypographyConfiguration(
            style: lyricMaterialStyle,
            opacity: lyricOpacity,
            glowStrength: lyricGlowStrength,
            particleDensity: particleDensity,
            particleSize: particleSize,
            particleMotion: particleMotion,
            glassIntensity: glassIntensity
        )
    }

    /// 自定义字幕色（自动取色关闭时生效）
    private var customLyricColor: Color? {
        lyricAutoColor ? nil : Color(hex: lyricColorHex)
    }

    /// 歌词层调色板：自定义颜色覆盖 primary/accent，背景层仍用封面取色
    private var lyricPalette: AriaPalette {
        guard let custom = customLyricColor else { return palette }
        var p = palette
        p.primary = custom
        p.accent = custom
        p.accentCycle = []
        return p
    }

    /// 绑定的视频背景（歌曲优先，其次全局；旧上下文仅作兼容回退）
    private var videoURL: URL? {
        bgManager.resolvedVideoURL(for: player.currentSong, context: player.playContext)
    }

    /// 字幕排版位置 → 纵向偏移
    private func lyricLayoutOffset(stageHeight: CGFloat) -> CGFloat {
        switch lyricLayout {
        case .center: return 0
        case .lower: return stageHeight * 0.16
        case .upper: return -stageHeight * 0.16
        }
    }

    /// 歌词时间轴帧率：词入场弹簧由 SwiftUI 隐式动画按屏幕刷新率插值，
    /// 时间轴只负责推进 time 驱动的包络（辉光/浸染/呼吸），30fps 足够平滑。
    private var lyricFPS: Int {
        guard player.isPlaying else { return 12 }
        if lyricMaterialStyle == .particle {
            switch perf.tier {
            case .high: return 24
            case .medium: return 20
            case .low: return 16
            }
        }
        if lyricEffect.usesFullStage {
            switch perf.tier {
            case .high: return 24
            case .medium: return 20
            case .low: return 16
            }
        }
        switch perf.tier {
        case .high: return 30
        case .medium: return 24
        case .low: return 20
        }
    }

    var body: some View {
        // 帧闭包外提：这些值与帧无关，避免 60fps 逐帧重算（调色板派生含多次 UIColor 转换）
        let palette = self.palette
        let lyricPalette = self.lyricPalette
        let lyricEffect = self.lyricEffect
        let lyricLanguage = AriaLyricLanguage.resolve(lines: lyricStore.lines)
        // 翻译字体先于外语字体覆盖解析：确保 .custom 绑定的是主字体的导入 ID
        let translationFont: Font = {
            AriaLyricFontChoice.customFontIDOverride = nil
            return self.lyricFont.font(
                size: 20 * CGFloat(fontScale),
                weight: .medium
            )
        }()
        let lyricFont = effectiveLyricFont(for: lyricLanguage)
        let lyricTypography = self.lyricTypography
        let lyricDepthAmount = pow(min(max(lyricDepthIntensity, 0), 1), 0.72)

        GeometryReader { geo in
            ZStack {
                // 舞台底座：封面流体 + 音频光场 + 景深纹理
                AriaStageShell(
                    coverUrl: player.currentSong?.coverUrl?.sized(500),
                    palette: palette,
                    pulse: audioPulse,
                    isPlaying: player.isPlaying,
                    seed: stageSeed,
                    backgroundOpacity: backgroundOpacity,
                    reduceMotion: !ambientMotion,
                    videoURL: videoURL,
                    depthIntensity: lyricDepthIntensity
                )

                // 歌词舞台 + 字幕层：同一条时间轴逐帧驱动
                Group {
                    if lyricStore.lines.isEmpty {
                        emptyLyricsState
                    } else {
                        TimelineView(AppFrameRate.throttledTimeline(
                            maximumFramesPerSecond: lyricFPS,
                            paused: showLandscapeSettings || showVideoSheet
                        )) { _ in
                            let time = currentPlaybackTime
                            let activeIndex = AriaLyricEngine.activeLineIndex(
                                in: lyricStore.lines,
                                at: time
                            )
                            let activeLine = lyricStore.lines.indices.contains(activeIndex)
                                ? lyricStore.lines[activeIndex]
                                : nil

                            ZStack {
                                Group {
                                    if lyricEffect == .classic {
                                        if let activeLine {
                                            if lyricLanguage == .foreign {
                                                AriaForeignClassicLyricStage(
                                                    line: activeLine,
                                                    palette: lyricPalette.lineVariant(activeLine.id),
                                                    fontChoice: lyricFont,
                                                    fontScale: fontScale,
                                                    time: time,
                                                    stageSize: geo.size
                                                )
                                            } else {
                                                AriaClassicLyricStage(
                                                    line: activeLine,
                                                    palette: lyricPalette.lineVariant(activeLine.id),
                                                    fontChoice: lyricFont,
                                                    fontScale: fontScale,
                                                    time: time,
                                                    stageSize: geo.size
                                                )
                                            }
                                        }
                                    } else {
                                        AriaFoliaLyricStage(
                                            lines: lyricStore.lines,
                                            palette: lyricPalette,
                                            effect: lyricEffect,
                                            language: lyricLanguage,
                                            fontChoice: lyricFont,
                                            fontScale: fontScale,
                                            time: time,
                                            stageSize: geo.size
                                        )
                                    }
                                }
                                .id(
                                    "\(lyricEffect.rawValue)|\(lyricFont.cacheIdentity)|\(customFontID)|\(foreignLyricFontRaw)|\(foreignCustomFontID)|\(lyricLanguage)|\(lyricTypography)"
                                )
                                .frame(
                                    width: geo.size.width,
                                    height: lyricEffect.usesFullStage
                                        ? geo.size.height
                                        : geo.size.height * 0.7
                                )
                                .offset(
                                    y: lyricEffect.usesFullStage
                                        ? 0
                                        : lyricLayoutOffset(stageHeight: geo.size.height)
                                )
                                .frame(width: geo.size.width, height: geo.size.height)
                                .ariaLyricTypography(
                                    configuration: lyricTypography,
                                    palette: lyricPalette,
                                    time: time
                                )
                                .ariaLyricSpatialDepth(
                                    palette: lyricPalette,
                                    intensity: lyricDepthIntensity,
                                    time: time,
                                    motionEnabled: ambientMotion && player.isPlaying,
                                    usesFullStage: lyricEffect.usesFullStage,
                                    embossEnabled: lyricEmbossEnabled
                                )

                                // 天幕开启「小字显示翻译」后，翻译已内嵌到注音位，
                                // 不再叠加底部字幕胶囊
                                if showTranslation,
                                   !(lyricEffect == .canopy && canopyCaptionTranslation),
                                   let translation = activeLine?.translation,
                                   !translation.isEmpty,
                                   !chromeHidden {
                                    VStack {
                                        Spacer()
                                        AriaSubtitleOverlay(
                                            translation: translation,
                                            palette: lyricPalette,
                                            font: translationFont
                                        )
                                        .padding(.bottom, capsuleExpanded ? 118 : 62)
                                        .opacity(lyricTypography.opacity)
                                        .shadow(
                                            color: .white.opacity(
                                                lyricEmbossEnabled ? 0.18 * lyricDepthAmount : 0
                                            ),
                                            radius: 1.5,
                                            y: -1
                                        )
                                        .shadow(
                                            color: .black.opacity(
                                                lyricEmbossEnabled ? 0.4 * lyricDepthAmount : 0
                                            ),
                                            radius: CGFloat(2 + 3 * lyricDepthAmount),
                                            y: CGFloat(2 + 2 * lyricDepthAmount)
                                        )
                                    }
                                    .transition(.opacity)
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
                        HStack(spacing: 10) {
                            videoBackgroundToggleButton
                            settingsButton
                        }
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

                if showLandscapeSettings {
                    AriaLandscapeSettingsView(palette: palette) {
                        markInteraction()
                        withAnimation(.smooth(duration: 0.28)) {
                            showLandscapeSettings = false
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    .zIndex(20)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .compatFontDesign(nil)
        .environment(\.colorScheme, .dark)
        .fullScreenCover(isPresented: $showVideoSheet) {
            ImmersiveBackgroundSheet(palette: palette)
        }
        .onAppear {
            audioPulse.start()
            OrientationManager.shared.enterLandscape()
            // ProMotion 压回 60Hz：沉浸模式全屏动画在 120Hz 下渲染开销翻倍，是发热主源之一；
            // 录屏/投屏时系统还要逐帧抓取编码，进一步压到 30Hz。
            AppFrameRate.pushFrameRateCeiling(
                perf.isScreenCaptured ? 30 : 60,
                reason: "aria stage"
            )
            stageColors.extract(from: player.currentSong?.coverUrl?.sized(200).absoluteString)
            withAnimation(.easeOut(duration: 0.7).delay(0.15)) {
                stageRevealed = true
            }
        }
        .onDisappear {
            audioPulse.stop()
            OrientationManager.shared.exitLandscape()
            AppFrameRate.popFrameRateCeiling(reason: "aria stage")
            // 离开舞台清掉外语字体的自定义 ID 覆盖，避免污染设置页预览
            AriaLyricFontChoice.customFontIDOverride = nil
        }
        .onReceive(idleTicker) { _ in
            audioPulse.reattachIfNeeded()
            guard capsuleExpanded,
                  player.isPlaying,
                  !isDraggingSlider,
                  !showPanel,
                  !showShelfWall,
                  !showLandscapeSettings,
                  !showVideoSheet else {
                return
            }
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
        .onChange(of: forceUppercaseEnglish) { _, enabled in
            lyricStore.rebuild(forceUppercaseEnglish: enabled)
        }
        .onChange(of: perf.isScreenCaptured) { _, captured in
            AppFrameRate.pushFrameRateCeiling(
                captured ? 30 : 60,
                reason: "aria stage capture \(captured ? "on" : "off")"
            )
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

    private var settingsButton: some View {
        Button {
            markInteraction()
            withAnimation(.smooth(duration: 0.28)) {
                showLandscapeSettings = true
            }
        } label: {
            MonologueIcon(icon: .settings, size: 18, color: .white.opacity(0.9))
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

    /// 视频背景开关：开着 → 一键暂停（绑定保留）；有设定但关着 → 一键恢复；
    /// 完全没设定 → 跳到视频背景设置界面选择视频。
    private var videoBackgroundToggleButton: some View {
        let isActive = videoURL != nil

        return Button(action: toggleVideoBackground) {
            ZStack {
                MonologueIcon(
                    icon: .mv,
                    size: 17,
                    color: .white.opacity(isActive ? 0.9 : 0.5)
                )
                if isActive {
                    Capsule()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 1.6, height: 23)
                        .rotationEffect(.degrees(45))
                }
            }
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(Color.black.opacity(0.25)))
            )
            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(MonologueBouncingButtonStyle())
        .accessibilityLabel(
            isActive
                ? String(localized: "关闭视频背景")
                : String(localized: "开启视频背景")
        )
    }

    private func toggleVideoBackground() {
        markInteraction()

        if videoURL != nil {
            bgManager.videoBackgroundEnabled = false
            HapticManager.shared.light()
            return
        }

        let hasBinding = bgManager.boundVideo(
            for: player.currentSong,
            context: player.playContext
        ) != nil

        if hasBinding {
            bgManager.videoBackgroundEnabled = true
            HapticManager.shared.light()
        } else {
            showVideoSheet = true
        }
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
