import Combine
import SwiftUI

extension Notification.Name {
    static let monoColorConfigurationDidChange = Notification.Name(
        "zijiu.Monologue.color-engine-configuration-did-change"
    )
}

enum CoverPaletteMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case adaptive
    case random

    var id: String { rawValue }

    var label: String {
        switch self {
        case .adaptive:
            return String(localized: "智能取色")
        case .random:
            return String(localized: "随机取色")
        }
    }
}

@MainActor
final class CoverPalettePreferences: ObservableObject {
    static let shared = CoverPalettePreferences()

    @Published var colorCount: Int {
        didSet {
            let clamped = min(max(colorCount, 2), 6)
            if colorCount != clamped {
                colorCount = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: "coverPalette.colorCount")
            NotificationCenter.default.post(name: .monoColorConfigurationDidChange, object: nil)
        }
    }

    @Published var mode: CoverPaletteMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "coverPalette.mode")
            NotificationCenter.default.post(name: .monoColorConfigurationDidChange, object: nil)
        }
    }

    @Published private(set) var randomSeed: Int {
        didSet {
            UserDefaults.standard.set(randomSeed, forKey: "coverPalette.randomSeed")
            NotificationCenter.default.post(name: .monoColorConfigurationDidChange, object: nil)
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        let storedCount = defaults.object(forKey: "coverPalette.colorCount") as? Int ?? 4
        colorCount = min(max(storedCount, 2), 6)
        mode = CoverPaletteMode(
            rawValue: defaults.string(forKey: "coverPalette.mode") ?? ""
        ) ?? .adaptive
        randomSeed = defaults.integer(forKey: "coverPalette.randomSeed")
    }

    func reshuffle() {
        randomSeed = randomSeed &+ 1
    }
}

/// 从封面图片提取可在背景、歌词、播放器和主题氛围间共享的多色调色板。
@MainActor
final class CoverColorExtractor: ObservableObject {
    @Published var palette: [Color] = [.gray, .gray.opacity(0.6)]
    @Published var dominantColor: Color = .gray
    @Published var secondaryColor: Color = .gray.opacity(0.6)
    @Published var isDark = true
    @Published var isTopDark = true
    @Published var luminance: CGFloat = 0.3
    @Published var lyricRegionLuminance: CGFloat = 0.3
    @Published var contentColor: Color = .white
    @Published var secondaryContentColor: Color = .white.opacity(0.68)
    @Published var lyricContentColor: Color = .white
    @Published var lyricSecondaryContentColor: Color = .white.opacity(0.62)
    @Published var isLyricRegionDark = true
    @Published private(set) var resolvedURL: String?

    private let preferences = CoverPalettePreferences.shared
    private let minimumColorCount: Int
    private var lastURL: String?
    private var requestIdentity = ""
    private var cancellables = Set<AnyCancellable>()

    init(minimumColorCount: Int = 2) {
        self.minimumColorCount = min(max(minimumColorCount, 2), 6)

        Publishers.CombineLatest3(
            preferences.$colorCount.removeDuplicates(),
            preferences.$mode.removeDuplicates(),
            preferences.$randomSeed.removeDuplicates()
        )
        .dropFirst()
        .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            guard let self, let lastURL else { return }
            extract(from: lastURL, force: true)
        }
        .store(in: &cancellables)
    }

    /// 从 URL 异步提取颜色。重复 URL 会复用已显示结果，配置变化时强制刷新。
    func extract(from urlString: String?, force: Bool = false) {
        guard let urlString, !urlString.isEmpty else {
            reset()
            return
        }
        guard force || urlString != lastURL else { return }
        guard URL(string: urlString) != nil else { return }

        let isNewSource = urlString != lastURL
        lastURL = urlString
        if isNewSource {
            resolvedURL = nil
        }
        let colorCount = max(preferences.colorCount, minimumColorCount)
        let mode = preferences.mode
        let randomSeed = preferences.randomSeed
        let requiredColorCount = minimumColorCount
        let identity = "\(urlString)|\(colorCount)|\(mode.rawValue)|\(randomSeed)"
        requestIdentity = identity

        Task { [weak self] in
            guard let colors = await UnifiedColorEngine.shared.artworkColors(
                for: urlString,
                minimumCount: requiredColorCount
            ), let self, self.requestIdentity == identity else { return }
            withAnimation(.easeOut(duration: 0.45)) {
                self.palette = colors.palette
                self.dominantColor = colors.dominant
                self.secondaryColor = colors.secondary
                self.isDark = colors.isDark
                self.isTopDark = colors.isTopDark
                self.luminance = colors.luminance
                self.lyricRegionLuminance = colors.lyricRegionLuminance
                self.contentColor = colors.foreground
                self.secondaryContentColor = colors.secondaryForeground
                self.lyricContentColor = colors.lyricForeground
                self.lyricSecondaryContentColor = colors.lyricSecondaryForeground
                self.isLyricRegionDark = colors.isLyricRegionDark
                self.resolvedURL = urlString
            }
        }
    }

    func reset() {
        lastURL = nil
        requestIdentity = ""
        resolvedURL = nil
        palette = [.gray, .gray.opacity(0.6)]
        dominantColor = .gray
        secondaryColor = .gray.opacity(0.6)
        isDark = true
        isTopDark = true
        luminance = 0.3
        lyricRegionLuminance = 0.3
        contentColor = .white
        secondaryContentColor = .white.opacity(0.68)
        lyricContentColor = .white
        lyricSecondaryContentColor = .white.opacity(0.62)
        isLyricRegionDark = true
    }
}

