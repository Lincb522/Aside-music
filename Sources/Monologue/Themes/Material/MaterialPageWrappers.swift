import SwiftUI

private struct MaterialThemeRoot<Content: View>: View {
    let content: Content
    @ObservedObject private var settings = SettingsManager.shared

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        content
            .tint(MaterialStyle.primary)
            .themeRenderSceneLayer()
    }
}

struct MaterialPodcastView: View {
    var body: some View {
        MaterialThemeRoot {
            PodcastView()
        }
    }
}

struct MaterialSearchView: View {
    var body: some View {
        MaterialThemeRoot {
            SearchView()
        }
    }
}

struct MaterialLibraryView: View {
    var body: some View {
        MaterialThemeRoot {
            LibraryView()
        }
    }
}

struct MaterialProfileView: View {
    var body: some View {
        MaterialThemeRoot {
            ProfileView()
        }
    }
}

struct MaterialLocalHomeView: View {
    var body: some View {
        MaterialThemeRoot {
            LocalModeHomeView()
        }
    }
}

struct MaterialLocalMusicView: View {
    var body: some View {
        MaterialThemeRoot {
            LocalMusicView()
        }
    }
}

struct MaterialLocalLibraryView: View {
    var body: some View {
        MaterialThemeRoot {
            LocalLibraryView()
        }
    }
}

struct MaterialLocalProfileView: View {
    var body: some View {
        MaterialThemeRoot {
            LocalModeProfileView()
        }
    }
}
