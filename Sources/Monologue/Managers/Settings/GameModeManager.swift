// 游戏模式管理器：一键切到"边玩游戏边听歌"的状态集合
// 进入游戏模式时的副作用：
//   1. 强制 backgroundAudioPolicy = .alwaysMix（游戏音效和音乐共存）
//   2. 可选：降低音质到 .standard（减少 CPU/电量消耗）
//   3. 可选：暂停 Live Activity / 灵动岛歌词（不抢通知栏）
//   4. 可选：切换到"游戏配乐"歌单
// 退出游戏模式时恢复进入前的状态。

import Foundation
import Combine
import SwiftUI
import WidgetKit
import AVFoundation

@MainActor
final class GameModeManager: ObservableObject {
    static let shared = GameModeManager()

    // MARK: - Published
    @Published var isActive: Bool = false

    // MARK: - 依赖
    private let settings = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()

    /// 游戏模式 applyEnter 正在执行中（给 PlayerManager 判断：内部切音质 vs 用户手动切）
    private(set) var isApplyingEnter: Bool = false

    // MARK: - 自动退出监听
    /// 次要音频 hint 监听（仅游戏模式开启 + 用户允许自动退出时激活）
    private var secondaryHintObserver: NSObjectProtocol?
    /// 检测到「其他媒体 App 停止」后的延时退出任务（避免偶发跳出误判）
    private var autoExitDelayTask: Task<Void, Never>?
    /// 自动退出判定延时（秒）
    private static let autoExitDelay: TimeInterval = 12

    private init() {
        // 启动时恢复持久化状态
        // 数据源以 AppGroup 为准（控制中心 Widget 可能在 App 退出时改过)
        let appGroupValue = UserDefaults(suiteName: "group.zijiu.Monologue.com")?
            .bool(forKey: "monologue_game_mode_enabled") ?? false
        let legacyValue = settings.gameModeEnabled
        let wasActive = appGroupValue || legacyValue

        // 若 AppGroup 与 standard 不一致，向 AppGroup 看齐（控制中心优先)
        if appGroupValue != legacyValue {
            settings.gameModeEnabled = appGroupValue
        }

        // ⚠️ 冷启动重入保护：
        // 本 init 可能发生在 PlayerManager.init → setupAudioSession → 访问
        // `GameModeManager.shared` 的同步路径中。若此处同步调用
        // `syncToAppGroup` / `applyEnter` 会反向访问 `PlayerManager.shared`
        // / `ControlCenter.shared.reloadControls` / Darwin broadcast，造成：
        //   - 单例循环初始化（EXC_BREAKPOINT brk 1）
        //   - SwiftUI 首帧 dispatchActions 期间 @Published 状态突变
        //
        // 所有有"反向访问其他单例 / 全局副作用"的工作都必须 defer 到下一轮
        // run loop，确保 `PlayerManager.shared` 初始化已完成。
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if wasActive {
                // 先置位再 apply：PlayerManager.audioSessionOptions 会读 isActive
                self.isActive = true
                self.applyEnter(persist: false)
                self.syncToAppGroup(active: true)
            } else {
                // 兜底：确保 AppGroup 状态写一次，避免控制中心 Widget 胶囊 isOn 漂移
                self.syncToAppGroup(active: false)
            }
        }

