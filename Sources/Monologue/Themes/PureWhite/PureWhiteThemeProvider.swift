import SwiftUI

struct PureWhiteThemeProvider: GlobalThemeProvider {
    let id: GlobalThemeId = .pureWhite

    var colorPalette: GlobalColorPalette {
        GlobalColorPalette(
            background: PureWhiteStyle.base,
            surface: PureWhiteStyle.surface,
            primary: PureWhiteStyle.ink,
            secondary: PureWhiteStyle.inkSoft,
            accent: PureWhiteStyle.accent,
            accentGradient: PureWhiteStyle.accentGradient,
            separator: PureWhiteStyle.separator,
            navBarTint: PureWhiteStyle.ink,
            iconBackground: PureWhiteStyle.paperBlue,
            iconForeground: PureWhiteStyle.strokeInk,
            cardBackground: PureWhiteStyle.surfaceRaised,
            floatingBarFill: PureWhiteStyle.surfaceRaised.opacity(0.985),
            destructive: PureWhiteStyle.coral
        )
    }

    var typography: GlobalTypography {
        GlobalTypography(
            titleFont: { size in PureWhiteStyle.titleFont(size, weight: .black) },
            bodyFont: { size in PureWhiteStyle.bodyFont(size) },
            captionFont: { size in PureWhiteStyle.labelFont(size) },
            monoFont: { size in .system(size: size, weight: .bold, design: .monospaced) },
            fontDesign: .rounded,
            letterSpacing: 0
        )
    }

    var shapeLanguage: GlobalShapeLanguage {
        GlobalShapeLanguage(
            cardRadius: PureWhiteStyle.cardRadius,
            buttonRadius: 14,
            sheetRadius: 26,
            shadowStyle: .soft,
            borderWidth: PureWhiteStyle.strokeWidth
        )
    }

    var iconStyle: GlobalIconStyle {
        GlobalIconStyle(
            variant: .outlined,
            weight: .bold,
            badgeRadius: 14
        )
    }

    var animationStyle: GlobalAnimationStyle {
        GlobalAnimationStyle(
            pageTransition: .opacity.combined(with: .scale(scale: 0.992, anchor: .bottom)),
            cardAppear: .spring(response: 0.34, dampingFraction: 0.78),
            buttonPress: .spring(response: 0.18, dampingFraction: 0.7),
            staggerDelay: 0.032
        )
    }

    func makeHomeView() -> AnyView {
        AnyView(PureWhiteHomeView())
    }

    func makePodcastView() -> AnyView {
        AnyView(PureWhitePodcastView())
    }

    func makeSearchView() -> AnyView {
        AnyView(PureWhiteSearchView())
    }

    func makeLibraryView() -> AnyView {
        AnyView(PureWhiteLibraryView())
    }

    func makeProfileView() -> AnyView {
        AnyView(PureWhiteProfileView())
    }

    func makeLocalHomeView() -> AnyView {
        AnyView(PureWhiteLocalHomeView())
    }

    func makeLocalMusicView() -> AnyView {
        AnyView(PureWhiteLocalMusicView())
    }

    func makeLocalLibraryView() -> AnyView {
        AnyView(PureWhiteLocalLibraryView())
    }

    func makeLocalProfileView() -> AnyView {
        AnyView(PureWhiteLocalProfileView())
    }
}
