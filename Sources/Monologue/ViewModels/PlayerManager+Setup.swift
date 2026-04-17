// PlayerManager+Setup.swift
// Monologue
//
// 播放器初始化设置：音频会话、远程控制、StreamPlayer 代理、定时器

import Foundation
import AVFoundation
import MediaPlayer
import FFmpegSwiftSDK

extension PlayerManager {
    
    /// 独占播放模式（默认）：系统将本 App 识别为主媒体播放器，锁屏/灵动岛正常显示。
    /// `.playback` 本身就支持常规蓝牙音频输出，这里不要再叠加 `.allowBluetoothA2DP`，
    /// 否则会触发 NSOSStatusErrorDomain Code=-50（无效参数）。
    nonisolated static let playbackAudioSessionOptions: AVAudioSession.CategoryOptions = []
    /// 共存播放模式：与游戏、短视频等混音，但系统不再将本 App 视为主媒体播放器。
    nonisolated static let mixingAudioSessionOptions: AVAudioSession.CategoryOptions = [.mixWithOthers]

    private func audioSessionOptions(otherAudioPlaying: Bool? = nil) -> AVAudioSession.CategoryOptions {
        switch SettingsManager.shared.backgroundAudioPolicy {
        case .exclusive:
            return Self.playbackAudioSessionOptions
        case .automatic:
            let shouldMix = otherAudioPlaying ?? AVAudioSession.sharedInstance().isOtherAudioPlaying
            return shouldMix ? Self.mixingAudioSessionOptions : Self.playbackAudioSessionOptions
        case .alwaysMix:
            return Self.mixingAudioSessionOptions
        }
    }

    func handleBackgroundAudioPolicySettingChanged() {
        let session = AVAudioSession.sharedInstance()
        let options = audioSessionOptions(otherAudioPlaying: session.isOtherAudioPlaying)

        do {
            try session.setCategory(.playback, mode: .default, options: options)
            try session.setActive(true)
            if currentSong != nil {
                updateNowPlayingInfo()
                updateNowPlayingArtwork(for: currentSong)
            }
        } catch {
            AppLogger.error("应用后台音频策略失败: \(error)")
        }
    }

    // MARK: - Setup

