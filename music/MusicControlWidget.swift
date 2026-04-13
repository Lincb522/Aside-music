// MusicControlWidget.swift
// Monologue 桌面小组件 + 控制中心快捷操作

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - App Group

private let appGroupID = "group.zijiu.Monologue.com"

// MARK: - 控制中心 ControlWidget

@available(iOS 18, *)
struct PlayPauseControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "zijiu.Monologue.com.control.playpause") {
            ControlWidgetButton(action: TogglePlaybackIntent()) {
                Label("播放/暂停", systemImage: "play.pause.fill")
            }
        }
        .displayName("Monologue 播放/暂停")
    }
}

@available(iOS 18, *)
struct NextTrackControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "zijiu.Monologue.com.control.next") {
            ControlWidgetButton(action: NextTrackIntent()) {
                Label("下一首", systemImage: "forward.fill")
            }
        }
        .displayName("Monologue 下一首")
    }
}

// MARK: - Widget Theme

enum WidgetTheme: String, CaseIterable, AppEnum {
    case polaroid
    case vinyl
    case poster
    case manga
    case magazine
    case pager
    case pagerLight

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "主题")
    static let caseDisplayRepresentations: [WidgetTheme: DisplayRepresentation] = [
        .polaroid:    "拍立得",
        .vinyl:       "黑胶",
        .poster:      "海报",
        .manga:       "漫画",
        .magazine:    "杂志",
        .pager:       "寻呼机(深色)",
        .pagerLight:  "寻呼机(浅色)",
    ]
}

// MARK: - Theme Config Intent

struct ThemeConfigIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "选择主题"
    static let description = IntentDescription("选择小组件的视觉主题")

    @Parameter(title: "主题", default: .polaroid)
    var theme: WidgetTheme
}

// MARK: - Widget Definition

struct NowPlayingWidget: Widget {
    let kind = "zijiu.Monologue.com.widget.nowplaying"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ThemeConfigIntent.self, provider: NowPlayingProvider()) { entry in
            NowPlayingWidgetView(entry: entry)
        }
        .configurationDisplayName("正在播放")
        .description("显示当前播放的歌曲与快捷控制")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

// MARK: - Entry & Provider

struct NowPlayingEntry: TimelineEntry {
    var date: Date
    let songName: String
    let artistName: String
    let albumName: String
    let playbackState: PlaybackSurfaceState
    let coverImageData: Data?
    let theme: WidgetTheme
    let dominantRGB: [CGFloat]
    let secondaryRGB: [CGFloat]
    let coverIsDark: Bool
    let sourceName: String
    let qualityText: String
    let playModeText: String
    let queueIndex: Int
    let queueCount: Int
    let tempoBPM: Int?
    let tempoIsAnalyzing: Bool
    let lyricText: String

    var isEmpty: Bool { songName.isEmpty }

    var isPlaying: Bool {
        playbackState.isPlaying
    }

    var isLoading: Bool {
        playbackState.isLoading
    }

    var controlSymbolName: String {
        switch playbackState {
        case .loading:
            return "hourglass"
        case .playing:
            return "pause.fill"
        case .paused, .idle:
            return "play.fill"
        }
    }

    var statusSymbolName: String {
        switch playbackState {
        case .loading:
            return "hourglass"
        case .playing:
            return "waveform"
        case .paused, .idle:
            return "music.note"
        }
    }

    var dominantColor: Color {
        guard dominantRGB.count >= 3 else { return Color(hex: "1E1B4B") }
        return Color(.sRGB, red: dominantRGB[0], green: dominantRGB[1], blue: dominantRGB[2])
    }

    var secondaryColor: Color {
        guard secondaryRGB.count >= 3 else { return Color(hex: "0F0F23") }
        return Color(.sRGB, red: secondaryRGB[0], green: secondaryRGB[1], blue: secondaryRGB[2])
    }

    static func preview(theme: WidgetTheme) -> NowPlayingEntry {
        switch theme {
        case .polaroid:
            return NowPlayingEntry(
                date: .now,
                songName: "纸飞机",
                artistName: "Monologue",
                albumName: "Polaroid Preview",
                playbackState: .playing,
                coverImageData: nil,
                theme: theme,
                dominantRGB: [0.93, 0.74, 0.33],
                secondaryRGB: [0.95, 0.94, 0.90],
                coverIsDark: false,
                sourceName: "ncm",
                qualityText: "HQ",
                playModeText: "顺序",
                queueIndex: 3,
                queueCount: 12,
                tempoBPM: 112,
                tempoIsAnalyzing: false,
                lyricText: ""
            )
        case .vinyl:
            return NowPlayingEntry(
                date: .now,
                songName: "Midnight Drive",
                artistName: "Monologue",
                albumName: "Vinyl Preview",
                playbackState: .playing,
                coverImageData: nil,
                theme: theme,
                dominantRGB: [0.78, 0.52, 0.28],
                secondaryRGB: [0.20, 0.13, 0.09],
                coverIsDark: true,
                sourceName: "qcm",
                qualityText: "320K",
                playModeText: "顺序",
                queueIndex: 2,
                queueCount: 9,
                tempoBPM: 126,
                tempoIsAnalyzing: false,
                lyricText: ""
            )
        case .pager:
            return NowPlayingEntry(
                date: .now,
                songName: "READY...",
                artistName: "M O T O P A G E R",
                albumName: "Preview",
                playbackState: .playing,
                coverImageData: nil,
                theme: theme,
                dominantRGB: [0.99, 0.64, 0.07],
                secondaryRGB: [0.12, 0.10, 0.08],
                coverIsDark: true,
                sourceName: "ncm",
                qualityText: "HQ",
                playModeText: "顺序",
                queueIndex: 1,
                queueCount: 8,
                tempoBPM: 96,
                tempoIsAnalyzing: false,
                lyricText: "PRINTING..."
            )
        default:
            let isDark = [.vinyl, .poster].contains(theme)
            return NowPlayingEntry(
                date: .now,
                songName: "Midnight Drive",
                artistName: "Monologue",
                albumName: "Preview",
                playbackState: .playing,
                coverImageData: nil,
                theme: theme,
                dominantRGB: isDark ? [0.65, 0.42, 0.22] : [0.93, 0.74, 0.33],
                secondaryRGB: isDark ? [0.15, 0.10, 0.06] : [0.95, 0.94, 0.90],
                coverIsDark: isDark,
                sourceName: "ncm",
                qualityText: "HQ",
                playModeText: "顺序",
                queueIndex: 3,
                queueCount: 12,
                tempoBPM: 120,
                tempoIsAnalyzing: false,
                lyricText: "在这寂静的夜里"
            )
        }
    }

    static let placeholder = preview(theme: .polaroid)

}

struct NowPlayingProvider: AppIntentTimelineProvider {
    private let groupDefaults = UserDefaults(suiteName: appGroupID)

    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry.preview(theme: cachedTheme())
    }

    func snapshot(for configuration: ThemeConfigIntent, in context: Context) async -> NowPlayingEntry {
        let entry = currentEntry(theme: configuration.theme)
        if context.isPreview || entry.isEmpty {
            return NowPlayingEntry.preview(theme: configuration.theme)
        }
        return entry
    }

    func timeline(for configuration: ThemeConfigIntent, in context: Context) async -> Timeline<NowPlayingEntry> {
        let base = currentEntry(theme: configuration.theme)

        if base.isPlaying, configuration.theme == .vinyl {
            let interval: TimeInterval = 0.5
            let totalDuration: TimeInterval = 600
            let count = Int(totalDuration / interval)
            var entries: [NowPlayingEntry] = []
            for i in 0..<count {
                var e = base
                e.date = Date.now.addingTimeInterval(Double(i) * interval)
                entries.append(e)
            }
            return Timeline(entries: entries, policy: .after(Date.now.addingTimeInterval(totalDuration)))
        }

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: base.date) ?? base.date.addingTimeInterval(300)
        return Timeline(entries: [base], policy: .after(nextUpdate))
    }

    private func currentEntry(theme: WidgetTheme) -> NowPlayingEntry {
        groupDefaults?.set(theme.rawValue, forKey: "widget_cachedTheme")
        let songName = groupDefaults?.string(forKey: "widget_songName") ?? ""
        let artistName = groupDefaults?.string(forKey: "widget_artistName") ?? ""
        let albumName = groupDefaults?.string(forKey: "widget_album_name") ?? ""
        let playbackState: PlaybackSurfaceState = {
            if let raw = groupDefaults?.string(forKey: "widget_playbackState"),
               let state = PlaybackSurfaceState(rawValue: raw) {
                return state
            }
            return (groupDefaults?.bool(forKey: "widget_isPlaying") ?? false) ? .playing : .paused
        }()

        let dominantRGB = (groupDefaults?.array(forKey: "widget_dominantRGB") as? [CGFloat]) ?? []
        let secondaryRGB = (groupDefaults?.array(forKey: "widget_secondaryRGB") as? [CGFloat]) ?? []
        let coverIsDark = groupDefaults?.bool(forKey: "widget_coverIsDark") ?? true
        let sourceName = groupDefaults?.string(forKey: "widget_source") ?? ""
        let qualityText = groupDefaults?.string(forKey: "widget_quality") ?? ""
        let playModeText = groupDefaults?.string(forKey: "widget_play_mode") ?? "顺序"
        let queueIndex = groupDefaults?.integer(forKey: "widget_queue_index") ?? 0
        let queueCount = groupDefaults?.integer(forKey: "widget_queue_count") ?? 0
        let tempoBPM = groupDefaults?.object(forKey: "widget_tempo_bpm") as? Int
        let tempoIsAnalyzing = groupDefaults?.bool(forKey: "widget_tempo_analyzing") ?? false

        var coverData: Data?
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            coverData = try? Data(contentsOf: url.appendingPathComponent("widget_cover.jpg"))
        }

        if songName.isEmpty {
            return NowPlayingEntry(
                date: .now, songName: "", artistName: "", albumName: "", playbackState: .idle,
                coverImageData: nil, theme: theme,
                dominantRGB: [], secondaryRGB: [], coverIsDark: true,
                sourceName: "", qualityText: "", playModeText: "顺序", queueIndex: 0, queueCount: 0,
                tempoBPM: nil, tempoIsAnalyzing: false, lyricText: ""
            )
        }

        return NowPlayingEntry(
            date: .now, songName: songName, artistName: artistName, albumName: albumName,
            playbackState: playbackState, coverImageData: coverData, theme: theme,
            dominantRGB: dominantRGB, secondaryRGB: secondaryRGB, coverIsDark: coverIsDark,
            sourceName: sourceName, qualityText: qualityText, playModeText: playModeText,
            queueIndex: queueIndex, queueCount: queueCount,
            tempoBPM: tempoBPM, tempoIsAnalyzing: tempoIsAnalyzing,
            lyricText: groupDefaults?.string(forKey: "widget_lyricText") ?? ""
        )
    }

    private func cachedTheme() -> WidgetTheme {
        guard let raw = groupDefaults?.string(forKey: "widget_cachedTheme"),
              let t = WidgetTheme(rawValue: raw) else { return .polaroid }
        return t
    }
}

// MARK: - Shared Components

private struct CoverImage: View {
    let data: Data?
    let radius: CGFloat

    var body: some View {
        if let data, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color(white: 0.95))
                .overlay(Image(systemName: "music.note").font(.title).foregroundStyle(.gray))
        }
    }
}

private struct GreenSquiggle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width; let h = rect.height
        path.move(to: CGPoint(x: 0, y: h/2))
        path.addQuadCurve(to: CGPoint(x: w/4, y: h/2), control: CGPoint(x: w/8, y: -h/2))
        path.addQuadCurve(to: CGPoint(x: 2*w/4, y: h/2), control: CGPoint(x: 3*w/8, y: 1.5*h))
        path.addQuadCurve(to: CGPoint(x: 3*w/4, y: h/2), control: CGPoint(x: 5*w/8, y: -h/2))
        path.addQuadCurve(to: CGPoint(x: w, y: h/2), control: CGPoint(x: 7*w/8, y: 1.5*h))
        return path
    }
}

// MARK: - Widget Views

private let accentYellow = Color(hex: "E5A849")
private let accentGreen = Color(hex: "27AE60")

