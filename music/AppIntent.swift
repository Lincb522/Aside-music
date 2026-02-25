// AppIntent.swift
// 灵动岛交互意图 — 播放控制
// 通过 App Group UserDefaults 传递控制命令
// 主 App 监听变化并执行实际操作

import AppIntents

/// App Group ID（需要在 Xcode 中配置 App Group capability）
let appGroupID = "group.zijiu.Aside.com"

// MARK: - 播放/暂停

struct TogglePlaybackIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "播放/暂停" }
    
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: appGroupID)
        let current = defaults?.string(forKey: "liveActivityCommand") ?? ""
        // 写入带时间戳的命令，确保每次都触发变化
        defaults?.set("togglePlay_\(Date().timeIntervalSince1970)", forKey: "liveActivityCommand")
        return .result()
    }
}

// MARK: - 下一首

struct NextTrackIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "下一首" }
    
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set("next_\(Date().timeIntervalSince1970)", forKey: "liveActivityCommand")
        return .result()
    }
}

// MARK: - 上一首

struct PreviousTrackIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "上一首" }
    
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set("previous_\(Date().timeIntervalSince1970)", forKey: "liveActivityCommand")
        return .result()
    }
}
