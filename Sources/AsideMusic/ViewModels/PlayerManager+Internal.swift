// PlayerManager+Internal.swift
// AsideMusic
//
// 内部播放逻辑：shuffle 生成、播放结束处理、无缝切歌、预加载、loadAndPlay

import Foundation
import Combine
import FFmpegSwiftSDK
import QQMusicKit

extension PlayerManager {
    
    // MARK: - Internal Methods
    
    /// 根据歌曲来源获取歌词（统一入口，避免重复判断）
    func fetchLyricsForSong(_ song: Song) {
        if song.isQQMusic, let mid = song.qqMid {
            LyricViewModel.shared.fetchQQLyrics(mid: mid, songId: song.id)
        } else {
            LyricViewModel.shared.fetchLyrics(for: song.id)
        }
    }
    
    /// 根据歌曲来源加载副歌时间和动态封面（仅网易云）
    func loadSongExtras(for song: Song) {
        chorusStartTime = nil
        chorusEndTime = nil
        dynamicCoverUrl = nil
        if !song.isQQMusic {
            loadChorusTime(songId: song.id)
            loadDynamicCover(songId: song.id)
        }
    }
    
    func generateShuffledContext() {
        guard let current = currentSong else {
            shuffledContext = context.shuffled()
            return
        }
        
        var shuffled = context.shuffled()
        if let index = shuffled.firstIndex(where: { $0.id == current.id }) {
            shuffled.remove(at: index)
            shuffled.insert(current, at: 0)
        }
        shuffledContext = shuffled
        contextIndex = 0
    }
    
    /// StreamPlayer 播放结束回调（由 delegate adapter 调用）
    func playerDidFinishPlaying() {
        AppLogger.info("playerDidFinishPlaying 被调用, currentTime=\(currentTime), duration=\(duration), song=\(currentSong?.name ?? "nil")")
        switch mode {
        case .loopSingle:
            // 重新播放当前歌曲
            if let song = currentSong {
                loadAndPlay(song: song)
            }
        case .sequence, .shuffle:
            next()
        }
    }
    
    /// 无缝切歌：SDK 已自动切换到下一首的 pipeline，这里只更新 UI 状态
    func advanceToNextTrack() {
        guard mode != .loopSingle else { return }
        
        consecutiveFailures = 0
        retryDelay = 1.0
        
        // 从 context 列表取下一首
        let list = currentContextList
        guard !list.isEmpty else { return }
        
        var nextIndex = contextIndex + 1
        if nextIndex >= list.count {
            nextIndex = 0
        }
        
        contextIndex = nextIndex
        let song = list[nextIndex]
        
        // 立即更新 UI（SDK 已经在播放下一首了）
        currentSong = song
        fetchLyricsForSong(song)
        loadSongExtras(for: song)
        addToHistory(song: song)
        saveState()
        updateNowPlayingInfo()
        updateNowPlayingArtwork(for: song)
    }
    
    /// 准备下一首歌曲信息（不更新 UI，等待当前歌曲真正结束）
    func preparePendingNextTrack() {
        guard mode != .loopSingle else { return }
        
        let list = currentContextList
        guard !list.isEmpty else { return }
        
        var nextIndex = contextIndex + 1
        if nextIndex >= list.count {
            nextIndex = 0
        }
        pendingNextSong = list[nextIndex]
    }
    
