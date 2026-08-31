import SwiftUI

struct ConsoleThemeProvider: GlobalThemeProvider {
    let id: GlobalThemeId = .signal

    var colorPalette: GlobalColorPalette {
        GlobalColorPalette(
            background: SignalStyle.base,
            surface: SignalStyle.surface,
            primary: SignalStyle.ink,
            secondary: SignalStyle.inkSoft,
            accent: SignalStyle.accent,
            accentGradient: [SignalStyle.accent, SignalStyle.accent],
            separator: SignalStyle.separator,
            navBarTint: SignalStyle.accent,
            iconBackground: SignalStyle.control,
            iconForeground: SignalStyle.ink,
            cardBackground: SignalStyle.surfaceRaised,
            floatingBarFill: SignalStyle.paper,
            destructive: SignalStyle.red
        )
    }

    var typography: GlobalTypography {
        GlobalTypography(
            titleFont: { SignalStyle.titleFont($0, weight: .semibold) },
            bodyFont: { SignalStyle.bodyFont($0) },
            captionFont: { SignalStyle.labelFont($0) },
            monoFont: { SignalStyle.monoFont($0) },
            fontDesign: .default,
            letterSpacing: 0
        )
    }

    var shapeLanguage: GlobalShapeLanguage {
        GlobalShapeLanguage(
            cardRadius: 16,
            buttonRadius: 12,
            sheetRadius: 24,
            shadowStyle: .soft,
            borderWidth: 0.7
        )
    }

    var iconStyle: GlobalIconStyle {
        GlobalIconStyle(variant: .outlined, weight: .medium, badgeRadius: 8)
    }

    var animationStyle: GlobalAnimationStyle {
        GlobalAnimationStyle(
            pageTransition: .opacity,
            cardAppear: .easeOut(duration: 0.28),
            buttonPress: .spring(response: 0.22, dampingFraction: 0.78),
            staggerDelay: 0.035
        )
    }

    var suggestedPlayerTheme: PlayerTheme? { .console }

    func makeHomeView() -> AnyView { AnyView(ConsoleThemeRoot { HomeView() }) }
    func makePodcastView() -> AnyView { AnyView(ConsoleThemeRoot { PodcastView() }) }
    func makeSearchView() -> AnyView { AnyView(ConsoleThemeRoot { SearchView() }) }
    func makeLibraryView() -> AnyView { AnyView(ConsoleThemeRoot { LibraryView() }) }
    func makeProfileView() -> AnyView { AnyView(ConsoleThemeRoot { ProfileView() }) }
    func makeLocalHomeView() -> AnyView { AnyView(ConsoleThemeRoot { LocalModeHomeView() }) }
    func makeLocalMusicView() -> AnyView { AnyView(ConsoleThemeRoot { LocalMusicView() }) }
    func makeLocalLibraryView() -> AnyView { AnyView(ConsoleThemeRoot { LocalLibraryView() }) }
    func makeLocalProfileView() -> AnyView { AnyView(ConsoleThemeRoot { LocalModeProfileView() }) }
}

private struct ConsoleThemeRoot<Content: View>: View {
    @ObservedObject private var settings = SettingsManager.shared
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        content()
            .tint(SignalStyle.accent)
            .preferredColorScheme(.dark)
            .themeRenderSceneLayer()
    }
}
