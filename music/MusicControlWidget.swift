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
        .displayName("mono 播放/暂停")
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
        .displayName("mono 下一首")
    }
}

// MARK: - Widget Theme

enum WidgetTheme: String, CaseIterable, AppEnum {
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

    static let allCases: [WidgetTheme] = [
        .polaroid,
        .poster,
        .manga,
        .magazine,
        .aperture,
        .pager,
        .pagerLight,
        .radio,
        .dashboard,
        .soundwave,
        .typewriter,
    ]

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "主题")
    static let caseDisplayRepresentations: [WidgetTheme: DisplayRepresentation] = [
        .polaroid:    "拍立得",
        .vinyl:       "黑胶",
        .poster:      "海报",
        .manga:       "漫画",
        .magazine:    "杂志",
        .aperture:    "圆窗唱片",
        .pager:       "寻呼机(深色)",
        .pagerLight:  "寻呼机(浅色)",
        .radio:       "收音机",
        .dashboard:   "仪表盘",
        .soundwave:   "声波",
        .typewriter:  "打字机"
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
    let playbackCurrentTime: TimeInterval
    let playbackDuration: TimeInterval
    let playbackReferenceDate: Date

    init(
        date: Date,
        songName: String,
        artistName: String,
        albumName: String,
        playbackState: PlaybackSurfaceState,
        coverImageData: Data?,
        theme: WidgetTheme,
        dominantRGB: [CGFloat],
        secondaryRGB: [CGFloat],
        coverIsDark: Bool,
        sourceName: String,
        qualityText: String,
        playModeText: String,
        queueIndex: Int,
        queueCount: Int,
        tempoBPM: Int?,
        tempoIsAnalyzing: Bool,
        lyricText: String,
        playbackCurrentTime: TimeInterval = 0,
        playbackDuration: TimeInterval = 0,
        playbackReferenceDate: Date = .now
    ) {
        self.date = date
        self.songName = songName
        self.artistName = artistName
        self.albumName = albumName
        self.playbackState = playbackState
        self.coverImageData = coverImageData
        self.theme = theme
        self.dominantRGB = dominantRGB
        self.secondaryRGB = secondaryRGB
        self.coverIsDark = coverIsDark
        self.sourceName = sourceName
        self.qualityText = qualityText
        self.playModeText = playModeText
        self.queueIndex = queueIndex
        self.queueCount = queueCount
        self.tempoBPM = tempoBPM
        self.tempoIsAnalyzing = tempoIsAnalyzing
        self.lyricText = lyricText
        self.playbackCurrentTime = playbackCurrentTime
        self.playbackDuration = playbackDuration
        self.playbackReferenceDate = playbackReferenceDate
    }

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
                artistName: "mono",
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
                artistName: "mono",
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
        case .aperture:
            return NowPlayingEntry(
                date: .now,
                songName: "Wonderwall",
                artistName: "Oasis",
                albumName: "Aperture Preview",
                playbackState: .playing,
                coverImageData: nil,
                theme: theme,
                dominantRGB: [0.62, 0.58, 0.52],
                secondaryRGB: [0.90, 0.88, 0.84],
                coverIsDark: false,
                sourceName: "ncm",
                qualityText: "HQ",
                playModeText: "顺序",
                queueIndex: 3,
                queueCount: 12,
                tempoBPM: 96,
                tempoIsAnalyzing: false,
                lyricText: "",
                playbackCurrentTime: 82,
                playbackDuration: 238,
                playbackReferenceDate: .now
            )
        default:
            let isDark = [.vinyl, .poster].contains(theme)
            return NowPlayingEntry(
                date: .now,
                songName: "Midnight Drive",
                artistName: "mono",
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
    private var groupDefaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

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
        let playbackCurrentTime = groupDefaults?.double(forKey: "widget_current_time") ?? 0
        let playbackDuration = groupDefaults?.double(forKey: "widget_duration") ?? 0
        let playbackReferenceDate = groupDefaults?.object(forKey: "widget_progress_reference_date") as? Date ?? .now

        var coverData: Data?
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let coverURL = url.appendingPathComponent("widget_cover.jpg")
            let attributes = try? FileManager.default.attributesOfItem(atPath: coverURL.path)
            if let fileSize = attributes?[.size] as? NSNumber,
               fileSize.intValue <= 500_000 {
                coverData = try? Data(contentsOf: coverURL, options: [.mappedIfSafe])
            }
        }

        if songName.isEmpty {
            return NowPlayingEntry(
                date: .now, songName: "", artistName: "", albumName: "", playbackState: .idle,
                coverImageData: nil, theme: theme,
                dominantRGB: [], secondaryRGB: [], coverIsDark: true,
                sourceName: "", qualityText: "", playModeText: "顺序", queueIndex: 0, queueCount: 0,
                tempoBPM: nil, tempoIsAnalyzing: false, lyricText: "",
                playbackCurrentTime: 0, playbackDuration: 0, playbackReferenceDate: .now
            )
        }

        return NowPlayingEntry(
            date: .now, songName: songName, artistName: artistName, albumName: albumName,
            playbackState: playbackState, coverImageData: coverData, theme: theme,
            dominantRGB: dominantRGB, secondaryRGB: secondaryRGB, coverIsDark: coverIsDark,
            sourceName: sourceName, qualityText: qualityText, playModeText: playModeText,
            queueIndex: queueIndex, queueCount: queueCount,
            tempoBPM: tempoBPM, tempoIsAnalyzing: tempoIsAnalyzing,
            lyricText: groupDefaults?.string(forKey: "widget_lyricText") ?? "",
            playbackCurrentTime: playbackCurrentTime,
            playbackDuration: playbackDuration,
            playbackReferenceDate: playbackReferenceDate
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
        case .aperture:
            ApertureWidgetTheme(entry: entry, family: family)
        case .pager:
            PagerWidgetTheme(entry: entry, family: family, isLight: false)
        case .pagerLight:
            PagerWidgetTheme(entry: entry, family: family, isLight: true)
        case .radio:
            RadioTheme(entry: entry, family: family)
        case .dashboard:
            DashboardTheme(entry: entry, family: family)
        case .soundwave:
            SoundwaveTheme(entry: entry, family: family)
        case .typewriter:
            TypewriterWidgetTheme(entry: entry, family: family)
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
        case .aperture:
            Color(hex: "F2F2F2").ignoresSafeArea()
        case .pager, .pagerLight:
            Color.clear.ignoresSafeArea()
        case .radio:
            Color(hex: "1E1E1E").ignoresSafeArea()
        case .dashboard:
            Color(hex: "1A1A1E").ignoresSafeArea()
        case .soundwave:
            Color(hex: "151515").ignoresSafeArea()
        case .typewriter:
            Color(hex: "DED0B6").ignoresSafeArea()
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
                    .minimumScaleFactor(0.6)
                Text(entry.isEmpty ? "暂无歌曲信息" : entry.artistName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
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
                                .minimumScaleFactor(0.6)
                                .contentTransition(.interpolate)
                        }
                        ZStack(alignment: .leading) {
                            Text("playing now")
                                .font(.custom("Snell Roundhand", size: 16)).foregroundStyle(accentYellow.opacity(0.7)).offset(x: 2, y: -3)
                            Text(displayArtistName)
                                .font(.system(size: 9, weight: .medium)).foregroundStyle(inkGray).lineLimit(1).padding(.leading, 2)
                                .minimumScaleFactor(0.6)
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
                                    .minimumScaleFactor(0.6)
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
                                    .minimumScaleFactor(0.6)
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
                            .minimumScaleFactor(0.6)
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

private struct VinylWidgetAnimationFrame {
    let date: Date
    let isActive: Bool

    var time: TimeInterval {
        date.timeIntervalSinceReferenceDate
    }

    func recordRotationDegrees(base: Double) -> Double {
        guard isActive else { return base }
        return time * 42.0 + base
    }
}

private struct VinylWidgetAnimationTimeline<Content: View>: View {
    let isActive: Bool
    let fallbackDate: Date
    @ViewBuilder var content: (VinylWidgetAnimationFrame) -> Content

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { context in
            let date = isActive ? context.date : fallbackDate
            content(VinylWidgetAnimationFrame(date: date, isActive: isActive))
        }
    }
}

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
        VinylWidgetAnimationTimeline(isActive: entry.isPlaying, fallbackDate: entry.date) { animationFrame in
            switch family {
            case .systemMedium:
                mediumLayout(animationFrame: animationFrame)
            case .systemLarge:
                largeLayout(animationFrame: animationFrame)
            default:
                smallLayout(animationFrame: animationFrame)
            }
        }
    }

    private func smallLayout(animationFrame: VinylWidgetAnimationFrame) -> some View {
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
                            animationFrame: animationFrame
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
                            playbackIndicator(height: 10, compact: true, animationFrame: animationFrame)
                            Text(displayArtistName)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(dimTextColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
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

    private func mediumLayout(animationFrame: VinylWidgetAnimationFrame) -> some View {
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
                        mediumRecordStage(recordSize: recordSize, animationFrame: animationFrame)
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
                                    .minimumScaleFactor(0.6)

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
                                playbackIndicator(height: 12, compact: false, animationFrame: animationFrame)

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

    private func mediumRecordStage(recordSize: CGFloat, animationFrame: VinylWidgetAnimationFrame) -> some View {
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
                animationFrame: animationFrame
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

    private func largeLayout(animationFrame: VinylWidgetAnimationFrame) -> some View {
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
                                animationFrame: animationFrame
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
                            .minimumScaleFactor(0.6)
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
                            playbackIndicator(height: 12, compact: false, animationFrame: animationFrame)
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

    private func playbackIndicator(height: CGFloat, compact: Bool, animationFrame: VinylWidgetAnimationFrame) -> some View {
        Group {
            if entry.isPlaying {
                PlaybackWave(
                    isActive: true,
                    barCount: compact ? 3 : 4,
                    color: accentColor.opacity(0.95),
                    height: height,
                    externalTime: animationFrame.time
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
                .minimumScaleFactor(0.6)
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
            .minimumScaleFactor(0.6)
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
                .minimumScaleFactor(0.6)
            Text(value)
                .font(.system(size: compact ? 12 : 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
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
            .overlay(
                // Simulating top-left dark inner shadow (bevel)
                shape.stroke(
                    LinearGradient(
                        colors: [Color.black.opacity(0.45), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
            )
            .overlay(
                // Simulating bottom-right bright rim
                shape.stroke(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
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
    let animationFrame: VinylWidgetAnimationFrame

    private var rotationDegrees: Double {
        animationFrame.recordRotationDegrees(base: glossAngle)
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
                .fill(
                    RadialGradient(
                        colors: [Color.black.opacity(0.5), .clear],
                        center: .center, startRadius: size * 0.1, endRadius: size * 0.44
                    )
                )
                .frame(width: size * 1.05, height: size * 0.34)
                .offset(y: size * 0.40)
            
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.black.opacity(0.6), .clear],
                        center: .center, startRadius: size * 0.05, endRadius: size * 0.31
                    )
                )
                .frame(width: size * 0.72, height: size * 0.18)
                .offset(y: size * 0.43)

            ZStack {
                discPlate
                glossRing(angle: .degrees(rotationDegrees))
            }
            .rotationEffect(.degrees(rotationDegrees))
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
                    .minimumScaleFactor(0.6)

                Capsule(style: .continuous)
                    .fill(.white.opacity(0.42))
                    .frame(width: size * 0.40, height: 1.5)

                Text(labelSubtitle)
                    .font(.system(size: size * 0.085, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, size * 0.10)

                Text(labelFooter)
                    .font(.system(size: size * 0.078, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
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


// MARK: - Playback Wave

private struct PlaybackWave: View {
    let isActive: Bool
    let barCount: Int
    let color: Color
    let height: CGFloat
    var externalDate: Date?
    var externalTime: TimeInterval?

    var body: some View {
        if let time = externalTime {
            waveBody(time: time)
        } else if let date = externalDate {
            waveBody(time: date.timeIntervalSinceReferenceDate)
                .animation(.linear(duration: 0.5), value: date)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isActive)) { context in
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
        let phases: [Double] = [0.0, 1.8, 0.9, 2.7, 1.4, 3.2, 0.5, 2.3]
        let phase = phases[index % phases.count]
        let wave = sin(time * 12.0 + phase) * 0.5 + 0.5
        let minScale: CGFloat = 0.15
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
    private var displayArtist: String { entry.isEmpty ? "mono" : entry.artistName }
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
                        .minimumScaleFactor(0.6)
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
                        .minimumScaleFactor(0.6)
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
                                .minimumScaleFactor(0.6)
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
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 20)
                    .padding(.top, 3)

                if !entry.albumName.isEmpty {
                    Text(entry.albumName)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
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
    var tailOffset: CGFloat = 34

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
    
    private var period: TimeInterval {
        switch type {
        case .pulse:
            return 1.6
        case .twinkle:
            return 2.4
        case .wobble:
            return 4.0
        case .float:
            return 3.0
        }
    }

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let phase = phaseValue(for: timeline.date)
            animated(content: content, phase: phase)
        }
    }

    @ViewBuilder
    private func animated(content: Content, phase: CGFloat) -> some View {
        switch type {
        case .pulse:
            content.scaleEffect(1.0 + 0.15 * phase)
        case .twinkle:
            content
                .scaleEffect(0.85 + 0.25 * phase)
                .opacity(0.6 + 0.4 * phase)
        case .wobble:
            content.rotationEffect(.degrees(-6 + 12 * Double(phase)))
        case .float:
            content.offset(y: 3 - 6 * phase)
        }
    }

    private func phaseValue(for date: Date) -> CGFloat {
        let raw = date.timeIntervalSinceReferenceDate / period
        let wave = (sin(raw * .pi * 2.0) + 1.0) * 0.5
        return CGFloat(wave)
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
                    .minimumScaleFactor(0.6)
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
                HStack(spacing: 2) {
                    Text("\(b)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(inkSub.opacity(0.8))
                    
                    ZStack {
                        MangaHeartShape().fill(accentPink)
                        MangaHeartShape().stroke(ink, lineWidth: 1.5)
                    }
                    .frame(width: 9, height: 8)
                    .offset(y: -1)
                    .modifier(MangaMicroAnimator(type: .pulse))
                    
                    Text("bpm")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(inkSub.opacity(0.8))
                }
            } else {
                ZStack {
                    MangaHeartShape().fill(accentPink)
                    MangaHeartShape().stroke(ink, lineWidth: 1.5)
                }
                .frame(width: 12, height: 10)
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
                                .minimumScaleFactor(0.4)
                                
                            Text(artist)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(inkSub)
                                .lineLimit(2)
                                .minimumScaleFactor(0.4)
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
                    HStack(alignment: .center, spacing: 14) { // Reverted back to .center for layout symmetry
                        coverView(side: 104) // Much larger cover taking full height
                        
                        // Right column layout
                        VStack(alignment: .leading, spacing: 10) { // Increased spacing to detach play controls from bubble
                            mangaBubble {
                                VStack(alignment: .leading, spacing: 2) {
                                    Spacer().frame(height: 10) // Internal top buffer for the overlay header

                                    Text(song)
                                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                                        .foregroundStyle(ink)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.4)

                                    Text(artist)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(inkSub)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.4)

                                    if !lyric.isEmpty {
                                        Rectangle()
                                            .fill(ink.opacity(0.12))
                                            .frame(height: 1)
                                            .padding(.vertical, 2)

                                        Text(lyric)
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundStyle(ink.opacity(0.8))
                                            .lineLimit(4) // Cap at 4 lines so the engine can bound and scale the text instead of discarding it out of bounds
                                            .minimumScaleFactor(0.5) // Gracefully scale down text size if it fills up the entire layout height
                                    }
                                }
                            }
                            .overlay(alignment: .topLeading) {
                                nowPlayingHeader
                                    .alignmentGuide(.top) { d in d[VerticalAlignment.center] }
                                    .offset(x: 24, y: 0)
                            }
                            // Extra space below the bubble to accommodate play controls tightly
                            
                            if !entry.isEmpty {
                                HStack(spacing: 6) {
                                    mediaButton(intent: PreviousTrackIntent(), icon: "backward.fill", w: 26, h: 22, style: .normal)
                                    mediaButton(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, w: 32, h: 32, style: .play)
                                    mediaButton(intent: NextTrackIntent(), icon: "forward.fill", w: 26, h: 22, style: .normal)
                                }
                                .padding(.leading, 8) // Align perfectly flush with the bubble's square edge (bypassing the tail width)
                                .padding(.bottom, 8) // Minimized padding to push bubble downward
                            } else {
                                Spacer().frame(height: 32)
                            }
                        }
                        .padding(.top, 24) // Give room for header popping out of top bounds
                    }
                    .frame(maxHeight: .infinity) // Force HStack to capture total fixed widget height, preventing cover from moving when content grows
                    .padding(.horizontal, 16)
                    
                    // BPM Footer overlaid globally bottom right
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            bpmFooter
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
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
                        .minimumScaleFactor(0.4)
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
                            .lineLimit(5)
                            .minimumScaleFactor(0.4)
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
                            .minimumScaleFactor(0.6)
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
                        .minimumScaleFactor(0.6)
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
                            .minimumScaleFactor(0.6)
                            .padding(.top, 4)

                        if !entry.albumName.isEmpty {
                            Text(entry.albumName)
                                .font(.system(size: 10, weight: .regular, design: .serif))
                                .foregroundStyle(inkLight.opacity(0.7))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
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



// MARK: - Aperture Theme (圆窗唱片)

struct ApertureWidgetTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    private let paperTop = Color(hex: "F2F2F2")
    private let paperBottom = Color(hex: "DFDFDF")
    private let ink = Color(hex: "24231E")
    private let mutedInk = Color(hex: "9B9B98")
    private let rule = Color.black.opacity(0.10)
    private let consoleFill = Color.white.opacity(0.34)

    private var song: String { entry.isEmpty ? "未在播放" : entry.songName }
    private var artist: String { entry.isEmpty ? "暂无歌曲信息" : entry.artistName }
    private var totalSeconds: Int {
        guard entry.playbackDuration.isFinite, entry.playbackDuration > 0 else { return 0 }
        return Int(entry.playbackDuration.rounded(.down))
    }
    private var durationText: String {
        totalSeconds > 0 ? formatTime(totalSeconds) : "--:--"
    }

    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        case .systemLarge: largeLayout
        default: smallLayout
        }
    }

    private var smallLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let radius = min(w, h) * 0.18
            let discSide = w * 1.16

            ZStack(alignment: .top) {
                apertureSurface

                coverDisc(side: discSide, hubSize: w * 0.32)
                    .offset(y: -discSide * 0.56)

                smallInfoStack(
                    width: w * 0.76,
                    controlSize: min(19, w * 0.125)
                )
                .padding(.top, h * 0.43)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(cardStroke(radius: radius))
            .widgetURL(URL(string: "monologue://player"))
        }
    }

    private var mediumLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let radius = min(h * 0.24, 28)
            let pad: CGFloat = 10
            let discSide = min(h - pad * 2.3, 130)
            let deckHeight = h - pad * 2

            ZStack {
                apertureSurface

                mediumDeck(width: w, height: h, pad: pad, deckHeight: deckHeight, discSide: discSide)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(cardStroke(radius: radius))
            .widgetURL(URL(string: "monologue://player"))
        }
    }

    private var largeLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let panelHeight = min(h * 0.44, 154)
            let heroHeight = max(144, h - panelHeight - 14)

            ZStack {
                apertureSurface

                VStack(spacing: 0) {
                    largeHero(width: w, height: heroHeight)

                    largePlayerPanel(width: w - 28, height: panelHeight)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                }
            }
            .frame(width: w, height: h)
            .clipShape(ContainerRelativeShape())
            .overlay(
                ContainerRelativeShape()
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .widgetURL(URL(string: "monologue://player"))
        }
    }

    private func smallInfoStack(width: CGFloat, controlSize: CGFloat) -> some View {
        TimelineView(.periodic(from: entry.playbackReferenceDate, by: 1.0)) { timeline in
            let activeDate = entry.isPlaying ? timeline.date : entry.playbackReferenceDate
            let activeSeconds = playbackSeconds(at: activeDate)
            let progress = progressValue(at: activeDate)

            VStack(spacing: 2) {
                Image(systemName: entry.statusSymbolName)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(mutedInk.opacity(0.78))
                    .contentTransition(.symbolEffect(.replace))

                Text(artist)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(ink.opacity(0.32))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Text(song)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ink.opacity(entry.isEmpty ? 0.42 : 0.96))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)

                progressBar(width: 38, progress: progress)
                    .padding(.top, 1)

                timeRow(fontSize: 11, currentSeconds: activeSeconds)

                transportControls(
                    buttonSize: controlSize,
                    playSize: controlSize + 3,
                    spacing: width * 0.06,
                    elevated: false
                )
                .padding(.top, 1)
            }
            .frame(width: width)
        }
    }

    private func mediumDeck(
        width: CGFloat,
        height: CGFloat,
        pad: CGFloat,
        deckHeight: CGFloat,
        discSide: CGFloat
    ) -> some View {
        let deckWidth = width - pad * 2
        let contentLeft = pad + discSide * 0.82
        let contentWidth = max(122, width - contentLeft - pad * 1.5)

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: deckHeight * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.36),
                            Color.white.opacity(0.20),
                            paperBottom.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: deckHeight * 0.28, style: .continuous)
                        .stroke(Color.white.opacity(0.46), lineWidth: 1)
                )
                .overlay(
                    HStack(spacing: 5) {
                        ForEach(0..<12, id: \.self) { index in
                            Capsule()
                                .fill(Color.black.opacity(index % 3 == 0 ? 0.08 : 0.045))
                                .frame(width: 1, height: deckHeight * (index % 3 == 0 ? 0.68 : 0.46))
                        }
                    }
                    .padding(.leading, discSide + 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .blendMode(.multiply)
                )
                .frame(width: deckWidth, height: deckHeight)
                .offset(x: pad)
                .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 6)

            mediumEmbeddedDisc(side: discSide)
                .offset(x: pad + 3)

            mediumPanel(width: contentWidth, height: deckHeight - 20)
                .offset(x: contentLeft)
        }
        .frame(width: width, height: height)
    }

    private func mediumEmbeddedDisc(side: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(paperTop.opacity(0.94))
                .frame(width: side + 14, height: side + 14)
                .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)

            coverDisc(side: side, hubSize: side * 0.26)

            Circle()
                .stroke(Color.white.opacity(0.72), lineWidth: 4)
                .frame(width: side + 5, height: side + 5)

            Circle()
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                .frame(width: side + 15, height: side + 15)
        }
        .frame(width: side + 16, height: side + 16)
    }

    private func mediumPanel(width: CGFloat, height: CGFloat) -> some View {
        TimelineView(.periodic(from: entry.playbackReferenceDate, by: 1.0)) { timeline in
            let activeDate = entry.isPlaying ? timeline.date : entry.playbackReferenceDate
            let activeSeconds = playbackSeconds(at: activeDate)
            let progress = progressValue(at: activeDate)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    statusBadge(entry.isPlaying ? "PLAYING" : "READY", fontSize: 8)
                    Spacer(minLength: 6)
                    Text(formatTime(activeSeconds))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(ink.opacity(0.36))
                        .monospacedDigit()
                }

                Spacer(minLength: 4)

                Text(song)
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ink.opacity(entry.isEmpty ? 0.46 : 0.98))
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)
                    .fixedSize(horizontal: false, vertical: true)

                Text(artist)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(ink.opacity(0.34))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.top, 3)

                HStack(spacing: 8) {
                    progressBar(width: min(width * 0.62, 118), progress: progress)
                    Text(durationText)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(ink.opacity(0.28))
                        .monospacedDigit()
                }
                .padding(.top, 8)

                Spacer(minLength: 6)

                HStack {
                    Image(systemName: entry.statusSymbolName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(mutedInk.opacity(0.72))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.white.opacity(0.32)))
                        .contentTransition(.symbolEffect(.replace))
                    Spacer(minLength: 8)
                    transportControls(buttonSize: 25, playSize: 35, spacing: 10, elevated: true)
                }
            }
            .padding(.vertical, 1)
            .frame(width: width, height: height, alignment: .leading)
        }
    }

    private func largeHero(width: CGFloat, height: CGFloat) -> some View {
        let side = width * 0.92

        return TimelineView(.periodic(from: entry.playbackReferenceDate, by: 1.0)) { timeline in
            let activeDate = entry.isPlaying ? timeline.date : entry.playbackReferenceDate
            let activeSeconds = playbackSeconds(at: activeDate)

            ZStack(alignment: .topTrailing) {
                coverDisc(side: side, hubSize: side * 0.25)
                    .offset(x: -width * 0.18, y: -side * 0.30)

                VStack(alignment: .trailing, spacing: 7) {
                    statusBadge("APERTURE", fontSize: 10)
                    Text(formatTime(activeSeconds))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(ink.opacity(0.42))
                        .monospacedDigit()
                }
                .padding(.top, 18)
                .padding(.trailing, 20)
            }
            .frame(width: width, height: height)
            .clipped()
        }
    }

    private func largePlayerPanel(width: CGFloat, height: CGFloat) -> some View {
        TimelineView(.periodic(from: entry.playbackReferenceDate, by: 1.0)) { timeline in
            let activeDate = entry.isPlaying ? timeline.date : entry.playbackReferenceDate
            let activeSeconds = playbackSeconds(at: activeDate)
            let progress = progressValue(at: activeDate)

            VStack(alignment: .leading, spacing: 0) {
                Text(artist.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ink.opacity(0.34))
                    .tracking(1.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Text(song)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ink.opacity(entry.isEmpty ? 0.46 : 0.98))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .padding(.top, 5)

                HStack(spacing: 10) {
                    progressBar(width: min(width * 0.58, 174), progress: progress)
                    timeRow(fontSize: 13, currentSeconds: activeSeconds)
                        .layoutPriority(1)
                }
                .padding(.top, 10)

                Spacer(minLength: 10)

                HStack {
                    Text(entry.sourceName.isEmpty ? "ASIDE" : entry.sourceName.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(ink.opacity(0.28))
                        .tracking(1.4)

                    Spacer(minLength: 12)

                    transportControls(buttonSize: 36, playSize: 58, spacing: 18, elevated: true)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(consoleFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.50), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
        }
    }

    private func statusBadge(_ text: String, fontSize: CGFloat) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
            .foregroundStyle(ink.opacity(0.46))
            .tracking(1.2)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.32))
                    .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
            )
    }

    private func transportControls(buttonSize: CGFloat, playSize: CGFloat, spacing: CGFloat, elevated: Bool) -> some View {
        HStack(spacing: spacing) {
            apertureControlButton(intent: PreviousTrackIntent(), icon: "backward.fill", size: buttonSize, isPrimary: false, elevated: elevated)
            apertureControlButton(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, size: playSize, isPrimary: true, elevated: elevated)
            apertureControlButton(intent: NextTrackIntent(), icon: "forward.fill", size: buttonSize, isPrimary: false, elevated: elevated)
        }
    }

    private func apertureControlButton<I: AppIntent>(
        intent: I,
        icon: String,
        size: CGFloat,
        isPrimary: Bool,
        elevated: Bool
    ) -> some View {
        Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: size * (isPrimary ? 0.34 : 0.32), weight: .semibold))
                .foregroundStyle(isPrimary ? paperTop : ink.opacity(0.62))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isPrimary ? ink : Color.white.opacity(elevated ? 0.56 : 0.20))
                        .overlay(
                            Circle()
                                .stroke(isPrimary ? Color.white.opacity(0.10) : Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(
                            color: Color.black.opacity(elevated ? 0.16 : 0.06),
                            radius: elevated ? 7 : 2,
                            x: 0,
                            y: elevated ? 4 : 1
                        )
                )
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }

    private var apertureSurface: some View {
        ZStack {
            LinearGradient(colors: [paperTop, paperBottom], startPoint: .top, endPoint: .bottom)

            LinearGradient(
                colors: [Color.white.opacity(0.55), Color.clear, Color.black.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func cardStroke(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(Color.black.opacity(0.10), lineWidth: 1)
    }

    private func coverDisc(side: CGFloat, hubSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            entry.secondaryColor.opacity(0.88),
                            entry.dominantColor.opacity(0.9),
                            Color(hex: "ECEAE7"),
                            entry.dominantColor.opacity(0.78),
                            entry.secondaryColor.opacity(0.88)
                        ],
                        center: .center
                    )
                )

            if let data = entry.coverImageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: side, height: side)
                    .clipShape(Circle())
            }

            LinearGradient(
                colors: [Color.white.opacity(0.22), Color.clear, Color.black.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(Circle())

            Circle()
                .stroke(Color.black.opacity(0.14), lineWidth: 1)

            discHub(size: hubSize)
        }
        .frame(width: side, height: side)
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
    }

    private func discHub(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: "C9C9C9"))
            Circle()
                .stroke(Color.white.opacity(0.70), lineWidth: max(2, size * 0.08))
                .padding(size * 0.12)
            Circle()
                .stroke(Color(hex: "8E8E94").opacity(0.36), lineWidth: max(1, size * 0.03))
                .padding(size * 0.22)
            Circle()
                .trim(from: 0.08, to: 0.42)
                .stroke(
                    Color(hex: "B4A92F").opacity(0.58),
                    style: StrokeStyle(lineWidth: max(2, size * 0.04), lineCap: .round)
                )
                .rotationEffect(.degrees(84))
                .padding(size * 0.02)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.16), radius: 4, x: 0, y: 2)
    }

    private func infoStack(
        width: CGFloat,
        iconSize: CGFloat,
        artistSize: CGFloat,
        songSize: CGFloat,
        timeSize: CGFloat,
        progressWidth: CGFloat,
        spacing: CGFloat
    ) -> some View {
        VStack(spacing: spacing) {
            Image(systemName: entry.statusSymbolName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(mutedInk.opacity(0.78))
                .contentTransition(.symbolEffect(.replace))

            Text(artist)
                .font(.system(size: artistSize, weight: .medium, design: .monospaced))
                .foregroundStyle(ink.opacity(0.32))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .contentTransition(.interpolate)

            Text(song)
                .font(.system(size: songSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(ink.opacity(entry.isEmpty ? 0.42 : 0.96))
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .contentTransition(.interpolate)

            progressBar(width: progressWidth, progress: progressValue(at: entry.playbackReferenceDate))
                .padding(.top, spacing * 0.28)

            timeRow(fontSize: timeSize, currentSeconds: playbackSeconds(at: entry.playbackReferenceDate))
                .padding(.top, spacing * 0.2)
        }
        .frame(width: width)
    }

    private func progressBar(width: CGFloat, progress: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(rule)
            Rectangle()
                .fill(Color.black.opacity(entry.isEmpty ? 0.16 : 0.40))
                .frame(width: width * progress)
        }
        .frame(width: width, height: 4)
    }

    private func timeRow(fontSize: CGFloat, currentSeconds: Int) -> some View {
        HStack(spacing: max(6, fontSize * 0.35)) {
            Text(formatTime(currentSeconds))
                .foregroundStyle(ink.opacity(entry.isEmpty ? 0.38 : 0.98))
            Text("/")
                .foregroundStyle(ink.opacity(0.32))
            Text(durationText)
                .foregroundStyle(ink.opacity(0.32))
        }
        .font(.system(size: fontSize, weight: .medium, design: .monospaced))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.65)
    }

    private func progressValue(at date: Date) -> CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(min(max(playbackTime(at: date) / Double(totalSeconds), 0), 1))
    }

    private func playbackSeconds(at date: Date) -> Int {
        Int(playbackTime(at: date).rounded(.down))
    }

    private func playbackTime(at date: Date) -> TimeInterval {
        let baseTime = max(0, entry.playbackCurrentTime)
        let elapsed = entry.isPlaying ? max(0, date.timeIntervalSince(entry.playbackReferenceDate)) : 0
        let activeTime = baseTime + elapsed
        guard totalSeconds > 0 else { return activeTime }
        return min(activeTime, Double(totalSeconds))
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainder = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainder)
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
                            .minimumScaleFactor(0.4)
                            .contentTransition(.interpolate)

                        Text(artist)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(amber.opacity(0.4))
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)

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
                                .minimumScaleFactor(0.4)
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
                                    .minimumScaleFactor(0.4)
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
                                .minimumScaleFactor(0.4)
                                .contentTransition(.interpolate)

                            VStack(alignment: .center, spacing: 6) {
                                Text(artist)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(amber.opacity(0.55))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.4)

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
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(" P A G E R")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(brandBright)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

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

