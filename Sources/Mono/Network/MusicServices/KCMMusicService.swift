import Foundation

struct KCMSearchPage {
    let songs: [Song]
    let total: Int?
    let hasMore: Bool
}

struct KCMPlaylistPage {
    let playlists: [Playlist]
    let hasMore: Bool
}

struct KCMArtistSearchPage {
    let artists: [ArtistInfo]
    let total: Int
    let hasMore: Bool
}

struct KCMPlaylistSearchPage {
    let playlists: [Playlist]
    let total: Int
    let hasMore: Bool
}

struct KCMAlbumSearchPage {
    let albums: [SearchAlbum]
    let total: Int
    let hasMore: Bool
}

struct KCMMVSearchPage {
    let mvs: [KCMMV]
    let total: Int
    let hasMore: Bool
}

struct KCMPlaylistCategory: Identifiable, Hashable {
    let id: Int
    let name: String
    let groupName: String?
}

struct KCMQRCodeSession: Sendable {
    let key: String
    let imageData: Data
}

enum KCMQRCodeStatus: Sendable {
    case expired
    case waiting
    case scanned
    case confirmed
}

struct KCMAccountProfile: Sendable {
    let userID: Int
    let nickname: String?
    let avatarURL: URL?
    let membershipLevel: KCMMembershipLevel
    let membershipExpiration: Date?
    let conceptProductType: String?

    var isVIP: Bool { membershipLevel != .none }
}

struct KCMSongQualityInfo: Identifiable, Sendable {
    let quality: SoundQuality
    let code: String
    let bitrate: Int
    let size: Int
    let isAvailable: Bool

    var id: String { code }

    var sizeText: String {
        guard size > 0 else { return "" }
        if size >= 1_048_576 {
            return String(format: "%.1f MB", Double(size) / 1_048_576)
        }
        if size >= 1_024 {
            return String(format: "%.0f KB", Double(size) / 1_024)
        }
        return "\(size) B"
    }
}

struct KCMPlaybackURLResult: Sendable {
    let url: URL
    let quality: SoundQuality
}

enum KCMDailyVIPClaimResult: Sendable {
    case claimed
    case alreadyClaimed
}

enum KCMMusicError: LocalizedError {
    case authenticationRequired
    case verificationRequired
    case invalidResponse
    case server(Int, String)
    case unavailable

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "需要登录 KCM"
        case .verificationRequired:
            return "KCM 需要完成验证"
        case .invalidResponse:
            return "KCM 返回了无效响应"
        case .server(let code, let message):
            return message.isEmpty ? "KCM 服务错误 \(code)" : message
        case .unavailable:
            return "KCM 暂不可用"
        }
    }
}

final class KCMMusicService: @unchecked Sendable {
    static let shared = KCMMusicService()

    private let session: URLSession
    private let cookieKey = "mono_kugou_cookie"
    private let membershipLevelKey = "mono_kcm_membership_level"
    private let membershipUserIDKey = "mono_kcm_membership_user_id"

    init(session: URLSession = .shared) {
        self.session = session
    }

    private var baseURL: URL {
        URL(string: AppConfig.API.kugouBaseURL)!
    }

    private var serviceEndpoints: [(line: ServerLine, url: URL)] {
        var lines = [ServerLineManager.currentLine]
        if !lines.contains(.primary) {
            lines.append(.primary)
        }
        if ServerLineManager.isFirstBackupConfigured, !lines.contains(.backup) {
            lines.append(.backup)
        }
        if ServerLineManager.isSecondBackupConfigured, !lines.contains(.backup2) {
            lines.append(.backup2)
        }
        return lines.compactMap { line in
            URL(string: SecureConfig.kugouBaseURL(for: line)).map { (line, $0) }
        }
    }

