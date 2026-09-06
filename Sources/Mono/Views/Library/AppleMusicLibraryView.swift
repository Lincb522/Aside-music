import SwiftUI

enum AppleMusicLibraryCategory: String, CaseIterable, Identifiable {
    case playlists
    case songs
    case albums
    case artists

    var id: String { rawValue }

    var title: String {
        switch self {
        case .playlists: return String(localized: "apple_music_category_playlists")
        case .songs: return String(localized: "apple_music_category_songs")
        case .albums: return String(localized: "apple_music_category_albums")
        case .artists: return String(localized: "apple_music_category_artists")
        }
    }

    var icon: MonoIcon.IconType {
        switch self {
        case .playlists: return .musicNoteList
        case .songs: return .musicNote
        case .albums: return .album
        case .artists: return .personCircle
        }
    }
}

/// 按 Apple Music 原生资料库分类同步播放列表、歌曲、专辑与艺人。
@MainActor
final class AppleMusicLibraryViewModel: ObservableObject {
    @Published fileprivate var selectedCategory: AppleMusicLibraryCategory = .playlists
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var songs: [Song] = []
    @Published private(set) var albums: [AlbumInfo] = []
    @Published private(set) var artists: [ArtistInfo] = []
    @Published private(set) var loadingCategories: Set<AppleMusicLibraryCategory> = []
    @Published private(set) var loadedCategories: Set<AppleMusicLibraryCategory> = []
    @Published private(set) var errors: [AppleMusicLibraryCategory: String] = [:]

    private let service = AppleMusicService.shared
    private let pageSize = 100

    var isLoadingSelectedCategory: Bool {
        loadingCategories.contains(selectedCategory)
    }

    var selectedError: String? {
        errors[selectedCategory]
    }

    var isSelectedCategoryEmpty: Bool {
        switch selectedCategory {
        case .playlists: return playlists.isEmpty
        case .songs: return songs.isEmpty
        case .albums: return albums.isEmpty
        case .artists: return artists.isEmpty
        }
    }

    func loadSelected(force: Bool = false) async {
        await load(selectedCategory, force: force)
    }

    func load(_ category: AppleMusicLibraryCategory, force: Bool = false) async {
        guard !loadingCategories.contains(category) else { return }
        guard force || !loadedCategories.contains(category) else { return }

        loadingCategories.insert(category)
        errors[category] = nil
        defer { loadingCategories.remove(category) }

        do {
            switch category {
            case .playlists:
                playlists = try await loadAllPlaylists()
            case .songs:
                songs = try await loadAllSongs()
            case .albums:
                albums = try await loadAllAlbums()
            case .artists:
                artists = try await loadAllArtists()
            }
            guard !Task.isCancelled else { return }
            loadedCategories.insert(category)
        } catch is CancellationError {
            return
        } catch {
            errors[category] = error.localizedDescription
            AppLogger.warning(
                "[AppleMusic] 资料库\(category.title)同步失败: \(error.localizedDescription)",
                step: "apple-music.library.\(category.rawValue)"
            )
        }
    }

    private func loadAllPlaylists() async throws -> [Playlist] {
        var result: [Playlist] = []
        var offset = 0
        repeat {
            let page = try await service.libraryPlaylists(
                offset: offset,
                limit: pageSize
            )
            try Task.checkCancellation()
            result.appendUnique(page.playlists, key: { $0.appleMusicID ?? String($0.id) })
            guard page.hasMore, page.nextOffset > offset else { break }
            offset = page.nextOffset
            await Task.yield()
        } while !Task.isCancelled
        return result
    }

    private func loadAllSongs() async throws -> [Song] {
        var result: [Song] = []
        var offset = 0
        repeat {
            let page = try await service.librarySongs(
                offset: offset,
                limit: pageSize
            )
            try Task.checkCancellation()
            result.appendUnique(
                page.songs,
                key: { PlayerManager.playbackIdentityKey(for: $0) }
            )
            guard page.hasMore, page.nextOffset > offset else { break }
            offset = page.nextOffset
            await Task.yield()
        } while !Task.isCancelled
        return result
    }

