import SwiftUI

/// 沉浸模式全局入口（独立于播放器主题，从播放器右上角三点菜单进入）
@MainActor
final class CinemaModeController: ObservableObject {
    static let shared = CinemaModeController()
    @Published var isPresented = false

    private init() {}

    /// 先锁定横屏再呈现，保证首帧就是横屏布局
    func present() {
        OrientationManager.shared.enterLandscape()
        isPresented = true
    }
}

/// 影院沉浸播放器 — 4K 视频背景（按歌曲/歌单绑定）+ 快闪歌词 + 极简控件
struct CinemaVideoPlayerLayout: View {
    /// 舞台模式：沉浸（快闪歌词）/ 常规横屏（左瀑布流歌词 + 右封面）
    enum StageMode: String {
        case immersive
        case classic
    }

    @Environment(\.dismiss) var dismiss
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var bgManager = ImmersiveBackgroundManager.shared

    @AppStorage("cinemaStageMode") private var stageModeRaw = StageMode.immersive.rawValue
    @AppStorage("cinemaLyricStyle") private var lyricStyleRaw = CinemaLyricStyle.folia.rawValue
    @AppStorage("cinemaBackgroundStyle") private var backgroundStyleRaw = CinemaBackgroundStyle.galaxy.rawValue
    @State private var showLyrics = true
    @State private var showStageSettings = false
    @State private var chromeHidden = false
    /// 沉浸锁定：净屏且点击不再唤出控制栏，只弹出临时解锁按钮
    @State private var immersiveLocked = false
    @State private var showLockHint = false
    @State private var lockHintToken = 0
    @State private var showShelf = false
    @State private var showAssignSheet = false
    @State private var showMoreMenu = false
    @State private var showQualitySheet = false
    @State private var showEQSettings = false
    @State private var isDraggingSlider = false
    @State private var dragTimeValue: Double = 0

    /// 实时音频脉冲：驱动粒子星河、节拍辉光与封面呼吸
    @StateObject private var audioPulse = CinemaAudioPulse()
    /// 性能调节器：发热/省电时自动降帧
    @ObservedObject private var perf = CinemaPerformanceGovernor.shared
    /// 水平仪视差：陀螺仪姿态驱动镜头微倾
    @State private var motionParallax = CinemaMotionParallax()
    /// folia 背景层取色
    @StateObject private var stageColors = CoverColorExtractor()
    /// 净屏自动隐藏计时
    @State private var lastInteractionAt = Date()
    private let idleTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let idleHideDelay: TimeInterval = 6

    private var stageMode: StageMode {
        StageMode(rawValue: stageModeRaw) ?? .immersive
    }

    private var lyricStyle: CinemaLyricStyle {
        CinemaLyricStyle(rawValue: lyricStyleRaw) ?? .folia
    }

    private var backgroundStyle: CinemaBackgroundStyle {
        CinemaBackgroundStyle(rawValue: backgroundStyleRaw) ?? .galaxy
    }

    /// folia 背景所需的封面取色
    private var stagePalette: VJPalette {
        VJPalette.derive(
            dominant: stageColors.dominantColor,
            secondary: stageColors.secondaryColor
        )
    }

    private var videoURL: URL? {
        bgManager.resolvedVideoURL(for: player.currentSong, context: player.playContext)
    }

    private var anyOverlayOpen: Bool {
        showAssignSheet || showMoreMenu || showQualitySheet || showEQSettings || showStageSettings || isDraggingSlider
    }

    private func markInteraction() {
        lastInteractionAt = Date()
    }

    private func toggleChrome() {
        // 沉浸锁定：点击只弹出临时解锁按钮
        if immersiveLocked {
            flashLockHint()
            return
        }
        // 常规横屏模式控制栏常驻，避免误触后找不到按钮
        guard stageMode == .immersive else { return }
        withAnimation(.easeInOut(duration: 0.25)) { chromeHidden.toggle() }
        markInteraction()
    }

