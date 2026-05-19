import SwiftUI

private enum PureWhitePageIdentity {
    case home
    case podcast
    case search
    case library
    case profile
    case localHome
    case localMusic
    case localLibrary
    case localProfile

    var tag: String {
        switch self {
        case .home: return "HOME"
        case .podcast: return "POD"
        case .search: return "FIND"
        case .library: return "LIB"
        case .profile: return "ME"
        case .localHome: return "LOCAL"
        case .localMusic: return "MUSIC"
        case .localLibrary: return "FILES"
        case .localProfile: return "SET"
        }
    }

    var icon: MonologueIcon.IconType {
        switch self {
        case .home, .localHome: return .homeFilled
        case .podcast: return .podcastFilled
        case .search: return .magnifyingGlass
        case .library, .localLibrary: return .libraryFilled
        case .profile, .localProfile: return .profileFilled
        case .localMusic: return .musicNoteList
        }
    }

    var tint: Color {
        switch self {
        case .home, .localHome: return PureWhiteStyle.accent
        case .podcast: return PureWhiteStyle.paperBlue
        case .search: return PureWhiteStyle.accent.opacity(0.72)
        case .library, .localLibrary: return PureWhiteStyle.inkSoft.opacity(0.62)
        case .profile, .localProfile: return PureWhiteStyle.separator
        case .localMusic: return PureWhiteStyle.accent.opacity(0.82)
        }
    }
}

private struct PureWhiteThemeRoot<Content: View>: View {
    let page: PureWhitePageIdentity
    let content: Content
    @ObservedObject private var settings = SettingsManager.shared

    init(page: PureWhitePageIdentity, @ViewBuilder content: () -> Content) {
        self.page = page
        self.content = content()
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            content
                .padding(.top, 4)
                .tint(PureWhiteStyle.accent)
                .themeRenderSceneLayer()

            PureWhitePageChrome(page: page)
        }
        .background(PureWhiteRootBackdrop())
    }
}

private struct PureWhitePageChrome: View {
    let page: PureWhitePageIdentity

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PureWhitePageRail(page: page)
                    .padding(.top, max(76, proxy.safeAreaInsets.top + 54))
                    .padding(.leading, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                PureWhitePageTag(page: page)
                    .padding(.top, max(18, proxy.safeAreaInsets.top + 12))
                    .padding(.trailing, DeviceLayout.isPad ? 28 : 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                PureWhitePageFooterMark(page: page)
                    .padding(.bottom, max(DeviceLayout.safeAreaBottom + 20, 24))
                    .padding(.leading, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct PureWhitePageRail: View {
    let page: PureWhitePageIdentity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Capsule(style: .continuous)
                .fill(page.tint.opacity(0.65))
                .frame(width: 18, height: 4)

            ForEach(0 ..< 6, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index.isMultiple(of: 2) ? PureWhiteStyle.separator.opacity(0.9) : page.tint.opacity(0.18))
                    .frame(width: index.isMultiple(of: 2) ? 20 : 12, height: 4)
            }
        }
    }
}

private struct PureWhitePageTag: View {
    let page: PureWhitePageIdentity

    var body: some View {
        HStack(spacing: 7) {
            MonologueIcon(icon: page.icon, size: 14, color: PureWhiteStyle.ink, lineWidth: 1.8)

            Text(page.tag)
                .font(PureWhiteStyle.labelFont(10, weight: .black))
                .foregroundStyle(PureWhiteStyle.ink)
                .tracking(1.0)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(PureWhiteStyle.surfaceRaised)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(PureWhiteStyle.separator, lineWidth: 1)
                )
                .overlay(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(page.tint)
                        .frame(width: 4, height: 14)
                        .padding(.leading, 7)
                }
        )
        .shadow(color: PureWhiteStyle.strokeInk.opacity(0.08), radius: 0, x: 0, y: 2)
    }
}

private struct PureWhitePageFooterMark: View {
    let page: PureWhitePageIdentity

    var body: some View {
        HStack(spacing: 8) {
            Capsule(style: .continuous)
                .fill(page.tint.opacity(0.72))
                .frame(width: 22, height: 3)
            MonologueIcon(icon: page.icon, size: 12, color: PureWhiteStyle.inkMuted, lineWidth: 1.6)
            Capsule(style: .continuous)
                .fill(PureWhiteStyle.separator)
                .frame(width: 26, height: 2)
        }
        .opacity(0.82)
    }
}

struct PureWhiteHomeView: View {
    var body: some View {
        PureWhiteThemeRoot(page: .home) {
            HomeView()
        }
    }
}

struct PureWhitePodcastView: View {
    var body: some View {
        PureWhiteThemeRoot(page: .podcast) {
            PodcastView()
        }
    }
}

struct PureWhiteSearchView: View {
    var body: some View {
        PureWhiteThemeRoot(page: .search) {
            SearchView()
        }
    }
}

struct PureWhiteLibraryView: View {
    var body: some View {
        PureWhiteThemeRoot(page: .library) {
            LibraryView()
        }
    }
}

struct PureWhiteProfileView: View {
    var body: some View {
        PureWhiteThemeRoot(page: .profile) {
            ProfileView()
        }
    }
}

struct PureWhiteLocalHomeView: View {
    var body: some View {
        PureWhiteThemeRoot(page: .localHome) {
            LocalModeHomeView()
        }
    }
}

struct PureWhiteLocalMusicView: View {
    var body: some View {
        PureWhiteThemeRoot(page: .localMusic) {
            LocalMusicView()
        }
    }
}

struct PureWhiteLocalLibraryView: View {
    var body: some View {
        PureWhiteThemeRoot(page: .localLibrary) {
            LocalLibraryView()
        }
    }
}

struct PureWhiteLocalProfileView: View {
    var body: some View {
        PureWhiteThemeRoot(page: .localProfile) {
            LocalModeProfileView()
        }
    }
}
