// WidgetTheme.swift
// Monologue Widget Extension

import WidgetKit
import SwiftUI

// MARK: - Widget Theme

// `Sendable` 必须与类型定义同文件声明：SelectableThemeWidget.swift 里的
// AppEnum 一致性要求 Sendable，跨文件补会触发 retroactive conformance 报错。
enum WidgetTheme: String, CaseIterable, Hashable, Sendable {
    case polaroid
    case vinyl
    case poster
    case manga
    case magazine
    case aperture
    case pager
    case pagerLight
    case radio
    case dashboard
    case soundwave
    case typewriter
    case lyrics

    var displayName: String {
        switch self {
        case .polaroid: return "拍立得"
        case .vinyl: return "黑胶"
        case .poster: return "海报"
        case .manga: return "漫画"
        case .magazine: return "杂志"
        case .aperture: return "圆窗唱片"
        case .pager: return "寻呼机（深色）"
        case .pagerLight: return "寻呼机（浅色）"
        case .radio: return "收音机"
        case .dashboard: return "仪表盘"
        case .soundwave: return "声波"
        case .typewriter: return "打字机"
        case .lyrics: return "歌词"
        }
    }

    var widgetKind: String {
        // Keep the original kind for Polaroid so existing installations retain
        // one valid widget after migrating away from the shared theme intent.
        if self == .polaroid {
            return "zijiu.Monologue.com.widget.nowplaying"
        }
        return "zijiu.Monologue.com.widget.nowplaying.\(rawValue)"
    }

    var configurationDisplayName: String {
        "Mono · \(displayName)"
    }

    var configurationDescription: String {
        "显示\(displayName)主题的当前歌曲与播放控制"
    }

    var supportedFamilies: [WidgetFamily] {
        let homeScreenFamilies: [WidgetFamily] = [
            .systemSmall,
            .systemMedium,
            .systemLarge,
        ]
        if self == .polaroid {
            return homeScreenFamilies + [
                .accessoryCircular,
                .accessoryRectangular,
            ]
        }
        return homeScreenFamilies
    }
}