struct NowPlayingWidgetView: View {
    let entry: NowPlayingEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:    circularWidget
            case .accessoryRectangular: rectangularWidget
            default:                    themedBody
            }
        }
        .containerBackground(for: .widget) {
            themeBackground
        }
    }

    @ViewBuilder
    private var themedBody: some View {
        switch entry.theme {
        case .polaroid:
            PolaroidTheme(entry: entry, family: family)
        case .vinyl:
            VinylTheme(entry: entry, family: family)
        case .poster:
            PosterWidgetTheme(entry: entry, family: family)
        case .manga:
            MangaTheme(entry: entry, family: family)
        case .magazine:
            MagazineTheme(entry: entry, family: family)
        case .pager:
            PagerWidgetTheme(entry: entry, family: family, isLight: false)
        case .pagerLight:
            PagerWidgetTheme(entry: entry, family: family, isLight: true)
        }
    }

    @ViewBuilder
    private var themeBackground: some View {
        switch entry.theme {
        case .polaroid:
            Color(hex: "F7F6F3")
                .ignoresSafeArea()
        case .vinyl:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "030407"),
                        Color(hex: "0B0F15"),
                        Color(hex: "05070B")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.035),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 220
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        case .poster:
            Color(hex: "0A0A0C").ignoresSafeArea()
        case .manga:
            Color(hex: "FFF0F5").ignoresSafeArea()
        case .magazine:
            Color(hex: "F4F1EA").ignoresSafeArea()
        case .pager, .pagerLight:
            Color.clear.ignoresSafeArea()
        }
    }

    // MARK: - Lock Screen
    private var circularWidget: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: entry.controlSymbolName)
                .font(.system(size: 18))
                .foregroundStyle(.primary)
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    private var rectangularWidget: some View {
        HStack(spacing: 8) {
            if entry.isPlaying {
                PlaybackWave(isActive: true, barCount: 3, color: .primary, height: 14)
                    .frame(width: 14)
            } else {
                Image(systemName: entry.statusSymbolName)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isEmpty ? "未在播放" : entry.songName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(entry.isEmpty ? "暂无歌曲信息" : entry.artistName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "monologue://player"))
    }
}

// MARK: - 1. Polaroid Theme (拍立得)

