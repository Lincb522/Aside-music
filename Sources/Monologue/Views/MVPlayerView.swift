// MVPlayerView.swift
// MV 播放器 — 上方视频 + 下方信息 + 内嵌评论，遵循 Monologue 设计系统
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
final class MVPlayerWrapper: ObservableObject {
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
            guard let self else { return }
            let t = time.seconds
            if t.isFinite && !t.isNaN {
                MainActor.assumeIsolated {
                    self.currentTime = t
                }
            }
        }
    }

    private func observeItem(_ item: AVPlayerItem) {
        durationObservation?.invalidate()

        durationObservation = item.observe(\.duration, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            let d = item.duration.seconds
            if d.isFinite && d > 0 {
                MainActor.assumeIsolated {
                    self.duration = d
                }
            }
        }
    }
}

struct MVPlayerView: View {
    let mvId: Int
    @State private var viewModel: MVPlayerViewModel
    @StateObject private var commentVM: CommentViewModel
    @ObservedObject private var player = PlayerManager.shared
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
        _viewModel = State(initialValue: MVPlayerViewModel(mvId: mvId))
        _commentVM = StateObject(wrappedValue: CommentViewModel(resourceId: mvId, resourceType: .mv))
    }

    var body: some View {
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
        .monologueSheet(isPresented: $showSimiSheet, preset: .standard){
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
            MonologueBackground().ignoresSafeArea()

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

    private var topBar: some View {
        HStack {
            MonologueBackButton(style: .dismiss)
            Spacer()
            Text(String(localized: "mv_title"))
                .font(.rounded(size: 18, weight: .bold))
                .foregroundColor(.monologueTextPrimary)
            Spacer()
            // 占位
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    // MARK: - 视频区域

    private var videoSection: some View {
        ZStack {
            // 视频背景
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black)

            if viewModel.videoUrl != nil {
                AVPlayerVideoView(player: mvPlayerWrapper.player)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                mvVideoControlsOverlay(fullscreen: false)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else if let error = viewModel.errorMessage {
                // 错误状态
                VStack(spacing: 14) {
                    MonologueIcon(icon: .warning, size: 32, color: .white.opacity(0.4))
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
                MonologueLoadingView()
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 24)
    }

    // MARK: - MV 信息 + 收藏

    private var infoSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                if let detail = viewModel.detail {
                    Text(detail.name ?? String(localized: "mv_unknown"))
                        .font(.rounded(size: 22, weight: .bold))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        Text(detail.displayArtistName)
                            .font(.rounded(size: 14))
                            .foregroundColor(.monologueTextSecondary)

                        if let count = detail.playCount {
                            Text("·")
                                .foregroundColor(.monologueTextSecondary.opacity(0.4))
                            Text(formatCount(count) + String(localized: "mv_play_count"))
                                .font(.rounded(size: 12))
                                .foregroundColor(.monologueTextSecondary.opacity(0.6))
                        }
                    }
                } else {
                    // 骨架占位
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.monologueTextSecondary.opacity(0.08))
                        .frame(height: 22)
                        .frame(maxWidth: 200)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.monologueTextSecondary.opacity(0.06))
                        .frame(height: 16)
                        .frame(maxWidth: 120)
                }
            }

            Spacer()

            // 收藏按钮
            Button {
                viewModel.toggleSubscribe()
            } label: {
                MonologueIcon(
                    icon: viewModel.isSubscribed ? .liked : .like,
                    size: 22,
                    color: viewModel.isSubscribed ? .monologueAccentRed : .monologueTextSecondary
                )
                .frame(width: 40, height: 40)
            }
            .buttonStyle(MonologueBouncingButtonStyle())
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 相关推荐预览

    private var relatedPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(String(localized: "mv_related"))
                    .font(.rounded(size: 18, weight: .bold))
                    .foregroundColor(.monologueTextPrimary)
                Spacer()
                let total = viewModel.simiMVs.count + viewModel.relatedMVs.count
                if total > 3 {
                    Button(action: { showSimiSheet = true }) {
                        HStack(spacing: 4) {
                            Text(String(localized: "mv_more"))
                                .font(.rounded(size: 14, weight: .medium))
                                .foregroundColor(.monologueTextSecondary)
                            MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary)
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
                                    if let urlStr = mv.coverUrl, let url = URL(string: urlStr) {
                                        CachedAsyncImage(url: url) {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.monologueTextSecondary.opacity(0.06))
                                        }
                                        .aspectRatio(16/9, contentMode: .fill)
                                        .frame(width: 180, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    } else {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.monologueTextSecondary.opacity(0.06))
                                            .frame(width: 180, height: 100)
                                    }

                                    if !mv.durationText.isEmpty {
                                        Text(mv.durationText)
                                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(.clear).monologueGlassCapsule()
                                            .padding(6)
                                    }
                                }

                                Text(mv.name ?? String(localized: "mv_unknown"))
                                    .font(.rounded(size: 13, weight: .medium))
                                    .foregroundColor(.monologueTextPrimary)
                                    .lineLimit(1)
                                Text(mv.artistName ?? "")
                                    .font(.rounded(size: 11))
                                    .foregroundColor(.monologueTextSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 180)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - 加载覆盖

    private var loadingOverlay: some View {
        ZStack {
            Color.monologueBackground.opacity(0.6).ignoresSafeArea()
            MonologueLoadingView(text: "LOADING MV")
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
            return String(format: String(localized: "%.1f亿"), Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: String(localized: "%.1f万"), Double(count) / 10_000)
        }
        return "\(count)"
    }

    // MARK: - 相似推荐 Sheet

    private var simiSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "mv_related"))
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundColor(.monologueTextPrimary)
                Spacer()
                let total = viewModel.simiMVs.count + viewModel.relatedMVs.count
                Text("\(total)个")
                    .font(.rounded(size: 13))
                    .foregroundColor(.monologueTextSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Rectangle()
                .fill(Color.monologueSeparator)
                .frame(height: 0.5)

            ScrollView {
                LazyVStack(spacing: 10) {
                    if !viewModel.simiMVs.isEmpty {
                        simiSectionLabel(String(localized: "mv_similar"))
                        ForEach(viewModel.simiMVs) { mv in
                            MVRowCard(mv: mv) {
                                showSimiSheet = false
                                switchToMV(mv.id)
                            }
                        }
                    }

                    if !viewModel.relatedMVs.isEmpty {
                        simiSectionLabel(String(localized: "mv_related_videos"))
                        ForEach(viewModel.relatedMVs) { mv in
                            MVRowCard(mv: mv) {
                                showSimiSheet = false
                                switchToMV(mv.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .background {
            Rectangle()
                .fill(Color.monologueGlassTint)
                .monologueGlass(cornerRadius: 16)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func simiSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.rounded(size: 14, weight: .semibold))
            .foregroundColor(.monologueTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}
