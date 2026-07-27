// 游戏模式切换 Intent —— 主 App 和 Widget Extension 均引用此文件

import Foundation
import AppIntents
import WidgetKit

// MARK: - App Group 常量

let gameModeGroupID = "group.zijiu.Monologue.com"
let gameModeKey = "mono_game_mode_enabled"

// MARK: - 切换游戏模式 Intent

/// 在主 App 与控制中心扩展之间同步游戏模式状态，并通知存活的主进程应用副作用。
struct ToggleGameModeIntent: SetValueIntent {
    static let title: LocalizedStringResource = "游戏模式"
    static let description = IntentDescription(
        "切换 Mono 游戏模式（边玩游戏边听歌）",
        categoryName: "Mono"
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
            CFNotificationName("com.zijiu.Mono.gamemode.changed" as CFString),
            nil,
            nil,
            true
        )
        #endif

        return .result()
    }
}