    var currentCookie: String? {
        let value = KeychainHelper.loadString(key: cookieKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    var isAuthenticated: Bool {
        guard let cookie = currentCookie else { return false }
        let values = Self.cookieValues(in: cookie)
        guard let token = values["token"], !token.isEmpty,
              let userID = values["userid"], userID != "0", !userID.isEmpty else {
            return false
        }
        return true
    }

    var currentUserID: Int? {
        guard let cookie = currentCookie else { return nil }
        return Self.cookieValues(in: cookie)["userid"].flatMap(Int.init)
    }

    var currentMembershipLevel: KCMMembershipLevel? {
        guard let userID = currentUserID,
              UserDefaults.standard.integer(forKey: membershipUserIDKey) == userID,
              let rawValue = UserDefaults.standard.string(forKey: membershipLevelKey) else {
            return nil
        }
        return KCMMembershipLevel(rawValue: rawValue)
    }

    func applyCookie(_ cookie: String) {
        let previousUserID = currentUserID
        let ignoredAttributes = Set(["path", "domain", "expires", "max-age", "samesite", "secure", "httponly"])
        let normalized = cookie
            .replacingOccurrences(of: "Set-Cookie:", with: "", options: .caseInsensitive)
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { component in
                guard !component.isEmpty else { return false }
                let name = component.split(separator: "=", maxSplits: 1).first?.lowercased() ?? ""
                return !ignoredAttributes.contains(name)
            }
            .joined(separator: "; ")
        guard !normalized.isEmpty else {
            logout()
            return
        }
        let nextUserID = Self.cookieValues(in: normalized)["userid"].flatMap(Int.init)
        if previousUserID != nextUserID {
            clearMembershipCache()
        }
        KeychainHelper.save(key: cookieKey, value: normalized)
    }

    func logout() {
        KeychainHelper.delete(key: cookieKey)
        clearMembershipCache()
        HTTPCookieStorage.shared.cookies(for: baseURL)?.forEach {
            HTTPCookieStorage.shared.deleteCookie($0)
        }
    }

    func createQRCode() async throws -> KCMQRCodeSession {
        let (keyResponse, _) = try await loginRequest(path: "/login/qr/key")
        let keyData = keyResponse["data"] as? [String: Any] ?? [:]
        guard let key = Self.string(keyData["qrcode"]), !key.isEmpty else {
            throw KCMMusicError.invalidResponse
        }

        if let encodedImage = Self.string(keyData["qrcode_img"]),
           let imageData = Self.decodeBase64Image(encodedImage) {
            return KCMQRCodeSession(key: key, imageData: imageData)
        }

        let (createResponse, _) = try await loginRequest(
            path: "/login/qr/create",
            query: [
                URLQueryItem(name: "key", value: key),
                URLQueryItem(name: "qrimg", value: "1"),
            ]
        )
        let createData = createResponse["data"] as? [String: Any] ?? [:]
        guard let encodedImage = Self.string(createData["base64"]),
              let imageData = Self.decodeBase64Image(encodedImage) else {
            throw KCMMusicError.invalidResponse
        }
        return KCMQRCodeSession(key: key, imageData: imageData)
    }

    func checkQRCode(key: String) async throws -> KCMQRCodeStatus {
        let (json, responseURL) = try await loginRequest(
            path: "/login/qr/check",
            query: [URLQueryItem(name: "key", value: key)]
        )
        let data = json["data"] as? [String: Any] ?? [:]
        guard let status = Self.int(data["status"]) else {
            throw KCMMusicError.invalidResponse
        }
        switch status {
        case 0:
            return .expired
        case 1:
            return .waiting
        case 2:
            return .scanned
        case 4:
            try persistAuthenticatedSession(json: json, responseURL: responseURL)
            Task { [weak self] in await self?.synchronizeCurrentAccount() }
            Task { @MainActor in KCMDailyMembershipEngine.shared.checkIfNeeded() }
            return .confirmed
        default:
            return .waiting
        }
    }

    func fetchAccountProfile() async throws -> KCMAccountProfile? {
        guard isAuthenticated, let fallbackUserID = currentUserID else { return nil }
        let timestamp = Self.requestTimestamp
        let cacheBuster = [URLQueryItem(name: "timestamp", value: timestamp)]
        async let detailRequest = request(path: "/user/detail", query: cacheBuster)
        async let vipRequest = request(path: "/user/vip/detail", query: cacheBuster)
        let detail = try await detailRequest
        let vip = (try? await vipRequest) ?? [:]
        let userID = Self.firstInt(in: detail, keys: ["userid", "user_id", "id"]) ?? fallbackUserID
        let nickname = Self.firstString(in: detail, keys: ["nickname", "nick_name", "username", "user_name"])
        let avatarString = Self.firstString(
            in: detail,
            keys: ["pic", "k_pic", "avatar", "avatar_url", "headimg", "user_image"]
        )
        let membership = Self.membershipSummary(detail: detail, vip: vip)
        cacheMembershipLevel(membership.level, userID: userID)
        return KCMAccountProfile(
            userID: userID,
            nickname: nickname,
            avatarURL: avatarString.flatMap {
                URL(string: Self.secureURL($0.replacingOccurrences(of: "{size}", with: "240")))
            },
            membershipLevel: membership.level,
            membershipExpiration: membership.expiration,
            conceptProductType: membership.productType
        )
    }

    func synchronizeCurrentAccount(profile: KCMAccountProfile? = nil) async {
        guard let cookie = currentCookie else { return }
        do {
            let resolvedProfile: KCMAccountProfile?
            if let profile {
                resolvedProfile = profile
            } else {
                resolvedProfile = try await fetchAccountProfile()
            }
            guard let resolvedProfile else { return }
            _ = try await APIService.shared.saveKCMAccount(cookie: cookie, profile: resolvedProfile)
        } catch {
            AppLogger.warning("KCM 账号同步失败: \(error)")
        }
    }

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

    private func searchCatalog(
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

    func fetchPlaylistCategories() async throws -> [KCMPlaylistCategory] {
        let json = try await request(path: "/playlist/tags")
        guard let groups = json["data"] as? [[String: Any]] else { return [] }
        var result = [KCMPlaylistCategory(id: 0, name: "推荐", groupName: nil)]
        for group in groups {
            let groupName = Self.string(group["tag_name"])
            let children = group["son"] as? [[String: Any]] ?? []
            result.append(contentsOf: children.compactMap { item in
                guard let id = Self.int(item["tag_id"]),
                      let name = Self.string(item["tag_name"]), !name.isEmpty else { return nil }
                return KCMPlaylistCategory(id: id, name: name, groupName: groupName)
            })
        }
        return result
    }

    func fetchPlaylists(categoryID: Int, page: Int, pageSize: Int) async throws -> KCMPlaylistPage {
        let json = try await request(
            path: "/top/playlist",
            query: [
                URLQueryItem(name: "category_id", value: String(categoryID)),
                URLQueryItem(name: "page", value: String(max(1, page))),
                URLQueryItem(name: "pagesize", value: String(pageSize)),
                URLQueryItem(name: "withsong", value: "0"),
                URLQueryItem(name: "withtag", value: "1"),
            ]
        )
        let data = json["data"] as? [String: Any] ?? [:]
        let items = data["special_list"] as? [[String: Any]] ?? []
        let playlists = items.compactMap(Self.playlist(from:))
        let explicit = Self.bool(data["has_next"])
        return KCMPlaylistPage(playlists: playlists, hasMore: explicit ?? (playlists.count >= pageSize))
    }

    func fetchUserPlaylists() async throws -> [Playlist] {
        guard isAuthenticated else { throw KCMMusicError.authenticationRequired }
        let json = try await request(path: "/user/playlist")
        let data = json["data"] as? [String: Any] ?? json
        let items = Self.firstDictionaryArray(in: data, keys: ["info", "list", "lists", "playlist", "playlists"])
        return items.compactMap(Self.userPlaylist(from:))
    }

    func fetchRecommendedPlaylists(limit: Int = 12) async throws -> [Playlist] {
        let page = try await fetchPlaylists(categoryID: 0, page: 1, pageSize: max(1, limit))
        return Array(page.playlists.prefix(max(1, limit)))
    }

    func fetchTopLists() async throws -> [TopList] {
        let json = try await request(path: "/rank/list")
        let data = json["data"] as? [String: Any] ?? json
        let items = Self.firstDictionaryArray(in: data, keys: ["info", "list", "rank_list", "items"])
        return items.compactMap { item in
            guard let rankID = Self.int(item["rankid"]),
                  let name = Self.string(item["rankname"]), !name.isEmpty else { return nil }
            let rankCID = Self.int(item["rank_cid"]) ?? 0
            let cover = (Self.string(item["imgurl"]) ?? Self.string(item["banner7url"]))
                .map { Self.secureURL($0.replacingOccurrences(of: "{size}", with: "800")) }
            return TopList(
                id: Self.stableID("rank:\(rankID):\(rankCID)"),
                name: name,
                coverImgUrl: cover,
                updateFrequency: Self.string(item["update_frequency"]) ?? "",
                source: .kugou,
                kugouID: "rank:\(rankID):\(rankCID)"
            )
        }
    }

    func fetchPlaylistSongs(globalID: String, page: Int, pageSize: Int) async throws -> [Song] {
        if globalID.hasPrefix("user:") {
            let listID = String(globalID.dropFirst("user:".count))
            let json = try await request(
                path: "/playlist/track/all/new",
                query: [
                    URLQueryItem(name: "listid", value: listID),
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "pagesize", value: String(pageSize)),
                ]
            )
            return Self.firstDictionaryArray(in: json, keys: ["songlist", "songs", "info", "list"])
                .compactMap(Self.song(from:))
        }
        if globalID.hasPrefix("rank:") {
            let components = globalID.split(separator: ":")
            guard components.count >= 2 else { throw KCMMusicError.invalidResponse }
            let json = try await request(
                path: "/rank/audio",
                query: [
                    URLQueryItem(name: "rankid", value: String(components[1])),
                    URLQueryItem(name: "rank_cid", value: components.count > 2 ? String(components[2]) : nil),
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "pagesize", value: String(pageSize)),
                ]
            )
            return Self.firstDictionaryArray(in: json, keys: ["songlist", "songs", "info", "list"])
                .compactMap(Self.song(from:))
        }
        let json = try await request(
            path: "/playlist/track/all",
            query: [
                URLQueryItem(name: "id", value: globalID),
                URLQueryItem(name: "page", value: String(max(1, page))),
                URLQueryItem(name: "pagesize", value: String(pageSize)),
            ]
        )
        let data = json["data"] as? [String: Any] ?? [:]
        let items = data["songs"] as? [[String: Any]] ?? []
        return items.compactMap(Self.song(from:))
    }

    func fetchSongURL(song: Song, quality: SoundQuality = .exhigh) async throws -> KCMPlaybackURLResult {
        guard song.kugouHash?.isEmpty == false else { throw KCMMusicError.unavailable }
        let membershipLevel = isAuthenticated
            ? await resolvedCurrentMembershipLevel()
            : KCMMembershipLevel.none
        let preferredUserID = membershipLevel != KCMMembershipLevel.none ? currentUserID : nil
        let excludedUserID = isAuthenticated && membershipLevel == KCMMembershipLevel.none
            ? currentUserID
            : nil

        var seenCodes = Set<String>()
        let qualityCodes = SoundQuality.fallbackCandidates(from: quality).compactMap { candidate in
            let code = Self.kcmQualityCode(for: candidate)
            return seenCodes.insert(code).inserted ? code : nil
        }
        if let result = try await APIService.shared.fetchKCMAccountPoolSongURL(
            song: song,
            qualityCodes: qualityCodes,
            excludeUserID: excludedUserID,
            preferredUserID: preferredUserID
        ) {
            return KCMPlaybackURLResult(
                url: result.url,
                quality: Self.soundQuality(forKCMCode: result.qualityCode) ?? quality
            )
        }
        throw KCMMusicError.unavailable
    }

    private func fetchSongURLUsingCurrentAccount(
        song: Song,
        quality: SoundQuality
    ) async throws -> KCMPlaybackURLResult {
        guard isAuthenticated else { throw KCMMusicError.authenticationRequired }
        guard let hash = song.kugouHash, !hash.isEmpty else { throw KCMMusicError.unavailable }
        var seenCodes = Set<String>()
        let candidates = SoundQuality.fallbackCandidates(from: quality).filter {
            seenCodes.insert(Self.kcmQualityCode(for: $0)).inserted
        }
        var lastError: Error = KCMMusicError.unavailable
        for candidate in candidates {
            do {
                let json = try await request(
                    path: "/song/url",
                    query: [
                        URLQueryItem(name: "hash", value: hash),
                        URLQueryItem(name: "album_id", value: String(song.kugouAlbumID ?? 0)),
                        URLQueryItem(name: "album_audio_id", value: String(song.kugouAlbumAudioID ?? 0)),
                        URLQueryItem(name: "quality", value: Self.kcmQualityCode(for: candidate)),
                    ]
                )
                if let value = Self.firstURLString(in: json),
                   let url = URL(string: Self.secureURL(value)) {
                    return KCMPlaybackURLResult(url: url, quality: candidate)
                }
            } catch KCMMusicError.authenticationRequired {
                throw KCMMusicError.authenticationRequired
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func resolvedCurrentMembershipLevel() async -> KCMMembershipLevel {
        if let currentMembershipLevel { return currentMembershipLevel }
        return (try? await fetchAccountProfile())?.membershipLevel ?? KCMMembershipLevel.none
    }

    private func cacheMembershipLevel(_ level: KCMMembershipLevel, userID: Int) {
        UserDefaults.standard.set(level.rawValue, forKey: membershipLevelKey)
        UserDefaults.standard.set(userID, forKey: membershipUserIDKey)
    }

    private func clearMembershipCache() {
        UserDefaults.standard.removeObject(forKey: membershipLevelKey)
        UserDefaults.standard.removeObject(forKey: membershipUserIDKey)
    }

    func fetchSongPlatformDetail(song: Song) async throws -> PlatformSongDetail {
        var payloads: [[String: Any]] = []
        var lastError: Error?

        if let audioID = song.kugouAlbumAudioID, audioID > 0 {
            do {
                payloads.append(
                    try await request(
                        path: "/krm/audio",
                        query: [
                            URLQueryItem(name: "album_audio_id", value: String(audioID)),
                            URLQueryItem(
                                name: "fields",
                                value: "album_info,base,authors.base,extra,tags,tagmap"
                            ),
                        ]
                    )
                )
            } catch {
                lastError = error
            }
        }

        if let albumID = song.kugouAlbumID, albumID > 0 {
            do {
                payloads.append(
                    try await request(
                        path: "/album",
                        query: [
                            URLQueryItem(name: "album_id", value: String(albumID)),
                            URLQueryItem(
                                name: "fields",
                                value: "intro,publish_company,language,category,publish_date,authors,author_name"
                            ),
                        ]
                    )
                )
            } catch {
                lastError = error
            }
        }

        guard !payloads.isEmpty else {
            if song.kugouAlbumAudioID == nil, song.kugouAlbumID == nil {
                return .empty
            }
            throw lastError ?? KCMMusicError.unavailable
        }

        let introductions = payloads.flatMap {
            Self.readablePlatformTexts(
                in: $0,
                keys: ["intro", "introduction", "description", "desc", "full_intro", "mix_intro"],
                maximumLength: 12_000
            )
        }
        let introduction = introductions
            .filter { $0.count >= 12 }
            .max { lhs, rhs in lhs.count < rhs.count }
        let releaseDate = payloads.compactMap {
            Self.readablePlatformTexts(
                in: $0,
                keys: ["publish_date", "release_date", "publish_time"],
                maximumLength: 80
            ).first
        }.first
        let authorNames = payloads.flatMap {
            Self.readablePlatformTexts(
                in: $0,
                keys: ["author_name", "authors", "singername", "singer_name"],
                maximumLength: 120
            )
        }
        .reduce(into: [String]()) { result, value in
            if !result.contains(value), value != song.artistName { result.append(value) }
        }
        let tags = payloads.flatMap {
            Self.readablePlatformTexts(
                in: $0,
                keys: ["tags", "tag_name", "tagmap", "category"],
                maximumLength: 60
            )
        }
        .reduce(into: [String]()) { result, value in
            if !result.contains(value) { result.append(value) }
        }

        var sections: [PlatformSongSection] = []
        if let introduction {
            sections.append(
                PlatformSongSection(
                    id: "kcm-introduction",
                    title: String(localized: "song_detail_introduction"),
                    body: introduction
                )
            )
        }
        if !authorNames.isEmpty {
            sections.append(
                PlatformSongSection(
                    id: "kcm-credits",
                    title: String(localized: "song_detail_credits"),
                    body: authorNames.joined(separator: "、")
                )
            )
        }
        if !tags.isEmpty {
            sections.append(
                PlatformSongSection(
                    id: "kcm-tags",
                    title: String(localized: "song_detail_tags"),
                    body: tags.joined(separator: " · ")
                )
            )
        }
        return PlatformSongDetail(
            releaseDate: releaseDate,
            attributes: [],
            sections: sections
        )
    }

    private static func readablePlatformTexts(
        in value: Any,
        keys: Set<String>,
        maximumLength: Int
    ) -> [String] {
        var result: [String] = []

        func collect(_ value: Any, acceptsScalar: Bool) {
            if let text = value as? String {
                guard acceptsScalar,
                      let normalized = normalizedPlatformText(text),
                      normalized.count <= maximumLength else { return }
                result.append(normalized)
                return
            }
            if let dictionary = value as? [String: Any] {
                for (key, child) in dictionary {
                    collect(child, acceptsScalar: acceptsScalar || keys.contains(key.lowercased()))
                }
                return
            }
            if let array = value as? [Any] {
                array.forEach { collect($0, acceptsScalar: acceptsScalar) }
            }
        }

        collect(value, acceptsScalar: false)
        return result
    }

    private static func normalizedPlatformText(_ value: String) -> String? {
        var text = value
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
        text = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        guard !text.isEmpty,
              text.range(of: #"^https?://"#, options: .regularExpression) == nil,
              text.range(of: #"^\d+$"#, options: .regularExpression) == nil else {
            return nil
        }
        return text
    }

    func fetchSongQualities(song: Song) async throws -> [KCMSongQualityInfo] {
        guard let hash = song.kugouHash, !hash.isEmpty else { throw KCMMusicError.unavailable }
        let json = try await request(
            path: "/privilege/lite",
            method: "POST",
            query: [
                URLQueryItem(name: "hash", value: hash),
                URLQueryItem(name: "album_id", value: String(song.kugouAlbumID ?? 0)),
            ]
        )
        let goods = ["relate_goods", "goods", "qualities"]
            .flatMap { Self.allDictionaryItems(in: json, matchingKey: $0) }
        var seen = Set<SoundQuality>()
        let parsed = goods.compactMap { item -> KCMSongQualityInfo? in
            let code = Self.string(item["quality"])
                ?? Self.string(item["quality_type"])
                ?? Self.string(item["level"])
            guard let code,
                  let quality = Self.soundQuality(forKCMCode: code),
                  seen.insert(quality).inserted else { return nil }
            let info = item["info"] as? [String: Any]
            let hash = Self.string(item["hash"])
            let published = Self.int(item["is_publish"])
                ?? Self.int(item["publish"])
                ?? 1
            let rawBitrate = Self.int(info?["bitrate"])
                ?? Self.int(item["bitrate"])
                ?? Self.int(item["bit_rate"])
                ?? 0
            let bitrate = rawBitrate > 0 && rawBitrate < 10_000
                ? rawBitrate * 1_000
                : rawBitrate
            return KCMSongQualityInfo(
                quality: quality,
                code: Self.kcmQualityCode(for: quality),
                bitrate: bitrate,
                size: Self.int(info?["filesize"])
                    ?? Self.int(item["filesize"])
                    ?? Self.int(item["file_size"])
                    ?? 0,
                isAvailable: hash?.isEmpty == false && published != 0
            )
        }
        if !parsed.isEmpty {
            var combined = Dictionary(uniqueKeysWithValues: parsed.map { ($0.quality, $0) })
            for info in Self.qualitiesReported(by: song) where combined[info.quality] == nil {
                combined[info.quality] = info
            }
            return Self.kcmQualityOrder.compactMap { combined[$0] }
        }
        return Self.qualitiesReported(by: song)
    }

    func fetchSongComments(
        mixSongID: String,
        page: Int,
        pageSize: Int
    ) async throws -> PlatformCommentPage {
        let json = try await request(
            path: "/comment/music",
            query: [
                URLQueryItem(name: "mixsongid", value: mixSongID),
                URLQueryItem(name: "page", value: String(max(1, page))),
                URLQueryItem(name: "pagesize", value: String(max(1, pageSize))),
                URLQueryItem(name: "show_classify", value: "0"),
                URLQueryItem(name: "show_hotword_list", value: "0"),
            ]
        )
        let items = Self.firstDictionaryArray(in: json, keys: ["list", "lists", "comments", "items"])
        let comments = items.compactMap(Self.comment(from:))
        let total = Self.firstInt(in: json, keys: ["combine_count", "count", "total", "total_count"])
            ?? comments.count
        let explicitMore = Self.firstInt(in: json, keys: ["has_more", "hasMore", "more"])
            .map { $0 != 0 }
        return PlatformCommentPage(
            comments: comments,
            totalCount: total,
            hasMore: explicitMore ?? (comments.count >= pageSize && page * pageSize < total),
            cursor: ""
        )
    }

    func fetchLyrics(song: Song) async throws -> String {
        guard let hash = song.kugouHash, !hash.isEmpty else { throw KCMMusicError.unavailable }
        let search = try await request(
            path: "/search/lyric",
            query: [
                URLQueryItem(name: "hash", value: hash),
                URLQueryItem(name: "album_audio_id", value: String(song.kugouAlbumAudioID ?? 0)),
                URLQueryItem(name: "duration", value: String(song.dt ?? 0)),
                URLQueryItem(name: "man", value: "no"),
            ]
        )
        guard let candidates = search["candidates"] as? [[String: Any]],
              let candidate = candidates.first,
              let id = Self.string(candidate["id"]),
              let accessKey = Self.string(candidate["accesskey"]) else {
            throw KCMMusicError.unavailable
        }
        let lyric = try await request(
            path: "/lyric",
            query: [
                URLQueryItem(name: "id", value: id),
                URLQueryItem(name: "accesskey", value: accessKey),
                URLQueryItem(name: "fmt", value: "lrc"),
                URLQueryItem(name: "decode", value: "true"),
            ]
        )
        guard let content = Self.string(lyric["decodeContent"]), !content.isEmpty else {
            throw KCMMusicError.unavailable
        }
        return content
    }

    private static func comment(from item: [String: Any]) -> Comment? {
        guard let content = firstString(in: item, keys: ["content", "text"]), !content.isEmpty else {
            return nil
        }
        let rawCommentID = firstString(in: item, keys: ["id", "comment_id", "tid"])
            ?? "kcm:\(content)"
        let rawUserID = firstString(in: item, keys: ["user_id", "userid", "uid"])
            ?? "kcm:anonymous"
        let like = item["like"] as? [String: Any]
        let timestamp = commentTimestamp(
            firstString(in: item, keys: ["addtime", "create_time", "time"])
        )
        return Comment(
            commentId: APIService.stableCommentID(rawCommentID),
            content: content,
            time: timestamp,
            likedCount: firstInt(in: like ?? [:], keys: ["count", "likenum", "like_count"])
                ?? firstInt(in: item, keys: ["like_count", "liked_count"])
                ?? 0,
            liked: firstInt(in: like ?? [:], keys: ["haslike", "liked", "is_liked"]).map { $0 != 0 }
                ?? false,
            user: CommentUser(
                userId: APIService.stableCommentID(rawUserID),
                nickname: firstString(in: item, keys: ["user_name", "nickname", "username"])
                    ?? String(localized: "匿名用户"),
                avatarUrl: firstString(in: item, keys: ["user_pic", "avatar", "avatar_url"]).map(secureURL),
                vipType: firstInt(in: item, keys: ["vip_type", "vip_user_type"])
            ),
            beReplied: nil,
            ipLocation: IPLocation(location: firstString(in: item, keys: ["location", "city"])),
            timeStr: nil,
            parentCommentId: nil
        )
    }

    private static func commentTimestamp(_ rawValue: String?) -> Int {
        guard let rawValue, !rawValue.isEmpty else {
            return Int(Date().timeIntervalSince1970 * 1_000)
        }
        if let value = Int(rawValue) {
            return value > 10_000_000_000 ? value : value * 1_000
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: rawValue)
            .map { Int($0.timeIntervalSince1970 * 1_000) }
            ?? Int(Date().timeIntervalSince1970 * 1_000)
    }

    func claimDailyLiteVIP(date: Date = Date()) async throws -> KCMDailyVIPClaimResult {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        do {
            let json = try await request(
                path: "/youth/day/vip",
                method: "POST",
                query: [
                    URLQueryItem(name: "receive_day", value: formatter.string(from: date)),
                    URLQueryItem(name: "timestamp", value: Self.requestTimestamp),
                ]
            )
            guard Self.isSuccess(json) else { throw KCMMusicError.unavailable }
            Task { [weak self] in await self?.synchronizeCurrentAccount() }
            return .claimed
        } catch KCMMusicError.server(let code, _) where code == 131001 {
            return .alreadyClaimed
        }
    }

    func upgradeDailyLiteVIP() async throws -> Bool {
        let succeeded = Self.isSuccess(
            try await request(
                path: "/youth/day/vip/upgrade",
                method: "POST",
                query: [URLQueryItem(name: "timestamp", value: Self.requestTimestamp)]
            )
        )
        if succeeded { Task { [weak self] in await self?.synchronizeCurrentAccount() } }
        return succeeded
    }

    private func request(
        path: String,
        method: String = "GET",
        query: [URLQueryItem] = []
    ) async throws -> [String: Any] {
        var lastError: Error = KCMMusicError.invalidResponse
        let endpoints = serviceEndpoints
        for (index, endpoint) in endpoints.enumerated() {
            guard var components = URLComponents(
                url: endpoint.url.appendingPathComponent(path),
                resolvingAgainstBaseURL: false
            ) else {
                continue
            }
            components.queryItems = query.isEmpty ? nil : query
            guard let url = components.url else { continue }
            do {
                return try await request(url: url, method: method)
            } catch {
                lastError = error
                guard Self.shouldTryNextServiceEndpoint(after: error),
                      index < endpoints.index(before: endpoints.endIndex) else {
                    throw error
                }
                AppLogger.warning(
                    "[KCM] \(endpoint.line.rawValue) endpoint unavailable, trying \(endpoints[index + 1].line.rawValue)"
                )
            }
        }
        throw lastError
    }

    private func loginRequest(
        path: String,
        query: [URLQueryItem] = []
    ) async throws -> ([String: Any], URL) {
        var lastError: Error = KCMMusicError.invalidResponse
        let endpoints = serviceEndpoints
        for (index, endpoint) in endpoints.enumerated() {
            guard var components = URLComponents(
                url: endpoint.url.appendingPathComponent(path),
                resolvingAgainstBaseURL: false
            ) else {
                continue
            }
            var items = query
            items.append(URLQueryItem(name: "timestamp", value: String(Int(Date().timeIntervalSince1970 * 1_000))))
            components.queryItems = items
            guard let url = components.url else { continue }

            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("no-store, no-cache, max-age=0", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")
            applyApplicationAuthorization(to: &request)
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      !data.isEmpty,
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw KCMMusicError.invalidResponse
                }
                try Self.validate(json: json, statusCode: http.statusCode)
                return (json, url)
            } catch {
                lastError = error
                guard Self.shouldTryNextServiceEndpoint(after: error),
                      index < endpoints.index(before: endpoints.endIndex) else {
                    throw error
                }
                AppLogger.warning(
                    "[KCM] \(endpoint.line.rawValue) login endpoint unavailable, trying \(endpoints[index + 1].line.rawValue)"
                )
            }
        }
        throw lastError
    }

    private static func shouldTryNextServiceEndpoint(after error: Error) -> Bool {
        if error is URLError { return true }
        guard let error = error as? KCMMusicError else { return false }
        switch error {
        case .invalidResponse:
            return true
        case .server(let code, _):
            return code >= 500
        case .authenticationRequired, .verificationRequired, .unavailable:
            return false
        }
    }

    private func persistAuthenticatedSession(json: [String: Any], responseURL: URL) throws {
        let data = json["data"] as? [String: Any] ?? [:]
        var values: [String: String] = [:]
        for cookie in HTTPCookieStorage.shared.cookies(for: responseURL) ?? [] {
            values[cookie.name] = cookie.value
        }
        if let token = Self.string(data["token"]), !token.isEmpty {
            values["token"] = token
        }
        if let userID = Self.string(data["userid"]), !userID.isEmpty {
            values["userid"] = userID
        }
        var normalizedValues: [String: String] = [:]
        for (name, value) in values {
            normalizedValues[name.lowercased()] = value
        }
        guard let token = normalizedValues["token"], !token.isEmpty,
              let userID = normalizedValues["userid"], userID != "0", !userID.isEmpty else {
            throw KCMMusicError.authenticationRequired
        }
        let header = values
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "; ")
        KeychainHelper.save(key: cookieKey, value: header)
    }

    private func request(
        url: URL,
        method: String = "GET",
        sendCookie: Bool = true,
        headers: [String: String] = [:]
    ) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyApplicationAuthorization(to: &request)
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        if sendCookie, let cookie = currentCookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw KCMMusicError.invalidResponse }
        if sendCookie { persistResponseCookies(for: url) }
        guard !data.isEmpty,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KCMMusicError.invalidResponse
        }
        try Self.validate(json: json, statusCode: http.statusCode)
        return json
    }

