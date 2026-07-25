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

struct KCMPlaylistCategory: Identifiable, Hashable {
    let id: Int
    let name: String
    let groupName: String?
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
            return "需要 KCM 授权"
        case .verificationRequired:
            return "KCM 需要完成验证"
        case .invalidResponse:
            return "KCM 返回了无效响应"
        case .server(_, let message):
            return message.isEmpty ? "KCM 服务异常" : message
        case .unavailable:
            return "KCM 暂不可用"
        }
    }
}

final class KCMMusicService: @unchecked Sendable {
    static let shared = KCMMusicService()

    private let session: URLSession
    private let baseURL: URL
    private let cookieKey = "monologue_kugou_cookie"

    init(session: URLSession = .shared) {
        self.session = session
        self.baseURL = URL(string: AppConfig.API.kugouBaseURL)!
    }

    var currentCookie: String? {
        let value = KeychainHelper.loadString(key: cookieKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    var isAuthenticated: Bool { currentCookie != nil }

    func applyCookie(_ cookie: String) {
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
        KeychainHelper.save(key: cookieKey, value: normalized)
    }

    func logout() {
        KeychainHelper.delete(key: cookieKey)
        HTTPCookieStorage.shared.cookies(for: baseURL)?.forEach {
            HTTPCookieStorage.shared.deleteCookie($0)
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

    func fetchPlaylistSongs(globalID: String, page: Int, pageSize: Int) async throws -> [Song] {
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

    func fetchSongURL(song: Song, quality: String = "high") async throws -> URL {
        guard isAuthenticated else { throw KCMMusicError.authenticationRequired }
        guard let hash = song.kugouHash, !hash.isEmpty else { throw KCMMusicError.unavailable }
        let json = try await request(
            path: "/song/url",
            query: [
                URLQueryItem(name: "hash", value: hash),
                URLQueryItem(name: "album_id", value: String(song.kugouAlbumID ?? 0)),
                URLQueryItem(name: "album_audio_id", value: String(song.kugouAlbumAudioID ?? 0)),
                URLQueryItem(name: "quality", value: quality),
            ]
        )
        guard let value = Self.firstURLString(in: json), let url = URL(string: Self.secureURL(value)) else {
            throw KCMMusicError.unavailable
        }
        return url
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

    func claimDailyLiteVIP(date: Date = Date()) async throws -> Bool {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let json = try await request(
            path: "/youth/day/vip",
            method: "POST",
            query: [URLQueryItem(name: "receive_day", value: formatter.string(from: date))]
        )
        return Self.isSuccess(json)
    }

    func upgradeDailyLiteVIP() async throws -> Bool {
        Self.isSuccess(try await request(path: "/youth/day/vip/upgrade", method: "POST"))
    }

    private func request(
        path: String,
        method: String = "GET",
        query: [URLQueryItem] = []
    ) async throws -> [String: Any] {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw KCMMusicError.invalidResponse
        }
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw KCMMusicError.invalidResponse }
        return try await request(url: url, method: method)
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

    private func persistResponseCookies(for url: URL) {
        guard let cookies = HTTPCookieStorage.shared.cookies(for: url), !cookies.isEmpty else { return }
        let header = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"]
        if let header, !header.isEmpty { KeychainHelper.save(key: cookieKey, value: header) }
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

    private static func song(from item: [String: Any]) -> Song? {
        let hash = string(item["hash"]) ?? string(item["FileHash"]) ?? string(item["filehash"])
        guard let hash, !hash.isEmpty else { return nil }
        let rawName = string(item["name"]) ?? string(item["SongName"]) ?? string(item["songname"]) ?? ""
        let singerInfo = item["singerinfo"] as? [[String: Any]] ?? []
        let artists: [Artist] = singerInfo.compactMap { singer in
            guard let name = string(singer["name"]), !name.isEmpty else { return nil }
            return Artist(id: int(singer["id"]) ?? stableID(name), name: name)
        }
        let singerName = string(item["SingerName"]) ?? string(item["singername"])
        let fallbackArtists: [Artist] = singerName?.split(separator: "、").map {
            let value = String($0)
            return Artist(id: stableID(value), name: value)
        } ?? []
        let resolvedArtists: [Artist] = artists.isEmpty ? fallbackArtists : artists
        let title: String = {
            guard let separator = rawName.range(of: " - ") else { return rawName }
            let prefix = String(rawName[..<separator.lowerBound])
            let shouldStripPrefix = resolvedArtists.isEmpty || resolvedArtists.contains {
                prefix.localizedCaseInsensitiveContains($0.name)
            }
            return shouldStripPrefix ? String(rawName[separator.upperBound...]) : rawName
        }()

        let albumInfo = item["albuminfo"] as? [String: Any]
        let albumID = int(item["album_id"]) ?? int(item["AlbumID"]) ?? int(albumInfo?["id"])
        let albumName = string(item["AlbumName"]) ?? string(item["album_name"]) ?? string(albumInfo?["name"]) ?? ""
        let rawCover = string(item["cover"])
            ?? string(item["Image"])
            ?? string(item["image"])
            ?? string((item["trans_param"] as? [String: Any])?["union_cover"])
        let cover = rawCover.map { secureURL($0.replacingOccurrences(of: "{size}", with: "800")) }
        let duration = int(item["timelen"]) ?? int(item["Duration"]) ?? int(item["duration"])
        let durationMS = duration.map { $0 < 10_000 ? $0 * 1_000 : $0 }
        let audioID = int(item["mixsongid"]) ?? int(item["MixSongID"]) ?? int(item["album_audio_id"]) ?? int(item["audio_id"])

        return Song(
            id: stableID(hash),
            name: title,
            ar: resolvedArtists.isEmpty ? nil : resolvedArtists,
            al: Album(id: albumID ?? 0, name: albumName, picUrl: cover),
            dt: durationMS,
            fee: nil,
            mv: nil,
            h: nil, m: nil, l: nil, sq: nil, hr: nil,
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
        let cover = (string(item["flexible_cover"]) ?? string(item["imgurl"]) ?? string(item["pic"]))
            .map { secureURL($0.replacingOccurrences(of: "{size}", with: "800")) }
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

    private static func firstURLString(in value: Any) -> String? {
        if let dictionary = value as? [String: Any] {
            for key in ["url", "play_url", "playUrl", "backup_url", "backupUrl"] {
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

    private static func secureURL(_ value: String) -> String {
        if value.hasPrefix("//") { return "https:\(value)" }
        if value.hasPrefix("http://") { return "https://\(value.dropFirst(7))" }
        return value
    }

    private static func secureOptionalURL(_ value: String?) -> String? {
        value.map(secureURL)
    }
}
