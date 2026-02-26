// MVPlayerView.swift
// MV 播放器 — 上方视频 + 下方信息 + 内嵌评论，遵循 Aside 设计系统
// 视频播放使用 FFmpeg StreamPlayer（与音频播放统一引擎）

import SwiftUI
import AVFoundation
import NeteaseCloudMusicAPI
import FFmpegSwiftSDK

// MARK: - FFmpeg 视频渲染层 UIKit 包装

/// 将 StreamPlayer 的 AVSampleBufferDisplayLayer 嵌入 SwiftUI
/// 使用自定义 UIView 子类确保 layer frame 在布局变化时正确更新
struct FFmpegVideoView: UIViewRepresentable {
    let displayLayer: AVSampleBufferDisplayLayer

    func makeUIView(context: Context) -> VideoContainerView {
        let view = VideoContainerView(displayLayer: displayLayer)
        return view
    }

    func updateUIView(_ uiView: VideoContainerView, context: Context) {
        // 确保 layer 引用是最新的（虽然通常不会变）
        uiView.updateDisplayLayer(displayLayer)
    }
}

/// 自定义容器视图，在 layoutSubviews 中更新 displayLayer 的 frame
/// 解决 SwiftUI 初始布局时 bounds 为 zero 导致视频不显示的问题
final class VideoContainerView: UIView {
    private var displayLayer: AVSampleBufferDisplayLayer?
    /// 定时器：监控 displayLayer 状态，自动恢复错误
    private nonisolated(unsafe) var statusCheckTimer: Timer?
    
    init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        super.init(frame: .zero)
        backgroundColor = .clear
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(displayLayer)
        startStatusMonitor()
    }
    
    required init?(coder: NSCoder) {
        // 此 View 仅支持代码初始化，不支持 Storyboard/XIB
        return nil
    }
    
    deinit {
        // Timer 不是 Sendable，不能在 nonisolated deinit 中直接访问
        // 使用 nonisolated(unsafe) 局部引用来安全地 invalidate
        let timer = statusCheckTimer
        timer?.invalidate()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // 每次布局变化时更新 displayLayer 的 frame
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer?.frame = bounds
        CATransaction.commit()
    }
    
    func updateDisplayLayer(_ newLayer: AVSampleBufferDisplayLayer) {
        guard newLayer !== displayLayer else { return }
        displayLayer?.removeFromSuperlayer()
        displayLayer = newLayer
        newLayer.videoGravity = .resizeAspect
        newLayer.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(newLayer)
        setNeedsLayout()
    }
    
    /// 启动状态监控，自动处理 displayLayer 错误状态
    private func startStatusMonitor() {
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let layer = self.displayLayer else { return }
                // 检查是否需要 flush 才能恢复解码（FFmpeg 手动喂帧场景，仍需使用 displayLayer 自身的 API）
                if layer.status == .failed || layer.requiresFlushToResumeDecoding {
                    AppLogger.warning("[VideoContainerView] displayLayer 需要 flush，正在恢复...")
                    layer.flush()
                }
            }
        }
    }
}

// MARK: - MV 播放器包装器

/// 包装 StreamPlayer 为 ObservableObject，确保 SwiftUI 正确管理生命周期
final class MVStreamPlayerWrapper: ObservableObject {
    let player = StreamPlayer()
    
    deinit {
        player.stop()
    }
}

struct MVPlayerView: View {
    let mvId: Int
    @State private var viewModel: MVPlayerViewModel
    @StateObject private var commentVM: CommentViewModel
    @ObservedObject private var player = PlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool

    /// MV 专用 FFmpeg 播放器（独立于音乐播放器）
    @StateObject private var mvPlayerWrapper = MVStreamPlayerWrapper()
    /// 便捷访问底层 StreamPlayer
    private var mvPlayer: StreamPlayer { mvPlayerWrapper.player }
    
    @State private var isPlaying = true
    @State private var showSimiSheet = false
    @State private var isFullscreen = false
    
