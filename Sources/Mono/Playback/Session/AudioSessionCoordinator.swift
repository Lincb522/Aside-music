// 音频会话协调器：AVAudioSession 配置/激活、后台音频策略、
// 中断（电话/微信录音）与路由变化（耳机/蓝牙拔插）的暂停与自动恢复、
// 假播放输出修复、中断超时看门狗。
// 由 PlayerManager 强持有；对外状态通过 PlayerManager 上的同名 facade 暴露。

import Foundation
import AVFoundation
import UIKit

/// `AVAudioSession.setActive` is a synchronous and potentially slow system call.
/// Keep every session mutation on one private serial queue so the main actor never
/// blocks and playback/recording category changes cannot overtake each other.
private final class AudioSessionMutationExecutor: @unchecked Sendable {
    static let shared = AudioSessionMutationExecutor()

    private let queue = DispatchQueue(
        label: "com.zijiu.monologue.audio-session",
        qos: .userInitiated
    )

    private init() {}

    func configurePlayback(optionsRawValue: UInt, activate: Bool) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    let options = AVAudioSession.CategoryOptions(rawValue: optionsRawValue)
                    if session.category != .playback
                        || session.mode != .default
                        || session.categoryOptions != options {
                        try session.setCategory(.playback, mode: .default, options: options)
                    }
                    if activate {
                        try session.setActive(true)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func configureRecordingAndActivate() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.record, mode: .default)
                    try session.setActive(true)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deactivate(optionsRawValue: UInt) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let options = AVAudioSession.SetActiveOptions(rawValue: optionsRawValue)
                    try AVAudioSession.sharedInstance().setActive(false, options: options)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

@MainActor
final class AudioSessionCoordinator {

    unowned let player: PlayerManager

    init(player: PlayerManager) {
        self.player = player
    }

    // MARK: - 会话选项常量

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

    /// 阶梯重试时间表（秒）。只在系统不发 .ended 或 setActive 失败时才用。
    /// 正常路径（系统发了 .ended + shouldResume）直接恢复，不走重试。
    nonisolated static let interruptionResumeBackoff: [TimeInterval] = [1.5, 3.0, 6.0]

    // MARK: - 状态

    /// 音频中断进行中（如微信录音）
    var isUnderInterruption: Bool = false
    /// 音频中断前是否正在播放（用于中断恢复）
    var wasPlayingBeforeInterruption: Bool = false
    /// 最近一次实际应用到 AVAudioSession 的 options，避免重复 setActive
    var lastAppliedAudioSessionOptions: AVAudioSession.CategoryOptions?
    /// Last stable output route, used because iOS 17 may report a Bluetooth
    /// removal as `.routeConfigurationChange` instead of `.oldDeviceUnavailable`.
    var lastKnownAudioOutputPortTypes: Set<String> = []
    /// 中断开始时间戳，仅用于日志
    var interruptionStartedAt: Date?

    /// NotificationCenter observer tokens
    private var interruptionObserver: Any?
    private var mediaResetObserver: Any?
    private var foregroundObserver: Any?
    /// 游戏模式只用系统主音频提示调低本 App 渲染音量，不修改会话类别。
    private var gameVoiceHintObserver: Any?
    private var gameVoiceDuckingTask: Task<Void, Never>?
    /// 音频路由变化（其他 App 释放会话等）时用于延迟尝试恢复播放
    private var routeChangeObserver: Any?
    private var routeChangeResumeWorkItem: DispatchWorkItem?
    /// Debounced renderer liveness check after Bluetooth/audio-route changes.
    private var audioOutputRecoveryTask: Task<Void, Never>?
    private var stalledOutputRecoveryTask: Task<Void, Never>?
    private var observedPlaybackSessionID: Int?
    private var lastAudibleDuration: TimeInterval = 0
    private var lastAudibleAdvanceAt = Date()
    private var zeroEnvelopeDetectedAt: Date?
    /// 自己调用 setCategory / setActive 后系统也会回送 categoryChange。
    /// 这段窗口内若输出路由没有变化，不再把回声当成外部路由重建。
    private var selfManagedSessionMutationDeadline: Date = .distantPast
    /// 中断/路由恢复阶梯重试任务（1.5s → 3s → 6s）。
    /// 由 `scheduleInterruptionResumeRetry` 创建，失败时自动按下一档重试。
    private var interruptionResumeTask: Task<Void, Never>?
    /// 中断状态巡检。部分 App 不发送 `.ended`，这里只记录异常状态，
    /// 不允许在缺少系统恢复建议时自行开始播放。
    private var interruptionWatchdogTask: Task<Void, Never>?

    private var isHandlingSelfManagedSessionMutation: Bool {
        Date() < selfManagedSessionMutationDeadline
    }

    private func markSelfManagedSessionMutation() {
        selfManagedSessionMutationDeadline = Date().addingTimeInterval(1.0)
    }

    // MARK: - 会话选项计算

    private func audioSessionOptions(primaryAudioActive: Bool? = nil) -> AVAudioSession.CategoryOptions {
        var base: AVAudioSession.CategoryOptions
        switch SettingsManager.shared.backgroundAudioPolicy {
        case .exclusive:
            base = Self.playbackAudioSessionOptions
        case .automatic:
            // `isOtherAudioPlaying` 也会把环境音和本就允许混音的会话算进去，
            // 对媒体 App 来说范围过宽。Apple 建议判断真正的非混音主音频时
            // 使用 secondaryAudioShouldBeSilencedHint。
            let shouldMix = primaryAudioActive
                ?? AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
            base = shouldMix ? Self.mixingAudioSessionOptions : Self.playbackAudioSessionOptions
        case .alwaysMix:
            base = Self.mixingAudioSessionOptions
        }
        return base
    }

    func handleBackgroundAudioPolicySettingChanged() {
        lastAppliedAudioSessionOptions = nil
        // Apple 明确说明：活动中的 session 改 category/options 会立即引发
        // 路由变化。正在稳定出声时不热切换，避免卡顿、瞬断和 AudioEngine
        // 重建；用户的选择会在下一次播放、恢复或真正需要重建会话时应用。
        if player.isPlaying,
           player.appleMusicPlayback.isActive || player.streamPlayer.isAudioOutputRunning {
            AppLogger.info("后台音频策略已更新，将在下一次播放或恢复时应用")
            return
        }
        reapplyAudioSessionOptions(reason: "策略变更")
    }