private struct PolaroidTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    private let inkBlack = Color(hex: "1A1A1A")
    private let inkGray = Color(hex: "777777")

    private var displaySongName: String {
        entry.isEmpty ? "未在播放" : entry.songName
    }

    private var displayArtistName: String {
        entry.isEmpty ? "暂无歌曲信息" : entry.artistName
    }

    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        case .systemLarge:  largeLayout
        default:            smallLayout
        }
    }

    // MARK: - Small 竖版拍立得

    private var smallLayout: some View {
        GeometryReader { geo in
            let frameSide: CGFloat = 10
            let frameTop: CGFloat = 8
            let infoH: CGFloat = 48
            let coverRadius: CGFloat = 12
            let coverH: CGFloat = geo.size.height - frameTop - infoH

            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    CoverImage(data: entry.coverImageData, radius: coverRadius)

                    if !entry.isEmpty {
                        LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .center, endPoint: .bottom)
                            .frame(height: 46)
                            .clipShape(UnevenRoundedRectangle(
                                topLeadingRadius: 0, bottomLeadingRadius: coverRadius,
                                bottomTrailingRadius: coverRadius, topTrailingRadius: 0, style: .continuous
                            ))

                        HStack(spacing: 26) {
                            Button(intent: PreviousTrackIntent()) {
                                Image(systemName: "backward.fill").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.75))
                            }.buttonStyle(.plain)
                            Button(intent: TogglePlaybackIntent()) {
                                Image(systemName: entry.controlSymbolName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .contentTransition(.symbolEffect(.replace))
                            }.buttonStyle(.plain)
                            Button(intent: NextTrackIntent()) {
                                Image(systemName: "forward.fill").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.75))
                            }.buttonStyle(.plain)
                        }
                        .padding(.bottom, 22)
                    }
                }
                .frame(height: coverH)
                .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                .padding(.horizontal, frameSide)
                .padding(.top, frameTop)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill").font(.system(size: 11)).foregroundStyle(inkBlack)
                            Text(displaySongName)
                                .font(.system(size: 13, weight: .heavy, design: .serif)).foregroundStyle(inkBlack).lineLimit(1)
                                .contentTransition(.interpolate)
                        }
                        ZStack(alignment: .leading) {
                            Text("playing now")
                                .font(.custom("Snell Roundhand", size: 16)).foregroundStyle(accentYellow.opacity(0.7)).offset(x: 2, y: -3)
                            Text(displayArtistName)
                                .font(.system(size: 9, weight: .medium)).foregroundStyle(inkGray).lineLimit(1).padding(.leading, 2)
                        }
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(dateString).font(.system(size: 9, weight: .medium)).foregroundStyle(inkGray)
                        Text(entry.date, style: .time).font(.system(size: 12, weight: .bold)).foregroundStyle(inkBlack)
                        GreenSquiggle().stroke(accentGreen, style: StrokeStyle(lineWidth: 1.5, lineCap: .round)).frame(width: 20, height: 3)
                    }
                }
                .frame(height: infoH)
                .padding(.horizontal, frameSide + 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Large 大尺寸拍立得（独立设计）

    private var largeLayout: some View {
        GeometryReader { geo in
            let frameSide: CGFloat = 16
            let frameTop: CGFloat = 14
            let infoH: CGFloat = 120
            let coverRadius: CGFloat = 18
            let coverH: CGFloat = geo.size.height - frameTop - infoH

            VStack(spacing: 0) {
                // 大封面 — 无控制按钮叠加，保持干净
                CoverImage(data: entry.coverImageData, radius: coverRadius)
                    .frame(height: coverH)
                    .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                    .padding(.horizontal, frameSide)
                    .padding(.top, frameTop)

                // 底部信息区 — 拍立得经典宽白边
                VStack(spacing: 0) {
                    // 歌曲信息行
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 5) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 17))
                                    .foregroundStyle(inkBlack)
                                Text(displaySongName)
                                    .font(.system(size: 20, weight: .heavy, design: .serif))
                                    .foregroundStyle(inkBlack)
                                    .lineLimit(1)
                                    .contentTransition(.interpolate)
                            }

                            ZStack(alignment: .leading) {
                                Text("playing now")
                                    .font(.custom("Snell Roundhand", size: 28))
                                    .foregroundStyle(accentYellow.opacity(0.7))
                                    .offset(x: 2, y: -6)

                                Text(displayArtistName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(inkGray)
                                    .lineLimit(1)
                                    .padding(.leading, 2)
                            }
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(dateString)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(inkGray)
                            Text(entry.date, style: .time)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(inkBlack)
                            GreenSquiggle()
                                .stroke(accentGreen, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .frame(width: 32, height: 4)
                        }
                    }

                    Spacer(minLength: 0)

                    // 播放控件行 — 独立于封面，居中展示
                    if !entry.isEmpty {
                        HStack(spacing: 32) {
                            Button(intent: PreviousTrackIntent()) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(inkBlack.opacity(0.5))
                            }.buttonStyle(.plain)

                            Button(intent: TogglePlaybackIntent()) {
                                ZStack {
                                    Circle()
                                        .fill(inkBlack)
                                        .frame(width: 40, height: 40)
                                    Image(systemName: entry.controlSymbolName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color(hex: "F7F6F3"))
                                        .contentTransition(.symbolEffect(.replace))
                                }
                            }.buttonStyle(.plain)

                            Button(intent: NextTrackIntent()) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(inkBlack.opacity(0.5))
                            }.buttonStyle(.plain)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .frame(height: infoH)
                .padding(.horizontal, frameSide + 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Medium 横版拍立得

    private var mediumLayout: some View {
        GeometryReader { geo in
            let framePad: CGFloat = 10
            let coverRadius: CGFloat = 12
            let coverSize = geo.size.height - framePad * 2

            HStack(spacing: 0) {
                // 左侧：封面
                CoverImage(data: entry.coverImageData, radius: coverRadius)
                    .frame(width: coverSize, height: coverSize)
                    .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                    .padding(.leading, framePad)
                    .padding(.vertical, framePad)

                // 右侧
                VStack(alignment: .leading, spacing: 6) {
                    // 手写体装饰
                    Text("playing now ♪")
                        .font(.custom("Snell Roundhand", size: 24))
                        .foregroundStyle(accentYellow.opacity(0.65))

                    // 歌名
                    Text(displaySongName)
                        .font(.system(size: 18, weight: .heavy, design: .serif))
                        .foregroundStyle(inkBlack)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.interpolate)

                    // 歌手
                    HStack(spacing: 4) {
                        Image(systemName: "music.mic")
                            .font(.system(size: 10))
                            .foregroundStyle(inkGray)
                        Text(displayArtistName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(inkGray)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    // 控件行
                    if !entry.isEmpty {
                        HStack(spacing: 18) {
                            Button(intent: PreviousTrackIntent()) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(inkBlack.opacity(0.4))
                            }.buttonStyle(.plain)

                            Button(intent: TogglePlaybackIntent()) {
                                ZStack {
                                    Circle()
                                        .fill(inkBlack)
                                        .frame(width: 32, height: 32)
                                    Image(systemName: entry.controlSymbolName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color(hex: "F7F6F3"))
                                        .contentTransition(.symbolEffect(.replace))
                                }
                            }.buttonStyle(.plain)

                            Button(intent: NextTrackIntent()) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(inkBlack.opacity(0.4))
                            }.buttonStyle(.plain)

                            Spacer(minLength: 4)

                            HStack(spacing: 4) {
                                Text(dateString)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(inkGray)
                                Text(entry.date, style: .time)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(inkBlack)
                                GreenSquiggle()
                                    .stroke(accentGreen, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                                    .frame(width: 16, height: 3)
                            }
                        }
                    } else {
                        HStack(alignment: .bottom, spacing: 5) {
                            Text(dateString)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(inkGray)
                            Spacer()
                            Text(entry.date, style: .time)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(inkBlack)
                        }
                    }
                }
                .padding(.leading, 14)
                .padding(.trailing, 12)
                .padding(.vertical, framePad)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    private var dateString: String {
        let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: entry.date)
    }
}

// MARK: - 2. Vinyl Theme (黑胶)

private struct VinylTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily
    @Environment(\.widgetContentMargins) private var widgetContentMargins

    private let shellColor = Color(hex: "0F1218")
    private let panelColor = Color(hex: "171B24")
    private let lineColor = Color.white.opacity(0.09)
    private let metalColor = Color(hex: "D9DDE4")
    private let dimTextColor = Color.white.opacity(0.66)

    private var accentColor: Color {
        entry.isEmpty ? Color(hex: "C89B5B") : entry.dominantColor
    }

    private var accentSecondaryColor: Color {
        entry.isEmpty ? Color(hex: "745738") : entry.secondaryColor
    }

    private var isActivePlayback: Bool {
        entry.isPlaying || entry.isLoading
    }

    private var glossAngle: Double {
        let signature = [
            entry.songName,
            entry.artistName,
            entry.albumName,
            entry.sourceName
        ].joined(separator: "|")
        let hash = signature.unicodeScalars.reduce(0) { partial, scalar in
            (partial * 33 + Int(scalar.value)) % 360
        }
        return Double((hash + 28) % 360)
    }

    private struct BackgroundCoverageProfile {
        let heroGlowScale: CGFloat
        let heroGlowOffsetX: CGFloat
        let heroGlowOffsetY: CGFloat
        let ringScale: CGFloat
        let ringOffsetX: CGFloat
        let ringOffsetY: CGFloat
        let innerRingScale: CGFloat
        let accentCloudScale: CGFloat
        let accentCloudOffsetX: CGFloat
        let accentCloudOffsetY: CGFloat
        let guideWidthRatio: CGFloat
        let guideOffsetX: CGFloat
        let guideOffsetY: CGFloat
        let sheenWidthRatio: CGFloat
        let sheenHeightRatio: CGFloat
        let sheenOffsetX: CGFloat
        let sheenOffsetY: CGFloat
    }

    private var backgroundCoverageProfile: BackgroundCoverageProfile {
        switch family {
        case .systemSmall:
            return BackgroundCoverageProfile(
                heroGlowScale: 1.12,
                heroGlowOffsetX: 0.20,
                heroGlowOffsetY: -0.22,
                ringScale: 1.00,
                ringOffsetX: 0.18,
                ringOffsetY: -0.12,
                innerRingScale: 0.74,
                accentCloudScale: 0.52,
                accentCloudOffsetX: -0.18,
                accentCloudOffsetY: 0.16,
                guideWidthRatio: 0.24,
                guideOffsetX: -0.18,
                guideOffsetY: 0.24,
                sheenWidthRatio: 0.72,
                sheenHeightRatio: 0.20,
                sheenOffsetX: -0.08,
                sheenOffsetY: -0.28
            )
        case .systemMedium:
            return BackgroundCoverageProfile(
                heroGlowScale: 1.34,
                heroGlowOffsetX: 0.26,
                heroGlowOffsetY: -0.18,
                ringScale: 1.28,
                ringOffsetX: 0.24,
                ringOffsetY: -0.08,
                innerRingScale: 0.94,
                accentCloudScale: 0.62,
                accentCloudOffsetX: -0.24,
                accentCloudOffsetY: 0.18,
                guideWidthRatio: 0.30,
                guideOffsetX: -0.20,
                guideOffsetY: 0.22,
                sheenWidthRatio: 0.78,
                sheenHeightRatio: 0.18,
                sheenOffsetX: -0.05,
                sheenOffsetY: -0.26
            )
        case .systemLarge:
            return BackgroundCoverageProfile(
                heroGlowScale: 1.58,
                heroGlowOffsetX: 0.30,
                heroGlowOffsetY: -0.14,
                ringScale: 1.52,
                ringOffsetX: 0.28,
                ringOffsetY: -0.04,
                innerRingScale: 1.10,
                accentCloudScale: 0.72,
                accentCloudOffsetX: -0.28,
                accentCloudOffsetY: 0.20,
                guideWidthRatio: 0.36,
                guideOffsetX: -0.22,
                guideOffsetY: 0.20,
                sheenWidthRatio: 0.84,
                sheenHeightRatio: 0.16,
                sheenOffsetX: -0.02,
                sheenOffsetY: -0.24
            )
        default:
            return BackgroundCoverageProfile(
                heroGlowScale: 1.12,
                heroGlowOffsetX: 0.20,
                heroGlowOffsetY: -0.22,
                ringScale: 1.00,
                ringOffsetX: 0.18,
                ringOffsetY: -0.12,
                innerRingScale: 0.74,
                accentCloudScale: 0.52,
                accentCloudOffsetX: -0.18,
                accentCloudOffsetY: 0.16,
                guideWidthRatio: 0.24,
                guideOffsetX: -0.18,
                guideOffsetY: 0.24,
                sheenWidthRatio: 0.72,
                sheenHeightRatio: 0.20,
                sheenOffsetX: -0.08,
                sheenOffsetY: -0.28
            )
        }
    }

    private var statusTitle: String {
        switch entry.playbackState {
        case .loading:
            return "缓冲中"
        case .playing:
            return "播放中"
        case .paused:
            return "已暂停"
        case .idle:
            return "未播放"
        }
    }

    private var tempoText: String {
        if let tempoBPM = entry.tempoBPM, tempoBPM > 0 {
            return "\(tempoBPM) BPM"
        }

        if entry.tempoIsAnalyzing {
            return "BPM ..."
        }

        return entry.isEmpty ? "BPM --" : "BPM --"
    }

    private var sourceText: String {
        if entry.isEmpty {
            return "未播放"
        }

        return entry.sourceName.isEmpty ? "未知来源" : entry.sourceName
    }

    private var smallSourceText: String {
        guard !entry.isEmpty else { return "-" }

        let normalizedSource = entry.sourceName.uppercased()
        if normalizedSource.contains("QQ") {
            return "Q"
        }
        if normalizedSource.contains("NETEASE") {
            return "N"
        }

        return String(entry.sourceName.prefix(1)).uppercased()
    }

    private var qualityDisplayText: String {
        entry.qualityText.isEmpty ? "--" : entry.qualityText
    }

    private var queueText: String {
        guard entry.queueIndex > 0, entry.queueCount > 0 else { return "--/--" }
        return "\(entry.queueIndex)/\(entry.queueCount)"
    }

    private var displayAlbumName: String {
        if entry.isEmpty {
            return "暂无专辑"
        }

        return entry.albumName.isEmpty ? "专辑信息缺失" : entry.albumName
    }

    private var playModeDisplayText: String {
        entry.playModeText.isEmpty ? "--" : entry.playModeText
    }

    private var displaySongName: String {
        entry.isEmpty ? "未在播放" : entry.songName
    }

    private var displayArtistName: String {
        entry.isEmpty ? "暂无歌曲信息" : entry.artistName
    }

    private var contentInsets: EdgeInsets {
        let extraHorizontal: CGFloat
        let extraTop: CGFloat
        let extraBottom: CGFloat

        switch family {
        case .systemSmall:
            extraHorizontal = 8
            extraTop = 8
            extraBottom = 8
        case .systemMedium:
            extraHorizontal = 11
            extraTop = 14
            extraBottom = 15
        case .systemLarge:
            extraHorizontal = 12
            extraTop = 12
            extraBottom = 15
        default:
            extraHorizontal = 8
            extraTop = 8
            extraBottom = 8
        }

        return EdgeInsets(
            top: widgetContentMargins.top + extraTop,
            leading: widgetContentMargins.leading + extraHorizontal,
            bottom: widgetContentMargins.bottom + extraBottom,
            trailing: widgetContentMargins.trailing + extraHorizontal
        )
    }

    var body: some View {
        switch family {
        case .systemMedium:
            mediumLayout(animationDate: entry.date)
        case .systemLarge:
            largeLayout(animationDate: entry.date)
        default:
            smallLayout(animationDate: entry.date)
        }
    }

    private func smallLayout(animationDate: Date) -> some View {
        GeometryReader { geo in
            let contentWidth = geo.size.width - contentInsets.leading - contentInsets.trailing
            let contentHeight = geo.size.height - contentInsets.top - contentInsets.bottom
            let recordSize = min(contentHeight * 0.64, contentWidth * 0.42)

            ZStack {
                basePanel(cornerRadius: 24)
                    .frame(width: geo.size.width, height: geo.size.height)

                HStack(spacing: 8) {
                    ZStack(alignment: .topTrailing) {
                        VinylRecordView(
                            entry: entry,
                            size: recordSize,
                            accentColor: accentColor,
                            accentSecondaryColor: accentSecondaryColor,
                            glossAngle: glossAngle,
                            animationDate: animationDate
                        )

                        VinylTonearmView(
                            size: recordSize,
                            isActive: isActivePlayback,
                            metalColor: metalColor,
                            accentColor: accentColor
                        )
                        .frame(width: recordSize, height: recordSize)
                        .offset(x: recordSize * 0.01, y: recordSize * 0.015)
                    }
                    .frame(width: recordSize + 2, height: contentHeight)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            smallSourceBadge(title: smallSourceText)
                            Spacer(minLength: 2)
                            Text(qualityDisplayText)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(dimTextColor)
                        }

                        Spacer(minLength: 0)

                        Text(displaySongName)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                            .contentTransition(.interpolate)

                        HStack(spacing: 4) {
                            playbackIndicator(height: 10, compact: true, animationDate: animationDate)
                            Text(displayArtistName)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(dimTextColor)
                                .lineLimit(1)
                        }

                        if !entry.isEmpty {
                            HStack(spacing: 5) {
                                transportButton(PreviousTrackIntent(), systemName: "backward.fill", diameter: 18, filled: false)
                                transportButton(TogglePlaybackIntent(), systemName: entry.controlSymbolName, diameter: 26, filled: true)
                                transportButton(NextTrackIntent(), systemName: "forward.fill", diameter: 18, filled: false)
                            }
                        } else {
                            Text(statusTitle)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(accentColor.opacity(0.92))
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 10)
                    .background(recessedInfoPanel(cornerRadius: 18))
                }
                .padding(.top, contentInsets.top)
                .padding(.leading, contentInsets.leading)
                .padding(.bottom, contentInsets.bottom)
                .padding(.trailing, contentInsets.trailing)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    private func mediumLayout(animationDate: Date) -> some View {
        GeometryReader { geo in
            let contentWidth = geo.size.width - contentInsets.leading - contentInsets.trailing
            let contentHeight = geo.size.height - contentInsets.top - contentInsets.bottom
            let recordSize = min(contentHeight * 0.71, contentWidth * 0.34)
            let recordStageWidth = recordSize + 20

            ZStack {
                basePanel(cornerRadius: 28)
                    .frame(width: geo.size.width, height: geo.size.height)

                VStack(alignment: .leading, spacing: 8) {
                    headerBadge(title: sourceText, compact: true)
                    .padding(.top, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(alignment: .center, spacing: 12) {
                        mediumRecordStage(recordSize: recordSize, animationDate: animationDate)
                            .frame(width: recordStageWidth, height: recordSize + 18, alignment: .leading)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(displaySongName)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .contentTransition(.interpolate)

                            HStack(alignment: .top, spacing: 8) {
                                Text(displayArtistName)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(dimTextColor)
                                    .lineLimit(1)

                                Spacer(minLength: 8)

                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("队列")
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .foregroundStyle(accentColor.opacity(0.95))
                                    Text(queueText)
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundStyle(dimTextColor)
                                }
                            }

                            HStack(spacing: 8) {
                                playbackIndicator(height: 12, compact: false, animationDate: animationDate)

                                Text(statusTitle)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.84))

                                Spacer(minLength: 6)

                                Text(tempoText)
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(dimTextColor)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(infoPanel(cornerRadius: 16))

                            Spacer(minLength: 0)

                            if !entry.isEmpty {
                                HStack(spacing: 0) {
                                    transportButton(PreviousTrackIntent(), systemName: "backward.fill", diameter: 21, filled: false)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    transportButton(TogglePlaybackIntent(), systemName: entry.controlSymbolName, diameter: 30, filled: true)
                                        .frame(maxWidth: .infinity, alignment: .center)

                                    transportButton(NextTrackIntent(), systemName: "forward.fill", diameter: 21, filled: false)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .padding(.horizontal, 2)
                                .padding(.top, 2)
                                .padding(.bottom, 3)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .offset(y: -4)
                    }
                }
                .padding(.top, contentInsets.top + 10)
                .padding(.leading, max(contentInsets.leading - 4, 0))
                .padding(.bottom, contentInsets.bottom + 10)
                .padding(.trailing, contentInsets.trailing)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    private func mediumRecordStage(recordSize: CGFloat, animationDate: Date) -> some View {
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.045),
                            Color.white.opacity(0.018),
                            accentColor.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.03),
                                    accentColor.opacity(0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .padding(8)

            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(width: 4, height: recordSize * 0.72)
                .blur(radius: 3)
                .offset(x: 10, y: recordSize * 0.14)

            Circle()
                .fill(accentColor.opacity(0.10))
                .frame(width: recordSize * 0.82, height: recordSize * 0.82)
                .blur(radius: recordSize * 0.08)
                .offset(x: recordSize * 0.06, y: recordSize * 0.08)

            VinylRecordView(
                entry: entry,
                size: recordSize * 0.96,
                accentColor: accentColor,
                accentSecondaryColor: accentSecondaryColor,
                glossAngle: glossAngle,
                animationDate: animationDate
            )
            .offset(x: 6, y: 8)

            VinylTonearmView(
                size: recordSize * 0.96,
                isActive: isActivePlayback,
                metalColor: metalColor,
                accentColor: accentColor
            )
            .frame(width: recordSize * 0.96, height: recordSize * 0.96)
            .offset(x: 6, y: 8)
        }
    }

    private func largeLayout(animationDate: Date) -> some View {
        GeometryReader { geo in
            let pad = contentInsets
            let w = geo.size.width - pad.leading - pad.trailing
            let h = geo.size.height - pad.top - pad.bottom
            let turntableWidth = w * 0.52
            let recordSize = min(turntableWidth - 16, h * 0.65)
            let coverSize: CGFloat = 72

            ZStack {
                basePanel(cornerRadius: 30)
                    .frame(width: geo.size.width, height: geo.size.height)

                HStack(alignment: .top, spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(lineColor, lineWidth: 1)
                            )

                        Circle()
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                            .frame(width: recordSize * 1.12, height: recordSize * 1.12)

                        ZStack(alignment: .topTrailing) {
                            VinylRecordView(
                                entry: entry,
                                size: recordSize,
                                accentColor: accentColor,
                                accentSecondaryColor: accentSecondaryColor,
                                glossAngle: glossAngle,
                                animationDate: animationDate
                            )

                            VinylTonearmView(
                                size: recordSize,
                                isActive: isActivePlayback,
                                metalColor: metalColor,
                                accentColor: accentColor
                            )
                            .frame(width: recordSize, height: recordSize)
                            .offset(x: recordSize * 0.01, y: recordSize * 0.015)
                        }
                    }
                    .frame(width: turntableWidth)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            if let data = entry.coverImageData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: coverSize, height: coverSize)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(accentColor.opacity(0.2))
                                    .frame(width: coverSize, height: coverSize)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(displayAlbumName)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(dimTextColor)
                                    .lineLimit(2)

                                HStack(spacing: 4) {
                                    headerBadge(title: sourceText, compact: true)
                                    Text(qualityDisplayText)
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundStyle(accentColor.opacity(0.9))
                                }
                            }
                        }

                        Spacer().frame(height: 14)

                        Text(displaySongName)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .minimumScaleFactor(0.75)
                            .contentTransition(.interpolate)

                        Text(displayArtistName)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(dimTextColor)
                            .lineLimit(1)
                            .padding(.top, 2)

                        if !entry.lyricText.isEmpty {
                            Text(entry.lyricText)
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(accentColor.opacity(0.75))
                                .italic()
                                .minimumScaleFactor(0.7)
                                .padding(.top, 8)
                        }

                        Spacer()

                        HStack(spacing: 5) {
                            statBlock(title: "BPM", value: tempoText, compact: true)
                            statBlock(title: "模式", value: playModeDisplayText, compact: true)
                            statBlock(title: "队列", value: queueText, compact: true)
                        }
                        .padding(.bottom, 8)

                        HStack {
                            playbackIndicator(height: 12, compact: false, animationDate: animationDate)
                            Text(statusTitle)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.86))

                            Spacer(minLength: 4)

                            if !entry.isEmpty {
                                HStack(spacing: 8) {
                                    transportButton(PreviousTrackIntent(), systemName: "backward.fill", diameter: 22, filled: false)
                                    transportButton(TogglePlaybackIntent(), systemName: entry.controlSymbolName, diameter: 32, filled: true)
                                    transportButton(NextTrackIntent(), systemName: "forward.fill", diameter: 22, filled: false)
                                }
                            }
                        }
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.top, pad.top + 8)
                .padding(.bottom, pad.bottom + 6)
                .padding(.leading, pad.leading + 4)
                .padding(.trailing, pad.trailing + 4)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    private func transportButton<I: AppIntent>(
        _ intent: I,
        systemName: String,
        diameter: CGFloat,
        filled: Bool
    ) -> some View {
        Button(intent: intent) {
            ZStack {
                Circle()
                    .fill(
                        filled
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.98),
                                    accentSecondaryColor.opacity(0.82)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(Color.white.opacity(0.05))
                    )

                Circle()
                    .stroke(Color.white.opacity(filled ? 0.10 : 0.12), lineWidth: 1)

                Image(systemName: systemName)
                    .font(.system(size: diameter * (filled ? 0.34 : 0.31), weight: .bold))
                    .foregroundStyle(filled ? shellColor : .white.opacity(0.88))
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: diameter, height: diameter)
            .shadow(
                color: filled ? accentColor.opacity(0.32) : .black.opacity(0.16),
                radius: filled ? 12 : 6,
                x: 0,
                y: filled ? 6 : 3
            )
        }
        .buttonStyle(.plain)
    }

    private func playbackIndicator(height: CGFloat, compact: Bool, animationDate: Date) -> some View {
        Group {
            if entry.isPlaying {
                PlaybackWave(
                    isActive: true,
                    barCount: compact ? 3 : 4,
                    color: accentColor.opacity(0.95),
                    height: height,
                    externalDate: entry.date
                )
                    .frame(width: compact ? 12 : 18)
            } else {
                Image(systemName: entry.statusSymbolName)
                    .font(.system(size: compact ? 9 : 11, weight: .semibold))
                    .foregroundStyle(accentColor.opacity(0.95))
                    .contentTransition(.symbolEffect(.replace))
            }
        }
    }

    private func headerBadge(title: String, compact: Bool = false) -> some View {
        let dotSize: CGFloat = compact ? 5 : 6
        let horizontalPadding: CGFloat = compact ? 8 : 9
        let verticalPadding: CGFloat = compact ? 5 : 6

        return HStack(spacing: compact ? 5 : 6) {
            Circle()
                .fill(accentColor.opacity(0.95))
                .frame(width: dotSize, height: dotSize)
            Text(title)
                .font(.system(size: compact ? 9 : 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func smallSourceBadge(title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(.white.opacity(0.94))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.10),
                                        accentColor.opacity(0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }

    private func statBlock(title: String, value: String, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 4) {
            Text(title)
                .font(.system(size: compact ? 8 : 9, weight: .bold, design: .rounded))
                .foregroundStyle(dimTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(value)
                .font(.system(size: compact ? 12 : 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func basePanel(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        shellColor.opacity(0.96),
                        panelColor.opacity(0.98),
                        shellColor.opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                panelDecoration(cornerRadius: cornerRadius)
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.03),
                                Color.black.opacity(0.24)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    private func panelDecoration(cornerRadius: CGFloat) -> some View {
        let profile = backgroundCoverageProfile

        return GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let minSide = min(width, height)
            let arcLineWidth = max(minSide * 0.010, 1)
            let ringDiameter = minSide * profile.ringScale
            let innerRingDiameter = minSide * profile.innerRingScale
            let guideWidth = width * profile.guideWidthRatio
            let heroGlowOpacity = entry.isEmpty ? 0.10 : 0.18

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.032),
                                .clear,
                                Color.black.opacity(0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: minSide * 0.22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                Color.white.opacity(0.012),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: width * profile.sheenWidthRatio,
                        height: height * profile.sheenHeightRatio
                    )
                    .rotationEffect(.degrees(-14))
                    .blur(radius: minSide * 0.05)
                    .offset(x: width * profile.sheenOffsetX, y: height * profile.sheenOffsetY)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColor.opacity(heroGlowOpacity),
                                accentSecondaryColor.opacity(entry.isEmpty ? 0.05 : 0.10),
                                .clear
                            ],
                            center: .center,
                            startRadius: minSide * 0.06,
                            endRadius: minSide * 0.50
                        )
                    )
                    .frame(width: minSide * profile.heroGlowScale, height: minSide * profile.heroGlowScale)
                    .blur(radius: minSide * 0.08)
                    .offset(x: width * profile.heroGlowOffsetX, y: height * profile.heroGlowOffsetY)

                Circle()
                    .fill(accentSecondaryColor.opacity(0.05))
                    .frame(width: minSide * profile.accentCloudScale, height: minSide * profile.accentCloudScale)
                    .blur(radius: minSide * 0.11)
                    .offset(x: width * profile.accentCloudOffsetX, y: height * profile.accentCloudOffsetY)

                Circle()
                    .stroke(Color.white.opacity(0.032), lineWidth: 1)
                    .frame(width: ringDiameter, height: ringDiameter)
                    .offset(x: width * profile.ringOffsetX, y: height * profile.ringOffsetY)

                Circle()
                    .stroke(Color.white.opacity(0.018), lineWidth: 1)
                    .frame(width: innerRingDiameter, height: innerRingDiameter)
                    .offset(
                        x: width * (profile.ringOffsetX + 0.02),
                        y: height * (profile.ringOffsetY + 0.01)
                    )

                Circle()
                    .trim(from: 0.09, to: 0.37)
                    .stroke(
                        AngularGradient(
                            colors: [
                                accentColor.opacity(0.20),
                                accentSecondaryColor.opacity(0.10),
                                .clear,
                                .clear
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: arcLineWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter * 0.84, height: ringDiameter * 0.84)
                    .rotationEffect(.degrees(-22))
                    .offset(
                        x: width * (profile.ringOffsetX + 0.02),
                        y: height * (profile.ringOffsetY - 0.01)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: guideWidth, height: 1.2)

                    Capsule(style: .continuous)
                        .fill(accentSecondaryColor.opacity(0.13))
                        .frame(width: max(guideWidth * 0.58, 18), height: 1.6)
                }
                .offset(x: width * profile.guideOffsetX, y: height * profile.guideOffsetY)
            }
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    private func infoPanel(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(lineColor, lineWidth: 1)
            )
    }

    private func recessedInfoPanel(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return shape
            .fill(
                LinearGradient(
                    colors: [
                        shellColor.opacity(0.76),
                        panelColor.opacity(0.90),
                        shellColor.opacity(0.82)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                shape
                    .stroke(Color.black.opacity(0.34), lineWidth: 6)
                    .blur(radius: 6)
                    .offset(x: 2, y: 2)
                    .mask {
                        shape.fill(
                            LinearGradient(
                                colors: [.black, .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
            }
            .overlay {
                shape
                    .stroke(Color.white.opacity(0.045), lineWidth: 3)
                    .blur(radius: 2.5)
                    .offset(x: -1.2, y: -1.2)
                    .mask {
                        shape.fill(
                            LinearGradient(
                                colors: [.white, .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
            }
            .overlay(
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.015),
                            Color.black.opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
            )
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: entry.date)
    }
}

private struct VinylRecordView: View {
    let entry: NowPlayingEntry
    let size: CGFloat
    let accentColor: Color
    let accentSecondaryColor: Color
    let glossAngle: Double
    let animationDate: Date

    private var rotationDegrees: Double {
        entry.date.timeIntervalSinceReferenceDate * 36.0 + glossAngle
    }

    private var discPlate: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "3A3E47"), Color(hex: "1A1C22")],
                        center: .center, startRadius: size * 0.38, endRadius: size * 0.52
                    )
                )
                .frame(width: size, height: size)

            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: size * 0.008)
                .frame(width: size * 0.985, height: size * 0.985)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "2A2E35"), Color(hex: "17191F"), Color(hex: "0E1014")],
                        center: .center, startRadius: size * 0.08, endRadius: size * 0.48
                    )
                )
                .frame(width: size * 0.94, height: size * 0.94)

            VinylGrooveView()
                .padding(size * 0.11)
                .frame(width: size * 0.94, height: size * 0.94)

            Circle()
                .trim(from: 0.08, to: 0.31)
                .stroke(accentColor.opacity(0.46),
                        style: StrokeStyle(lineWidth: size * 0.014, lineCap: .round))
                .frame(width: size * 0.76, height: size * 0.76)
                .rotationEffect(.degrees(glossAngle * 0.68 + 18))
                .blur(radius: 0.2)

            VinylLabelView(
                entry: entry, size: size * 0.42,
                accentColor: accentColor, accentSecondaryColor: accentSecondaryColor
            )

            Circle().fill(Color(hex: "F3E3D2").opacity(0.94))
                .frame(width: size * 0.050, height: size * 0.050)
            Circle().fill(Color.black.opacity(0.86))
                .frame(width: size * 0.020, height: size * 0.020)
        }
    }

    private func glossRing(angle: Angle) -> some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.white.opacity(0.28), .clear, .white.opacity(0.12),
                                 .clear, .white.opacity(0.20), .clear],
                        center: .center
                    ),
                    lineWidth: size * 0.022
                )
                .frame(width: size * 0.92, height: size * 0.92)
                .rotationEffect(angle)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.16), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: size * 0.014, height: size * 0.26)
                .offset(y: -size * 0.30)
                .rotationEffect(angle + .degrees(90))
        }
    }

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: size * 0.88, height: size * 0.24)
                .blur(radius: size * 0.09)
                .offset(y: size * 0.40)
            Ellipse()
                .fill(Color.black.opacity(0.28))
                .frame(width: size * 0.62, height: size * 0.12)
                .blur(radius: size * 0.045)
                .offset(y: size * 0.43)

            ZStack {
                discPlate
                glossRing(angle: .degrees(rotationDegrees))
            }
            .rotationEffect(.degrees(rotationDegrees))
            .animation(entry.isPlaying ? .linear(duration: 0.5) : .none, value: rotationDegrees)
        }
        .frame(width: size, height: size)
    }
}

