import Combine
import SwiftUI
import UIKit

/// `Color.mono*` 是同步语义 token，不能在 getter 中跨 actor await。
/// 这个镜像只由主线程引擎发布，让已有的同步设计系统安全读取最新快照。
enum UnifiedColorRuntime {
    nonisolated(unsafe) private(set) static var colors: GlobalColorPalette?
    /// Theme-owned structural palette. This never contains artwork-derived
    /// colors and is used by settings containers, alerts, sheets and menus.
    nonisolated(unsafe) private(set) static var structuralColors: GlobalColorPalette?
    nonisolated(unsafe) private(set) static var onAccent: Color?
    nonisolated(unsafe) private(set) static var themeId: GlobalThemeId?

    @MainActor
    static func publish(_ snapshot: UnifiedColorEngine.Snapshot) {
        colors = snapshot.resolved
        structuralColors = snapshot.base
        onAccent = snapshot.onAccent
        themeId = snapshot.themeId
    }
}

/// 全局颜色的工作模式。主题负责品牌基因，封面取色负责当前音乐的环境氛围。
enum GlobalColorEngineMode: String, CaseIterable, Identifiable, Sendable {
    case theme
    case fusion
    case artwork

    var id: String { rawValue }

    var title: String {
        switch self {
        case .theme: return String(localized: "color_engine_mode_theme")
        case .fusion: return String(localized: "color_engine_mode_fusion")
        case .artwork: return String(localized: "color_engine_mode_artwork")
        }
    }

    var detail: String {
        switch self {
        case .theme: return String(localized: "color_engine_mode_theme_desc")
        case .fusion: return String(localized: "color_engine_mode_fusion_desc")
        case .artwork: return String(localized: "color_engine_mode_artwork_desc")
        }
    }
}

@MainActor
final class GlobalColorEnginePreferences: ObservableObject {
    static let shared = GlobalColorEnginePreferences()

    @Published var mode: GlobalColorEngineMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "globalColorEngine.mode")
        }
    }

    private init() {
        mode = GlobalColorEngineMode(
            rawValue: UserDefaults.standard.string(forKey: "globalColorEngine.mode") ?? ""
        ) ?? .fusion
    }
}

/// 主题 token 与封面取色的唯一全局入口。
///
/// `MonoColorEngine` 保留为底层图像分析器（缓存、去重、聚类）；业务层不再直接组装
/// 主题色与封面色，而是由本引擎一次性输出背景、表面、文字、强调色与环境渐变。
@MainActor
final class UnifiedColorEngine: ObservableObject {
    static let shared = UnifiedColorEngine()

    struct Snapshot {
        let themeId: GlobalThemeId
        let mode: GlobalColorEngineMode
        let base: GlobalColorPalette
        let resolved: GlobalColorPalette
        let ambient: [Color]
        let artwork: UIImage.ExtractedColors?
        let artworkIdentity: String?
        let onAccent: Color
    }

    @Published private(set) var snapshot: Snapshot
    @Published private(set) var revision: Int = 0
    @Published private(set) var isStarted = false

    var colors: GlobalColorPalette { snapshot.resolved }
    var ambientColors: [Color] { snapshot.ambient }
    var onAccent: Color { snapshot.onAccent }
    var hasArtworkPalette: Bool { snapshot.artwork != nil }
    var mode: GlobalColorEngineMode { snapshot.mode }

    private let preferences = GlobalColorEnginePreferences.shared
    private var cancellables = Set<AnyCancellable>()
    private var artworkTask: Task<Void, Never>?
    private var requestedArtworkIdentity: String?

    private init() {
        let initialMode = GlobalColorEnginePreferences.shared.mode
        let initialTheme = GlobalThemeId.persistedOrDefault
        let base = GlobalColorPalette.default
        snapshot = Snapshot(
            themeId: initialTheme,
            mode: initialMode,
            base: base,
            resolved: base,
            ambient: base.accentGradient,
            artwork: nil,
            artworkIdentity: nil,
            onAccent: ThemeColorCustomization.accentForegroundColor(for: initialTheme)
        )
    }

