// musicBundle.swift
// Widget Extension 入口

import WidgetKit
import SwiftUI

@main
struct musicBundle: WidgetBundle {
    var body: some Widget {
        musicLiveActivity()
        // 占位 Widget（WidgetKit extension 至少需要一个常规 Widget）
        musicPlaceholderWidget()
    }
}

/// 最小占位 Widget，不会出现在添加小组件列表中
struct musicPlaceholderWidget: Widget {
    let kind = "zijiu.Aside.com.music.placeholder"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { _ in
            EmptyView()
        }
        .configurationDisplayName("Aside Music")
        .supportedFamilies([])  // 空数组 = 不出现在小组件选择器中
    }
}

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: .now)
    }
    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: .now)], policy: .never))
    }
}