// MARK: - Radio Theme (收音机)

struct RadioTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    private let chassis = Color(hex: "1E1E1E")
    private let chassisDeep = Color(hex: "111112")
    private let lcd = Color(hex: "3CBDAE")
    private let lcdHot = Color(hex: "71E4D5")
    private let lcdInk = Color(hex: "111112")
    private let tunerInk = Color.white.opacity(0.92)
    private let tunerTick = Color.white.opacity(0.18)

    private var song: String { entry.isEmpty ? "FM Radio" : entry.songName }
    private var artist: String { entry.isEmpty ? "Tune In" : entry.artistName }
    private var statusText: String {
        if entry.isLoading { return "SCAN" }
        return entry.isPlaying ? "LIVE" : "STBY"
    }
    private var frequencySeed: Int {
        (song + artist).unicodeScalars.reduce(0) { $0 + Int($1.value) }
    }
    private var frequencyText: String {
        let value = entry.isEmpty ? 101.4 : 101.0 + Double(frequencySeed % 19) / 10.0
        return String(format: "%.1f", value)
    }

    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        case .systemLarge: largeLayout
        default: smallLayout
        }
    }

    private var smallLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pad: CGFloat = max(7, min(w, h) * 0.045)
            let innerW = w - pad * 2
            let innerH = h - pad * 2
            let screenH = innerH * 0.48
            let tunerH = innerH * 0.22
            let buttonSize = min(innerW * 0.18, 22)

            ZStack {
                radioBody(cornerRadius: min(w, h) * 0.18)

                VStack(spacing: 4) {
                    lcdPanel(width: innerW, height: screenH, compact: true)
                    tunerStrip(width: innerW, height: tunerH, showLabels: true)
                    if !entry.isEmpty {
                        controls(buttonSize: buttonSize, spacing: innerW * 0.08)
                    }
                }
                .padding(pad)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    private var mediumLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pad: CGFloat = 10
            let innerW = w - pad * 2
            let innerH = h - pad * 2
            let screenW = min(innerW * 0.54, innerH * 1.38)
            let sideW = innerW - screenW - 10

            ZStack {
                radioBody(cornerRadius: 26)

                HStack(spacing: 10) {
                    lcdPanel(width: screenW, height: innerH, compact: false)

                    VStack(alignment: .leading, spacing: 7) {
                        stationInfo(compact: true)
                        tunerStrip(width: sideW, height: min(50, innerH * 0.36), showLabels: true)
                        if !entry.isEmpty {
                            controls(buttonSize: 29, spacing: 11)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .frame(width: sideW, height: innerH)
                }
                .padding(pad)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    private var largeLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pad: CGFloat = 14
            let innerW = w - pad * 2
            let innerH = h - pad * 2
            let screenH = min(innerH * 0.44, 154)
            let tunerH = min(innerH * 0.19, 66)

            ZStack {
                radioBody(cornerRadius: 38)

                VStack(spacing: 9) {
                    lcdPanel(width: innerW, height: screenH, compact: false)
                    stationInfo(compact: false)
                    tunerStrip(width: innerW, height: tunerH, showLabels: true)
                    if !entry.isEmpty {
                        controls(buttonSize: 36, spacing: 18)
                    }
                }
                .padding(pad)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    private func radioBody(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "252525"), chassis, chassisDeep],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.55), lineWidth: 2)
                    .padding(1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
    }

    private func lcdPanel(width: CGFloat, height: CGFloat, compact: Bool) -> some View {
        let radius = min(width, height) * (compact ? 0.20 : 0.28)
        let freqSize = min(height * (compact ? 0.42 : 0.48), width * (compact ? 0.26 : 0.25))
        let unitSize = max(10, min(freqSize * 0.34, compact ? 16 : 24))
        let badgeSize = max(9, min(height * 0.18, compact ? 15 : 22))

        return ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(lcd)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [lcdHot.opacity(0.85), lcd.opacity(0.92), Color(hex: "278C82").opacity(0.92)],
                                center: .center,
                                startRadius: 0,
                                endRadius: max(width, height) * 0.7
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .overlay(lcdScanlines(width: width, height: height, radius: radius))
                .overlay(lcdVerticalGrid(radius: radius))

            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text("FM")
                        .font(.system(size: badgeSize, weight: .black, design: .monospaced))
                        .foregroundStyle(lcd)
                        .padding(.horizontal, compact ? 5 : 8)
                        .padding(.vertical, compact ? 2 : 4)
                        .background(lcdInk.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: compact ? 4 : 7, style: .continuous))

                    Spacer(minLength: 4)

                    Text(statusText)
                        .font(.system(size: max(8, badgeSize * 0.62), weight: .bold, design: .monospaced))
                        .foregroundStyle(lcdInk.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: compact ? 2 : 5) {
                    Text(frequencyText)
                        .font(.system(size: freqSize, weight: .heavy, design: .monospaced))
                        .foregroundStyle(lcdInk)
                        .monospacedDigit()
                    Text("KHz")
                        .font(.system(size: unitSize, weight: .heavy, design: .monospaced))
                        .foregroundStyle(lcdInk)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                Text(song.uppercased())
                    .font(.system(size: compact ? 7 : 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(lcdInk.opacity(compact ? 0.55 : 0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, compact ? 9 : 16)
            .padding(.vertical, compact ? 8 : 14)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .shadow(color: lcd.opacity(0.32), radius: compact ? 8 : 14, x: 0, y: 0)
        .shadow(color: Color.black.opacity(0.45), radius: 4, x: 0, y: 3)
    }

    private func lcdScanlines(width: CGFloat, height: CGFloat, radius: CGFloat) -> some View {
        VStack(spacing: max(3, height / 18)) {
            ForEach(0..<12, id: \.self) { _ in
                Rectangle()
                    .fill(lcdInk.opacity(0.07))
                    .frame(height: 1)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private func lcdVerticalGrid(radius: CGFloat) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<28, id: \.self) { _ in
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)
            }
        }
        .blendMode(.softLight)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private func tunerStrip(width: CGFloat, height: CGFloat, showLabels: Bool) -> some View {
        let tickCount = 25
        let markerWidth = max(5, min(width * 0.045, 14))

        return ZStack {
            RoundedRectangle(cornerRadius: min(18, height * 0.33), style: .continuous)
                .fill(Color.black.opacity(0.12))

            VStack(spacing: 0) {
                if showLabels {
                    HStack {
                        Text("101")
                        Spacer()
                        Text("102")
                    }
                    .font(.system(size: max(9, height * 0.22), weight: .bold, design: .monospaced))
                    .foregroundStyle(tunerInk)
                    .monospacedDigit()
                    .padding(.horizontal, width * 0.17)
                    .padding(.top, max(2, height * 0.08))
                }

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    ForEach(0..<tickCount, id: \.self) { index in
                        let isMajor = index % 6 == 0
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(isMajor ? tunerInk.opacity(0.34) : tunerTick)
                            .frame(width: isMajor ? 2 : 1, height: height * (isMajor ? 0.32 : 0.2))
                        if index < tickCount - 1 {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, width * 0.08)
                .padding(.bottom, max(5, height * 0.12))
            }

            RoundedRectangle(cornerRadius: markerWidth / 2, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .frame(width: markerWidth, height: height * 0.78)
                .shadow(color: Color.white.opacity(0.35), radius: 3, x: 0, y: 0)
        }
        .frame(width: width, height: height)
    }

    private func stationInfo(compact: Bool) -> some View {
        HStack(spacing: compact ? 7 : 10) {
            coverTile(size: compact ? 30 : 44)

            VStack(alignment: .leading, spacing: compact ? 1 : 3) {
                Text(song)
                    .font(.system(size: compact ? 12 : 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .contentTransition(.interpolate)

                Text(artist)
                    .font(.system(size: compact ? 9 : 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.52))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .contentTransition(.interpolate)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func coverTile(size: CGFloat) -> some View {
        if let data = entry.coverImageData,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "radio")
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(lcd.opacity(0.9))
                )
        }
    }

    @ViewBuilder
    private func controls(buttonSize: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            radioButton(intent: PreviousTrackIntent(), icon: "backward.fill", size: buttonSize, isMain: false)
            radioButton(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, size: buttonSize * 1.12, isMain: true)
            radioButton(intent: NextTrackIntent(), icon: "forward.fill", size: buttonSize, isMain: false)
        }
    }

    private func radioButton<I: AppIntent>(intent: I, icon: String, size: CGFloat, isMain: Bool) -> some View {
        Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: size * 0.34, weight: .black))
                .foregroundStyle(isMain ? lcdInk : Color.white.opacity(0.86))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isMain ? lcd : Color.white.opacity(0.08))
                        .overlay(
                            Circle()
                                .stroke(isMain ? lcdHot.opacity(0.45) : Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.38), radius: 3, x: 0, y: 2)
                )
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Legacy Radio Theme

private struct LegacyRadioTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    // 从封面取色生成动态配色
    private var dominantColor: Color {
        guard entry.dominantRGB.count == 3, !entry.isEmpty else { return Color(hex: "D0CEC8") }
        return Color(red: Double(entry.dominantRGB[0]), green: Double(entry.dominantRGB[1]), blue: Double(entry.dominantRGB[2]))
    }

    private var secondaryColor: Color {
        guard entry.secondaryRGB.count == 3, !entry.isEmpty else { return Color(hex: "E8E6E2") }
        return Color(red: Double(entry.secondaryRGB[0]), green: Double(entry.secondaryRGB[1]), blue: Double(entry.secondaryRGB[2]))
    }

    /// 背景色：封面主色 → 调高亮度、降低饱和度，保持柔和拟物感
    private var bgTop: Color {
        guard entry.dominantRGB.count == 3, !entry.isEmpty else { return Color(hex: "F0EEEA") }
        let r = Double(entry.dominantRGB[0])
        let g = Double(entry.dominantRGB[1])
        let b = Double(entry.dominantRGB[2])
        // 混合白色 75%，保留 25% 色调
        return Color(red: r * 0.25 + 0.75, green: g * 0.25 + 0.75, blue: b * 0.25 + 0.75)
    }

    private var bgBottom: Color {
        guard entry.dominantRGB.count == 3, !entry.isEmpty else { return Color(hex: "E6E4E0") }
        let r = Double(entry.dominantRGB[0])
        let g = Double(entry.dominantRGB[1])
        let b = Double(entry.dominantRGB[2])
        // 混合白色 65%，保留 35% 色调，略深
        return Color(red: r * 0.35 + 0.65, green: g * 0.35 + 0.65, blue: b * 0.35 + 0.65)
    }

    // 文字
    private let textPrimary = Color(hex: "2C2C2C")
    private let textSecondary = Color(hex: "9A9A9A")
    private let fmColor = Color(hex: "A0A0A0")

    // 刻度盘 — 跟随背景色调
    private var dialScreenBg: Color {
        guard entry.dominantRGB.count == 3, !entry.isEmpty else { return Color(hex: "D8D6D2") }
        let r = Double(entry.dominantRGB[0])
        let g = Double(entry.dominantRGB[1])
        let b = Double(entry.dominantRGB[2])
        return Color(red: r * 0.3 + 0.56, green: g * 0.3 + 0.56, blue: b * 0.3 + 0.56)
    }

    private var dialScreenTop: Color {
        guard entry.dominantRGB.count == 3, !entry.isEmpty else { return Color(hex: "E2E0DC") }
        let r = Double(entry.dominantRGB[0])
        let g = Double(entry.dominantRGB[1])
        let b = Double(entry.dominantRGB[2])
        return Color(red: r * 0.25 + 0.63, green: g * 0.25 + 0.63, blue: b * 0.25 + 0.63)
    }

    private let dialInnerShadow = Color(hex: "B0AEA8")
    private let tickColor = Color(hex: "B0ADA6")
    private let tickMajorColor = Color(hex: "9A9894")
    private let needleColor = Color(hex: "A8A6A0")
    private let freqColor = Color(hex: "8A8884")

    // 按钮
    private let btnTopColor = Color(hex: "F2F0EC")
    private let btnBottomColor = Color(hex: "E0DDD8")
    private let btnShadowColor = Color(hex: "C0BDB6")
    private let btnIconColor = Color(hex: "7A7874")

    private var song: String { entry.isEmpty ? "FM Radio" : entry.songName }
    private var artist: String { entry.isEmpty ? "Tune In" : entry.artistName }

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
            let h = geo.size.height
            let btnSz: CGFloat = min(w * 0.21, 30)

            VStack(spacing: 0) {
                // FM 标签
                HStack {
                    Spacer()
                    Text("FM")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(fmColor)
                }
                .padding(.trailing, 14)
                .padding(.top, 10)

                // 频率刻度盘 — 凹陷屏幕
                radioDialScreen(width: w - 24, height: h * 0.35)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                // 歌曲信息
                VStack(alignment: .leading, spacing: 1) {
                    Text(song)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.interpolate)

                    Text(artist)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.interpolate)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.top, 6)

                Spacer(minLength: 2)

                // 控制按钮
                if !entry.isEmpty {
                    HStack(spacing: w * 0.06) {
                        radioKnob(intent: PreviousTrackIntent(), icon: "backward.fill", size: btnSz, isMain: false)
                        radioKnob(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, size: btnSz + 6, isMain: true)
                        radioKnob(intent: NextTrackIntent(), icon: "forward.fill", size: btnSz, isMain: false)
                    }
                    .padding(.bottom, 12)
                } else {
                    Spacer().frame(height: 12)
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Medium

    private var mediumLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let coverSize: CGFloat = h - 24
            let btnSz: CGFloat = 28

            HStack(spacing: 0) {
                // 左侧 — 凹陷封面框
                ZStack {
                    // 凹陷底座
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [bgBottom.opacity(0.6), bgBottom.opacity(0.4)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.05), Color.clear],
                                        startPoint: .top, endPoint: .center
                                    )
                                )
                        )
                        .frame(width: coverSize, height: coverSize)

                    // 封面图片
                    if let data = entry.coverImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: coverSize - 8, height: coverSize - 8)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        Image(systemName: "radio")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(textSecondary.opacity(0.5))
                    }
                }
                .frame(width: coverSize + 4)
                .padding(.leading, 12)

                // 右侧 — 信息和控制
                VStack(alignment: .leading, spacing: 0) {
                    // RADIO + 音质
                    HStack {
                        Text("RADIO")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(fmColor)
                            .tracking(1)
                        Spacer()
                        if !entry.qualityText.isEmpty {
                            Text(entry.qualityText)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(fmColor.opacity(0.7))
                                .italic()
                        }
                    }
                    .padding(.top, 10)

                    // 频率刻度盘
                    radioDialScreen(width: w - coverSize - 44, height: 42)
                        .padding(.top, 4)

                    // 歌曲信息
                    Text(song)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.interpolate)
                        .padding(.top, 5)

                    Text(artist)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.interpolate)
                        .padding(.top, 1)

                    Spacer(minLength: 2)

                    // 控制按钮
                    if !entry.isEmpty {
                        HStack(spacing: 12) {
                            radioKnob(intent: PreviousTrackIntent(), icon: "backward.fill", size: btnSz, isMain: false)
                            radioKnob(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, size: btnSz + 4, isMain: true)
                            radioKnob(intent: NextTrackIntent(), icon: "forward.fill", size: btnSz, isMain: false)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 10)
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 14)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Large

    private var largeLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // 封面高度基于可用空间计算，预留顶部(40)+刻度盘(66)+歌曲信息(50)+格栅(16)+按钮(60)=232
            let coverH: CGFloat = min(h - 230, w * 0.5)
            let coverW: CGFloat = w - 40
            let btnSz: CGFloat = 36

            VStack(spacing: 0) {
                // 顶部：RADIO + 音质
                HStack {
                    Text("RADIO")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(fmColor)
                        .tracking(1.5)
                    Spacer()
                    if !entry.qualityText.isEmpty {
                        Text(entry.qualityText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(fmColor.opacity(0.7))
                            .italic()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                // 频率刻度盘
                radioDialScreen(width: w - 36, height: 58)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                // 凹陷封面框
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [bgBottom.opacity(0.5), bgBottom.opacity(0.35)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.04), Color.clear],
                                        startPoint: .top, endPoint: .center
                                    )
                                )
                        )
                        .frame(width: coverW, height: coverH)

                    if let data = entry.coverImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: coverW - 10, height: coverH - 10)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Image(systemName: "radio")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(textSecondary.opacity(0.4))
                    }
                }
                .padding(.top, 10)

                // 歌曲信息
                VStack(alignment: .leading, spacing: 3) {
                    Text(song)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.interpolate)

                    Text(artist)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.interpolate)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer(minLength: 6)

                // 装饰扬声器格栅线
                HStack(spacing: 3) {
                    ForEach(0..<Int(w / 5), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(btnShadowColor.opacity(0.15))
                            .frame(width: 1, height: 6)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

                // 控制按钮
                if !entry.isEmpty {
                    HStack(spacing: 18) {
                        radioKnob(intent: PreviousTrackIntent(), icon: "backward.fill", size: btnSz, isMain: false)
                        radioKnob(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, size: btnSz + 8, isMain: true)
                        radioKnob(intent: NextTrackIntent(), icon: "forward.fill", size: btnSz, isMain: false)
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - 凹陷频率刻度盘

    /// 模拟参考图中的凹陷屏幕：深色背景，频率数字在顶部，长刻度线贯穿，半透明指针
    private func radioDialScreen(width: CGFloat, height: CGFloat) -> some View {
        let frequencies = [88, 92, 96, 100, 104, 108]
        let totalTicks = 26 // 每个区间5格 × 5区间 + 首尾 = 26

        return ZStack {
            // 凹陷屏幕背景
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [dialScreenTop, dialScreenBg, dialScreenBg.opacity(0.95)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                // 内阴影效果 — 凹陷感
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(dialInnerShadow.opacity(0.5), lineWidth: 1)
                )
                .overlay(
                    // 顶部内阴影
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.06), Color.clear],
                                startPoint: .top, endPoint: .center
                            )
                        )
                )

            // 内容
            VStack(spacing: 0) {
                // 频率数字
                HStack(spacing: 0) {
                    ForEach(frequencies, id: \.self) { freq in
                        Text("\(freq)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(freqColor)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)

                Spacer(minLength: 2)

                // 刻度线区域
                ZStack(alignment: .bottom) {
                    // 刻度线
                    HStack(spacing: 0) {
                        ForEach(0..<totalTicks, id: \.self) { i in
                            let isMajor = i % 5 == 0
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                Rectangle()
                                    .fill(isMajor ? tickMajorColor : tickColor.opacity(0.6))
                                    .frame(width: isMajor ? 1.2 : 0.8, height: isMajor ? height * 0.48 : height * 0.32)
                            }
                            if i < totalTicks - 1 {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.horizontal, 10)

                    // 指针 — 半透明竖线
                    let needlePos = entry.isEmpty ? 0.5 : stableNeedlePosition()
                    Rectangle()
                        .fill(needleColor.opacity(0.7))
                        .frame(width: 2.5, height: height * 0.55)
                        .background(
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 6)
                                .blur(radius: 2)
                        )
                        .offset(x: (needlePos - 0.5) * (width - 28))
                }
                .padding(.bottom, 6)
            }
        }
        .frame(width: width, height: height)
        // 外阴影 — 凹陷感
        .shadow(color: Color.white.opacity(0.6), radius: 1, x: 0, y: 1)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: -1)
    }

    private func stableNeedlePosition() -> CGFloat {
        let hash = abs(entry.songName.hashValue)
        return CGFloat(hash % 70 + 15) / 100.0 // 0.15 ~ 0.85
    }

    // MARK: - 轻拟物按钮

    private func radioKnob<I: AppIntent>(intent: I, icon: String, size: CGFloat, isMain: Bool) -> some View {
        Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(isMain ? textPrimary.opacity(0.65) : btnIconColor)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [btnTopColor, btnBottomColor],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        // 柔和的底部投影 — 圆润凸起感
                        .shadow(color: btnShadowColor.opacity(0.5), radius: 2.5, x: 0, y: 2)
                        .shadow(color: Color.white.opacity(0.5), radius: 0.5, x: 0, y: -0.5)
                )
                // 淡淡的顶部高亮 — 圆润感
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.clear],
                                startPoint: .top, endPoint: .center
                            )
                        )
                        .padding(2)
                        .allowsHitTesting(false)
                )
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dashboard Theme (仪表盘)

