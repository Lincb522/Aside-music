import SwiftUI

/// 无印良品主题 — 极简暖色纸质感、大量留白、衬线字体
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
                fallback: [MujiStyle.clay, MujiStyle.straw, MujiStyle.tea],
                fallbackHexes: ["B56B4B", "D8B56D"]
            ),
            separator: MujiStyle.separator,
            navBarTint: MujiStyle.ink,
            iconBackground: MujiStyle.ink,
            iconForeground: MujiStyle.onTint,
            cardBackground: MujiStyle.surfaceRaised,
            floatingBarFill: MujiStyle.surface.opacity(0.94),
            destructive: MujiStyle.red
        )
    }

    var typography: GlobalTypography {
        GlobalTypography(
            titleFont: { size in .system(size: size, weight: .semibold, design: .serif) },
            bodyFont: { size in .system(size: size, weight: .regular, design: .serif) },
            captionFont: { size in .system(size: size, weight: .medium, design: .rounded) },
            monoFont: { size in .system(size: size, weight: .regular, design: .monospaced) },
            fontDesign: .serif,
            letterSpacing: 0.2
        )
    }

    var shapeLanguage: GlobalShapeLanguage {
        GlobalShapeLanguage(
            cardRadius: 12,
            buttonRadius: 8,
            sheetRadius: 20,
            shadowStyle: .soft,
            borderWidth: 0
        )
    }

    var iconStyle: GlobalIconStyle {
        GlobalIconStyle(
            variant: .outlined,
            weight: .light,
            badgeRadius: 6
        )
    }

    var animationStyle: GlobalAnimationStyle {
        GlobalAnimationStyle(
            pageTransition: .opacity,
            cardAppear: .easeInOut(duration: 0.5),
            buttonPress: .easeInOut(duration: 0.2),
            staggerDelay: 0.08
        )
    }

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
