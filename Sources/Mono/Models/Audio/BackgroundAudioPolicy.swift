import Foundation

/// 与其他 App 音频的共存策略。
///
/// category/options 在每次播放或恢复前确定；播放过程中保持稳定，
/// 避免活动音频会话热切换造成路由抖动和瞬断。
enum BackgroundAudioPolicy: String, CaseIterable, Identifiable {
    case exclusive
    case automatic
    case alwaysMix

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .exclusive:
            return String(localized: "settings_background_audio_policy_exclusive")
        case .automatic:
            return String(localized: "settings_background_audio_policy_automatic")
        case .alwaysMix:
            return String(localized: "settings_background_audio_policy_always_mix")
        }
    }

    var detailText: String {
        switch self {
        case .exclusive:
            return String(localized: "settings_background_audio_policy_exclusive_desc")
        case .automatic:
            return String(localized: "settings_background_audio_policy_automatic_desc")
        case .alwaysMix:
            return String(localized: "settings_background_audio_policy_always_mix_desc")
        }
    }
}
