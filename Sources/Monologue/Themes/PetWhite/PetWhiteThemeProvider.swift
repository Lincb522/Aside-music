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
            navBarTint: PetWhiteStyle.ink,
            iconBackground: PetWhiteStyle.mint,
            iconForeground: PetWhiteStyle.ink,
            cardBackground: PetWhiteStyle.surfaceRaised,
            floatingBarFill: PetWhiteStyle.surfaceRaised,
            destructive: PetWhiteStyle.destructive
        )
    }

    var typography: GlobalTypography {
        GlobalTypography(
            titleFont: { size in PetWhiteStyle.titleFont(size, weight: .bold) },
            bodyFont: { size in PetWhiteStyle.bodyFont(size, weight: .medium) },
            captionFont: { size in PetWhiteStyle.labelFont(size, weight: .semibold) },
            monoFont: { size in .system(size: size, weight: .medium, design: .monospaced) },
            fontDesign: .rounded,
            letterSpacing: 0
        )
    }

    var shapeLanguage: GlobalShapeLanguage {
        GlobalShapeLanguage(
            cardRadius: PetWhiteStyle.cardRadius,
            buttonRadius: 20,
            sheetRadius: 34,
            shadowStyle: .soft,
            borderWidth: PetWhiteStyle.strokeWidth
        )
    }

    var iconStyle: GlobalIconStyle {
        GlobalIconStyle(
            variant: .outlined,
            weight: .medium,
            badgeRadius: 18
        )
    }

    var animationStyle: GlobalAnimationStyle {
        // 黏土手感：按压回弹更 Q，卡片入场带一点果冻感
        GlobalAnimationStyle(
            pageTransition: .opacity.combined(with: .scale(scale: 0.97, anchor: .bottom)),
            cardAppear: .spring(response: 0.44, dampingFraction: 0.72),
            buttonPress: .spring(response: 0.28, dampingFraction: 0.55),
            staggerDelay: 0.05
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
