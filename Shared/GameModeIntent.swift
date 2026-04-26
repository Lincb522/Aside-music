// GameModeIntent.swift
// 游戏模式切换 Intent —— 主 App 和 Widget Extension 均引用此文件

import Foundation
import AppIntents
import WidgetKit

// MARK: - App Group 常量

let gameModeGroupID = "group.zijiu.Monologue.com"
let gameModeKey = "monologue_game_mode_enabled"

// MARK: - 切换游戏模式 Intent

struct ToggleGameModeIntent: SetValueIntent {
    static let title: LocalizedStringResource = "游戏模式"
    static let description = IntentDescription(
        "切换 Monologue 游戏模式（边玩游戏边听歌）",
        categoryName: "Monologue"
    )

    @Parameter(title: "游戏模式")
    var value: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("游戏模式设为 \(\.$value)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // 写入 App Group（主 App 与 Widget 共享；读写都以此为准）
        let defaults = UserDefaults(suiteName: gameModeGroupID)
        defaults?.set(value, forKey: gameModeKey)
        // 追加一个时间戳，主 App 下次进入前台时若发现时间戳变化即可强制 re-sync
        defaults?.set(Date().timeIntervalSince1970, forKey: gameModeKey + ".changedAt")

        #if MAIN_APP
        // 主 App 内走完整的 GameModeManager 流程（含副作用）
        if value {
            GameModeManager.shared.enter()
        } else {
            GameModeManager.shared.exit()
        }
        #else
        // Widget 进程内：
        // 1) 立刻让控制中心胶囊刷新 isOn 视觉
        if #available(iOS 18, *) {
            ControlCenter.shared.reloadControls(
                ofKind: "zijiu.Monologue.com.control.gamemode"
            )
        }
        // 2) 通过 Darwin Notification 广播给主 App，让它即时响应（前台/后台均可）
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName("com.zijiu.Monologue.gamemode.changed" as CFString),
            nil,
            nil,
            true
        )
        #endif

        return .result()
    }
}

// MARK: - 开启游戏模式 Intent（Siri / 快捷指令 / 主屏快捷 / Spotlight）

/// 独立「开启」Intent：用户说 "Hey Siri 开启游戏模式" / 快捷指令可直接调用
struct OpenGameModeIntent: AppIntent {
    static let title: LocalizedStringResource = "开启游戏模式"
    static let description = IntentDescription(
        "开启 Monologue 游戏模式：强制混音，音乐和游戏音效共存",
        categoryName: "Monologue"
    )

    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: gameModeGroupID)
        defaults?.set(true, forKey: gameModeKey)
        defaults?.set(Date().timeIntervalSince1970, forKey: gameModeKey + ".changedAt")

        #if MAIN_APP
        GameModeManager.shared.enter()
        #else
        if #available(iOS 18, *) {
            ControlCenter.shared.reloadControls(
                ofKind: "zijiu.Monologue.com.control.gamemode"
            )
        }
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName("com.zijiu.Monologue.gamemode.changed" as CFString),
            nil,
            nil,
            true
        )
        #endif

        return .result()
    }
}

/// 独立「关闭」Intent
struct ExitGameModeIntent: AppIntent {
    static let title: LocalizedStringResource = "关闭游戏模式"
    static let description = IntentDescription(
        "关闭 Monologue 游戏模式，恢复原本播放设置",
        categoryName: "Monologue"
    )

    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: gameModeGroupID)
        defaults?.set(false, forKey: gameModeKey)
        defaults?.set(Date().timeIntervalSince1970, forKey: gameModeKey + ".changedAt")

        #if MAIN_APP
        GameModeManager.shared.exit()
        #else
        if #available(iOS 18, *) {
            ControlCenter.shared.reloadControls(
                ofKind: "zijiu.Monologue.com.control.gamemode"
            )
        }
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName("com.zijiu.Monologue.gamemode.changed" as CFString),
            nil,
            nil,
            true
        )
        #endif

        return .result()
    }
}

// MARK: - Siri Shortcuts（语音短语推荐）
//
// 注意：AppShortcutsProvider 每 app 只允许一个。OpenGameModeIntent /
// ExitGameModeIntent / ToggleGameModeIntent 的语音短语已统一合并到
// Sources/Monologue/Managers/MediaIntentHandler.swift 里的
// `MonologueShortcuts`，这里不再单独注册 AppShortcutsProvider。
