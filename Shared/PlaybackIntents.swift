// 共享播放控制 Intent —— 主 App 和 Widget Extension 均引用此文件
// 使用 AudioPlaybackIntent 协议，系统会在后台唤醒 App 进程执行，无需打开 UI

import AppIntents
import WidgetKit

/// 从 Widget 或系统播放控件切换主播放器的播放状态。
struct TogglePlaybackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "播放/暂停"
    static let description = IntentDescription("切换 Monologue 播放状态")

    @MainActor
    func perform() async throws -> some IntentResult {
        #if MAIN_APP
        let player = PlayerManager.shared
        player.beginTransitionKeepAlive(reason: "widget toggle playback")
        player.togglePlayPause()
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        return .result()
    }
}

/// 从 Widget 或系统播放控件切换到下一首。
struct NextTrackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "下一首"
    static let description = IntentDescription("播放 Monologue 下一首")

    @MainActor
    func perform() async throws -> some IntentResult {
        #if MAIN_APP
        let player = PlayerManager.shared
        player.beginTransitionKeepAlive(reason: "widget next track")
        player.next()
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        return .result()
    }
}

/// 从 Widget 或系统播放控件切换到上一首。
struct PreviousTrackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "上一首"
    static let description = IntentDescription("播放 Monologue 上一首")

    @MainActor
    func perform() async throws -> some IntentResult {
        #if MAIN_APP
        let player = PlayerManager.shared
        player.beginTransitionKeepAlive(reason: "widget previous track")
        player.previous()
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        return .result()
    }
}