private struct VinylGrooveView: View {
    var body: some View {
        Canvas { context, canvasSize in
            let minSide = min(canvasSize.width, canvasSize.height)
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let innerRadius = minSide * 0.18
            let outerRadius = minSide * 0.49
            let ringCount = 26

            for index in 0..<ringCount {
                let progress = CGFloat(index) / CGFloat(ringCount - 1)
                let radius = innerRadius + (outerRadius - innerRadius) * progress
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )

                var path = Path()
                path.addEllipse(in: rect)

                context.stroke(
                    path,
                    with: .color(.white.opacity(0.15 - Double(progress) * 0.09)),
                    lineWidth: progress < 0.48 ? 0.55 : 0.8
                )
            }
        }
    }
}

private struct VinylLabelView: View {
    let entry: NowPlayingEntry
    let size: CGFloat
    let accentColor: Color
    let accentSecondaryColor: Color

    private var labelTitle: String {
        if entry.isEmpty {
            return "未播放"
        }

        return entry.sourceName.isEmpty ? "未知来源" : entry.sourceName
    }

    private var labelSubtitle: String {
        entry.isEmpty ? "暂无歌曲信息" : entry.artistName
    }

    private var labelFooter: String {
        if let tempoBPM = entry.tempoBPM, tempoBPM > 0 {
            return "\(tempoBPM) BPM"
        }

        if entry.tempoIsAnalyzing {
            return "BPM ..."
        }

        if !entry.qualityText.isEmpty {
            return entry.qualityText
        }

        return "BPM --"
    }