    private func loadAllAlbums() async throws -> [AlbumInfo] {
        var result: [AlbumInfo] = []
        var offset = 0
        repeat {
            let page = try await service.libraryAlbums(
                offset: offset,
                limit: pageSize
            )
            try Task.checkCancellation()
            result.appendUnique(page.albums, key: { $0.appleMusicID ?? String($0.id) })
            guard page.hasMore, page.nextOffset > offset else { break }
            offset = page.nextOffset
            await Task.yield()
        } while !Task.isCancelled
        return result
    }

    private func loadAllArtists() async throws -> [ArtistInfo] {
        var result: [ArtistInfo] = []
        var offset = 0
        repeat {
            let page = try await service.libraryArtists(
                offset: offset,
                limit: pageSize
            )
            try Task.checkCancellation()
            result.appendUnique(page.artists, key: { $0.appleMusicID ?? String($0.id) })
            guard page.hasMore, page.nextOffset > offset else { break }
            offset = page.nextOffset
            await Task.yield()
        } while !Task.isCancelled
        return result
    }
}

private extension Array {
    mutating func appendUnique(
        _ newElements: [Element],
        key: (Element) -> String
    ) {
        var existing = Set(map(key))
        for element in newElements where existing.insert(key(element)).inserted {
            append(element)
        }
    }
}

struct AppleMusicLibraryView: View {
    @StateObject private var model = AppleMusicLibraryViewModel()

    let embeddedInParentScroll: Bool

    init(embeddedInParentScroll: Bool = false) {
        self.embeddedInParentScroll = embeddedInParentScroll
    }

