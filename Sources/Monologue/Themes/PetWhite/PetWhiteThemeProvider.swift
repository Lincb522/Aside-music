import SwiftUI

struct PetWhiteThemeProvider: GlobalThemeProvider {
    let id: GlobalThemeId = .petWhite

    var colorPalette: GlobalColorPalette {
        GlobalColorPalette(
            background: PetWhiteStyle.base,
            surface: PetWhiteStyle.surface,
            primary: PetWhiteStyle.ink,
            secondary: PetWhiteStyle.inkSoft,
            accent: PetWhiteStyle.accent,
            accentGradient: PetWhiteStyle.accentGradient,
            separator: PetWhiteStyle.separator,
            navBarTint: PetWhiteStyle.stroke,
            iconBackground: PetWhiteStyle.mint,
            iconForeground: PetWhiteStyle.stroke,
            cardBackground: PetWhiteStyle.surfaceRaised,
            floatingBarFill: PetWhiteStyle.surfaceRaised,
            destructive: PetWhiteStyle.destructive
        )
    }

    var typography: GlobalTypography {
        GlobalTypography(
            titleFont: { size in PetWhiteStyle.titleFont(size, weight: .black) },
            bodyFont: { size in PetWhiteStyle.bodyFont(size, weight: .semibold) },
            captionFont: { size in PetWhiteStyle.labelFont(size, weight: .bold) },
            monoFont: { size in .system(size: size, weight: .bold, design: .monospaced) },
            fontDesign: .rounded,
            letterSpacing: 0
        )
    }

    var shapeLanguage: GlobalShapeLanguage {
        GlobalShapeLanguage(
            cardRadius: PetWhiteStyle.cardRadius,
            buttonRadius: 16,
            sheetRadius: 28,
            shadowStyle: .hard,
            borderWidth: PetWhiteStyle.strokeWidth
        )
    }

    var iconStyle: GlobalIconStyle {
        GlobalIconStyle(
            variant: .outlined,
            weight: .bold,
            badgeRadius: 16
        )
    }

    var animationStyle: GlobalAnimationStyle {
        GlobalAnimationStyle(
            pageTransition: .opacity.combined(with: .scale(scale: 0.985, anchor: .bottom)),
            cardAppear: .spring(response: 0.38, dampingFraction: 0.84),
            buttonPress: .spring(response: 0.18, dampingFraction: 0.72),
            staggerDelay: 0.035
        )
    }

    func makeHomeView() -> AnyView {
        AnyView(PetWhiteHomeView())
    }

    func makePodcastView() -> AnyView {
        AnyView(PetWhitePodcastView())
    }

    func makeSearchView() -> AnyView {
        AnyView(PetWhiteSearchView())
    }

    func makeLibraryView() -> AnyView {
        AnyView(PetWhiteLibraryView())
    }

    func makeProfileView() -> AnyView {
        AnyView(PetWhiteProfileView())
    }

    func makeLocalHomeView() -> AnyView {
        AnyView(PetWhiteLocalHomeView())
    }

    func makeLocalMusicView() -> AnyView {
        AnyView(PetWhiteLocalMusicView())
    }

    func makeLocalLibraryView() -> AnyView {
        AnyView(PetWhiteLocalLibraryView())
    }

    func makeLocalProfileView() -> AnyView {
        AnyView(PetWhiteLocalProfileView())
    }
}
