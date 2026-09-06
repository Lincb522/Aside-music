import SwiftUI

/// 默认主题 — 直接复用现有所有视图，零改动向后兼容
struct DefaultThemeProvider: GlobalThemeProvider {
    let id: GlobalThemeId = .default

    var colorPalette: GlobalColorPalette { .default }
    var typography: GlobalTypography { .default }
    var shapeLanguage: GlobalShapeLanguage { .default }
    var iconStyle: GlobalIconStyle { .default }
    var animationStyle: GlobalAnimationStyle { .default }
    var suggestedPlayerTheme: PlayerTheme? { .classic }

    // ── 布局：直接返回现有视图 ──

    func makeHomeView() -> AnyView {
        AnyView(HomeView())
    }

    func makePodcastView() -> AnyView {
        AnyView(PodcastView())
    }

    func makeSearchView() -> AnyView {
        AnyView(SearchView())
    }

    func makeLibraryView() -> AnyView {
        AnyView(LibraryView())
    }

    func makeProfileView() -> AnyView {
        AnyView(ProfileView())
    }

    func makeLocalHomeView() -> AnyView {
        AnyView(LocalModeHomeView())
    }

    func makeLocalMusicView() -> AnyView {
        AnyView(LocalMusicView(isRoot: true))
    }

    func makeLocalLibraryView() -> AnyView {
        AnyView(LocalLibraryView(isRoot: true))
    }

    func makeLocalProfileView() -> AnyView {
        AnyView(LocalModeProfileView())
    }
}
