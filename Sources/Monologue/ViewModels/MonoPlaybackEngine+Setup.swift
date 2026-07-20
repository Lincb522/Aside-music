// MonoPlaybackEngine+Setup.swift
// Monologue
//
// 播放器初始化设置：音频会话、远程控制、StreamPlayer 代理、定时器

import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import FFmpegSwiftSDK

extension PlayerManager {
    
    /// 独占播放模式（默认）：系统将本 App 识别为主媒体播放器，锁屏/灵动岛正常显示。
    /// `.playback` 本身就支持常规蓝牙音频输出，这里不要再叠加 `.allowBluetoothA2DP`，
    /// 否则会触发 NSOSStatusErrorDomain Code=-50（无效参数）。
    nonisolated static let playbackAudioSessionOptions: AVAudioSession.CategoryOptions = []
    /// 共存播放模式：与游戏、短视频等混音，但系统不再将本 App 视为主媒体播放器。
    nonisolated static let mixingAudioSessionOptions: AVAudioSession.CategoryOptions = [.mixWithOthers]
    /// Outputs whose disappearance must not silently fall back to the phone speaker.
    nonisolated static let disconnectSensitiveAudioOutputPortTypes: Set<String> = [
        AVAudioSession.Port.bluetoothA2DP.rawValue,
        AVAudioSession.Port.bluetoothHFP.rawValue,
        AVAudioSession.Port.bluetoothLE.rawValue,
        AVAudioSession.Port.headphones.rawValue,
        AVAudioSession.Port.usbAudio.rawValue,
        AVAudioSession.Port.airPlay.rawValue,
        AVAudioSession.Port.carAudio.rawValue
    ]

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
        // `.interruptSpokenAudioAndMixWithOthers` —— VoIP/语音通话开始时自动压低音乐。
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
        scheduleAutomaticAudioPolicyReevaluation(reason: "策略变更")
    }

    /// `.automatic` 模式从混音态回到主播放器依赖系统更新
    /// `isOtherAudioPlaying`。hint 刚结束时该值偶尔仍未刷新，分阶段复查可避免
    /// 会话永久留在 mixWithOthers，继而让控制中心/灵动岛长期不接管本 App。
    func scheduleAutomaticAudioPolicyReevaluation(reason: String) {
        automaticAudioPolicyReevaluationTask?.cancel()
        automaticAudioPolicyReevaluationTask = nil

        guard SettingsManager.shared.backgroundAudioPolicy == .automatic else {
            repairSystemPlaybackSurfacesIfNeeded(reason: "audio policy \(reason)")
            return
        }

        automaticAudioPolicyReevaluationTask = Task { @MainActor [weak self] in
            defer { self?.automaticAudioPolicyReevaluationTask = nil }
            for delay in [0.6, 1.8, 4.0] {
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    return
                }
                guard let self, self.currentSong != nil else { return }
                self.reapplyAudioSessionOptions(reason: "automatic policy reevaluation: \(reason)")
                self.repairSystemPlaybackSurfacesIfNeeded(reason: "automatic policy reevaluation")
                if self.lastAppliedAudioSessionOptions == Self.playbackAudioSessionOptions {
                    return
                }
            }
        }
    }

    /// 其他 App 还在出声时，是否仍允许自动恢复播放。
    ///
    /// 共存模式（alwaysMix）本来就与其他声音混音，电话/语音中断结束后
    /// 即便游戏、视频还在响也应该直接恢复；独占与智能模式则保持礼貌，
    /// 等对方停止再恢复，避免自动播放抢占别人的音频焦点。
    var canAutoResumeWithOtherAudio: Bool {
        SettingsManager.shared.backgroundAudioPolicy == .alwaysMix
    }

    /// 自动恢复前的统一判定：无其他音频，或当前策略允许共存。
    func isAutoResumePermittedNow() -> Bool {
        !AVAudioSession.sharedInstance().isOtherAudioPlaying || canAutoResumeWithOtherAudio
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
            if desired != lastAppliedAudioSessionOptions
                || session.category != .playback
                || session.mode != .default
                || session.categoryOptions != desired {
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
            lastKnownAudioOutputPortTypes = Set(
                session.currentRoute.outputs.map { $0.portType.rawValue }
            )
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
                    self.automaticAudioPolicyReevaluationTask?.cancel()
                    self.automaticAudioPolicyReevaluationTask = nil
                    AppLogger.info("其他主媒体 App 开始播放，重新评估 options")
                    self.reapplyAudioSessionOptions(reason: "secondary hint begin")
                case .end:
                    AppLogger.info("其他主媒体 App 停止播放，重新评估 options")
                    self.reapplyAudioSessionOptions(reason: "secondary hint end")
                    self.scheduleAutomaticAudioPolicyReevaluation(reason: "secondary hint end")
                    // 其他 App 停止后，等 1s 确认真的停了再尝试恢复
                    if self.wasPlayingBeforeInterruption, self.currentSong != nil, !self.isPlaying {
                        Task { @MainActor [weak self] in
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            guard let self, self.wasPlayingBeforeInterruption, !self.isPlaying else { return }
                            guard self.isAutoResumePermittedNow() else { return }
                            AppLogger.info("secondary hint end: 确认可恢复，恢复播放")
                            let _ = self.resumeAfterInterruption(reason: "secondary hint end")
                        }
                    }
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
            let reasonValue = userInfo[AVAudioSessionInterruptionReasonKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // iOS 17 起，耳机/蓝牙断开可能以「中断 + routeDisconnected」的形式下发，
                // 而不只是 routeChange 通知。这类"中断"永远不会有 .ended，
                // 绝不能进入中断自动恢复状态机——否则 watchdog 60s 后会把音乐
                // 从扬声器外放出来。按「设备断开」标准行为处理：只暂停。
                if #available(iOS 17.0, *),
                   type == .began,
                   let reasonValue,
                   AVAudioSession.InterruptionReason(rawValue: reasonValue) == .routeDisconnected {
                    self.pauseForDisconnectedAudioOutput(reason: "interruption.routeDisconnected")
                    return
                }

                switch type {
                case .began:
                    AppLogger.info("音频中断开始，暂停播放")
                    // The system may deactivate the session without changing our
                    // cached category options. Force the next resume to reactivate it.
                    self.lastAppliedAudioSessionOptions = nil
                    // 标记中断进行中，阻止路由变化触发的自动恢复
                    self.isUnderInterruption = true
                    self.interruptionStartedAt = Date()
                    self.routeChangeResumeWorkItem?.cancel()
                    self.routeChangeResumeWorkItem = nil
                    self.cancelInterruptionResumeRetry()
                    let wasActivePlayback = self.isPlaying || self.streamPlayer.state == .playing
                    if wasActivePlayback, self.currentSong != nil {
                        // 接管进行中的软暂停淡出，避免其收尾回调与中断路径竞争
                        self.cancelPlaybackFade(restoreVolume: false)
                        self.wasPlayingBeforeInterruption = true
                        self.streamPlayer.pause()
                        self.streamPlayer.outputVolume = 1.0
                        self.isPlaying = false
                        self.isLoading = false
                        self.lastPausedAt = Date()
                        self.refreshPlaybackSurfaceState()
                        self.saveStateImmediately()
                    }
                    // 启动 watchdog：60s 后若仍在中断态，强制清除并尝试一次恢复
                    self.armInterruptionWatchdog()
                case .ended:
                    AppLogger.info("音频中断结束")
                    self.isUnderInterruption = false
                    self.cancelInterruptionWatchdog()
                    guard self.wasPlayingBeforeInterruption else { break }
                    // 检查系统是否建议恢复
                    let shouldResume: Bool
                    if let opts = optionsValue {
                        shouldResume = AVAudioSession.InterruptionOptions(rawValue: opts).contains(.shouldResume)
                    } else {
                        // 没有 options 时默认尝试恢复（电话结束等场景）
                        shouldResume = true
                    }
                    if shouldResume {
                        // 系统明确建议恢复 — 直接恢复，不走重试链
                        // 延迟 0.3s 让系统音频路由稳定
                        Task { @MainActor [weak self] in
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            guard let self, self.wasPlayingBeforeInterruption, !self.isPlaying else { return }
                            if !self.resumeAfterInterruption(reason: "interruption ended (shouldResume)") {
                                // 极少数情况下 setActive 失败，启动兜底重试
                                self.scheduleInterruptionResumeRetry(reason: "interruption ended fallback")
                            }
                        }
                    } else {
                        // 系统未建议恢复 — 启动保守重试（1.5s → 3s → 6s）
                        AppLogger.info("系统未建议立即恢复，启动保守重试")
                        self.scheduleInterruptionResumeRetry(reason: "interruption ended (no shouldResume)")
                    }
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
                self.reconcilePendingTrackTransitionWithEngine(reason: "didBecomeActive")
                self.repairSystemPlaybackSurfacesIfNeeded(reason: "didBecomeActive")
                self.scheduleAutomaticAudioPolicyReevaluation(reason: "didBecomeActive")
                if self.isPlaying || self.streamPlayer.state == .playing {
                    self.scheduleAudioOutputRecoveryIfNeeded(reason: "didBecomeActive")
                }
                guard self.wasPlayingBeforeInterruption, !self.isPlaying, self.currentSong != nil else { return }
                // App 回前台 — 等 0.5s 让系统状态稳定，然后检查是否可以恢复
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled, self.wasPlayingBeforeInterruption, !self.isPlaying else { return }
                // 独占/智能模式只在没有其他音频时恢复；共存模式允许直接混音恢复
                guard self.isAutoResumePermittedNow() else {
                    AppLogger.debug("didBecomeActive: 其他音频仍在播放，不自动恢复")
                    return
                }
                AppLogger.info("App 激活且满足恢复条件，恢复播放")
                let _ = self.resumeAfterInterruption(reason: "didBecomeActive")
            }
        }

        if let old = routeChangeObserver {
            NotificationCenter.default.removeObserver(old)
        }
        routeChangeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
            let reportedPreviousOutputPortTypes = Set(
                (userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription)?
                    .outputs
                    .map { $0.portType.rawValue } ?? []
            )
            Task { @MainActor [weak self] in
                guard let self else { return }
                let currentOutputPortTypes = Set(
                    AVAudioSession.sharedInstance().currentRoute.outputs.map { $0.portType.rawValue }
                )
                let previousOutputPortTypes = reportedPreviousOutputPortTypes.isEmpty
                    ? self.lastKnownAudioOutputPortTypes
                    : reportedPreviousOutputPortTypes
                self.lastKnownAudioOutputPortTypes = currentOutputPortTypes
                EQManager.shared.handleAudioRouteChanged()

                let previousHadExternalOutput = !previousOutputPortTypes
                    .isDisjoint(with: Self.disconnectSensitiveAudioOutputPortTypes)
                let currentHasExternalOutput = !currentOutputPortTypes
                    .isDisjoint(with: Self.disconnectSensitiveAudioOutputPortTypes)
                let didLoseExternalOutput = previousHadExternalOutput && !currentHasExternalOutput

                // iOS 17 can report Bluetooth removal as routeConfigurationChange.
                // Route topology is the source of truth; never rebuild onto speaker.
                if reason == .oldDeviceUnavailable || didLoseExternalOutput {
                    self.pauseForDisconnectedAudioOutput(
                        reason: "\(reason), previous=\(previousOutputPortTypes), current=\(currentOutputPortTypes)"
                    )
                    return
                }

                switch reason {
                case .newDeviceAvailable:
                    AppLogger.info("新音频设备连接，重新确认音频会话与输出引擎")
                    let expectedToPlay = self.isPlaying || self.streamPlayer.state == .playing
                    self.lastAppliedAudioSessionOptions = nil
                    if expectedToPlay {
                        _ = self.activateAudioSessionForPlaybackChecked(reason: "new audio device")
                    }
                    _ = self.streamPlayer.handleAudioRouteChange()
                    if expectedToPlay {
                        self.scheduleAudioOutputRecoveryIfNeeded(reason: "new audio device")
                    }
                case .oldDeviceUnavailable:
                    break // handled by route topology check above
                case .categoryChange:
                    let expectedToPlay = self.isPlaying || self.streamPlayer.state == .playing
                    if expectedToPlay {
                        _ = self.activateAudioSessionForPlaybackChecked(reason: "audio category change")
                    }
                    _ = self.streamPlayer.handleAudioRouteChange()
                    if expectedToPlay {
                        self.scheduleAudioOutputRecoveryIfNeeded(reason: "audio category change")
                    }
                    self.scheduleResumeAfterRouteChangeIfNeeded()
                case .override, .routeConfigurationChange:
                    let expectedToPlay = self.isPlaying || self.streamPlayer.state == .playing
                    self.lastAppliedAudioSessionOptions = nil
                    if expectedToPlay {
                        _ = self.activateAudioSessionForPlaybackChecked(reason: "audio route configuration change")
                    }
                    _ = self.streamPlayer.handleAudioRouteChange()
                    if expectedToPlay {
                        self.scheduleAudioOutputRecoveryIfNeeded(reason: "audio route configuration change")
                    }
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
                // 清理可能正在跑的重试任务，避免和重建竞态
                self.cancelInterruptionResumeRetry()
                self.cancelInterruptionWatchdog()
                self.reapplyAudioSessionOptions(reason: "media services reset")
                self.setupRemoteCommands()
                self.repairSystemPlaybackSurfacesIfNeeded(reason: "media services reset")
                // 如果正在播放，重新触发当前歌曲播放（让库重新走 AudioRenderer.start 流程）
                if let song = self.currentSong, self.isPlaying {
                    let time = self.currentTime
                    AppLogger.info("媒体服务重置后重新播放: \(song.name), 从 \(String(format: "%.1f", time))s 继续")
                    self.loadAndPlay(
                        song: song,
                        startTime: time,
                        fadeInDuration: 0.8,
                        fadeInReason: "media services reset"
                    )
                }
            }
        }
    }

    /// External-route removal is a safety pause, not an interruption recovery.
    /// Stop immediately so no tail can escape through the built-in speaker.
    func pauseForDisconnectedAudioOutput(reason: String) {
        AppLogger.info("外接音频输出已断开，立即暂停: \(reason)")
        rollbackPendingPlaybackQueueMutationIfNeeded()
        invalidateInFlightPlaybackWork(reason: "audio output disconnected: \(reason)")
        audioOutputRecoveryTask?.cancel()
        audioOutputRecoveryTask = nil
        routeChangeResumeWorkItem?.cancel()
        routeChangeResumeWorkItem = nil
        cancelInterruptionResumeRetry()
        cancelInterruptionWatchdog()
        cancelPlaybackFade(restoreVolume: false)
        clearPlaybackStartFade(restoreVolume: true)
        endTransitionKeepAlive()

        wasPlayingBeforeInterruption = false
        isUnderInterruption = false
        lastAppliedAudioSessionOptions = nil

        if streamPlayer.state == .connecting {
            // A connecting pipeline would otherwise enter `.playing` on speaker
            // after this callback. Keep the song selected and reload on explicit play.
            suppressStopHandlingUntil = Date().addingTimeInterval(1)
            streamPlayer.stop()
        } else {
            _ = streamPlayer.pauseAudioOutputImmediately()
        }
        streamPlayer.outputVolume = 1.0
        isPlaying = false
        isLoading = false
        lastPausedAt = Date()
        refreshPlaybackSurfaceState()
        saveStateImmediately()

        if currentSong != nil {
            updateNowPlayingInfo()
            updateNowPlayingArtwork(for: currentSong)
        }
    }
    
    func setupRemoteCommands() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        // Media services can reset independently of the app process. Re-register
        // idempotently so a reset does not leave stale or duplicated handlers.
        let managedCommands: [MPRemoteCommand] = [
            commandCenter.playCommand,
            commandCenter.pauseCommand,
            commandCenter.togglePlayPauseCommand,
            commandCenter.nextTrackCommand,
            commandCenter.previousTrackCommand,
            commandCenter.skipForwardCommand,
            commandCenter.skipBackwardCommand,
            commandCenter.changePlaybackRateCommand,
            commandCenter.changePlaybackPositionCommand,
            commandCenter.changeRepeatModeCommand,
            commandCenter.changeShuffleModeCommand,
        ]
        managedCommands.forEach { $0.removeTarget(nil) }
        lastRemoteCommandProfileIsPodcast = nil

        commandCenter.playCommand.addTarget { [weak self] _ in
            (self?.playPlayback() ?? false) ? .success : .commandFailed
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            (self?.pausePlayback() ?? false) ? .success : .commandFailed
        }
        // 有线/蓝牙耳机的单击「播放暂停切换」走的是 toggle 命令，
        // 不注册的话部分耳机按键会没有反应。
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            let handled = self.isPlaying ? self.pausePlayback() : self.playPlayback()
            return handled ? .success : .commandFailed
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        // 播客场景的锁屏 ±15s 快进快退（由 updateRemoteCommandProfile 按内容类型启停）
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let self else { return .commandFailed }
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            self.seekForward(seconds: interval)
            return .success
        }
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let self else { return .commandFailed }
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            self.seekBackward(seconds: interval)
            return .success
        }
        // 播客倍速（CarPlay / 锁屏长按等入口）
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates =
            [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0].map { NSNumber(value: $0) }
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let self, let event = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            self.setPlaybackSpeed(event.playbackRate)
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
            }
            return .success
        }
        // 锁屏 / CarPlay 的循环与随机模式切换
        commandCenter.changeRepeatModeCommand.isEnabled = true
        commandCenter.changeRepeatModeCommand.addTarget { [weak self] event in
            guard let self, let event = event as? MPChangeRepeatModeCommandEvent else { return .commandFailed }
            switch event.repeatType {
            case .one:
                self.applyRemotePlayMode(.loopSingle)
            case .all, .off:
                self.applyRemotePlayMode(self.mode == .shuffle ? .shuffle : .sequence)
            @unknown default:
                return .commandFailed
            }
            return .success
        }
        commandCenter.changeShuffleModeCommand.isEnabled = true
        commandCenter.changeShuffleModeCommand.addTarget { [weak self] event in
            guard let self, let event = event as? MPChangeShuffleModeCommandEvent else { return .commandFailed }
            switch event.shuffleType {
            case .off:
                self.applyRemotePlayMode(.sequence)
            case .items, .collections:
                self.applyRemotePlayMode(.shuffle)
            @unknown default:
                return .commandFailed
            }
            return .success
        }

        // 冷启动先按音乐布局收敛一次（系统默认所有命令都是 enabled，
        // 不收敛的话锁屏可能同时挂着切歌和 ±15s 两套按钮）
        updateRemoteCommandProfile()
    }

    /// 按内容类型切换锁屏/控制中心的命令布局：
    ///   - 音乐 / FM：上一首、下一首 + 循环/随机切换；
    ///   - 播客：±15s 快进快退 + 倍速（系统在禁用上/下一首时才会把
    ///     锁屏两侧按钮渲染成跳转间隔样式）。
    /// 由 updateNowPlayingInfo 在每次曲目/来源变化时调用，幂等且去重。
    func updateRemoteCommandProfile() {
        let podcast = isPlayingPodcast
        guard lastRemoteCommandProfileIsPodcast != podcast else { return }
        lastRemoteCommandProfileIsPodcast = podcast

        commandCenter.skipForwardCommand.isEnabled = podcast
        commandCenter.skipBackwardCommand.isEnabled = podcast
        commandCenter.changePlaybackRateCommand.isEnabled = podcast
        commandCenter.nextTrackCommand.isEnabled = !podcast
        commandCenter.previousTrackCommand.isEnabled = !podcast
        commandCenter.changeRepeatModeCommand.isEnabled = !podcast
        commandCenter.changeShuffleModeCommand.isEnabled = !podcast
    }

    /// 远程命令（锁屏 / CarPlay）触发的播放模式切换
    private func applyRemotePlayMode(_ newMode: PlayMode) {
        guard newMode != mode else { return }
        mode = newMode
        if mode == .shuffle {
            generateShuffledContext()
        } else if let current = currentSong {
            contextIndex = context.firstIndex(where: { $0.id == current.id }) ?? 0
        }
        saveState()
        syncWidgetState()
    }

    // MARK: - 后台生命周期（节流 + 保活）

    /// 监听前后台切换：
    ///   - 进入后台：标记状态并立刻刷新一次锁屏时间锚点（锁屏进度靠 rate 自走）；
    ///   - 回到前台：清除节流状态并立刻补一次完整 UI 同步。
    func setupBackgroundStateObservers() {
        for observer in backgroundStateObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        backgroundStateObservers.removeAll()

        let didEnterBackground = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isAppInBackground = true
                self.backgroundTickSkipCounter = 0
                // 进入后台前把最新时间写入锁屏，之后由系统按 rate 自行推进
                if self.currentSong != nil {
                    self.updateNowPlayingTime()
                    self.syncWidgetState()
                    // 立即落盘一次进度快照：后台被系统回收时，
                    // 下次冷启动仍能从最后一秒精确续播
                    self.savePlaybackProgressIfNeeded(force: true)
                }
            }
        }
        backgroundStateObservers.append(didEnterBackground)

        let willEnterForeground = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isAppInBackground = false
                self.backgroundTickSkipCounter = 0
                self.endTransitionKeepAlive()
                self.reconcilePendingTrackTransitionWithEngine(reason: "willEnterForeground")
                // 回前台立即同步一次，避免 UI 显示后台期间的旧进度
                if self.currentSong != nil {
                    if let time = self.boundedEnginePlaybackTime(
                        self.streamPlayer.currentTime
                    ), !self.isSeeking {
                        self.currentTime = time
                    }
                    LyricViewModel.shared.updateCurrentTime(self.currentTime)
                    self.repairSystemPlaybackSurfacesIfNeeded(reason: "willEnterForeground")
                    self.updateNowPlayingTime()
                    self.scheduleAutomaticAudioPolicyReevaluation(reason: "willEnterForeground")
                }
            }
        }
        backgroundStateObservers.append(willEnterForeground)
    }

    // MARK: - 后台切歌保活

    /// 歌曲在后台自然结束、需要网络请求下一首 URL 时，音频输出短暂停止，
    /// 系统可能在请求完成前挂起 App，导致「后台放完一首就停」。
    /// 这里申请一个短时后台任务（约 30s 窗口）保住切歌流程。
    func beginTransitionKeepAlive(reason: String) {
        guard isAppInBackground else { return }
        guard transitionKeepAliveTaskId == .invalid else { return }
        transitionKeepAliveTaskId = UIApplication.shared.beginBackgroundTask(withName: "Monologue.TrackTransition") { [weak self] in
            Task { @MainActor [weak self] in
                self?.endTransitionKeepAlive()
            }
        }
        if transitionKeepAliveTaskId != .invalid {
            AppLogger.debug("后台切歌保活开始: \(reason)")
        }
    }

    /// 播放真正恢复 / 出错 / 回前台时释放保活任务。
    func endTransitionKeepAlive() {
        guard transitionKeepAliveTaskId != .invalid else { return }
        UIApplication.shared.endBackgroundTask(transitionKeepAliveTaskId)
        transitionKeepAliveTaskId = .invalid
        AppLogger.debug("后台切歌保活结束")
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
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // ── 睡眠定时器始终 tick（不受 isPlaying guard 影响） ──
                self.tickSleepTimer()

                // ── 后台节流：界面不可见时降到 1Hz 采样 ──
                // 锁屏进度由系统按 rate 自动推进、歌词行级同步 1s 粒度足够，
                // 大幅减少后台 CPU 唤醒次数，降低整机功耗。
                if self.isAppInBackground {
                    self.backgroundTickSkipCounter += 1
                    if self.backgroundTickSkipCounter % 4 != 0 { return }
                } else {
                    self.backgroundTickSkipCounter = 0
                }

                // Mono 的音频管线可能已在后台完成无缝热切，但主线程元数据
                // 回调被系统延迟。每次有效 tick 都对账一次，避免回到 App
                // 仍显示上一首；引擎会在旧歌尾音尚未播完时阻止提前切 UI。
                self.reconcilePendingTrackTransitionWithEngine(
                    reason: self.isAppInBackground ? "background tick" : "foreground tick"
                )

                // Route notifications are not guaranteed to describe every engine
                // invalidation. Detect the stale `.playing` + dead output combination
                // from the regular player heartbeat as a final safety net.
                if self.isPlaying,
                   self.streamPlayer.state == .playing,
                   !self.streamPlayer.isAudioOutputRunning {
                    self.scheduleAudioOutputRecoveryIfNeeded(reason: "playback heartbeat")
                }

                if self.currentSong != nil {
                    self.repairSystemPlaybackSurfacesIfNeeded(
                        reason: self.isAppInBackground
                            ? "background playback heartbeat"
                            : "foreground playback heartbeat"
                    )
                }

                // 采样 StreamPlayer 状态
                let rawTime = self.streamPlayer.currentTime
                let boundedTime = self.boundedEnginePlaybackTime(rawTime)
                let time = boundedTime ?? rawTime
                let timeValid = boundedTime != nil
                let loadingTimeout = self.isLoading
                    && self.playbackStartedAt.map { Date().timeIntervalSince($0) > 60.0 } == true
                let playing = self.isPlaying
                let seeking = self.isSeeking
                let seekTarget = self.seekTargetTime
                let seekStarted = self.seekStartedAt

                guard playing || (timeValid && time > 0) || loadingTimeout else { return }
                
                if loadingTimeout {
                    AppLogger.warning("isLoading 超时（60s），强制解除")
                    self.isLoading = false
                }
                
                // ── isSeeking 状态解除 ──
                if seeking {
                    var resolved = false
                    if let target = seekTarget {
                        // 必须确认播放内核已经到达目标附近。旧逻辑只判断
                        // `time >= target - 1`，向后拖动时旧时间天然大于目标，
                        // 会立刻结束 seeking 并把进度覆盖回拖动前的位置。
                        if timeValid && abs(time - target) <= 1.0 {
                            resolved = true
                        } else if let started = seekStarted,
                                  Date().timeIntervalSince(started) > 1.5 {
                            if self.seekRetryCount < self.maxSeekRetryCount {
                                self.seekRetryCount += 1
                                self.seekStartedAt = Date()
                                self.streamPlayer.seek(to: target)
                                AppLogger.warning(
                                    "Seek 尚未到达目标，重新提交第\(self.seekRetryCount)次 target=\(String(format: "%.2f", target)) current=\(String(format: "%.2f", time))",
                                    step: "playback.seek.retry"
                                )
                            } else if let song = self.currentSong {
                                // 最后兜底重建当前歌曲到目标位置。不能把旧内核
                                // 时间写回 UI，否则向后拖动会直接弹回原位置。
                                AppLogger.warning(
                                    "Seek 多次未生效，重建当前管线 target=\(String(format: "%.2f", target))",
                                    step: "playback.seek.pipeline-rebuild"
                                )
                                self.isSeeking = false
                                self.seekTargetTime = nil
                                self.seekStartedAt = nil
                                self.seekRetryCount = 0
                                self.loadAndPlay(
                                    song: song,
                                    startTime: target,
                                    fadeInDuration: 0.45,
                                    fadeInReason: "seek recovery"
                                )
                                return
                            }
                        }
                    } else {
                        resolved = true
                    }
                    if resolved {
                        self.isSeeking = false
                        self.seekTargetTime = nil
                        self.seekStartedAt = nil
                        self.seekRetryCount = 0
                        if timeValid { self.currentTime = time }
                    }
                }
                
                // ── 正常时间更新 ──
                if timeValid && !self.isSeeking {
                    self.currentTime = time
                }
                LyricViewModel.shared.updateCurrentTime(self.currentTime)
                self.savePlaybackProgressIfNeeded()

                // ── 无缝引擎阶段 B：临近结尾装配下一首管线（后台随节流降为 1Hz） ──
                self.tickGaplessEngine()

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
        guard !isUnderInterruption else {
            AppLogger.debug("中断进行中，忽略路由变化触发的恢复")
            return
        }
        guard wasPlayingBeforeInterruption, currentSong != nil, !isPlaying else { return }
        // 延迟 1s 检查，避免路由切换瞬间的误判
        routeChangeResumeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.wasPlayingBeforeInterruption, !self.isPlaying, self.currentSong != nil else { return }
            guard self.isAutoResumePermittedNow() else {
                AppLogger.debug("路由变化后仍有其他音频，不恢复")
                return
            }
            AppLogger.info("路由变化后确认可恢复，恢复播放")
            let _ = self.resumeAfterInterruption(reason: "route change")
        }
        routeChangeResumeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    /// Debounces route churn, then compares the public playback state with the
    /// actual AVAudioEngine output. A stale `.playing` value must never be allowed
    /// to strand the UI or make the play button a no-op.
    func scheduleAudioOutputRecoveryIfNeeded(reason: String) {
        guard currentSong != nil else { return }
        guard isPlaying || streamPlayer.state == .playing else { return }
        guard audioOutputRecoveryTask == nil else { return }

        let expectedSessionId = playbackSessionId
        audioOutputRecoveryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self else { return }
            self.audioOutputRecoveryTask = nil
            guard self.playbackSessionId == expectedSessionId,
                  self.currentSong != nil,
                  self.isPlaying || self.streamPlayer.state == .playing else { return }
            guard !self.streamPlayer.isAudioOutputRunning else {
                if MPNowPlayingInfoCenter.default().nowPlayingInfo == nil {
                    self.updateNowPlayingInfo()
                    self.updateNowPlayingArtwork(for: self.currentSong)
                }
                return
            }
            _ = self.recoverUnavailableAudioOutput(reason: reason)
        }
    }

    /// Rebuilds an invalidated output in place when possible. If iOS refuses the
    /// existing renderer, fall back to a fresh pipeline at the audible position.
    @discardableResult
    func recoverUnavailableAudioOutput(reason: String) -> Bool {
        guard let song = currentSong else { return false }
        if streamPlayer.isAudioOutputRunning {
            updateNowPlayingInfo()
            updateNowPlayingArtwork(for: song)
            return true
        }

        AppLogger.warning("检测到假播放状态，重建音频输出 reason=\(reason)")
        cancelPlaybackFade(restoreVolume: false)
        lastAppliedAudioSessionOptions = nil
        guard activateAudioSessionForPlaybackChecked(reason: "recover dead output: \(reason)") else {
            isPlaying = false
            isLoading = false
            wasPlayingBeforeInterruption = true
            refreshPlaybackSurfaceState()
            scheduleInterruptionResumeRetry(reason: "recover dead output: \(reason)")
            return false
        }

        if streamPlayer.state == .playing {
            streamPlayer.pause()
        }
        if streamPlayer.state == .paused, let song = currentSong {
            streamPlayer.outputVolume = 0.0
            if streamPlayer.resume(), streamPlayer.isAudioOutputRunning {
                isPlaying = true
                isLoading = false
                lastPausedAt = nil
                wasPlayingBeforeInterruption = false
                refreshPlaybackSurfaceState()
                updateNowPlayingInfo()
                updateNowPlayingArtwork(for: song)
                saveState()
                beginPlaybackFade(to: 1.0, duration: 0.7)
                return true
            }
        }

        let resumeTime = max(currentTime, 0)
        AppLogger.warning("原音频输出无法复活，从 \(String(format: "%.1f", resumeTime))s 重建播放管线")
        isPlaying = false
        isLoading = true
        refreshPlaybackSurfaceState()
        loadAndPlay(
            song: song,
            startTime: resumeTime,
            fadeInDuration: 0.8,
            fadeInReason: "audio output rebuild"
        )
        return true
    }
    
    /// 中断恢复：先尝试 resume，如果播放器状态异常则从当前位置重新加载
    ///
    /// ⚠️ 调用约定：
    /// - 优先使用 `attemptInterruptionResume(reason:)`：内部已包含失败重试和状态保护。
    /// - 直接调本方法的场景仅限「确定 session 可激活、要立刻恢复」时（如用户主动点播放）。
    /// - **失败时不会清空 `wasPlayingBeforeInterruption`**，方便上层重试。
    @discardableResult
    func resumeAfterInterruption(reason: String = "interruption resume") -> Bool {
        guard let song = currentSong else { return false }
        AppLogger.info("恢复播放 (state=\(streamPlayer.state), reason=\(reason))")

        // 强制重写 options（绕过缓存），中断恢复时确保 session 处于 active。
        // 这里使用 activateAudioSessionForPlayback，而不是只依赖 reapply，
        // 避免 options 未变化但 session 已被系统打断的场景。
        lastAppliedAudioSessionOptions = nil
        let activated = activateAudioSessionForPlaybackChecked(reason: reason)
        guard activated else {
            AppLogger.warning("中断恢复时音频会话激活失败 reason=\(reason)，保留中断标志等待重试")
            return false
        }

        // 激活成功才清状态，让重试链不会被打断
        routeChangeResumeWorkItem?.cancel()
        routeChangeResumeWorkItem = nil
        cancelInterruptionResumeRetry()
        cancelInterruptionWatchdog()
        isUnderInterruption = false
        wasPlayingBeforeInterruption = false

        // 中断持续过久（长电话/长语音）后网络流 URL 大概率已过期，
        // 直接 resume 会放完缓冲区就断流。主动重新取址从断点续播。
        if isResumeLikelyStale {
            AppLogger.info("中断恢复时 URL 已老化，重新取址续播: \(song.name)")
            lastPausedAt = nil
            loadAndPlay(
                song: song,
                startTime: max(currentTime, 0),
                fadeInDuration: 0.8,
                fadeInReason: "interruption stale reload"
            )
            return true
        }

        if streamPlayer.state == .paused {
            streamPlayer.outputVolume = 0.0
            guard streamPlayer.resume(), streamPlayer.isAudioOutputRunning else {
                let time = currentTime
                AppLogger.warning("中断后无法复活原输出，从 \(String(format: "%.1f", time))s 重新加载")
                loadAndPlay(
                    song: song,
                    startTime: time,
                    fadeInDuration: 0.8,
                    fadeInReason: "interruption resume fallback"
                )
                return true
            }
            isPlaying = true
            isLoading = false
            lastPausedAt = nil
            refreshPlaybackSurfaceState()
            beginPlaybackFade(to: 1.0, duration: 0.7)
        } else if streamPlayer.state == .playing {
            // 微信语音/电话等中断后，SDK 状态偶尔仍停在 `.playing`，
            // 但底层 AudioEngine 已经不出声。强制走一次 pause→resume
            // 让 AudioRenderer 在重新激活的 session 上启动。
            streamPlayer.pause()
            streamPlayer.outputVolume = 0.0
            guard streamPlayer.resume(), streamPlayer.isAudioOutputRunning else {
                let time = currentTime
                AppLogger.warning("中断后播放状态与输出不一致，从 \(String(format: "%.1f", time))s 重新加载")
                loadAndPlay(
                    song: song,
                    startTime: time,
                    fadeInDuration: 0.8,
                    fadeInReason: "interruption output rebuild"
                )
                return true
            }
            isPlaying = true
            isLoading = false
            lastPausedAt = nil
            refreshPlaybackSurfaceState()
            beginPlaybackFade(to: 1.0, duration: 0.7)
        } else {
            let time = currentTime
            AppLogger.info("播放器状态非 paused，从 \(String(format: "%.1f", time))s 重新加载")
            loadAndPlay(
                song: song,
                startTime: time,
                fadeInDuration: 0.8,
                fadeInReason: "interruption state reload"
            )
        }
        return true
    }

    // MARK: - 中断恢复（阶梯重试 + watchdog）

    /// 阶梯重试时间表（秒）。只在系统不发 .ended 或 setActive 失败时才用。
    /// 正常路径（系统发了 .ended + shouldResume）直接恢复，不走重试。
    nonisolated static let interruptionResumeBackoff: [TimeInterval] = [1.5, 3.0, 6.0]

    /// 立即尝试一次中断恢复；失败则启动阶梯重试。
    /// 推荐外部调用此方法而非直接调 `resumeAfterInterruption`。
    func attemptInterruptionResume(reason: String) {
        guard currentSong != nil else { return }
        guard wasPlayingBeforeInterruption else { return }
        guard !isPlaying else { return }
        if resumeAfterInterruption(reason: reason) {
            return
        }
        scheduleInterruptionResumeRetry(reason: reason)
    }

    /// 启动（或重启）阶梯重试任务。每一档都会尝试一次 `resumeAfterInterruption`，
    /// 任何一档成功即整条链路结束。
    func scheduleInterruptionResumeRetry(reason: String) {
        cancelInterruptionResumeRetry()
        // 中断结束后音频尚未出声，App 可能随时被挂起；
        // 保活到重试链结束（成功恢复后由 .playing 状态回调释放）。
        beginTransitionKeepAlive(reason: "interruption resume retry")
        let schedule = Self.interruptionResumeBackoff
        interruptionResumeTask = Task { @MainActor [weak self] in
            for (index, delay) in schedule.enumerated() {
                let nanos = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                guard !Task.isCancelled else { return }
                guard let self else { return }
                guard self.wasPlayingBeforeInterruption,
                      self.currentSong != nil,
                      !self.isPlaying else {
                    self.endTransitionKeepAlive()
                    return
                }
                // 独占/智能模式下不抢占其他音频；共存模式直接混音恢复
                if !self.isAutoResumePermittedNow() {
                    AppLogger.info("中断恢复重试 [\(index+1)/\(schedule.count)]: 其他音频仍在播放，跳过")
                    continue
                }
                let attempt = index + 1
                let total = schedule.count
                AppLogger.info("中断恢复阶梯重试 [\(attempt)/\(total)] (delay=\(delay)s, reason=\(reason))")
                if self.resumeAfterInterruption(reason: "\(reason) retry#\(attempt)") {
                    return
                }
            }
            if let self, self.wasPlayingBeforeInterruption, !self.isPlaying {
                AppLogger.warning("中断恢复阶梯重试全部失败 reason=\(reason)，等待用户手动恢复")
            }
            self?.endTransitionKeepAlive()
        }
    }

    /// 取消正在进行中的阶梯重试。`pausePlayback` / 用户主动停止 / 恢复成功时调用。
    func cancelInterruptionResumeRetry() {
        interruptionResumeTask?.cancel()
        interruptionResumeTask = nil
    }

    /// 中断 watchdog：60s 后若仍处于中断态，强制清除 `isUnderInterruption` 并启动恢复重试。
    /// 处理「微信、抖音等不发 interruption.ended」的场景。
    func armInterruptionWatchdog() {
        cancelInterruptionWatchdog()
        interruptionWatchdogTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            guard let self, self.isUnderInterruption else { return }
            AppLogger.warning("中断 watchdog 触发：60s 仍未收到 interruption.ended，强制清除并尝试恢复")
            self.isUnderInterruption = false
            if self.wasPlayingBeforeInterruption, self.currentSong != nil, !self.isPlaying {
                self.attemptInterruptionResume(reason: "interruption watchdog")
            }
        }
    }

    func cancelInterruptionWatchdog() {
        interruptionWatchdogTask?.cancel()
        interruptionWatchdogTask = nil
    }

    /// 安全版的 `activateAudioSessionForPlayback`：返回 `Bool` 而非吞掉错误。
    /// 用于中断恢复路径，让上层根据结果决定是否重试。
    @discardableResult
    func activateAudioSessionForPlaybackChecked(reason: String) -> Bool {
        let session = AVAudioSession.sharedInstance()
        let desired = audioSessionOptions(otherAudioPlaying: session.isOtherAudioPlaying)

        do {
            if desired != lastAppliedAudioSessionOptions
                || session.category != .playback
                || session.mode != .default
                || session.categoryOptions != desired {
                try session.setCategory(.playback, mode: .default, options: desired)
                lastAppliedAudioSessionOptions = desired
            }
            try session.setActive(true)
            AppLogger.info("音频会话已激活（开播前） options=\(desired)  原因: \(reason)")
            return true
        } catch {
            AppLogger.error("开播前激活音频会话失败 reason=\(reason): \(error)")
            // 激活失败时清缓存，下次重试一定会重写 category
            lastAppliedAudioSessionOptions = nil
            return false
        }
    }
}
