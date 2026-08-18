import SwiftUI

// 主题渲染层基础设施：为不同主题按需开启渲染隔离（compositingGroup）
// 与动画抑制，缓解高成本主题背景在滚动/频繁重绘场景下的性能问题。

/// 当前主题渲染环境的快照，各 `isolates*/stabilizes*` 开关按主题特性决定哪些角色需要优化。
struct ThemeRenderContext: Equatable {
    let theme: GlobalThemeId
    let revision: Int
    let colorScheme: ColorScheme
    let isHosted: Bool

    var isDark: Bool {
        colorScheme == .dark
    }

    var backdropIdentity: String {
        [
            theme.rawValue,
            isDark ? "dark" : "light",
        ].joined(separator: "-")
    }

    var usesManagedRenderLayers: Bool {
        isHosted
    }

    var providesGlobalBackdrop: Bool {
        false
    }

    var stabilizesSceneRendering: Bool {
        isHosted
    }

    var stabilizesScrollRendering: Bool {
        isHosted && theme != .default
    }

    var isolatesExpensiveSurfaces: Bool {
        isHosted && (theme == .manga || theme == .minimalWhite || theme == .petWhite)
    }

    var stabilizesLightweightSurfaces: Bool {
        isHosted && (theme == .neumorphic || theme == .capsule || theme == .clarity || theme == .minimalWhite || theme == .petWhite)
    }

    var isolatesFrequentRows: Bool {
        isHosted && (theme == .neumorphic || theme == .capsule || theme == .clarity || theme == .minimalWhite || theme == .petWhite)
    }

    var isolatesInteractiveSurfaces: Bool {
        isHosted && (theme == .neumorphic || theme == .manga || theme == .capsule || theme == .clarity || theme == .minimalWhite || theme == .petWhite)
    }
}

/// 视图在渲染优化中扮演的角色，决定应用哪种优化策略。
enum ThemeRenderLayerRole {
    case scene
    case scroll
    case surface
    case row
    case sheet
    case interactive
}

private struct ThemeRenderContextKey: EnvironmentKey {
    static let defaultValue = ThemeRenderContext(
        theme: .default,
        revision: 0,
        colorScheme: .light,
        isHosted: false
    )
}

private struct ThemeRenderHostActiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var themeRenderContext: ThemeRenderContext {
        get { self[ThemeRenderContextKey.self] }
        set { self[ThemeRenderContextKey.self] = newValue }
    }

    var themeRenderHostActive: Bool {
        get { self[ThemeRenderHostActiveKey.self] }
        set { self[ThemeRenderHostActiveKey.self] = newValue }
    }
}

/// 渲染宿主：在内容下方铺主题底色，并向子树注入 `themeRenderContext` 环境值。
/// 应用根视图与独立展示层（如全屏播放器）各自包一层。
struct ThemeRenderHost<Content: View>: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var colorEngine = UnifiedColorEngine.shared
    @Environment(\.colorScheme) private var colorScheme

    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            ThemeRenderUnderlay(theme: renderContext.theme, revision: renderContext.revision)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            if renderContext.providesGlobalBackdrop {
                ThemeRenderBackdrop(theme: renderContext.theme, revision: renderContext.revision)
                    .id("managed-backdrop-\(renderContext.backdropIdentity)")
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transaction { transaction in
                        transaction.animation = nil
                        transaction.disablesAnimations = true
                    }
            }

            content()
                .environment(\.themeRenderContext, renderContext)
                .environment(\.themeRenderHostActive, true)
                .environment(\.themeCustomizationRevision, renderContext.revision)
        }
        .onAppear {
            colorEngine.start()
        }
    }

    private var renderContext: ThemeRenderContext {
        ThemeRenderContext(
            theme: settings.globalThemeId,
            revision: settings.globalThemeRevision &* 31 &+ colorEngine.revision,
            colorScheme: colorScheme,
            isHosted: true
        )
    }
}

/// 各主题的纯色底色层，防止内容间隙露出系统背景。
struct ThemeRenderUnderlay: View {
    let theme: GlobalThemeId
    var revision: Int = 0
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var colorEngine = UnifiedColorEngine.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let _ = revision
        let _ = settings.globalThemeRevision

