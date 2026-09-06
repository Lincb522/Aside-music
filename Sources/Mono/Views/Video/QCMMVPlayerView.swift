// qcm MV 播放器
// 使用 AVPlayer 播放 qcm MV

import SwiftUI
import Combine

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
    private var hasStartedLoading = false
    
    init(vid: String) {
        self.vid = vid
    }
    
    func fetchData() {
        guard isLoading, !hasStartedLoading else { return }
        hasStartedLoading = true
        
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
                    self?.errorMessage = String(localized: "qqmv_no_url")
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
    private let player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var mvPlayerWrapper = MVPlayerWrapper()
    
    @State private var isPlaying = true
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var isSeeking = false
    @State private var seekValue: Double = 0
    @State private var isFullscreen = false
    
    init(vid: String) {
        self.vid = vid
        _viewModel = StateObject(wrappedValue: QQMVPlayerViewModel(vid: vid))
    }
    
    var body: some View {
        let _ = settings.globalThemeRevision

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
                AppLogger.info("[QQMVPlayer] 开始播放: \(url)")
                mvPlayerWrapper.play(url: url)
                isPlaying = true
            }
        }
        .statusBar(hidden: isFullscreen)
    }
    
    // MARK: - 全屏视图
    
    private var fullscreenView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AVPlayerVideoView(player: mvPlayerWrapper.player)
                .ignoresSafeArea()
            videoControlsOverlay(fullscreen: true)
                .ignoresSafeArea()
        }
    }
    
    // MARK: - 正常视图
    
    private var normalView: some View {
        ZStack {
            ThemedPageBackground().ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部栏
                HStack {
                    Button(action: { dismiss() }) {
                        MonoIcon(icon: .close, size: 22, color: .monoTextPrimary)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(MonoBouncingButtonStyle())
                    .contentShape(Rectangle())
                    
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
                        Text("MV")
                            .font(.rounded(size: 18, weight: .bold))
                            .foregroundColor(.monoTextPrimary)
                    }
                    
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, DeviceLayout.headerTopPadding)
                
                // 视频区域
                videoSection
                
                // 下方内容（可滚动）
                ScrollView {
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
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
            
            // 加载覆盖
            if viewModel.isLoading && viewModel.mvDetail == nil {
                ZStack {
                    Color.monoBackground.opacity(0.6).ignoresSafeArea()
                    MonoLoadingView(text: "LOADING MV")
                }
            }
        }
    }

    
    // MARK: - 视频区域

    /// aside 编辑部风格：默认主题走平排编辑部版式
    private var isAside: Bool {
        !ThemedPageStyle.isActive
    }

    private var videoSection: some View {
        let radius: CGFloat = isAside ? 18 : 20
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        return ZStack {
            shape.fill(Color.black)
            
            if viewModel.videoUrl != nil {
                AVPlayerVideoView(player: mvPlayerWrapper.player)
                    .clipShape(shape)
                videoControlsOverlay(fullscreen: false)
                    .clipShape(shape)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 14) {
                    MonoIcon(icon: .warning, size: 32, color: .white.opacity(0.4))
                    Text(error)
                        .font(.rounded(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button(String(localized: "radio_retry")) { viewModel.fetchData() }
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
        .padding(.top, 4)
    }
    
    // MARK: - MV 信息
    
    private var mvInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: isAside ? 8 : 6) {
                    if isAside {
                        HStack(spacing: 8) {
                            Capsule()
                                .fill(Color.monoAccent)
                                .frame(width: 18, height: 3)

                            Text("NOW SHOWING")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .tracking(2.2)
                                .foregroundColor(.monoTextSecondary.opacity(0.72))

                            PlatformBadgeLabel(text: "QCM", source: .qqmusic, fontSize: 10)
                        }

                        Text(viewModel.mvDetail?.name ?? String(localized: "qqmv_loading"))
                            .font(.rounded(size: 22, weight: .bold))
                            .foregroundColor(.monoTextPrimary)
                            .lineLimit(2)
                    } else {
                        HStack(spacing: 8) {
                            PlatformBadgeLabel(text: "QCM", source: .qqmusic, fontSize: 10)
                            
                            Text(viewModel.mvDetail?.name ?? String(localized: "qqmv_loading"))
                                .font(.rounded(size: 20, weight: .bold))
                                .foregroundColor(.monoTextPrimary)
                                .lineLimit(2)
                        }
                    }
                    
                    HStack(spacing: isAside ? 8 : 10) {
                        if let singer = viewModel.mvDetail?.singerName {
                            Text(singer)
                                .font(.rounded(size: isAside ? 13.5 : 14, weight: isAside ? .medium : .regular))
                                .foregroundColor(.monoTextSecondary)
                        }
                        
                        if let playCount = viewModel.mvDetail?.playCountText, !playCount.isEmpty {
                            if isAside {
                                Rectangle()
                                    .fill(Color.monoSeparator.opacity(0.9))
                                    .frame(width: 0.7, height: 10)
                            } else {
                                Text("·")
                                    .foregroundColor(.monoTextSecondary.opacity(0.4))
                            }
                            Text(playCount + String(localized: "qqmv_play_suffix"))
                                .font(.rounded(size: 12))
                                .foregroundColor(.monoTextSecondary.opacity(0.6))
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
                            MonoIcon(icon: .clock, size: 12, color: .monoTextSecondary.opacity(0.5))
                            Text(date)
                                .font(.rounded(size: 12))
                                .foregroundColor(.monoTextSecondary.opacity(0.6))
                        }
                    }
                    if let duration = viewModel.mvDetail?.durationText, !duration.isEmpty {
                        HStack(spacing: 4) {
                            MonoIcon(icon: .musicNote, size: 12, color: .monoTextSecondary.opacity(0.5))
                            Text(duration)
                                .font(.rounded(size: 12))
                                .foregroundColor(.monoTextSecondary.opacity(0.6))
                        }
                    }
                }
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.rounded(size: 14))
                    .foregroundColor(.monoTextSecondary)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - 同歌手其他 MV
    
    private var relatedMVsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: isAside ? .firstTextBaseline : .center) {
                if isAside {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Capsule()
                                .fill(Color.monoAccent)
                                .frame(width: 18, height: 3)

                            Text("MORE FROM ARTIST")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .tracking(2.2)
                                .foregroundColor(.monoTextSecondary.opacity(0.72))
                        }

                        Text("qqmv_more_mv")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.monoTextPrimary)
                    }
                } else {
                    Text("qqmv_more_mv")
                        .font(.rounded(size: 18, weight: .bold))
                        .foregroundColor(.monoTextPrimary)
                }
                Spacer()
                Text(String(format: String(localized: "qqmv_mv_count"), viewModel.relatedMVs.count))
                    .font(.rounded(size: 13))
                    .foregroundColor(.monoTextSecondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 24)
            
            // 横向滚动
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(viewModel.relatedMVs.prefix(10)) { mv in
                        Button(action: { switchToMV(mv) }) {
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
                                                .overlay {
                                                    MonoIcon(icon: .play, size: 24, color: .monoTextSecondary.opacity(0.3))
                                                }
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
                                
                                Text(mv.name)
                                    .font(.rounded(size: 13, weight: .medium))
                                    .foregroundColor(.monoTextPrimary)
                                    .lineLimit(1)
                                Text(mv.singerName ?? "")
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

    
    // MARK: - 视频控件覆盖层
    
    private func videoControlsOverlay(fullscreen: Bool) -> some View {
        MVPlaybackTimeReader(clock: mvPlayerWrapper.clock) { clock in
            MVVideoControlsOverlay(
                fullscreen: fullscreen,
                showControls: showControls,
                isPlaying: isPlaying,
                isSeeking: isSeeking,
                seekValue: seekValue,
                mvCurrentTime: clock.currentTime,
                mvDuration: clock.duration,
                mvName: viewModel.mvDetail?.name,
                onTogglePlayback: togglePlayPause,
                onToggleControlsVisibility: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showControls.toggle()
                    }
                    if showControls { scheduleControlsHide() }
                },
                onScheduleControlsHide: scheduleControlsHide,
                onEnterFullscreen: {
                    withAnimation(.easeInOut(duration: 0.3)) { isFullscreen = true }
                    OrientationManager.shared.enterLandscape()
                },
                onExitFullscreen: {
                    OrientationManager.shared.exitLandscape()
                    withAnimation(.easeInOut(duration: 0.3)) { isFullscreen = false }
                },
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
    }
    
    // MARK: - 辅助方法
    
    private func togglePlayPause() {
        if isPlaying {
            mvPlayerWrapper.pause()
        } else {
            mvPlayerWrapper.resume()
        }
        isPlaying.toggle()
        if isPlaying {
            scheduleControlsHide()
        } else {
            controlsTimer?.invalidate()
            showControls = true
        }
    }
    
    private func switchToMV(_ mv: QQMV) {
        mvPlayerWrapper.stop()
        dismiss()
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
}