    /// 只在根渲染宿主出现后绑定播放状态，避免 App 冷启动阶段提前创建整套播放引擎。
    func start() {
        guard !isStarted else { return }
        isStarted = true
        UnifiedColorRuntime.publish(snapshot)

        let themeManager = GlobalThemeManager.shared
        let player = PlayerManager.shared

        themeManager.$currentThemeId
            .combineLatest(themeManager.$tokenRevision)
            .dropFirst()
            .sink { [weak self] _, _ in
                self?.refreshTheme()
            }
            .store(in: &cancellables)

        preferences.$mode
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.rebuildSnapshot()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .monoColorConfigurationDidChange)
            .sink { [weak self] _ in
                self?.reloadCurrentArtwork()
            }
            .store(in: &cancellables)

        player.$currentSong
            .map { $0?.coverUrl?.absoluteString }
            .removeDuplicates()
            .sink { [weak self] urlString in
                self?.setNowPlayingArtwork(urlString)
            }
            .store(in: &cancellables)

        refreshTheme()
    }

    func refreshTheme() {
        rebuildSnapshot()
    }

    /// 为现有封面、歌词和播放器提供同一取色入口。
    func artworkColors(
        for urlString: String,
        minimumCount: Int = 2
    ) async -> UIImage.ExtractedColors? {
        await MonoColorEngine.shared.configuredColors(
            for: urlString,
            minimumCount: minimumCount
        )
    }

    func setExtractionColorCount(_ count: Int) {
        MonoColorEngine.shared.setColorCount(count)
    }

    func setExtractionMode(_ mode: CoverPaletteMode) {
        MonoColorEngine.shared.setMode(mode)
    }

    func reshuffleArtworkPalette() {
        MonoColorEngine.shared.reshuffle()
    }

    nonisolated static func analyzeArtwork(
        image: UIImage,
        count: Int = 6,
        mode: CoverPaletteMode = .adaptive,
        randomSeed: Int = 0,
        sourceSeed: Int = 0
    ) -> UIImage.ExtractedColors {
        MonoColorEngine.analyze(
            image: image,
            count: count,
            mode: mode,
            randomSeed: randomSeed,
            sourceSeed: sourceSeed
        )
    }

    private func reloadCurrentArtwork() {
        guard let identity = requestedArtworkIdentity else {
            rebuildSnapshot()
            return
        }
        requestedArtworkIdentity = nil
        setNowPlayingArtwork(identity)
    }

    private func setNowPlayingArtwork(_ urlString: String?) {
        artworkTask?.cancel()
        requestedArtworkIdentity = urlString

        guard let urlString, !urlString.isEmpty else {
            rebuildSnapshot(artwork: nil, artworkIdentity: nil, preserveArtwork: false)
            return
        }

        // 切歌时先回到主题基准，不让旧封面色污染新歌。
        rebuildSnapshot(artwork: nil, artworkIdentity: urlString, preserveArtwork: false)

        artworkTask = Task { [weak self] in
            guard let self else { return }
            let colors = await artworkColors(for: urlString, minimumCount: 4)
            guard !Task.isCancelled,
                  requestedArtworkIdentity == urlString else { return }
            rebuildSnapshot(artwork: colors, artworkIdentity: urlString, preserveArtwork: false)
        }
    }

    private func rebuildSnapshot(
        artwork: UIImage.ExtractedColors? = nil,
        artworkIdentity: String? = nil,
        preserveArtwork: Bool = true
    ) {
        let themeManager = GlobalThemeManager.shared
        let themeId = themeManager.currentThemeId
        let base = themeManager.current.colorPalette
        let retainedArtwork: UIImage.ExtractedColors?
        let retainedIdentity: String?

        if preserveArtwork {
            retainedArtwork = snapshot.artwork
            retainedIdentity = snapshot.artworkIdentity
        } else {
            retainedArtwork = artwork
            retainedIdentity = artworkIdentity
        }

        let mode = preferences.mode
        let resolved = Self.resolve(base: base, artwork: retainedArtwork, mode: mode)
        let ambient = Self.ambientColors(
            base: base,
            artwork: retainedArtwork,
            resolved: resolved,
            mode: mode
        )
        let baseOnAccent = ThemeColorCustomization.accentForegroundColor(for: themeId)
        let resolvedOnAccent = mode == .theme || retainedArtwork == nil
            ? baseOnAccent
            : Self.mix(
                baseOnAccent,
                Self.readableForeground(on: resolved.accent),
                amount: 1
            )

        snapshot = Snapshot(
            themeId: themeId,
            mode: mode,
            base: base,
            resolved: resolved,
            ambient: ambient,
            artwork: retainedArtwork,
            artworkIdentity: retainedIdentity,
            onAccent: resolvedOnAccent
        )
        UnifiedColorRuntime.publish(snapshot)
        revision &+= 1
    }

    private static func resolve(
        base: GlobalColorPalette,
        artwork: UIImage.ExtractedColors?,
        mode: GlobalColorEngineMode
    ) -> GlobalColorPalette {
        guard mode != .theme, let artwork else { return base }

        let dominant = artwork.dominant
        let secondary = artwork.secondary
        let artworkWeight = mode == .artwork ? 0.84 : 0.58
        let backgroundWeight = mode == .artwork ? 0.30 : 0.14
        let accent = mix(base.accent, dominant, amount: artworkWeight)
        let background = mix(base.background, dominant, amount: backgroundWeight)
        let artworkGradient = [accent, secondary] + Array(artwork.palette.dropFirst(2).prefix(3))
        let baseGradient = base.accentGradient.isEmpty ? [base.accent] : base.accentGradient
        let gradient = artworkGradient.enumerated().map { index, color in
            let darkBase = baseGradient[index % baseGradient.count]
            return mix(darkBase, color, amount: 1)
        }
        return GlobalColorPalette(
            background: background,
            // Structural materials are theme-owned. Artwork color must never
            // leak into settings containers, alerts, sheets or context menus.
            surface: base.surface,
            primary: base.primary,
            secondary: base.secondary,
            accent: accent,
            accentGradient: gradient,
            separator: base.separator,
            navBarTint: accent,
            iconBackground: base.iconBackground,
            iconForeground: base.iconForeground,
            cardBackground: base.cardBackground,
            floatingBarFill: base.floatingBarFill,
            destructive: base.destructive
        )
    }

    private static func ambientColors(
        base: GlobalColorPalette,
        artwork: UIImage.ExtractedColors?,
        resolved: GlobalColorPalette,
        mode: GlobalColorEngineMode
    ) -> [Color] {
        guard mode != .theme, let artwork else {
            return Array((base.accentGradient + [base.background]).prefix(6))
        }
        return Array(([resolved.accent] + artwork.palette + [resolved.background]).prefix(6))
    }

    private static func readableForeground(on color: Color) -> Color {
        ThemeColorCustomization.readableForegroundColor(
            on: color,
            light: Color(hex: "10151B"),
            dark: .white
        )
    }

    private static func mix(_ base: Color, _ overlay: Color, amount: Double) -> Color {
        let clamped = min(max(amount, 0), 1)
        return Color(
            light: mix(base, overlay, amount: clamped, style: .light),
            // 深色模式必须保留主题原始 token。封面色只作用于浅色分支，
            // 避免背景、图标、文字和选中态被同一封面色同时拉低对比度。
            dark: mix(base, overlay, amount: 0, style: .dark)
        )
    }

    private static func mix(
        _ base: Color,
        _ overlay: Color,
        amount: Double,
        style: UIUserInterfaceStyle
    ) -> Color {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let lhs = UIColor(base).resolvedColor(with: traits)
        let rhs = UIColor(overlay).resolvedColor(with: traits)
        var lr: CGFloat = 0
        var lg: CGFloat = 0
        var lb: CGFloat = 0
        var la: CGFloat = 0
        var rr: CGFloat = 0
        var rg: CGFloat = 0
        var rb: CGFloat = 0
        var ra: CGFloat = 0
        guard lhs.getRed(&lr, green: &lg, blue: &lb, alpha: &la),
              rhs.getRed(&rr, green: &rg, blue: &rb, alpha: &ra) else {
            return overlay
        }
        let t = CGFloat(amount)
        return Color(
            uiColor: UIColor(
                red: lr + (rr - lr) * t,
                green: lg + (rg - lg) * t,
                blue: lb + (rb - lb) * t,
                alpha: la + (ra - la) * t
            )
        )
    }
}