    private func applyApplicationAuthorization(to request: inout URLRequest) {
        guard let token = SecureConfig.apiToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else { return }
        request.setValue(token, forHTTPHeaderField: "X-Api-Token")
        request.setValue(DeviceIdentifier.uuid, forHTTPHeaderField: "X-Device-ID")
    }

    private func persistResponseCookies(for url: URL) {
        guard let cookies = HTTPCookieStorage.shared.cookies(for: url), !cookies.isEmpty else { return }
        let header = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"]
        guard let header, !header.isEmpty else { return }
        let values = Self.cookieValues(in: header)
        guard values["token"]?.isEmpty == false,
              let userID = values["userid"], userID != "0", !userID.isEmpty else { return }
        KeychainHelper.save(key: cookieKey, value: header)
    }

    private static func validate(json: [String: Any], statusCode: Int) throws {
        let code = int(json["error_code"]) ?? int(json["errcode"]) ?? int(json["code"])
        if code == 152 { throw KCMMusicError.authenticationRequired }
        if code == 20028 { throw KCMMusicError.verificationRequired }
        if let code, code != 0 && code != 1 && code != 200 {
            let message = string(json["error_msg"]) ?? string(json["error"]) ?? string(json["errmsg"]) ?? string(json["message"]) ?? ""
            throw KCMMusicError.server(code, message)
        }
        guard (200..<300).contains(statusCode) else {
            let message = string(json["error_msg"]) ?? string(json["error"]) ?? string(json["message"]) ?? ""
            throw KCMMusicError.server(statusCode, message)
        }
    }

