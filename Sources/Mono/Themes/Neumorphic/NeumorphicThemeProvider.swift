import SwiftUI

/// 新拟物主题 — 柔软实体感、凸起/凹陷层级、低对比触觉界面
struct NeumorphicThemeProvider: GlobalThemeProvider {
    let id: GlobalThemeId = .neumorphic

    var colorPalette: GlobalColorPalette {
        GlobalColorPalette(
            background: NeumorphicStyle.base,
            surface: NeumorphicStyle.surface,
            primary: NeumorphicStyle.ink,
            secondary: NeumorphicStyle.inkSoft,
            accent: NeumorphicStyle.accent,
            accentGradient: ThemeColorCustomization.accentGradientColors(
                for: .neumorphic,
                fallback: [NeumorphicStyle.accent, NeumorphicStyle.sage, NeumorphicStyle.warm],
                fallbackHexes: ["4F8E86", "7D9475"]
            ),
            separator: NeumorphicStyle.separator,
            navBarTint: NeumorphicStyle.ink,
            iconBackground: NeumorphicStyle.surfaceRaised,
            iconForeground: NeumorphicStyle.accent,
            cardBackground: NeumorphicStyle.surface,
            floatingBarFill: NeumorphicStyle.surface.opacity(0.94),
            destructive: NeumorphicStyle.red
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
            cardRadius: NeumorphicStyle.cardRadius,
            buttonRadius: NeumorphicStyle.buttonRadius,
            sheetRadius: 28,
            shadowStyle: .soft,
            borderWidth: 0.8
        )
    }

    var iconStyle: GlobalIconStyle {
        GlobalIconStyle(
            variant: .outlined,
            weight: .medium,
            badgeRadius: 14
        )
    }

    var animationStyle: GlobalAnimationStyle {
        GlobalAnimationStyle(
            pageTransition: .scale(scale: 0.985).combined(with: .opacity),
            cardAppear: .spring(response: 0.5, dampingFraction: 0.86),
            buttonPress: .spring(response: 0.28, dampingFraction: 0.72),
            staggerDelay: 0.055
        )
    }

    var suggestedPlayerTheme: PlayerTheme? {
        .classic
    }

    func makeHomeView() -> AnyView {
        AnyView(NeumorphicHomeView())
    }

    func makePodcastView() -> AnyView {
        AnyView(NeumorphicPodcastView())
    }

    func makeSearchView() -> AnyView {
        AnyView(NeumorphicSearchView())
    }

    func makeLibraryView() -> AnyView {
        AnyView(NeumorphicLibraryView())
    }

    func makeProfileView() -> AnyView {
        AnyView(NeumorphicProfileView())
    }

    func makeLocalHomeView() -> AnyView {
        AnyView(NeumorphicLocalHomeView())
    }

    func makeLocalMusicView() -> AnyView {
        AnyView(NeumorphicLocalMusicView())
    }

    func makeLocalLibraryView() -> AnyView {
        AnyView(NeumorphicLocalLibraryView())
    }

    func makeLocalProfileView() -> AnyView {
        AnyView(NeumorphicLocalProfileView())
    }
}