struct DashboardTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    // 色彩系统 — 深色仪表盘
    private let bgColor = Color(hex: "1C1C1E")
    private let cardBg = Color(hex: "242428")
    private let pillBg = Color.white.opacity(0.06)
    private let textWhite = Color.white
    private let textGray = Color(hex: "98989D")
    private let accentBar = Color(hex: "FF9F0A") // 橙黄色竖条
    private let indicatorDot = Color(hex: "8B6914") // 偏深金/棕色指示点
    private let btnColor = Color(hex: "7C7C80") // 未激活按钮颜色

    private var song: String { entry.isEmpty ? "Dashboard" : entry.songName }
    private var artist: String { entry.isEmpty ? "Not Playing" : entry.artistName }
    private var displayLyric: String { entry.lyricText.isEmpty ? "" : entry.lyricText }

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
            let h = geo.size.height
            let coverSize: CGFloat = min(w * 0.42, h * 0.38)

            VStack(spacing: 0) {
                // 上半部：封面 + 标签
                HStack(alignment: .top, spacing: 8) {
                    // 凹陷封面
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(cardBg)
                            .frame(width: coverSize, height: coverSize)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                            )

                        if let data = entry.coverImageData,
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: coverSize - 6, height: coverSize - 6)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(textGray.opacity(0.4))
                        }
                    }

                    // 右侧标签
                    VStack(alignment: .trailing, spacing: 6) {
                        // 音质标签
                        dashboardPill(
                            icon: "music.note",
                            text: entry.qualityText.isEmpty ? "Standard" : entry.qualityText
                        )

                        // 播放模式标签
                        dashboardPill(
                            icon: "play.fill",
                            text: entry.playModeText.isEmpty ? "顺序" : entry.playModeText
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                Spacer(minLength: 4)

                // 歌曲信息
                VStack(alignment: .leading, spacing: 3) {
                    Text(song)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(textWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.interpolate)

                    HStack(spacing: 5) {
                        // 橙色竖条
                        RoundedRectangle(cornerRadius: 1)
                            .fill(accentBar)
                            .frame(width: 2.5, height: 12)

                        Text(artist)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(textGray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .contentTransition(.interpolate)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)

                Spacer(minLength: 4)

                // 底部控制按钮
                if !entry.isEmpty {
                    HStack(spacing: 0) {
                        dashboardBtn(intent: PreviousTrackIntent(), icon: "backward.fill")
                        dashboardBtn(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, isMain: true)
                        dashboardBtn(intent: NextTrackIntent(), icon: "forward.fill")

                        Spacer()

                        DashboardActivityDot(isActive: entry.isPlaying, color: indicatorDot, size: 6)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                } else {
                    Spacer().frame(height: 12)
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Medium

    private var mediumLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let coverSize: CGFloat = h - 24

            HStack(spacing: 0) {
                // 左侧封面
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(cardBg)
                        .frame(width: coverSize, height: coverSize)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        )

                    if let data = entry.coverImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: coverSize - 8, height: coverSize - 8)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(textGray.opacity(0.4))
                    }
                }
                .padding(.leading, 14)

                // 右侧
                VStack(alignment: .leading, spacing: 0) {
                    // 标签
                    HStack(spacing: 6) {
                        dashboardPill(icon: "music.note", text: entry.qualityText.isEmpty ? "Standard" : entry.qualityText)
                        dashboardPill(icon: "play.fill", text: entry.playModeText.isEmpty ? "顺序" : entry.playModeText)
                        Spacer()
                        DashboardActivityDot(isActive: entry.isPlaying, color: indicatorDot, size: 6)
                    }
                    .padding(.top, 10)

                    Spacer(minLength: 4)

                    // 歌曲信息
                    Text(song)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(textWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.interpolate)

                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(accentBar)
                            .frame(width: 2.5, height: 12)
                        Text(artist)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(textGray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .contentTransition(.interpolate)
                    }
                    .padding(.top, 2)

                    // 歌词滚动框 (独特跑马灯切入动画)
                    if !displayLyric.isEmpty {
                        Text(displayLyric)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(accentBar)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(cardBg)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                                    )
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                            .id(displayLyric)
                            .clipped() // 防止滑动时溢出
                    }

                    Spacer(minLength: 4)

                    // 按钮
                    if !entry.isEmpty {
                        HStack(spacing: 0) {
                            dashboardBtn(intent: PreviousTrackIntent(), icon: "backward.fill")
                            dashboardBtn(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, isMain: true)
                            dashboardBtn(intent: NextTrackIntent(), icon: "forward.fill")
                        }
                        .padding(.bottom, 10)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    private var largeLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let coverSize: CGFloat = min(w * 0.45, 150) // 左侧中等偏大封面

            VStack(spacing: 0) {
                // 上半部分：分栏布局 (类似中控双屏)
                HStack(alignment: .top, spacing: 16) {
                    // 左侧：封面
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cardBg)
                            .frame(width: coverSize, height: coverSize)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))

                        if let data = entry.coverImageData,
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: coverSize - 10, height: coverSize - 10)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: 36, weight: .light))
                                .foregroundStyle(textGray.opacity(0.4))
                        }
                    }

                    // 右侧：信息与标签
                    VStack(alignment: .leading, spacing: 0) {
                        // 顶部标签区
                        HStack(spacing: 6) {
                            dashboardPill(icon: "music.note", text: entry.qualityText.isEmpty ? "Standard" : entry.qualityText)
                            dashboardPill(icon: "play.fill", text: entry.playModeText.isEmpty ? "顺序" : entry.playModeText)
                            Spacer(minLength: 0)
                            DashboardActivityDot(isActive: entry.isPlaying, color: indicatorDot, size: 8)
                        }
                        
                        Spacer(minLength: 10)

                        // 歌曲名
                        Text(song)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(textWhite)
                            .lineLimit(2)
                            .minimumScaleFactor(0.4)
                            .contentTransition(.interpolate)
                            .padding(.bottom, 6)

                        // 歌手名
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(accentBar)
                                .frame(width: 3, height: 14)
                            Text(artist)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(textGray)
                                .lineLimit(2)
                                .minimumScaleFactor(0.4)
                                .contentTransition(.interpolate)
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .frame(height: coverSize, alignment: .top) // 让右侧与封面等高
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                Spacer(minLength: 16)

                // 中间部分：巨大的歌词遥测面板
                if !displayLyric.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "teletype")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(accentBar.opacity(0.8))
                            Text("LYRICS_TELEMETRY")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(textGray.opacity(0.8))
                        }
                        
                        Text(displayLyric)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(textWhite.opacity(0.95))
                            .lineLimit(3)
                            .minimumScaleFactor(0.8) // 保证缩放不缩略
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1) // 防止外部布局挤压缩略
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                            .id(displayLyric)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(width: w - 40, alignment: .topLeading) // 强制全宽，优先保证文本不被截断
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(cardBg.opacity(0.6))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04), lineWidth: 1))
                    )
                }

                Spacer(minLength: 16)

                // 底部部分：超宽扁平控制栏
                if !entry.isEmpty {
                    HStack(spacing: 0) {
                        dashboardBtn(intent: PreviousTrackIntent(), icon: "backward.fill", btnW: 60, btnH: 44, iconSize: 18)
                        Spacer()
                        dashboardBtn(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, isMain: true, btnW: 100, btnH: 44, iconSize: 26)
                        Spacer()
                        dashboardBtn(intent: NextTrackIntent(), icon: "forward.fill", btnW: 60, btnH: 44, iconSize: 18)
                    }
                    .background(cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.04), lineWidth: 1))
                    .padding(.horizontal, 30)
                    .padding(.bottom, 24)
                } else {
                    Spacer().frame(height: 24)
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - 胶囊标签

    private func dashboardPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
        }
        .foregroundStyle(textWhite.opacity(0.75))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(pillBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    // MARK: - 扁平控制按钮

    private func dashboardBtn<I: AppIntent>(intent: I, icon: String, isMain: Bool = false, btnW: CGFloat = 36, btnH: CGFloat = 28, iconSize: CGFloat = 14) -> some View {
        Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: isMain ? iconSize + 4 : iconSize, weight: .semibold))
                .foregroundStyle(isMain ? textWhite : btnColor)
                .frame(width: btnW, height: btnH)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
}

