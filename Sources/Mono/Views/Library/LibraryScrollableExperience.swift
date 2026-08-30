import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shared Scrollable Library

struct ScrollableLibraryExperience: View {
    enum MyLibraryColumn: CaseIterable, Hashable {
        case localPlaylists, ncmPlaylists, qcmPlaylists, kcmPlaylists, appleMusic, localPodcasts, ncmPodcasts

        var title: String {
            switch self {
            case .localPlaylists: return String(localized: "lib_local_playlists")
            case .ncmPlaylists: return String(localized: "lib_netease_playlists")
            case .qcmPlaylists: return String(localized: "QCM歌单")
            case .kcmPlaylists: return "KCM 歌单"
            case .appleMusic: return String(localized: "apple_music_library")
            case .localPodcasts: return String(localized: "本地播客")
            case .ncmPodcasts: return String(localized: "NCM 播客")
            }
        }

        var icon: MonoIcon.IconType {
            switch self {
            case .localPlaylists: return .musicNoteList
            case .ncmPlaylists, .qcmPlaylists, .kcmPlaylists: return .list
            case .appleMusic: return .musicNote
            case .localPodcasts, .ncmPodcasts: return .radio
            }
        }
    }

    @ObservedObject var viewModel: LibraryViewModel
    @Binding var tabIndex: Int
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var loginIdentity = LoginIdentityManager.shared
    @ObservedObject var localManager = LocalPlaylistManager.shared
    @ObservedObject var subManager = SubscriptionManager.shared
    @ObservedObject var qqSession = QQUserSession.shared
    @State var selectedMyLibraryColumn: MyLibraryColumn = .localPlaylists
    @State var isLibraryActionsExpanded = false
    @State var isArtistFiltersExpanded = false
    @State var showFileImporter = false
    @State var showQQImport = false
    @State var isImporting = false
    @State var qqUserPlaylists: [Playlist] = []
    @State var isLoadingQQUserPlaylists = false
    @State var hasLoadedQQUserPlaylists = false
    @Namespace var sequoiaLibraryNamespace

    let tabs = LibraryViewModel.LibraryTab.allCases
    let twoColumns = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]
    let actionColumns = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]
    let artistColumns = Array(repeating: GridItem(.flexible(), spacing: 14), count: DeviceLayout.artistGridColumns)

    var selectedTab: LibraryViewModel.LibraryTab {
        tabs[min(max(tabIndex, 0), tabs.count - 1)]
    }

    var activeTabTint: Color {
        tint(for: selectedTab)
    }

    var activeTabEyebrow: String {
        switch selectedTab {
        case .my: return "COLLECTION"
        case .square: return "DISCOVER"
        case .artists: return "ARTISTS"
        case .charts: return "CHARTS"
        }
    }

    var activeTabShortLabel: String {
        switch selectedTab {
        case .my: return String(localized: "tab_profile")
        case .square: return String(localized: "广场")
        case .artists: return String(localized: "lib_tab_artists")
        case .charts: return String(localized: "榜单")
        }
    }

    var contentHorizontalPadding: CGFloat {
        if MinimalWhiteStyle.isActive { return DeviceLayout.libraryHorizontalPadding }
        return PetWhiteStyle.isActive ? (DeviceLayout.isPad ? 16 : 10) : DeviceLayout.libraryHorizontalPadding
    }

    var body: some View {
        let _ = settings.globalThemeRevision
        ZStack {
            ThemedPageBackground(useRenderLayer: true)
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header
                        .monoPageHeaderCollapse()
                    tabContent
                }
                .padding(.bottom, 128)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .task {
            guard await MainTabActivationGate.waitUntilSettled(.library) else { return }
            selectActiveIdentityLibrary()
            syncTabFromViewModel()
            loadCurrentTab()
            if subManager.subscribedRadios.isEmpty {
                subManager.fetchSubscribedRadios()
            }
        }
        .onChange(of: viewModel.currentTab) { _, _ in
            guard MainTabActivationGate.isSettled(.library) else { return }
            syncTabFromViewModel()
            loadCurrentTab()
        }
        .onChange(of: tabIndex) { _, _ in
            guard MainTabActivationGate.isSettled(.library) else { return }
            loadCurrentTab()
        }
        .onChange(of: qqSession.sessionRevision) { _, _ in
            qqUserPlaylists = []
            hasLoadedQQUserPlaylists = false
            isLoadingQQUserPlaylists = false
            guard MainTabActivationGate.isSettled(.library) else { return }
            if qqSession.isLoggedIn {
                loadQQUserPlaylistsIfNeeded(force: true)
            }
        }
        .onChange(of: loginIdentity.activeSource) { _, _ in
            guard MainTabActivationGate.isSettled(.library) else { return }
            selectActiveIdentityLibrary()
            if selectedTab == .my {
                loadCurrentTab()
            }
        }
        .monoSheet(isPresented: $showQQImport, preset: .large) {
            QQPlaylistImportView()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                importPlaylistFromFile(url: url)
            case let .failure(error):
                AlertManager.shared.show(
                    title: String(localized: "lib_import_failed"),
                    message: error.localizedDescription,
                    primaryButtonTitle: String(localized: "lib_confirm"),
                    primaryAction: {}
                )
            }
        }
    }

    private func selectActiveIdentityLibrary() {
        switch loginIdentity.activeSource {
        case .netease: selectedMyLibraryColumn = .ncmPlaylists
        case .qqmusic: selectedMyLibraryColumn = .qcmPlaylists
        case .kugou: selectedMyLibraryColumn = .kcmPlaylists
        case .qishui, .appleMusic, .local, nil: selectedMyLibraryColumn = .localPlaylists
        }
    }

}
