// GameModeScenarioPreset.swift
// Monologue
//
// 游戏模式「场景预设」数据模型：
//   - FPS 竞技：强调语音/不打扰 → Ducking ✓ / 低音质 ✓ / 静默 NowPlaying ✓ / 自动退出 ✓
//   - RPG 剧情：音乐沉浸、允许锁屏显示 → Ducking ✗ / 低音质 ✗ / 静默 NowPlaying ✗ / 自动退出 ✓
//   - 音游：极简干扰 → Ducking ✓ / 低音质 ✗（保留原音质）/ 静默 NowPlaying ✓ / 自动退出 ✓
//
// 预设仅切"行为开关"。不修改用户的显式选择：
//   - gameModePreferredQuality（指定音质）
//   - gameModeAutoPlaylistLocalId（指定歌单）
// 保证用户对这两个子项的控制优先级最高。

import Foundation

enum GameModeScenarioPreset: String, CaseIterable, Identifiable {
    case fps
    case rpg
    case rhythm

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .fps:    return NSLocalizedString("game_mode_preset_fps_title", comment: "")
        case .rpg:    return NSLocalizedString("game_mode_preset_rpg_title", comment: "")
        case .rhythm: return NSLocalizedString("game_mode_preset_rhythm_title", comment: "")
        }
    }

    var localizedSubtitle: String {
        switch self {
        case .fps:    return NSLocalizedString("game_mode_preset_fps_subtitle", comment: "")
        case .rpg:    return NSLocalizedString("game_mode_preset_rpg_subtitle", comment: "")
        case .rhythm: return NSLocalizedString("game_mode_preset_rhythm_subtitle", comment: "")
        }
    }

    var systemIconName: String {
        switch self {
        case .fps:    return "scope"
        case .rpg:    return "book.pages"
        case .rhythm: return "music.quarternote.3"
        }
    }

    struct Behavior {
        let autoDucking: Bool
        let lowerQuality: Bool
        let silentNowPlaying: Bool
        let autoExit: Bool
    }

    var behavior: Behavior {
        switch self {
        case .fps:
            return .init(autoDucking: true, lowerQuality: true, silentNowPlaying: true, autoExit: true)
        case .rpg:
            return .init(autoDucking: false, lowerQuality: false, silentNowPlaying: false, autoExit: true)
        case .rhythm:
            return .init(autoDucking: true, lowerQuality: false, silentNowPlaying: true, autoExit: true)
        }
    }
}

@MainActor
enum GameModeScenarioApplier {
    /// 将指定预设应用到 SettingsManager；若游戏模式已开启，立即触发副作用重算
    static func apply(_ preset: GameModeScenarioPreset) {
        let settings = SettingsManager.shared
        let gameMode = GameModeManager.shared
        let b = preset.behavior

        // 写入 settings（标准化：先全部写完再同步一次，避免中间态触发多次副作用）
        settings.gameModeAutoDucking = b.autoDucking
        settings.gameModeLowerQuality = b.lowerQuality
        settings.gameModeSilentNowPlaying = b.silentNowPlaying
        settings.gameModeAutoExit = b.autoExit

        // 记一下最近选择，用于 UI 高亮"当前所属预设"
        UserDefaults.standard.set(preset.rawValue, forKey: AppConfig.StorageKeys.gameModeLastScenarioPreset)

        // 若游戏模式已开启，立即把副作用全部重算一次
        if gameMode.isActive {
            PlayerManager.shared.handleGameModeDuckingChanged()
            gameMode.reapplyQualityPreference()
            gameMode.reapplyAutoExitObserver()
            PlayerManager.shared.updateNowPlayingInfo()
        }

        AppLogger.info("游戏模式：已应用场景预设『\(preset.rawValue)』")
    }

    /// 当前 settings 的组合是否匹配某个预设（用于在 UI 高亮）
    static var currentMatchedPreset: GameModeScenarioPreset? {
        let settings = SettingsManager.shared
        for preset in GameModeScenarioPreset.allCases {
            let b = preset.behavior
            if settings.gameModeAutoDucking == b.autoDucking &&
                settings.gameModeLowerQuality == b.lowerQuality &&
                settings.gameModeSilentNowPlaying == b.silentNowPlaying &&
                settings.gameModeAutoExit == b.autoExit {
                return preset
            }
        }
        return nil
    }
}