    /// 当前歌曲真正结束后，应用待切换的下一首
    func applyPendingTrackTransition() {
        guard hasPendingTrackTransition, let song = pendingNextSong else {
            // 安全清理：如果 pendingNextSong 为 nil 但 hasPendingTrackTransition 为 true，重置标记
            if hasPendingTrackTransition {
                AppLogger.warning("applyPendingTrackTransition: pendingNextSong 为 nil，重置标记")
                hasPendingTrackTransition = false
                pendingNextSong = nil
            }
            return
        }
        
        hasPendingTrackTransition = false
        pendingNextSong = nil
        pendingTransitionStartedAt = nil
        consecutiveFailures = 0
        retryDelay = 1.0
        
        // 更新队列索引
        if let index = currentContextList.firstIndex(where: { $0.id == song.id }) {
            contextIndex = index
        }
        
        // 更新 UI
        currentSong = song
        currentTime = 0
        
        // 确保播放状态正确（无缝切歌时 SDK 一直在播放，isPlaying 应为 true）
        if !isPlaying {
            isPlaying = true
        }
        
        // 从 streamInfo 获取下一首的 duration（transitionToNextTrack 中不再单独发送 didUpdateDuration）
        if let nextDuration = streamPlayer.streamInfo?.duration, nextDuration > 0 {
            duration = nextDuration
        }
        
        fetchLyricsForSong(song)
        loadSongExtras(for: song)
        addToHistory(song: song)
        saveState()
        updateNowPlayingInfo()
        updateNowPlayingArtwork(for: song)
    }
    