    /// 其他 App 还在出声时，是否仍允许自动恢复播放。
    ///
    /// 智能共存与始终共存都允许在其他主音频存在时恢复：
    /// 智能模式会在恢复前重新判断并切换为 mixWithOthers；标准播放则
    /// 保持主播放器语义，不在其他主音频仍活跃时主动抢占。
    var canAutoResumeWithOtherAudio: Bool {
        SettingsManager.shared.backgroundAudioPolicy != .exclusive
    }

    /// 自动恢复前的统一判定：无其他音频，或当前策略允许共存。
    func isAutoResumePermittedNow() -> Bool {
        !AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
            || canAutoResumeWithOtherAudio
    }

    /// 供 GameModeManager 调用：立即应用共存策略，并按当前主音频状态
    /// 更新本 App 的独立音量乘数。
    func handleGameModeDuckingChanged() {
        reapplyAudioSessionOptions(reason: "游戏模式 ducking 变更")
        updateGameModeVoiceDucking(
            primaryAudioActive: AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
        )
    }

    private var isGameModeEnabledWithoutInitializingManager: Bool {
        let appGroupEnabled = UserDefaults(suiteName: "group.zijiu.Monologue.com")?
            .bool(forKey: "mono_game_mode_enabled") ?? false
        return SettingsManager.shared.gameModeEnabled || appGroupEnabled
    }

    /// Apple 的 `interruptSpokenAudioAndMixWithOthers` 会暂停其他 App 的语音，
    /// 与“游戏语音优先”目标相反。这里响应主音频 hint，只调低 Mono 自己
    /// 的渲染乘数，并与暂停/睡眠淡出音量独立叠加。
    private func updateGameModeVoiceDucking(primaryAudioActive: Bool) {
        let shouldDuck = isGameModeEnabledWithoutInitializingManager
            && SettingsManager.shared.gameModeAutoDucking
            && primaryAudioActive
            && !player.appleMusicPlayback.isActive
        let target: Float = shouldDuck ? 0.32 : 1.0
        let start = player.streamPlayer.duckingVolume
        guard abs(start - target) > 0.001 else { return }

        gameVoiceDuckingTask?.cancel()
        gameVoiceDuckingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let steps = 10
            for step in 1...steps {
                do {
                    try await Task.sleep(nanoseconds: 22_000_000)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                let progress = Float(step) / Float(steps)
                self.player.streamPlayer.duckingVolume =
                    start + (target - start) * progress
            }
            self.gameVoiceDuckingTask = nil
        }
    }