private struct DashboardActivityDot: View {
    let isActive: Bool
    let color: Color
    let size: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { timeline in
            let pulse = isActive
                ? (sin(timeline.date.timeIntervalSinceReferenceDate * 3.4) + 1.0) * 0.5
                : 0.0

            Circle()
                .fill(color.opacity(0.72 + 0.28 * pulse))
                .frame(width: size, height: size)
                .scaleEffect(CGFloat(1.0 + 0.14 * pulse))
                .shadow(color: Color.black.opacity(0.8), radius: 1, x: 0, y: 1)
                .shadow(color: color.opacity(0.22 + 0.36 * pulse), radius: CGFloat(2 + 3 * pulse))
        }
    }
}

// MARK: - SoundwaveTheme (声波主题)

struct SoundwaveTheme: View {
    var entry: NowPlayingEntry
    var family: WidgetFamily

    private var song: String {
        return entry.songName.isEmpty ? "mono" : entry.songName
    }
    
    private var artist: String {
        return entry.artistName.isEmpty ? "聆听你的声音" : entry.artistName
    }
    
    private var displayLyric: String {
        return entry.lyricText.isEmpty ? "" : entry.lyricText
    }

    // Colors
    private let cardBg = Color(hex: "151515")
    private let ringOrange = Color(hex: "CC7A33")
    private let playOrange = Color(hex: "F06A00")
    private let infoBg = Color(hex: "111112")
    private let pillBg = Color(hex: "1C1C1E")