    /// 预加载下一首歌曲的 URL，传给 StreamPlayer.prepareNext
    func prepareNextTrackURL() {
        guard mode != .loopSingle else { return }
        
        let list = currentContextList
        guard !list.isEmpty else { return }
        var nextIndex = contextIndex + 1
        if nextIndex >= list.count {
            nextIndex = 0
        }
        let song = list[nextIndex]
        
        // 优先使用本地文件
        if let localURL = DownloadManager.shared.localFileURL(songId: song.id) {
            AppLogger.info("预加载下一首 (本地): \(song.name)")
            streamPlayer.prepareNext(url: localURL.absoluteString)
            return
        }
        
        nextTrackCancellable?.cancel()
        
        // 网络获取 URL
        if song.isQQMusic, let mid = song.qqMid {
            let quality = self.qqMusicQuality
            Task { @MainActor in
                self.nextTrackCancellable = APIService.shared.fetchQQSongUrl(mid: mid, quality: quality)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            AppLogger.warning("[QQMusic] 预加载下一首 URL 获取失败: \(error)")
                        }
                    }, receiveValue: { [weak self] result in
                        guard let self = self, let url = URL(string: result.url) else { return }
                        AppLogger.info("[QQMusic] 预加载下一首 (网络): \(song.name)")
                        self.streamPlayer.prepareNext(url: url.absoluteString)
                    })
            }
        } else {
            Task { @MainActor in
                self.nextTrackCancellable = APIService.shared.fetchSongUrl(
                    id: song.id,
                    level: self.soundQuality.rawValue,
                    kugouQuality: self.kugouQuality.rawValue
                )
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        AppLogger.warning("预加载下一首 URL 获取失败: \(error)")
                    }
                }, receiveValue: { [weak self] result in
                    guard let self = self, let url = URL(string: result.url) else { return }
                    AppLogger.info("预加载下一首 (网络): \(song.name)")
                    self.streamPlayer.prepareNext(url: url.absoluteString)
                })
            }
        }
    }
    
    func loadAndPlay(song: Song, autoPlay: Bool = true, startTime: Double = 0) {
        // 用户主动切歌（非 previous 回退）时，把当前歌曲压入回退栈
        if !isApplyingBackNavigation,
           let current = currentSong,
           current.id != song.id {
            playbackBackStack.append(current)
            if playbackBackStack.count > maxBackStackSize {
                playbackBackStack.removeFirst(playbackBackStack.count - maxBackStackSize)
            }
        }

        // 递增会话 ID，旧会话的回调会被忽略
        playbackSessionId += 1
        // 清除待切换状态（用户手动切歌）
        hasPendingTrackTransition = false
        pendingNextSong = nil
        pendingTransitionStartedAt = nil
        // 清除 seek 状态
        isSeeking = false
        seekTargetTime = nil
        seekStartedAt = nil
        
        isLoading = true
        currentSong = song
        currentTime = 0
        isCurrentSongUnblocked = false
        streamInfo = nil
        // 切歌时重置异常停止计数器
        if startTime == 0 {
            abnormalStopRetryCount = 0
        }
        addToHistory(song: song)
        saveState()
        
        // 全局歌词获取（根据来源选择不同歌词接口）
        fetchLyricsForSong(song)
        
        // 加载副歌时间和动态封面
        loadSongExtras(for: song)
        
        // 上报听歌记录到网易云（仅网易云歌曲）
        if !song.isQQMusic {
            scrobbleToCloud(song: song)
        }

        // 优先使用本地已下载文件
        if let localURL = DownloadManager.shared.localFileURL(songId: song.id) {
            AppLogger.info("使用本地下载文件播放: \(song.name)")
            self.consecutiveFailures = 0
            self.retryDelay = 1.0
            self.startPlayback(url: localURL, autoPlay: autoPlay, startTime: startTime)
            return
        }

        // 根据歌曲来源获取播放 URL
        if song.isQQMusic, let mid = song.qqMid {
            loadAndPlayQQSong(mid: mid, song: song, autoPlay: autoPlay, startTime: startTime)
        } else {
            loadAndPlayNeteaseSong(song: song, autoPlay: autoPlay, startTime: startTime)
        }
    }
    
    /// 加载并播放网易云歌曲
    private func loadAndPlayNeteaseSong(song: Song, autoPlay: Bool, startTime: Double) {
        let sessionId = playbackSessionId
        playbackURLCancellable?.cancel()
        
        Task { @MainActor in
            self.playbackURLCancellable = APIService.shared.fetchSongUrl(
                id: song.id,
                level: self.soundQuality.rawValue,
                kugouQuality: self.kugouQuality.rawValue
            )
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    guard self.playbackSessionId == sessionId else { return }
                    if case .failure(let error) = completion {
                        AppLogger.error("获取播放 URL 失败: \(error)")
                        self.isLoading = false

                        let isUnavailable = (error as? APIService.PlaybackError) == .unavailable

                        self.consecutiveFailures += 1

                        if self.consecutiveFailures >= self.maxConsecutiveFailures {
                            AlertManager.shared.show(
                                title: isUnavailable ? "无法播放" : "播放失败",
                                message: isUnavailable
                                    ? "连续多首歌曲暂无版权"
                                    : "连续多首歌曲无法播放，请检查网络连接",
                                primaryButtonTitle: "确定",
                                primaryAction: {}
                            )
                            self.consecutiveFailures = 0
                            self.retryDelay = 1.0
                            return
                        }

                        if autoPlay {
                            let currentDelay = self.retryDelay
                            self.retryDelay = min(self.retryDelay * 2, self.maxRetryDelay)
                            DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) { [weak self] in
                                self?.autoNext()
                            }
                        }
                    }
                }, receiveValue: { [weak self] result in
                    guard let self = self, let url = URL(string: result.url) else { return }
                    guard self.playbackSessionId == sessionId else { return }
                    self.consecutiveFailures = 0
                    self.retryDelay = 1.0
                    self.isCurrentSongUnblocked = result.isUnblocked
                    
                    #if DEBUG
                    print("[PlayerManager] 网易云歌曲 URL 获取成功: \(song.name), isUnblocked=\(result.isUnblocked)")
                    #endif
                    
                    if SettingsManager.shared.listenAndSave,
                       !DownloadManager.shared.isDownloaded(songId: song.id) {
                        DownloadManager.shared.download(song: song, quality: self.soundQuality)
                    }
                    
                    self.startPlayback(url: url, autoPlay: autoPlay, startTime: startTime)
                })
        }
    }
    
    func autoNext() {
        // 自动下一首（播放失败时调用），不重置 consecutiveFailures
        let list = currentContextList
        guard !list.isEmpty else { return }
        
        var nextIndex = contextIndex + 1
        if nextIndex >= list.count {
            nextIndex = 0
        }
        
        contextIndex = nextIndex
        loadAndPlay(song: list[nextIndex])
    }
    
    func startPlayback(url: URL, autoPlay: Bool = true, startTime: Double = 0) {
        isLoading = true
        
        if startTime <= 0 {
            self.currentTime = 0
            self.duration = 0
        }
        
        // 保存当前播放 URL（用于音频分析等功能）
        self.currentPlayingURL = url.absoluteString
        
        AppLogger.network("开始播放 (FFmpeg): \(url.absoluteString)")
        
        AppLogger.info("startPlayback session=\(playbackSessionId), url=\(url.lastPathComponent)")
        
        // 使用 StreamPlayer 播放
        streamPlayer.play(url: url.absoluteString)
        
        if !autoPlay {
            // 如果不自动播放，立即暂停
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.streamPlayer.pause()
                self?.isPlaying = false
            }
        }
        
        // seek 到指定位置（切换音质时保留进度）
        if startTime > 0 {
            streamPlayer.seek(to: startTime)
            currentTime = startTime
        }
        
        updateNowPlayingInfo()
        updateNowPlayingArtwork(for: currentSong)
    }
    
    /// 加载并播放 QQ 音乐歌曲
    private func loadAndPlayQQSong(mid: String, song: Song, autoPlay: Bool, startTime: Double) {
        let quality = qqMusicQuality
        let sessionId = playbackSessionId
        playbackURLCancellable?.cancel()
        
        Task { @MainActor in
            self.playbackURLCancellable = APIService.shared.fetchQQSongUrl(mid: mid, quality: quality)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    guard self.playbackSessionId == sessionId else { return }
                    if case .failure(let error) = completion {
                        AppLogger.error("[QQMusic] 获取播放 URL 失败: \(error)")
                        self.isLoading = false
                        
                        self.consecutiveFailures += 1
                        if self.consecutiveFailures >= self.maxConsecutiveFailures {
                            AlertManager.shared.show(
                                title: "无法播放",
                                message: "QQ音乐连续多首歌曲无法播放",
                                primaryButtonTitle: "确定",
                                primaryAction: {}
                            )
                            self.consecutiveFailures = 0
                            self.retryDelay = 1.0
                            return
                        }
                        
                        if autoPlay {
                            let currentDelay = self.retryDelay
                            self.retryDelay = min(self.retryDelay * 2, self.maxRetryDelay)
                            DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) { [weak self] in
                                self?.autoNext()
                            }
                        }
                    }
                }, receiveValue: { [weak self] result in
                    guard let self = self, let url = URL(string: result.url) else { return }
                    guard self.playbackSessionId == sessionId else { return }
                    self.consecutiveFailures = 0
                    self.retryDelay = 1.0
                    self.isCurrentSongUnblocked = false
                    
                    if SettingsManager.shared.listenAndSave,
                       !DownloadManager.shared.isDownloaded(songId: song.id) {
                        DownloadManager.shared.downloadQQ(song: song, quality: self.qqMusicQuality)
                    }
                    
                    AppLogger.info("[QQMusic] 开始播放: \(song.name)")
                    self.startPlayback(url: url, autoPlay: autoPlay, startTime: startTime)
                })
        }
    }
    
    // MARK: - 副歌时间加载
    
    private func loadChorusTime(songId: Int) {
        APIService.shared.fetchSongChorus(id: songId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] result in
                guard let self = self, self.currentSong?.id == songId else { return }
                self.chorusStartTime = result.startTime
                self.chorusEndTime = result.endTime
            })
            .store(in: &cancellables)
    }
    
    private func loadDynamicCover(songId: Int) {
        APIService.shared.fetchSongDynamicCover(id: songId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] url in
                guard let self = self, self.currentSong?.id == songId else { return }
                self.dynamicCoverUrl = url
            })
            .store(in: &cancellables)
    }
}
