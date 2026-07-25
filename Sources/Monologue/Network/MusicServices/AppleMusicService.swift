import Foundation
import Combine
@preconcurrency import MusicKit

struct AppleMusicSearchPage {
    let songs: [Song]
    let hasMore: Bool
}

struct AppleMusicLibraryPage {
    let songs: [Song]
    let hasMore: Bool
    let nextOffset: Int
}

struct AppleMusicPlaylistPage {
    let playlists: [Playlist]
    let hasMore: Bool
}

struct AppleMusicArtistPage {
    let artists: [ArtistInfo]
    let hasMore: Bool
}

struct AppleMusicArtistDetailPage {
    let artist: ArtistInfo
    let songs: [Song]
    let albums: [AlbumInfo]
    let similarArtists: [ArtistInfo]
}

struct AppleMusicAlbumDetailPage {
    let album: AlbumInfo
    let songs: [Song]
}

enum AppleMusicServiceError: LocalizedError {
    case authorizationDenied
    case requestUnauthorized
    case subscriptionRequired
    case invalidCatalogID
    case itemUnavailable

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return String(localized: "apple_music_error_authorization")
        case .requestUnauthorized:
            return String(localized: "apple_music_error_request_unauthorized")
        case .subscriptionRequired:
            return String(localized: "apple_music_error_subscription")
        case .invalidCatalogID:
            return String(localized: "apple_music_error_invalid_id")
        case .itemUnavailable:
            return String(localized: "apple_music_error_unavailable")
        }
    }
}

@MainActor
final class AppleMusicService: ObservableObject {
    static let shared = AppleMusicService()

    @Published private(set) var authorizationStatus = MusicAuthorization.currentStatus
    @Published private(set) var canPlayCatalogContent = false

    private var songCache: [String: MusicKit.Song] = [:]
    private var artworkURLCache: [String: URL] = [:]
    private var playlistCache: [String: MusicKit.Playlist] = [:]
    private var playlistTrackCache: [String: MusicItemCollection<MusicKit.Track>] = [:]
    private var subscriptionCheckTask: Task<Bool, Never>?
    private var subscriptionStatusCheckedAt: Date?
    private let subscriptionStatusCacheDuration: TimeInterval = 5 * 60

    private init() {}

    var isAuthorized: Bool {
        MusicAuthorization.currentStatus == .authorized
    }

    @discardableResult
    func requestAuthorizationIfNeeded(
        refreshesSubscription: Bool = false
    ) async -> Bool {
        let status: MusicAuthorization.Status
        if MusicAuthorization.currentStatus == .notDetermined {
            status = await MusicAuthorization.request()
        } else {
            status = MusicAuthorization.currentStatus
        }
        authorizationStatus = status
        guard status == .authorized else {
            subscriptionCheckTask?.cancel()
            subscriptionCheckTask = nil
            subscriptionStatusCheckedAt = nil
            canPlayCatalogContent = false
            return false
        }

        if refreshesSubscription {
            _ = await refreshSubscriptionStatusIfNeeded()
        }
        return true
    }

    /// 订阅状态属于播放能力，不应被每次目录搜索、歌单翻页重复查询。
    /// MusicKit 的账号解析失败时系统会产生大量 DSID 日志，因此这里合并
    /// 并缓存并发请求；真正播放或用户主动授权时才刷新。
    private func refreshSubscriptionStatusIfNeeded(
        force: Bool = false
    ) async -> Bool {
        if !force,
           let checkedAt = subscriptionStatusCheckedAt,
           Date().timeIntervalSince(checkedAt) < subscriptionStatusCacheDuration {
            return canPlayCatalogContent
        }

        if let task = subscriptionCheckTask {
            return await task.value
        }

        let task = Task { @MainActor () -> Bool in
            do {
                let subscription = try await MusicSubscription.current
                return subscription.canPlayCatalogContent
            } catch {
                AppLogger.warning(
                    "[AppleMusic] 无法读取订阅状态: \(error.localizedDescription)",
                    step: "apple-music.subscription"
                )
                return false
            }
        }
        subscriptionCheckTask = task
        let canPlay = await task.value
        subscriptionCheckTask = nil
        subscriptionStatusCheckedAt = Date()
        canPlayCatalogContent = canPlay
        return canPlay
    }

