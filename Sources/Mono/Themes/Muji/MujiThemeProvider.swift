import SwiftUI

/// 无印良品主题 — 青苔手帖：青竹绿 + 杏子暖 + 水洗色块，文艺清新
struct MujiThemeProvider: GlobalThemeProvider {
    let id: GlobalThemeId = .muji

    // ── 视觉 Token ──

    var colorPalette: GlobalColorPalette {
        GlobalColorPalette(
            background: MujiStyle.paper,
            surface: MujiStyle.surface,
            primary: MujiStyle.ink,
            secondary: MujiStyle.inkSoft,
            accent: MujiStyle.clay,
            accentGradient: ThemeColorCustomization.accentGradientColors(
                for: .muji,
                fallback: [MujiStyle.clay, MujiStyle.tea, MujiStyle.indigo],
                fallbackHexes: ["5C8A6A", "C89B66"]
            ),
            separator: MujiStyle.separator,
            navBarTint: MujiStyle.ink,
            iconBackground: MujiStyle.clay,
            iconForeground: MujiStyle.onTint,
            cardBackground: MujiStyle.surfaceRaised,
            floatingBarFill: MujiStyle.surface.opacity(0.94),
            destructive: MujiStyle.red
        )
    }

    var typography: GlobalTypography {
        GlobalTypography(
            titleFont: { size in .system(size: size, weight: .medium, design: .serif) },
            bodyFont: { size in .system(size: size, weight: .regular, design: .serif) },
            captionFont: { size in .system(size: size, weight: .medium, design: .rounded) },
            monoFont: { size in .system(size: size, weight: .regular, design: .monospaced) },
            fontDesign: .serif,
            letterSpacing: 0.3
        )
    }

    var shapeLanguage: GlobalShapeLanguage {
        GlobalShapeLanguage(
            cardRadius: 18,
            buttonRadius: 12,
            sheetRadius: 26,
            shadowStyle: .soft,
            borderWidth: 0
        )
    }

    var iconStyle: GlobalIconStyle {
        GlobalIconStyle(
            variant: .outlined,
            weight: .light,
            badgeRadius: 9
        )
    }

    var animationStyle: GlobalAnimationStyle {
        GlobalAnimationStyle(
            pageTransition: .opacity,
            cardAppear: .spring(response: 0.5, dampingFraction: 0.86),
            buttonPress: .spring(response: 0.3, dampingFraction: 0.75),
            staggerDelay: 0.07
        )
    }

    var suggestedPlayerTheme: PlayerTheme? { .muji }

    // ── 布局工厂 ──

    func makeHomeView() -> AnyView {
        AnyView(MujiHomeView())
    }

    func makePodcastView() -> AnyView {
        AnyView(MujiPodcastView())
    }

    func makeSearchView() -> AnyView {
        AnyView(MujiSearchView())
    }

    func makeLibraryView() -> AnyView {
        AnyView(MujiLibraryView())
    }

    func makeProfileView() -> AnyView {
        AnyView(MujiProfileView())
    }

    func makeLocalHomeView() -> AnyView {
        AnyView(MujiLocalHomeView())
    }

    func makeLocalMusicView() -> AnyView {
        AnyView(MujiLocalMusicView())
    }

    func makeLocalLibraryView() -> AnyView {
        AnyView(MujiLocalLibraryView())
    }

    func makeLocalProfileView() -> AnyView {
        AnyView(MujiLocalProfileView())
    }
}