    private static func songDictionaries(in json: [String: Any]) -> [[String: Any]] {
        let data = json["data"] as? [String: Any] ?? json
        for key in ["info", "songs", "lists", "items"] {
            if let items = data[key] as? [[String: Any]] { return items }
        }
        return []
    }

    private static func catalogItems(in json: [String: Any]) -> [[String: Any]] {
        let data = json["data"] as? [String: Any] ?? json
        return firstDictionaryArray(in: data, keys: ["lists", "list", "items", "info"])
    }

    private static func catalogTotal(in json: [String: Any]) -> Int? {
        let data = json["data"] as? [String: Any] ?? json
        return firstInt(in: data, keys: ["total", "count", "total_count"])
    }

    private static func catalogHasMore(
        in json: [String: Any],
        page: Int,
        pageSize: Int,
        itemCount: Int,
        total: Int
    ) -> Bool {
        let data = json["data"] as? [String: Any] ?? json
        if let explicit = firstInt(in: data, keys: ["has_more", "hasMore", "more"]) {
            return explicit != 0
        }
        return itemCount >= pageSize && page * pageSize < total
    }

    private static func artist(from item: [String: Any]) -> ArtistInfo? {
        guard let id = firstInt(in: item, keys: ["AuthorId", "author_id", "singerid", "id"]),
              let name = firstString(in: item, keys: ["AuthorName", "author_name", "singername", "name"]),
              !name.isEmpty else { return nil }
        let avatar = kugouArtworkURL(
            firstArtworkString(
                in: item,
                keys: [
                    "FirstFrameImage", "Avatar", "first_frame_image", "avatar",
                    "imgurl", "img", "cover", "image_url", "image", "pic",
                ]
            )
        )
        return ArtistInfo(
            id: id,
            name: name,
            picUrl: avatar,
            img1v1Url: avatar,
            cover: avatar,
            avatar: avatar,
            musicSize: firstInt(in: item, keys: ["AudioCount", "audio_count", "songcount"]),
            albumSize: firstInt(in: item, keys: ["AlbumCount", "album_count"]),
            mvSize: firstInt(in: item, keys: ["VideoCount", "video_count", "mv_count"]),
            briefDesc: nil,
            alias: nil,
            followed: nil,
            accountId: nil,
            source: .kugou,
            kugouID: String(id)
        )
    }

