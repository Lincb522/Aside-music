import SwiftUI

struct ClarityThemeProvider: GlobalThemeProvider {
    let id: GlobalThemeId = .clarity

    var colorPalette: GlobalColorPalette {
        GlobalColorPalette(
            background: ClarityStyle.base,
            surface: ClarityStyle.membrane,
            primary: ClarityStyle.ink,
            secondary: ClarityStyle.inkSoft,
            accent: ClarityStyle.baseAccent,
            accentGradient: ClarityStyle.baseAccentGradient,
            separator: ClarityStyle.line,
            navBarTint: ClarityStyle.ink,
            iconBackground: ClarityStyle.membraneStrong,
            iconForeground: ClarityStyle.ink,
            cardBackground: ClarityStyle.membraneStrong,
            floatingBarFill: ClarityStyle.membraneStrong,
            destructive: ClarityStyle.destructive
        )
    }

    var typography: GlobalTypography {
        GlobalTypography(
            titleFont: { ClarityStyle.title($0, weight: .bold) },
            bodyFont: { ClarityStyle.body($0) },
            captionFont: { ClarityStyle.body($0, weight: .medium) },
            monoFont: { .system(size: $0, weight: .medium, design: .monospaced) },
            fontDesign: .default,
            letterSpacing: 0
        )
    }

    var shapeLanguage: GlobalShapeLanguage {
        GlobalShapeLanguage(cardRadius: 30, buttonRadius: 999, sheetRadius: 36, shadowStyle: .soft, borderWidth: 0.9)
    }

    var iconStyle: GlobalIconStyle {
        GlobalIconStyle(variant: .outlined, weight: .medium, badgeRadius: 999)
    }

    var animationStyle: GlobalAnimationStyle {
        GlobalAnimationStyle(
            pageTransition: .opacity.combined(with: .scale(scale: 0.992)),
            cardAppear: .spring(response: 0.44, dampingFraction: 0.9),
            buttonPress: .spring(response: 0.25, dampingFraction: 0.82),
            staggerDelay: 0.035
        )
    }

    var suggestedPlayerTheme: PlayerTheme? {
        .clarity
    }

    func makeHomeView() -> AnyView {
        AnyView(ClarityHomeView())
    }

    func makePodcastView() -> AnyView {
        AnyView(ClarityPodcastView())
    }

    func makeSearchView() -> AnyView {
        AnyView(ClaritySearchView())
    }

    func makeLibraryView() -> AnyView {
        AnyView(ClarityLibraryView())
    }

    func makeProfileView() -> AnyView {
        AnyView(ClarityProfileView())
    }

    func makeLocalHomeView() -> AnyView {
        AnyView(ClarityLocalHomeView())
    }

    func makeLocalMusicView() -> AnyView {
        AnyView(ClarityLocalMusicView())
    }

    func makeLocalLibraryView() -> AnyView {
        AnyView(ClarityLocalLibraryView())
    }

    func makeLocalProfileView() -> AnyView {
        AnyView(ClarityLocalProfileView())
    }
}
