import SwiftUI

/// 漫画风主题 — 纸张分格、粗墨线、网点与硬阴影
struct MangaThemeProvider: GlobalThemeProvider {
    let id: GlobalThemeId = .manga

    // ── 视觉 Token ──

    var colorPalette: GlobalColorPalette {
        GlobalColorPalette(
            background: MangaStyle.paper,
            surface: MangaStyle.surface,
            primary: MangaStyle.ink,
            secondary: MangaStyle.inkSub,
            accent: MangaStyle.accentPink,
            accentGradient: ThemeColorCustomization.accentGradientColors(
                for: .manga,
                fallback: [MangaStyle.accentPink, MangaStyle.labelYellow, MangaStyle.decoBlue, MangaStyle.mint],
                fallbackHexes: ["FF4F84", "FFE067"]
            ),
            separator: MangaStyle.separator,
            navBarTint: MangaStyle.ink,
            iconBackground: MangaStyle.strokeInk,
            iconForeground: MangaStyle.onStrokeInk,
            cardBackground: MangaStyle.bubbleWhite,
            floatingBarFill: MangaStyle.bubbleWhite.opacity(0.94),
            destructive: MangaStyle.red
        )
    }

    var typography: GlobalTypography {
        GlobalTypography(
            titleFont: { size in .system(size: size, weight: .heavy, design: .rounded) },
            bodyFont: { size in .system(size: size, weight: .bold, design: .rounded) },
            captionFont: { size in .system(size: size, weight: .black, design: .rounded) },
            monoFont: { size in .system(size: size, weight: .heavy, design: .monospaced) },
            fontDesign: .rounded,
            letterSpacing: 0
        )
    }

    var shapeLanguage: GlobalShapeLanguage {
        GlobalShapeLanguage(
            cardRadius: 16,
            buttonRadius: 11,
            sheetRadius: 22,
            shadowStyle: .hard,
            borderWidth: MangaStyle.strokeWidth
        )
    }

    var iconStyle: GlobalIconStyle {
        GlobalIconStyle(
            variant: .filled,
            weight: .bold,
            badgeRadius: 10
        )
    }

    var animationStyle: GlobalAnimationStyle {
        GlobalAnimationStyle(
            pageTransition: .scale(scale: 0.96).combined(with: .opacity),
            cardAppear: .spring(response: 0.48, dampingFraction: 0.76),
            buttonPress: .spring(response: 0.28, dampingFraction: 0.64),
            staggerDelay: 0.045
        )
    }

    // ── 布局工厂 ──

    func makeHomeView() -> AnyView {
        AnyView(MangaHomeView())
    }

    func makePodcastView() -> AnyView {
        AnyView(MangaPodcastView())
    }

    func makeSearchView() -> AnyView {
        AnyView(MangaSearchView())
    }

    func makeLibraryView() -> AnyView {
        AnyView(MangaLibraryView())
    }

    func makeProfileView() -> AnyView {
        AnyView(MangaProfileView())
    }

    func makeLocalHomeView() -> AnyView {
        AnyView(MangaLocalHomeView())
    }

    func makeLocalMusicView() -> AnyView {
        AnyView(MangaLocalMusicView())
    }

    func makeLocalLibraryView() -> AnyView {
        AnyView(MangaLocalLibraryView())
    }

    func makeLocalProfileView() -> AnyView {
        AnyView(MangaLocalProfileView())
    }
}
