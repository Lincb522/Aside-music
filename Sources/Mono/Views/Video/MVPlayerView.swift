// MV 播放器 — 上方视频 + 下方信息 + 内嵌评论，遵循 Mono 设计系统
// 视频播放使用 AVPlayer（系统原生播放器）

import SwiftUI
import AVFoundation
import NeteaseCloudMusicAPI

// MARK: - AVPlayer 视频渲染层 SwiftUI 包装

/// 将 AVPlayerLayer 嵌入 SwiftUI
struct AVPlayerVideoView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

/// 使用 AVPlayerLayer 作为 layerClass 的容器视图，自动跟随 bounds 变化
final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { return nil }
}

// MARK: - MV 播放器包装器

/// 包装 AVPlayer 为 ObservableObject，提供播放控制和状态观察
@preconcurrency
final class MVPlayerWrapper: ObservableObject, @unchecked Sendable {
    let player = AVPlayer()
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isPlaying = false

    private nonisolated(unsafe) var timeObserver: Any?
    private var durationObservation: NSKeyValueObservation?

    init() {
        player.automaticallyWaitsToMinimizeStalling = true
        setupTimeObserver()
    }

    deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        durationObservation?.invalidate()
    }

    func play(url: String) {
        guard let videoURL = URL(string: url) else { return }
        let item = AVPlayerItem(url: videoURL)
        player.replaceCurrentItem(with: item)
        observeItem(item)
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func resume() {
        player.play()
        isPlaying = true
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.3, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let t = time.seconds
            guard t.isFinite && !t.isNaN else { return }

            Task { @MainActor [weak self] in
                self?.currentTime = t
            }
        }
    }

    private func observeItem(_ item: AVPlayerItem) {
        durationObservation?.invalidate()

        durationObservation = item.observe(\.duration, options: [.new]) { [weak self] item, _ in
            let d = item.duration.seconds
            guard d.isFinite && d > 0 else { return }

            Task { @MainActor [weak self] in
                self?.duration = d
            }
        }
    }
}

struct MVPlayerView: View {
    let mvId: Int
    @StateObject private var viewModel: MVPlayerViewModel
    @StateObject private var commentVM: CommentViewModel
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool

    /// MV 专用 AVPlayer 播放器（独立于音乐播放器）
    @StateObject private var mvPlayerWrapper = MVPlayerWrapper()
    
    @State private var isPlaying = true
    @State private var showSimiSheet = false
    @State private var isFullscreen = false
    
    // 自定义播放器控件状态
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var isSeeking = false
    @State private var seekValue: Double = 0