    /// 根据当前策略和“其他非混音主音频是否存在”的系统提示，
    /// 按需配置 session options。
    /// 仅在 options 真的发生变化时重写 session，避免无意义的 setActive。
    ///
    /// ⚠️ 懒激活策略：
    ///   - 只有真实播放、加载开播或 MusicKit 正在输出时才激活 session；
    ///   - 仅恢复歌曲信息、预加载或浏览设置时只更新 category，
    ///     避免空闲状态下主动抢占其他 App 的音频。
    func reapplyAudioSessionOptions(reason: String) {
        let session = AVAudioSession.sharedInstance()
        let desired = audioSessionOptions(
            primaryAudioActive: session.secondaryAudioShouldBeSilencedHint
        )
        guard desired != lastAppliedAudioSessionOptions else { return }
        let shouldActivate = player.isPlaying
            || player.streamPlayer.state == .playing
            || player.appleMusicPlayback.isActive
        markSelfManagedSessionMutation()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await AudioSessionMutationExecutor.shared.configurePlayback(
                    optionsRawValue: desired.rawValue,
                    activate: shouldActivate
                )
                self.lastAppliedAudioSessionOptions = desired
                if shouldActivate {
                    AppLogger.info("音频会话已激活 options=\(desired)  原因: \(reason)")
                    self.player.updateNowPlayingInfo()
                    self.player.updateNowPlayingArtwork(for: self.player.currentSong)
                } else {
                    AppLogger.info("音频会话仅更新 category options=\(desired)（无当前歌曲，延迟激活） 原因: \(reason)")
                }
            } catch {
                self.lastAppliedAudioSessionOptions = nil
                AppLogger.error("应用后台音频策略失败: \(error)")
            }
        }
    }

    /// 开播前强制激活音频会话。
    ///
    /// `loadAndPlay(song:)` 首次调用此方法以：
    ///   1. 在 `.automatic` 策略下，按最新的主音频提示选择 options；
    ///   2. 把之前 `setupAudioSession` 里只预声明的 category 真正 `setActive(true)`；
    ///   3. 与 StreamPlayer.play 前置，避免抢占音频路由在 play 之后发生。
    ///
    /// 无论 options 是否变化都执行一次 `setActive(true)`，因为即便 options 相同
    /// 也可能是首次从"空闲未激活"切到"真正播放"的那一刻。
    func activateAudioSessionForPlayback(reason: String) async {
        _ = await activateAudioSessionForPlaybackChecked(reason: reason)
    }

    /// 安全版的 `activateAudioSessionForPlayback`：返回 `Bool` 而非吞掉错误。
    /// 用于中断恢复路径，让上层根据结果决定是否重试。
    @discardableResult
    func activateAudioSessionForPlaybackChecked(reason: String) async -> Bool {
        let session = AVAudioSession.sharedInstance()
        let desired = audioSessionOptions(
            primaryAudioActive: session.secondaryAudioShouldBeSilencedHint
        )

        do {
            markSelfManagedSessionMutation()
            try await AudioSessionMutationExecutor.shared.configurePlayback(
                optionsRawValue: desired.rawValue,
                activate: true
            )
            lastAppliedAudioSessionOptions = desired
            updateGameModeVoiceDucking(
                primaryAudioActive: session.secondaryAudioShouldBeSilencedHint
            )
            AppLogger.info("音频会话已激活（开播前） options=\(desired)  原因: \(reason)")
            return true
        } catch {
            AppLogger.error("开播前激活音频会话失败 reason=\(reason): \(error)")
            // 激活失败时清缓存，下次重试一定会重写 category
            lastAppliedAudioSessionOptions = nil
            return false
        }
    }

    /// Listening recognition temporarily borrows the shared session for input.
    /// It uses the same serial executor as playback so record/playback mutations
    /// cannot race each other.
    func activateAudioSessionForRecording(reason: String) async -> Bool {
        do {
            markSelfManagedSessionMutation()
            try await AudioSessionMutationExecutor.shared.configureRecordingAndActivate()
            lastAppliedAudioSessionOptions = nil
            AppLogger.info("音频会话已切换到录音模式 原因: \(reason)")
            return true
        } catch {
            AppLogger.error("录音音频会话激活失败 reason=\(reason): \(error)")
            return false
        }
    }

    /// Stops owning the system audio route after all playback I/O has stopped.
    /// Deactivation is intentionally fire-and-forget for UI commands, but its
    /// blocking system work stays off the main actor.
    func deactivateAudioSession(reason: String) {
        lastAppliedAudioSessionOptions = nil
        markSelfManagedSessionMutation()
        Task { @MainActor [weak self] in
            do {
                try await AudioSessionMutationExecutor.shared.deactivate(
                    optionsRawValue: AVAudioSession.SetActiveOptions.notifyOthersOnDeactivation.rawValue
                )
                AppLogger.info("音频会话已释放 原因: \(reason)")
                guard let self else { return }
                // A new play command may arrive while deactivation is in flight.
                // Repair that rare ordering rather than leaving the new pipeline
                // attached to an inactive session.
                if self.player.currentSong != nil,
                   self.player.isPlaying || self.player.isLoading {
                    _ = await self.activateAudioSessionForPlaybackChecked(
                        reason: "repair after overlapping deactivation"
                    )
                }
            } catch {
                AppLogger.warning("释放音频会话失败 reason=\(reason): \(error)")
            }
        }
    }

    // MARK: - Setup（冷启动只声明 category + 挂观察者）

    func setupAudioSession() {
        // ⚠️ 懒激活：冷启动只**设置 category**，不 `setActive(true)`。
        //
        // 历史问题：App 启动即 `setActive(true)` 会**主动抢占音频路由**。
        // 若用户设 `.exclusive` 但仅仅是打开 App 还没点播放，
        // 也会把其他 App（如 Apple Music）打断，这不符合用户预期。
        //
        // 正确做法：
        //   - 这里只预声明 category，让系统知道我们属于 playback；
        //   - 真正的 `setActive(true)` 推迟到 `loadAndPlay(song:)` 实际开播
        //     或已在输出时的恢复流程。
        let session = AVAudioSession.sharedInstance()
        let primaryAudioActive = session.secondaryAudioShouldBeSilencedHint
        let opts = audioSessionOptions(primaryAudioActive: primaryAudioActive)
        lastKnownAudioOutputPortTypes = Set(
            session.currentRoute.outputs.map { $0.portType.rawValue }
        )
        markSelfManagedSessionMutation()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await AudioSessionMutationExecutor.shared.configurePlayback(
                    optionsRawValue: opts.rawValue,
                    activate: false
                )
                self.lastAppliedAudioSessionOptions = opts
                if primaryAudioActive && opts == Self.mixingAudioSessionOptions {
                    AppLogger.info("启动时检测到其他主音频，预设为共存模式（未激活）")
                }
            } catch {
                self.lastAppliedAudioSessionOptions = nil
                AppLogger.error("AVAudioSession 配置失败: \(error)")
            }
        }

        setupInterruptionObserver()
        setupForegroundObserver()
        setupGameVoiceHintObserver()
        setupRouteChangeObserver()
        setupMediaResetObserver()
    }

    private func setupGameVoiceHintObserver() {
        if let old = gameVoiceHintObserver {
            NotificationCenter.default.removeObserver(old)
        }
        gameVoiceHintObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let rawValue = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
                  let hint = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: rawValue)
            else { return }

            Task { @MainActor [weak self] in
                self?.updateGameModeVoiceDucking(primaryAudioActive: hint == .begin)
            }
        }
    }

    /// 监听电话、录音或其他媒体 App 引发的音频会话中断。
    private func setupInterruptionObserver() {
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
                guard let self else { return }

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
                    let wasActivePlayback = self.player.isPlaying
                        || self.player.streamPlayer.state == .playing
                        || self.player.appleMusicPlayback.isActive
                    if wasActivePlayback, self.player.currentSong != nil {
                        // 接管进行中的软暂停淡出，避免其收尾回调与中断路径竞争
                        self.player.cancelPlaybackFade(restoreVolume: false)
                        self.wasPlayingBeforeInterruption = true
                        if self.player.appleMusicPlayback.isActive {
                            _ = self.player.appleMusicPlayback.pause()
                        } else {
                            self.player.streamPlayer.pause()
                            self.player.streamPlayer.outputVolume = 1.0
                        }
                        self.player.isPlaying = false
                        self.player.isLoading = false
                        self.player.lastPausedAt = Date()
                        self.player.refreshPlaybackSurfaceState()
                        self.player.saveStateImmediately()
                    }
                    // 启动中断巡检：只记录异常，不在缺少系统 `.ended` 时擅自续播。
                    self.armInterruptionWatchdog()
                case .ended:
                    AppLogger.info("音频中断结束")
                    self.isUnderInterruption = false
                    self.cancelInterruptionWatchdog()
                    guard self.wasPlayingBeforeInterruption else { break }
                    // 媒体播放 App 只能在系统明确给出 shouldResume 时自动恢复。
                    // 缺少 options 与明确不建议恢复含义相同，必须保持暂停，
                    // 等待用户从 App、锁屏或耳机主动按下播放。
                    let shouldResume = optionsValue.map {
                        AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume)
                    } ?? false
                    if shouldResume {
                        // 系统明确建议恢复 — 直接恢复，不走重试链
                        // 延迟 0.3s 让系统音频路由稳定
                        Task { @MainActor [weak self] in
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            guard let self, self.wasPlayingBeforeInterruption, !self.player.isPlaying else { return }
                            if !(await self.resumeAfterInterruption(reason: "interruption ended (shouldResume)")) {
                                // 极少数情况下 setActive 失败，启动兜底重试
                                self.scheduleInterruptionResumeRetry(reason: "interruption ended fallback")
                            }
                        }
                    } else {
                        self.wasPlayingBeforeInterruption = false
                        self.player.refreshPlaybackSurfaceState()
                        self.player.saveStateImmediately()
                        AppLogger.info("系统未建议恢复，保持暂停并等待用户操作")
                    }
                @unknown default:
                    break
                }
            }
        }
    }

    private func setupForegroundObserver() {
        if let old = foregroundObserver {
            NotificationCenter.default.removeObserver(old)
        }
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.player.appleMusicPlayback.isActive,
                   (self.player.isPlaying || self.player.streamPlayer.state == .playing),
                   !self.player.streamPlayer.isAudioOutputRunning {
                    self.scheduleAudioOutputRecoveryIfNeeded(reason: "didBecomeActive")
                }
                guard !self.isUnderInterruption,
                      self.wasPlayingBeforeInterruption,
                      !self.player.isPlaying,
                      self.player.currentSong != nil else { return }
                // App 回前台 — 等 0.5s 让系统状态稳定，然后检查是否可以恢复
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled,
                      !self.isUnderInterruption,
                      self.wasPlayingBeforeInterruption,
                      !self.player.isPlaying else { return }
                // 标准模式不主动抢占；智能/始终共存会按最新状态混音恢复。
                guard self.isAutoResumePermittedNow() else {
                    AppLogger.debug("didBecomeActive: 其他音频仍在播放，不自动恢复")
                    return
                }
                AppLogger.info("App 激活且满足恢复条件，恢复播放")
                let _ = await self.resumeAfterInterruption(reason: "didBecomeActive")
            }
        }
    }

    private func setupRouteChangeObserver() {
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
                let routeTopologyUnchanged = previousOutputPortTypes == currentOutputPortTypes

                if self.isHandlingSelfManagedSessionMutation,
                   routeTopologyUnchanged,
                   (reason == .categoryChange || reason == .routeConfigurationChange) {
                    AppLogger.debug(
                        "忽略本 App 音频会话变更的路由回声 reason=\(reason)"
                    )
                    return
                }

                // iOS 17 can report Bluetooth removal as routeConfigurationChange.
                // Route topology is the source of truth; never rebuild onto speaker.
                if reason == .oldDeviceUnavailable || didLoseExternalOutput {
                    self.pauseForDisconnectedAudioOutput(
                        reason: "\(reason), previous=\(previousOutputPortTypes), current=\(currentOutputPortTypes)"
                    )
                    return
                }

                // MusicKit 自行管理受保护音频的路由切换；这里不能用
                // FFmpeg AudioEngine 的存活状态去重建 Apple Music 输出。
                if self.player.appleMusicPlayback.isActive {
                    return
                }

                switch reason {
                case .newDeviceAvailable:
                    AppLogger.info("新音频设备连接，重新确认音频会话与输出引擎")
                    let expectedToPlay = self.player.isPlaying || self.player.streamPlayer.state == .playing
                    self.lastAppliedAudioSessionOptions = nil
                    if expectedToPlay {
                        _ = await self.activateAudioSessionForPlaybackChecked(reason: "new audio device")
                    }
                    _ = self.player.streamPlayer.handleAudioRouteChange()
                    if expectedToPlay {
                        self.scheduleAudioOutputRecoveryIfNeeded(reason: "new audio device")
                    }
                case .oldDeviceUnavailable:
                    break // handled by route topology check above
                case .categoryChange:
                    let expectedToPlay = self.player.isPlaying || self.player.streamPlayer.state == .playing
                    let outputIsRunning = self.player.streamPlayer.isAudioOutputRunning
                    let session = AVAudioSession.sharedInstance()
                    if expectedToPlay,
                       (!outputIsRunning || session.category != .playback) {
                        _ = await self.activateAudioSessionForPlaybackChecked(reason: "audio category change")
                    }
                    if !outputIsRunning {
                        _ = self.player.streamPlayer.handleAudioRouteChange()
                    }
                    if expectedToPlay && !self.player.streamPlayer.isAudioOutputRunning {
                        self.scheduleAudioOutputRecoveryIfNeeded(reason: "audio category change")
                    }
                    self.scheduleResumeAfterRouteChangeIfNeeded()
                case .override, .routeConfigurationChange:
                    let expectedToPlay = self.player.isPlaying || self.player.streamPlayer.state == .playing
                    if expectedToPlay && !self.player.streamPlayer.isAudioOutputRunning {
                        self.lastAppliedAudioSessionOptions = nil
                        _ = await self.activateAudioSessionForPlaybackChecked(reason: "audio route configuration change")
                    }
                    _ = self.player.streamPlayer.handleAudioRouteChange()
                    if expectedToPlay && !self.player.streamPlayer.isAudioOutputRunning {
                        self.scheduleAudioOutputRecoveryIfNeeded(reason: "audio route configuration change")
                    }
                    self.scheduleResumeAfterRouteChangeIfNeeded()
                default:
                    break
                }
            }
        }
    }

    private func setupMediaResetObserver() {
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
                self.player.nowPlayingController.setupRemoteCommands()
                self.player.repairSystemPlaybackSurfacesIfNeeded(reason: "media services reset")
                // 如果正在播放，重新触发当前歌曲播放（让库重新走 AudioRenderer.start 流程）
                if let song = self.player.currentSong, self.player.isPlaying {
                    let time = self.player.currentTime
                    AppLogger.info("媒体服务重置后重新播放: \(song.name), 从 \(String(format: "%.1f", time))s 继续")
                    self.player.loadAndPlay(
                        song: song,
                        startTime: time,
                        fadeInDuration: 0.8,
                        fadeInReason: "media services reset"
                    )
                }
            }
        }
    }

    // MARK: - 外接输出断开

    /// External-route removal is a safety pause, not an interruption recovery.
    /// Stop immediately so no tail can escape through the built-in speaker.
    func pauseForDisconnectedAudioOutput(reason: String) {
        AppLogger.info("外接音频输出已断开，立即暂停: \(reason)")
        player.rollbackPendingPlaybackQueueMutationIfNeeded()
        player.invalidateInFlightPlaybackWork(reason: "audio output disconnected: \(reason)")
        audioOutputRecoveryTask?.cancel()
        audioOutputRecoveryTask = nil
        routeChangeResumeWorkItem?.cancel()
        routeChangeResumeWorkItem = nil
        cancelInterruptionResumeRetry()
        cancelInterruptionWatchdog()
        player.cancelPlaybackFade(restoreVolume: false)
        player.clearPlaybackStartFade(restoreVolume: true)
        player.endTransitionKeepAlive()

        wasPlayingBeforeInterruption = false
        isUnderInterruption = false
        lastAppliedAudioSessionOptions = nil

        if player.appleMusicPlayback.isActive {
            _ = player.appleMusicPlayback.pause()
        } else if player.streamPlayer.state == .connecting {
            // A connecting pipeline would otherwise enter `.playing` on speaker
            // after this callback. Keep the song selected and reload on explicit play.
            player.suppressStopHandlingUntil = Date().addingTimeInterval(1)
            player.streamPlayer.stop()
        } else {
            _ = player.streamPlayer.pauseAudioOutputImmediately()
        }
        player.streamPlayer.outputVolume = 1.0
        player.isPlaying = false
        player.isLoading = false
        player.lastPausedAt = Date()
        player.refreshPlaybackSurfaceState()
        player.saveStateImmediately()

        if player.currentSong != nil {
            player.updateNowPlayingInfo()
            player.updateNowPlayingArtwork(for: player.currentSong)
        }
    }

    // MARK: - 路由变化后的延迟恢复

    /// 其他 App 释放音频路由后，系统的主音频提示可能稍后才更新，在此再尝试恢复。
    func scheduleResumeAfterRouteChangeIfNeeded() {
        guard !isUnderInterruption else {
            AppLogger.debug("中断进行中，忽略路由变化触发的恢复")
            return
        }
        guard wasPlayingBeforeInterruption, player.currentSong != nil, !player.isPlaying else { return }
        // 延迟 1s 检查，避免路由切换瞬间的误判
        routeChangeResumeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.wasPlayingBeforeInterruption, !self.player.isPlaying, self.player.currentSong != nil else { return }
                guard self.isAutoResumePermittedNow() else {
                    AppLogger.debug("路由变化后仍有其他音频，不恢复")
                    return
                }
                AppLogger.info("路由变化后确认可恢复，恢复播放")
                let _ = await self.resumeAfterInterruption(reason: "route change")
            }
        }
        routeChangeResumeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    /// 取消路由变化触发的延迟恢复 + 假播放输出巡检（用户显式暂停/停止时调用）
    func cancelScheduledAutoResumeWork() {
        routeChangeResumeWorkItem?.cancel()
        routeChangeResumeWorkItem = nil
        audioOutputRecoveryTask?.cancel()
        audioOutputRecoveryTask = nil
        stalledOutputRecoveryTask?.cancel()
        stalledOutputRecoveryTask = nil
        resetPlaybackOutputLiveness()
    }

    // MARK: - 假播放输出修复

    /// Debounces route churn, then compares the public playback state with the
    /// actual AVAudioEngine output. A stale `.playing` value must never be allowed
    /// to strand the UI or make the play button a no-op.
    func scheduleAudioOutputRecoveryIfNeeded(reason: String) {
        guard !player.appleMusicPlayback.isActive else { return }
        guard player.currentSong != nil else { return }
        guard player.isPlaying || player.streamPlayer.state == .playing else { return }
        guard !player.streamPlayer.isAudioOutputRunning else { return }
        guard audioOutputRecoveryTask == nil else { return }

        let expectedSessionId = player.playbackSessionId
        audioOutputRecoveryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled, let self else { return }
            defer { self.audioOutputRecoveryTask = nil }
            guard self.player.playbackSessionId == expectedSessionId,
                  self.player.currentSong != nil,
                  self.player.isPlaying || self.player.streamPlayer.state == .playing else { return }
            guard !self.player.streamPlayer.isAudioOutputRunning else {
                if MPNowPlayingInfoCenter.default().nowPlayingInfo == nil {
                    self.player.updateNowPlayingInfo()
                    self.player.updateNowPlayingArtwork(for: self.player.currentSong)
                }
                return
            }
            // App 激活和系统路由交接时 AudioEngine 可能短暂报告未运行。
            // 再确认一次，避免把瞬态当成故障而重建正在播放的输出。
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            guard self.player.playbackSessionId == expectedSessionId,
                  !self.player.streamPlayer.isAudioOutputRunning else { return }
            _ = await self.recoverUnavailableAudioOutput(reason: reason)
        }
    }

    func observePlaybackOutputLiveness(now: Date = Date()) {
        if observedPlaybackSessionID != player.playbackSessionId {
            observedPlaybackSessionID = player.playbackSessionId
            lastAudibleDuration = player.streamPlayer.totalAudiblePlaybackDuration
            lastAudibleAdvanceAt = now
            zeroEnvelopeDetectedAt = nil
        }

        guard player.currentSong != nil,
              !player.appleMusicPlayback.isActive,
              player.isPlaying,
              !player.isLoading,
              !player.isSeeking,
              !player.needsPlaybackRestoration,
              !isUnderInterruption,
              !wasPlayingBeforeInterruption,
              player.streamPlayer.state == .playing,
              !player.streamPlayer.isDrainingEndOfStream,
              !player.streamPlayer.isTrackTransitionNotificationDeferred else {
            resetPlaybackOutputLiveness(now: now)
            return
        }

        let duration = player.effectivePlaybackDuration
        if duration > 0, duration - player.currentTime <= 3 {
            resetPlaybackOutputLiveness(now: now)
            return
        }

        let outputVolume = player.streamPlayer.outputVolume
        if !player.sleepAndFade.isPlaybackFadeActive,
           outputVolume <= 0.01 || player.streamPlayer.duckingVolume <= 0.01 {
            if let zeroEnvelopeDetectedAt,
               now.timeIntervalSince(zeroEnvelopeDetectedAt) >= 1.25 {
                AppLogger.error(
                    "播放仍在进行但输出包络保持静音，恢复混音台音量",
                    step: "playback.output-envelope-repair"
                )
                player.cancelPlaybackFade(restoreVolume: true)
                player.streamPlayer.duckingVolume = 1.0
                self.zeroEnvelopeDetectedAt = nil
            } else if zeroEnvelopeDetectedAt == nil {
                zeroEnvelopeDetectedAt = now
            }
            return
        }
        zeroEnvelopeDetectedAt = nil

        let audibleDuration = player.streamPlayer.totalAudiblePlaybackDuration
        if audibleDuration > lastAudibleDuration + 0.02 {
            lastAudibleDuration = audibleDuration
            lastAudibleAdvanceAt = now
            return
        }

        guard player.streamPlayer.isAudioOutputRunning else {
            scheduleAudioOutputRecoveryIfNeeded(reason: "playback liveness")
            return
        }
        guard now.timeIntervalSince(lastAudibleAdvanceAt) >= 6,
              stalledOutputRecoveryTask == nil else { return }

        let expectedSong = player.currentSong
        stalledOutputRecoveryTask = Task { @MainActor [weak self] in
            guard let self, let expectedSong else { return }
            defer { self.stalledOutputRecoveryTask = nil }
            await self.recoverStalledAudioOutput(song: expectedSong)
        }
    }

    private func resetPlaybackOutputLiveness(now: Date = Date()) {
        observedPlaybackSessionID = player.playbackSessionId
        lastAudibleDuration = player.streamPlayer.totalAudiblePlaybackDuration
        lastAudibleAdvanceAt = now
        zeroEnvelopeDetectedAt = nil
    }

    private func recoverStalledAudioOutput(song: Song) async {
        let initialSessionID = player.playbackSessionId
        let initialAudibleDuration = player.streamPlayer.totalAudiblePlaybackDuration
        AppLogger.error(
            "播放进度仍在推进但 PCM 输出已停止，开始恢复音频管线",
            step: "playback.audible-stall"
        )

        player.cancelPlaybackFade(restoreVolume: true)
        lastAppliedAudioSessionOptions = nil
        guard await activateAudioSessionForPlaybackChecked(reason: "recover audible stall") else {
            pauseAndReleaseStalledPlayback(song: song, reason: "audio session activation failed")
            return
        }
        guard player.playbackSessionId == initialSessionID,
              player.matchesPlaybackTarget(player.currentSong, expected: song),
              player.isPlaying else { return }

        _ = player.streamPlayer.pauseAudioOutputImmediately()
        player.streamPlayer.outputVolume = 0
        if player.streamPlayer.resume() {
            player.beginPlaybackFade(to: 1, duration: 0.45)
        }

        do {
            try await Task.sleep(for: .seconds(2))
        } catch {
            return
        }
        guard !Task.isCancelled,
              player.matchesPlaybackTarget(player.currentSong, expected: song),
              player.isPlaying else { return }
        if player.streamPlayer.totalAudiblePlaybackDuration >= initialAudibleDuration + 0.3 {
            resetPlaybackOutputLiveness()
            AppLogger.info("音频输出已原位恢复", step: "playback.audible-stall-recovered")
            return
        }

        let resumeTime = max(player.currentTime, 0)
        player.loadAndPlay(
            song: song,
            startTime: resumeTime,
            fadeInDuration: 0.65,
            fadeInReason: "audible output recovery",
            preserveRetryBudget: true
        )
        let rebuildSessionID = player.playbackSessionId
        let rebuildBaseline = player.streamPlayer.totalAudiblePlaybackDuration

        do {
            try await Task.sleep(for: .seconds(12))
        } catch {
            return
        }
        guard !Task.isCancelled,
              player.playbackSessionId == rebuildSessionID,
              player.matchesPlaybackTarget(player.currentSong, expected: song),
              player.isPlaying || player.isLoading else { return }
        if player.streamPlayer.totalAudiblePlaybackDuration >= rebuildBaseline + 0.5 {
            resetPlaybackOutputLiveness()
            AppLogger.info("音频管线重建后已恢复输出", step: "playback.audible-stall-rebuilt")
            return
        }

        AppLogger.error(
            "音频输出恢复失败，暂停播放并释放系统音频会话",
            step: "playback.audible-stall-release-session"
        )
        pauseAndReleaseStalledPlayback(song: song, reason: "recovery budget exhausted")
    }

    private func pauseAndReleaseStalledPlayback(song: Song, reason: String) {
        guard player.matchesPlaybackTarget(player.currentSong, expected: song),
              player.isPlaying || player.isLoading else { return }
        player.invalidateInFlightPlaybackWork(reason: "audible output recovery exhausted")
        player.cancelPlaybackFade(restoreVolume: true)
        _ = player.streamPlayer.pauseAudioOutputImmediately()
        player.isPlaying = false
        player.isLoading = false
        player.lastPausedAt = Date()
        wasPlayingBeforeInterruption = false
        player.refreshPlaybackSurfaceState()
        player.saveState()
        deactivateAudioSession(reason: "audible output recovery: \(reason)")
        resetPlaybackOutputLiveness()
    }

    /// Rebuilds an invalidated output in place when possible. If iOS refuses the
    /// existing renderer, fall back to a fresh pipeline at the audible position.
    @discardableResult
    func recoverUnavailableAudioOutput(reason: String) async -> Bool {
        guard let song = player.currentSong else { return false }
        let expectedSessionId = player.playbackSessionId
        if song.isAppleMusic {
            return player.appleMusicPlayback.isActive
        }
        if player.streamPlayer.isAudioOutputRunning {
            player.updateNowPlayingInfo()
            player.updateNowPlayingArtwork(for: song)
            return true
        }

        AppLogger.warning("检测到假播放状态，重建音频输出 reason=\(reason)")
        player.cancelPlaybackFade(restoreVolume: false)
        lastAppliedAudioSessionOptions = nil
        guard await activateAudioSessionForPlaybackChecked(reason: "recover dead output: \(reason)") else {
            player.isPlaying = false
            player.isLoading = false
            wasPlayingBeforeInterruption = true
            player.refreshPlaybackSurfaceState()
            scheduleInterruptionResumeRetry(reason: "recover dead output: \(reason)")
            return false
        }
        guard player.playbackSessionId == expectedSessionId,
              player.matchesPlaybackTarget(player.currentSong, expected: song) else {
            return false
        }

        if player.streamPlayer.state == .playing {
            player.streamPlayer.pause()
        }
        if player.streamPlayer.state == .paused, let song = player.currentSong {
            player.streamPlayer.outputVolume = 0.0
            if player.streamPlayer.resume(), player.streamPlayer.isAudioOutputRunning {
                player.isPlaying = true
                player.isLoading = false
                player.lastPausedAt = nil
                wasPlayingBeforeInterruption = false
                player.refreshPlaybackSurfaceState()
                player.updateNowPlayingInfo()
                player.updateNowPlayingArtwork(for: song)
                player.saveState()
                player.beginPlaybackFade(to: 1.0, duration: 0.7)
                return true
            }
        }

        let resumeTime = max(player.currentTime, 0)
        AppLogger.warning("原音频输出无法复活，从 \(String(format: "%.1f", resumeTime))s 重建播放管线")
        player.isPlaying = false
        player.isLoading = true
        player.refreshPlaybackSurfaceState()
        player.loadAndPlay(
            song: song,
            startTime: resumeTime,
            fadeInDuration: 0.8,
            fadeInReason: "audio output rebuild"
        )
        return true
    }

    // MARK: - 中断恢复

    /// 中断恢复：先尝试 resume，如果播放器状态异常则从当前位置重新加载
    ///
    /// ⚠️ 调用约定：
    /// - 优先使用 `attemptInterruptionResume(reason:)`：内部已包含失败重试和状态保护。
    /// - 直接调本方法的场景仅限「确定 session 可激活、要立刻恢复」时（如用户主动点播放）。
    /// - **失败时不会清空 `wasPlayingBeforeInterruption`**，方便上层重试。
    @discardableResult
    func resumeAfterInterruption(reason: String = "interruption resume") async -> Bool {
        guard let song = player.currentSong else { return false }
        let expectedSessionId = player.playbackSessionId
        if song.isAppleMusic {
            guard wasPlayingBeforeInterruption else { return false }
            if player.appleMusicPlayback.matches(song) {
                do {
                    guard try await player.appleMusicPlayback.resume() else {
                        return false
                    }
                } catch {
                    player.showPlaybackError(song: song, error: error)
                    return false
                }
            } else {
                player.loadAndPlay(
                    song: song,
                    startTime: max(player.currentTime, 0)
                )
            }

            guard player.playbackSessionId == expectedSessionId,
                  player.matchesPlaybackTarget(player.currentSong, expected: song) else {
                return false
            }
            routeChangeResumeWorkItem?.cancel()
            routeChangeResumeWorkItem = nil
            cancelInterruptionResumeRetry()
            cancelInterruptionWatchdog()
            isUnderInterruption = false
            wasPlayingBeforeInterruption = false
            return true
        }
        AppLogger.info("恢复播放 (state=\(player.streamPlayer.state), reason=\(reason))")

        // 强制重写 options（绕过缓存），中断恢复时确保 session 处于 active。
        // 这里使用 activateAudioSessionForPlayback，而不是只依赖 reapply，
        // 避免 options 未变化但 session 已被系统打断的场景。
        lastAppliedAudioSessionOptions = nil
        let activated = await activateAudioSessionForPlaybackChecked(reason: reason)
        guard activated else {
            AppLogger.warning("中断恢复时音频会话激活失败 reason=\(reason)，保留中断标志等待重试")
            return false
        }
        guard player.playbackSessionId == expectedSessionId,
              player.matchesPlaybackTarget(player.currentSong, expected: song),
              wasPlayingBeforeInterruption else {
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
        if player.isResumeLikelyStale {
            AppLogger.info("中断恢复时 URL 已老化，重新取址续播: \(song.name)")
            player.lastPausedAt = nil
            player.loadAndPlay(
                song: song,
                startTime: max(player.currentTime, 0),
                fadeInDuration: 0.8,
                fadeInReason: "interruption stale reload"
            )
            return true
        }

        if player.streamPlayer.state == .paused {
            player.streamPlayer.outputVolume = 0.0
            guard player.streamPlayer.resume(), player.streamPlayer.isAudioOutputRunning else {
                let time = player.currentTime
                AppLogger.warning("中断后无法复活原输出，从 \(String(format: "%.1f", time))s 重新加载")
                player.loadAndPlay(
                    song: song,
                    startTime: time,
                    fadeInDuration: 0.8,
                    fadeInReason: "interruption resume fallback"
                )
                return true
            }
            player.isPlaying = true
            player.isLoading = false
            player.lastPausedAt = nil
            player.refreshPlaybackSurfaceState()
            player.beginPlaybackFade(to: 1.0, duration: 0.7)
        } else if player.streamPlayer.state == .playing {
            // 微信语音/电话等中断后，SDK 状态偶尔仍停在 `.playing`，
            // 但底层 AudioEngine 已经不出声。强制走一次 pause→resume
            // 让 AudioRenderer 在重新激活的 session 上启动。
            player.streamPlayer.pause()
            player.streamPlayer.outputVolume = 0.0
            guard player.streamPlayer.resume(), player.streamPlayer.isAudioOutputRunning else {
                let time = player.currentTime
                AppLogger.warning("中断后播放状态与输出不一致，从 \(String(format: "%.1f", time))s 重新加载")
                player.loadAndPlay(
                    song: song,
                    startTime: time,
                    fadeInDuration: 0.8,
                    fadeInReason: "interruption output rebuild"
                )
                return true
            }
            player.isPlaying = true
            player.isLoading = false
            player.lastPausedAt = nil
            player.refreshPlaybackSurfaceState()
            player.beginPlaybackFade(to: 1.0, duration: 0.7)
        } else {
            let time = player.currentTime
            AppLogger.info("播放器状态非 paused，从 \(String(format: "%.1f", time))s 重新加载")
            player.loadAndPlay(
                song: song,
                startTime: time,
                fadeInDuration: 0.8,
                fadeInReason: "interruption state reload"
            )
        }
        return true
    }

    /// 立即尝试一次中断恢复；失败则启动阶梯重试。
    /// 推荐外部调用此方法而非直接调 `resumeAfterInterruption`。
    func attemptInterruptionResume(reason: String) {
        guard player.currentSong != nil else { return }
        guard wasPlayingBeforeInterruption else { return }
        guard !player.isPlaying else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            if await self.resumeAfterInterruption(reason: reason) {
                return
            }
            self.scheduleInterruptionResumeRetry(reason: reason)
        }
    }

    /// 启动（或重启）阶梯重试任务。每一档都会尝试一次 `resumeAfterInterruption`，
    /// 任何一档成功即整条链路结束。
    func scheduleInterruptionResumeRetry(reason: String) {
        cancelInterruptionResumeRetry()
        // 中断结束后音频尚未出声，App 可能随时被挂起；
        // 保活到重试链结束（成功恢复后由 .playing 状态回调释放）。
        player.beginTransitionKeepAlive(reason: "interruption resume retry")
        let schedule = Self.interruptionResumeBackoff
        interruptionResumeTask = Task { @MainActor [weak self] in
            for (index, delay) in schedule.enumerated() {
                let nanos = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                guard !Task.isCancelled else { return }
                guard let self else { return }
                guard self.wasPlayingBeforeInterruption,
                      self.player.currentSong != nil,
                      !self.player.isPlaying else {
                    self.player.endTransitionKeepAlive()
                    return
                }
                // 标准模式下不抢占其他音频；智能/始终共存可混音恢复。
                if !self.isAutoResumePermittedNow() {
                    AppLogger.info("中断恢复重试 [\(index+1)/\(schedule.count)]: 其他音频仍在播放，跳过")
                    continue
                }
                let attempt = index + 1
                let total = schedule.count
                AppLogger.info("中断恢复阶梯重试 [\(attempt)/\(total)] (delay=\(delay)s, reason=\(reason))")
                if await self.resumeAfterInterruption(reason: "\(reason) retry#\(attempt)") {
                    return
                }
            }
            if let self, self.wasPlayingBeforeInterruption, !self.player.isPlaying {
                AppLogger.warning("中断恢复阶梯重试全部失败 reason=\(reason)，等待用户手动恢复")
            }
            self?.player.endTransitionKeepAlive()
        }
    }

    /// 取消正在进行中的阶梯重试。`pausePlayback` / 用户主动停止 / 恢复成功时调用。
    func cancelInterruptionResumeRetry() {
        interruptionResumeTask?.cancel()
        interruptionResumeTask = nil
    }

    /// 中断巡检：部分 App 不发送 `.ended`。巡检只能留下诊断信息，
    /// 不能猜测通话、录音或 Siri 已结束，更不能擅自恢复播放。
    func armInterruptionWatchdog() {
        cancelInterruptionWatchdog()
        interruptionWatchdogTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            guard let self, self.isUnderInterruption else { return }
            AppLogger.warning("音频中断持续 60s 且未收到 ended；保持暂停，等待系统或用户恢复")
        }
    }

    func cancelInterruptionWatchdog() {
        interruptionWatchdogTask?.cancel()
        interruptionWatchdogTask = nil
    }

    // MARK: - 清理

    /// deinit 清理：取消全部任务并移除观察者
    func cancelAllWork() {
        cancelInterruptionResumeRetry()
        cancelInterruptionWatchdog()
        cancelScheduledAutoResumeWork()
        gameVoiceDuckingTask?.cancel()
        gameVoiceDuckingTask = nil
        player.streamPlayer.duckingVolume = 1.0
        for observer in [interruptionObserver, mediaResetObserver,
                         foregroundObserver, gameVoiceHintObserver, routeChangeObserver] {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        interruptionObserver = nil
        mediaResetObserver = nil
        foregroundObserver = nil
        gameVoiceHintObserver = nil
        routeChangeObserver = nil
    }
}