/// 各主题背景共用的环境染色层，保留主题纹理，只改变光与色温。
struct UnifiedColorAmbientLayer: View {
    @ObservedObject private var engine = UnifiedColorEngine.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var strength: Double = 0.5
    var appliesAdditionalBlur = true

    @ViewBuilder
    var body: some View {
        let paletteLayer = DynamicCoverPaletteLayer(
            colors: engine.ambientColors,
            opacity: resolvedOpacity
        )

        if appliesAdditionalBlur {
            paletteLayer
                .blur(radius: engine.hasArtworkPalette ? 34 : 52)
                .saturation(engine.mode == .artwork ? 1.06 : 0.9)
                .animation(.easeOut(duration: 0.5), value: engine.revision)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            // DynamicCoverPaletteLayer already uses feathered radial gradients.
            // Clarity renders those gradients directly to avoid a second
            // viewport-sized blur texture while retaining the complete palette.
            paletteLayer
                .saturation(engine.mode == .artwork ? 1.06 : 0.9)
                .animation(.easeOut(duration: 0.5), value: engine.revision)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var resolvedOpacity: Double {
        guard !reduceTransparency, colorScheme != .dark else { return 0 }
        switch engine.mode {
        case .theme:
            return 0
        case .fusion:
            return strength * (engine.hasArtworkPalette ? 0.82 : 0.34)
        case .artwork:
            return strength * (engine.hasArtworkPalette ? 1.08 : 0.42)
        }
    }
}

/// 设置页只展示策略与取色参数，颜色组装仍完全由 `UnifiedColorEngine` 处理。
struct UnifiedColorEngineSettingsControls: View {
    @ObservedObject private var engine = UnifiedColorEngine.shared
    @ObservedObject private var preferences = GlobalColorEnginePreferences.shared
    @Environment(\.colorScheme) private var colorScheme

    let accent: Color

    private var resolvedAccent: Color {
        engine.isStarted ? engine.colors.accent : accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                ForEach(GlobalColorEngineMode.allCases) { mode in
                    Button {
                        preferences.mode = mode
                    } label: {
                        Text(mode.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(preferences.mode == mode ? engine.onAccent : Color.monoTextSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(preferences.mode == mode ? resolvedAccent : Color.monoTextPrimary.opacity(0.045))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(preferences.mode == mode ? .isSelected : [])
                }
            }

            Text(preferences.mode.detail)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.monoTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if colorScheme == .dark {
                Text(String(localized: "color_engine_dark_mode_guard"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.monoTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                ForEach(Array(engine.ambientColors.prefix(6).enumerated()), id: \.offset) { _, color in
                    Capsule(style: .continuous)
                        .fill(color)
                        .frame(maxWidth: .infinity)
                        .frame(height: 10)
                }
            }
            .animation(.easeOut(duration: 0.3), value: engine.revision)

            CoverPaletteSettingsControls(
                accent: resolvedAccent,
                darkStyle: false,
                showsLivePreview: true
            )
        }
    }
}
