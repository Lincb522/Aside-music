// QQMVPlayerView.swift
// QQ 音乐 MV 播放器
// 使用 FFmpeg StreamPlayer 播放 QQ 音乐 MV

import SwiftUI
import Combine
import FFmpegSwiftSDK

// MARK: - QQ MV ViewModel

@MainActor
class QQMVPlayerViewModel: ObservableObject {
    @Published var mvDetail: QQMV?
    @Published var videoUrl: String?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var relatedMVs: [QQMV] = []
    @Published var isLoadingRelated = false
    
    let vid: String
    private var cancellables = Set<AnyCancellable>()
    
    init(vid: String) {
        self.vid = vid
    }
    
    func fetchData() {
        guard isLoading else { return }
        
        // 获取详情
        APIService.shared.fetchQQMVDetail(vid: vid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.error("[QQMVPlayer] 详情获取失败: \(error)")
                }
            }, receiveValue: { [weak self] detail in
                self?.mvDetail = detail
                // 获取同歌手的其他 MV
                if let singerMid = detail?.singerMid, !singerMid.isEmpty {
                    self?.fetchRelatedMVs(singerMid: singerMid)
                }
            })
            .store(in: &cancellables)
        
        // 获取播放 URL
        APIService.shared.fetchQQMVUrl(vid: vid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] url in
                self?.isLoading = false
                if let url, !url.isEmpty {
                    self?.videoUrl = url
                } else {
                    self?.errorMessage = "无法获取 MV 播放链接"
                }
            })
            .store(in: &cancellables)
    }
    
    private func fetchRelatedMVs(singerMid: String) {
        isLoadingRelated = true
        APIService.shared.fetchQQSingerMVs(mid: singerMid, num: 10, begin: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingRelated = false
            }, receiveValue: { [weak self] mvs in
                guard let self else { return }
                // 过滤掉当前正在播放的 MV
                self.relatedMVs = mvs.filter { $0.vid != self.vid }
            })
            .store(in: &cancellables)
    }
}


// MARK: - QQ MV 播放器视图

struct QQMVPlayerView: View {
    let vid: String
    @StateObject private var viewModel: QQMVPlayerViewModel
    @ObservedObject private var player = PlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var mvPlayerWrapper = MVStreamPlayerWrapper()
    private var mvPlayer: StreamPlayer { mvPlayerWrapper.player }
    
    @State private var isPlaying = true
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var mvCurrentTime: TimeInterval = 0
    @State private var mvDuration: TimeInterval = 0
    @State private var isSeeking = false
    @State private var seekValue: Double = 0
    @State private var timeUpdateTimer: Timer?
    @State private var isFullscreen = false
    
    init(vid: String) {
        self.vid = vid
        _viewModel = StateObject(wrappedValue: QQMVPlayerViewModel(vid: vid))
    }
    