    func searchSongs(
        term: String,
        offset: Int,
        limit: Int = 25
    ) async throws -> AppleMusicSearchPage {
        guard await requestAuthorizationIfNeeded() else {
            throw AppleMusicServiceError.authorizationDenied
        }

        var request = MusicCatalogSearchRequest(term: term, types: [MusicKit.Song.self])
        request.offset = max(0, offset)
        request.limit = max(1, min(limit, 25))
        let response = try await Self.performMusicKitRequest {
            try await request.response()
        }
        let musicKitSongs: [MusicKit.Song] = Array(response.songs)
        for song in musicKitSongs {
            songCache[song.id.rawValue] = song
        }
        let songs: [Song] = musicKitSongs.compactMap { song in
            Self.convert(song)
        }
        return AppleMusicSearchPage(
            songs: songs,
            hasMore: musicKitSongs.count >= max(1, min(limit, 25))
        )
    }

    func librarySongs(
        offset: Int,
        limit: Int = 50
    ) async throws -> AppleMusicLibraryPage {
        guard await requestAuthorizationIfNeeded() else {
            throw AppleMusicServiceError.authorizationDenied
        }

        let pageSize = max(1, min(limit, 100))
        var request = MusicLibraryRequest<MusicKit.Song>()
        request.offset = max(0, offset)
        request.limit = pageSize
        request.sort(by: \.libraryAddedDate, ascending: false)
        let response = try await Self.performMusicKitRequest {
            try await request.response()
        }
        let musicKitSongs: [MusicKit.Song] = Array(response.items)
        cache(musicKitSongs)
        let songs: [Song] = musicKitSongs.compactMap { song in
            Self.convert(song)
        }
        return AppleMusicLibraryPage(
            songs: songs,
            hasMore: response.items.hasNextBatch,
            nextOffset: max(0, offset) + musicKitSongs.count
        )
    }

    func searchPlaylists(
        term: String,
        offset: Int,
        limit: Int = 25
    ) async throws -> AppleMusicPlaylistPage {
        guard await requestAuthorizationIfNeeded() else {
            throw AppleMusicServiceError.authorizationDenied
        }

        let pageSize = max(1, min(limit, 25))
        var request = MusicCatalogSearchRequest(term: term, types: [MusicKit.Playlist.self])
        request.offset = max(0, offset)
        request.limit = pageSize
        let response = try await Self.performMusicKitRequest {
            try await request.response()
        }
        let playlists: [MusicKit.Playlist] = Array(response.playlists)
        for playlist in playlists {
            playlistCache[playlist.id.rawValue] = playlist
        }
        let convertedPlaylists: [Playlist] = playlists.compactMap { playlist in
            Self.convert(playlist)
        }
        return AppleMusicPlaylistPage(
            playlists: convertedPlaylists,
            hasMore: playlists.count >= pageSize
        )
    }

    func searchArtists(
        term: String,
        offset: Int,
        limit: Int = 25
    ) async throws -> AppleMusicArtistPage {
        guard await requestAuthorizationIfNeeded() else {
            throw AppleMusicServiceError.authorizationDenied
        }

        let pageSize = max(1, min(limit, 25))
        var request = MusicCatalogSearchRequest(term: term, types: [MusicKit.Artist.self])
        request.offset = max(0, offset)
        request.limit = pageSize
        let response = try await Self.performMusicKitRequest {
            try await request.response()
        }
        let artists: [MusicKit.Artist] = Array(response.artists)
        let convertedArtists: [ArtistInfo] = artists.compactMap { artist in
            Self.convert(artist)
        }
        return AppleMusicArtistPage(
            artists: convertedArtists,
            hasMore: artists.count >= pageSize
        )
    }

    func artistDetail(artistID: String) async throws -> AppleMusicArtistDetailPage {
        guard await requestAuthorizationIfNeeded() else {
            throw AppleMusicServiceError.authorizationDenied
        }

        var request = MusicCatalogResourceRequest<MusicKit.Artist>(
            matching: \.id,
            equalTo: MusicItemID(artistID)
        )
        request.limit = 1
        request.properties = [
            .topSongs,
            .albums,
            .similarArtists
        ]

        guard let source = try await Self.performMusicKitRequest({
            try await request.response()
        }).items.first else {
            throw AppleMusicServiceError.itemUnavailable
        }

        let musicKitSongs: [MusicKit.Song] = source.topSongs.map { collection in
            Array(collection)
        } ?? []
        cache(musicKitSongs)
        let songs: [Song] = musicKitSongs.compactMap { song in
            Self.convert(song)
        }
        let musicKitAlbums: [MusicKit.Album] = source.albums.map { collection in
            Array(collection)
        } ?? []
        let albums: [AlbumInfo] = musicKitAlbums.compactMap { album in
            Self.convert(album)
        }
        let relatedArtists: [MusicKit.Artist] = source.similarArtists.map { collection in
            Array(collection)
        } ?? []
        let similarArtists: [ArtistInfo] = relatedArtists.compactMap { relatedArtist in
            Self.convert(relatedArtist)
        }
        let artist = Self.convert(
            source,
            musicSize: songs.count,
            albumSize: albums.count,
            mvSize: source.musicVideos?.count
        )

        guard let artist else {
            throw AppleMusicServiceError.itemUnavailable
        }

        return AppleMusicArtistDetailPage(
            artist: artist,
            songs: songs,
            albums: albums,
            similarArtists: similarArtists
        )
    }