// MARK: - PlayerManager facade（外部调用点保持不变）

import MediaPlayer

extension PlayerManager {

    func reapplyAudioSessionOptions(reason: String) {
        audioSessionCoordinator.reapplyAudioSessionOptions(reason: reason)
    }

    func activateAudioSessionForPlayback(reason: String) async {
        await audioSessionCoordinator.activateAudioSessionForPlayback(reason: reason)
    }

    @discardableResult
    func activateAudioSessionForPlaybackChecked(reason: String) async -> Bool {
        await audioSessionCoordinator.activateAudioSessionForPlaybackChecked(reason: reason)
    }

    @discardableResult
    func activateAudioSessionForRecording(reason: String) async -> Bool {
        await audioSessionCoordinator.activateAudioSessionForRecording(reason: reason)
    }

    func deactivateAudioSession(reason: String) {
        audioSessionCoordinator.deactivateAudioSession(reason: reason)
    }

    func handleBackgroundAudioPolicySettingChanged() {
        audioSessionCoordinator.handleBackgroundAudioPolicySettingChanged()
    }

    func handleGameModeDuckingChanged() {
        audioSessionCoordinator.handleGameModeDuckingChanged()
    }

    @discardableResult
    func resumeAfterInterruption(reason: String = "interruption resume") async -> Bool {
        await audioSessionCoordinator.resumeAfterInterruption(reason: reason)
    }

    func scheduleInterruptionResumeRetry(reason: String) {
        audioSessionCoordinator.scheduleInterruptionResumeRetry(reason: reason)
    }

    func cancelInterruptionResumeRetry() {
        audioSessionCoordinator.cancelInterruptionResumeRetry()
    }

    func cancelInterruptionWatchdog() {
        audioSessionCoordinator.cancelInterruptionWatchdog()
    }

    @discardableResult
    func recoverUnavailableAudioOutput(reason: String) async -> Bool {
        await audioSessionCoordinator.recoverUnavailableAudioOutput(reason: reason)
    }
}