    private static func searchPlaylist(from item: [String: Any]) -> Playlist? {
        guard let platformID = string(item["gid"])
                ?? string(item["global_collection_id"])
                ?? string(item["specialid"])
                ?? string(item["id"]),
              let name = firstString(in: item, keys: ["specialname", "name", "title"]),
              !name.isEmpty else { return nil }
        let cover = kugouArtworkURL(
            firstArtworkString(
                in: item,
                keys: ["img", "flexible_cover", "cover", "imgurl", "image_url", "image", "pic"]
            )
        )
        let creatorName = firstString(in: item, keys: ["nickname", "user_name", "creator"])
        let creator = creatorName.map {
            PlaylistCreator(
                userId: stableID(firstString(in: item, keys: ["suid", "user_id"]) ?? $0),
                nickname: $0,
                avatarUrl: nil
            )
        }
        return Playlist(
            id: stableID("playlist:\(platformID)"),
            name: name,
            coverImgUrl: cover,
            picUrl: nil,
            trackCount: firstInt(in: item, keys: ["song_count", "songcount", "track_count"]),
            playCount: firstInt(in: item, keys: ["total_play_count", "play_count", "playcount"]),
            subscribedCount: firstInt(in: item, keys: ["collect_count", "collectcount"]),
            shareCount: nil,
            commentCount: nil,
            creator: creator,
            description: firstString(in: item, keys: ["intro", "description"]),
            tags: nil,
            source: .kugou,
            kugouID: platformID
        )
    }

