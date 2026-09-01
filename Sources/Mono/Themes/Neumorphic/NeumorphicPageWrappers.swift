import SwiftUI

// Neumorphic 主题的页面包装层：统一套上主题 tint 与渲染场景层后复用通用页面。

private struct NeumorphicThemeRoot<Content: View>: View {
    let content: () -> Content
    @Environment(\.themeCustomizationRevision) private var themeRevision

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        let _ = themeRevision

        content()
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