    var body: some View {
        ZStack {
            if isFullscreen {
                fullscreenView
            } else {
                normalView
            }
        }
        .onAppear {
            player.isTabBarHidden = true
            if player.isPlaying { player.togglePlayPause() }
            viewModel.fetchData()
            startTimeUpdater()
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
                AppLogger.info("[QQMVPlayer] 开始播放: \(url)")
                mvPlayer.play(url: url)
                isPlaying = true
            }
        }
        .statusBar(hidden: isFullscreen)
    }
    
    // MARK: - 全屏视图
    
    private var fullscreenView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            FFmpegVideoView(displayLayer: mvPlayer.videoDisplayLayer)
                .ignoresSafeArea()
            videoControlsOverlay(fullscreen: true)
                .ignoresSafeArea()
        }
    }
    
    // MARK: - 正常视图
    
    private var normalView: some View {
        ZStack {
            AsideBackground().ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部栏
                HStack {
                    Button(action: { dismiss() }) {
                        AsideIcon(icon: .close, size: 22, color: .asideTextPrimary)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    .contentShape(Rectangle())
                    
                    Spacer()
                    
                    Text("MV")
                        .font(.rounded(size: 18, weight: .bold))
                        .foregroundColor(.asideTextPrimary)
                    
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, DeviceLayout.headerTopPadding)
                
                // 视频区域
                videoSection
                
                // 下方内容（可滚动）
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // MV 信息
                        mvInfoSection
                        
                        // 同歌手其他 MV
                        if !viewModel.relatedMVs.isEmpty {
                            relatedMVsSection
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 80)
                }
            }
            
            // 加载覆盖
            if viewModel.isLoading && viewModel.mvDetail == nil {
                ZStack {
                    Color.asideBackground.opacity(0.6).ignoresSafeArea()
                    AsideLoadingView(text: "LOADING MV")
                }
            }
        }
    }

    
    // MARK: - 视频区域
    
    private var videoSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black)
            
            if viewModel.videoUrl != nil {
                FFmpegVideoView(displayLayer: mvPlayer.videoDisplayLayer)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                videoControlsOverlay(fullscreen: false)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else if let error = viewModel.errorMessage {
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
        .padding(.top, 4)
    }
    
    // MARK: - MV 信息
    
    private var mvInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("QQ")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.green.opacity(0.8)))
                        
                        Text(viewModel.mvDetail?.name ?? "加载中...")
                            .font(.rounded(size: 20, weight: .bold))
                            .foregroundColor(.asideTextPrimary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 10) {
                        if let singer = viewModel.mvDetail?.singerName {
                            Text(singer)
                                .font(.rounded(size: 14))
                                .foregroundColor(.asideTextSecondary)
                        }
                        
                        if let playCount = viewModel.mvDetail?.playCountText, !playCount.isEmpty {
                            Text("·")
                                .foregroundColor(.asideTextSecondary.opacity(0.4))
                            Text(playCount + "播放")
                                .font(.rounded(size: 12))
                                .foregroundColor(.asideTextSecondary.opacity(0.6))
                        }
                        
                        // 硬件加速标签
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
                }
                
                Spacer()
            }
            
            // 发布日期 + 时长
            if viewModel.mvDetail != nil {
                HStack(spacing: 16) {
                    if let date = viewModel.mvDetail?.publishDate, !date.isEmpty {
                        HStack(spacing: 4) {
                            AsideIcon(icon: .clock, size: 12, color: .asideTextSecondary.opacity(0.5))
                            Text(date)
                                .font(.rounded(size: 12))
                                .foregroundColor(.asideTextSecondary.opacity(0.6))
                        }
                    }
                    if let duration = viewModel.mvDetail?.durationText, !duration.isEmpty {
                        HStack(spacing: 4) {
                            AsideIcon(icon: .musicNote, size: 12, color: .asideTextSecondary.opacity(0.5))
                            Text(duration)
                                .font(.rounded(size: 12))
                                .foregroundColor(.asideTextSecondary.opacity(0.6))
                        }
                    }
                }
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.rounded(size: 14))
                    .foregroundColor(.asideTextSecondary)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - 同歌手其他 MV
    
    private var relatedMVsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("更多MV")
                    .font(.rounded(size: 18, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                Spacer()
                Text("\(viewModel.relatedMVs.count)个")
                    .font(.rounded(size: 13))
                    .foregroundColor(.asideTextSecondary)
            }
            .padding(.horizontal, 24)
            
            // 横向滚动
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.relatedMVs.prefix(10)) { mv in
                        Button(action: { switchToMV(mv) }) {
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
                                            .overlay {
                                                AsideIcon(icon: .play, size: 24, color: .asideTextSecondary.opacity(0.3))
                                            }
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
                                
                                Text(mv.name)
                                    .font(.rounded(size: 13, weight: .medium))
                                    .foregroundColor(.asideTextPrimary)
                                    .lineLimit(1)
                                Text(mv.singerName ?? "")
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

    
    // MARK: - 视频控件覆盖层
    
    private func videoControlsOverlay(fullscreen: Bool) -> some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showControls.toggle()
                    }
                    if showControls { scheduleControlsHide() }
                }
            
            if showControls {
                Color.black.opacity(0.3)
                    .allowsHitTesting(false)
                
                // 中央播放/暂停
                Button(action: togglePlayPause) {
                    AsideIcon(
                        icon: isPlaying ? .pause : .play,
                        size: 48,
                        color: .white
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8)
                }
                .buttonStyle(AsideBouncingButtonStyle())
                .contentShape(Rectangle())
                
                // 底部进度条
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Text(formatTime(mvCurrentTime))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Slider(
                            value: isSeeking ? $seekValue : .constant(mvDuration > 0 ? mvCurrentTime / mvDuration : 0),
                            in: 0...1,
                            onEditingChanged: { editing in
                                isSeeking = editing
                                if !editing {
                                    let targetTime = seekValue * mvDuration
                                    mvPlayer.seek(to: targetTime)
                                    mvCurrentTime = targetTime
                                }
                            }
                        )
                        .tint(.white)
                        
                        Text(formatTime(mvDuration))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Button(action: toggleFullscreen) {
                            AsideIcon(
                                icon: fullscreen ? .shrinkScreen : .expandScreen,
                                size: 18,
                                color: .white
                            )
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                        .contentShape(Rectangle())
                    }
                    .padding(.horizontal, fullscreen ? 24 : 16)
                    .padding(.bottom, fullscreen ? 20 : 12)
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func togglePlayPause() {
        if isPlaying {
            mvPlayer.pause()
        } else {
            mvPlayer.resume()
        }
        isPlaying.toggle()
        if isPlaying {
            scheduleControlsHide()
        } else {
            controlsTimer?.invalidate()
            showControls = true
        }
    }
    
    private func toggleFullscreen() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isFullscreen.toggle()
        }
        if isFullscreen {
            OrientationManager.shared.enterLandscape()
        } else {
            OrientationManager.shared.exitLandscape()
        }
    }
    
    /// 切换到另一个 MV（dismiss 当前，由外部重新打开）
    private func switchToMV(_ mv: QQMV) {
        mvPlayer.stop()
        dismiss()
        // 由于 fullScreenCover 的限制，切换 MV 需要先 dismiss 再重新打开
        // 这里只能 dismiss，用户需要从列表重新点击
    }
    
    private func startTimeUpdater() {
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [self] _ in
            Task { @MainActor in
                if !isSeeking {
                    let t = mvPlayer.currentTime
                    if t.isFinite && !t.isNaN { mvCurrentTime = t }
                    if let d = mvPlayer.streamInfo?.duration, d > 0 { mvDuration = d }
                }
            }
        }
    }
    
    private func scheduleControlsHide() {
        controlsTimer?.invalidate()
        guard isPlaying else { return }
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls = false
                }
            }
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
