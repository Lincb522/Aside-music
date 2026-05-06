import SwiftUI

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
            "\(revision)",
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
        isHosted && theme == .manga
    }

    var stabilizesLightweightSurfaces: Bool {
        isHosted && theme == .neumorphic
    }

    var isolatesFrequentRows: Bool {
        isHosted && theme == .neumorphic
    }

    var isolatesInteractiveSurfaces: Bool {
        isHosted && (theme == .neumorphic || theme == .manga)
    }
}

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

struct ThemeRenderHost<Content: View>: View {
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
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

            content
                .environment(\.themeRenderContext, renderContext)
                .environment(\.themeRenderHostActive, true)
                .environment(\.themeCustomizationRevision, renderContext.revision)
        }
    }

    private var renderContext: ThemeRenderContext {
        ThemeRenderContext(
            theme: settings.globalThemeId,
            revision: settings.globalThemeRevision,
            colorScheme: colorScheme,
            isHosted: true
        )
    }
}

struct ThemeRenderUnderlay: View {
    let theme: GlobalThemeId
    var revision: Int = 0
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = revision
        let _ = settings.globalThemeRevision

        switch theme {
        case .manga:
            MangaStyle.paper
        case .muji:
            MujiStyle.paper
        case .neumorphic:
            NeumorphicStyle.base
        case .bento, .sequoia, .liquidGlass, .clay, .signal, .default:
            Color.monologueBackground
        }
    }
}

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
        case .muji:
            MujiRootBackdrop()
        case .neumorphic:
            NeumorphicRenderBackdrop()
        case .bento, .sequoia, .liquidGlass, .clay, .signal, .default:
            MonologueBackground()
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
                        transaction.animation = MonologueAnimation.panelToggle
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