    var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
        case .systemMedium:
            mediumLayout
        case .systemLarge:
            largeLayout
        default:
            smallLayout
        }
    }

    // MARK: - Small Layout
    
    private var smallLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // 背景
                cardBg.ignoresSafeArea()
                
                // 4个工业风螺丝角 (使用深色圆环模拟)
                let inset: CGFloat = 8
                Group {
                    screwCorner().position(x: inset, y: inset)
                    screwCorner().position(x: w - inset, y: inset)
                    screwCorner().position(x: inset, y: h - inset)
                    screwCorner().position(x: w - inset, y: h - inset)
                }
                
                // 内部主结构
                VStack(spacing: 8) {
                    
                    // 顶部区域：表盘 + 按钮胶囊
                    HStack(spacing: 6) {
                        // 左边：雷达表盘形进度 (100%TRACK)
                        ZStack {
                            Circle()
                                .stroke(ringOrange.opacity(0.35), lineWidth: 2)
                                
                            // 刻度线
                            ForEach(0..<12) { i in
                                Rectangle()
                                    .fill(ringOrange.opacity(i % 3 == 0 ? 0.7 : 0.4))
                                    .frame(width: 1.5, height: i % 3 == 0 ? 6 : 3)
                                    .offset(y: -22)
                                    .rotationEffect(.degrees(Double(i) * 30))
                            }
                            
                            VStack(spacing: 1) {
                                Text("100%")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                
                                PlaybackWave(isActive: entry.isPlaying, barCount: 3, color: ringOrange, height: 8)
                                    
                                Text("TRACK")
                                    .font(.system(size: 7, weight: .black, design: .monospaced))
                                    .foregroundColor(ringOrange)
                            }
                        }
                        .frame(width: 50, height: 50)
                        
                        // 右边：上下两个胶囊
                        VStack(spacing: 6) {
                            // VOL
                            HStack(spacing: 4) {
                                PlaybackWave(isActive: entry.isPlaying, barCount: 3, color: playOrange, height: 10)
                                Text("VOL")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(ringOrange)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 20)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(pillBg))
                            
                            // 控件胶囊
                            HStack(spacing: 0) {
                                Button(intent: PreviousTrackIntent()) {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color.gray.opacity(0.8))
                                        .frame(width: 22, height: 26)
                                }.buttonStyle(.plain)
                                
                                Spacer(minLength: 2)
                                
                                Button(intent: TogglePlaybackIntent()) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(playOrange)
                                        Image(systemName: entry.controlSymbolName)
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundColor(.black)
                                    }
                                    .frame(width: 26, height: 26)
                                    .shadow(color: playOrange.opacity(0.4), radius: 3, y: 1.5)
                                }.buttonStyle(.plain)
                                
                                Spacer(minLength: 2)
                                
                                Button(intent: NextTrackIntent()) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color.gray.opacity(0.8))
                                        .frame(width: 22, height: 26)
                                }.buttonStyle(.plain)
                            }
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(pillBg))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 14)
                    
                    // 下方：信号信息大卡片
                    ZStack(alignment: .bottomTrailing) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CURRENT_SIGNAL")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.gray.opacity(0.7))
                                
                            Spacer(minLength: 4)
                                
                            Text(song)
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                                
                            Text(artist)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(ringOrange)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 64)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(infoBg))
                        
                        // 卡片内部右下角的虚晃微型波形
                        PlaybackWave(isActive: entry.isPlaying, barCount: 3, color: ringOrange.opacity(0.8), height: 10)
                            .padding(14)
                    }
                    .padding(.horizontal, 12)
                    
                    Spacer()
                }
                
                // 最底部角落修饰字符 "SYS_LINK"
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(ringOrange.opacity(0.5)).frame(width: 5, height: 5)
                            Text("SYS_LINK")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(ringOrange.opacity(0.4))
                        }
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }
    
    // MARK: - Medium Layout
    
    private var mediumLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                cardBg.ignoresSafeArea()
                
                let inset: CGFloat = 8
                VStack {
                    HStack { screwCorner(); Spacer(); screwCorner() }
                    Spacer()
                    HStack { screwCorner(); Spacer(); screwCorner() }
                }
                .padding(inset)
                
                HStack(spacing: 12) {
                    // Left: Cover + Song Info + Controls (VStack)
                    VStack(alignment: .leading, spacing: 8) {
                        // Top row of left: Radar Cover
                        HStack(spacing: 12) {
                            // Radar
                            ZStack {
                                Circle().stroke(ringOrange.opacity(0.35), lineWidth: 2)
                                ForEach(0..<12) { i in
                                    Rectangle()
                                        .fill(ringOrange.opacity(i % 3 == 0 ? 0.7 : 0.4))
                                        .frame(width: 1.5, height: i % 3 == 0 ? 6 : 3)
                                        .offset(y: -22)
                                        .rotationEffect(.degrees(Double(i) * 30))
                                }
                                
                                if let data = entry.coverImageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .clipShape(Circle())
                                        .frame(width: 40, height: 40)
                                } else {
                                    Circle().fill(Color.white.opacity(0.1)).frame(width: 40, height: 40)
                                    Image(systemName: "music.note")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .frame(width: 50, height: 50)
                            
                            // Info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(song)
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.4)
                                    
                                Text(artist)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(ringOrange)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.4)
                            }
                        }
                        
                        Spacer()
                        
                        // Controls Pill
                        HStack(spacing: 0) {
                            Button(intent: PreviousTrackIntent()) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.gray.opacity(0.8))
                                    .frame(width: 24, height: 32)
                            }.buttonStyle(.plain)
                            
                            Spacer()
                            
                            Button(intent: TogglePlaybackIntent()) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(playOrange)
                                    Image(systemName: entry.controlSymbolName)
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundColor(.black)
                                }
                                .frame(width: 32, height: 32)
                                .shadow(color: playOrange.opacity(0.4), radius: 3, y: 1.5)
                            }.buttonStyle(.plain)
                            
                            Spacer()
                            
                            Button(intent: NextTrackIntent()) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.gray.opacity(0.8))
                                    .frame(width: 24, height: 32)
                            }.buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(pillBg))
                    }
                    .frame(maxWidth: w * 0.44)
                    
                    // Right: Lyrics Terminal
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            PlaybackWave(isActive: entry.isPlaying, barCount: 3, color: playOrange, height: 10)
                            Text("LYRICS_DATA")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(ringOrange)
                            Spacer()
                            Circle().fill(ringOrange.opacity(0.5)).frame(width: 4, height: 4)
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        Text(displayLyric)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                            .layoutPriority(1)
                        
                        Spacer()
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(infoBg)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(ringOrange.opacity(0.15), lineWidth: 1))
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }
    
    // MARK: - Large Layout
    
    private var largeLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                cardBg.ignoresSafeArea()
                
                let inset: CGFloat = 10
                VStack {
                    HStack { screwCorner(); Spacer(); screwCorner() }
                    Spacer()
                    HStack { screwCorner(); Spacer(); screwCorner() }
                }
                .padding(inset)
                
                VStack(spacing: 12) {
                    // Row 1: Radar Cover + Info Panel
                    HStack(spacing: 16) {
                        // Radar Big Cover
                        ZStack {
                            Circle().stroke(ringOrange.opacity(0.35), lineWidth: 3)
                            ForEach(0..<18) { i in
                                Rectangle()
                                    .fill(ringOrange.opacity(i % 3 == 0 ? 0.7 : 0.4))
                                    .frame(width: 2, height: i % 3 == 0 ? 8 : 4)
                                    .offset(y: -42)
                                    .rotationEffect(.degrees(Double(i) * 20))
                            }
                            
                            if let data = entry.coverImageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .clipShape(Circle())
                                    .frame(width: 76, height: 76)
                            } else {
                                Circle().fill(Color.white.opacity(0.1)).frame(width: 76, height: 76)
                            }
                        }
                        .frame(width: 90, height: 90)
                        
                        // Vertical Song Info Hub
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOW_TRACKING")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.gray.opacity(0.7))
                            Text(song)
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.4)
                            Text(artist)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(ringOrange)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    
                    // Row 2: Equalizer / Control Deck Strip
                    HStack {
                        SoundwaveEqualizerBars(isActive: entry.isPlaying, color: playOrange)
                        .padding(.leading, 12)
                        
                        Spacer()
                        
                        // Controls
                        HStack(spacing: 20) {
                            Button(intent: PreviousTrackIntent()) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.gray.opacity(0.8))
                                    .frame(width: 32, height: 40)
                            }.buttonStyle(.plain)
                            
                            Button(intent: TogglePlaybackIntent()) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(playOrange)
                                    Image(systemName: entry.controlSymbolName)
                                        .font(.system(size: 16, weight: .black))
                                        .foregroundColor(.black)
                                }
                                .frame(width: 40, height: 40)
                                .shadow(color: playOrange.opacity(0.4), radius: 3, y: 1.5)
                            }.buttonStyle(.plain)
                            
                            Button(intent: NextTrackIntent()) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.gray.opacity(0.8))
                                    .frame(width: 32, height: 40)
                            }.buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .background(pillBg)
                    .cornerRadius(16)
                    .padding(.horizontal, 14)
                    
                    // Row 3: Massive Lyrics Screen
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            PlaybackWave(isActive: entry.isPlaying, barCount: 4, color: playOrange, height: 12)
                            Text("LIVE_LYRICS_STREAM")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(ringOrange)
                            Spacer()
                            Circle().fill(ringOrange.opacity(0.5)).frame(width: 6, height: 6)
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        Text(displayLyric)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(6)
                            .minimumScaleFactor(0.4)
                            .layoutPriority(1)
                        Spacer()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(infoBg)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(ringOrange.opacity(0.15), lineWidth: 1.5))
                            .overlay(
                                VStack {
                                    HStack { screwCorner(); Spacer(); screwCorner() }
                                    Spacer()
                                    HStack { screwCorner(); Spacer(); screwCorner() }
                                }
                                .padding(12)
                            )
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }
    
    // 角落的仿真螺丝
    private func screwCorner() -> some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 8, height: 8)
            .shadow(color: Color.black.opacity(0.5), radius: 1, x: 0, y: 1)
            .overlay(
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 6, height: 1)
                    .rotationEffect(.degrees(45))
            )
            .overlay(
                Circle().stroke(Color.black.opacity(0.5), lineWidth: 0.5)
            )
    }
}

