// MusicControlWidget.swift
// 控制中心快捷操作 + 主屏幕小组件

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - 播放控制 Intent

struct TogglePlaybackIntent: AppIntent {
    static var title: LocalizedStringResource = "播放/暂停"
    
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.zijiu.Aside.com")
        defaults?.set("togglePlay_\(Date().timeIntervalSince1970)", forKey: "widgetCommand")
        return .result()
    }
}

struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "下一首"
    
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.zijiu.Aside.com")
        defaults?.set("next_\(Date().timeIntervalSince1970)", forKey: "widgetCommand")
        return .result()
    }
}

struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "上一首"
    
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.zijiu.Aside.com")
        defaults?.set("previous_\(Date().timeIntervalSince1970)", forKey: "widgetCommand")
        return .result()
    }
}

// MARK: - 控制中心 ControlWidget（iOS 18+）

struct PlayPauseControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.aside.control.playpause") {
            ControlWidgetButton(action: TogglePlaybackIntent()) {
                Label("播放/暂停", systemImage: "play.pause.fill")
            }
        }
        .displayName("Aside 播放/暂停")
    }
}

struct NextTrackControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.aside.control.next") {
            ControlWidgetButton(action: NextTrackIntent()) {
                Label("下一首", systemImage: "forward.fill")
            }
        }
        .displayName("Aside 下一首")
    }
}

// MARK: - 主屏幕小组件

struct NowPlayingWidget: Widget {
    let kind = "com.aside.widget.nowplaying"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NowPlayingProvider()) { entry in
            NowPlayingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("正在播放")
        .description("显示当前播放的歌曲信息")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Widget Entry & Provider

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let songName: String
    let artistName: String
    let isPlaying: Bool
    
    static var placeholder: NowPlayingEntry {
        NowPlayingEntry(date: .now, songName: "Aside Music", artistName: "发现好音乐", isPlaying: false)
    }
}

struct NowPlayingProvider: TimelineProvider {
    private let groupDefaults = UserDefaults(suiteName: "group.zijiu.Aside.com")
    
    func placeholder(in context: Context) -> NowPlayingEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        completion(currentEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
    
    private func currentEntry() -> NowPlayingEntry {
        let songName = groupDefaults?.string(forKey: "widget_songName") ?? ""
        let artistName = groupDefaults?.string(forKey: "widget_artistName") ?? ""
        let isPlaying = groupDefaults?.bool(forKey: "widget_isPlaying") ?? false
        
        if songName.isEmpty {
            return .placeholder
        }
        return NowPlayingEntry(date: .now, songName: songName, artistName: artistName, isPlaying: isPlaying)
    }
}

// MARK: - Widget Views

struct NowPlayingWidgetView: View {
    let entry: NowPlayingEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .accessoryCircular:
            circularWidget
        case .accessoryRectangular:
            rectangularWidget
        default:
            smallWidget
        }
    }
    
    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: entry.isPlaying ? "waveform" : "music.note")
                .font(.system(size: 24))
                .foregroundStyle(.tint)
                .symbolEffect(.variableColor.iterative, isActive: entry.isPlaying)
            
            Spacer()
            
            Text(entry.songName)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(2)
            
            Text(entry.artistName)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var mediumWidget: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: entry.isPlaying ? "waveform" : "music.note")
                    .font(.system(size: 20))
                    .foregroundStyle(.tint)
                    .symbolEffect(.variableColor.iterative, isActive: entry.isPlaying)
                
                Spacer()
                
                Text(entry.songName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                
                Text(entry.artistName)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Spacer()
                
                Button(intent: PreviousTrackIntent()) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16))
                }
                .tint(.primary)
                
                Button(intent: TogglePlaybackIntent()) {
                    Image(systemName: entry.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .contentTransition(.symbolEffect(.replace))
                }
                .tint(.primary)
                
                Button(intent: NextTrackIntent()) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                }
                .tint(.primary)
                
                Spacer()
            }
        }
    }
    
    private var circularWidget: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18))
                .contentTransition(.symbolEffect(.replace))
        }
        .widgetURL(URL(string: "aside://player"))
    }
    
    private var rectangularWidget: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.isPlaying ? "waveform" : "music.note")
                .font(.system(size: 16))
                .symbolEffect(.variableColor.iterative, isActive: entry.isPlaying)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.songName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(entry.artistName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "aside://player"))
    }
}