    func albumDetail(albumID: String) async throws -> AppleMusicAlbumDetailPage {
        guard await requestAuthorizationIfNeeded() else {
            throw AppleMusicServiceError.authorizationDenied
        }

        var request = MusicCatalogResourceRequest<MusicKit.Album>(
            matching: \.id,
            equalTo: MusicItemID(albumID)
        )
        request.limit = 1
        request.properties = [.tracks]

        guard let source = try await Self.performMusicKitRequest({
            try await request.response()
        }).items.first,
        let album = Self.convert(source) else {
            throw AppleMusicServiceError.itemUnavailable
        }

        var tracks = source.tracks ?? []
        while tracks.hasNextBatch,
              let nextBatch = try await Self.performMusicKitRequest({
                  try await tracks.nextBatch(limit: 100)
              }) {
            tracks += nextBatch
        }

        let musicKitSongs = Array(tracks).compactMap { track -> MusicKit.Song? in
            guard case let .song(song) = track else { return nil }
            return song
        }
        cache(musicKitSongs)
        let songs: [Song] = musicKitSongs.compactMap { song in
            Self.convert(song)
        }

        return AppleMusicAlbumDetailPage(
            album: album,
            songs: songs
        )
    }

    /// 分页读取 Apple Music 歌单曲目，并缓存已补全的歌单关系与已拉取批次。
    ///
    /// `offset` 超出当前缓存时会按需请求后续批次；非歌曲类型的 Track 会被过滤。
    func playlistSongs(
        playlistID: String,
        offset: Int,
        limit: Int = 30
    ) async throws -> AppleMusicSearchPage {
        guard await requestAuthorizationIfNeeded() else {
            throw AppleMusicServiceError.authorizationDenied
        }

        let pageSize = max(1, min(limit, 100))
        let playlist: MusicKit.Playlist
        if let cached = playlistCache[playlistID] {
            playlist = cached
        } else {
            var request = MusicCatalogResourceRequest<MusicKit.Playlist>(
                matching: \.id,
                equalTo: MusicItemID(playlistID)
            )
            request.limit = 1
            guard let resolved = try await Self.performMusicKitRequest({
                try await request.response()
            }).items.first else {
                throw AppleMusicServiceError.itemUnavailable
            }
            playlistCache[playlistID] = resolved
            playlist = resolved
        }

        var trackCollection: MusicItemCollection<MusicKit.Track>
        if let cachedTracks = playlistTrackCache[playlistID] {
            trackCollection = cachedTracks
        } else {
            let hydratedPlaylist = try await Self.performMusicKitRequest {
                try await playlist.with(.tracks)
            }
            playlistCache[playlistID] = hydratedPlaylist
            guard let hydratedTracks = hydratedPlaylist.tracks else {
                return AppleMusicSearchPage(songs: [], hasMore: false)
            }
            trackCollection = hydratedTracks
        }

        let requiredCount = max(0, offset) + pageSize
        while trackCollection.count < requiredCount,
              trackCollection.hasNextBatch,
              let nextBatch = try await Self.performMusicKitRequest({
                  try await trackCollection.nextBatch(limit: pageSize)
              }) {
            trackCollection += nextBatch
        }
        playlistTrackCache[playlistID] = trackCollection

        let tracks = Array(trackCollection)
        let start = min(max(0, offset), tracks.count)
        let end = min(start + pageSize, tracks.count)
        let songs = tracks[start..<end].compactMap { track -> Song? in
            guard case let .song(song) = track else { return nil }
            songCache[song.id.rawValue] = song
            return Self.convert(song)
        }
        return AppleMusicSearchPage(
            songs: songs,
            hasMore: end < tracks.count || trackCollection.hasNextBatch
        )
    }

