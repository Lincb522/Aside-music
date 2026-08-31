import SwiftUI

/// MinimalWhite（极简白）主题的 `GlobalThemeProvider` 实现：
/// 提供配色/字体/形状/动画定义，并为各主页面返回 MinimalWhite 包装视图。
struct MinimalWhiteThemeProvider: GlobalThemeProvider {
    let id: GlobalThemeId = .minimalWhite

    var colorPalette: GlobalColorPalette {
        GlobalColorPalette(
            background: MinimalWhiteStyle.base,
            surface: MinimalWhiteStyle.surface,
            primary: MinimalWhiteStyle.ink,
            secondary: MinimalWhiteStyle.inkSoft,
            accent: MinimalWhiteStyle.accent,
            accentGradient: MinimalWhiteStyle.accentGradient,
            separator: MinimalWhiteStyle.separator,
            navBarTint: MinimalWhiteStyle.ink,
            iconBackground: MinimalWhiteStyle.controlGlassFill,
            iconForeground: MinimalWhiteStyle.ink,
            cardBackground: MinimalWhiteStyle.glassFill,
            floatingBarFill: MinimalWhiteStyle.glassStrongFill,
            destructive: MinimalWhiteStyle.destructive
        )
    }

    var typography: GlobalTypography {
        GlobalTypography(
            titleFont: { size in MinimalWhiteStyle.titleFont(size, weight: .bold) },
            bodyFont: { size in MinimalWhiteStyle.bodyFont(size, weight: .regular) },
            captionFont: { size in MinimalWhiteStyle.labelFont(size, weight: .medium) },
            monoFont: { size in .system(size: size, weight: .medium, design: .monospaced) },
            fontDesign: .default,
            letterSpacing: 0
        )
    }

    var shapeLanguage: GlobalShapeLanguage {
        GlobalShapeLanguage(
            cardRadius: MinimalWhiteStyle.cardRadius,
            buttonRadius: MinimalWhiteStyle.compactRadius,
            sheetRadius: 22,
            shadowStyle: .soft,
            borderWidth: MinimalWhiteStyle.strokeWidth
        )
    }

    var iconStyle: GlobalIconStyle {
        GlobalIconStyle(
            variant: .outlined,
            weight: .regular,
            badgeRadius: 12
        )
    }

    var animationStyle: GlobalAnimationStyle {
        GlobalAnimationStyle(
            pageTransition: .opacity,
            cardAppear: .easeOut(duration: 0.18),
            buttonPress: .spring(response: 0.18, dampingFraction: 0.86),
            staggerDelay: 0.014
        )
    }

    var suggestedPlayerTheme: PlayerTheme? { .minimalWhite }

    func makeHomeView() -> AnyView {
        AnyView(MinimalWhiteHomeView())
    }

    func makePodcastView() -> AnyView {
        AnyView(MinimalWhitePodcastView())
    }

    func makeSearchView() -> AnyView {
        AnyView(MinimalWhiteSearchView())
    }

    func makeLibraryView() -> AnyView {
        AnyView(MinimalWhiteLibraryView())
    }

    func makeProfileView() -> AnyView {
        AnyView(MinimalWhiteProfileView())
    }

    func makeLocalHomeView() -> AnyView {
        AnyView(MinimalWhiteLocalHomeView())
    }

    func makeLocalMusicView() -> AnyView {
        AnyView(MinimalWhiteLocalMusicView())
    }

    func makeLocalLibraryView() -> AnyView {
        AnyView(MinimalWhiteLocalLibraryView())
    }

    func makeLocalProfileView() -> AnyView {
        AnyView(MinimalWhiteLocalProfileView())
    }
}