    // 自定义播放器控件状态
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var mvCurrentTime: TimeInterval = 0
    @State private var mvDuration: TimeInterval = 0
    @State private var isSeeking = false
    @State private var seekValue: Double = 0
    @State private var timeUpdateTimer: Timer?

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
            startMVTimeUpdater()
            scheduleControlsHide()
        }
        .onDisappear {
            timeUpdateTimer?.invalidate()
            controlsTimer?.invalidate()
            mvPlayer.stop()
            player.isTabBarHidden = false
            if isFullscreen {
                OrientationManager.shared.exitLandscape()
            }
        }
        .onChange(of: viewModel.videoUrl) { _, url in
            if let url, let _ = URL(string: url) {
                AppLogger.info("[MVPlayer] 开始播放视频: \(url)")
                mvPlayer.play(url: url)
                isPlaying = true
            } else {
                AppLogger.warning("[MVPlayer] 视频 URL 无效: \(url ?? "nil")")
            }
        }
        .onChange(of: viewModel.detail?.name) { _, name in
            AppLogger.debug("[MVPlayer View] detail.name 变化: \(name ?? "nil")")
        }
        .statusBar(hidden: isFullscreen)
        .sheet(isPresented: $showSimiSheet) {
            simiSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - 全屏横屏视图

    private var fullscreenView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            FFmpegVideoView(displayLayer: mvPlayer.videoDisplayLayer)
                .ignoresSafeArea()

            // 自定义控件覆盖层
            mvVideoControlsOverlay(fullscreen: true)
                .ignoresSafeArea()
        }
    }

    // MARK: - 正常竖屏视图

    private var normalView: some View {
        ZStack {
            AsideBackground().ignoresSafeArea()

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
            AsideBackButton(style: .dismiss)
            Spacer()
            Text(String(localized: "mv_title"))
                .font(.rounded(size: 18, weight: .bold))
                .foregroundColor(.asideTextPrimary)
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
                FFmpegVideoView(displayLayer: mvPlayer.videoDisplayLayer)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // 自定义控件覆盖层
                mvVideoControlsOverlay(fullscreen: false)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else if let error = viewModel.errorMessage {
                // 错误状态
                VStack(spacing: 14) {
                    AsideIcon(icon: .warning, size: 32, color: .white.opacity(0.4))
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
                AsideLoadingView()
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
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        Text(detail.displayArtistName)
                            .font(.rounded(size: 14))
                            .foregroundColor(.asideTextSecondary)

                        if let count = detail.playCount {
                            Text("·")
                                .foregroundColor(.asideTextSecondary.opacity(0.4))
                            Text(formatCount(count) + String(localized: "mv_play_count"))
                                .font(.rounded(size: 12))
                                .foregroundColor(.asideTextSecondary.opacity(0.6))
                        }
                        
                        // VideoToolbox 硬件加速标签
                        if mvPlayer.isVideoHardwareAccelerated {
                            Text("HW")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.green.opacity(0.5), lineWidth: 0.8)
                                )
                        }
                    }
                } else {
                    // 骨架占位
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.asideTextSecondary.opacity(0.08))
                        .frame(height: 22)
                        .frame(maxWidth: 200)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.asideTextSecondary.opacity(0.06))
                        .frame(height: 16)
                        .frame(maxWidth: 120)
                }
            }

            Spacer()

            // 收藏按钮
            Button {
                viewModel.toggleSubscribe()
            } label: {
                AsideIcon(
                    icon: viewModel.isSubscribed ? .liked : .like,
                    size: 22,
                    color: viewModel.isSubscribed ? .asideAccentRed : .asideTextSecondary
                )
                .frame(width: 40, height: 40)
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 相关推荐预览

    private var relatedPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(String(localized: "mv_related"))
                    .font(.rounded(size: 18, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                Spacer()
                let total = viewModel.simiMVs.count + viewModel.relatedMVs.count
                if total > 3 {
                    Button(action: { showSimiSheet = true }) {
                        HStack(spacing: 4) {
                            Text(String(localized: "mv_more"))
                                .font(.rounded(size: 14, weight: .medium))
                                .foregroundColor(.asideTextSecondary)
                            AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary)
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
                                                .fill(Color.asideTextSecondary.opacity(0.06))
                                        }
                                        .aspectRatio(16/9, contentMode: .fill)
                                        .frame(width: 180, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    } else {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.asideTextSecondary.opacity(0.06))
                                            .frame(width: 180, height: 100)
                                    }

                                    if !mv.durationText.isEmpty {
                                        Text(mv.durationText)
                                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(.clear).glassEffect(.regular, in: .rect(cornerRadius: 16))
                                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                            .padding(6)
                                    }
                                }

                                Text(mv.name ?? String(localized: "mv_unknown"))
                                    .font(.rounded(size: 13, weight: .medium))
                                    .foregroundColor(.asideTextPrimary)
                                    .lineLimit(1)
                                Text(mv.artistName ?? "")
                                    .font(.rounded(size: 11))
                                    .foregroundColor(.asideTextSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 180)
                        }
                        .buttonStyle(AsideBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - 加载覆盖

    private var loadingOverlay: some View {
        ZStack {
            Color.asideBackground.opacity(0.6).ignoresSafeArea()
            AsideLoadingView(text: "LOADING MV")
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
            mvCurrentTime: mvCurrentTime,
            mvDuration: mvDuration,
            mvName: viewModel.detail?.name,
            mvPlayer: mvPlayer,
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
                mvPlayer.seek(to: value)
                mvCurrentTime = value
                isSeeking = false
            }
        )
    }

    // MARK: - 辅助方法

    /// 定时轮询 mvPlayer 的播放时间
    private func startMVTimeUpdater() {
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            DispatchQueue.main.async {
                guard !isSeeking else { return }
                let t = mvPlayer.currentTime
                if t.isFinite && !t.isNaN { mvCurrentTime = t }
                if let d = mvPlayer.streamInfo?.duration, d > 0 { mvDuration = d }
            }
        }
    }

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
            mvPlayer.pause()
        } else {
            mvPlayer.resume()
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
        mvPlayer.stop()
        viewModel.simiMVs = []
        viewModel.relatedMVs = []
        viewModel.detail = nil
        viewModel.videoUrl = nil
        viewModel.detailInfo = nil
        dismiss()
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: "%.1f亿", Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: "%.1f万", Double(count) / 10_000)
        }
        return "\(count)"
    }

    // MARK: - 相似推荐 Sheet

    private var simiSheet: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.asideTextSecondary.opacity(0.25))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            HStack {
                Text(String(localized: "mv_related"))
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                Spacer()
                let total = viewModel.simiMVs.count + viewModel.relatedMVs.count
                Text("\(total)个")
                    .font(.rounded(size: 13))
                    .foregroundColor(.asideTextSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Rectangle()
                .fill(Color.asideSeparator)
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
        }
        .background {
            Rectangle()
                .fill(Color.asideGlassTint)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func simiSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.rounded(size: 14, weight: .semibold))
            .foregroundColor(.asideTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}