        // 监听回到前台，同步控制中心改动
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.syncFromAppGroup()
                }
            }
            .store(in: &cancellables)

        // 跨进程 Darwin 通知：控制中心 Widget 点击后即时唤醒 App 侧逻辑
        // （前台 + 后台运行态均可收到；完全退出由冷启动 init 兜底)
        registerDarwinObserver()
    }

    deinit {
        // 注意：`GameModeManager.shared` 是 App 生命周期单例，正常情况下 deinit
        // 永不会被调用。此处保留 unregister 仅作为防御性清理
        // （如未来改成可释放对象 / 测试场景重建实例时才有意义）
        //
        // 直接内联 CFNotificationCenter 调用而非走 @MainActor 方法，
        // 因为 Swift 6 并发下 deinit 是 nonisolated 的，不能直接调用主隔离方法。
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveObserver(
            center,
            observer,
            CFNotificationName(rawValue: Self.darwinNotificationName as CFString),
            nil
        )
    }

    // MARK: - Darwin Cross-Process Notification

    /// 控制中心 Widget 修改后广播此通知，主 App 收到即同步副作用
    nonisolated private static let darwinNotificationName = "com.zijiu.Monologue.gamemode.changed"

    private func registerDarwinObserver() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let manager = Unmanaged<GameModeManager>
                    .fromOpaque(observer)
                    .takeUnretainedValue()
                Task { @MainActor in
                    manager.syncFromAppGroup()
                }
            },
            Self.darwinNotificationName as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func unregisterDarwinObserver() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveObserver(
            center,
            observer,
            CFNotificationName(rawValue: Self.darwinNotificationName as CFString),
            nil
        )
    }

    /// 向其他进程（Widget）广播状态变更
    fileprivate static func broadcastDarwinChange() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(rawValue: darwinNotificationName as CFString),
            nil,
            nil,
            true
        )
    }

    /// 从 App Group 读取控制中心的改动，必要时 enter/exit
    private func syncFromAppGroup() {
        let appGroupValue = UserDefaults(suiteName: "group.zijiu.Monologue.com")?
            .bool(forKey: "monologue_game_mode_enabled") ?? false

        if appGroupValue && !isActive {
            // 控制中心开了，但 App 里还没开 → 进入
            isActive = true
            applyEnter(persist: true)
            AppLogger.info("游戏模式已从控制中心开启（前台同步）")
        } else if !appGroupValue && isActive {
            // 控制中心关了，但 App 里还开着 → 退出
            isActive = false
            applyExit(persist: true)
            AppLogger.info("游戏模式已从控制中心关闭（前台同步）")
        }
    }

    // MARK: - 开关

    /// 切换游戏模式（UI 层直接调用）
    func toggle() {
        if isActive {
            exit()
        } else {
            enter()
        }
    }

    /// 手动进入游戏模式
    func enter() {
        guard !isActive else { return }
        // 先置位再 apply：PlayerManager.audioSessionOptions 会读 isActive
        isActive = true
        applyEnter(persist: true)
        syncToAppGroup(active: true)
        PlayerManager.shared.handleGameModeDuckingChanged()
        AppLogger.info("游戏模式已开启")
    }

    /// 手动退出游戏模式
    func exit() {
        guard isActive else { return }
        // 先置位为 false 再 apply：PlayerManager.audioSessionOptions 会读 isActive
        isActive = false
        applyExit(persist: true)
        syncToAppGroup(active: false)
        PlayerManager.shared.handleGameModeDuckingChanged()
        AppLogger.info("游戏模式已关闭")
    }

    // MARK: - App Group 同步（控制中心 Widget 读取用）

    private func syncToAppGroup(active: Bool) {
        UserDefaults(suiteName: "group.zijiu.Monologue.com")?
            .set(active, forKey: "monologue_game_mode_enabled")
        if #available(iOS 18, *) {
            ControlCenter.shared.reloadControls(
                ofKind: "zijiu.Monologue.com.control.gamemode"
            )
        }
        // 广播给其他进程（主要让 Widget 可以刷新 UI,未来多进程扩展预留）
        Self.broadcastDarwinChange()
        // 更新 Home Screen Quick Actions 的文案（开启中/未开启）
        // 直接传入 active，避免 refresh 内部再读 shared 触发循环初始化
        MonologueQuickActionsManager.refresh(isActive: active)
    }

    // MARK: - 进入副作用

    private func applyEnter(persist: Bool) {
        // 1. 备份当前状态（用于退出时恢复）
        //    使用「managed」标记：只有当我们真的改了用户的偏好时，退出才恢复；
        //    否则保持用户原值（避免把用户本来就是 alwaysMix 的偏好改掉）
        if persist {
            settings.gameModeEnabled = true

            let originalPolicy = settings.backgroundAudioPolicy
            UserDefaults.standard.set(
                originalPolicy.rawValue,
                forKey: AppConfig.StorageKeys.gameModeSavedBackgroundPolicy
            )
            let policyWasManaged = originalPolicy != .alwaysMix
            UserDefaults.standard.set(
                policyWasManaged,
                forKey: AppConfig.StorageKeys.gameModeSavedPolicyWasManaged
            )

            let originalQuality = PlayerManager.shared.soundQuality
            UserDefaults.standard.set(
                originalQuality.rawValue,
                forKey: AppConfig.StorageKeys.gameModeSavedSoundQuality
            )
        }

        // 2. 强制 .alwaysMix（关键）
        settings.backgroundAudioPolicy = .alwaysMix
        PlayerManager.shared.handleBackgroundAudioPolicySettingChanged()

        // 2.1 Ducking：若用户开启，给 session options 叠加 .interruptSpokenAudioAndMixWithOthers
        // PlayerManager.audioSessionOptions() 会读 GameModeManager.isActive
        // 但 isActive 的 set 在调用方之后才 true；这里主动触发一次 re-apply
        // （实际 applyEnter 先跑，isActive 随后置 true → 下次 re-apply 时才生效，
        // 所以由 enter() / toggle() 外壳在 isActive 置位之后再调一次）

        // 3. 可选：切到首选音质（用户指定 > 降音质默认 > 不变）
        // 标记：此段时间内的 switchQuality 属于"游戏模式内部切换"，不应覆盖备份
        isApplyingEnter = true
        defer { isApplyingEnter = false }

        if let preferred = settings.gameModePreferredQuality,
           preferred != PlayerManager.shared.soundQuality {
            PlayerManager.shared.switchQuality(preferred)
        } else if settings.gameModeLowerQuality {
            let current = PlayerManager.shared.soundQuality
            // 只在当前音质高于"标准"时降低，避免用户本来就是标准不必折腾
            let downgrade: [SoundQuality] = [.jymaster, .sky, .jyeffect, .hires, .lossless, .exhigh, .higher]
            if downgrade.contains(current) {
                PlayerManager.shared.switchQuality(.standard)
            }
        }

        // 4. 可选：切到指定本地歌单
        if !settings.gameModeAutoPlaylistLocalId.isEmpty {
            switchToAutoPlaylistIfAvailable()
        }

        // 5. 刷新一次 NowPlayingInfo（让「隐藏锁屏信息」开关立即生效）
        PlayerManager.shared.updateNowPlayingInfo()

        // 6. 若用户开启「检测到游戏关闭时自动退出」，注册 secondary hint 监听
        if settings.gameModeAutoExit {
            registerAutoExitObserver()
        }
    }

    /// 根据 settings.gameModeAutoPlaylistLocalId 切到对应本地歌单
    /// 行为：
    /// - 已在播（有 currentSong 且 isPlaying）→ 不打断，仅记录日志
    /// - 空闲（没有 currentSong，或暂停中且无当前歌曲）→ 自动开始播
    private func switchToAutoPlaylistIfAvailable() {
        let targetId = settings.gameModeAutoPlaylistLocalId
        let playlistManager = LocalPlaylistManager.shared
        guard let playlist = playlistManager.playlists.first(where: { $0.id == targetId }) else {
            AppLogger.warning("游戏模式指定歌单不存在: \(targetId)")
            return
        }
        let songs = playlistManager.songs(for: playlist)
        guard let first = songs.first else {
            AppLogger.warning("游戏模式指定歌单为空: \(playlist.name)")
            return
        }

        // 用户正在听歌 → 不打断（尊重用户当前选择，音乐比游戏模式决定优先）
        if PlayerManager.shared.currentSong != nil && PlayerManager.shared.isPlaying {
            AppLogger.info("游戏模式：当前正在播放，跳过自动切歌单『\(playlist.name)』")
            return
        }

        // 空闲 or 暂停中无当前歌曲 → 自动开始播
        AppLogger.info("游戏模式自动切到歌单: \(playlist.name)（\(songs.count) 首）")
        PlayerManager.shared.play(song: first, in: songs)
    }

    // MARK: - 退出副作用

    private func applyExit(persist: Bool) {
        if persist {
            settings.gameModeEnabled = false
        }

        // 恢复背景音频策略：
        // 仅在 `gameModeSavedPolicyWasManaged == true` 时恢复
        // （即进入游戏模式时我们确实把用户原值 exclusive/automatic 改成了 alwaysMix）
        let policyWasManaged = UserDefaults.standard.bool(forKey: AppConfig.StorageKeys.gameModeSavedPolicyWasManaged)
        if policyWasManaged {
            let savedPolicyRaw = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.gameModeSavedBackgroundPolicy)
            if let raw = savedPolicyRaw,
               let saved = BackgroundAudioPolicy(rawValue: raw) {
                settings.backgroundAudioPolicy = saved
            }
            PlayerManager.shared.handleBackgroundAudioPolicySettingChanged()
        } else {
            // 用户本来就是 alwaysMix，保持现状但仍重新应用一次 options
            // （避免遗留 Ducking option 未被清除）
            PlayerManager.shared.handleBackgroundAudioPolicySettingChanged()
        }

        // 恢复音质：仅当启用了「降音质」且真实做过切换
        if settings.gameModeLowerQuality {
            let savedQualityRaw = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.gameModeSavedSoundQuality)
            if let raw = savedQualityRaw,
               let saved = SoundQuality(rawValue: raw),
               saved != PlayerManager.shared.soundQuality {
                PlayerManager.shared.switchQuality(saved)
            }
        }

        // 清理备份
        UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.gameModeSavedBackgroundPolicy)
        UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.gameModeSavedSoundQuality)
        UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.gameModeSavedPolicyWasManaged)
        UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.gameModeSavedQualityWasManaged)

        // 恢复 NowPlayingInfo（从静默状态恢复）
        PlayerManager.shared.updateNowPlayingInfo()

        // 反注册自动退出监听 + 取消延时
        unregisterAutoExitObserver()
        autoExitDelayTask?.cancel()
        autoExitDelayTask = nil
    }

    // MARK: - 自动退出：secondary hint 监听

    /// 外部（如设置页）调用：根据当前 isActive + gameModeAutoExit 的组合，注册/反注册监听
    func reapplyAutoExitObserver() {
        if isActive && settings.gameModeAutoExit {
            registerAutoExitObserver()
        } else {
            unregisterAutoExitObserver()
            autoExitDelayTask?.cancel()
            autoExitDelayTask = nil
        }
    }

    private func registerAutoExitObserver() {
        unregisterAutoExitObserver()
        secondaryHintObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
                  let hintType = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: typeValue)
            else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch hintType {
                case .begin:
                    // 其他主媒体 App 开始播（可能是游戏重新进入前台），取消待定的退出
                    self.autoExitDelayTask?.cancel()
                    self.autoExitDelayTask = nil
                case .end:
                    // 其他主媒体 App 停止 → 延时判定是否真的游戏已结束
                    self.scheduleAutoExitCheck()
                @unknown default:
                    break
                }
            }
        }
    }

    private func unregisterAutoExitObserver() {
        if let observer = secondaryHintObserver {
            NotificationCenter.default.removeObserver(observer)
            secondaryHintObserver = nil
        }
    }

    /// 延时 N 秒，若届时仍然没有其他音频（即游戏真的退出了），执行 exit()
    private func scheduleAutoExitCheck() {
        autoExitDelayTask?.cancel()
        autoExitDelayTask = Task { @MainActor [weak self] in
            let delay = Self.autoExitDelay
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard let self, self.isActive else { return }
            // 二次确认：此刻系统仍报告没有其他音频在播
            let stillNoOther = !AVAudioSession.sharedInstance().isOtherAudioPlaying
            guard stillNoOther else { return }
            AppLogger.info("游戏模式：检测到其他音频停止超过 \(Int(delay))s，自动退出")
            self.exit()
        }
    }

    // MARK: - 子选项变化时的行为（由设置页调用）

    /// 音质偏好变了（比如用户在游戏模式已开启时关闭"降音质"）
    func reapplyQualityPreference() {
        guard isActive else { return }
        isApplyingEnter = true
        defer { isApplyingEnter = false }
        if settings.gameModeLowerQuality {
            let current = PlayerManager.shared.soundQuality
            let downgrade: [SoundQuality] = [.jymaster, .sky, .jyeffect, .hires, .lossless, .exhigh, .higher]
            if downgrade.contains(current) {
                PlayerManager.shared.switchQuality(.standard)
            }
        }
    }

    /// PlayerManager 调用：用户在游戏模式已开启时手动换了音质，更新备份值，
    /// 这样退出游戏模式时恢复到用户最新意图，而不是进入前的"历史值"
    func userDidSwitchSoundQuality(_ newQuality: SoundQuality) {
        guard isActive else { return }
        guard !isApplyingEnter else { return } // 游戏模式内部切换，跳过
        UserDefaults.standard.set(
            newQuality.rawValue,
            forKey: AppConfig.StorageKeys.gameModeSavedSoundQuality
        )
        AppLogger.info("游戏模式：用户手动切换音质 → 备份更新为 \(newQuality.rawValue)")
    }
}