    var body: some View {
        ZStack {
            if let data = entry.coverImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size * 0.92, height: size * 0.92)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.06),
                                        Color.clear,
                                        Color.black.opacity(0.12),
                                        Color.black.opacity(0.30)
                                    ],
                                    center: .center,
                                    startRadius: size * 0.02,
                                    endRadius: size * 0.48
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.96),
                                accentSecondaryColor.opacity(0.84),
                                accentColor.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)

            Circle()
                .stroke(Color.black.opacity(0.20), lineWidth: 4)
                .padding(4)

            Circle()
                .stroke(accentColor.opacity(0.24), lineWidth: 1.2)
                .padding(size * 0.08)

            VStack(spacing: size * 0.035) {
                Text(labelTitle)
                    .font(.system(size: size * 0.12, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Capsule(style: .continuous)
                    .fill(.white.opacity(0.42))
                    .frame(width: size * 0.40, height: 1.5)

                Text(labelSubtitle)
                    .font(.system(size: size * 0.085, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .padding(.horizontal, size * 0.10)

                Text(labelFooter)
                    .font(.system(size: size * 0.078, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .shadow(color: .black.opacity(0.26), radius: 5, x: 0, y: 1)

            Circle()
                .fill(Color(hex: "F5E6D8").opacity(0.95))
                .frame(width: size * 0.16, height: size * 0.16)

            Circle()
                .fill(Color.black.opacity(0.82))
                .frame(width: size * 0.06, height: size * 0.06)
        }
        .frame(width: size, height: size)
    }
}

private struct VinylTonearmView: View {
    let size: CGFloat
    let isActive: Bool
    let metalColor: Color
    let accentColor: Color

    private var pivotDiameter: CGFloat {
        size * 0.115
    }

    private var armLength: CGFloat {
        size * 0.485
    }

    private var armThickness: CGFloat {
        size * 0.041
    }

    private var restingAngle: Double {
        18.0
    }

    private var activeAngle: Double {
        -7.5
    }

    private var angle: Double {
        isActive ? activeAngle : restingAngle
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "6E7582"),
                            Color(hex: "3A3F48")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: pivotDiameter, height: pivotDiameter)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .overlay(
                    Circle()
                        .fill(Color.black.opacity(0.26))
                        .frame(width: pivotDiameter * 0.28, height: pivotDiameter * 0.28)
                )
                .shadow(color: .black.opacity(0.18), radius: size * 0.018, x: 0, y: size * 0.012)

            ZStack(alignment: .trailing) {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.20))
                    .frame(width: armLength * 0.96, height: armThickness * 0.62)
                    .blur(radius: size * 0.008)
                    .offset(x: -size * 0.032, y: size * 0.012)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                metalColor.opacity(0.96),
                                Color(hex: "7A808B"),
                                Color(hex: "C1C6D0")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: armLength, height: armThickness)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .padding(size * 0.005)
                            .mask(
                                LinearGradient(
                                    colors: [.white, .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.18))
                    .frame(width: size * 0.26, height: size * 0.012)
                    .offset(x: -size * 0.08)

                RoundedRectangle(cornerRadius: size * 0.018, style: .continuous)
                    .fill(accentColor.opacity(0.96))
                    .frame(width: size * 0.046, height: size * 0.031)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.018, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
                    .offset(x: size * 0.008)
            }
            .rotationEffect(.degrees(angle), anchor: .topTrailing)
            .offset(x: -size * 0.030, y: size * 0.058)
        }
        .frame(width: size, height: size, alignment: .topTrailing)
    }
}


// MARK: - Playback Wave (Lock Screen only)

private struct PlaybackWave: View {
    let isActive: Bool
    let barCount: Int
    let color: Color
    let height: CGFloat
    var externalDate: Date?

    var body: some View {
        if let date = externalDate {
            waveBody(time: date.timeIntervalSinceReferenceDate)
                .animation(.linear(duration: 0.5), value: date)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: !isActive)) { context in
                waveBody(time: context.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    @ViewBuilder
    private func waveBody(time: TimeInterval) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(width: 2.5, height: barHeight(for: i, time: time))
            }
        }
        .frame(height: height)
    }

    private func barHeight(for index: Int, time: TimeInterval) -> CGFloat {
        if !isActive {
            return 2.5
        }
        let phases: [Double] = [0.0, 1.3, 0.6, 2.1, 1.0, 2.6, 0.3, 1.8]
        let phase = phases[index % phases.count]
        let wave = sin(time * 3.5 + phase) * 0.5 + 0.5
        let minScale: CGFloat = 0.18
        return height * (minScale + CGFloat(wave) * (1.0 - minScale))
    }
}

// MARK: - Hex Color Helper

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
    }

    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}


// MARK: - Restored Themes


struct WidgetAnimation {
    static func spectrumBar(index: Int, maxBars: Int, date: Date, speed: Double = 1.0, amplitude: Double = 1.0) -> CGFloat {
        let time = date.timeIntervalSinceReferenceDate * speed * 2.0
        let phase = Double(index) * 0.4
        let sin1 = sin(time + phase)
        let sin2 = sin(time * 1.5 - phase * 0.5)
        let normalized = (sin1 + sin2 + 2.0) / 4.0
        return CGFloat(min(max(normalized * amplitude, 0.1), 1.0))
    }
    
    static func signalBars(index: Int, count: Int, date: Date) -> Bool {
        let time = date.timeIntervalSinceReferenceDate * 3.0
        let activeBars = Int((sin(time) + 1.0) / 2.0 * Double(count))
        return index <= activeBars
    }
    
    static func ledPulse(date: Date, speed: Double = 1.0) -> Double {
        let time = date.timeIntervalSinceReferenceDate * speed * 4.0
        return (sin(time) + 1.0) / 2.0
    }
    
    static func cursorBlink(date: Date) -> Double {
        let time = date.timeIntervalSinceReferenceDate * 2.0
        return sin(time) > 0 ? 1.0 : 0.0
    }
    
    static func sweepAngle(date: Date, speed: Double = 1.0) -> Double {
        let time = date.timeIntervalSinceReferenceDate * speed
        return (time.truncatingRemainder(dividingBy: 2.0)) * .pi
    }
    
    static func wobble(date: Date, speed: Double = 1.0, amount: Double = 1.0) -> Double {
        let time = date.timeIntervalSinceReferenceDate * speed * 3.0
        return sin(time) * amount
    }
    
    static func bounce(date: Date, speed: Double = 1.0, height: Double = 5.0) -> Double {
        let time = date.timeIntervalSinceReferenceDate * speed * 4.0
        return abs(sin(time)) * height
    }
    
    static func breathe(date: Date, speed: Double = 1.0, min: Double = 0.5, max: Double = 1.0) -> Double {
        let time = date.timeIntervalSinceReferenceDate * speed * 2.0
        return min + (max - min) * ((sin(time) + 1.0) / 2.0)
    }
}


// MARK: - Poster Theme (海报)

struct PosterWidgetTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    private var displaySong: String { entry.isEmpty ? "Not Playing" : entry.songName }
    private var displayArtist: String { entry.isEmpty ? "Aside Music" : entry.artistName }
    private var displayLyric: String { entry.lyricText.isEmpty ? "" : entry.lyricText }

    @ViewBuilder
    private func coverFill(width: CGFloat, height: CGFloat) -> some View {
        if let data = entry.coverImageData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
        } else {
            Color(hex: "0A0A0C")
                .frame(width: width, height: height)
        }
    }

    private var qualityBadge: some View {
        Group {
            if !entry.qualityText.isEmpty {
                Text(entry.qualityText)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
    }

    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        case .systemLarge: largeLayout
        default: smallLayout
        }
    }

    // MARK: - Small

    private var smallLayout: some View {
        GeometryReader { geo in
        ZStack {
            coverFill(width: geo.size.width, height: geo.size.height)

            LinearGradient(
                colors: [.black.opacity(0.3), .clear, .black.opacity(0.7)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(spacing: 0) {
                HStack {
                    Text(displayArtist.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .tracking(2)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(displaySong)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 1)

                    Text(displayArtist)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)

                if !entry.isEmpty {
                    HStack(spacing: 14) {
                        Button(intent: PreviousTrackIntent()) {
                            Image(systemName: "backward.fill").font(.system(size: 12))
                        }.buttonStyle(.plain)
                        Button(intent: TogglePlaybackIntent()) {
                            Image(systemName: entry.controlSymbolName).font(.system(size: 16, weight: .bold))
                                .contentTransition(.symbolEffect(.replace))
                        }.buttonStyle(.plain)
                        Button(intent: NextTrackIntent()) {
                            Image(systemName: "forward.fill").font(.system(size: 12))
                        }.buttonStyle(.plain)
                    }
                    .foregroundStyle(.white)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                }
            }
        }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Medium

    private var mediumLayout: some View {
        GeometryReader { geo in
            ZStack {
                coverFill(width: geo.size.width, height: geo.size.height)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.3), .black.opacity(0.8)],
                    startPoint: UnitPoint(x: 0.5, y: 0.3), endPoint: .bottom
                )
                .frame(width: geo.size.width, height: geo.size.height)

                VStack {
                    Spacer()

                    HStack(alignment: .bottom, spacing: 0) {
                        VStack(alignment: .leading, spacing: 3) {
                            qualityBadge

                            if !displayLyric.isEmpty {
                                Text(displayLyric)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .italic()
                                    .minimumScaleFactor(0.7)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            }

                            Text(displaySong)
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.65)
                                .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 2)

                            Text(displayArtist)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                        }

                        Spacer(minLength: 12)

                        if !entry.isEmpty {
                            VStack(spacing: 6) {
                                Button(intent: PreviousTrackIntent()) {
                                    Image(systemName: "backward.fill").font(.system(size: 11))
                                        .frame(width: 30, height: 30)
                                        .background(Color.white.opacity(0.15), in: Circle())
                                }.buttonStyle(.plain)
                                Button(intent: TogglePlaybackIntent()) {
                                    Image(systemName: entry.controlSymbolName)
                                        .font(.system(size: 16, weight: .bold))
                                        .contentTransition(.symbolEffect(.replace))
                                        .frame(width: 38, height: 38)
                                        .background(.ultraThinMaterial, in: Circle())
                                }.buttonStyle(.plain)
                                Button(intent: NextTrackIntent()) {
                                    Image(systemName: "forward.fill").font(.system(size: 11))
                                        .frame(width: 30, height: 30)
                                        .background(Color.white.opacity(0.15), in: Circle())
                                }.buttonStyle(.plain)
                            }
                            .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Large

    private var largeLayout: some View {
        GeometryReader { geo in
        ZStack {
            coverFill(width: geo.size.width, height: geo.size.height)

            LinearGradient(
                colors: [.black.opacity(0.15), .clear, .clear, .black.opacity(0.75)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    qualityBadge
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                Spacer()

                if !displayLyric.isEmpty {
                    Text("~ \(displayLyric) ~")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                Text(displaySong)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 20)

                Text(displayArtist)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .padding(.horizontal, 20)
                    .padding(.top, 3)

                if !entry.albumName.isEmpty {
                    Text(entry.albumName)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .padding(.horizontal, 20)
                        .padding(.top, 1)
                }

                if !entry.isEmpty {
                    HStack(spacing: 24) {
                        Button(intent: PreviousTrackIntent()) {
                            Image(systemName: "backward.fill").font(.system(size: 18))
                        }.buttonStyle(.plain)
                        Button(intent: TogglePlaybackIntent()) {
                            Image(systemName: entry.controlSymbolName)
                                .font(.system(size: 26, weight: .bold))
                                .contentTransition(.symbolEffect(.replace))
                        }.buttonStyle(.plain)
                        Button(intent: NextTrackIntent()) {
                            Image(systemName: "forward.fill").font(.system(size: 18))
                        }.buttonStyle(.plain)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(entry.sourceName.uppercased())
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                            Text(entry.playModeText)
                                .font(.system(size: 8, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.5))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
            }
        }
        }
        .widgetURL(URL(string: "monologue://player"))
    }
}

// MARK: - Manga Theme (日漫風)

private struct MangaStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let r = rect.width / 2
        let sides = 5
        let angle = -CGFloat.pi / 2
        for i in 0..<sides * 2 {
            let radius = i.isMultiple(of: 2) ? r : r * 0.45
            let theta = angle + CGFloat(i) * .pi / CGFloat(sides)
            let pt = CGPoint(x: center.x + radius * cos(theta), y: center.y + radius * sin(theta))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

private struct MangaSparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w/2, y: 0))
        path.addQuadCurve(to: CGPoint(x: w, y: h/2), control: CGPoint(x: w/2, y: h/2))
        path.addQuadCurve(to: CGPoint(x: w/2, y: h), control: CGPoint(x: w/2, y: h/2))
        path.addQuadCurve(to: CGPoint(x: 0, y: h/2), control: CGPoint(x: w/2, y: h/2))
        path.addQuadCurve(to: CGPoint(x: w/2, y: 0), control: CGPoint(x: w/2, y: h/2))
        return path
    }
}

private struct MangaHeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w/2, y: h * 0.25))
        path.addCurve(to: CGPoint(x: 0, y: h * 0.3), control1: CGPoint(x: w * 0.25, y: -0.15 * h), control2: CGPoint(x: 0, y: 0))
        path.addCurve(to: CGPoint(x: w/2, y: h * 0.95), control1: CGPoint(x: 0, y: h * 0.7), control2: CGPoint(x: w * 0.25, y: h * 0.85))
        path.addCurve(to: CGPoint(x: w, y: h * 0.3), control1: CGPoint(x: w * 0.75, y: h * 0.85), control2: CGPoint(x: w, y: h * 0.7))
        path.addCurve(to: CGPoint(x: w/2, y: h * 0.25), control1: CGPoint(x: w, y: 0), control2: CGPoint(x: w * 0.75, y: -0.15 * h))
        return path
    }
}

