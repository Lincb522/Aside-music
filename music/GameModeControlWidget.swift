// GameModeControlWidget.swift
// 游戏模式控制中心开关 —— Widget Extension 专用

import WidgetKit
import SwiftUI

// MARK: - 游戏模式状态 + 当前歌曲标题的复合值

@available(iOS 18, *)
struct GameModeControlValue {
    let isActive: Bool
    /// 当前歌曲标题（最长 24 字）。主 App 在歌曲变化 / 模式切换时写入 AppGroup。
    /// Widget 进程读取即可（无需 URL 请求）
    let currentSongTitle: String?
}

// MARK: - 游戏模式状态 Provider

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

// MARK: - 控制中心 ControlWidget

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

// NOTE: iOS 18 ControlWidgetToggle 不支持自定义「长按」跳转。
// 用户可通过主 App 的游戏模式设置页或 Home Screen Quick Action 进入详细配置。
