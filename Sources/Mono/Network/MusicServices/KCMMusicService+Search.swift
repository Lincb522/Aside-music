import Foundation

extension KCMMusicService {
    func searchSongs(keyword: String, page: Int, pageSize: Int) async throws -> KCMSearchPage {
        guard var components = URLComponents(string: AppConfig.API.kugouPublicSearchURL) else {
            throw KCMMusicError.invalidResponse
        }
        components.queryItems = [
                URLQueryItem(name: "keyword", value: keyword),
                URLQueryItem(name: "type", value: "song"),
                URLQueryItem(name: "page", value: String(max(1, page))),
                URLQueryItem(name: "pagesize", value: String(pageSize)),
                URLQueryItem(name: "platform", value: "WebFilter"),
                URLQueryItem(name: "userid", value: "-1"),
                URLQueryItem(name: "iscorrection", value: "1"),
                URLQueryItem(name: "privilege_filter", value: "0"),
        ]
        guard let url = components.url else { throw KCMMusicError.invalidResponse }
        let json = try await request(
            url: url,
            sendCookie: false,
            headers: [
                "Referer": "https://www.kugou.com/",
                "User-Agent": "Mozilla/5.0",
            ]
        )
        let dictionaries = Self.songDictionaries(in: json)
        let songs = dictionaries.compactMap(Self.song(from:))
        let total = Self.firstInt(in: json, keys: ["total", "total_count", "totalCount"])
        return KCMSearchPage(
            songs: songs,
            total: total,
            hasMore: total.map { max(1, page) * pageSize < $0 } ?? (songs.count >= pageSize)
        )
    }

    func searchArtists(keyword: String, page: Int, pageSize: Int) async throws -> KCMArtistSearchPage {
        let json = try await searchCatalog(keyword: keyword, type: "author", page: page, pageSize: pageSize)
        let items = Self.catalogItems(in: json)
        let artists = items.compactMap(Self.artist(from:))
        let total = Self.catalogTotal(in: json) ?? artists.count
        return KCMArtistSearchPage(
            artists: artists,
            total: total,
            hasMore: Self.catalogHasMore(in: json, page: page, pageSize: pageSize, itemCount: artists.count, total: total)
        )
    }

    func fetchArtists(type: Int = 0, sex: Int = 0, pageSize: Int = 200) async throws -> KCMArtistSearchPage {
        let json = try await request(
            path: "/singer/list",
            query: [
                URLQueryItem(name: "type", value: String(type)),
                URLQueryItem(name: "sextype", value: String(sex)),
                URLQueryItem(name: "hotsize", value: String(max(1, pageSize))),
            ]
        )
        let items = Self.allDictionaryItems(in: json, matchingKey: "singer")
        let artists = items.compactMap(Self.artist(from:))
        return KCMArtistSearchPage(artists: artists, total: artists.count, hasMore: false)
    }

    func searchPlaylists(keyword: String, page: Int, pageSize: Int) async throws -> KCMPlaylistSearchPage {
        let json = try await searchCatalog(keyword: keyword, type: "special", page: page, pageSize: pageSize)
        let items = Self.catalogItems(in: json)
        let playlists = items.compactMap(Self.searchPlaylist(from:))
        let total = Self.catalogTotal(in: json) ?? playlists.count
        return KCMPlaylistSearchPage(
            playlists: playlists,
            total: total,
            hasMore: Self.catalogHasMore(in: json, page: page, pageSize: pageSize, itemCount: playlists.count, total: total)
        )
    }

    func searchAlbums(keyword: String, page: Int, pageSize: Int) async throws -> KCMAlbumSearchPage {
        let json = try await searchCatalog(keyword: keyword, type: "album", page: page, pageSize: pageSize)
        let items = Self.catalogItems(in: json)
        let albums = items.compactMap(Self.searchAlbum(from:))
        let total = Self.catalogTotal(in: json) ?? albums.count
        return KCMAlbumSearchPage(
            albums: albums,
            total: total,
            hasMore: Self.catalogHasMore(in: json, page: page, pageSize: pageSize, itemCount: albums.count, total: total)
        )
    }

