// 游戏模式控制中心开关 —— Widget Extension 专用

import WidgetKit
import SwiftUI

// MARK: - 游戏模式状态 + 当前歌曲标题的复合值

/// 控制中心游戏模式开关所需的只读快照。
@available(iOS 18, *)
struct GameModeControlValue {
    let isActive: Bool
    /// 当前歌曲标题（最长 24 字）。主 App 在歌曲变化 / 模式切换时写入 AppGroup。
    /// Widget 进程读取即可（无需 URL 请求）
    let currentSongTitle: String?
}

// MARK: - 游戏模式状态提供器

/// 从 App Group 读取游戏模式与当前曲目，不在扩展进程发起网络请求。
@available(iOS 18, *)
struct GameModeValueProvider: ControlValueProvider {
    var previewValue: GameModeControlValue {
        GameModeControlValue(isActive: false, currentSongTitle: nil)
    }

    func currentValue() async throws -> GameModeControlValue {
        let defaults = UserDefaults(suiteName: gameModeGroupID)
        let active = defaults?.bool(forKey: gameModeKey) ?? false

        // 读取主 App 写入的 `widget_songName`（与 Home Screen Widget 共用）
        // 若读不到（App 从未播过）→ nil，label 回退默认
        let rawTitle = defaults?.string(forKey: "widget_songName")
        let trimmed = rawTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title: String? = (trimmed?.isEmpty == false) ? trimmed : nil

        return GameModeControlValue(isActive: active, currentSongTitle: title)
    }
}

// MARK: - 控制中心组件

/// iOS 18 控制中心中的游戏模式开关。
@available(iOS 18, *)
struct GameModeControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "zijiu.Monologue.com.control.gamemode",
            provider: GameModeValueProvider()
        ) { value in
            ControlWidgetToggle(
                value.isActive ? "游戏模式 · 开" : "游戏模式",
                isOn: value.isActive,
                action: ToggleGameModeIntent()
            ) { isActive in
                // iOS 18 的 ControlWidgetToggle 只允许 Label 样式，
                // 通过 title + systemImage 的组合展示歌名（若无歌 → 默认标题）
                let displayTitle: String = {
                    if isActive, let t = value.currentSongTitle, !t.isEmpty {
                        // 进入游戏模式且主 App 有当前歌 → 显示歌名
                        return t
                    }
                    return isActive ? "游戏模式" : "游戏模式"
                }()
                Label(
                    displayTitle,
                    systemImage: isActive ? "gamecontroller.fill" : "gamecontroller"
                )
            }
        }
        .displayName("Mono 游戏模式")
        .description("边玩游戏边听歌，音乐与游戏音效共存")
    }
}

// ControlWidgetToggle 不提供自定义长按跳转，详细配置仍由主 App 承载。
