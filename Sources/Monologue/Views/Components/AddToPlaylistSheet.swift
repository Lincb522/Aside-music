import SwiftUI

/// 单曲收藏到歌单选择器
struct AddToPlaylistSheet: View {
    let song: Song

    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    @ObservedObject private var manager = LocalPlaylistManager.shared

    @State private var showCreateLocal = false
    @State private var showCreateNetease = false
    @State private var newPlaylistName = ""
    @State private var neteaseUserPlaylists: [Playlist] = []
    @State private var isLoadingNetease = false
    @State private var activeOperationID: String?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private enum OperationKey {
        static let favorite = "favorite"
        static let createLocal = "create_local"
        static let createNetease = "create_netease"

        static func localPlaylist(_ id: String) -> String {
            "local_\(id)"
        }

        static func neteasePlaylist(_ id: Int) -> String {
            "netease_\(id)"
        }
    }

    private enum PlaylistPickerError: LocalizedError {
        case createFailed
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .createFailed:
                return String(localized: "playlist_picker_create_failed")
            case .saveFailed:
                return String(localized: "playlist_picker_save_failed")
            }
        }
    }

    private var trimmedPlaylistName: String {
        newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFavorite: Bool {
        manager.isFavorite(songId: song.id)
    }

    private var localPlaylists: [LocalPlaylist] {
        manager.playlists.filter { !$0.isDownload && !$0.isFavorite }
    }

    private var isBusy: Bool {
        activeOperationID != nil
    }
    
    var body: some View {
        NavigationStack {
                ScrollView {
                VStack(spacing: 20) {
                    summaryCard
                    quickActionsSection
                        localPlaylistSection
                        
                        if !song.isQQMusic {
                            neteasePlaylistSection
                        }
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, 36)
                .iPadContentWidth(520)
            }
            .scrollIndicators(.hidden)
            .background {
                MonologueSheetAwareBackground {
                    ThemedPageBackground()
                }
            }
            .themedNavigationChrome(title: String(localized: "add_to_playlist_title"), eyebrow: "PLAYLIST", icon: .addToQueue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("alert_cancel")) {
                        dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
                    }
                    .disabled(isBusy)
                }
            }
            .task(id: song.id) {
                if !song.isQQMusic {
                    await loadNeteaseUserPlaylists()
                }
            }
            .alert(LocalizedStringKey("add_to_playlist_create"), isPresented: $showCreateLocal) {
                TextField(LocalizedStringKey("add_to_playlist_name"), text: $newPlaylistName)
                    .monologueTextInputBehavior()
                Button(LocalizedStringKey("lib_create")) {
                    guard !trimmedPlaylistName.isEmpty else { return }
                    Task { await createLocalPlaylist() }
                }
                Button(LocalizedStringKey("alert_cancel"), role: .cancel) {}
            }
            .alert(LocalizedStringKey("create_netease_playlist"), isPresented: $showCreateNetease) {
                TextField(LocalizedStringKey("create_netease_playlist_name"), text: $newPlaylistName)
                    .monologueTextInputBehavior()
                Button(LocalizedStringKey("lib_create")) {
                    guard !trimmedPlaylistName.isEmpty else { return }
                    Task { await createNeteasePlaylist() }
                }
                Button(LocalizedStringKey("alert_cancel"), role: .cancel) {}
            }
            .alert(LocalizedStringKey("playlist_picker_error_title"), isPresented: $showErrorAlert) {
                Button(LocalizedStringKey("alert_cancel"), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var summaryCard: some View {
        PlaylistPickerContainerCard {
            HStack(spacing: 14) {
                Group {
                    if let coverURL = song.coverUrl {
                        CachedAsyncImage(url: coverURL.sized(200)) {
                            summaryArtworkPlaceholder
                        }
                        .aspectRatio(contentMode: .fill)
                    } else {
                        summaryArtworkPlaceholder
                    }
                }
                .frame(width: 58, height: 58)
                .clipShape(.rect(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(song.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.monologueTextPrimary)
                        .lineLimit(2)

                    Text(song.artistName)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color.monologueTextSecondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        PlaylistPickerStatusBadge(
                            text: song.musicSource.widgetDisplayName,
                            tint: song.musicSource.themedBadgeColor
                        )

                        if isFavorite {
                            PlaylistPickerStatusBadge(
                                text: String(localized: "playlist_picker_already_saved"),
                                tint: .red
                            )
                        }
                    }

                    Text(String(localized: "playlist_picker_choose_destination"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.monologueTextSecondary.opacity(0.8))
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var quickActionsSection: some View {
        PlaylistPickerSection(
            title: LocalizedStringKey("playlist_picker_quick_actions"),
            subtitle: String(localized: "playlist_picker_quick_actions_subtitle")
        ) {
            PlaylistPickerActionCard(
                icon: .liked,
                title: String(localized: "playlist_picker_liked"),
                subtitle: String(localized: "playlist_picker_liked_subtitle"),
                tint: .red,
                statusText: isFavorite ? String(localized: "playlist_picker_already_saved") : nil,
                statusTint: .red,
                isLoading: activeOperationID == OperationKey.favorite,
                isDisabled: isFavorite || isBusy
            ) {
                Task { await addToFavorite() }
            }

            PlaylistPickerActionCard(
                icon: .add,
                title: String(localized: "add_to_playlist_new"),
                subtitle: String(localized: "playlist_picker_local_create_subtitle"),
                tint: .monologueAccentBlue,
                isLoading: activeOperationID == OperationKey.createLocal,
                isDisabled: isBusy
            ) {
                newPlaylistName = ""
                showCreateLocal = true
            }

            if !song.isQQMusic {
                PlaylistPickerActionCard(
                    icon: .cloud,
                    title: String(localized: "create_netease_playlist"),
                    subtitle: String(localized: "playlist_picker_netease_create_subtitle"),
                    tint: .green,
                    isLoading: activeOperationID == OperationKey.createNetease,
                    isDisabled: isBusy
                ) {
                    newPlaylistName = ""
                    showCreateNetease = true
                }
            }
        }
    }

    private var localPlaylistSection: some View {
        PlaylistPickerSection(
            title: LocalizedStringKey("local_playlist_section"),
            subtitle: String(localized: "playlist_picker_local_section_subtitle")
        ) {
            if localPlaylists.isEmpty {
                PlaylistPickerEmptyStateCard(
                    icon: .musicNoteList,
                    message: String(localized: "playlist_picker_empty_local")
                )
            } else {
                ForEach(localPlaylists, id: \.id) { playlist in
                    let contains = playlist.containsSong(id: song.id)

                    PlaylistPickerPlaylistRow(
                        title: playlist.name,
                        subtitle: songsCountText(playlist.trackCount),
                        coverURL: playlist.displayCoverUrl,
                        placeholderIcon: .musicNoteList,
                        statusText: contains ? String(localized: "playlist_picker_already_saved") : nil,
                        statusTint: .monologueTextSecondary,
                        isLoading: activeOperationID == OperationKey.localPlaylist(playlist.id),
                        isDisabled: contains || isBusy
                    ) {
                        Task { await addToLocalPlaylist(playlist) }
                    }
                }
            }
        }
    }
    
    private var neteasePlaylistSection: some View {
        PlaylistPickerSection(
            title: LocalizedStringKey("netease_playlist_section"),
            subtitle: String(localized: "playlist_picker_netease_section_subtitle")
        ) {
            if isLoadingNetease {
                PlaylistPickerContainerCard {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.monologueTextSecondary)

                        Text(LocalizedStringKey("refreshing"))
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Color.monologueTextSecondary)
                    }
                }
            } else if neteaseUserPlaylists.isEmpty {
                PlaylistPickerEmptyStateCard(
                    icon: .cloud,
                    message: String(localized: "playlist_picker_empty_netease")
                )
            } else {
                ForEach(neteaseUserPlaylists) { playlist in
                    PlaylistPickerPlaylistRow(
                        title: playlist.name,
                        subtitle: songsCountText(playlist.trackCount ?? 0),
                        coverURL: playlist.coverUrl,
                        placeholderIcon: .cloud,
                        isLoading: activeOperationID == OperationKey.neteasePlaylist(playlist.id),
                        isDisabled: isBusy,
                        showsChevron: true
                    ) {
                        Task { await addToNeteasePlaylist(pid: playlist.id) }
                    }
                }
            }
        }
    }

    private var summaryArtworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.monologueGlassTint)

            MonologueIcon(icon: .musicNote, size: 20, color: .monologueTextSecondary.opacity(0.45))
        }
    }

    @MainActor
    private func addToFavorite() async {
        guard !isFavorite else { return }

        activeOperationID = OperationKey.favorite
        defer { activeOperationID = nil }

        manager.addToFavorite(song)
        dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
    }

    @MainActor
    private func addToLocalPlaylist(_ playlist: LocalPlaylist) async {
        guard !playlist.containsSong(id: song.id) else { return }

        activeOperationID = OperationKey.localPlaylist(playlist.id)
        defer { activeOperationID = nil }

        manager.addSong(song, to: playlist)
        dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
    }

    @MainActor
    private func createLocalPlaylist() async {
        let name = trimmedPlaylistName
        guard !name.isEmpty else { return }

        activeOperationID = OperationKey.createLocal
        defer {
            activeOperationID = nil
            newPlaylistName = ""
        }

        let playlist = manager.createPlaylist(name: name)
        manager.addSong(song, to: playlist)
        dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
    }

    @MainActor
    private func loadNeteaseUserPlaylists() async {
        guard let uid = APIService.shared.currentUserId else {
            neteaseUserPlaylists = []
            return
        }

        isLoadingNetease = true
        defer { isLoadingNetease = false }

        do {
            let playlists = try await APIService.shared.fetchUserPlaylists(uid: uid).async()
                neteaseUserPlaylists = playlists.filter { $0.creator?.userId == uid }
        } catch {
            neteaseUserPlaylists = []
            AppLogger.error("加载 NCM 歌单失败: \(error)")
        }
    }

    @MainActor
    private func createNeteasePlaylist() async {
        let name = trimmedPlaylistName
        guard !name.isEmpty else { return }

        activeOperationID = OperationKey.createNetease
        defer {
            activeOperationID = nil
            newPlaylistName = ""
        }

        do {
            guard let playlist = try await APIService.shared.createPlaylist(name: name, privacy: 0).async() else {
                throw PlaylistPickerError.createFailed
            }

            let response = try await APIService.shared
                .modifyPlaylistTracks(op: "add", pid: playlist.id, trackIds: [song.id])
                .async()

            guard response.code == 200 else {
                throw PlaylistPickerError.saveFailed
            }

                    dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
        } catch {
            presentError(error)
        }
    }

    @MainActor
    private func addToNeteasePlaylist(pid: Int) async {
        activeOperationID = OperationKey.neteasePlaylist(pid)
        defer { activeOperationID = nil }

        do {
            let response = try await APIService.shared
                .modifyPlaylistTracks(op: "add", pid: pid, trackIds: [song.id])
                .async()

            guard response.code == 200 else {
                throw PlaylistPickerError.saveFailed
            }

            dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
        } catch {
            presentError(error)
        }
    }

    private func presentError(_ error: Error) {
        AppLogger.error("收藏到歌单失败: \(error)")
        errorMessage = error.localizedDescription
        showErrorAlert = true
    }

    private func songsCountText(_ count: Int) -> String {
        String(format: NSLocalizedString("songs_count_format", comment: ""), count)
    }
}
