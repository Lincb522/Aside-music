// SelectableThemeWidget.swift
// Monologue Widget Extension
//
// 「自选主题」小组件：与 13 个固定主题小组件并存，
// 用户长按 → 编辑小组件即可在下拉框里随时切换主题，无需删除重加。

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Theme AppEnum

extension WidgetTheme: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "主题")
    }

    // appintentsmetadataprocessor 在编译期静态提取，此处必须是穷举的
    // 字典字面量（不能由 allCases 动态构造），文案需与 displayName 保持一致。
    static let caseDisplayRepresentations: [WidgetTheme: DisplayRepresentation] = [
        .polaroid: "拍立得",
        .vinyl: "黑胶",
        .poster: "海报",
        .manga: "漫画",
        .magazine: "杂志",
        .aperture: "圆窗唱片",
        .pager: "寻呼机（深色）",
        .pagerLight: "寻呼机（浅色）",
        .radio: "收音机",
        .dashboard: "仪表盘",
        .soundwave: "声波",
        .typewriter: "打字机",
        .lyrics: "歌词",
    ]
}

// MARK: - Configuration Intent

struct NowPlayingThemeIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "选择主题"
    static let description = IntentDescription("选择这个小组件使用的主题")

    @Parameter(title: "主题", default: .polaroid)
    var theme: WidgetTheme
}

// MARK: - Provider

struct SelectableNowPlayingProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry.preview(theme: .polaroid)
    }

    func snapshot(
        for configuration: NowPlayingThemeIntent,
        in context: Context
    ) async -> NowPlayingEntry {
        NowPlayingProvider(theme: configuration.theme).snapshotEntry(in: context)
    }

    func timeline(
        for configuration: NowPlayingThemeIntent,
        in context: Context
    ) async -> Timeline<NowPlayingEntry> {
        NowPlayingProvider(theme: configuration.theme).makeTimeline(in: context)
    }
}

// MARK: - Widget

struct SelectableNowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "zijiu.Monologue.com.widget.nowplaying.selectable",
            intent: NowPlayingThemeIntent.self,
            provider: SelectableNowPlayingProvider()
        ) { entry in
            NowPlayingWidgetView(entry: entry)
        }
        .configurationDisplayName("Mono · 自选主题")
        .description("长按编辑小组件可切换主题")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
