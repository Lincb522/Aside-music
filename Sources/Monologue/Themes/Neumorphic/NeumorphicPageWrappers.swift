import SwiftUI

private struct NeumorphicThemeRoot<Content: View>: View {
    let content: Content
    @ObservedObject private var settings = SettingsManager.shared

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        content
            .tint(NeumorphicStyle.accent)
            .themeRenderSceneLayer()
    }
}

struct NeumorphicPodcastView: View {
    var body: some View {
        NeumorphicThemeRoot {
            PodcastView()
        }
    }
}

struct NeumorphicSearchView: View {
    var body: some View {
        NeumorphicThemeRoot {
            SearchView()
        }
    }
}

struct NeumorphicLibraryView: View {
    var body: some View {
        NeumorphicThemeRoot {
            LibraryView()
        }
    }
}

struct NeumorphicProfileView: View {
    var body: some View {
        NeumorphicThemeRoot {
            ProfileView()
        }
    }
}

struct NeumorphicLocalHomeView: View {
    var body: some View {
        NeumorphicThemeRoot {
            LocalModeHomeView()
        }
    }
}

struct NeumorphicLocalMusicView: View {
    var body: some View {
        NeumorphicThemeRoot {
            LocalMusicView()
        }
    }
}

struct NeumorphicLocalLibraryView: View {
    var body: some View {
        NeumorphicThemeRoot {
            LocalLibraryView()
        }
    }
}

struct NeumorphicLocalProfileView: View {
    var body: some View {
        NeumorphicThemeRoot {
            LocalModeProfileView()
        }
    }
}
