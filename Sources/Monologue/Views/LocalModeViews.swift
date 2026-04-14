import SwiftUI
import UniformTypeIdentifiers

private func localModeText(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func localModeFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: localModeText(key), locale: Locale.current, arguments: arguments)
}

private struct LocalSystemPlaylistDestinationView: View {
    let playlistId: String?
    let fallbackFilter: LocalMusicFilter

    var body: some View {
        if let playlistId {
            LocalPlaylistDetailView(playlistId: playlistId)
        } else {
            LocalMusicView(initialFilter: fallbackFilter)
        }
    }
}

enum LocalMusicFilter: CaseIterable, Identifiable {
    case all
    case favorites
    case downloads
    case recent

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .all: return "local_filter_all"
        case .favorites: return "local_filter_favorites"
        case .downloads: return "local_filter_downloads"
        case .recent: return "local_filter_recent"
        }
    }

    var icon: MonologueIcon.IconType {
        switch self {
        case .all: return .musicNoteList
        case .favorites: return .liked
        case .downloads: return .download
        case .recent: return .history
        }
    }
}

enum LocalMusicSort: CaseIterable, Identifiable {
    case newest
    case title
    case artist

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .newest: return "local_sort_newest"
        case .title: return "local_sort_title"
        case .artist: return "local_sort_artist"
        }
    }
}

@MainActor
private func offlinePlayableSongs(from songs: [Song], using downloadManager: DownloadManager) -> [Song] {
    var seen = Set<Int>()

    return songs.filter { song in
        let isPlayable = song.isLocal || downloadManager.isDownloaded(songId: song.id, isQQ: song.isQQMusic)
        guard isPlayable, !seen.contains(song.id) else { return false }
        seen.insert(song.id)
        return true
    }
}

@MainActor
private func recentOfflineSongs(limit: Int, using downloadManager: DownloadManager) -> [Song] {
    let history = HistoryRepository().getPlayHistory(limit: max(limit * 3, 30))
    var seen = Set<Int>()
    var songs: [Song] = []

    for item in history {
        let song = item.toSong()
        let isPlayable = song.isLocal || downloadManager.isDownloaded(songId: song.id, isQQ: song.isQQMusic)
        guard isPlayable, !seen.contains(song.id) else { continue }
        seen.insert(song.id)
        songs.append(song)
        if songs.count >= limit {
            break
        }
    }

    return songs
}

struct LocalModeHomeView: View {
    @ObservedObject private var localLibrary = LocalMusicLibraryManager.shared
    @ObservedObject private var localPlaylists = LocalPlaylistManager.shared
    @ObservedObject private var downloadManager = DownloadManager.shared
    @ObservedObject private var playerManager = PlayerManager.shared

    @State private var showImporter = false
    @State private var recentSongs: [Song] = []

    private var customPlaylists: [LocalPlaylist] {
        localPlaylists.playlists.filter { !$0.isSystem }
    }

    private var favoriteSongs: [Song] {
        offlinePlayableSongs(from: localPlaylists.favoritePlaylist?.songs ?? [], using: downloadManager)
    }

    private var downloadedSongs: [Song] {
        offlinePlayableSongs(from: localPlaylists.downloadPlaylist?.songs ?? [], using: downloadManager)
    }

    private var recentlyAddedSongs: [Song] {
        Array(localLibrary.songs.prefix(10))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MonologueBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        homeHeroCard

                        actionCards

                        quickAccessSection

                        if !recentSongs.isEmpty {
                            localSongSection(
                                title: localModeText("local_home_continue_title"),
                                songs: recentSongs,
                                destination: LocalMusicView(initialFilter: .recent)
                            )
                        }

                        if !recentlyAddedSongs.isEmpty {
                            localSongSection(
                                title: localModeText("local_home_recent_added_title"),
                                songs: recentlyAddedSongs,
                                destination: LocalMusicView(initialFilter: .all)
                            )
                        }

                        playlistsPreviewSection

                        if localLibrary.songs.isEmpty {
                            LocalEmptyStateView(
                                title: localModeText("local_empty_music_title"),
                                subtitle: localModeText("local_home_empty_hint"),
                                buttonTitle: localModeText("local_action_import_title"),
                                buttonAction: { showImporter = true }
                            )
                        }

                        Color.clear.frame(height: 110)
                    }
                    .padding(.top, DeviceLayout.headerTopPadding + 12)
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .iPadContentWidth(700)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(localModeText("tabbar_home"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task {
                            let result = await localLibrary.scanLibrary()
                            showLibraryResult(title: localModeText("local_scan_complete_title"), result: result)
                            refreshRecentSongs()
                        }
                    } label: {
                        MonologueIcon(icon: .refresh, size: 16, color: .monologueTextPrimary)
                    }

                    Button {
                        showImporter = true
                    } label: {
                        MonologueIcon(icon: .download, size: 16, color: .monologueTextPrimary)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: LocalMusicLibraryManager.importableContentTypes,
            allowsMultipleSelection: true
        ) { result in
            handleMusicImport(result)
        }
        .onAppear {
            refreshRecentSongs()
            Task {
                await LocalPlaylistCloudSyncManager.shared.refreshFromCloudIfNeeded()
            }
        }
        .onReceive(playerManager.$currentSong.dropFirst()) { _ in
            refreshRecentSongs()
        }
    }