private struct MangaChatBubbleShape: Shape {
    var cornerRadius: CGFloat = 16
    var tailSize: CGFloat = 8
    var tailOffset: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let tr = CGPoint(x: rect.maxX, y: rect.minY)
        let br = CGPoint(x: rect.maxX, y: rect.maxY)
        let bl = CGPoint(x: rect.minX + tailSize, y: rect.maxY)
        let tl = CGPoint(x: rect.minX + tailSize, y: rect.minY)

        path.move(to: CGPoint(x: tl.x + cornerRadius, y: tl.y))
        path.addLine(to: CGPoint(x: tr.x - cornerRadius, y: tr.y))
        path.addArc(center: CGPoint(x: tr.x - cornerRadius, y: tr.y + cornerRadius), radius: cornerRadius, startAngle: .degrees(-90), endAngle: .zero, clockwise: false)
        path.addLine(to: CGPoint(x: br.x, y: br.y - cornerRadius))
        path.addArc(center: CGPoint(x: br.x - cornerRadius, y: br.y - cornerRadius), radius: cornerRadius, startAngle: .zero, endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: bl.x + cornerRadius, y: bl.y))
        path.addArc(center: CGPoint(x: bl.x + cornerRadius, y: bl.y - cornerRadius), radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        
        path.addLine(to: CGPoint(x: tl.x, y: tl.y + tailOffset + tailSize))
        path.addLine(to: CGPoint(x: rect.minX, y: tl.y + tailOffset + tailSize / 2))
        path.addLine(to: CGPoint(x: tl.x, y: tl.y + tailOffset))
        
        path.addLine(to: CGPoint(x: tl.x, y: tl.y + cornerRadius))
        path.addArc(center: CGPoint(x: tl.x + cornerRadius, y: tl.y + cornerRadius), radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        
        return path
    }
}

private struct MangaMicroAnimator: ViewModifier {
    var type: AnimationType
    
    enum AnimationType {
        case pulse
        case twinkle
        case wobble
        case float
    }
    
    func body(content: Content) -> some View {
        content.phaseAnimator([false, true]) { view, phase in
            switch type {
            case .pulse:
                view.scaleEffect(phase ? 1.15 : 1.0)
            case .twinkle:
                view
                    .scaleEffect(phase ? 1.1 : 0.85)
                    .opacity(phase ? 1.0 : 0.6)
            case .wobble:
                view.rotationEffect(.degrees(phase ? 6 : -6))
            case .float:
                view.offset(y: phase ? -3 : 3)
            }
        } animation: { phase in
            switch type {
            case .pulse:
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
            case .twinkle:
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
            case .wobble:
                .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
            case .float:
                .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
            }
        }
    }
}

