import SwiftUI

private struct MujiThemeRoot<Content: View>: View {
    let content: () -> Content
    @ObservedObject private var settings = SettingsManager.shared

    init(
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        content()
            .tint(MujiStyle.clay)
            .themeRenderSceneLayer()
    }
}

struct MujiPodcastView: View {
    var body: some View {
        MujiThemeRoot {
            PodcastView()
        }
    }
}

struct MujiSearchView: View {
    var body: some View {
        MujiThemeRoot {
            SearchView()
        }
    }
}

struct MujiLibraryView: View {
    var body: some View {
        MujiThemeRoot {
            LibraryView()
        }
    }
}

struct MujiProfileView: View {
    var body: some View {
        MujiThemeRoot {
            ProfileView()
        }
    }
}

struct MujiLocalHomeView: View {
    var body: some View {
        MujiThemeRoot {
            LocalModeHomeView()
        }
    }
}

struct MujiLocalMusicView: View {
    var body: some View {
        MujiThemeRoot {
            LocalMusicView()
        }
    }
}

struct MujiLocalLibraryView: View {
    var body: some View {
        MujiThemeRoot {
            LocalLibraryView()
        }
    }
}

struct MujiLocalProfileView: View {
    var body: some View {
        MujiThemeRoot {
            LocalModeProfileView()
        }
    }
}
