import Foundation

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