    /// 资料库歌曲的 `Song.artwork` 偶尔为空，但其专辑关系或对应目录歌曲仍有封面。
    /// 播放链路调用此方法异步补图，不阻塞 MusicKit 开始播放。
    func resolvedArtworkURL(
        for song: Song,
        preferred source: MusicKit.Song? = nil
    ) async -> URL? {
        let cacheKey = song.appleMusicCatalogID ?? String(song.id)
        if let cached = artworkURLCache[cacheKey] {
            return cached
        }

        var checkedIDs = Set<String>()
        var candidates: [MusicKit.Song] = []
        if let source {
            candidates.append(source)
        }
        if let catalogID = song.appleMusicCatalogID,
           let cachedSong = songCache[catalogID],
           !candidates.contains(where: { $0.id == cachedSong.id }) {
            candidates.append(cachedSong)
        }

        for candidate in candidates {
            checkedIDs.insert(candidate.id.rawValue)
            if let url = await artworkURL(from: candidate) {
                cacheArtworkURL(url, for: song, source: candidate)
                return url
            }
        }

        if let catalogID = song.appleMusicCatalogID,
           !catalogID.isEmpty,
           !checkedIDs.contains(catalogID) {
            var request = MusicCatalogResourceRequest<MusicKit.Song>(
                matching: \.id,
                equalTo: MusicItemID(catalogID)
            )
            request.limit = 1
            request.properties = [.albums]
            if let resolved = try? await Self.performMusicKitRequest({
                try await request.response()
            }).items.first {
                songCache[catalogID] = resolved
                if let url = await artworkURL(from: resolved) {
                    cacheArtworkURL(url, for: song, source: resolved)
                    return url
                }
            }
        }

        if let isrc = song.appleMusicISRC, !isrc.isEmpty {
            var request = MusicCatalogResourceRequest<MusicKit.Song>(
                matching: \.isrc,
                equalTo: isrc
            )
            request.limit = 1
            request.properties = [.albums]
            if let resolved = try? await Self.performMusicKitRequest({
                try await request.response()
            }).items.first {
                songCache[resolved.id.rawValue] = resolved
                if let url = await artworkURL(from: resolved) {
                    cacheArtworkURL(url, for: song, source: resolved)
                    return url
                }
            }
        }

        let query = "\(song.artistName) \(song.name)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            var request = MusicCatalogSearchRequest(
                term: query,
                types: [MusicKit.Song.self]
            )
            request.limit = 10
            if let response = try? await Self.performMusicKitRequest({
                try await request.response()
            }) {
                let matches = Array(response.songs)
                    .sorted {
                        Self.artworkMatchScore($0, target: song)
                            > Self.artworkMatchScore($1, target: song)
                    }
                for resolved in matches
                where Self.artworkMatchScore(resolved, target: song) >= 0.72 {
                    songCache[resolved.id.rawValue] = resolved
                    if let url = await artworkURL(from: resolved) {
                        cacheArtworkURL(url, for: song, source: resolved)
                        return url
                    }
                }
            }
        }

        if let existing = song.coverUrl {
            artworkURLCache[cacheKey] = existing
            return existing
        }
        return nil
    }

    func playableSong(for song: Song) async throws -> MusicKit.Song {
        guard await requestAuthorizationIfNeeded() else {
            throw AppleMusicServiceError.authorizationDenied
        }
        guard await refreshSubscriptionStatusIfNeeded() else {
            throw AppleMusicServiceError.subscriptionRequired
        }
        guard let catalogID = song.appleMusicCatalogID, !catalogID.isEmpty else {
            throw AppleMusicServiceError.invalidCatalogID
        }
        if let cached = songCache[catalogID] {
            return cached
        }

        var request = MusicCatalogResourceRequest<MusicKit.Song>(
            matching: \.id,
            equalTo: MusicItemID(catalogID)
        )
        request.limit = 1
        do {
            if let resolved = try await request.response().items.first {
                songCache[catalogID] = resolved
                return resolved
            }
        } catch let serviceError as AppleMusicServiceError {
            throw serviceError
        } catch {
            if Self.isUnauthorizedMusicKitError(error) {
                throw AppleMusicServiceError.requestUnauthorized
            }
            AppLogger.debug(
                "[AppleMusic] 目录 ID 恢复失败，尝试资料库与 ISRC: \(catalogID)",
                step: "apple-music.catalog-id-fallback"
            )
        }

        // 资料库歌曲在部分地区会返回 library ID。重启后内存缓存不存在时，
        // 先从用户资料库按 ID 恢复，再用 ISRC 回退到当前 storefront。
        var libraryRequest = MusicLibraryRequest<MusicKit.Song>()
        libraryRequest.limit = 1
        libraryRequest.filter(
            matching: \.id,
            equalTo: MusicItemID(catalogID)
        )
        do {
            if let resolved = try await libraryRequest.response().items.first {
                songCache[catalogID] = resolved
                return resolved
            }
        } catch {
            if Self.isUnauthorizedMusicKitError(error) {
                throw AppleMusicServiceError.requestUnauthorized
            }
        }

        if let isrc = song.appleMusicISRC, !isrc.isEmpty {
            var isrcRequest = MusicCatalogResourceRequest<MusicKit.Song>(
                matching: \.isrc,
                equalTo: isrc
            )
            isrcRequest.limit = 1
            do {
                if let resolved = try await isrcRequest.response().items.first {
                    songCache[catalogID] = resolved
                    songCache[resolved.id.rawValue] = resolved
                    return resolved
                }
            } catch {
                throw Self.normalizedError(error)
            }
        }
        throw AppleMusicServiceError.itemUnavailable
    }

    private static func normalizedError(_ error: Error) -> Error {
        if let serviceError = error as? AppleMusicServiceError {
            return serviceError
        }
        if isUnauthorizedMusicKitError(error) {
            return AppleMusicServiceError.requestUnauthorized
        }
        return error
    }

    private static func performMusicKitRequest<T>(
        _ operation: () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            throw normalizedError(error)
        }
    }

    private static func isUnauthorizedMusicKitError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.code == 401 { return true }

        let description = [
            nsError.localizedDescription,
            nsError.localizedFailureReason,
            nsError.localizedRecoverySuggestion
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        if description.contains("401") || description.contains("unauthorized") {
            return true
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isUnauthorizedMusicKitError(underlying)
        }
        return false
    }

    private func cache(_ songs: [MusicKit.Song]) {
        for song in songs {
            songCache[song.id.rawValue] = song
        }
    }

    private func artworkURL(from song: MusicKit.Song) async -> URL? {
        if let direct = song.artwork?.url(width: 1200, height: 1200) {
            return direct
        }
        if let albumArtwork = song.albums?.first?.artwork?.url(width: 1200, height: 1200) {
            return albumArtwork
        }

        guard let hydrated = try? await Self.performMusicKitRequest({
            try await song.with(.albums)
        }) else {
            return nil
        }
        songCache[song.id.rawValue] = hydrated
        return hydrated.artwork?.url(width: 1200, height: 1200)
            ?? hydrated.albums?.first?.artwork?.url(width: 1200, height: 1200)
    }

    private func cacheArtworkURL(
        _ url: URL,
        for song: Song,
        source: MusicKit.Song
    ) {
        artworkURLCache[song.appleMusicCatalogID ?? String(song.id)] = url
        artworkURLCache[source.id.rawValue] = url
        songCache[source.id.rawValue] = source
        SongArtworkFallbackRegistry.shared.registerResolvedArtwork(url, for: song)
    }

    private static func artworkMatchScore(
        _ candidate: MusicKit.Song,
        target: Song
    ) -> Double {
        let targetTitle = normalizedArtworkMatchText(target.name)
        let targetArtist = normalizedArtworkMatchText(target.artistName)
        let candidateTitle = normalizedArtworkMatchText(candidate.title)
        let candidateArtist = normalizedArtworkMatchText(candidate.artistName)

        let titleScore = targetTitle == candidateTitle
            ? 1.0
            : (targetTitle.contains(candidateTitle) || candidateTitle.contains(targetTitle) ? 0.82 : 0)
        let artistScore = targetArtist.isEmpty || targetArtist == candidateArtist
            ? 1.0
            : (targetArtist.contains(candidateArtist) || candidateArtist.contains(targetArtist) ? 0.76 : 0)

        let durationScore: Double = {
            guard let targetDuration = target.dt,
                  let candidateDuration = candidate.duration else {
                return 0.72
            }
            let difference = abs(Double(targetDuration) / 1_000 - candidateDuration)
            switch difference {
            case 0...3: return 1
            case 3...8: return 0.82
            case 8...15: return 0.55
            default: return 0
            }
        }()

        return titleScore * 0.58 + artistScore * 0.27 + durationScore * 0.15
    }

    private static func normalizedArtworkMatchText(_ value: String) -> String {
        value.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .joined()
    }

    private static func convert(_ source: MusicKit.Song) -> Song? {
        let catalogID = source.id.rawValue
        let numericID = Int(catalogID) ?? stableNumericID(for: catalogID)
        let artworkURL = (
            source.artwork?.url(width: 1200, height: 1200)
                ?? source.albums?.first?.artwork?.url(width: 1200, height: 1200)
        )?.absoluteString
        let durationMilliseconds = source.duration.map {
            Int(($0 * 1_000).rounded())
        }

        return Song(
            id: numericID,
            name: source.title,
            ar: [Artist(id: 0, name: source.artistName)],
            al: Album(
                id: 0,
                name: source.albumTitle ?? "",
                picUrl: artworkURL
            ),
            dt: durationMilliseconds,
            fee: 0,
            mv: 0,
            h: nil,
            m: nil,
            l: nil,
            sq: nil,
            hr: nil,
            alia: nil,
            source: .appleMusic,
            appleMusicID: catalogID,
            appleMusicISRC: source.isrc
        )
    }

    private static func convert(_ source: MusicKit.Playlist) -> Playlist? {
        let catalogID = source.id.rawValue
        let numericID = stableNumericID(for: "playlist:\(catalogID)")
        let artworkURL = source.artwork?.url(width: 1200, height: 1200)?.absoluteString
        return Playlist(
            id: numericID,
            name: source.name,
            coverImgUrl: artworkURL,
            picUrl: nil,
            trackCount: nil,
            playCount: nil,
            subscribedCount: nil,
            shareCount: nil,
            commentCount: nil,
            creator: source.curatorName.map {
                PlaylistCreator(userId: 0, nickname: $0, avatarUrl: nil)
            },
            description: source.standardDescription ?? source.shortDescription,
            tags: nil,
            source: .appleMusic,
            appleMusicID: catalogID
        )
    }

    private static func convert(
        _ source: MusicKit.Artist,
        musicSize: Int? = nil,
        albumSize: Int? = nil,
        mvSize: Int? = nil
    ) -> ArtistInfo? {
        let catalogID = source.id.rawValue
        let numericID = stableNumericID(for: "artist:\(catalogID)")
        let artworkURL = source.artwork?.url(width: 1200, height: 1200)?.absoluteString
        return ArtistInfo(
            id: numericID,
            name: source.name,
            picUrl: artworkURL,
            img1v1Url: artworkURL,
            cover: artworkURL,
            avatar: artworkURL,
            musicSize: musicSize,
            albumSize: albumSize,
            mvSize: mvSize,
            briefDesc: source.editorialNotes?.standard,
            alias: nil,
            followed: nil,
            accountId: nil,
            source: .appleMusic,
            qqMid: nil,
            appleMusicID: catalogID
        )
    }

    private static func convert(_ source: MusicKit.Album) -> AlbumInfo? {
        let catalogID = source.id.rawValue
        let numericID = stableNumericID(for: "album:\(catalogID)")
        let artworkURL = source.artwork?.url(width: 1200, height: 1200)?.absoluteString
        let publishTime = source.releaseDate.map {
            Int($0.timeIntervalSince1970 * 1_000)
        }
        let artistInfo = ArtistInfo(
            id: stableNumericID(for: "album-artist:\(source.artistName)"),
            name: source.artistName,
            picUrl: nil,
            img1v1Url: nil,
            cover: nil,
            avatar: nil,
            musicSize: nil,
            albumSize: nil,
            mvSize: nil,
            briefDesc: nil,
            alias: nil,
            followed: nil,
            accountId: nil,
            source: .appleMusic
        )

        return AlbumInfo(
            id: numericID,
            name: source.title,
            picUrl: artworkURL,
            publishTime: publishTime,
            size: source.trackCount,
            artist: artistInfo,
            artists: [Artist(id: artistInfo.id, name: source.artistName)],
            description: source.editorialNotes?.standard,
            company: source.recordLabelName,
            subType: source.isSingle == true ? "Single" : nil,
            qqAlbumMid: nil,
            source: .appleMusic,
            appleMusicID: catalogID
        )
    }

    private static func stableNumericID(for rawValue: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in rawValue.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash & UInt64(Int.max))
    }
}
