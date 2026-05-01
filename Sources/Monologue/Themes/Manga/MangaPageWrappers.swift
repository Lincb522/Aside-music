import SwiftUI

// MARK: - Manga Theme Root Wrapper

private struct MangaThemeRoot<Content: View>: View {
    let content: Content
    @ObservedObject private var settings = SettingsManager.shared

    init(
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        content
            .tint(MangaStyle.accentPink)
            .themeRenderSceneLayer()
    }
}

// MARK: - Page Wrappers

struct MangaPodcastView: View {
    var body: some View {
        MangaThemeRoot {
            PodcastView()
        }
    }
}

struct MangaSearchView: View {
    var body: some View {
        MangaThemeRoot {
            SearchView()
        }
    }
}

struct MangaLibraryView: View {
    var body: some View {
        MangaThemeRoot {
            LibraryView()
        }
    }
}

struct MangaProfileView: View {
    var body: some View {
        MangaThemeRoot {
            ProfileView()
        }
    }
}

struct MangaLocalHomeView: View {
    var body: some View {
        MangaThemeRoot {
            LocalModeHomeView()
        }
    }
}

struct MangaLocalMusicView: View {
    var body: some View {
        MangaThemeRoot {
            LocalMusicView()
        }
    }
}

struct MangaLocalLibraryView: View {
    var body: some View {
        MangaThemeRoot {
            LocalLibraryView()
        }
    }
}

struct MangaLocalProfileView: View {
    var body: some View {
        MangaThemeRoot {
            LocalModeProfileView()
        }
    }
}