    private var homeHeroCard: some View {
        MonologueLiquidGlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localModeText("local_home_hero_title"))
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(.monologueTextPrimary)
                            .tracking(-0.5)
                    }

                    Spacer(minLength: 16)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.monologueAccent.opacity(0.85),
                                    Color.monologueAccent.opacity(0.35)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            MonologueIcon(icon: .musicNote, size: 24, color: .white)
                        )
                }

                HStack(spacing: 10) {
                    LocalMetricBadge(
                        title: localModeText("tabbar_local_music"),
                        value: "\(localLibrary.songCount)"
                    )
                    LocalMetricBadge(
                        title: localModeText("profile_local_playlists"),
                        value: "\(customPlaylists.count)"
                    )
                    LocalMetricBadge(
                        title: localModeText("local_downloads_title"),
                        value: "\(downloadManager.downloadedSongIds.count)"
                    )
                }

                HStack(spacing: 12) {
                    Button {
                        playAllLocalSongs()
                    } label: {
                        HStack(spacing: 8) {
                            MonologueIcon(icon: .play, size: 13, color: .monologueIconForeground)
                            Text(localModeText("local_home_play_all"))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.monologueIconForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.monologueIconBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                    .disabled(localLibrary.songs.isEmpty)

                    NavigationLink(destination: LocalLibraryView()) {
                        HStack(spacing: 8) {
                            MonologueIcon(icon: .library, size: 14, color: .monologueTextPrimary)
                            Text(localModeText("local_home_open_library"))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.monologueTextPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.monologueGlassTint.opacity(0.65))
                        .monologueGlass(cornerRadius: 16)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                }
            }
            .padding(22)
        }
    }

    private var actionCards: some View {
        HStack(spacing: 14) {
            LocalPrimaryActionCard(
                title: localModeText("local_action_scan_title"),
                systemImage: "arrow.trianglehead.2.clockwise",
                isLoading: localLibrary.isProcessing
            ) {
                Task {
                    let result = await localLibrary.scanLibrary()
                    showLibraryResult(title: localModeText("local_scan_complete_title"), result: result)
                    refreshRecentSongs()
                }
            }

            LocalPrimaryActionCard(
                title: localModeText("local_action_import_title"),
                systemImage: "square.and.arrow.down",
                isLoading: false
            ) {
                showImporter = true
            }
        }
    }

    private var quickAccessSection: some View {
        VStack(spacing: 14) {
            SectionHeader(
                title: localModeText("local_home_quick_access_title"),
                subtitle: nil
            )

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2),
                spacing: 14
            ) {
                NavigationLink(destination: LocalMusicView(initialFilter: .all)) {
                    LocalShortcutCard(
                        title: localModeText("local_filter_all"),
                        value: "\(localLibrary.songCount)",
                        icon: .musicNoteList,
                        accent: .blue
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                NavigationLink(
                    destination: LocalSystemPlaylistDestinationView(
                        playlistId: localPlaylists.favoritePlaylist?.id,
                        fallbackFilter: .favorites
                    )
                ) {
                    LocalShortcutCard(
                        title: localModeText("local_filter_favorites"),
                        value: "\(favoriteSongs.count)",
                        icon: .liked,
                        accent: .pink
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                NavigationLink(
                    destination: LocalSystemPlaylistDestinationView(
                        playlistId: localPlaylists.downloadPlaylist?.id,
                        fallbackFilter: .downloads
                    )
                ) {
                    LocalShortcutCard(
                        title: localModeText("local_filter_downloads"),
                        value: "\(downloadedSongs.count)",
                        icon: .download,
                        accent: .cyan
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                NavigationLink(destination: LocalMusicView(initialFilter: .recent)) {
                    LocalShortcutCard(
                        title: localModeText("local_filter_recent"),
                        value: "\(recentSongs.count)",
                        icon: .history,
                        accent: .orange
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        }
    }

    @ViewBuilder
    private func localSongSection<Destination: View>(
        title: String,
        songs: [Song],
        destination: Destination
    ) -> some View {
        VStack(spacing: 14) {
            NavigationLink(destination: destination) {
                SectionHeader(title: title, subtitle: nil)
            }
            .buttonStyle(.plain)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(songs.prefix(10)) { song in
                        SongCard(song: song) {
                            PlayerManager.shared.play(song: song, in: songs)
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var playlistsPreviewSection: some View {
        VStack(spacing: 14) {
            SectionHeader(
                title: localModeText("local_home_playlists_title"),
                subtitle: nil
            )

            if customPlaylists.isEmpty {
                LocalEmptyStateView(
                    title: localModeText("local_empty_playlist_title"),
                    subtitle: localModeText("local_home_playlist_empty_hint")
                )
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            } else {
                VStack(spacing: 12) {
                    ForEach(customPlaylists.prefix(3), id: \.id) { playlist in
                        NavigationLink(destination: LocalPlaylistDetailView(playlistId: playlist.id)) {
                            LocalPlaylistRow(playlist: playlist)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
                    }

                    NavigationLink(destination: LocalLibraryView()) {
                        LocalInlineActionCard(
                            title: localModeText("local_home_manage_playlists"),
                            icon: .library
                        )
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            }
        }
    }

    private func playAllLocalSongs() {
        guard let first = localLibrary.songs.first else { return }
        PlayerManager.shared.playReplacingContext(song: first, in: localLibrary.songs)
    }

    private func handleMusicImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            Task {
                let importResult = await localLibrary.importItems(from: urls)
                showLibraryResult(title: localModeText("local_import_complete_title"), result: importResult)
                refreshRecentSongs()
            }
        case .failure(let error):
            AlertManager.shared.show(
                title: localModeText("local_import_failed_title"),
                message: error.localizedDescription,
                primaryButtonTitle: localModeText("common_ok"),
                primaryAction: {}
            )
        }
    }

    private func showLibraryResult(title: String, result: LocalMusicLibraryManager.ImportResult) {
        let message = localModeFormat(
            "local_result_message",
            result.summaryText,
            localLibrary.songCount,
            localPlaylists.playlists.count
        )

        AlertManager.shared.show(
            title: title,
            message: message,
            primaryButtonTitle: localModeText("common_ok"),
            primaryAction: {}
        )
    }

    private func refreshRecentSongs() {
        recentSongs = recentOfflineSongs(limit: 10, using: downloadManager)
    }
}

struct LocalMusicView: View {
    @ObservedObject private var localLibrary = LocalMusicLibraryManager.shared
    @ObservedObject private var localPlaylists = LocalPlaylistManager.shared
    @ObservedObject private var downloadManager = DownloadManager.shared
    @ObservedObject private var playerManager = PlayerManager.shared

    @State private var searchText = ""
    @State private var showImporter = false
    @State private var selectedFilter: LocalMusicFilter
    @State private var sortMode: LocalMusicSort = .newest
    @State private var recentSongs: [Song] = []

    init(initialFilter: LocalMusicFilter = .all) {
        _selectedFilter = State(initialValue: initialFilter)
    }

    private var sourceSongs: [Song] {
        switch selectedFilter {
        case .all:
            return localLibrary.songs
        case .favorites:
            return offlinePlayableSongs(from: localPlaylists.favoritePlaylist?.songs ?? [], using: downloadManager)
        case .downloads:
            return offlinePlayableSongs(from: localPlaylists.downloadPlaylist?.songs ?? [], using: downloadManager)
        case .recent:
            return recentSongs
        }
    }

    private var sortedSongs: [Song] {
        switch sortMode {
        case .newest:
            if selectedFilter == .recent {
                return sourceSongs
            }
            return sourceSongs.sorted { lhs, rhs in
                let lhsDate = lhs.localImportedAt ?? .distantPast
                let rhsDate = rhs.localImportedAt ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .title:
            return sourceSongs.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .artist:
            return sourceSongs.sorted {
                if $0.artistName != $1.artistName {
                    return $0.artistName.localizedCaseInsensitiveCompare($1.artistName) == .orderedAscending
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    private var filteredSongs: [Song] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return sortedSongs }

        return sortedSongs.filter { song in
            song.name.localizedCaseInsensitiveContains(keyword)
                || song.artistName.localizedCaseInsensitiveContains(keyword)
                || (song.album?.name.localizedCaseInsensitiveContains(keyword) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MonologueBackground()
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    overviewCard
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                        .padding(.top, DeviceLayout.headerTopPadding + 10)

                    filterBar

                    if filteredSongs.isEmpty {
                        Spacer()
                        LocalEmptyStateView(
                            title: emptyTitle,
                            subtitle: emptySubtitle,
                            buttonTitle: localLibrary.songs.isEmpty && selectedFilter == .all ? localModeText("local_action_import_title") : nil,
                            buttonAction: localLibrary.songs.isEmpty && selectedFilter == .all ? { showImporter = true } : nil
                        )
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                        Spacer()
                    } else {
                        List {
                            ForEach(Array(filteredSongs.enumerated()), id: \.element.id) { index, song in
                                SongListRow(
                                    song: song,
                                    index: index,
                                    onTap: {
                                        playerManager.play(song: song, in: filteredSongs)
                                    }
                                )
                                .if(song.isLocal) { row in
                                    row.swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            localLibrary.deleteSong(song)
                                        } label: {
                                            Label(localModeText("local_action_remove"), systemImage: "trash")
                                        }
                                    }
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            }

                            Color.clear
                                .frame(height: 110)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(localModeText("tabbar_local_music"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .searchable(text: $searchText, prompt: localModeText("local_music_search_prompt"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(LocalMusicSort.allCases) { mode in
                            Button {
                                sortMode = mode
                            } label: {
                                if sortMode == mode {
                                    Label(localModeText(mode.titleKey), systemImage: "checkmark")
                                } else {
                                    Text(localModeText(mode.titleKey))
                                }
                            }
                        }
                    } label: {
                        MonologueIcon(icon: .filter, size: 16, color: .monologueTextPrimary)
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task {
                            let result = await localLibrary.scanLibrary()
                            showScanOrImportResult(title: localModeText("local_scan_complete_title"), result: result)
                            refreshRecentSongs()
                        }
                    } label: {
                        MonologueIcon(icon: .refresh, size: 16, color: .monologueTextPrimary)
                    }

                    Button {
                        showImporter = true
                    } label: {
                        MonologueIcon(icon: .download, size: 16, color: .monologueTextPrimary)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: LocalMusicLibraryManager.importableContentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                guard !urls.isEmpty else { return }
                Task {
                    let importResult = await localLibrary.importItems(from: urls)
                    showScanOrImportResult(title: localModeText("local_import_complete_title"), result: importResult)
                    refreshRecentSongs()
                }
            case .failure(let error):
                AlertManager.shared.show(
                    title: localModeText("local_import_failed_title"),
                    message: error.localizedDescription,
                    primaryButtonTitle: localModeText("common_ok"),
                    primaryAction: {}
                )
            }
        }
        .onAppear(perform: refreshRecentSongs)
        .onReceive(playerManager.$currentSong.dropFirst()) { _ in
            refreshRecentSongs()
        }
    }

    private var overviewCard: some View {
        MonologueLiquidGlassCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Text(localModeText(selectedFilter.titleKey))
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)

                    Spacer(minLength: 16)

                    Text("\(filteredSongs.count)")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.monologueAccent)
                }

                HStack(spacing: 12) {
                    LocalInlinePill(
                        title: localModeText("local_toolbar_scan"),
                        icon: .refresh
                    ) {
                        Task {
                            let result = await localLibrary.scanLibrary()
                            showScanOrImportResult(title: localModeText("local_scan_complete_title"), result: result)
                            refreshRecentSongs()
                        }
                    }

                    LocalInlinePill(
                        title: localModeText("local_toolbar_import"),
                        icon: .download
                    ) {
                        showImporter = true
                    }
                }
            }
            .padding(20)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(LocalMusicFilter.allCases) { filter in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 8) {
                            MonologueIcon(
                                icon: filter.icon,
                                size: 13,
                                color: selectedFilter == filter ? .monologueIconForeground : .monologueTextPrimary
                            )
                            Text(localModeText(filter.titleKey))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(selectedFilter == filter ? .monologueIconForeground : .monologueTextPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if selectedFilter == filter {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.monologueIconBackground)
                                } else {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.monologueGlassTint.opacity(0.65))
                                        .monologueGlass(cornerRadius: 16)
                                }
                            }
                        )
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                }
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyTitle: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localModeText("local_empty_search_title")
        }
        if selectedFilter == .all {
            return localModeText("local_empty_music_title")
        }
        return localModeText("local_empty_collection_title")
    }

    private var emptySubtitle: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localModeText("local_empty_search_subtitle")
        }
        if selectedFilter == .all {
            return localModeText("local_empty_music_subtitle")
        }
        return localModeText("local_empty_collection_subtitle")
    }

    private func showScanOrImportResult(title: String, result: LocalMusicLibraryManager.ImportResult) {
        AlertManager.shared.show(
            title: title,
            message: result.summaryText,
            primaryButtonTitle: localModeText("common_ok"),
            primaryAction: {}
        )
    }

    private func refreshRecentSongs() {
        recentSongs = recentOfflineSongs(limit: 40, using: downloadManager)
    }
}

struct LocalLibraryView: View {
    @ObservedObject private var localLibrary = LocalMusicLibraryManager.shared
    @ObservedObject private var localPlaylists = LocalPlaylistManager.shared
    @ObservedObject private var downloadManager = DownloadManager.shared

    @State private var showFileImporter = false
    @State private var recentSongs: [Song] = []

    private var customPlaylists: [LocalPlaylist] {
        localPlaylists.playlists.filter { !$0.isSystem }
    }

    private var favoriteSongs: [Song] {
        offlinePlayableSongs(from: localPlaylists.favoritePlaylist?.songs ?? [], using: downloadManager)
    }

    private var downloadedSongs: [Song] {
        offlinePlayableSongs(from: localPlaylists.downloadPlaylist?.songs ?? [], using: downloadManager)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MonologueBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        libraryOverviewCard

                        managementSection

                        systemCollectionsSection

                        customPlaylistsSection

                        Color.clear.frame(height: 110)
                    }
                    .padding(.top, DeviceLayout.headerTopPadding + 12)
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .iPadContentWidth(700)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    refreshRecentSongs()
                    _ = try? await LocalPlaylistCloudSyncManager.shared.refreshAndSync()
                }
            }
            .navigationTitle(localModeText("local_library_navigation_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handlePlaylistImport(result)
        }
        .onAppear {
            refreshRecentSongs()
            Task {
                await LocalPlaylistCloudSyncManager.shared.refreshFromCloudIfNeeded()
            }
        }
    }

    private var libraryOverviewCard: some View {
        MonologueLiquidGlassCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text(localModeText("local_library_overview_title"))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                HStack(spacing: 0) {
                    StatCell(value: "\(localLibrary.songCount)", label: localModeText("tabbar_local_music"))
                    Rectangle()
                        .fill(Color.monologueSeparator)
                        .frame(width: 0.5, height: 28)
                    StatCell(value: "\(favoriteSongs.count)", label: localModeText("local_filter_favorites"))
                    Rectangle()
                        .fill(Color.monologueSeparator)
                        .frame(width: 0.5, height: 28)
                    StatCell(value: "\(downloadedSongs.count)", label: localModeText("local_filter_downloads"))
                }
            }
            .padding(20)
        }
    }

    private var managementSection: some View {
        VStack(spacing: 14) {
            SectionHeader(
                title: localModeText("local_library_manage_title"),
                subtitle: nil
            )

            HStack(spacing: 14) {
                LocalManagementButton(
                    title: localModeText("lib_create_playlist"),
                    icon: .add
                ) {
                    createPlaylist()
                }

                LocalManagementButton(
                    title: localModeText("lib_import_playlist"),
                    icon: .arrowDownToLine
                ) {
                    showFileImporter = true
                }
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        }
    }

    private var systemCollectionsSection: some View {
        VStack(spacing: 14) {
            SectionHeader(
                title: localModeText("local_library_system_title"),
                subtitle: nil
            )

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2),
                spacing: 14
            ) {
                NavigationLink(destination: LocalMusicView(initialFilter: .all)) {
                    LocalShortcutCard(
                        title: localModeText("local_filter_all"),
                        value: "\(localLibrary.songCount)",
                        icon: .musicNoteList,
                        accent: .blue
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                NavigationLink(
                    destination: LocalSystemPlaylistDestinationView(
                        playlistId: localPlaylists.favoritePlaylist?.id,
                        fallbackFilter: .favorites
                    )
                ) {
                    LocalShortcutCard(
                        title: localModeText("local_filter_favorites"),
                        value: "\(favoriteSongs.count)",
                        icon: .liked,
                        accent: .pink
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                NavigationLink(
                    destination: LocalSystemPlaylistDestinationView(
                        playlistId: localPlaylists.downloadPlaylist?.id,
                        fallbackFilter: .downloads
                    )
                ) {
                    LocalShortcutCard(
                        title: localModeText("local_filter_downloads"),
                        value: "\(downloadedSongs.count)",
                        icon: .download,
                        accent: .cyan
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                NavigationLink(destination: LocalMusicView(initialFilter: .recent)) {
                    LocalShortcutCard(
                        title: localModeText("local_filter_recent"),
                        value: "\(recentSongs.count)",
                        icon: .history,
                        accent: .orange
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        }
    }

    private var customPlaylistsSection: some View {
        VStack(spacing: 14) {
            SectionHeader(
                title: localModeText("local_library_custom_title"),
                subtitle: nil
            )

            if customPlaylists.isEmpty {
                LocalEmptyStateView(
                    title: localModeText("local_empty_playlist_title"),
                    subtitle: localModeText("local_empty_playlist_subtitle"),
                    buttonTitle: localModeText("lib_create_playlist"),
                    buttonAction: createPlaylist
                )
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            } else {
                VStack(spacing: 12) {
                    ForEach(customPlaylists, id: \.id) { playlist in
                        NavigationLink(destination: LocalPlaylistDetailView(playlistId: playlist.id)) {
                            LocalPlaylistRow(playlist: playlist)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
                        .contextMenu {
                            Button {
                                renamePlaylist(playlist)
                            } label: {
                                Label(localModeText("local_playlist_rename"), systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                deletePlaylist(playlist)
                            } label: {
                                Label(localModeText("local_playlist_delete"), systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            }
        }
    }

    private func createPlaylist() {
        AlertManager.shared.showInput(
            title: localModeText("lib_create_playlist"),
            message: "",
            placeholder: localModeText("local_playlist_name"),
            primaryButtonTitle: localModeText("lib_confirm"),
            secondaryButtonTitle: localModeText("alert_cancel"),
            onConfirm: { name in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                localPlaylists.createPlaylist(name: trimmed)
            }
        )
    }

    private func renamePlaylist(_ playlist: LocalPlaylist) {
        AlertManager.shared.showInput(
            title: localModeText("local_playlist_rename"),
            message: "",
            placeholder: localModeText("local_playlist_name"),
            primaryButtonTitle: localModeText("lib_confirm"),
            secondaryButtonTitle: localModeText("alert_cancel"),
            onConfirm: { name in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                localPlaylists.renamePlaylist(playlist, name: trimmed)
            }
        )
        AlertManager.shared.inputText = playlist.name
    }

    private func deletePlaylist(_ playlist: LocalPlaylist) {
        AlertManager.shared.show(
            title: localModeText("local_playlist_delete"),
            message: localModeFormat("local_playlist_delete_confirm", playlist.name),
            primaryButtonTitle: localModeText("local_playlist_delete"),
            secondaryButtonTitle: localModeText("alert_cancel"),
            primaryAction: {
                localPlaylists.deletePlaylist(playlist)
            }
        )
    }

    private func handlePlaylistImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importPlaylistFromFile(url: url)
        case .failure(let error):
            AlertManager.shared.show(
                title: localModeText("lib_import_failed"),
                message: error.localizedDescription,
                primaryButtonTitle: localModeText("lib_confirm"),
                primaryAction: {}
            )
        }
    }

    private func importPlaylistFromFile(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let parsed = try LocalPlaylistManager.parseExportFile(url: url)
            let localSongMap = Dictionary(uniqueKeysWithValues: localLibrary.songs.map { ($0.id, $0) })
            let matchedSongs = parsed.songIds.compactMap { localSongMap[$0] }

            guard !matchedSongs.isEmpty else {
                AlertManager.shared.show(
                    title: localModeText("lib_import_failed"),
                    message: localModeText("local_library_import_no_local_match"),
                    primaryButtonTitle: localModeText("lib_confirm"),
                    primaryAction: {}
                )
                return
            }

            localPlaylists.importPlaylist(name: parsed.name, songs: matchedSongs)

            AlertManager.shared.show(
                title: localModeText("local_import_complete_title"),
                message: localModeFormat("local_library_import_success", parsed.name, matchedSongs.count),
                primaryButtonTitle: localModeText("lib_confirm"),
                primaryAction: {}
            )
        } catch {
            AlertManager.shared.show(
                title: localModeText("lib_import_failed"),
                message: error.localizedDescription,
                primaryButtonTitle: localModeText("lib_confirm"),
                primaryAction: {}
            )
        }
    }

    private func refreshRecentSongs() {
        recentSongs = recentOfflineSongs(limit: 20, using: downloadManager)
    }
}

struct LocalModeProfileView: View {
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @ObservedObject private var localLibrary = LocalMusicLibraryManager.shared
    @ObservedObject private var localPlaylists = LocalPlaylistManager.shared
    @ObservedObject private var downloadManager = DownloadManager.shared
    @ObservedObject private var playerManager = PlayerManager.shared

    @State private var tokenInput = SecureConfig.apiToken ?? ""
    @State private var isSubmitting = false
    @State private var recentSongs: [Song] = []

    private var customPlaylistCount: Int {
        localPlaylists.playlists.filter { !$0.isSystem }.count
    }

    private var favoriteSongs: [Song] {
        offlinePlayableSongs(from: localPlaylists.favoritePlaylist?.songs ?? [], using: downloadManager)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MonologueBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        profileHeroCard
                            .padding(.top, DeviceLayout.headerTopPadding + 10)

                        statsBar

                        shortcutsSection

                        if !recentSongs.isEmpty {
                            localRecentSection
                        }

                        managementMenu

                        localAccessCard

                        Color.clear.frame(height: 110)
                    }
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .iPadContentWidth(700)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(localModeText("tabbar_profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            tokenInput = SecureConfig.apiToken ?? tokenInput
            refreshRecentSongs()
        }
        .onReceive(playerManager.$currentSong.dropFirst()) { _ in
            refreshRecentSongs()
        }
    }

    private var profileHeroCard: some View {
        MonologueLiquidGlassCard(cornerRadius: 24) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.monologueAccent.opacity(0.9),
                                Color.monologueAccent.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .overlay(
                        MonologueIcon(icon: .profileFilled, size: 30, color: .white)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(localModeText("local_profile_hero_title"))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private var statsBar: some View {
        HStack(spacing: 0) {
            StatCell(value: "\(localLibrary.songCount)", label: localModeText("tabbar_local_music"))
            Rectangle()
                .fill(Color.monologueSeparator)
                .frame(width: 0.5, height: 28)
            StatCell(value: "\(customPlaylistCount)", label: localModeText("profile_local_playlists"))
            Rectangle()
                .fill(Color.monologueSeparator)
                .frame(width: 0.5, height: 28)
            StatCell(value: "\(downloadManager.downloadedSongIds.count)", label: localModeText("local_downloads_title"))
        }
        .padding(.vertical, 14)
        .monologueGlass(cornerRadius: 18)
    }

    private var shortcutsSection: some View {
        VStack(spacing: 14) {
            SectionHeader(
                title: localModeText("local_profile_shortcuts_title"),
                subtitle: nil
            )

            HStack(spacing: 14) {
                NavigationLink(
                    destination: LocalSystemPlaylistDestinationView(
                        playlistId: localPlaylists.favoritePlaylist?.id,
                        fallbackFilter: .favorites
                    )
                ) {
                    LocalShortcutCard(
                        title: localModeText("local_filter_favorites"),
                        value: "\(favoriteSongs.count)",
                        icon: .liked,
                        accent: .pink
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                NavigationLink(destination: LocalMusicView(initialFilter: .recent)) {
                    LocalShortcutCard(
                        title: localModeText("local_filter_recent"),
                        value: "\(recentSongs.count)",
                        icon: .history,
                        accent: .orange
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        }
    }

    private var localRecentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(localModeText("profile_recently_played"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Spacer()

                NavigationLink(destination: RecentPlayHistoryView()) {
                    HStack(spacing: 4) {
                        Text(localModeText("view_all"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                        MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(recentSongs.prefix(10)) { song in
                        SongCard(song: song) {
                            playerManager.play(song: song, in: recentSongs)
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var managementMenu: some View {
        VStack(spacing: 14) {
            SectionHeader(
                title: localModeText("local_profile_manage_title"),
                subtitle: nil
            )

            VStack(spacing: 0) {
                NavigationLink(destination: LocalLibraryView()) {
                    ProfileMenuRow(
                        icon: .library,
                        title: localModeText("local_library_navigation_title"),
                        trailingText: "\(customPlaylistCount)"
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                Divider().padding(.leading, 56)

                NavigationLink(destination: DownloadManageView()) {
                    ProfileMenuRow(
                        icon: .download,
                        title: localModeText("local_downloads_title"),
                        trailingText: "\(downloadManager.downloadedSongIds.count)"
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                Divider().padding(.leading, 56)

                NavigationLink(destination: StorageManageView()) {
                    ProfileMenuRow(
                        icon: .storage,
                        title: localModeText("settings_storage_manage")
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                Divider().padding(.leading, 56)

                NavigationLink(destination: SettingsView()) {
                    ProfileMenuRow(
                        icon: .settings,
                        title: localModeText("settings_title")
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
            }
            .monologueGlass(cornerRadius: 20)
        }
    }

    private var localAccessCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localModeText("access_unlock_title"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.monologueTextPrimary)

            HStack(spacing: 10) {
                MonologueIcon(icon: .unlock, size: 14, color: .monologueAccent)

                TextField(localModeText("access_token_input_placeholder"), text: $tokenInput)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .monologueTextInputBehavior()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.monologueSeparator.opacity(0.18))
            )

            Button {
                submitToken()
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting || onlineAccess.isVerifying {
                        ProgressView()
                            .tint(.monologueIconForeground)
                    } else {
                        MonologueIcon(icon: .sparkle, size: 13, color: .monologueIconForeground)
                    }

                    Text(localModeText("access_unlock_button"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(.monologueIconForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.monologueIconBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
            .disabled(isSubmitting || tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(20)
        .monologueGlass(cornerRadius: 22)
    }

    private func submitToken() {
        let value = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        isSubmitting = true
        Task {
            let status = await onlineAccess.submitToken(value)
            await MainActor.run {
                isSubmitting = false
                switch status {
                case .valid(let name):
                    AlertManager.shared.show(
                        title: localModeText("access_enabled_title"),
                        message: name.isEmpty ? localModeText("access_enabled_message") : localModeFormat("access_enabled_message_name", name),
                        primaryButtonTitle: localModeText("common_ok"),
                        primaryAction: {}
                    )
                case .validationDisabled:
                    AlertManager.shared.show(
                        title: localModeText("access_validation_bypassed_title"),
                        message: localModeText("access_validation_bypassed_message"),
                        primaryButtonTitle: localModeText("common_ok"),
                        primaryAction: {}
                    )
                case .invalid, .missing:
                    AlertManager.shared.show(
                        title: localModeText("access_invalid_title"),
                        message: localModeText("access_invalid_message"),
                        primaryButtonTitle: localModeText("common_ok"),
                        primaryAction: {}
                    )
                case .expired:
                    AlertManager.shared.show(
                        title: String(localized: "Token 已过期"),
                        message: String(localized: "您输入的 Token 已经过期，请获取新的 Token 或者重新授权。"),
                        primaryButtonTitle: localModeText("common_ok"),
                        primaryAction: {}
                    )
                case .deviceMismatch:
                    AlertManager.shared.show(
                        title: String(localized: "设备不匹配"),
                        message: String(localized: "此 Token 已绑定到其他设备，无法在当前设备使用。"),
                        primaryButtonTitle: localModeText("common_ok"),
                        primaryAction: {}
                    )
                case .networkError:
                    AlertManager.shared.show(
                        title: localModeText("access_network_error_title"),
                        message: localModeText("access_network_error_message"),
                        primaryButtonTitle: localModeText("common_ok"),
                        primaryAction: {}
                    )
                }
            }
        }
    }

    private func refreshRecentSongs() {
        recentSongs = recentOfflineSongs(limit: 12, using: downloadManager)
    }
}

private struct LocalPrimaryActionCard: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MonologueLiquidGlassCard(cornerRadius: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.monologueIconBackground)
                            .frame(width: 54, height: 54)

                        if isLoading {
                            ProgressView()
                                .tint(.monologueIconForeground)
                        } else {
                            Image(systemName: systemImage)
                                .font(.system(size: 21, weight: .bold))
                                .foregroundColor(.monologueIconForeground)
                        }
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundColor(.monologueTextPrimary)
                            .multilineTextAlignment(.leading)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 162, alignment: .leading)
                .padding(18)
            }
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
    }
}

private struct LocalShortcutCard: View {
    let title: String
    let value: String
    let icon: MonologueIcon.IconType
    let accent: Color

    var body: some View {
        MonologueLiquidGlassCard(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 36, height: 36)
                        .overlay(
                            MonologueIcon(icon: icon, size: 16, color: accent)
                        )

                    Spacer(minLength: 12)

                    Text(value)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
            .padding(16)
        }
    }
}

private struct LocalMetricBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(.monologueTextPrimary)

            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.monologueGlassTint.opacity(0.55))
                .monologueGlass(cornerRadius: 16)
        )
    }
}

private struct LocalInlineActionCard: View {
    let title: String
    let icon: MonologueIcon.IconType

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.monologueAccent.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    MonologueIcon(icon: icon, size: 16, color: .monologueAccent)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
            }

            Spacer(minLength: 0)

            MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary.opacity(0.7))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.monologueGlassTint.opacity(0.7))
                .monologueGlass(cornerRadius: 18)
        )
    }
}

private struct LocalManagementButton: View {
    let title: String
    let icon: MonologueIcon.IconType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MonologueLiquidGlassCard(cornerRadius: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    Circle()
                        .fill(Color.monologueAccent.opacity(0.14))
                        .frame(width: 40, height: 40)
                        .overlay(
                            MonologueIcon(icon: icon, size: 16, color: .monologueAccent)
                        )

                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
                .padding(16)
            }
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
    }
}

private struct LocalInlinePill: View {
    let title: String
    let icon: MonologueIcon.IconType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                MonologueIcon(icon: icon, size: 12, color: .monologueTextPrimary)
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Color.monologueGlassTint.opacity(0.65))
                    .monologueGlassCapsule()
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
    }
}

private struct LocalEmptyStateView: View {
    let title: String
    let subtitle: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(Color.monologueGlassTint.opacity(0.85))
                .frame(width: 62, height: 62)
                .overlay(
                    MonologueIcon(icon: .musicNoteList, size: 24, color: .monologueTextSecondary)
                )

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle, let buttonAction {
                Button(action: buttonAction) {
                    Text(buttonTitle)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.monologueIconForeground)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.monologueIconBackground)
                        .clipShape(Capsule())
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .monologueGlass(cornerRadius: 20)
    }
}

private extension View {
    @ViewBuilder
    func `if`<Transformed: View>(_ condition: Bool, transform: (Self) -> Transformed) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