    private static func searchAlbum(from item: [String: Any]) -> SearchAlbum? {
        guard let platformID = firstString(in: item, keys: ["albumid", "album_id", "id"]),
              let name = firstString(in: item, keys: ["albumname", "album_name", "name"]),
              !name.isEmpty else { return nil }
        let singerItems = item["singers"] as? [[String: Any]] ?? []
        let artists = singerItems.compactMap { singer -> Artist? in
            guard let name = firstString(in: singer, keys: ["name", "singername"]), !name.isEmpty else { return nil }
            return Artist(id: firstInt(in: singer, keys: ["id", "singerid"]) ?? stableID(name), name: name)
        }
        let fallbackSinger = firstString(in: item, keys: ["singer", "singername", "author_name"])
        let resolvedArtists = artists.isEmpty
            ? fallbackSinger.map { [Artist(id: stableID($0), name: $0)] }
            : artists
        let cover = kugouArtworkURL(
            firstArtworkString(
                in: item,
                keys: ["img", "sizable_cover", "cover", "album_cover", "imgurl", "image_url", "image", "pic"]
            )
        )
        return SearchAlbum(
            id: stableID("album:\(platformID)"),
            name: name,
            picUrl: cover,
            artist: resolvedArtists?.first,
            artists: resolvedArtists,
            size: firstInt(in: item, keys: ["songcount", "song_count", "size"]),
            publishTime: dateTimestamp(firstString(in: item, keys: ["publish_time", "publish_date"])),
            source: .kugou,
            qqMid: nil,
            appleMusicID: nil,
            kugouID: platformID
        )
    }

    private static func albumInfo(from item: [String: Any]) -> AlbumInfo? {
        guard let album = searchAlbum(from: item) else { return nil }
        return AlbumInfo(
            id: album.id,
            name: album.name,
            picUrl: album.picUrl,
            publishTime: album.publishTime,
            size: album.size,
            artist: album.artist.map {
                ArtistInfo(
                    id: $0.id,
                    name: $0.name,
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
                    source: .kugou,
                    kugouID: String($0.id)
                )
            },
            artists: album.artists,
            description: firstString(in: item, keys: ["intro", "description", "short_intro"]),
            company: firstString(in: item, keys: ["company", "publish_company"]),
            subType: nil,
            qqAlbumMid: nil,
            source: .kugou,
            appleMusicID: nil,
            kugouID: album.kugouID
        )
    }