struct DynamicCoverPaletteLayer: View {
    let colors: [Color]
    var opacity: Double = 1

    var body: some View {
        GeometryReader { proxy in
            let longSide = max(proxy.size.width, proxy.size.height)
            let anchors: [UnitPoint] = [
                .init(x: 0.14, y: 0.12),
                .init(x: 0.86, y: 0.2),
                .init(x: 0.22, y: 0.82),
                .init(x: 0.78, y: 0.76),
                .center,
                .init(x: 0.52, y: 0.16)
            ]

            ZStack {
                ForEach(Array(colors.prefix(6).enumerated()), id: \.offset) { index, color in
                    RadialGradient(
                        colors: [
                            color.opacity((index == 0 ? 0.34 : 0.24) * opacity),
                            color.opacity(0.07 * opacity),
                            .clear
                        ],
                        center: anchors[index % anchors.count],
                        startRadius: 0,
                        endRadius: longSide * (index == 0 ? 0.64 : 0.5)
                    )
                    .blendMode(.plusLighter)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct CoverPaletteSettingsControls: View {
    @ObservedObject private var preferences = CoverPalettePreferences.shared
    @ObservedObject private var player = PlayerManager.shared
    @StateObject private var previewColors = CoverColorExtractor()

    let accent: Color
    let darkStyle: Bool
    let showsLivePreview: Bool

    /// 保留原有两参数入口，避免现有播放器设置页在增量构建时被迫链接到
    /// 带默认参数的新 memberwise initializer。
    init(accent: Color, darkStyle: Bool = true) {
        self.accent = accent
        self.darkStyle = darkStyle
        self.showsLivePreview = false
    }

    init(accent: Color, darkStyle: Bool, showsLivePreview: Bool) {
        self.accent = accent
        self.darkStyle = darkStyle
        self.showsLivePreview = showsLivePreview
    }

    private var primary: Color {
        darkStyle ? .white : .monoTextPrimary
    }

    private var secondary: Color {
        darkStyle ? .white.opacity(0.5) : .monoTextSecondary
    }

    var body: some View {
        VStack(spacing: 12) {
            if showsLivePreview, player.currentSong?.coverUrl != nil {
                liveEnginePreview
            }

            HStack(spacing: 7) {
                ForEach(CoverPaletteMode.allCases) { mode in
                    modeButton(mode)
                }
            }

            VStack(spacing: 8) {
                HStack {
                    Text(String(localized: "提取颜色数量"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(primary.opacity(0.8))
                    Spacer()
                    Text("\(preferences.colorCount)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(secondary)
                }

                HStack(spacing: 6) {
                    ForEach(2...6, id: \.self) { count in
                        Button {
                            UnifiedColorEngine.shared.setExtractionColorCount(count)
                        } label: {
                            Text("\(count)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    preferences.colorCount == count
                                        ? Color.white
                                        : secondary
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(
                                            preferences.colorCount == count
                                                ? accent.opacity(0.82)
                                                : primary.opacity(darkStyle ? 0.05 : 0.04)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "\(String(localized: "提取颜色数量")) \(count)"
                        )
                        .accessibilityAddTraits(
                            preferences.colorCount == count ? .isSelected : []
                        )
                    }
                }
            }

            if preferences.mode == .random {
                Button {
                    UnifiedColorEngine.shared.reshuffleArtworkPalette()
                } label: {
                    HStack(spacing: 8) {
                        MonoIcon(icon: .refresh, size: 14, color: accent)
                        Text(String(localized: "重新随机"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(primary.opacity(0.84))
                        Spacer()
                    }
                    .frame(height: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: showsLivePreview ? player.currentSong?.coverUrl?.absoluteString : nil) {
            guard showsLivePreview else { return }
            previewColors.extract(
                from: player.currentSong?.coverUrl?.sized(240).absoluteString,
                force: true
            )
        }
    }

    private var liveEnginePreview: some View {
        HStack(spacing: 11) {
            if let coverURL = player.currentSong?.coverUrl?.sized(240) {
                CachedAsyncImage(url: coverURL, width: 46, height: 46) {
                    accent.opacity(0.12)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(String(localized: "实时取色"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(primary.opacity(0.76))

                HStack(spacing: 5) {
                    ForEach(Array(previewColors.palette.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(primary.opacity(0.12), lineWidth: 0.5))
                    }
                }
            }

            Spacer(minLength: 4)

            Text("Aa")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(previewColors.contentColor)
                .frame(width: 34, height: 34)
                .background(Circle().fill(previewColors.dominantColor))
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(primary.opacity(darkStyle ? 0.055 : 0.035))
        )
    }

    private func modeButton(_ mode: CoverPaletteMode) -> some View {
        let selected = preferences.mode == mode

        return Button {
            UnifiedColorEngine.shared.setExtractionMode(mode)
        } label: {
            Text(mode.label)
                .font(.system(size: 11, weight: selected ? .bold : .medium))
                .foregroundStyle(selected ? primary : secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            selected
                                ? accent.opacity(darkStyle ? 0.18 : 0.12)
                                : primary.opacity(darkStyle ? 0.035 : 0.025)
                        )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(
                            selected ? accent.opacity(0.5) : primary.opacity(0.06),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