    var body: some View {
        Group {
            if embeddedInParentScroll {
                content
            } else {
                ScrollView {
                    content
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
            }
        }
        .task(id: model.selectedCategory) {
            await model.loadSelected()
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            categoryPicker
            categoryContent
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(AppleMusicLibraryCategory.allCases) { category in
                    let selected = model.selectedCategory == category
                    Button {
                        model.selectedCategory = category
                    } label: {
                        HStack(spacing: 6) {
                            MonoIcon(
                                icon: category.icon,
                                size: 12,
                                color: selected
                                    ? .monoIconForeground
                                    : Color.monoTextSecondary
                            )
                            Text(category.title)
                                .font(.rounded(size: 12, weight: selected ? .semibold : .medium))
                                .foregroundStyle(
                                    selected
                                        ? Color.monoTextPrimary
                                        : Color.monoTextSecondary
                                )
                        }
                        .padding(.horizontal, 13)
                        .frame(height: 38)
                        .background(
                            Capsule()
                                .fill(
                                    selected
                                        ? MusicSource.appleMusic.themedBadgeColor.opacity(0.2)
                                        : Color.monoGlassTint.opacity(0.45)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, embeddedInParentScroll ? 0 : DeviceLayout.libraryHorizontalPadding)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
    }

    @ViewBuilder
    private var categoryContent: some View {
        if model.isLoadingSelectedCategory, model.isSelectedCategoryEmpty {
            ProgressView()
                .tint(MusicSource.appleMusic.themedBadgeColor)
                .frame(maxWidth: .infinity)
                .padding(.top, 42)
        } else if let errorMessage = model.selectedError,
                  model.isSelectedCategoryEmpty {
            statusView(
                icon: model.selectedCategory.icon,
                title: "无法读取\(model.selectedCategory.title)",
                detail: errorMessage,
                actionTitle: String(localized: "action_retry")
            ) {
                Task {
                    await model.loadSelected(force: true)
                }
            }
        } else if model.isSelectedCategoryEmpty {
            statusView(
                icon: model.selectedCategory.icon,
                title: "Apple Music 资料库中暂无\(model.selectedCategory.title)",
                detail: nil,
                actionTitle: nil,
                action: nil
            )
        } else {
            switch model.selectedCategory {
            case .playlists:
                playlistContent
            case .songs:
                songContent
            case .albums:
                albumContent
            case .artists:
                artistContent
            }
        }
    }

    private var playlistContent: some View {
        LazyVStack(spacing: 8) {
            ForEach(model.playlists) { playlist in
                NavigationLink(
                    value: LibraryViewModel.NavigationDestination.playlist(playlist)
                ) {
                    collectionRow(
                        imageURL: playlist.coverUrl,
                        title: playlist.name,
                        subtitle: playlist.trackCount.map { "\($0) 首歌曲" },
                        circularArtwork: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, embeddedInParentScroll ? 0 : DeviceLayout.libraryHorizontalPadding)
        .padding(.bottom, embeddedInParentScroll ? 0 : 120)
    }

    private var songContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(model.songs.enumerated()), id: \.element.identityKey) { index, song in
                SongListRow(
                    song: song,
                    index: index,
                    onTap: {
                        PlayerManager.shared.play(
                            song: song,
                            in: model.songs
                        )
                    }
                )
            }
        }
        .padding(.bottom, embeddedInParentScroll ? 0 : 120)
    }

    private var albumContent: some View {
        LazyVStack(spacing: 8) {
            ForEach(model.albums) { album in
                NavigationLink {
                    AlbumDetailView(album: album)
                } label: {
                    collectionRow(
                        imageURL: album.coverUrl,
                        title: album.name,
                        subtitle: album.artistName,
                        circularArtwork: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, embeddedInParentScroll ? 0 : DeviceLayout.libraryHorizontalPadding)
        .padding(.bottom, embeddedInParentScroll ? 0 : 120)
    }

    private var artistContent: some View {
        LazyVStack(spacing: 8) {
            ForEach(model.artists) { artist in
                NavigationLink(
                    value: LibraryViewModel.NavigationDestination.artistInfo(artist)
                ) {
                    collectionRow(
                        imageURL: artist.coverUrl,
                        title: artist.name,
                        subtitle: nil,
                        circularArtwork: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, embeddedInParentScroll ? 0 : DeviceLayout.libraryHorizontalPadding)
        .padding(.bottom, embeddedInParentScroll ? 0 : 120)
    }

    private func collectionRow(
        imageURL: URL?,
        title: String,
        subtitle: String?,
        circularArtwork: Bool
    ) -> some View {
        HStack(spacing: 13) {
            CachedAsyncImage(
                url: imageURL?.sized(400),
                width: 58,
                height: 58
            ) {
                RoundedRectangle(cornerRadius: circularArtwork ? 29 : 11, style: .continuous)
                    .fill(Color.gray.opacity(0.12))
                    .overlay {
                        MonoIcon(
                            icon: circularArtwork ? .personCircle : .musicNote,
                            size: 21,
                            color: Color.monoTextSecondary.opacity(0.65)
                        )
                    }
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 58, height: 58)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: circularArtwork ? 29 : 11,
                    style: .continuous
                )
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.rounded(size: 14, weight: .semibold))
                    .foregroundStyle(Color.monoTextPrimary)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.rounded(size: 11, weight: .regular))
                        .foregroundStyle(Color.monoTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)
            MonoIcon(icon: .chevronRight, size: 11, color: Color.monoTextSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.monoGlassTint.opacity(0.32))
        )
        .contentShape(Rectangle())
    }

    private func statusView(
        icon: MonoIcon.IconType,
        title: String,
        detail: String?,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        VStack(spacing: 12) {
            MonoIcon(
                icon: icon,
                size: 34,
                color: MusicSource.appleMusic.themedBadgeColor,
                lineWidth: 1.7
            )

            Text(title)
                .font(.rounded(size: 15, weight: .semibold))
                .foregroundStyle(Color.monoTextPrimary)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.rounded(size: 12, weight: .regular))
                    .foregroundStyle(Color.monoTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.rounded(size: 12, weight: .semibold))
                        .foregroundStyle(Color.monoTextPrimary)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(MusicSource.appleMusic.themedBadgeColor.opacity(0.16))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.top, 42)
    }
}