    private static func mv(from item: [String: Any]) -> KCMMV? {
        guard let hash = firstString(in: item, keys: ["MvHash", "mvhash", "mv_hash", "hash"]),
              !hash.isEmpty else { return nil }
        let pic = firstArtworkString(
            in: item,
            keys: ["Pic", "pic", "cover", "img", "image_url", "image", "ThumbGif", "thumb_gif"]
        )
        let cover: String? = pic.map { raw in
            if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
                return kugouArtworkURL(raw) ?? secureURL(raw)
            }
            return "https://imge.kugou.com/mvhdpic/1000/\(raw)"
        }
        return KCMMV(
            hash: hash,
            videoID: firstInt(in: item, keys: ["MvID", "mvid", "mv_id", "video_id"]),
            name: firstString(in: item, keys: ["MvName", "mvname", "name", "FileName"])
                ?? String(localized: "mv_unknown_name"),
            artistName: firstString(in: item, keys: ["SingerName", "singername", "author_name"]),
            artistID: firstInt(in: item, keys: ["SingerID", "singerid", "author_id"]),
            coverURL: cover,
            duration: firstInt(in: item, keys: ["Duration", "duration"]),
            playCount: firstInt(in: item, keys: ["HistoryHeat", "MvHot", "play_count"]),
            publishDate: firstString(in: item, keys: ["PublishDate", "publish_date"]),
            description: firstString(in: item, keys: ["Description", "description", "Remark"])
        )
    }

    private static func dateTimestamp(_ raw: String?) -> Int? {
        guard let raw, !raw.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return Int(date.timeIntervalSince1970 * 1_000)
            }
        }
        return nil
    }

    private static func song(from item: [String: Any]) -> Song? {
        let deprecated = item["deprecated"] as? [String: Any]
        let base = item["base"] as? [String: Any]
        let audioInfo = item["audio_info"] as? [String: Any]
        let albumInfo = (item["albuminfo"] as? [String: Any]) ?? (item["album_info"] as? [String: Any])
        let transParam = item["trans_param"] as? [String: Any]
        let hash = string(item["hash"])
            ?? string(item["FileHash"])
            ?? string(item["filehash"])
            ?? string(deprecated?["hash"])
            ?? string(audioInfo?["hash_128"])
        guard let hash, !hash.isEmpty else { return nil }
        let rawName = string(item["name"])
            ?? string(item["SongName"])
            ?? string(item["songname"])
            ?? string(item["audio_name"])
            ?? string(base?["audio_name"])
            ?? ""
        let singerInfo = (item["singerinfo"] as? [[String: Any]])
            ?? (item["authors"] as? [[String: Any]])
            ?? []
        let artists: [Artist] = singerInfo.compactMap { singer in
            guard let name = string(singer["name"])
                    ?? string(singer["author_name"]),
                  !name.isEmpty else { return nil }
            return Artist(
                id: int(singer["id"])
                    ?? int(singer["author_id"])
                    ?? stableID(name),
                name: name
            )
        }
        let singerName = string(item["SingerName"])
            ?? string(item["singername"])
            ?? string(base?["author_name"])
        let fallbackArtists: [Artist] = singerName?.split(separator: "、").map {
            let value = String($0)
            return Artist(id: stableID(value), name: value)
        } ?? []
        let resolvedArtists: [Artist] = artists.isEmpty ? fallbackArtists : artists
        let titleWithoutArtist: String = {
            guard let separator = rawName.range(of: " - ") else { return rawName }
            let prefix = String(rawName[..<separator.lowerBound])
            let shouldStripPrefix = resolvedArtists.isEmpty || resolvedArtists.contains {
                prefix.localizedCaseInsensitiveContains($0.name)
            }
            return shouldStripPrefix ? String(rawName[separator.upperBound...]) : rawName
        }()
        let title = cleanedAudioTitle(titleWithoutArtist)

        let albumID = int(item["album_id"])
            ?? int(item["AlbumID"])
            ?? int(base?["album_id"])
            ?? int(albumInfo?["id"])
            ?? int(albumInfo?["album_id"])
        let albumName = string(item["AlbumName"])
            ?? string(item["album_name"])
            ?? string(base?["album_name"])
            ?? string(albumInfo?["name"])
            ?? string(albumInfo?["album_name"])
            ?? ""
        let rawCover = firstArtworkString(
            in: item,
            keys: [
                "cover", "Image", "image", "sizable_cover", "album_cover",
                "union_cover", "imgurl", "image_url", "pic",
            ]
        )
            ?? string(albumInfo?["sizable_cover"])
            ?? string(albumInfo?["cover"])
            ?? string(transParam?["union_cover"])
        let cover = kugouArtworkURL(rawCover)
        let duration = int(item["timelen"])
            ?? int(item["Duration"])
            ?? int(item["duration"])
            ?? int(audioInfo?["duration"])
        let durationMS = duration.map { $0 < 10_000 ? $0 * 1_000 : $0 }
        let audioID = int(item["mixsongid"])
            ?? int(item["MixSongID"])
            ?? int(item["album_audio_id"])
            ?? int(item["audio_id"])
            ?? int(base?["album_audio_id"])
            ?? int(base?["audio_id"])

        let standard = songQuality(
            hash: string(audioInfo?["hash_128"]) ?? hash,
            bitrate: int(audioInfo?["bitrate_128"]) ?? 128_000,
            size: int(audioInfo?["filesize_128"]) ?? int(item["FileSize"])
        )
        let high = songQuality(
            hash: string(item["HQFileHash"]) ?? string(audioInfo?["hash_320"]),
            bitrate: int(audioInfo?["bitrate_320"]) ?? 320_000,
            size: int(item["HQFileSize"]) ?? int(audioInfo?["filesize_320"])
        )
        let lossless = songQuality(
            hash: string(item["SQFileHash"]) ?? string(audioInfo?["hash_flac"]),
            bitrate: int(audioInfo?["bitrate_flac"]) ?? 900_000,
            size: int(item["SQFileSize"]) ?? int(audioInfo?["filesize_flac"])
        )
        let hires = songQuality(
            hash: string(item["ResFileHash"])
                ?? string(audioInfo?["hash_high"])
                ?? string(audioInfo?["hash_hires"]),
            bitrate: int(audioInfo?["bitrate_high"]) ?? int(audioInfo?["bitrate_hires"]) ?? 1_800_000,
            size: int(item["ResFileSize"])
                ?? int(audioInfo?["filesize_high"])
                ?? int(audioInfo?["filesize_hires"])
        )

        return Song(
            id: stableID(hash),
            name: title,
            ar: resolvedArtists.isEmpty ? nil : resolvedArtists,
            al: Album(id: albumID ?? 0, name: albumName, picUrl: cover),
            dt: durationMS,
            fee: nil,
            mv: nil,
            h: high, m: nil, l: standard, sq: lossless, hr: hires,
            alia: nil,
            source: .kugou,
            kugouHash: hash,
            kugouAlbumID: albumID,
            kugouAlbumAudioID: audioID
        )
    }

    private static func playlist(from item: [String: Any]) -> Playlist? {
        guard let globalID = string(item["global_collection_id"]), !globalID.isEmpty else { return nil }
        let name = string(item["specialname"]) ?? string(item["name"]) ?? ""
        let cover = kugouArtworkURL(
            firstArtworkString(
                in: item,
                keys: ["flexible_cover", "imgurl", "img", "cover", "image_url", "image", "pic"]
            )
        )
        let tagItems = item["tags"] as? [[String: Any]] ?? []
        let tags = tagItems.compactMap { string($0["tag_name"]) }
        let nickname = string(item["nickname"]) ?? string(item["singername"])
        let creator = nickname.map { PlaylistCreator(userId: int(item["suid"]) ?? stableID($0), nickname: $0, avatarUrl: secureOptionalURL(string(item["pic"]))) }
        return Playlist(
            id: stableID(globalID),
            name: name,
            coverImgUrl: cover,
            picUrl: nil,
            trackCount: int(item["song_count"]) ?? int(item["count"]),
            playCount: int(item["play_count"]),
            subscribedCount: int(item["collectcount"]),
            shareCount: nil,
            commentCount: nil,
            creator: creator,
            description: string(item["intro"]),
            tags: tags.isEmpty ? nil : tags,
            source: .kugou,
            kugouID: globalID
        )
    }

    private static func cleanedAudioTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathExtension = (trimmed as NSString).pathExtension.lowercased()
        let audioExtensions: Set<String> = ["mp3", "flac", "m4a", "aac", "wav", "ogg", "ape", "wma"]
        guard audioExtensions.contains(pathExtension) else { return trimmed }
        return (trimmed as NSString).deletingPathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func userPlaylist(from item: [String: Any]) -> Playlist? {
        guard let listID = string(item["listid"])
            ?? string(item["list_id"])
            ?? string(item["id"]), !listID.isEmpty else { return nil }
        let name = string(item["listname"])
            ?? string(item["specialname"])
            ?? string(item["name"])
            ?? ""
        let cover = kugouArtworkURL(
            firstArtworkString(
                in: item,
                keys: ["list_pic", "imgurl", "img", "cover", "image_url", "image", "pic"]
            )
        )
        return Playlist(
            id: stableID("user:\(listID)"),
            name: name,
            coverImgUrl: cover,
            picUrl: nil,
            trackCount: int(item["songcount"]) ?? int(item["song_count"]) ?? int(item["count"]),
            playCount: int(item["play_count"]),
            subscribedCount: nil,
            shareCount: nil,
            commentCount: nil,
            creator: nil,
            description: string(item["intro"]),
            tags: nil,
            source: .kugou,
            kugouID: "user:\(listID)"
        )
    }

    private static func firstDictionaryArray(
        in value: Any,
        keys: Set<String>,
        allowDirectArray: Bool = true
    ) -> [[String: Any]] {
        if allowDirectArray, let dictionaries = value as? [[String: Any]], !dictionaries.isEmpty {
            return dictionaries
        }
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary where keys.contains(key) {
                if let result = child as? [[String: Any]] { return result }
            }
            for child in dictionary.values {
                let result = firstDictionaryArray(in: child, keys: keys, allowDirectArray: allowDirectArray)
                if !result.isEmpty { return result }
            }
        } else if let array = value as? [Any] {
            for child in array {
                let result = firstDictionaryArray(in: child, keys: keys, allowDirectArray: allowDirectArray)
                if !result.isEmpty { return result }
            }
        }
        return []
    }

    private static func allDictionaryItems(in value: Any, matchingKey key: String) -> [[String: Any]] {
        var result: [[String: Any]] = []
        if let dictionary = value as? [String: Any] {
            for (childKey, child) in dictionary {
                if childKey == key, let items = child as? [[String: Any]] {
                    result.append(contentsOf: items)
                } else {
                    result.append(contentsOf: allDictionaryItems(in: child, matchingKey: key))
                }
            }
        } else if let array = value as? [Any] {
            for child in array {
                result.append(contentsOf: allDictionaryItems(in: child, matchingKey: key))
            }
        }
        return result
    }

    private struct MembershipSummary {
        let level: KCMMembershipLevel
        let expiration: Date?
        let productType: String?
    }

    private static func membershipSummary(
        detail: [String: Any],
        vip: [String: Any]
    ) -> MembershipSummary {
        let merged: [Any] = [vip, detail]
        let activeFlags = merged.flatMap {
            allInts(in: $0, keys: ["is_vip", "vip_status", "vip_level"])
        }
        let expiration = merged.flatMap {
            allTimestamps(
                in: $0,
                keys: ["vip_end_time", "end_time", "endtime", "expire_time", "expireTime", "paid_vip_expire_time"]
            )
        }.max()
        let isActive = activeFlags.contains(where: { $0 > 0 }) || expiration.map { $0 > Date() } == true
        guard isActive else {
            return MembershipSummary(level: .none, expiration: expiration, productType: nil)
        }

        let paidFlags = merged.flatMap {
            allInts(in: $0, keys: ["is_paid_vip", "purchased_type", "purchased_ios_type"])
        }
        let vipData = vip["data"] as? [String: Any] ?? vip
        let mainVIPType = int(vipData["vip_type"]) ?? int(vipData["m_type"]) ?? 0
        let level: KCMMembershipLevel = paidFlags.contains(where: { $0 > 0 }) || mainVIPType > 0
            ? .full
            : .trial

        let productTypes = merged.flatMap {
            allStrings(in: $0, keys: ["product_type"])
        }.map { $0.lowercased() }
        let productType = productTypes.contains("svip")
            ? "svip"
            : productTypes.first
        return MembershipSummary(level: level, expiration: expiration, productType: productType)
    }

    private static func allTimestamps(in value: Any, keys: Set<String>) -> [Date] {
        var result: [Date] = []
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary where keys.contains(key) {
                if let date = timestamp(child) { result.append(date) }
            }
            for child in dictionary.values {
                result.append(contentsOf: allTimestamps(in: child, keys: keys))
            }
        } else if let array = value as? [Any] {
            for child in array {
                result.append(contentsOf: allTimestamps(in: child, keys: keys))
            }
        }
        return result
    }

    private static func timestamp(_ value: Any) -> Date? {
        if let number = value as? NSNumber {
            var seconds = number.doubleValue
            if seconds > 10_000_000_000 { seconds /= 1_000 }
            return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
        }
        guard let raw = string(value), !raw.isEmpty else { return nil }
        if var seconds = Double(raw) {
            if seconds > 10_000_000_000 { seconds /= 1_000 }
            return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
        }
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: raw) { return date }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: raw)
    }

    private static func songQuality(hash: String?, bitrate: Int, size: Int?) -> SongQuality? {
        guard let hash, !hash.isEmpty else { return nil }
        return SongQuality(br: bitrate, fid: nil, size: size, vd: nil, sr: nil)
    }

    private static func soundQuality(forKCMCode code: String) -> SoundQuality? {
        switch code.lowercased() {
        case "multitrack", "multi_track": return .multitrack
        case "128", "standard", "low": return .standard
        case "320", "exhigh", "hq": return .exhigh
        case "flac", "lossless", "sq": return .lossless
        case "high", "hires", "res": return .hires
        case "viper_clear", "jyeffect": return .jyeffect
        case "viper_atmos", "sky": return .sky
        case "viper_tape", "jymaster", "master": return .jymaster
        default: return nil
        }
    }

    private static func kcmQualityCode(for quality: SoundQuality) -> String {
        switch quality {
        case .multitrack: return "multitrack"
        case .standard, .higher, .none: return "128"
        case .exhigh: return "320"
        case .lossless: return "flac"
        case .hires: return "high"
        case .jyeffect: return "viper_clear"
        case .sky: return "viper_atmos"
        case .jymaster: return "viper_tape"
        }
    }

    private static let kcmQualityOrder: [SoundQuality] = [
        .multitrack, .jymaster, .sky, .jyeffect,
        .hires, .lossless, .exhigh, .standard,
    ]

    private static func qualitiesReported(by song: Song) -> [KCMSongQualityInfo] {
        let values: [(SoundQuality, String, SongQuality?)] = [
            (.hires, "high", song.hr),
            (.lossless, "flac", song.sq),
            (.exhigh, "320", song.h),
            (.standard, "128", song.l),
        ]
        return values.compactMap { quality, code, info in
            guard let info else { return nil }
            return KCMSongQualityInfo(
                quality: quality,
                code: code,
                bitrate: info.br,
                size: info.size ?? 0,
                isAvailable: true
            )
        }
    }

    private static func firstInt(in value: Any, keys: Set<String>) -> Int? {
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                if keys.contains(key), let number = int(child) { return number }
            }
            for child in dictionary.values {
                if let found = firstInt(in: child, keys: keys) { return found }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let found = firstInt(in: child, keys: keys) { return found }
            }
        }
        return nil
    }

    private static func allInts(in value: Any, keys: Set<String>) -> [Int] {
        var result: [Int] = []
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                if keys.contains(key), let number = int(child) {
                    result.append(number)
                }
                result.append(contentsOf: allInts(in: child, keys: keys))
            }
        } else if let array = value as? [Any] {
            for child in array {
                result.append(contentsOf: allInts(in: child, keys: keys))
            }
        }
        return result
    }

    private static func allStrings(in value: Any, keys: Set<String>) -> [String] {
        var result: [String] = []
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                if keys.contains(key), let text = string(child), !text.isEmpty {
                    result.append(text)
                }
                result.append(contentsOf: allStrings(in: child, keys: keys))
            }
        } else if let array = value as? [Any] {
            for child in array {
                result.append(contentsOf: allStrings(in: child, keys: keys))
            }
        }
        return result
    }

    private static var requestTimestamp: String {
        String(Int(Date().timeIntervalSince1970 * 1_000))
    }

    private static func firstString(in value: Any, keys: Set<String>) -> String? {
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                if keys.contains(key), let result = string(child), !result.isEmpty { return result }
            }
            for child in dictionary.values {
                if let result = firstString(in: child, keys: keys) { return result }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let result = firstString(in: child, keys: keys) { return result }
            }
        }
        return nil
    }

    private static func firstURLString(in value: Any) -> String? {
        if let dictionary = value as? [String: Any] {
            for key in ["url", "play_url", "playUrl", "downurl", "backupdownurl", "backup_url", "backupUrl"] {
                if let candidate = string(dictionary[key]), candidate.hasPrefix("http") { return candidate }
                if let candidates = dictionary[key] as? [String], let candidate = candidates.first(where: { $0.hasPrefix("http") }) { return candidate }
            }
            for child in dictionary.values {
                if let candidate = firstURLString(in: child) { return candidate }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let candidate = firstURLString(in: child) { return candidate }
            }
        }
        return nil
    }

    private static func isSuccess(_ json: [String: Any]) -> Bool {
        let code = int(json["error_code"]) ?? int(json["errcode"]) ?? int(json["code"]) ?? int(json["status"])
        return code == nil || code == 0 || code == 1 || code == 200
    }

    private static func stableID(_ value: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return -Int(hash % UInt64(Int.max - 1)) - 1
    }

    private static func string(_ value: Any?) -> String? {
        switch value {
        case let value as String: return value
        case let value as NSNumber: return value.stringValue
        default: return nil
        }
    }

    private static func int(_ value: Any?) -> Int? {
        switch value {
        case let value as Int: return value
        case let value as NSNumber: return value.intValue
        case let value as String: return Int(value)
        default: return nil
        }
    }

    private static func bool(_ value: Any?) -> Bool? {
        switch value {
        case let value as Bool: return value
        case let value as NSNumber: return value.boolValue
        case let value as String: return ["1", "true", "yes"].contains(value.lowercased())
        default: return nil
        }
    }

    private static func cookieValues(in header: String) -> [String: String] {
        var values: [String: String] = [:]
        for component in header.split(separator: ";") {
            let pair = component.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { continue }
            let key = pair[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = pair[1].trimmingCharacters(in: .whitespacesAndNewlines)
            values[key] = value
        }
        return values
    }

    private static func decodeBase64Image(_ value: String) -> Data? {
        let encoded = value.components(separatedBy: ",").last ?? value
        return Data(base64Encoded: encoded)
    }

    private static func secureURL(_ value: String) -> String {
        if value.hasPrefix("//") { return "https:\(value)" }
        if value.hasPrefix("http://") { return "https://\(value.dropFirst(7))" }
        return value
    }

    private static func firstArtworkString(
        in value: [String: Any],
        keys: [String]
    ) -> String? {
        for key in keys {
            if let candidate = string(value[key]), !candidate.isEmpty {
                return candidate
            }
        }
        for key in keys {
            if let candidate = firstString(in: value, keys: [key]), !candidate.isEmpty {
                return candidate
            }
        }
        return nil
    }

    private static func kugouArtworkURL(_ rawValue: String?, preferredSize: Int = 1000) -> String? {
        guard var value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }

        let size = min(max(preferredSize, 400), 1000)
        value = value
            .replacingOccurrences(of: "{size}", with: String(size))
            .replacingOccurrences(of: "{width}", with: String(size))
            .replacingOccurrences(of: "{height}", with: String(size))
        value = secureURL(value)

        guard let url = URL(string: value),
              url.host?.lowercased().hasSuffix(".kugou.com") == true,
              let range = value.range(
                of: #"/(?:100|120|150|160|180|240|300|400|480|500|640|800|1000)/"#,
                options: .regularExpression
              ) else {
            return value
        }
        return value.replacingCharacters(in: range, with: "/\(size)/")
    }

    private static func secureOptionalURL(_ value: String?) -> String? {
        value.map(secureURL)
    }
}
