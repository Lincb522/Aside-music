import SwiftUI

/// Sequoia — 清透系统材质、轻量层级、精致控件状态
struct SequoiaThemeProvider: GlobalThemeProvider {
    let id: GlobalThemeId = .sequoia

    var colorPalette: GlobalColorPalette {
        GlobalColorPalette(
            background: SequoiaStyle.base,
            surface: SequoiaStyle.materialList,
            primary: SequoiaStyle.ink,
            secondary: SequoiaStyle.inkSoft,
            accent: SequoiaStyle.accent,
            accentGradient: ThemeColorCustomization.accentGradientColors(
                for: .sequoia,
                fallback: [SequoiaStyle.accent, SequoiaStyle.aqua],
                fallbackHexes: ["0A84FF", "26AFCF"]
            ),
            separator: SequoiaStyle.separator,
            navBarTint: SequoiaStyle.ink,
            iconBackground: SequoiaStyle.selectedWash,
            iconForeground: SequoiaStyle.accent,
            cardBackground: SequoiaStyle.materialList,
            floatingBarFill: SequoiaStyle.materialFloating,
            destructive: SequoiaStyle.red
        )
    }

    var typography: GlobalTypography {
        GlobalTypography(
            titleFont: { size in .system(size: size, weight: .semibold, design: .default) },
            bodyFont: { size in .system(size: size, weight: .regular, design: .default) },
            captionFont: { size in .system(size: size, weight: .medium, design: .rounded) },
            monoFont: { size in .system(size: size, weight: .medium, design: .monospaced) },
            fontDesign: .default,
            letterSpacing: 0
        )
    }

    var shapeLanguage: GlobalShapeLanguage {
        GlobalShapeLanguage(
            cardRadius: SequoiaStyle.cardRadius,
            buttonRadius: SequoiaStyle.buttonRadius,
            sheetRadius: 28,
            shadowStyle: .soft,
            borderWidth: 0.5
        )
    }

    var iconStyle: GlobalIconStyle {
        GlobalIconStyle(
            variant: .outlined,
            weight: .medium,
            badgeRadius: 13
        )
    }

    var animationStyle: GlobalAnimationStyle {
        GlobalAnimationStyle(
            pageTransition: .opacity.combined(with: .scale(scale: 0.992)),
            cardAppear: .spring(response: 0.36, dampingFraction: 0.9),
            buttonPress: .spring(response: 0.2, dampingFraction: 0.86),
            staggerDelay: 0.03
        )
    }

    var suggestedPlayerTheme: PlayerTheme? {
        .classic
    }

    func makeHomeView() -> AnyView {
        AnyView(SequoiaHomeView())
    }

    func makePodcastView() -> AnyView {
        AnyView(SequoiaPodcastView())
    }

    func makeSearchView() -> AnyView {
        AnyView(SequoiaSearchView())
    }

    func makeLibraryView() -> AnyView {
        AnyView(SequoiaLibraryView())
    }

    func makeProfileView() -> AnyView {
        AnyView(SequoiaProfileView())
    }

    func makeLocalHomeView() -> AnyView {
        AnyView(SequoiaLocalHomeView())
    }

    func makeLocalMusicView() -> AnyView {
        AnyView(SequoiaLocalMusicView())
    }

    func makeLocalLibraryView() -> AnyView {
        AnyView(SequoiaLocalLibraryView())
    }

    func makeLocalProfileView() -> AnyView {
        AnyView(SequoiaLocalProfileView())
    }
}
