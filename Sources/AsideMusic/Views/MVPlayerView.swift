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
    private var statusCheckTimer: Timer?
    
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
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        statusCheckTimer?.invalidate()
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
            guard let self, let layer = self.displayLayer else { return }
            DispatchQueue.main.async {
                // 检查是否需要 flush 才能恢复解码
                if layer.status == .failed || layer.requiresFlushToResumeDecoding {
                    print("[VideoContainerView] ⚠️ displayLayer 需要 flush，正在恢复...")
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
    @StateObject private var viewModel: MVPlayerViewModel
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
        _viewModel = StateObject(wrappedValue: MVPlayerViewModel(mvId: mvId))
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
                print("[MVPlayer] 🎬 开始播放视频: \(url)")
                mvPlayer.play(url: url)
                isPlaying = true
            } else {
                print("[MVPlayer] ⚠️ 视频 URL 无效: \(url ?? "nil")")
            }
        }
        .onChange(of: viewModel.detail?.name) { _, name in
            print("[MVPlayer View] detail.name 变化: \(name ?? "nil")")
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
            videoControlsOverlay(fullscreen: true)
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
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // MV 信息 + 收藏
                        infoSection

                        // 相关推荐预览
                        if !viewModel.simiMVs.isEmpty || !viewModel.relatedMVs.isEmpty {
                            relatedPreview
                        }

                        // 内嵌评论区
                        embeddedCommentSection
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 80)
                }

                // 底部评论输入栏
                commentInputBar
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
            Text("MV")
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
                videoControlsOverlay(fullscreen: false)
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
                    Button("重试") { viewModel.fetchData() }
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
                    Text(detail.name ?? "未知MV")
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
                            Text(formatCount(count) + "播放")
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
                Text("相关推荐")
                    .font(.rounded(size: 18, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                Spacer()
                let total = viewModel.simiMVs.count + viewModel.relatedMVs.count
                if total > 3 {
                    Button(action: { showSimiSheet = true }) {
                        HStack(spacing: 4) {
                            Text("更多")
                                .font(.rounded(size: 14, weight: .medium))
                                .foregroundColor(.asideTextSecondary)
                            AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            // 横向滚动展示
            ScrollView(.horizontal, showsIndicators: false) {
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
                                            .background(.ultraThinMaterial)
                                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                            .padding(6)
                                    }
                                }

                                Text(mv.name ?? "未知MV")
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

    // MARK: - 内嵌评论区

    private var embeddedCommentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 评论区标题
            HStack(alignment: .bottom) {
                HStack(spacing: 6) {
                    Text("评论")
                        .font(.rounded(size: 22, weight: .bold))
                        .foregroundColor(.asideTextPrimary)
                    if commentVM.totalCount > 0 {
                        Text("\(commentVM.totalCount)")
                            .font(.rounded(size: 14, weight: .medium))
                            .foregroundColor(.asideTextSecondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 24)

            // 排序标签
            HStack(spacing: 8) {
                ForEach(CommentSortType.allCases, id: \.rawValue) { type in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            commentVM.changeSortType(type)
                        }
                    } label: {
                        Text(type.title)
                            .font(.rounded(size: 13, weight: commentVM.sortType == type ? .semibold : .medium))
                            .foregroundColor(commentVM.sortType == type ? .asideIconForeground : .asideTextSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(commentVM.sortType == type ? Color.asideIconBackground : Color.asideTextPrimary.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 24)

            if commentVM.isLoading {
                // 骨架屏
                VStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(Color.asideTextPrimary.opacity(0.06))
                                .frame(width: 36, height: 36)
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.asideTextPrimary.opacity(0.06))
                                    .frame(width: 80, height: 12)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.asideTextPrimary.opacity(0.04))
                                    .frame(height: 14)
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 24)
            } else if commentVM.comments.isEmpty && commentVM.hotComments.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    AsideIcon(icon: .comment, size: 32, color: .asideTextSecondary.opacity(0.25))
                    Text("暂无评论")
                        .font(.rounded(size: 15))
                        .foregroundColor(.asideTextSecondary)
                    Text("来发表第一条评论吧")
                        .font(.rounded(size: 13))
                        .foregroundColor(.asideTextSecondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 14) {
                    // 热门评论
                    if !commentVM.hotComments.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                AsideIcon(icon: .sparkle, size: 14, color: .asideOrange)
                                Text("热门评论")
                                    .font(.rounded(size: 14, weight: .semibold))
                                    .foregroundColor(.asideTextPrimary)
                            }
                            .padding(.leading, 4)

                            VStack(spacing: 0) {
                                ForEach(Array(commentVM.hotComments.enumerated()), id: \.element.id) { index, comment in
                                    CommentRow(
                                        comment: comment,
                                        isHot: true,
                                        onLike: { commentVM.toggleLike(comment: comment, isHot: true) },
                                        onReply: {
                                            commentVM.replyTarget = comment
                                            isInputFocused = true
                                        }
                                    )
                                    if index < commentVM.hotComments.count - 1 {
                                        Divider().padding(.leading, 52)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.asideGlassOverlay))
                                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    // 全部评论
                    if !commentVM.comments.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Text("全部评论")
                                    .font(.rounded(size: 14, weight: .semibold))
                                    .foregroundColor(.asideTextPrimary)
                                if commentVM.totalCount > 0 {
                                    Text("\(commentVM.totalCount)")
                                        .font(.rounded(size: 12, weight: .medium))
                                        .foregroundColor(.asideTextSecondary)
                                }
                            }
                            .padding(.leading, 4)

                            VStack(spacing: 0) {
                                ForEach(Array(commentVM.comments.enumerated()), id: \.element.id) { index, comment in
                                    CommentRow(
                                        comment: comment,
                                        isHot: false,
                                        onLike: { commentVM.toggleLike(comment: comment, isHot: false) },
                                        onReply: {
                                            commentVM.replyTarget = comment
                                            isInputFocused = true
                                        }
                                    )
                                    if index < commentVM.comments.count - 1 {
                                        Divider().padding(.leading, 52)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.asideGlassOverlay))
                                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    // 加载更多
                    if commentVM.hasMore {
                        Button {
                            commentVM.loadMore()
                        } label: {
                            HStack(spacing: 8) {
                                if commentVM.isLoadingMore {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Text("加载更多评论")
                                        .font(.rounded(size: 14, weight: .medium))
                                }
                            }
                            .foregroundColor(.asideTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.asideTextPrimary.opacity(0.04))
                            )
                        }
                        .disabled(commentVM.isLoadingMore)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - 底部评论输入栏

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.asideSeparator)
                .frame(height: 0.5)

            // 回复提示
            if let reply = commentVM.replyTarget {
                HStack(spacing: 8) {
                    Text("回复")
                        .font(.rounded(size: 12))
                        .foregroundColor(.asideTextSecondary)
                    Text("@\(reply.user.nickname)")
                        .font(.rounded(size: 12, weight: .medium))
                        .foregroundColor(.asideTextPrimary)
                    Spacer()
                    Button {
                        withAnimation { commentVM.replyTarget = nil }
                    } label: {
                        AsideIcon(icon: .xmark, size: 10, color: .asideTextSecondary)
                            .padding(6)
                            .background(Circle().fill(Color.asideTextPrimary.opacity(0.06)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    TextField(
                        commentVM.replyTarget != nil ? "回复 @\(commentVM.replyTarget!.user.nickname)..." : "写评论...",
                        text: $commentVM.commentText
                    )
                    .font(.rounded(size: 15))
                    .focused($isInputFocused)

                    if !commentVM.commentText.isEmpty {
                        Button {
                            commentVM.commentText = ""
                        } label: {
                            AsideIcon(icon: .xmark, size: 10, color: .asideTextSecondary)
                                .padding(4)
                                .background(Circle().fill(Color.asideTextPrimary.opacity(0.08)))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.asideTextPrimary.opacity(0.05))
                )

                let canSend = !commentVM.commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !commentVM.isSending
                Button {
                    commentVM.sendComment()
                    isInputFocused = false
                } label: {
                    ZStack {
                        Circle()
                            .fill(canSend ? Color.asideIconBackground : Color.asideTextPrimary.opacity(0.06))
                            .frame(width: 36, height: 36)
                        if commentVM.isSending {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.asideIconForeground)
                        } else {
                            AsideIcon(
                                icon: .send,
                                size: 16,
                                color: canSend ? .asideIconForeground : .asideTextSecondary.opacity(0.4)
                            )
                        }
                    }
                }
                .disabled(!canSend)
                .buttonStyle(AsideBouncingButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .padding(.bottom, 4)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - 自定义播放器控件覆盖层

    private func videoControlsOverlay(fullscreen: Bool) -> some View {
        ZStack {
            // 点击区域：切换控件显隐
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { toggleControlsVisibility() }

            if showControls || !isPlaying {
                // 半透明渐变遮罩
                VStack(spacing: 0) {
                    // 顶部渐变
                    LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: fullscreen ? 80 : 50)
                    Spacer()
                    // 底部渐变
                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                        .frame(height: fullscreen ? 100 : 70)
                }
                .allowsHitTesting(false)

                // 中央播放/暂停
                Button(action: { togglePlayback(); scheduleControlsHide() }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: fullscreen ? 64 : 52, height: fullscreen ? 64 : 52)
                        AsideIcon(
                            icon: isPlaying ? .pause : .play,
                            size: fullscreen ? 26 : 22,
                            color: .white
                        )
                        .offset(x: isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.9))

                // 顶部栏
                VStack {
                    HStack {
                        if fullscreen {
                            Button(action: exitFullscreen) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 38, height: 38)
                                    AsideIcon(icon: .shrinkScreen, size: 15, color: .white)
                                }
                            }
                            .buttonStyle(AsideBouncingButtonStyle())

                            if let name = viewModel.detail?.name {
                                Text(name)
                                    .font(.rounded(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .padding(.leading, 6)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, fullscreen ? 20 : 12)
                    .padding(.top, fullscreen ? 12 : 8)
                    Spacer()
                }

                // 底部控件栏
                VStack {
                    Spacer()
                    VStack(spacing: fullscreen ? 10 : 6) {
                        // 进度条
                        progressBar(fullscreen: fullscreen)

                        // 时间 + 全屏按钮
                        HStack(spacing: 8) {
                            Text(formatTime(isSeeking ? seekValue : mvCurrentTime))
                                .font(.system(size: fullscreen ? 12 : 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))

                            Text("/")
                                .font(.system(size: fullscreen ? 11 : 9, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))

                            Text(formatTime(mvDuration))
                                .font(.system(size: fullscreen ? 12 : 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))

                            Spacer()

                            Button(action: { fullscreen ? exitFullscreen() : enterFullscreen() }) {
                                AsideIcon(
                                    icon: fullscreen ? .shrinkScreen : .expandScreen,
                                    size: fullscreen ? 16 : 14,
                                    color: .white.opacity(0.9)
                                )
                                .frame(width: 32, height: 32)
                            }
                            .buttonStyle(AsideBouncingButtonStyle())
                        }
                    }
                    .padding(.horizontal, fullscreen ? 20 : 12)
                    .padding(.bottom, fullscreen ? 16 : 8)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showControls)
    }

    // MARK: - 进度条

    private func progressBar(fullscreen: Bool) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let barHeight: CGFloat = fullscreen ? 4 : 3
            let progress = mvDuration > 0 ? (isSeeking ? seekValue : mvCurrentTime) / mvDuration : 0
            let thumbSize: CGFloat = isSeeking ? (fullscreen ? 16 : 14) : (fullscreen ? 10 : 8)

            ZStack(alignment: .leading) {
                // 轨道背景
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: barHeight)

                // 已播放进度
                Capsule()
                    .fill(Color.asideAccent)
                    .frame(width: max(0, width * CGFloat(progress)), height: barHeight)

                // 拖拽拇指
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .offset(x: max(0, min(width * CGFloat(progress) - thumbSize / 2, width - thumbSize)))
            }
            .frame(height: max(barHeight, thumbSize))
            .contentShape(Rectangle().inset(by: -12))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isSeeking = true
                        let ratio = max(0, min(value.location.x / width, 1))
                        seekValue = Double(ratio) * mvDuration
                        scheduleControlsHide()
                    }
                    .onEnded { value in
                        let ratio = max(0, min(value.location.x / width, 1))
                        let target = Double(ratio) * mvDuration
                        mvPlayer.seek(to: target)
                        mvCurrentTime = target
                        isSeeking = false
                        scheduleControlsHide()
                    }
            )
        }
        .frame(height: fullscreen ? 16 : 14)
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

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "0:00" }
        let total = Int(max(0, seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - 相似推荐 Sheet

    private var simiSheet: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.asideTextSecondary.opacity(0.25))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            HStack {
                Text("相关推荐")
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

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    if !viewModel.simiMVs.isEmpty {
                        simiSectionLabel("相似MV")
                        ForEach(viewModel.simiMVs) { mv in
                            MVRowCard(mv: mv) {
                                showSimiSheet = false
                                switchToMV(mv.id)
                            }
                        }
                    }

                    if !viewModel.relatedMVs.isEmpty {
                        simiSectionLabel("相关视频")
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
                .fill(.ultraThinMaterial)
                .overlay(Color.asideCardBackground.opacity(0.55))
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