    /// 锁定状态下点击屏幕：短暂弹出解锁按钮
    private func flashLockHint() {
        lockHintToken += 1
        let token = lockHintToken
        withAnimation(.easeOut(duration: 0.2)) { showLockHint = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if token == lockHintToken {
                withAnimation(.easeIn(duration: 0.3)) { showLockHint = false }
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                background(size: geo.size)

                // 舞台铺满全屏；控制栏是浮层，不参与纵向布局分配（横屏高度有限，
                // 若用 VStack 串联，固定尺寸的舞台会把控制栏挤出屏幕）
                centerStage(size: geo.size)
                    .frame(width: geo.size.width, height: geo.size.height)

                VStack(spacing: 0) {
                    if !chromeHidden {
                        topBar
                            .padding(.top, DeviceLayout.headerTopPadding)
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .simultaneousGesture(TapGesture().onEnded { markInteraction() })
                    }

                    Spacer(minLength: 0)

                    if !chromeHidden {
                        bottomBar
                            .frame(maxWidth: 640)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 12)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .simultaneousGesture(TapGesture().onEnded { markInteraction() })
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)

                if !showShelf {
                    // 右缘唤出热区（窄条，不抢占画布交互）
                    HStack {
                        Spacer()
                        Color.clear
                            .frame(width: 22)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 12)
                                    .onEnded { value in
                                        if value.translation.width < -30 {
                                            openShelf()
                                        }
                                    }
                            )
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }

                // 3D 歌架：最顶层浮层（盖过控制栏），关闭靠右上角常驻按钮/右扫
                if showShelf {
                    HStack {
                        Spacer()
                        CinemaShelfView(pulse: audioPulse, accent: .monologueAccent)
                            .frame(maxHeight: .infinity)
                            .padding(.vertical, 64)
                            .padding(.trailing, 8)
                            // 竖向滚歌架，横向右扫直接收起
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 24)
                                    .onEnded { value in
                                        if value.translation.width > 48,
                                           abs(value.translation.width) > abs(value.translation.height) {
                                            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                                                showShelf = false
                                            }
                                        }
                                    }
                            )
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                // 3D 歌架常驻开关：右上角悬浮，不依赖控制栏呼出，永远在最顶层
                if !immersiveLocked {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                if showShelf {
                                    withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) { showShelf = false }
                                } else {
                                    openShelf()
                                }
                            } label: {
                                MonologueIcon(
                                    icon: .musicNoteList,
                                    size: 18,
                                    color: showShelf ? .monologueAccent : .white.opacity(0.9)
                                )
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(.ultraThinMaterial))
                                .overlay(Circle().stroke(Color.white.opacity(showShelf ? 0.28 : 0.14), lineWidth: 1))
                            }
                            .buttonStyle(MonologueBouncingButtonStyle())
                        }
                        .padding(.top, DeviceLayout.headerTopPadding)
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        Spacer()
                    }
                }

                // 沉浸锁定的临时解锁按钮
                if immersiveLocked && showLockHint {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                lockHintToken += 1
                                immersiveLocked = false
                                showLockHint = false
                                withAnimation(.easeInOut(duration: 0.25)) { chromeHidden = false }
                                markInteraction()
                            } label: {
                                HStack(spacing: 6) {
                                    MonologueIcon(icon: .lock, size: 15, color: .white)
                                    Text("解锁")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(.ultraThinMaterial))
                                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                            }
                            .buttonStyle(MonologueBouncingButtonStyle())
                        }
                        .padding(.top, DeviceLayout.headerTopPadding)
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding + 8)
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        showImmersiveEntry: false,
                        onQuality: { showQualitySheet = true },
                        onEQ: { showEQSettings = true }
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            audioPulse.start()
            motionParallax.start()
            OrientationManager.shared.enterLandscape()
        }
        .onDisappear {
            audioPulse.stop()
            motionParallax.stop()
            OrientationManager.shared.exitLandscape()
        }
        .onReceive(idleTicker) { _ in
            // 保险丝：BPM 分析等共享消费者可能关掉频谱开关，每秒确认重新占用
            audioPulse.reattachIfNeeded()
            // 只有沉浸舞台会自动净屏；常规横屏控制栏常驻
            // （歌架的开关是右上角常驻悬浮按钮，净屏不影响关闭）
            guard stageMode == .immersive, !immersiveLocked,
                  !chromeHidden, player.isPlaying, !anyOverlayOpen else { return }
            if Date().timeIntervalSince(lastInteractionAt) >= idleHideDelay {
                withAnimation(.easeInOut(duration: 0.35)) { chromeHidden = true }
            }
        }
        .onChange(of: stageModeRaw) { _, _ in
            // 切换舞台模式时恢复控制栏，保证常规模式下按钮可见
            immersiveLocked = false
            withAnimation(.easeInOut(duration: 0.25)) { chromeHidden = false }
        }
        .onChange(of: chromeHidden) { _, hidden in
            if !hidden { markInteraction() }
        }
        .onChange(of: isDraggingSlider) { _, _ in markInteraction() }
        .onChange(of: player.currentSong?.id) { _, _ in
            markInteraction()
            audioPulse.resetForNewTrack()
        }
        .onChange(of: anyOverlayOpen) { _, _ in markInteraction() }
        .monologueSheet(isPresented: $showAssignSheet, preset: .large) {
            ImmersiveBackgroundSheet()
        }
        .monologueSheet(isPresented: $showStageSettings, preset: .large) {
            CinemaStageSettingsSheet()
        }
        .task(id: player.currentSong?.coverUrl?.absoluteString) {
            stageColors.extract(from: player.currentSong?.coverUrl?.sized(200).absoluteString)
        }
        .monologueSheet(isPresented: $showEQSettings, preset: .large) {
            NavigationStack { EQSettingsView() }
        }
        .monologueSheet(isPresented: $showQualitySheet, preset: .compact) {
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
    }

    private func openShelf() {
        markInteraction()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) { showShelf = true }
    }

    // MARK: - 背景

    @ViewBuilder
    private func background(size: CGSize) -> some View {
        if let videoURL {
            // 视频画面吃节拍镜头的变焦冲击（radiusKick），复刻 Mineradio 的推镜感
            // 注意不能用 geo.size 定死 frame：那是安全区尺寸，横屏时刘海侧/Home 条
            // 会露出黑边；让视频层自己铺满并忽略安全区（AVPlayerLayer aspectFill 裁切）
            // 视频缩放 + 节拍辉光共用一个 TimelineView，省一路每帧回调与快照
            TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 30, paused: !player.isPlaying)) { _ in
                let snap = audioPulse.snapshot()
                let videoScale: Double = 1 + snap.radiusKick * 0.06
                let bloom = max(snap.lyricSun, max(snap.beatPulse * 1.22, snap.punch * 0.86 + snap.radiusKick * 1.85))
                ZStack {
                    ImmersiveVideoBackground(url: videoURL)
                        .scaleEffect(videoScale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // 压暗遮罩，保证前景可读
                    LinearGradient(
                        colors: [.black.opacity(0.45), .black.opacity(0.12), .black.opacity(0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // 节拍辉光：底部随鼓点轻微透亮，让视频画面"跟着音乐呼吸"
                    LinearGradient(
                        colors: [.clear, Color.monologueAccent.opacity(0.10 * min(1, bloom))],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    vignetteOverlay
                }
            }
            .ignoresSafeArea()
        } else {
            switch backgroundStyle {
            case .galaxy:
                PlaylistColorBackground(
                    coverUrl: player.currentSong?.coverUrl?.sized(200),
                    onBrightnessChanged: { _ in }
                )
                .ignoresSafeArea()

                // 压暗一层，让星河粒子在弥散色上更突出
                Color.black.opacity(0.32).ignoresSafeArea()

                // 无绑定视频时：音频驱动的星河粒子舞台（陀螺仪反向视差 = 远景）
                CinemaParticleStage(
                    pulse: audioPulse,
                    isPlaying: player.isPlaying,
                    accent: .monologueAccent,
                    motion: motionParallax
                )
                .ignoresSafeArea()

                beatGlowOverlay

                vignetteOverlay

            case .fluid:
                // folia 流体弥散：封面模糊铺满 + 对角渐变
                FoliaFluidBackground(
                    coverUrl: player.currentSong?.coverUrl?.sized(500),
                    palette: stagePalette
                )
                .ignoresSafeArea()

                beatGlowOverlay

                vignetteOverlay

            case .geometric:
                // folia 流体 + 分频几何漂浮体
                FoliaFluidBackground(
                    coverUrl: player.currentSong?.coverUrl?.sized(500),
                    palette: stagePalette
                )
                .ignoresSafeArea()

                FoliaGeometricBackground(
                    pulse: audioPulse,
                    palette: stagePalette,
                    isPlaying: player.isPlaying,
                    seed: Double(abs((player.currentSong?.id ?? 1).hashValue % 100_000))
                )
                .ignoresSafeArea()

                beatGlowOverlay

                vignetteOverlay
            }
        }
    }

    /// 电影暗角（Mineradio 背景着色器的 vignette 语义）：
    /// 四周压暗、中心通透，观者视线被聚拢到舞台中央 —— 静态图层零开销
    private var vignetteOverlay: some View {
        RadialGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.58),
                .init(color: Color.black.opacity(0.22), location: 0.82),
                .init(color: Color.black.opacity(0.52), location: 1)
            ],
            center: .center,
            startRadius: 0,
            endRadius: 720
        )
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    /// 节拍辉光 — 对应 Mineradio 的 musicBloom：
    /// max(lyricSunEnergy, beatPulse) 与镜头 punch 共同驱动画面透亮
    private var beatGlowOverlay: some View {
        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 30, paused: !player.isPlaying)) { _ in
            let snap = audioPulse.snapshot()
            let bloom = max(snap.lyricSun, max(snap.beatPulse * 1.22, snap.punch * 0.86 + snap.radiusKick * 1.85))
            LinearGradient(
                colors: [.clear, Color.monologueAccent.opacity(0.10 * min(1, bloom))],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    // MARK: - 顶部栏

    private var topBar: some View {
        HStack(spacing: 8) {
            Button(action: { dismiss() }) {
                MonologueIcon(icon: .back, size: 22, color: .white)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(MonologueBouncingButtonStyle())

            Spacer()

            // 舞台模式切换：沉浸（快闪歌词）↔ 常规横屏（瀑布流歌词 + 封面）
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    stageModeRaw = (stageMode == .immersive ? StageMode.classic : StageMode.immersive).rawValue
                }
            } label: {
                MonologueIcon(
                    icon: stageMode == .immersive ? .album : .sparkle,
                    size: 19,
                    color: .white.opacity(0.85)
                )
                .frame(width: 40, height: 40)
            }
            .buttonStyle(MonologueBouncingButtonStyle())

            // 沉浸模式下：快闪歌词 / 封面 切换
            if stageMode == .immersive {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showLyrics.toggle() }
                } label: {
                    MonologueIcon(icon: showLyrics ? .musicNote : .list, size: 18, color: .white.opacity(0.85))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }

            // 舞台设置：切换歌词效果 / 背景效果
            Button { showStageSettings = true } label: {
                MonologueIcon(icon: .settings, size: 19, color: .white.opacity(0.85))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(MonologueBouncingButtonStyle())

            // 视频背景导入 / 绑定
            Button { showAssignSheet = true } label: {
                ZStack(alignment: .topTrailing) {
                    MonologueIcon(icon: .mv, size: 20, color: .white)
                        .frame(width: 40, height: 40)
                    if videoURL != nil {
                        Circle().fill(Color.monologueAccent).frame(width: 7, height: 7).offset(x: -6, y: 8)
                    }
                }
            }
            .buttonStyle(MonologueBouncingButtonStyle())

            // 沉浸锁定：立即净屏，点击不再唤出控制栏（点屏幕弹临时解锁按钮）
            if stageMode == .immersive {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        immersiveLocked = true
                        chromeHidden = true
                    }
                    flashLockHint()
                } label: {
                    MonologueIcon(icon: .unlock, size: 19, color: .white.opacity(0.85))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }

            Button(action: { showMoreMenu = true }) {
                MonologueIcon(icon: .more, size: 22, color: .white)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(MonologueBouncingButtonStyle())
        }
        // 右侧让位给常驻的 3D 歌架悬浮按钮
        .padding(.trailing, 48)
    }

    // MARK: - 中部舞台

    @ViewBuilder
    private func centerStage(size: CGSize) -> some View {
        switch stageMode {
        case .immersive:
            immersiveStage(size: size)
        case .classic:
            // 常规横屏：左瀑布流歌词 + 右封面（普通封面，不做粒子）
            // 控制栏是浮层，这里用内边距避让，防止内容被顶栏/底栏遮挡
            let topInset: CGFloat = DeviceLayout.headerTopPadding + 52
            let bottomInset: CGFloat = 158
            let stageHeight: CGFloat = max(120, size.height - topInset - bottomInset)
            HStack(spacing: 20) {
                Group {
                    if let song = player.currentSong {
                        OrganicLyricsView(song: song) { toggleChrome() }
                            .environment(\.colorScheme, .dark)
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack {
                    Spacer(minLength: 0)
                    flatCover(side: min(stageHeight, size.width * 0.30, 320))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.top, topInset)
            .padding(.bottom, bottomInset)
        }
    }

    /// 沉浸舞台 — 复刻 Mineradio 场景结构：
    /// 封面粒子平面是镜头主体（俯仰角 + 慢速环绕漂移 + 节拍镜头冲击），
    /// 快闪歌词浮在封面前方，跟随镜头做更大幅度的视差（离观者更近 → 动得更多）
    private func immersiveStage(size: CGSize) -> some View {
        // 不随 isPlaying 暂停：缓冲/切歌间隙镜头漂移与陀螺仪视差也要继续，
        // 否则表现为"动态效果突然停掉"。不播放时只剩慢速漂移，降到 30fps 省电
        TimelineView(AppFrameRate.animationTimeline(
            maximumFramesPerSecond: player.isPlaying ? perf.stageFPS : 30,
            paused: false
        )) { timeline in
            let snap = audioPulse.snapshot()
            let t: Double = timeline.date.timeIntervalSinceReferenceDate

            // 镜头（Mineradio updateCinema 原参数）：
            // idle 漂移振幅只有 ~0.7°、周期极长（原版注释"非常缓慢的低频漂移，
            // 不再让人 motion sick"），动感主要来自节拍冲击而不是漂移
            let driftYaw: Double = sin(t * 0.08) * 0.7
            let driftPitch: Double = sin(t * 0.06 + 1.0) * 0.6
            let driftZoom: Double = sin(t * 0.04 + 2.0) * 0.012
            let gyroYaw: Double = motionParallax.tiltX * 8
            let gyroPitch: Double = motionParallax.tiltY * 5.5
            let yaw: Double = driftYaw + gyroYaw + snap.thetaKick * 110
            let pitch: Double = 6 + driftPitch + gyroPitch + snap.phiKick * 180

            let coverScale: Double = 1 + driftZoom + snap.radiusKick * 0.30 + snap.bass * 0.014
            let coverRoll: Double = snap.rollKick * 8
            let glow: Double = snap.beatPulse + snap.punch * 0.6
            let side: CGFloat = min(size.height * 0.58, size.width * 0.36)

            // 歌词层视差：文字保持正对观者（billboard），深度感全靠比封面
            // 更大的平移视差 + 极轻的偏航，不做俯仰扭曲（扭了文字就丑）
            let lyricYawDeg: Double = yaw * 0.30
            let lyricOffsetX: CGFloat = CGFloat(-yaw) * 3.4
            let lyricOffsetY: CGFloat = CGFloat(-(pitch - 6)) * 2.8
            let lyricScale: Double = 1 + snap.punch * 0.05 + snap.beatPulse * 0.02

            // 封面主体的平面视差（地面投影跟随位移但不跟随旋转）
            let coverDX: CGFloat = CGFloat(yaw) * -1.4
            let coverDY: CGFloat = CGFloat(snap.phiKick) * -420

            ZStack {
                // 中景漂尘：封面后方，视差中速 —— 镜头动时与远景星河拉开层次
                CinemaDepthDust(
                    pulse: audioPulse,
                    motion: motionParallax,
                    preset: .midDust,
                    accent: .monologueAccent
                )

                // 封面粒子舞台（镜头主体）。绑定了视频背景时视频就是主角，
                // 粒子封面整个不渲染，只留歌词浮在画面上；
                // 整幅舞台歌词模式（浮名/群唱/莫奈）独占画布，同样不渲染粒子封面
                if videoURL == nil && !lyricStyle.isFullStage {
                    CinemaCoverParticles(
                        pulse: audioPulse,
                        coverUrl: player.currentSong?.coverUrl?.sized(500),
                        side: side,
                        isPlaying: player.isPlaying
                    )
                    // 节拍辉光：径向渐变光晕代替 .shadow —— 粒子画布每帧都在重绘，
                    // 动态半径的 shadow 会迫使整块画布每帧走离屏高斯模糊，GPU 开销极大
                    .background(
                        RadialGradient(
                            colors: [Color.monologueAccent.opacity(0.34 * glow), .clear],
                            center: .center,
                            startRadius: side * 0.18,
                            endRadius: side * 0.85
                        )
                        .frame(width: side * 1.7, height: side * 1.7)
                        .allowsHitTesting(false)
                    )
                    .scaleEffect(coverScale)
                    .rotation3DEffect(.degrees(pitch), axis: (x: 1, y: 0, z: 0), perspective: 0.62)
                    .rotation3DEffect(.degrees(yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.62)
                    .rotationEffect(.radians(coverRoll))
                    .offset(x: coverDX, y: coverDY)
                }

                // 歌词层（设置里可切换效果）：
                // folia 经典流光（三态散点词 + 逐字素辉光）/ VJ 快闪（节拍爆闪）
                if showLyrics, let song = player.currentSong {
                    Group {
                        switch lyricStyle {
                        case .flash:
                            CinemaFlashLyricsView(song: song, pulse: audioPulse) { toggleChrome() }
                        default:
                            FoliaLyricsView(song: song, pulse: audioPulse, style: lyricStyle) { toggleChrome() }
                        }
                    }
                    // 整幅舞台模式自己掌控镜头（浮名追焦/莫奈静态海报），不叠加视差
                    .rotation3DEffect(.degrees(lyricStyle.isFullStage ? 0 : lyricYawDeg), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                    .scaleEffect(lyricStyle.isFullStage ? 1 : lyricScale)
                    .offset(
                        x: lyricStyle.isFullStage ? 0 : lyricOffsetX,
                        y: lyricStyle.isFullStage ? 0 : lyricOffsetY
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleChrome() }
    }

    /// 常规横屏模式的普通封面（节拍只做极轻的呼吸）
    private func flatCover(side: CGFloat) -> some View {
        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 30, paused: !player.isPlaying)) { _ in
            let snap = audioPulse.snapshot()
            let coverScale: Double = 1 + snap.radiusKick * 0.06 + snap.bass * 0.006
            Group {
                if let url = player.currentSong?.coverUrl?.sized(500) {
                    CachedAsyncImage(url: url) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.12))
                    }
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: side, height: side)
                        .overlay(MonologueIcon(icon: .musicNote, size: 60, color: .white.opacity(0.7)))
                }
            }
            .scaleEffect(coverScale)
            .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 14)
        }
    }

    // MARK: - 底部信息 + 进度 + 控件

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.currentSong?.name ?? "No Title")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(player.currentSong?.artistName ?? "Unknown Artist")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                Spacer()
                if let song = player.currentSong {
                    LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 26,
                               activeColor: .red, inactiveColor: .white.opacity(0.85))
                }
            }

            CinemaProgressBar(
                isDragging: $isDraggingSlider,
                dragValue: $dragTimeValue,
                accent: .monologueAccent
            )

            HStack {
                Button(action: { player.switchMode() }) {
                    MonologueIcon(icon: player.mode.monologueIcon, size: 22, color: .white.opacity(0.8))
                }
                .buttonStyle(MonologueBouncingButtonStyle())

                Spacer()

                Button(action: { player.previous() }) {
                    MonologueIcon(icon: .previous, size: 26, color: .white)
                }
                .buttonStyle(MonologueBouncingButtonStyle())

                Spacer()

                Button(action: { player.togglePlayPause() }) {
                    if player.isLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 44, height: 44)
                    } else {
                        MonologueIcon(icon: player.isPlaying ? .pause : .play, size: 44, color: .white)
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle())

                Spacer()

                Button(action: { player.next() }) {
                    MonologueIcon(icon: .next, size: 26, color: .white)
                }
                .buttonStyle(MonologueBouncingButtonStyle())

                Spacer()

                // 占位对称：歌架快捷开关
                Button {
                    if showShelf {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) { showShelf = false }
                    } else {
                        openShelf()
                    }
                } label: {
                    MonologueIcon(icon: .musicNoteList, size: 22, color: showShelf ? .monologueAccent : .white.opacity(0.8))
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
        }
    }
}