private struct SoundwaveEqualizerBars: View {
    let isActive: Bool
    let color: Color

    private let baseHeights: [CGFloat] = [12, 24, 18, 28, 16, 20]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { timeline in
            HStack(spacing: 4) {
                ForEach(baseHeights.indices, id: \.self) { index in
                    let pulse = phase(index: index, date: timeline.date)
                    Capsule()
                        .fill(color.opacity(0.5 + 0.28 * Double(pulse)))
                        .frame(width: 4, height: height(index: index, date: timeline.date))
                }
            }
        }
    }

    private func height(index: Int, date: Date) -> CGFloat {
        guard isActive else { return baseHeights[index] }
        let pulse = phase(index: index, date: date)
        return baseHeights[index] * (0.72 + 0.56 * pulse)
    }

    private func phase(index: Int, date: Date) -> CGFloat {
        let time = date.timeIntervalSinceReferenceDate * 4.8
        let wave = sin(time + Double(index) * 0.78) * 0.5 + 0.5
        return CGFloat(wave)
    }
}



// MARK: - Typewriter Theme (打字机)

struct TypewriterWidgetTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily
    
    // Aesthetic Palette
    private var metal: Color { Color(hex: "3C342E") }
    private var metalDark: Color { Color(hex: "28221D") }
    private var paper: Color { Color(hex: "DED0B6") }
    private var paperEdge: Color { Color(hex: "C5B79E") }
    private var ink: Color { Color(hex: "221A14") }
    private var inkFaded: Color { Color(hex: "6D5E50") }
    private var ribbon: Color { Color(hex: "A44E38") }
    private var keyFace: Color { Color(hex: "F0E8D8") }
    private var keyRim: Color { Color(hex: "6A5E52") }
    private var keyText: Color { Color(hex: "2C2218") }

    private var displaySong: String { entry.isEmpty ? "INSERT RECORD" : entry.songName }
    private var displayArtist: String { entry.isEmpty ? "等待歌曲开始播放…" : entry.artistName }

    // MARK: - Typewriter Stamp View
    @ViewBuilder
    private func stampCover(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "DCC8A0"), Color(hex: "B89060")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            if let data = entry.coverImageData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size * 0.84, height: size * 0.84)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.08, style: .continuous))
            } else {
                Image(systemName: "music.quarternote.3")
                    .font(.system(size: size * 0.35))
                    .foregroundColor(ink.opacity(0.4))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
        )
        .rotationEffect(.degrees(3))
        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 3)
    }

    // MARK: - Animated Typing Cursor
    private var typingCursor: some View {
        TimelineView(.animation(minimumInterval: 0.45)) { timeline in
            let isVisible = Int(timeline.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            Text("▌")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(ribbon)
                .opacity(!entry.isEmpty && entry.isPlaying && isVisible ? 1.0 : (!entry.isEmpty && entry.isPlaying ? 0.2 : 0))
        }
    }

    // MARK: - Keycap Constructor
    private func keyButton(icon: String, size: CGFloat, intent: any AppIntent) -> some View {
        Button(intent: intent) {
            ZStack {
                // Key Rim
                Circle()
                    .fill(
                        LinearGradient(colors: [keyRim, keyRim.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: size, height: size)
                // Key Face
                Circle()
                    .fill(
                        LinearGradient(colors: [keyFace, keyFace.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: size - 5, height: size - 5)
                // Symbol
                Image(systemName: icon)
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundColor(keyText)
            }
            .contentShape(Circle())
            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1.5)
        }
        .buttonStyle(.plain)
    }
    
    private func playKeyButton(size: CGFloat) -> some View {
        Button(intent: TogglePlaybackIntent()) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [ribbon, ribbon.opacity(0.78)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    
                Image(systemName: entry.controlSymbolName)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundColor(keyFace)
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(Circle())
            .shadow(color: Color.black.opacity(0.35), radius: 2.5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main Body
    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        case .systemLarge: largeLayout
        default: smallLayout
        }
    }
    
    // MARK: - Small Layout (Paper & Stamp)
    private var smallLayout: some View {
        GeometryReader { _ in
            ZStack {
                paper.ignoresSafeArea()
                
                // Paper watermark lines
                VStack(spacing: 20) {
                    Divider().background(inkFaded.opacity(0.12))
                    Divider().background(inkFaded.opacity(0.12))
                    Divider().background(inkFaded.opacity(0.12))
                    Divider().background(inkFaded.opacity(0.12))
                    Divider().background(inkFaded.opacity(0.12))
                }
                .padding(.top, 20)
                
                // Margin Line
                HStack {
                    Rectangle()
                        .fill(ribbon.opacity(0.28))
                        .frame(width: 1.5)
                        .padding(.leading, 18)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(!entry.isEmpty && entry.isPlaying ? ribbon : inkFaded.opacity(0.4))
                                .frame(width: 5, height: 5)
                            Text(!entry.isEmpty && entry.isPlaying ? "TYPING" : "READY")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(inkFaded)
                                .tracking(1)
                        }
                        Spacer()
                        stampCover(size: 45)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 0) {
                            Text(displaySong)
                                .font(.system(size: 15, weight: .bold, design: .serif))
                                .foregroundColor(ink)
                                .lineLimit(2)
                                .minimumScaleFactor(0.6)
                            typingCursor
                        }
                        
                        Text(displayArtist)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(inkFaded)
                            .lineLimit(1)
                    }
                }
                .padding(14)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }
    
    // MARK: - Medium Layout (Deck + Paper)
    private var mediumLayout: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Base background for medium is the paper sticking out
                paper.ignoresSafeArea()
                
                // Paper lines
                VStack(spacing: 22) {
                    Divider().background(inkFaded.opacity(0.15))
                    Divider().background(inkFaded.opacity(0.15))
                    Divider().background(inkFaded.opacity(0.15))
                }
                .padding(.top, 26)
                
                // Margin line
                HStack {
                    Rectangle()
                        .fill(ribbon.opacity(0.28))
                        .frame(width: 1.5)
                        .padding(.leading, 22)
                    Spacer()
                }

                // Top Paper Content
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(!entry.isEmpty && entry.isPlaying ? ribbon : inkFaded.opacity(0.4))
                                    .frame(width: 6, height: 6)
                                Text(!entry.isEmpty && entry.isPlaying ? "TYPING" : "READY")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(inkFaded)
                                    .tracking(2)
                            }
                            
                            HStack(spacing: 0) {
                                Text(displaySong.uppercased())
                                    .font(.system(size: 18, weight: .bold, design: .serif))
                                    .foregroundColor(ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                typingCursor
                            }
                            
                            Text(displayArtist)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(inkFaded)
                                .lineLimit(1)
                        }
                        Spacer()
                        stampCover(size: 50)
                            .offset(y: -4)
                    }
                    Spacer()
                }
                .padding(.top, 14)
                .padding(.horizontal, 16)
                
                // Bottom Metal Deck Base
                let deckHeight = geo.size.height * 0.45
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [metal, metalDark], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: -2)
                        
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(colors: [Color.white.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1
                        )
                        
                    // Deck Content
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ROLLING")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(keyFace.opacity(0.5))
                                .tracking(1)
                            
                            if !entry.qualityText.isEmpty {
                                Text(entry.qualityText)
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                        
                        Spacer()
                        
                        // Mechanical Controls
                        if !entry.isEmpty {
                            HStack(spacing: 12) {
                                UITargetedButton(icon: "backward.fill", size: 36, intent: PreviousTrackIntent())
                                playUITargetedButton(size: 46)
                                UITargetedButton(icon: "forward.fill", size: 36, intent: NextTrackIntent())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: deckHeight)
                }
                .frame(height: deckHeight)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }
    
    // Helper explicitly wrapping button creation
    private func UITargetedButton(icon: String, size: CGFloat, intent: any AppIntent) -> some View {
        return keyButton(icon: icon, size: size, intent: intent)
    }
    private func playUITargetedButton(size: CGFloat) -> some View {
        return playKeyButton(size: size)
    }
    
    // MARK: - Large Layout (Full Typewriter)
    private var largeLayout: some View {
        GeometryReader { geo in
            ZStack {
                metalDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Roller Bar
                    ZStack {
                        Capsule()
                            .fill(LinearGradient(colors: [metal, metalDark], startPoint: .top, endPoint: .bottom))
                            .frame(width: geo.size.width * 0.85, height: 12)
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
                            
                        HStack {
                            Circle().fill(metal).frame(width: 18)
                            Spacer()
                            Circle().fill(metal).frame(width: 18)
                        }
                        .frame(width: geo.size.width * 0.9)
                        .overlay(Circle().stroke(Color.white.opacity(0.2)), alignment: .leading)
                        .overlay(Circle().stroke(Color.white.opacity(0.2)), alignment: .trailing)
                    }
                    .padding(.top, 10)
                    .zIndex(2)
                    
                    // Paper Area
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(paper)
                            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(paperEdge, lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                            
                        // Margins and lines
                        VStack(spacing: 24) {
                            ForEach(0..<10, id: \.self) { _ in Divider().background(inkFaded.opacity(0.15)) }
                        }.padding(.top, 24)
                        
                        HStack {
                            Rectangle().fill(ribbon.opacity(0.28)).frame(width: 1.5).padding(.leading, 24)
                            Spacer()
                        }
                        
                        // Content
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Circle()
                                            .fill(!entry.isEmpty && entry.isPlaying ? ribbon : inkFaded.opacity(0.4))
                                            .frame(width: 6, height: 6)
                                        Text(!entry.isEmpty && entry.isPlaying ? "TYPING" : "READY")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(inkFaded)
                                            .tracking(2)
                                    }
                                    Text(displaySong)
                                        .font(.system(size: 24, weight: .bold, design: .serif))
                                        .foregroundColor(ink)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.5)
                                    Text(displayArtist)
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundColor(inkFaded)
                                }
                                Spacer()
                                stampCover(size: 58)
                            }
                            
                            Rectangle().fill(ink.opacity(0.1)).frame(height: 1)
                            
                            // Mock typing section for latest lyric
                            if !entry.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    let lyric = entry.lyricText.isEmpty ? "INSTRUMENTAL TRACK" : entry.lyricText
                                    HStack(alignment: .top, spacing: 0) {
                                        Text(lyric.uppercased())
                                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                            .foregroundColor(ink)
                                            .lineLimit(3)
                                        typingCursor
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 36)
                    }
                    .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.55)
                    .offset(y: -6)
                    .zIndex(1)
                    
                    // Bottom Deck
                    VStack {
                        Spacer()
                        // Metal base
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(LinearGradient(colors: [metal, metalDark], startPoint: .top, endPoint: .bottom))
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(LinearGradient(colors: [Color.white.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                                
                            HStack(spacing: 16) {
                                if !entry.isEmpty {
                                    UITargetedButton(icon: "backward.fill", size: 40, intent: PreviousTrackIntent())
                                    playUITargetedButton(size: 56)
                                    UITargetedButton(icon: "forward.fill", size: 40, intent: NextTrackIntent())
                                }
                            }
                        }
                        .frame(width: geo.size.width, height: geo.size.height * 0.28)
                        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: -4)
                    }
                    .zIndex(3)
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }
}
