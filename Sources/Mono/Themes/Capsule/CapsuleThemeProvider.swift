import SwiftUI

/// Capsule（胶囊）主题的 `GlobalThemeProvider` 实现：
/// 提供配色/字体/形状/动画定义，并为各主页面返回 Capsule 包装视图。
struct CapsuleThemeProvider: GlobalThemeProvider {
    let id: GlobalThemeId = .capsule

    var colorPalette: GlobalColorPalette {
        GlobalColorPalette(
            background: CapsuleStyle.base,
            surface: CapsuleStyle.surface,
            primary: CapsuleStyle.ink,
            secondary: CapsuleStyle.inkSoft,
            accent: CapsuleStyle.accent,
            accentGradient: CapsuleStyle.accentGradient,
            separator: CapsuleStyle.separator,
            navBarTint: CapsuleStyle.ink,
            iconBackground: CapsuleStyle.surfaceTint,
            iconForeground: CapsuleStyle.accent,
            cardBackground: CapsuleStyle.surfaceRaised,
            floatingBarFill: CapsuleStyle.surface.opacity(0.94),
            destructive: CapsuleStyle.coral
        )
    }

    var typography: GlobalTypography {
        GlobalTypography(
            titleFont: { size in CapsuleStyle.titleFont(size, weight: .bold) },
            bodyFont: { size in CapsuleStyle.bodyFont(size) },
            captionFont: { size in CapsuleStyle.labelFont(size) },
            monoFont: { size in .system(size: size, weight: .semibold, design: .monospaced) },
            fontDesign: .rounded,
            letterSpacing: 0
        )
    }

    var shapeLanguage: GlobalShapeLanguage {
        GlobalShapeLanguage(
            cardRadius: CapsuleStyle.cardRadius,
            buttonRadius: 999,
            sheetRadius: 30,
            shadowStyle: .soft,
            borderWidth: 1
        )
    }

    var iconStyle: GlobalIconStyle {
        GlobalIconStyle(
            variant: .outlined,
            weight: .semibold,
            badgeRadius: 18
        )
    }

    var animationStyle: GlobalAnimationStyle {
        GlobalAnimationStyle(
            pageTransition: .opacity.combined(with: .scale(scale: 0.985, anchor: .bottom)),
            cardAppear: .spring(response: 0.42, dampingFraction: 0.86),
            buttonPress: .spring(response: 0.22, dampingFraction: 0.78),
            staggerDelay: 0.045
        )
    }

    var suggestedPlayerTheme: PlayerTheme? {
        .capsule
    }

    func makeHomeView() -> AnyView {
        AnyView(CapsuleHomeView())
    }

    func makePodcastView() -> AnyView {
        AnyView(CapsulePodcastView())
    }

    func makeSearchView() -> AnyView {
        AnyView(CapsuleSearchView())
    }

    func makeLibraryView() -> AnyView {
        AnyView(CapsuleLibraryView())
    }

    func makeProfileView() -> AnyView {
        AnyView(CapsuleProfileView())
    }

    func makeLocalHomeView() -> AnyView {
        AnyView(CapsuleLocalHomeView())
    }

    func makeLocalMusicView() -> AnyView {
        AnyView(CapsuleLocalMusicView())
    }

    func makeLocalLibraryView() -> AnyView {
        AnyView(CapsuleLocalLibraryView())
    }

    func makeLocalProfileView() -> AnyView {
        AnyView(CapsuleLocalProfileView())
    }
}
