import SwiftUI

private struct MinimalWhiteThemeRoot<Content: View>: View {
    let content: () -> Content
    @ObservedObject private var settings = SettingsManager.shared

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        content()
            .tint(MinimalWhiteStyle.accent)
            .themeRenderSceneLayer()
            .background(MinimalWhiteRootBackdrop())
    }
}

struct MinimalWhiteHomeView: View {
    var body: some View {
        MinimalWhiteThemeRoot {
            HomeView()
        }
    }
}

struct MinimalWhitePodcastView: View {
    var body: some View {
        MinimalWhiteThemeRoot {
            PodcastView()
        }
    }
}

struct MinimalWhiteSearchView: View {
    var body: some View {
        MinimalWhiteThemeRoot {
            SearchView()
        }
    }
}

struct MinimalWhiteLibraryView: View {
    var body: some View {
        MinimalWhiteThemeRoot {
            LibraryView()
        }
    }
}

struct MinimalWhiteProfileView: View {
    var body: some View {
        MinimalWhiteThemeRoot {
            ProfileView()
        }
    }
}

struct MinimalWhiteLocalHomeView: View {
    var body: some View {
        MinimalWhiteThemeRoot {
            LocalModeHomeView()
        }
    }
}

struct MinimalWhiteLocalMusicView: View {
    var body: some View {
        MinimalWhiteThemeRoot {
            LocalMusicView()
        }
    }
}

struct MinimalWhiteLocalLibraryView: View {
    var body: some View {
        MinimalWhiteThemeRoot {
            LocalLibraryView()
        }
    }
}

struct MinimalWhiteLocalProfileView: View {
    var body: some View {
        MinimalWhiteThemeRoot {
            LocalModeProfileView()
        }
    }
}