    func searchMVs(keyword: String, page: Int, pageSize: Int) async throws -> KCMMVSearchPage {
        let json = try await searchCatalog(keyword: keyword, type: "mv", page: page, pageSize: pageSize)
        let items = Self.catalogItems(in: json)
        let mvs = items.compactMap(Self.mv(from:))
        let total = Self.catalogTotal(in: json) ?? mvs.count
        return KCMMVSearchPage(
            mvs: mvs,
            total: total,
            hasMore: Self.catalogHasMore(in: json, page: page, pageSize: pageSize, itemCount: mvs.count, total: total)
        )
    }

    func fetchArtistSongs(id: Int, page: Int = 1, pageSize: Int = 30) async throws -> [Song] {
        let json = try await request(
            path: "/artist/audios",
            query: [
                URLQueryItem(name: "id", value: String(id)),
                URLQueryItem(name: "page", value: String(max(1, page))),
                URLQueryItem(name: "pagesize", value: String(pageSize)),
            ]
        )
        return Self.firstDictionaryArray(in: json, keys: ["songs", "audios", "info", "list", "lists"])
            .compactMap(Self.song(from:))
    }

    func fetchArtistAlbums(id: Int, page: Int = 1, pageSize: Int = 30) async throws -> [AlbumInfo] {
        let json = try await request(
            path: "/artist/albums",
            query: [
                URLQueryItem(name: "id", value: String(id)),
                URLQueryItem(name: "page", value: String(max(1, page))),
                URLQueryItem(name: "pagesize", value: String(pageSize)),
            ]
        )
        return Self.firstDictionaryArray(in: json, keys: ["albums", "info", "list", "lists"])
            .compactMap(Self.albumInfo(from:))
    }

    func fetchAlbumSongs(id: String, page: Int = 1, pageSize: Int = 30) async throws -> [Song] {
        let json = try await request(
            path: "/album/songs",
            query: [
                URLQueryItem(name: "id", value: id),
                URLQueryItem(name: "page", value: String(max(1, page))),
                URLQueryItem(name: "pagesize", value: String(pageSize)),
            ]
        )
        return Self.firstDictionaryArray(in: json, keys: ["songs", "info", "list", "lists"])
            .compactMap(Self.song(from:))
    }

    func fetchMVURL(hash: String, videoID: Int? = nil) async throws -> URL {
        if let videoID {
            let detail = try? await request(
                path: "/video/detail",
                query: [URLQueryItem(name: "id", value: String(videoID))]
            )
            let payload = (detail?["data"] as? [[String: Any]])?.first
            let mp4Hashes = ["hd_hash", "qhd_hash", "sd_hash", "ld_hash"].compactMap {
                Self.string(payload?[$0])
            }
            for candidate in mp4Hashes where !candidate.isEmpty {
                if let url = try? await fetchMVURL(hash: candidate, videoID: nil) {
                    return url
                }
            }
        }
        let json = try await request(
            path: "/video/url",
            query: [URLQueryItem(name: "hash", value: hash)]
        )
        guard let value = Self.firstURLString(in: json),
              let url = URL(string: Self.secureURL(value)) else {
            throw KCMMusicError.unavailable
        }
        return url
    }

    func searchCatalog(
        keyword: String,
        type: String,
        page: Int,
        pageSize: Int
    ) async throws -> [String: Any] {
        try await request(
            path: "/search",
            query: [
                URLQueryItem(name: "keywords", value: keyword),
                URLQueryItem(name: "type", value: type),
                URLQueryItem(name: "page", value: String(max(1, page))),
                URLQueryItem(name: "pagesize", value: String(max(1, pageSize))),
            ]
        )
    }

}
