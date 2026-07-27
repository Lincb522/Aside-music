import SwiftUI

/// 漫画风主题 — 独立的印刷漫画封面系统。
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
            accentGradient: [MangaComicPalette.ink, MangaComicPalette.inkSoft, MangaComicPalette.toneMid],
            separator: MangaStyle.separator,
            navBarTint: MangaStyle.ink,
            iconBackground: MangaStyle.strokeInk,
            iconForeground: MangaStyle.onStrokeInk,
            cardBackground: MangaStyle.bubbleWhite,
            floatingBarFill: MangaComicPalette.paper,
            destructive: MangaComicPalette.toneDeep
        )
    }

    var typography: GlobalTypography {
        GlobalTypography(
            titleFont: { size in MangaComicPalette.displayFont(size) },
            bodyFont: { size in .system(size: size, weight: .bold, design: .rounded) },
            captionFont: { size in .system(size: size, weight: .heavy, design: .default) },
            monoFont: { size in .system(size: size, weight: .heavy, design: .monospaced) },
            fontDesign: .default,
            letterSpacing: 0
        )
    }

    var shapeLanguage: GlobalShapeLanguage {
        GlobalShapeLanguage(
            cardRadius: 8,
            buttonRadius: 7,
            sheetRadius: 12,
            shadowStyle: .hard,
            borderWidth: MangaStyle.strokeWidth
        )
    }

    var iconStyle: GlobalIconStyle {
        GlobalIconStyle(
            variant: .filled,
            weight: .bold,
            badgeRadius: 7
        )
    }

    var animationStyle: GlobalAnimationStyle {
        GlobalAnimationStyle(
            pageTransition: .scale(scale: 0.97).combined(with: .opacity),
            cardAppear: .spring(response: 0.42, dampingFraction: 0.74),
            buttonPress: .spring(response: 0.24, dampingFraction: 0.6),
            staggerDelay: 0.04
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