        ZStack {
            baseColor

            DynamicCoverPaletteLayer(
                colors: colorEngine.ambientColors,
                opacity: ambientOpacity
            )
            .blur(radius: colorEngine.hasArtworkPalette ? 34 : 52)
            .saturation(colorEngine.mode == .artwork ? 1.04 : 0.88)

            LinearGradient(
                colors: [
                    Color.white.opacity(colorEngine.hasArtworkPalette ? 0.10 : 0.18),
                    Color.clear,
                    colorEngine.colors.background.opacity(0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .animation(.easeOut(duration: 0.5), value: colorEngine.revision)
    }

    private var baseColor: Color {
        if colorEngine.isStarted {
            return colorEngine.colors.background
        }
        switch theme {
        case .manga: return MangaStyle.paper
        case .minimalWhite: return MinimalWhiteStyle.paper
        case .petWhite: return PetWhiteStyle.paper
        case .muji: return MujiStyle.paper
        case .neumorphic: return NeumorphicStyle.base
        case .capsule: return CapsuleStyle.base
        case .clarity: return ClarityStyle.base
        case .default: return Color.monoBackground
        }
    }

    private var ambientOpacity: Double {
        guard !reduceTransparency, colorScheme != .dark else { return 0 }
        switch colorEngine.mode {
        case .theme: return 0
        case .fusion: return colorEngine.hasArtworkPalette ? 0.70 : 0.30
        case .artwork: return colorEngine.hasArtworkPalette ? 0.92 : 0.38
        }
    }
}

/// 各主题的完整背景层（含纹理/渐变），目前仅在 `providesGlobalBackdrop` 开启时使用。
struct ThemeRenderBackdrop: View {
    let theme: GlobalThemeId
    var revision: Int = 0
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = revision
        let _ = settings.globalThemeRevision

        switch theme {
        case .manga:
            MangaRootBackdrop()
        case .minimalWhite:
            MinimalWhiteRootBackdrop()
        case .petWhite:
            PetWhiteRootBackdrop()
        case .muji:
            MujiRootBackdrop()
        case .neumorphic:
            NeumorphicRenderBackdrop()
        case .capsule:
            CapsuleRootBackdrop()
        case .clarity:
            ClarityBackdrop()
        case .default:
            MonoBackground()
                .ignoresSafeArea()
        }
    }
}

struct NeumorphicRenderBackdrop: View {
    var body: some View {
        NeumorphicRootBackdrop()
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
    }
}

/// 按角色应用渲染优化：scroll/row 禁用隐式动画，surface/sheet 合成分组隔离，
/// scene/interactive 对 Neumorphic 保留原动画；未在宿主内时直接透传。
private struct ThemeRenderLayerModifier: ViewModifier {
    let role: ThemeRenderLayerRole
    let isEnabled: Bool

    @Environment(\.themeRenderContext) private var renderContext

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled && renderContext.usesManagedRenderLayers {
            rendered(content)
        } else {
            content
        }
    }

    @ViewBuilder
    private func rendered(_ content: Content) -> some View {
        switch role {
        case .scene:
            if renderContext.stabilizesSceneRendering {
                content
                    .transaction { transaction in
                        if renderContext.theme == .neumorphic {
                            transaction.animation = transaction.animation
                        }
                    }
            } else {
                content
            }

        case .scroll:
            if renderContext.stabilizesScrollRendering {
                content
                    .transaction { transaction in
                        transaction.animation = nil
                    }
            } else {
                content
            }

        case .surface:
            if renderContext.isolatesExpensiveSurfaces {
                content
                    .compositingGroup()
            } else {
                content
            }

        case .row:
            if renderContext.isolatesFrequentRows || renderContext.stabilizesLightweightSurfaces {
                content
                    .transaction { transaction in
                        transaction.animation = nil
                    }
            } else {
                content
            }

        case .sheet:
            if renderContext.isolatesExpensiveSurfaces {
                content
                    .compositingGroup()
                    .transaction { transaction in
                        transaction.animation = MonoAnimation.panelToggle
                    }
            } else {
                content
            }

        case .interactive:
            if renderContext.isolatesInteractiveSurfaces {
                content
                    .transaction { transaction in
                        if renderContext.theme == .neumorphic {
                            transaction.animation = transaction.animation
                        }
                    }
            } else {
                content
            }
        }
    }
}

extension View {
    /// 标记视图的渲染角色；以下为各角色的便捷入口。
    func themeRenderLayer(_ role: ThemeRenderLayerRole, isEnabled: Bool = true) -> some View {
        modifier(ThemeRenderLayerModifier(role: role, isEnabled: isEnabled))
    }

    func themeRenderSceneLayer(isEnabled: Bool = true) -> some View {
        themeRenderLayer(.scene, isEnabled: isEnabled)
    }

    func themeRenderScrollLayer(isEnabled: Bool = true) -> some View {
        themeRenderLayer(.scroll, isEnabled: isEnabled)
    }

    func themeRenderSurfaceLayer(isEnabled: Bool = true) -> some View {
        themeRenderLayer(.surface, isEnabled: isEnabled)
    }

    func themeRenderRowLayer(isEnabled: Bool = true) -> some View {
        themeRenderLayer(.row, isEnabled: isEnabled)
    }

    func themeRenderSheetLayer(isEnabled: Bool = true) -> some View {
        themeRenderLayer(.sheet, isEnabled: isEnabled)
    }

    func themeRenderInteractiveLayer(isEnabled: Bool = true) -> some View {
        themeRenderLayer(.interactive, isEnabled: isEnabled)
    }
}