    func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            let otherPlaying = session.isOtherAudioPlaying
            let opts = audioSessionOptions(otherAudioPlaying: otherPlaying)
            try session.setCategory(.playback, mode: .default, options: opts)
            try session.setActive(true)
            if otherPlaying && opts == Self.mixingAudioSessionOptions {
                AppLogger.info("启动时检测到其他音频，以共存模式接入")
            }
        } catch {
            AppLogger.error("AVAudioSession 配置失败: \(error)")
        }
        
        // 监听音频中断（电话、其他 app 播放等）
        if let old = interruptionObserver {
            NotificationCenter.default.removeObserver(old)
        }
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            // 在进入 @MainActor Task 前提取值，避免 Sendable 数据竞争
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                switch type {
                case .began:
                    AppLogger.info("音频中断开始，暂停播放")
                    // 标记中断进行中，阻止路由变化触发的自动恢复
                    self.isUnderInterruption = true
                    self.routeChangeResumeWorkItem?.cancel()
                    self.routeChangeResumeWorkItem = nil
                    if self.isPlaying {
                        self.wasPlayingBeforeInterruption = true
                        self.streamPlayer.pause()
                        self.isPlaying = false
                        self.refreshPlaybackSurfaceState()
                        self.saveStateImmediately()
                    }
                case .ended:
                    AppLogger.info("音频中断结束")
                    self.isUnderInterruption = false
                    guard self.wasPlayingBeforeInterruption else { break }
                    // 检查系统是否建议恢复（微信录音等场景下系统会明确告知）
                    let shouldResume: Bool
                    if let opts = optionsValue {
                        shouldResume = AVAudioSession.InterruptionOptions(rawValue: opts).contains(.shouldResume)
                    } else {
                        // 没有 options 时默认尝试恢复（电话结束等场景）
                        shouldResume = true
                    }
                    guard shouldResume else {
                        AppLogger.info("系统未建议恢复，等待用户手动操作")
                        break
                    }
                    self.wasPlayingBeforeInterruption = false
                    self.resumeAfterInterruption()
                @unknown default:
                    break
                }
            }
        }


        if let old = foregroundObserver {
            NotificationCenter.default.removeObserver(old)
        }
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                AppLogger.debug("didBecomeActive: wasPlaying=\(self.wasPlayingBeforeInterruption), isPlaying=\(self.isPlaying), hasSong=\(self.currentSong != nil)")
                guard self.wasPlayingBeforeInterruption else { return }
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled, self.wasPlayingBeforeInterruption else { return }
                let otherPlaying = AVAudioSession.sharedInstance().isOtherAudioPlaying
                AppLogger.debug("didBecomeActive 延迟后: otherPlaying=\(otherPlaying)")
                if !otherPlaying {
                    AppLogger.info("App 激活且无其他音频，恢复播放")
                    self.wasPlayingBeforeInterruption = false
                    self.resumeAfterInterruption()
                }
            }
        }

        if let old = routeChangeObserver {
            NotificationCenter.default.removeObserver(old)
        }
        routeChangeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch reason {
                case .newDeviceAvailable:
                    // 蓝牙耳机/外接设备连接：检查采样率兼容性，必要时重建音频引擎
                    AppLogger.info("新音频设备连接，检查采样率兼容性")
                    self.streamPlayer.handleAudioRouteChange()
                case .oldDeviceUnavailable:
                    // 蓝牙耳机/外接设备断开：检查采样率兼容性，必要时重建音频引擎
                    AppLogger.info("音频设备断开，检查采样率兼容性")
                    self.streamPlayer.handleAudioRouteChange()
                case .categoryChange, .override, .routeConfigurationChange:
                    self.scheduleResumeAfterRouteChangeIfNeeded()
                default:
                    break
                }
            }
        }

        if let old = mediaResetObserver {
            NotificationCenter.default.removeObserver(old)
        }
        mediaResetObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { _ in
            AppLogger.warning("媒体服务被重置，重建 audio session")
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: PlayerManager.playbackAudioSessionOptions)
                try session.setActive(true)
            } catch {
                AppLogger.error("重建 audio session 失败: \(error)")
            }
            // 如果正在播放，重新触发当前歌曲播放（让库重新走 AudioRenderer.start 流程）
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let song = self.currentSong, self.isPlaying {
                    let time = self.currentTime
                    AppLogger.info("媒体服务重置后重新播放: \(song.name), 从 \(String(format: "%.1f", time))s 继续")
                    self.loadAndPlay(song: song, startTime: time)
                }
            }
        }
    }
    
    func setupRemoteCommands() {
        commandCenter.playCommand.addTarget { [weak self] _ in
            (self?.playPlayback() ?? false) ? .success : .commandFailed
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            (self?.pausePlayback() ?? false) ? .success : .commandFailed
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
            }
            return .success
        }
    }
    
    /// 设置 StreamPlayer delegate（通过桥接适配器）
    func setupStreamPlayerDelegate() {
        let adapter = StreamPlayerDelegateAdapter(playerManager: self)
        self.delegateAdapter = adapter
        streamPlayer.delegate = adapter
    }
    
    /// 定时器轮询 StreamPlayer 的 currentTime
    func startTimeUpdateTimer() {
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // ── 睡眠定时器始终 tick（不受 isPlaying guard 影响） ──
            self.tickSleepTimer()
            
            // 采样 StreamPlayer 状态（在 Timer RunLoop 中读取，不涉及 @Published）
            let time = self.streamPlayer.currentTime
            let timeValid = time.isFinite && !time.isNaN && time >= 0
            let loadingTimeout = self.isLoading
                && self.playbackStartedAt.map { Date().timeIntervalSince($0) > 60.0 } == true
            let playing = self.isPlaying
            let seeking = self.isSeeking
            let seekTarget = self.seekTargetTime
            let seekStarted = self.seekStartedAt
            
            guard playing || (timeValid && time > 0) || loadingTimeout else { return }
            
            // 将 @Published 修改推迟到下一个 RunLoop 迭代，避免在 SwiftUI 布局中触发
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if loadingTimeout {
                    AppLogger.warning("isLoading 超时（60s），强制解除")
                    self.isLoading = false
                }
                
                // ── isSeeking 状态解除 ──
                if seeking {
                    var resolved = false
                    if let target = seekTarget {
                        if timeValid && time >= target - 1.0 {
                            resolved = true
                        } else if let started = seekStarted,
                                  Date().timeIntervalSince(started) > 3.0 {
                            resolved = true
                        }
                    } else {
                        resolved = true
                    }
                    if resolved {
                        self.isSeeking = false
                        self.seekTargetTime = nil
                        self.seekStartedAt = nil
                        if timeValid { self.currentTime = time }
                    }
                }
                
                // ── 正常时间更新 ──
                if timeValid && !self.isSeeking {
                    self.currentTime = time
                }
                LyricViewModel.shared.updateCurrentTime(self.currentTime)
                self.savePlaybackProgressIfNeeded()

                let lyricIdx = LyricViewModel.shared.currentLineIndex
                let lyricChanged = lyricIdx != self.lastNowPlayingLyricIndex

                self.nowPlayingUpdateCounter += 1
                if lyricChanged || self.nowPlayingUpdateCounter >= 8 {
                    self.nowPlayingUpdateCounter = 0
                    self.updateNowPlayingTime()
                    #if canImport(ActivityKit) && os(iOS)
                    Task { @MainActor in
                        await LyricsLiveActivityManager.shared.sync(with: self)
                    }
                    #endif
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        timeUpdateTimer = timer
    }

    /// 其他 App 释放音频路由后，`isOtherAudioPlaying` 可能稍后变为 false，在此再尝试恢复。
    func scheduleResumeAfterRouteChangeIfNeeded() {
        // 中断进行中（如微信录音）时，路由变化不触发自动恢复
        guard !isUnderInterruption else {
            AppLogger.debug("中断进行中，忽略路由变化触发的恢复")
            return
        }
        guard wasPlayingBeforeInterruption, currentSong != nil, !isPlaying else { return }
        routeChangeResumeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.wasPlayingBeforeInterruption, !self.isPlaying, self.currentSong != nil else { return }
            guard !AVAudioSession.sharedInstance().isOtherAudioPlaying else { return }
            AppLogger.info("路由变化后检测到可恢复，继续播放")
            self.wasPlayingBeforeInterruption = false
            self.resumeAfterInterruption()
        }
        routeChangeResumeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }
    
    /// 中断恢复：先尝试 resume，如果播放器状态异常则从当前位置重新加载
    func resumeAfterInterruption() {
        AppLogger.info("恢复播放 (state=\(streamPlayer.state))")
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: audioSessionOptions(otherAudioPlaying: session.isOtherAudioPlaying))
            try session.setActive(true)
        } catch {
            AppLogger.error("重新激活音频会话失败: \(error)")
        }

        if streamPlayer.state == .paused {
            streamPlayer.resume()
            isPlaying = true
            refreshPlaybackSurfaceState()
        } else if let song = currentSong {
            let time = currentTime
            AppLogger.info("播放器状态非 paused，从 \(String(format: "%.1f", time))s 重新加载")
            loadAndPlay(song: song, startTime: time)
        }
    }
}