private struct MangaTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    private let ink = Color(hex: "2D2D3A")
    private let inkSub = Color(hex: "8888A0")
    private let accentPink = Color(hex: "FF8FAB")
    private let labelYellow = Color(hex: "FFE4B5")
    private let decoBlue = Color(hex: "B8D4F0")

    private var song: String { entry.isEmpty ? "未在播放" : entry.songName }
    private var artist: String { entry.isEmpty ? "暂无歌曲信息" : entry.artistName }
    private var lyric: String { entry.lyricText }

    private var bgColors: [Color] {
        [Color(hex: "E8F4FD"), Color(hex: "FDE8F0"), Color(hex: "FFF8EC")]
    }

    private var extractedPlayBtn: Color {
        guard entry.dominantRGB.count == 3, !entry.isEmpty else { return Color(hex: "5E5A53") }
        return Color(red: Double(entry.dominantRGB[0]), green: Double(entry.dominantRGB[1]), blue: Double(entry.dominantRGB[2]))
    }

    private func mangaCanvasBackdrop(size: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: bgColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, sz in
                let gap: CGFloat = 16
                let dotR: CGFloat = 1.0
                var y: CGFloat = gap/2
                var isEven = true
                while y < sz.height + gap {
                    var x: CGFloat = isEven ? gap/2 : gap
                    while x < sz.width + gap {
                        let rect = CGRect(x: x - dotR, y: y - dotR, width: dotR * 2, height: dotR * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(ink.opacity(0.12)))
                        x += gap
                    }
                    y += gap
                    isEven.toggle()
                }
            }
        }
    }

    private func coverView(side: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let d = entry.coverImageData, let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        labelYellow.opacity(0.4)
                        Image(systemName: "music.note")
                            .font(.system(size: side * 0.28, weight: .medium))
                            .foregroundStyle(inkSub.opacity(0.45))
                    }
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: side * 0.24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
                    .stroke(ink, lineWidth: 3)
            )
            .background(
                RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
                    .fill(ink)
                    .offset(x: 4, y: 4)
            )

            if !entry.qualityText.isEmpty {
                Text(entry.qualityText)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(labelYellow))
                    .overlay(Capsule().stroke(ink, lineWidth: 2.5))
                    .background(Capsule().fill(ink).offset(x: 2.5, y: 2.5))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 12, y: -4)
            }
        }
    }

    private var nowPlayingHeader: some View {
        HStack(spacing: 3) {
            Image(systemName: "music.note")
                .font(.system(size: 8, weight: .black))
            Text("NOW PLAYING")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(0.5)
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(labelYellow))
        .overlay(Capsule().stroke(ink, lineWidth: 2.5))
        .background(Capsule().fill(ink).offset(x: 2.5, y: 2.5))
    }

    private func mangaBubble<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.leading, 20)
            .padding(.trailing, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MangaChatBubbleShape().fill(Color.white))
            .overlay(MangaChatBubbleShape().stroke(ink, lineWidth: 3.5))
            .background(MangaChatBubbleShape().fill(ink).offset(x: 4.5, y: 4.5))
    }

    private enum MediaBtnStyle {
        case normal
        case play
    }

    private func mediaButton(intent: some AppIntent, icon: String, w: CGFloat, h: CGFloat, style: MediaBtnStyle) -> some View {
        Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: min(w, h) * 0.45, weight: .black))
                .foregroundStyle(style == .play ? Color.white : ink)
                .frame(width: w, height: h)
                .background(
                    RoundedRectangle(cornerRadius: min(w, h) * 0.35, style: .continuous)
                        .fill(style == .play ? extractedPlayBtn : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: min(w, h) * 0.35, style: .continuous)
                        .stroke(ink, lineWidth: 3)
                )
                .background(
                    RoundedRectangle(cornerRadius: min(w, h) * 0.35, style: .continuous)
                        .fill(ink)
                        .offset(x: 3, y: 3)
                )
        }
        .buttonStyle(.plain)
    }

    private var bpmFooter: some View {
        Group {
            if let b = entry.tempoBPM, b > 0 {
                HStack(spacing: 4) {
                    Text("\(b)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(inkSub.opacity(0.8))
                    
                    ZStack {
                        MangaHeartShape().fill(accentPink)
                        MangaHeartShape().stroke(ink, lineWidth: 1.5)
                    }
                    .frame(width: 12, height: 10)
                    .offset(y: -1)
                    .modifier(MangaMicroAnimator(type: .pulse))
                    
                    Text("bpm")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(inkSub.opacity(0.8))
                }
            } else {
                ZStack {
                    MangaHeartShape().fill(accentPink)
                    MangaHeartShape().stroke(ink, lineWidth: 1.5)
                }
                .frame(width: 16, height: 14)
            }
        }
    }

    // MARK: - Small

    private var smallWidget: some View {
        GeometryReader { g in
            let coverSide = max(g.size.width * 0.46, 60)

            ZStack {
                mangaCanvasBackdrop(size: g.size)

                // 漫画风背景点缀装饰
                ZStack {
                    ZStack {
                        MangaSparkleShape().fill(accentPink)
                        MangaSparkleShape().stroke(ink, lineWidth: 2)
                    }
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(10))
                    .modifier(MangaMicroAnimator(type: .twinkle))
                    .position(x: 20, y: 26) // Hugging top-left of cover
                    
                    ZStack {
                        MangaStarShape().fill(labelYellow)
                        MangaStarShape().stroke(ink, lineWidth: 2)
                    }
                    .frame(width: 16, height: 16)
                    .rotationEffect(.degrees(20))
                    .modifier(MangaMicroAnimator(type: .wobble))
                    .position(x: g.size.width - 24, y: 20)
                        
                    ZStack {
                        Circle().fill(Color(hex: "CEF09D")) // Lime green dot
                        Circle().stroke(ink, lineWidth: 2)
                    }
                    .frame(width: 8, height: 8)
                    .modifier(MangaMicroAnimator(type: .float))
                    .position(x: 26, y: g.size.height - 24)
                        
                    ZStack {
                        MangaHeartShape().fill(accentPink)
                        MangaHeartShape().stroke(ink, lineWidth: 1.5)
                    }
                    .frame(width: 14, height: 12)
                    .rotationEffect(.degrees(-15))
                    .modifier(MangaMicroAnimator(type: .pulse))
                    .position(x: g.size.width - 20, y: g.size.height - 24)
                }
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer(minLength: 16)
                    
                    HStack(alignment: .center, spacing: 10) {
                        coverView(side: coverSide)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(song)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(ink)
                                .lineLimit(3)
                                .minimumScaleFactor(0.85)
                                
                            Text(artist)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(inkSub)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 14)
                    
                    Spacer(minLength: 14)
                    
                    if !entry.isEmpty {
                        HStack(spacing: 6) {
                            mediaButton(intent: PreviousTrackIntent(), icon: "backward.fill", w: 26, h: 22, style: .normal)
                            mediaButton(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, w: 32, h: 36, style: .play)
                            mediaButton(intent: NextTrackIntent(), icon: "forward.fill", w: 26, h: 22, style: .normal)
                        }
                        .padding(.bottom, 16)
                    } else {
                        Spacer().frame(height: 16)
                    }
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Medium

    private var mediumWidget: some View {
        GeometryReader { g in
            let coverSide = max(g.size.width * 0.24, 76)

            ZStack {
                mangaCanvasBackdrop(size: g.size)

                // Widget outer comic border
                ContainerRelativeShape()
                    .stroke(ink, lineWidth: 2)

                // Background decorations
                ZStack {
                    ZStack {
                        MangaSparkleShape().fill(accentPink)
                        MangaSparkleShape().stroke(ink, lineWidth: 2)
                    }
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(10))
                    .modifier(MangaMicroAnimator(type: .twinkle))
                    .position(x: 14, y: 14)
                    
                    ZStack {
                        MangaStarShape().fill(labelYellow)
                        MangaStarShape().stroke(ink, lineWidth: 2)
                    }
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(20))
                    .modifier(MangaMicroAnimator(type: .wobble))
                    .position(x: g.size.width - 20, y: 16)
                        
                    ZStack {
                        Circle().fill(Color(hex: "CEF09D"))
                        Circle().stroke(ink, lineWidth: 2)
                    }
                    .frame(width: 6, height: 6)
                    .modifier(MangaMicroAnimator(type: .float))
                    .position(x: 24, y: g.size.height - 18)
                }
                .allowsHitTesting(false)

                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 12) {
                            coverView(side: coverSide)
                                .padding(.top, 4)
                            
                            mangaBubble {
                                VStack(alignment: .leading, spacing: 2) {
                                    Spacer().frame(height: 6) // Internal top buffer for the centered header overlap

                                    Text(song)
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                        .foregroundStyle(ink)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.85)

                                    Text(artist)
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(inkSub)
                                        .lineLimit(1)

                                    if !lyric.isEmpty {
                                        Rectangle()
                                            .fill(ink.opacity(0.12))
                                            .frame(height: 1)
                                            .padding(.vertical, 2)

                                        Text(lyric)
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundStyle(ink.opacity(0.8))
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                    } else {
                                        Spacer(minLength: 0) // Allows bubble to stretch when empty
                                    }
                                }
                                .frame(minHeight: 62, alignment: .top) // Enforce a fat bubble default!
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 14)

                        Spacer(minLength: 2)

                        ZStack(alignment: .bottomTrailing) {
                            if !entry.isEmpty {
                                HStack(spacing: 6) {
                                    mediaButton(intent: PreviousTrackIntent(), icon: "backward.fill", w: 26, h: 20, style: .normal)
                                    mediaButton(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, w: 32, h: 32, style: .play)
                                    mediaButton(intent: NextTrackIntent(), icon: "forward.fill", w: 26, h: 20, style: .normal)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 10)
                            }

                            bpmFooter
                                .padding(.trailing, 16)
                                .padding(.bottom, 12)
                        }
                    }

                    // Absolutely Centered Header overlapping the top components
                    nowPlayingHeader
                        .padding(.top, 6)
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Large

    private var largeWidget: some View {
        GeometryReader { g in
            let coverSide = min(min(g.size.width, g.size.height) * 0.48, 148)

            ZStack {
                mangaCanvasBackdrop(size: g.size)

                VStack {
                    HStack {
                        Image(systemName: "music.note")
                            .font(.system(size: 14))
                            .foregroundStyle(decoBlue.opacity(0.45))
                        Spacer()
                    }
                    .padding(14)
                    Spacer()
                }
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    HStack {
                        Spacer(minLength: 0)
                        nowPlayingHeader
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 12)

                    Spacer(minLength: 8)

                    coverView(side: coverSide)

                    Text(song)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    Text(artist)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(inkSub)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    if !lyric.isEmpty {
                        Text(lyric)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(ink.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 22)
                            .padding(.top, 10)
                    }

                    Spacer(minLength: 8)

                    if !entry.isEmpty {
                        HStack(spacing: 10) {
                            mediaButton(intent: PreviousTrackIntent(), icon: "backward.fill", w: 42, h: 34, style: .normal)
                            mediaButton(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, w: 50, h: 50, style: .play)
                            mediaButton(intent: NextTrackIntent(), icon: "forward.fill", w: 42, h: 34, style: .normal)
                        }
                        .padding(.bottom, 8)
                    }

                    HStack {
                        if !entry.sourceName.isEmpty {
                            Text(entry.sourceName.uppercased())
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(inkSub.opacity(0.65))
                        }
                        Spacer()
                        bpmFooter
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    var body: some View {
        switch family {
        case .systemSmall:  smallWidget
        case .systemMedium: mediumWidget
        default:            largeWidget
        }
    }
}




// MARK: - Magazine Theme (杂志)

struct MagazineTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    private let paper = Color(hex: "F4F1EA")
    private let ink = Color(hex: "1A1A1A")
    private let inkLight = Color(hex: "6B6560")
    private let rule = Color(hex: "C8C0B4")
    private let accent = Color(hex: "C23616")

    private var displaySong: String { entry.isEmpty ? "未在播放" : entry.songName }
    private var displayArtist: String { entry.isEmpty ? "暂无歌曲信息" : entry.artistName }
    private var displayLyric: String { entry.lyricText.isEmpty ? "" : entry.lyricText }

    private var issueNumber: String {
        guard entry.queueIndex > 0 else { return "No.—" }
        return "No.\(entry.queueIndex)"
    }

    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        case .systemLarge:  largeLayout
        default:            smallLayout
        }
    }

    // MARK: - Small

    private var smallLayout: some View {
        GeometryReader { geo in
            let pad: CGFloat = 12
            let coverH = geo.size.height * 0.60

            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    CoverImage(data: entry.coverImageData, radius: 0)
                        .frame(height: coverH)
                        .clipped()

                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                        .frame(height: coverH * 0.5)

                    if !entry.isEmpty {
                        Text(issueNumber)
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accent)
                            .padding(.leading, pad)
                            .padding(.bottom, 6)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(displaySong)
                        .font(.system(size: 14, weight: .black, design: .serif))
                        .foregroundStyle(ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .contentTransition(.interpolate)

                    Rectangle().fill(rule).frame(height: 0.8)

                    HStack(spacing: 0) {
                        if !entry.isEmpty {
                            HStack(spacing: 12) {
                                Button(intent: PreviousTrackIntent()) {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(ink.opacity(0.5))
                                }.buttonStyle(.plain)

                                Button(intent: TogglePlaybackIntent()) {
                                    Image(systemName: entry.controlSymbolName)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(accent)
                                        .contentTransition(.symbolEffect(.replace))
                                }.buttonStyle(.plain)

                                Button(intent: NextTrackIntent()) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(ink.opacity(0.5))
                                }.buttonStyle(.plain)
                            }
                        }

                        Spacer()

                        Text(displayArtist)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(inkLight)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, pad)
                .padding(.top, 7)
                .padding(.bottom, 8)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Medium

    private var mediumLayout: some View {
        GeometryReader { geo in
            let coverSize = geo.size.height
            let pad: CGFloat = 14

            HStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    CoverImage(data: entry.coverImageData, radius: 0)
                        .frame(width: coverSize, height: coverSize)
                        .clipped()

                    if !entry.isEmpty {
                        Text(issueNumber)
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(accent)
                            .padding(.leading, 8)
                            .padding(.top, 8)
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("ASIDE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(accent)
                        .tracking(4)

                    Spacer(minLength: 4)

                    Text(displaySong)
                        .font(.system(size: 20, weight: .black, design: .serif))
                        .foregroundStyle(ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.interpolate)

                    Text(displayArtist)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(inkLight)
                        .lineLimit(1)
                        .padding(.top, 2)

                    Spacer(minLength: 4)

                    if !displayLyric.isEmpty {
                        Text(displayLyric)
                            .font(.system(size: 11, weight: .medium, design: .serif))
                            .foregroundStyle(ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }

                    Spacer(minLength: 4)

                    Rectangle().fill(rule).frame(height: 0.8)

                    HStack(spacing: 0) {
                        if !entry.isEmpty {
                            HStack(spacing: 14) {
                                Button(intent: PreviousTrackIntent()) {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(ink.opacity(0.5))
                                }.buttonStyle(.plain)

                                Button(intent: TogglePlaybackIntent()) {
                                    Image(systemName: entry.controlSymbolName)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(accent)
                                        .contentTransition(.symbolEffect(.replace))
                                }.buttonStyle(.plain)

                                Button(intent: NextTrackIntent()) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(ink.opacity(0.5))
                                }.buttonStyle(.plain)
                            }

                            Spacer(minLength: 8)
                        }

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(entry.qualityText.isEmpty ? "--" : entry.qualityText)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(accent)
                            if let bpm = entry.tempoBPM, bpm > 0 {
                                Text("\(bpm) BPM")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(inkLight)
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, pad)
                .padding(.vertical, 10)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Large — 杂志内页风格

    private var largeLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let pad: CGFloat = 20

            VStack(spacing: 0) {
                HStack {
                    Text("ASIDE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(accent)
                        .tracking(5)
                    Spacer()
                    if !entry.isEmpty {
                        Text(issueNumber)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(accent)
                    }
                }
                .padding(.horizontal, pad)
                .padding(.top, 14)

                Rectangle().fill(ink).frame(height: 2)
                    .padding(.horizontal, pad)
                    .padding(.top, 6)

                HStack(alignment: .top, spacing: 14) {
                    CoverImage(data: entry.coverImageData, radius: 4)
                        .frame(width: w * 0.38, height: w * 0.38)
                        .clipped()
                        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(displaySong)
                            .font(.system(size: 22, weight: .black, design: .serif))
                            .foregroundStyle(ink)
                            .lineLimit(3)
                            .minimumScaleFactor(0.65)
                            .contentTransition(.interpolate)

                        Text(displayArtist)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(inkLight)
                            .lineLimit(1)
                            .padding(.top, 4)

                        if !entry.albumName.isEmpty {
                            Text(entry.albumName)
                                .font(.system(size: 10, weight: .regular, design: .serif))
                                .foregroundStyle(inkLight.opacity(0.7))
                                .lineLimit(1)
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, pad)
                .padding(.top, 12)

                if !displayLyric.isEmpty {
                    Text("「\(displayLyric)」")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(ink.opacity(0.7))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, pad)
                        .padding(.top, 10)
                }

                Spacer(minLength: 6)

                Rectangle().fill(rule).frame(height: 0.8)
                    .padding(.horizontal, pad)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        if !entry.qualityText.isEmpty {
                            HStack(spacing: 4) {
                                Text("音质")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(accent)
                                Text(entry.qualityText)
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(inkLight)
                            }
                        }
                        HStack(spacing: 8) {
                            Text(entry.playModeText)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(inkLight)
                            if let bpm = entry.tempoBPM, bpm > 0 {
                                Text("\(bpm) BPM")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(inkLight)
                            }
                        }
                    }

                    Spacer()

                    if !entry.isEmpty {
                        HStack(spacing: 18) {
                            Button(intent: PreviousTrackIntent()) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(ink.opacity(0.4))
                            }.buttonStyle(.plain)

                            Button(intent: TogglePlaybackIntent()) {
                                ZStack {
                                    Circle().fill(accent)
                                        .frame(width: 42, height: 42)
                                    Image(systemName: entry.controlSymbolName)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)
                                        .contentTransition(.symbolEffect(.replace))
                                }
                            }.buttonStyle(.plain)

                            Button(intent: NextTrackIntent()) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(ink.opacity(0.4))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, pad)
                .padding(.vertical, 10)

                Rectangle().fill(rule).frame(height: 0.8)
                    .padding(.horizontal, pad)

                HStack {
                    Text("ASIDE MUSIC EDITORIAL")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(inkLight.opacity(0.5))
                        .tracking(2)
                    Spacer()
                    Text(entry.sourceName.uppercased())
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(inkLight.opacity(0.5))
                }
                .padding(.horizontal, pad)
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }
}



// MARK: - Pager Theme (寻呼机)

struct PagerWidgetTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily
    var isLight: Bool = false

    // 色彩系统
    private var bodyTop: Color { isLight ? Color(hex: "F4F3F0") : Color(hex: "353230") }
    private var bodyBottom: Color { isLight ? Color(hex: "E8E6E0") : Color(hex: "252320") }
    private var screenBg: Color { isLight ? Color(hex: "E8E8E8") : Color(hex: "161616") }
    private var amber: Color { isLight ? Color(hex: "181818") : Color(hex: "fca311") }
    private var signalLit: Color { isLight ? dynamicTop : Color(hex: "fca311") }
    
    
    private var dynamicTop: Color {
        guard entry.dominantRGB.count == 3, !entry.isEmpty else { return Color(hex: "E5E4E0") }
        return Color(red: Double(entry.dominantRGB[0]), green: Double(entry.dominantRGB[1]), blue: Double(entry.dominantRGB[2]))
    }
    
    private var dynamicBottom: Color {
        guard entry.secondaryRGB.count == 3, !entry.isEmpty else { return Color(hex: "C8C6C0") }
        return Color(red: Double(entry.secondaryRGB[0]), green: Double(entry.secondaryRGB[1]), blue: Double(entry.secondaryRGB[2]))
    }
    
    private var btnMainTop: Color { isLight ? dynamicTop : Color(hex: "fca311") }
    private var btnMainBottom: Color { isLight ? dynamicBottom : Color(hex: "c47f0a") }
    
    private var btnBg: Color { isLight ? Color(hex: "D8D5D0") : Color(hex: "3a3630") }
    private var btnIcon: Color { isLight ? Color(hex: "A3A09A") : Color(hex: "78746c") }
    
    private var brandDim: Color { isLight ? Color(hex: "A09E98") : Color(hex: "807c76") }
    private var brandBright: Color { isLight ? Color(hex: "33312E") : Color.white.opacity(0.85) }

    private var song: String { entry.isEmpty ? "READY..." : entry.songName.uppercased() }
    private var artist: String { entry.isEmpty ? "M O T O P A G E R" : entry.artistName }

    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        case .systemLarge:  largeLayout
        default:            smallLayout
        }
    }

    // MARK: - Small

    private var smallLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let btnSz: CGFloat = min(w * 0.15, 24)

            VStack(spacing: 0) {
                // 品牌栏
                brandBar(fontSize: 9)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                // LCD 屏幕
                lcdScreen(cornerRadius: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(song)
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundStyle(amber)
                            .padding(.top, 6)
                            .lineLimit(2)
                            .minimumScaleFactor(0.65)
                            .contentTransition(.interpolate)

                        Text(artist)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(amber.opacity(0.4))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Spacer(minLength: 2)
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 10)
                    .padding(.vertical, 6)
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)

                Spacer(minLength: 4)

                // 按钮组
                if !entry.isEmpty {
                    HStack(spacing: 5) {
                        ctrlBtn(intent: PreviousTrackIntent(), icon: "backward.fill", size: btnSz, main: false)
                        ctrlBtn(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, size: btnSz + 3, main: true)
                        ctrlBtn(intent: NextTrackIntent(), icon: "forward.fill", size: btnSz, main: false)
                    }
                    .padding(.bottom, 12)
                } else {
                    Spacer().frame(height: 12)
                }
            }
            .background(deviceBody(cornerRadius: 22))
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Medium

    private var mediumLayout: some View {
        GeometryReader { geo in
            let btnSz: CGFloat = 32

            VStack(spacing: 0) {
                // ── 顶部品牌栏 + 音质 ──
                HStack(spacing: 0) {
                    Text("M O T O")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(brandDim)
                    Text(" P A G E R")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(brandBright)

                    Spacer()

                    signalBars(height: 9, active: !entry.isEmpty)

                    if !entry.qualityText.isEmpty {
                        Text(entry.qualityText)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(brandDim.opacity(0.6))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(brandDim.opacity(0.3), lineWidth: 1))
                            .padding(.leading, 6)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)

                // ── LCD 屏幕（含封面） ──
                lcdScreen(cornerRadius: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        // 封面
                        CoverImage(data: entry.coverImageData, radius: 6)
                            .frame(width: 62, height: 62)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(amber.opacity(0.35), lineWidth: 1))
                            .padding(.leading, 4)

                        // 歌曲信息
                        VStack(alignment: .leading, spacing: 3) {
                            Text(song)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(amber)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .contentTransition(.interpolate)

                            // 歌手 / 歌词
                            if !entry.lyricText.isEmpty {
                                (Text("\(artist) / ").foregroundStyle(amber.opacity(0.55)) +
                                 Text(entry.lyricText).foregroundStyle(amber))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .minimumScaleFactor(0.6)
                                    .contentTransition(.interpolate)
                            } else {
                                Text(artist)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(amber.opacity(0.55))
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: 62, alignment: .topLeading)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)

                Spacer(minLength: 4)

                // ── 底部：按钮 + BPM ──
                HStack {
                    if !entry.isEmpty {
                        HStack(spacing: 5) {
                            ctrlBtn(intent: PreviousTrackIntent(), icon: "backward.fill", size: btnSz, main: false)
                            ctrlBtn(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, size: btnSz + 3, main: true)
                            ctrlBtn(intent: NextTrackIntent(), icon: "forward.fill", size: btnSz, main: false)
                        }
                    }

                    Spacer()

                    if let bpm = entry.tempoBPM, bpm > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(bpm)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(brandDim.opacity(0.8))
                            Text("bpm")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(brandDim.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            .background(deviceBody(cornerRadius: 22))
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Large

    private var largeLayout: some View {
        GeometryReader { geo in
            let btnSz: CGFloat = 40

            VStack(spacing: 0) {
                // ── 顶部品牌栏 + 音质 ──
                HStack(spacing: 0) {
                    Text("M O T O")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(brandDim)
                    Text(" P A G E R")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(brandBright)

                    Spacer()

                    signalBars(height: 11, active: !entry.isEmpty)

                    if !entry.qualityText.isEmpty {
                        Text(entry.qualityText)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(brandDim.opacity(0.6))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(brandDim.opacity(0.3), lineWidth: 1))
                            .padding(.leading, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer(minLength: 10)

                // ── LCD 屏幕（含大封面） ──
                lcdScreen(cornerRadius: 16) {
                    VStack(alignment: .center, spacing: 10) {
                        CoverImage(data: entry.coverImageData, radius: 8)
                            .frame(width: 110, height: 110)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(amber.opacity(0.35), lineWidth: 1))

                        VStack(alignment: .center, spacing: 10) {
                            Text(song)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundStyle(amber)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .contentTransition(.interpolate)

                            VStack(alignment: .center, spacing: 6) {
                                Text(artist)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(amber.opacity(0.55))
                                    .lineLimit(1)

                                let subStr = entry.albumName.isEmpty ? entry.lyricText : entry.albumName
                                if !subStr.isEmpty {
                                    Text(subStr)
                                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                                        .foregroundStyle(amber.opacity(0.48))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.4)
                                        .padding(.horizontal, 10)
                                        .frame(height: 40)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 12)

                // 按钮组
                if !entry.isEmpty {
                    HStack(spacing: 16) {
                        ctrlBtn(intent: PreviousTrackIntent(), icon: "backward.fill", size: btnSz * 0.9, main: false)
                        ctrlBtn(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, size: (btnSz + 16) * 0.9, main: true)
                        ctrlBtn(intent: NextTrackIntent(), icon: "forward.fill", size: btnSz * 0.9, main: false)
                    }
                } else {
                    Spacer().frame(height: btnSz)
                }

                Spacer(minLength: 10)

                // 底部元数据栏
                HStack(alignment: .lastTextBaseline) {
                    // 左侧 QS
                    Text(!entry.sourceName.isEmpty ? entry.sourceName.uppercased() : "QS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(brandDim.opacity(0.4))
                    
                    Spacer()
                    
                    // 中部 顺序
                    Text("顺序")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(brandDim.opacity(0.4))
                    
                    Spacer()
                    
                    // 右侧 BPM
                    if let bpm = entry.tempoBPM, bpm > 0 {
                        Text("\(bpm) BPM")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(brandDim.opacity(0.4))
                    } else {
                        Text("-- BPM")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(brandDim.opacity(0.4))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
            }
            .background(deviceBody(cornerRadius: 26))
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - 共享组件

    /// 品牌栏
    private func brandBar(fontSize: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text("M O T O")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(brandDim)
            Text(" P A G E R")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(brandBright)

            Spacer()

            // 信号指示
            signalBars(height: fontSize, active: !entry.isEmpty)
        }
    }

    /// 信号格 — 重新设计：无 SF Symbol，纯几何构建的复古数据扫描缓冲 (Scanning Buffer)
    private func signalBars(height: CGFloat, active: Bool) -> some View {
        TimelineView(.animation(minimumInterval: 0.4, paused: !entry.isPlaying)) { timeline in
            // 定义来回扫描的索引序列 (Ping-pong array)
            let positions = [0, 1, 2, 3, 4, 3, 2, 1]
            // 如果正在播放，根据时间推移取模计算当前高亮的块
            let pos = (active && entry.isPlaying) ? positions[Int(timeline.date.timeIntervalSince1970 / 0.4) % positions.count] : -1
            
            HStack(spacing: 4) {
                // "TX" 数据发射标识文字
                Text("TX")
                    .font(.system(size: height * 0.7, weight: .heavy, design: .monospaced))
                    .foregroundStyle(entry.isPlaying ? signalLit.opacity(0.9) : brandDim.opacity(0.4))

                // 纯几何绘制的 5 段式扫描像素槽
                HStack(spacing: 1.5) {
                    ForEach(0..<5, id: \.self) { i in
                        let isLit = (i == pos)
                        Rectangle()
                            .fill(isLit ? signalLit.opacity(0.95) : brandDim.opacity(0.2))
                            .frame(width: 3.5, height: height * 0.75)
                            .animation(.none, value: isLit) // 硬切割动画，模拟真实老硬件的断电/通电质感
                    }
                }
            }
            .frame(height: height)
        }
    }

    /// LCD 屏幕 — 内凹效果
    private func lcdScreen<C: View>(cornerRadius cr: CGFloat, @ViewBuilder content: () -> C) -> some View {
        let shape = RoundedRectangle(cornerRadius: cr, style: .continuous)

        return ZStack(alignment: .leading) {
            // 底层：屏幕面板
            shape
                .fill(screenBg)

            // 内凹阴影 — 上边和左边暗色，模拟下沉
            shape
                .stroke(Color.black.opacity(isLight ? 0.25 : 0.6), lineWidth: 3)
                .blur(radius: 3)
                .offset(x: 1, y: 1)
                .mask(shape.padding(-1))

            // 内侧高光 — 底边和右边的微弱亮线
            shape
                .stroke(isLight ? Color.white.opacity(0.6) : Color.white.opacity(0.035), lineWidth: 2)
                .blur(radius: 1.5)
                .offset(x: -0.5, y: -0.5)
                .mask(shape.padding(-1))

            // 外轮廓
            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [isLight ? Color.black.opacity(0.1) : Color.black.opacity(0.5), isLight ? Color.white.opacity(0.4) : Color.white.opacity(0.06)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )

            // 左侧光标竖线
            RoundedRectangle(cornerRadius: 1)
                .fill(amber.opacity(0.12))
                .frame(width: 2)
                .padding(.vertical, 10)
                .padding(.leading, 6)

            // 内容
            content()
        }
    }

    /// 设备机身
    private func deviceBody(cornerRadius cr: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cr, style: .continuous)

        return ZStack {
            // 主体渐变
            shape.fill(
                LinearGradient(
                    colors: [bodyTop, bodyBottom],
                    startPoint: .top, endPoint: .bottom
                )
            )

            // 顶部高光边 — 金属感
            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.04),
                            Color.white.opacity(0.01),
                            Color.black.opacity(0.15)
                        ],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )

            // 顶部光泽 — 微妙的磨砂金属反光
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.04),
                            Color.white.opacity(0.01),
                            Color.clear,
                            Color.clear
                        ],
                        startPoint: .top, endPoint: .center
                    )
                )

            // 微噪点质感
            shape
                .fill(isLight ? Color.black.opacity(0.005) : Color.white.opacity(0.008))
        }
        .shadow(color: Color.black.opacity(isLight ? 0.08 : 0.35), radius: 16, x: 0, y: 8)
        .shadow(color: Color.black.opacity(isLight ? 0.04 : 0.15), radius: 4, x: 0, y: 2)
    }

    /// 控制按钮 — 截图参考像素级还原
    private func ctrlBtn<I: AppIntent>(intent: I, icon: String, size: CGFloat, main: Bool) -> some View {
        // 让按钮极其扁平细长，且大幅缩小上下曲的主体面积
        let h = main ? size * 0.70 : size * 0.58
        let w = main ? h * 2.7 : h * 2.1
        let cr = h * 0.25
        let shape = RoundedRectangle(cornerRadius: cr, style: .continuous)

        return Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: h * 0.42, weight: .bold))
                // 播放键图标极暗，切歌键图标用低对比度的暗灰色
                .foregroundStyle(main ? Color(hex: "181510") : btnIcon)
                .frame(width: w, height: h)
                .background(
                    ZStack {
                        shape.fill(
                            LinearGradient(
                                colors: main
                                    ? [btnMainTop, btnMainBottom]
                                    : [btnBg, isLight ? btnBg.opacity(0.9) : btnBg.opacity(0.7)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        // 物理高光效果：顶部极细的白光边，底部略深
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(main ? 0.2 : 0.08),
                                    Color.clear,
                                    Color.black.opacity(0.3)
                                ],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                    }
                )
                // 紧致硬朗的底部下沉阴影
                .shadow(color: Color.black.opacity(isLight ? 0.15 : 0.5), radius: 1, x: 0, y: 1.5)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
}

