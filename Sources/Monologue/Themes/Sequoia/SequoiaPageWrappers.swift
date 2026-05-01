import SwiftUI

private struct SequoiaThemeRoot<Content: View>: View {
    let content: Content
    @ObservedObject private var settings = SettingsManager.shared

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        content
            .tint(SequoiaStyle.accent)
            .themeRenderSceneLayer()
    }
}

struct SequoiaPodcastView: View {
    var body: some View {
        SequoiaThemeRoot {
            PodcastView()
        }
    }
}

struct SequoiaSearchView: View {
    var body: some View {
        SequoiaThemeRoot {
            SearchView()
        }
    }
}

struct SequoiaLibraryView: View {
    var body: some View {
        SequoiaThemeRoot {
            LibraryView()
        }
    }
}

struct SequoiaProfileView: View {
    var body: some View {
        SequoiaThemeRoot {
            ProfileView()
        }
    }
}

struct SequoiaLocalHomeView: View {
    var body: some View {
        SequoiaThemeRoot {
            LocalModeHomeView()
        }
    }
}

struct SequoiaLocalMusicView: View {
    var body: some View {
        SequoiaThemeRoot {
            LocalMusicView()
        }
    }
}

struct SequoiaLocalLibraryView: View {
    var body: some View {
        SequoiaThemeRoot {
            LocalLibraryView()
        }
    }
}

struct SequoiaLocalProfileView: View {
    var body: some View {
        SequoiaThemeRoot {
            LocalModeProfileView()
        }
    }
}