// MARK: - 影院进度条（无音纹：细胶囊 + 拖拽放大 + 时间贴两端）

private struct CinemaProgressBar: View {
    @Binding var isDragging: Bool
    @Binding var dragValue: Double
    var accent: Color = .monologueAccent

    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared

    var body: some View {
        HStack(spacing: 12) {
            Text(formatTime(isDragging ? dragValue : timePublisher.currentTime))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
                .monospacedDigit()
                .frame(width: 42, alignment: .trailing)

            GeometryReader { geo in
                let duration = timePublisher.duration
                let progress: Double = duration > 0
                    ? min(max((isDragging ? dragValue : timePublisher.currentTime) / duration, 0), 1)
                    : 0
                let barHeight: CGFloat = isDragging ? 10 : 5
                let fillWidth: CGFloat = geo.size.width * CGFloat(progress)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: barHeight)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.92), accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(fillWidth, barHeight), height: barHeight)
                        .shadow(color: accent.opacity(isDragging ? 0.55 : 0.25), radius: isDragging ? 8 : 4)
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
                            guard duration > 0 else { isDragging = false; return }
                            let p = min(max(value.location.x / geo.size.width, 0), 1)
                            isDragging = false
                            player.seek(to: p * duration)
                        }
                )
            }
            .frame(height: 26)

            Text(formatTime(timePublisher.duration))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
                .monospacedDigit()
                .frame(width: 42, alignment: .leading)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
