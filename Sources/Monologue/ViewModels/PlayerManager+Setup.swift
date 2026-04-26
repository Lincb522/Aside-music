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
        var base: AVAudioSession.CategoryOptions
        switch SettingsManager.shared.backgroundAudioPolicy {
        case .exclusive:
            base = Self.playbackAudioSessionOptions
        case .automatic:
            let shouldMix = otherAudioPlaying ?? AVAudioSession.sharedInstance().isOtherAudioPlaying
            base = shouldMix ? Self.mixingAudioSessionOptions : Self.playbackAudioSessionOptions
        case .alwaysMix:
            base = Self.mixingAudioSessionOptions
        }
        // 游戏模式 + 用户开启「游戏语音 / 系统语音优先」时，叠加
        // `.interruptSpokenAudioAndMixWithOthers` —— Siri/VoIP/语音通话开始时自动压低音乐。
        // 该 option 要求 `.playback` category，与 `.mixWithOthers` 可共存。
        //
        // ⚠️ 不直接访问 `GameModeManager.shared.isActive`：
        // 本方法会在 `PlayerManager.init → setupAudioSession` 流程中同步调用；
        // 若此时触发 `GameModeManager` 单例首次初始化，`GameModeManager.init`
        // 又会反向访问 `PlayerManager.shared`（applyEnter 内的 handleBackgroundAudio...）,
        // 造成冷启动单例循环 → EXC_BREAKPOINT。
        // 改成从 App Group UserDefaults 直读，零单例依赖。
        let gameModeActive = UserDefaults(suiteName: "group.zijiu.Monologue.com")?
            .bool(forKey: "monologue_game_mode_enabled") ?? false
        if gameModeActive && SettingsManager.shared.gameModeAutoDucking {
            base.insert(.interruptSpokenAudioAndMixWithOthers)
        }
        return base
    }

    func handleBackgroundAudioPolicySettingChanged() {
        reapplyAudioSessionOptions(reason: "策略变更")
    }

    /// 供 GameModeManager 调用，当游戏模式/自动 ducking 开关变化时重新应用 options
    func handleGameModeDuckingChanged() {
        reapplyAudioSessionOptions(reason: "游戏模式 ducking 变更")
    }

    /// 根据当前策略和 `isOtherAudioPlaying` 状态，按需切换 session options。
    /// 被以下时机调用：策略变更、其他 App 音频开始/结束、次要音频降音提示、中断恢复。
    /// 仅在 options 真的发生变化时重写 session，避免无意义的 setActive。
    ///
    /// ⚠️ 懒激活策略：
    ///   - **有当前歌曲**（`currentSong != nil`）才调用 `setActive(true)`
    ///     激活 session；
    ///   - **无当前歌曲**（用户只是切了设置但没播放）只更新 category，
    ///     避免空闲状态下主动抢占音频路由。
    ///   - 中断恢复/路由重置等必须激活的场景，调用方会先把
    ///     `lastAppliedAudioSessionOptions` 置 nil 并确保此时 `currentSong`
    ///     非空；若为空也不需要激活，自然无害。
    func reapplyAudioSessionOptions(reason: String) {
        let session = AVAudioSession.sharedInstance()
        let desired = audioSessionOptions(otherAudioPlaying: session.isOtherAudioPlaying)
        guard desired != lastAppliedAudioSessionOptions else { return }

        do {
            try session.setCategory(.playback, mode: .default, options: desired)
            if currentSong != nil {
                try session.setActive(true)
                AppLogger.info("音频会话已激活 options=\(desired)  原因: \(reason)")
            } else {
                AppLogger.info("音频会话仅更新 category options=\(desired)（无当前歌曲，延迟激活） 原因: \(reason)")
            }
            lastAppliedAudioSessionOptions = desired
            if currentSong != nil {
                updateNowPlayingInfo()
                updateNowPlayingArtwork(for: currentSong)
            }
        } catch {
            AppLogger.error("应用后台音频策略失败: \(error)")
        }
    }

    /// 开播前强制激活音频会话。
    ///
    /// `loadAndPlay(song:)` 首次调用此方法以：
    ///   1. 在 `.automatic` 策略下，按最新的 `isOtherAudioPlaying` 选择 options；
    ///   2. 把之前 `setupAudioSession` 里只预声明的 category 真正 `setActive(true)`；
    ///   3. 与 StreamPlayer.play 前置，避免抢占音频路由在 play 之后发生。
    ///
    /// 无论 options 是否变化都执行一次 `setActive(true)`，因为即便 options 相同
    /// 也可能是首次从"空闲未激活"切到"真正播放"的那一刻。
    func activateAudioSessionForPlayback(reason: String) {
        let session = AVAudioSession.sharedInstance()
        let desired = audioSessionOptions(otherAudioPlaying: session.isOtherAudioPlaying)

        do {
            if desired != lastAppliedAudioSessionOptions {
                try session.setCategory(.playback, mode: .default, options: desired)
                lastAppliedAudioSessionOptions = desired
            }
            try session.setActive(true)
            AppLogger.info("音频会话已激活（开播前） options=\(desired)  原因: \(reason)")
        } catch {
            AppLogger.error("开播前激活音频会话失败: \(error)")
        }
    }

    // MARK: - Setup

    func setupAudioSession() {
        // ⚠️ 懒激活：冷启动只**设置 category**，不 `setActive(true)`。
        //
        // 历史问题：App 启动即 `setActive(true)` 会**主动抢占音频路由**。
        // 若用户设 `.exclusive` 但仅仅是打开 App 还没点播放，
        // 也会把其他 App（如 Apple Music）打断，这不符合用户预期。
        //
        // 正确做法：
        //   - 这里只预声明 category，让系统知道我们属于 playback；
        //   - 真正的 `setActive(true)` 推迟到 `loadAndPlay(song:)` 第一次
        //     开播、或 `reapplyAudioSessionOptions` 被策略变更触发时。
        do {
            let session = AVAudioSession.sharedInstance()
            let otherPlaying = session.isOtherAudioPlaying
            let opts = audioSessionOptions(otherAudioPlaying: otherPlaying)
            try session.setCategory(.playback, mode: .default, options: opts)
            lastAppliedAudioSessionOptions = opts
            if otherPlaying && opts == Self.mixingAudioSessionOptions {
                AppLogger.info("启动时检测到其他音频，以共存模式接入（未激活）")
            }
        } catch {
            AppLogger.error("AVAudioSession 配置失败: \(error)")
        }

        // 监听次要音频降音提示：其他主媒体 App 开始/停止播放时触发
        // .automatic 策略下，我们据此动态切换 mixWithOthers options
        if let old = silenceHintObserver {
            NotificationCenter.default.removeObserver(old)
        }
        silenceHintObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
                  let hintType = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: typeValue)
            else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch hintType {
                case .begin:
                    AppLogger.info("其他主媒体 App 开始播放，重新评估 options")
                    self.reapplyAudioSessionOptions(reason: "secondary hint begin")
                case .end:
                    AppLogger.info("其他主媒体 App 停止播放，重新评估 options")
                    self.reapplyAudioSessionOptions(reason: "secondary hint end")
                @unknown default:
                    break
                }
            }
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
        mediaResetObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            AppLogger.warning("媒体服务被重置，重建 audio session")
            Task { @MainActor [weak self] in
                guard let self else { return }
                // 重置缓存，强制重写 options（而非跳过）
                self.lastAppliedAudioSessionOptions = nil
                self.reapplyAudioSessionOptions(reason: "media services reset")
                // 如果正在播放，重新触发当前歌曲播放（让库重新走 AudioRenderer.start 流程）
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
        // 强制重写 options（绕过缓存），中断恢复时确保 session 处于 active
        lastAppliedAudioSessionOptions = nil
        reapplyAudioSessionOptions(reason: "interruption resume")

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
