import SwiftUI

struct MaterialThemeProvider: GlobalThemeProvider {
    let id: GlobalThemeId = .material

    var colorPalette: GlobalColorPalette {
        GlobalColorPalette(
            background: MaterialStyle.base,
            surface: MaterialStyle.surfaceContainer,
            primary: MaterialStyle.ink,
            secondary: MaterialStyle.inkSoft,
            accent: MaterialStyle.primary,
            accentGradient: ThemeColorCustomization.accentGradientColors(
                for: .material,
                fallback: [MaterialStyle.primary, MaterialStyle.tertiary],
                fallbackHexes: ["6750A4", "7D5260"]
            ),
            separator: MaterialStyle.outline,
            navBarTint: MaterialStyle.ink,
            iconBackground: MaterialStyle.primary.opacity(0.12),
            iconForeground: MaterialStyle.primary,
            cardBackground: MaterialStyle.surfaceContainer,
            floatingBarFill: MaterialStyle.surfaceContainerHighest,
            destructive: MaterialStyle.error
        )
    }

    var typography: GlobalTypography {
        GlobalTypography(
            titleFont: { size in .system(size: size, weight: .semibold, design: .rounded) },
            bodyFont: { size in .system(size: size, weight: .regular, design: .rounded) },
            captionFont: { size in .system(size: size, weight: .medium, design: .rounded) },
            monoFont: { size in .system(size: size, weight: .medium, design: .monospaced) },
            fontDesign: .rounded,
            letterSpacing: 0
        )
    }

    var shapeLanguage: GlobalShapeLanguage {
        GlobalShapeLanguage(
            cardRadius: MaterialStyle.cardRadius,
            buttonRadius: MaterialStyle.buttonRadius,
            sheetRadius: MaterialStyle.sheetRadius,
            shadowStyle: .soft,
            borderWidth: 0.8
        )
    }

    var iconStyle: GlobalIconStyle {
        GlobalIconStyle(
            variant: .outlined,
            weight: .medium,
            badgeRadius: MaterialStyle.compactRadius
        )
    }

    var animationStyle: GlobalAnimationStyle {
        GlobalAnimationStyle(
            pageTransition: .opacity.combined(with: .scale(scale: 0.985)),
            cardAppear: .spring(response: 0.34, dampingFraction: 0.9),
            buttonPress: .spring(response: 0.22, dampingFraction: 0.86),
            staggerDelay: 0.026
        )
    }

    func makeHomeView() -> AnyView {
        AnyView(MaterialHomeView())
    }

    func makePodcastView() -> AnyView {
        AnyView(MaterialPodcastView())
    }

    func makeSearchView() -> AnyView {
        AnyView(MaterialSearchView())
    }

    func makeLibraryView() -> AnyView {
        AnyView(MaterialLibraryView())
    }

    func makeProfileView() -> AnyView {
        AnyView(MaterialProfileView())
    }

    func makeLocalHomeView() -> AnyView {
        AnyView(MaterialLocalHomeView())
    }

    func makeLocalMusicView() -> AnyView {
        AnyView(MaterialLocalMusicView())
    }

    func makeLocalLibraryView() -> AnyView {
        AnyView(MaterialLocalLibraryView())
    }

    func makeLocalProfileView() -> AnyView {
        AnyView(MaterialLocalProfileView())
    }
}
