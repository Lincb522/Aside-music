import SwiftUI

// Capsule 主题的页面包装层：统一套上主题 tint 与渲染场景层后复用通用页面。

private struct CapsuleThemeRoot<Content: View>: View {
    let content: () -> Content
    @ObservedObject private var settings = SettingsManager.shared

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        content()
            .tint(CapsuleStyle.accent)
            .themeRenderSceneLayer()
    }
}

struct CapsulePodcastView: View {
    var body: some View {
        CapsuleThemeRoot {
            CapsulePodcastExperience()
        }
    }
}

struct CapsuleSearchView: View {
    var body: some View {
        CapsuleThemeRoot {
            SearchView()
        }
    }
}

struct CapsuleLibraryView: View {
    var body: some View {
        CapsuleThemeRoot {
            LibraryView()
        }
    }
}

struct CapsuleProfileView: View {
    var body: some View {
        CapsuleThemeRoot {
            ProfileView()
        }
    }
}

struct CapsuleLocalHomeView: View {
    var body: some View {
        CapsuleThemeRoot {
            LocalModeHomeView()
        }
    }
}

struct CapsuleLocalMusicView: View {
    var body: some View {
        CapsuleThemeRoot {
            LocalMusicView(isRoot: true)
        }
    }
}

struct CapsuleLocalLibraryView: View {
    var body: some View {
        CapsuleThemeRoot {
            LocalLibraryView(isRoot: true)
        }
    }
}

struct CapsuleLocalProfileView: View {
    var body: some View {
        CapsuleThemeRoot {
            LocalModeProfileView()
        }
    }
}