    init(mvId: Int) {
        self.mvId = mvId
        _viewModel = StateObject(wrappedValue: MVPlayerViewModel(mvId: mvId))
        _commentVM = StateObject(wrappedValue: CommentViewModel(resourceId: mvId, resourceType: .mv))
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            if isFullscreen {
                // 全屏横屏模式
                fullscreenView
            } else {
                // 正常竖屏模式
                normalView
            }
        }
        .onAppear {
            player.isTabBarHidden = true
            if player.isPlaying { player.togglePlayPause() }
            viewModel.fetchData()
            commentVM.loadComments()
            scheduleControlsHide()
        }
        .onDisappear {
            controlsTimer?.invalidate()
            mvPlayerWrapper.stop()
            player.isTabBarHidden = false
            if isFullscreen {
                OrientationManager.shared.exitLandscape()
            }
        }
        .onChange(of: viewModel.videoUrl) { _, url in
            if let url, let _ = URL(string: url) {
                AppLogger.info("[MVPlayer] 开始播放视频: \(url)")
                mvPlayerWrapper.play(url: url)
                isPlaying = true
            } else {
                AppLogger.warning("[MVPlayer] 视频 URL 无效: \(url ?? "nil")")
            }
        }
        .onChange(of: viewModel.detail?.name) { _, name in
            AppLogger.debug("[MVPlayer View] detail.name 变化: \(name ?? "nil")")
        }
        .statusBar(hidden: isFullscreen)
        .monoSheet(isPresented: $showSimiSheet, preset: .standard){
            simiSheet

        }
    }

    // MARK: - 全屏横屏视图

    private var fullscreenView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AVPlayerVideoView(player: mvPlayerWrapper.player)
                .ignoresSafeArea()

            mvVideoControlsOverlay(fullscreen: true)
                .ignoresSafeArea()
        }
    }

    // MARK: - 正常竖屏视图

    private var normalView: some View {
        ZStack {
            ThemedPageBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部栏
                topBar
                    .padding(.top, DeviceLayout.headerTopPadding)

                // 视频区域
                videoSection

                // 下方信息 + 评论区域
                ScrollView {
                    VStack(spacing: 20) {
                        // MV 信息 + 收藏
                        infoSection

                        // 相关推荐预览
                        if !viewModel.simiMVs.isEmpty || !viewModel.relatedMVs.isEmpty {
                            relatedPreview
                        }

                        // 内嵌评论区
                        MVEmbeddedCommentSection(
                            commentVM: commentVM,
                            isInputFocused: $isInputFocused
                        )
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 80)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()

                // 底部评论输入栏
                MVCommentInputBar(
                    commentVM: commentVM,
                    isInputFocused: $isInputFocused
                )
            }

            // 加载 / 错误覆盖
            if viewModel.isLoading && viewModel.detail == nil {
                loadingOverlay
            }
        }
    }

    // MARK: - 顶部栏

    /// aside 编辑部风格：默认主题走平排编辑部版式
    private var isAside: Bool {
        !ThemedPageStyle.isActive
    }

    private var topBar: some View {
        HStack {
            MonoBackButton(style: .dismiss)
            Spacer()
            if isAside {
                HStack(spacing: 8) {
                    Capsule()
                        .fill(Color.monoAccent)
                        .frame(width: 16, height: 3)
                    Text("MV")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(3.0)
                        .foregroundColor(.monoTextPrimary)
                }
            } else {
                Text(String(localized: "mv_title"))
                    .font(.rounded(size: 18, weight: .bold))
                    .foregroundColor(.monoTextPrimary)
            }
            Spacer()
            // 占位
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    // MARK: - 视频区域

    private var videoSection: some View {
        let radius: CGFloat = isAside ? 18 : 20
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        return ZStack {
            // 视频背景
            shape.fill(Color.black)

            if viewModel.videoUrl != nil {
                AVPlayerVideoView(player: mvPlayerWrapper.player)
                    .clipShape(shape)

                mvVideoControlsOverlay(fullscreen: false)
                    .clipShape(shape)
            } else if let error = viewModel.errorMessage {
                // 错误状态
                VStack(spacing: 14) {
                    MonoIcon(icon: .warning, size: 32, color: .white.opacity(0.4))
                    Text(error)
                        .font(.rounded(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button(String(localized: "mv_retry")) { viewModel.fetchData() }
                        .font(.rounded(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
            } else {
                MonoLoadingView()
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .clipShape(shape)
        .overlay {
            if isAside {
                shape.stroke(Color.monoSeparator.opacity(0.9), lineWidth: 0.8)
            }
        }
        .shadow(color: .black.opacity(isAside ? 0 : 0.12), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 24)
    }

    // MARK: - MV 信息 + 收藏

    @ViewBuilder
    private var infoSection: some View {
        if isAside {
            asideInfoSection
        } else {
            themedInfoSection
        }
    }

    /// aside 编辑部式：眉题刻度 + 大标题 + 发丝元信息行，收藏为描边圆钮
    private var asideInfoSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Capsule()
                        .fill(Color.monoAccent)
                        .frame(width: 18, height: 3)

                    Text("NOW SHOWING")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(2.2)
                        .foregroundColor(.monoTextSecondary.opacity(0.72))
                }

                if let detail = viewModel.detail {
                    Text(detail.displayName)
                        .font(.rounded(size: 22, weight: .bold))
                        .foregroundColor(.monoTextPrimary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(detail.displayArtistName)
                            .font(.rounded(size: 13.5, weight: .medium))
                            .foregroundColor(.monoTextSecondary)

                        if let count = detail.playCount {
                            Rectangle()
                                .fill(Color.monoSeparator.opacity(0.9))
                                .frame(width: 0.7, height: 10)

                            Text(formatCount(count) + String(localized: "mv_play_count"))
                                .font(.rounded(size: 12))
                                .foregroundColor(.monoTextSecondary.opacity(0.65))
                        }
                    }
                } else {
                    // 骨架占位
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.monoTextSecondary.opacity(0.08))
                        .frame(height: 22)
                        .frame(maxWidth: 200)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.monoTextSecondary.opacity(0.06))
                        .frame(height: 16)
                        .frame(maxWidth: 120)
                }
            }

            Spacer()

            // 收藏按钮
            Button {
                viewModel.toggleSubscribe()
            } label: {
                MonoIcon(
                    icon: viewModel.isSubscribed ? .liked : .like,
                    size: 18,
                    color: viewModel.isSubscribed ? .monoAccentRed : .monoTextSecondary,
                    lineWidth: 1.4
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(
                            viewModel.isSubscribed ? Color.monoAccentRed.opacity(0.45) : Color.monoSeparator.opacity(0.95),
                            lineWidth: 0.8
                        )
                )
            }
            .buttonStyle(MonoBouncingButtonStyle())
        }
        .padding(.horizontal, 24)
    }

    private var themedInfoSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                if let detail = viewModel.detail {
                    Text(detail.displayName)
                        .font(.rounded(size: 22, weight: .bold))
                        .foregroundColor(.monoTextPrimary)
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        Text(detail.displayArtistName)
                            .font(.rounded(size: 14))
                            .foregroundColor(.monoTextSecondary)

                        if let count = detail.playCount {
                            Text("·")
                                .foregroundColor(.monoTextSecondary.opacity(0.4))
                            Text(formatCount(count) + String(localized: "mv_play_count"))
                                .font(.rounded(size: 12))
                                .foregroundColor(.monoTextSecondary.opacity(0.6))
                        }
                    }
                } else {
                    // 骨架占位
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.monoTextSecondary.opacity(0.08))
                        .frame(height: 22)
                        .frame(maxWidth: 200)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.monoTextSecondary.opacity(0.06))
                        .frame(height: 16)
                        .frame(maxWidth: 120)
                }
            }

            Spacer()

            // 收藏按钮
            Button {
                viewModel.toggleSubscribe()
            } label: {
                MonoIcon(
                    icon: viewModel.isSubscribed ? .liked : .like,
                    size: 22,
                    color: viewModel.isSubscribed ? .monoAccentRed : .monoTextSecondary
                )
                .frame(width: 40, height: 40)
            }
            .buttonStyle(MonoBouncingButtonStyle())
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 相关推荐预览

    private var relatedPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: isAside ? .firstTextBaseline : .center) {
                if isAside {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Capsule()
                                .fill(Color.monoAccent)
                                .frame(width: 18, height: 3)

                            Text("RELATED")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .tracking(2.2)
                                .foregroundColor(.monoTextSecondary.opacity(0.72))
                        }

                        Text(String(localized: "mv_related"))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.monoTextPrimary)
                    }
                } else {
                    Text(String(localized: "mv_related"))
                        .font(.rounded(size: 18, weight: .bold))
                        .foregroundColor(.monoTextPrimary)
                }

                Spacer()

                let total = viewModel.simiMVs.count + viewModel.relatedMVs.count
                if total > 3 {
                    Button(action: { showSimiSheet = true }) {
                        if isAside {
                            HStack(spacing: 3) {
                                Text("MORE")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .tracking(1.4)
                                MonoIcon(icon: .chevronRight, size: 10, color: .monoTextSecondary.opacity(0.75), lineWidth: 1.6)
                            }
                            .foregroundColor(.monoTextSecondary.opacity(0.75))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5.5)
                            .overlay(Capsule().stroke(Color.monoSeparator.opacity(0.95), lineWidth: 0.7))
                        } else {
                            HStack(spacing: 4) {
                                Text(String(localized: "mv_more"))
                                    .font(.rounded(size: 14, weight: .medium))
                                    .foregroundColor(.monoTextSecondary)
                                MonoIcon(icon: .chevronRight, size: 12, color: .monoTextSecondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            // 横向滚动展示
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    let allRelated = viewModel.simiMVs + viewModel.relatedMVs
                    ForEach(allRelated.prefix(8)) { mv in
                        Button(action: { switchToMV(mv.id) }) {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .bottomTrailing) {
                                    Group {
                                        if let urlStr = mv.coverUrl, let url = URL(string: urlStr) {
                                            CachedAsyncImage(url: url) {
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(Color.monoTextSecondary.opacity(0.06))
                                            }
                                            .aspectRatio(16/9, contentMode: .fill)
                                            .frame(width: 180, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        } else {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.monoTextSecondary.opacity(0.06))
                                                .frame(width: 180, height: 100)
                                        }
                                    }
                                    .overlay {
                                        if isAside {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.monoSeparator.opacity(0.9), lineWidth: 0.8)
                                        }
                                    }

                                    if !mv.durationText.isEmpty {
                                        Text(mv.durationText)
                                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                            .foregroundColor(isAside ? .white : .primary)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background {
                                                if isAside {
                                                    Capsule().fill(Color.black.opacity(0.55))
                                                } else {
                                                    Color.clear.monoGlassCapsule()
                                                }
                                            }
                                            .padding(6)
                                    }
                                }

                                Text(mv.displayName)
                                    .font(.rounded(size: 13, weight: .medium))
                                    .foregroundColor(.monoTextPrimary)
                                    .lineLimit(1)
                                Text(mv.artistName ?? "")
                                    .font(.rounded(size: 11))
                                    .foregroundColor(.monoTextSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 180)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    // MARK: - 加载覆盖

    private var loadingOverlay: some View {
        ZStack {
            Color.monoBackground.opacity(0.6).ignoresSafeArea()
            MonoLoadingView(text: "LOADING MV")
        }
    }


    // MARK: - 自定义播放器控件覆盖层（桥接到独立组件）

    private func mvVideoControlsOverlay(fullscreen: Bool) -> some View {
        MVVideoControlsOverlay(
            fullscreen: fullscreen,
            showControls: showControls,
            isPlaying: isPlaying,
            isSeeking: isSeeking,
            seekValue: seekValue,
            mvCurrentTime: mvPlayerWrapper.currentTime,
            mvDuration: mvPlayerWrapper.duration,
            mvName: viewModel.detail?.name,
            onTogglePlayback: togglePlayback,
            onToggleControlsVisibility: toggleControlsVisibility,
            onScheduleControlsHide: scheduleControlsHide,
            onEnterFullscreen: enterFullscreen,
            onExitFullscreen: exitFullscreen,
            onSeekChanged: { value in
                isSeeking = true
                seekValue = value
            },
            onSeekEnded: { value in
                mvPlayerWrapper.seek(to: value)
                isSeeking = false
            }
        )
    }

    // MARK: - 辅助方法

    /// 控件自动隐藏（3秒后）
    private func scheduleControlsHide() {
        controlsTimer?.invalidate()
        guard isPlaying else { return }
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation { showControls = false }
            }
        }
    }

    private func toggleControlsVisibility() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls.toggle()
        }
        if showControls { scheduleControlsHide() }
    }

    private func enterFullscreen() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isFullscreen = true
        }
        OrientationManager.shared.enterLandscape()
    }

    private func exitFullscreen() {
        OrientationManager.shared.exitLandscape()
        withAnimation(.easeInOut(duration: 0.3)) {
            isFullscreen = false
        }
    }

    private func togglePlayback() {
        if isPlaying {
            mvPlayerWrapper.pause()
        } else {
            mvPlayerWrapper.resume()
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            isPlaying.toggle()
        }
        if isPlaying {
            scheduleControlsHide()
        } else {
            controlsTimer?.invalidate()
            showControls = true
        }
    }

    private func switchToMV(_ newId: Int) {
        mvPlayerWrapper.stop()
        viewModel.simiMVs = []
        viewModel.relatedMVs = []
        viewModel.detail = nil
        viewModel.videoUrl = nil
        viewModel.detailInfo = nil
        dismiss()
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: String(localized: "count_hundred_million"), Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: String(localized: "count_ten_thousand"), Double(count) / 10_000)
        }
        return "\(count)"
    }

    // MARK: - 相似推荐 Sheet

    private var simiSheet: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                if isAside {
                    HStack(spacing: 8) {
                        Capsule()
                            .fill(Color.monoAccent)
                            .frame(width: 18, height: 3)

                        Text("RELATED")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(2.2)
                            .foregroundColor(.monoTextSecondary.opacity(0.72))
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(String(localized: "mv_related"))
                        .font(isAside ? .system(size: 22, weight: .bold, design: .rounded) : .rounded(size: 20, weight: .bold))
                        .foregroundColor(.monoTextPrimary)
                    Spacer()
                    let total = viewModel.simiMVs.count + viewModel.relatedMVs.count
                    Text("\(total)个")
                        .font(.rounded(size: 13))
                        .foregroundColor(.monoTextSecondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Rectangle()
                .fill(isAside ? Color.monoSeparator.opacity(0.7) : Color.monoSeparator)
                .frame(height: isAside ? 0.6 : 0.5)

            ScrollView {
                LazyVStack(spacing: isAside ? 0 : 10) {
                    if !viewModel.simiMVs.isEmpty {
                        simiSectionLabel(String(localized: "mv_similar"))
                        let lastId = viewModel.simiMVs.last?.id
                        ForEach(viewModel.simiMVs) { mv in
                            MVRowCard(mv: mv, showsDivider: mv.id != lastId) {
                                showSimiSheet = false
                                switchToMV(mv.id)
                            }
                        }
                    }

                    if !viewModel.relatedMVs.isEmpty {
                        simiSectionLabel(String(localized: "mv_related_videos"))
                        let lastId = viewModel.relatedMVs.last?.id
                        ForEach(viewModel.relatedMVs) { mv in
                            MVRowCard(mv: mv, showsDivider: mv.id != lastId) {
                                showSimiSheet = false
                                switchToMV(mv.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, isAside ? 8 : 14)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .background {
            Rectangle()
                .fill(Color.monoGlassTint)
                .monoGlass(cornerRadius: 16)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private func simiSectionLabel(_ text: String) -> some View {
        if isAside {
            HStack(spacing: 8) {
                Text(text)
                    .font(.rounded(size: 13, weight: .bold))
                    .foregroundColor(.monoTextPrimary.opacity(0.85))

                Rectangle()
                    .fill(Color.monoSeparator.opacity(0.7))
                    .frame(height: 0.6)
            }
            .padding(.top, 12)
            .padding(.bottom, 4)
        } else {
            Text(text)
                .font(.rounded(size: 14, weight: .semibold))
                .foregroundColor(.monoTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        }
    }
}
