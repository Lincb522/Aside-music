import Foundation

enum ExternalPlaylistProvider: String, CaseIterable, Identifiable {
    case automatic
    case netease
    case qqMusic
    case kugou
    case qishui
    case appleMusic
    case spotify
    case kuwo
    case text

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .automatic: "自动识别"
        case .netease: "NCM"
        case .qqMusic: "QCM"
        case .kugou: "KCM"
        case .qishui: "汽水音乐"
        case .appleMusic: "Apple Music"
        case .spotify: "Spotify"
        case .kuwo: "酷我音乐"
        case .text: "文本"
        }
    }
}

struct ExternalPlaylistTrack: Identifiable {
    let id: Int
    let provider: ExternalPlaylistProvider
    let externalID: String?
    let isrc: String?
    let title: String
    let artist: String
    let album: String?
    let durationMilliseconds: Int?
    let preferredSource: MusicSource?
    let nativeSong: Song?
}

struct ExternalPlaylistDraft {
    let provider: ExternalPlaylistProvider
    let externalID: String?
    let name: String
    let description: String?
    let coverURL: URL?
    let creator: String?
    let tracks: [ExternalPlaylistTrack]
}

enum ExternalPlaylistMatchState {
    case pending
    case matching
    case matched
    case unmatched
}

struct ExternalPlaylistMatchResult: Identifiable {
    let track: ExternalPlaylistTrack
    let song: Song?
    let score: Double

    var id: Int {
        track.id
    }
}

enum ExternalPlaylistImportError: LocalizedError {
    case unrecognizedInput
    case invalidLink(String)
    case emptyPlaylist
    case invalidResponse(String)
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .unrecognizedInput:
            "无法识别歌单链接或文本"
        case let .invalidLink(provider):
            "无法识别\(provider)歌单链接"
        case .emptyPlaylist:
            "歌单为空或无法访问"
        case let .invalidResponse(provider):
            "\(provider)返回的数据无法解析"
        case let .requestFailed(statusCode):
            "请求失败（HTTP \(statusCode)）"
        }
    }
}

/// 外部歌单只在这里被解析成曲目元数据。最终返回给本地歌单的始终是 Mono
/// 各音乐平台搜索接口产生的 `Song`，不会保存外部站点的播放地址。
@MainActor
final class ExternalPlaylistImportService {
    static let shared = ExternalPlaylistImportService()

    private let pageSize = 100
    private let maximumPages = 50
    private let userAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) " +
        "AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"

    private init() {}

    func resolve(
        input: String,
        provider requestedProvider: ExternalPlaylistProvider = .automatic
    ) async throws -> ExternalPlaylistDraft {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ExternalPlaylistImportError.unrecognizedInput }

        let provider = requestedProvider == .automatic ? detectProvider(in: trimmed) : requestedProvider
        switch provider {
        case .automatic:
            throw ExternalPlaylistImportError.unrecognizedInput
        case .netease:
            return try await resolveNetease(trimmed)
        case .qqMusic:
            return try await resolveQQMusic(trimmed)
        case .kugou:
            return try await resolveKugou(trimmed)
        case .qishui:
            return try await resolveQishui(trimmed)
        case .appleMusic:
            return try await resolveAppleMusic(trimmed)
        case .spotify:
            return try await resolveSpotify(trimmed)
        case .kuwo:
            return try await resolveKuwo(trimmed)
        case .text:
            return try resolveText(trimmed)
        }
    }

    func match(_ track: ExternalPlaylistTrack) async -> ExternalPlaylistMatchResult {
        if let nativeSong = track.nativeSong {
            return ExternalPlaylistMatchResult(track: track, song: nativeSong, score: 1)
        }
        if let cached = MonoMediaIdentityEngine.shared.cachedMatch(for: track) {
            return ExternalPlaylistMatchResult(
                track: track,
                song: cached.song,
                score: cached.score
            )
        }

        let query = [track.title, track.artist]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !query.isEmpty else {
            return ExternalPlaylistMatchResult(track: track, song: nil, score: 0)
        }

        var allCandidates: [Song] = []
        var seenCandidates = Set<String>()
        let sourceOrder: [MusicSource] = preferredSearchOrder(for: track)

        for source in sourceOrder {
            guard !Task.isCancelled else { break }
            let candidates: [Song]
            do {
                candidates = try await search(source: source, query: query)
            } catch {
                AppLogger.warning("外部歌单匹配搜索失败: source=\(source.rawValue), error=\(error)")
                continue
            }

            for candidate in candidates {
                let identity = PlayerManager.playbackIdentityKey(for: candidate)
                if seenCandidates.insert(identity).inserted {
                    allCandidates.append(candidate)
                }
            }
        }

        guard let match = MonoMediaIdentityEngine.shared.bestMatch(
            for: track,
            among: allCandidates
        ) else {
            return ExternalPlaylistMatchResult(track: track, song: nil, score: 0)
        }
        return ExternalPlaylistMatchResult(track: track, song: match.song, score: match.score)
    }

    // MARK: - Provider detection

    private func detectProvider(in input: String) -> ExternalPlaylistProvider {
        let value = input.lowercased()
        if value.contains("music.163.com") || value.contains("163cn.tv") {
            return .netease
        }
        if value.contains("y.qq.com") || value.contains("i.y.qq.com") {
            return .qqMusic
        }
        if value.contains("kugou.com") {
            return .kugou
        }
        if value.contains("qishui.douyin.com") || value.contains("music.douyin.com/qishui") {
            return .qishui
        }
        if value.contains("music.apple.com") {
            return .appleMusic
        }
        if value.contains("open.spotify.com/playlist") || value.contains("spotify:playlist:") {
            return .spotify
        }
        if value.contains("kuwo.cn") || value.contains("kuwo.com") {
            return .kuwo
        }
        if input.contains("\n") || !value.contains("://") {
            return .text
        }
        return .automatic
    }

    // MARK: - Native providers

    private func resolveNetease(_ input: String) async throws -> ExternalPlaylistDraft {
        let resolvedInput = try await resolvedRedirectInput(input)
        guard let id = firstCapture(
            in: resolvedInput,
            patterns: [
                #"playlist(?:\?id=|/)(\d+)"#,
                #"[?&#]id=(\d+)"#,
                #"^(\d+)$"#,
            ]
        ).flatMap(Int.init) else {
            throw ExternalPlaylistImportError.invalidLink("NCM")
        }

        let detail = try await APIService.shared.fetchPlaylistDetail(id: id).async()
        var songs: [Song] = []
        var offset = 0
        for _ in 0 ..< maximumPages {
            let page = try await APIService.shared
                .fetchPlaylistTracks(id: id, limit: pageSize, offset: offset)
                .async()
            songs.append(contentsOf: page)
            if page.count < pageSize { break }
            offset += page.count
        }
        guard !songs.isEmpty else { throw ExternalPlaylistImportError.emptyPlaylist }
        return nativeDraft(
            provider: .netease,
            externalID: String(id),
            name: detail.name,
            description: detail.description,
            coverURL: detail.coverUrl,
            creator: detail.creator?.nickname,
            songs: songs
        )
    }

    private func resolveQQMusic(_ input: String) async throws -> ExternalPlaylistDraft {
        let resolvedInput = try await resolvedRedirectInput(input)
        guard let id = firstCapture(
            in: resolvedInput,
            patterns: [#"playlist/(\d+)"#, #"[?&#]id=(\d+)"#, #"^(\d+)$"#]
        ).flatMap(Int.init) else {
            throw ExternalPlaylistImportError.invalidLink("QCM")
        }

        let detail = try await APIService.shared.qqClient.songlistDetail(
            songlistId: id,
            num: 1,
            page: 1
        )
        let name = detail["dirinfo"]?["title"]?.stringValue ?? "QCM 歌单"
        let description = detail["dirinfo"]?["desc"]?.stringValue
        let coverURL = normalizedURL(detail["dirinfo"]?["picurl"]?.stringValue)

        var songs: [Song] = []
        let qqPageSize = 50
        for page in 1 ... maximumPages {
            let result = try await APIService.shared
                .fetchQQPlaylistSongs(playlistId: id, page: page, num: qqPageSize)
                .async()
            songs.append(contentsOf: result)
            if result.count < qqPageSize { break }
        }
        guard !songs.isEmpty else { throw ExternalPlaylistImportError.emptyPlaylist }
        return nativeDraft(
            provider: .qqMusic,
            externalID: String(id),
            name: name,
            description: description,
            coverURL: coverURL,
            creator: nil,
            songs: songs
        )
    }

    private func resolveKugou(_ input: String) async throws -> ExternalPlaylistDraft {
        let resolvedInput = try await resolvedRedirectInput(input)
        guard let globalID = firstCapture(
            in: resolvedInput,
            patterns: [#"(gcid_[A-Za-z0-9]+)"#]
        ) else {
            throw ExternalPlaylistImportError.invalidLink("KCM")
        }

        var playlistName = "KCM 歌单"
        var coverURL: URL?
        if let pageURL = URL(string: "https://m.kugou.com/songlist/\(globalID)/"),
           let html = try? await fetchText(pageURL)
        {
            playlistName = htmlMetaContent(named: "og:title", in: html) ?? htmlTitle(in: html) ?? playlistName
            coverURL = normalizedURL(htmlMetaContent(named: "og:image", in: html))
        }

        var songs: [Song] = []
        for page in 1 ... maximumPages {
            let result = try await APIService.shared
                .fetchKugouPlaylistSongs(globalID: globalID, page: page, pageSize: pageSize)
                .async()
            songs.append(contentsOf: result)
            if result.count < pageSize { break }
        }
        guard !songs.isEmpty else { throw ExternalPlaylistImportError.emptyPlaylist }
        return nativeDraft(
            provider: .kugou,
            externalID: globalID,
            name: playlistName,
            description: nil,
            coverURL: coverURL,
            creator: nil,
            songs: songs
        )
    }

    private func resolveAppleMusic(_ input: String) async throws -> ExternalPlaylistDraft {
        guard let playlistID = firstCapture(
            in: input,
            patterns: [#"(pl\.[A-Za-z0-9._-]+)"#]
        ) else {
            throw ExternalPlaylistImportError.invalidLink("Apple Music")
        }

        var name = "Apple Music 歌单"
        var coverURL: URL?
        if let pageURL = firstURL(in: input), let html = try? await fetchText(pageURL) {
            name = htmlMetaContent(named: "og:title", in: html) ?? name
            coverURL = normalizedURL(htmlMetaContent(named: "og:image", in: html))
        }

        var songs: [Song] = []
        var offset = 0
        for _ in 0 ..< maximumPages {
            let page = try await AppleMusicService.shared.playlistSongs(
                playlistID: playlistID,
                offset: offset,
                limit: pageSize
            )
            songs.append(contentsOf: page.songs)
            if !page.hasMore || page.songs.isEmpty { break }
            offset += page.songs.count
        }
        guard !songs.isEmpty else { throw ExternalPlaylistImportError.emptyPlaylist }
        return nativeDraft(
            provider: .appleMusic,
            externalID: playlistID,
            name: name,
            description: nil,
            coverURL: coverURL,
            creator: nil,
            songs: songs
        )
    }

    private func nativeDraft(
        provider: ExternalPlaylistProvider,
        externalID: String?,
        name: String,
        description: String?,
        coverURL: URL?,
        creator: String?,
        songs: [Song]
    ) -> ExternalPlaylistDraft {
        let tracks = songs.enumerated().map { index, song in
            ExternalPlaylistTrack(
                id: index,
                provider: provider,
                externalID: platformIdentifier(for: song),
                isrc: song.appleMusicISRC,
                title: song.name,
                artist: song.artistName,
                album: song.album?.name,
                durationMilliseconds: song.dt,
                preferredSource: song.musicSource,
                nativeSong: song
            )
        }
        return ExternalPlaylistDraft(
            provider: provider,
            externalID: externalID,
            name: cleanedPlaylistName(name),
            description: description,
            coverURL: coverURL,
            creator: creator,
            tracks: tracks
        )
    }

    // MARK: - Metadata-only providers

    private func resolveQishui(_ input: String) async throws -> ExternalPlaylistDraft {
        let pageURL: URL
        if let id = firstCapture(in: input, patterns: [#"[?&]playlist_id=(\d+)"#]) {
            guard let url = URL(string: "https://music.douyin.com/qishui/share/playlist?playlist_id=\(id)") else {
                throw ExternalPlaylistImportError.invalidLink("汽水音乐")
            }
            pageURL = url
        } else if let id = firstCapture(in: input, patterns: [#"^(\d{10,})$"#]),
                  let url = URL(string: "https://music.douyin.com/qishui/share/playlist?playlist_id=\(id)")
        {
            pageURL = url
        } else if let url = firstURL(in: input) {
            pageURL = url
        } else {
            throw ExternalPlaylistImportError.invalidLink("汽水音乐")
        }

        let html = try await fetchText(pageURL)
        guard let object = embeddedJSONObject(after: "_ROUTER_DATA", in: html),
              let loaderData = object["loaderData"] as? [String: Any],
              let page = loaderData["playlist_page"] as? [String: Any],
              let info = page["playlistInfo"] as? [String: Any]
        else {
            throw ExternalPlaylistImportError.invalidResponse("汽水音乐")
        }

        let medias = page["medias"] as? [[String: Any]] ?? []
        let tracks = medias.enumerated().compactMap { index, media -> ExternalPlaylistTrack? in
            let entity = media["entity"] as? [String: Any]
            let track = entity?["track"] as? [String: Any]
            guard let title = nonemptyString(track?["name"]) else { return nil }
            let artists = (track?["artists"] as? [[String: Any]] ?? [])
                .compactMap { nonemptyString($0["name"]) ?? nonemptyString($0["simple_display_name"]) }
                .joined(separator: " / ")
            let album = (track?["album"] as? [String: Any]).flatMap { nonemptyString($0["name"]) }
            return ExternalPlaylistTrack(
                id: index,
                provider: .qishui,
                externalID: stringValue(track?["id"]) ?? stringValue(media["id"]),
                isrc: nonemptyString(track?["isrc"]),
                title: title,
                artist: artists,
                album: album,
                durationMilliseconds: intValue(track?["duration"]),
                preferredSource: .qishui,
                nativeSong: nil
            )
        }
        guard !tracks.isEmpty else { throw ExternalPlaylistImportError.emptyPlaylist }

        let owner = info["owner"] as? [String: Any]
        let cover = info["url_cover"] as? [String: Any]
        let coverURLs = cover?["urls"] as? [String]
        let coverURI = nonemptyString(cover?["uri"])
        let coverURL = normalizedURL(
            coverURLs?.first.flatMap { base in
                coverURI.map { "\(base)\($0)~tplv-b829550vbb-crop-center:720:720.jpg" }
            }
        )
        return ExternalPlaylistDraft(
            provider: .qishui,
            externalID: stringValue(info["id"]),
            name: nonemptyString(info["title"]) ?? "汽水音乐歌单",
            description: nil,
            coverURL: coverURL,
            creator: nonemptyString(owner?["nickname"]) ?? nonemptyString(owner?["public_name"]),
            tracks: tracks
        )
    }

    private func resolveSpotify(_ input: String) async throws -> ExternalPlaylistDraft {
        guard let id = firstCapture(
            in: input,
            patterns: [
                #"open\.spotify\.com/playlist/([A-Za-z0-9]{22})"#,
                #"spotify:playlist:([A-Za-z0-9]{22})"#,
                #"^([A-Za-z0-9]{22})$"#,
            ]
        ), let url = URL(string: "https://open.spotify.com/embed/playlist/\(id)") else {
            throw ExternalPlaylistImportError.invalidLink("Spotify")
        }

        let html = try await fetchText(url)
        guard let jsonText = firstCapture(
            in: html,
            patterns: [#"<script\s+id="__NEXT_DATA__"[^>]*>([\s\S]*?)</script>"#]
        ), let data = jsonText.data(using: .utf8),
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let props = root["props"] as? [String: Any],
        let pageProps = props["pageProps"] as? [String: Any],
        let state = pageProps["state"] as? [String: Any],
        let stateData = state["data"] as? [String: Any],
        let entity = stateData["entity"] as? [String: Any] else {
            throw ExternalPlaylistImportError.invalidResponse("Spotify")
        }

        let list = entity["trackList"] as? [[String: Any]] ?? []
        let tracks = list.enumerated().compactMap { index, item -> ExternalPlaylistTrack? in
            guard let title = nonemptyString(item["title"]) else { return nil }
            return ExternalPlaylistTrack(
                id: index,
                provider: .spotify,
                externalID: nonemptyString(item["uri"]) ?? nonemptyString(item["uid"]),
                isrc: nonemptyString(item["isrc"]),
                title: title,
                artist: nonemptyString(item["subtitle"]) ?? "",
                album: nil,
                durationMilliseconds: intValue(item["duration"]),
                preferredSource: nil,
                nativeSong: nil
            )
        }
        guard !tracks.isEmpty else { throw ExternalPlaylistImportError.emptyPlaylist }

        var coverURL: URL?
        if let coverArt = entity["coverArt"] as? [String: Any],
           let sources = coverArt["sources"] as? [[String: Any]]
        {
            let sorted = sources.sorted {
                abs((intValue($0["width"]) ?? 0) - 640) < abs((intValue($1["width"]) ?? 0) - 640)
            }
            coverURL = normalizedURL(nonemptyString(sorted.first?["url"]))
        }
        return ExternalPlaylistDraft(
            provider: .spotify,
            externalID: id,
            name: nonemptyString(entity["name"]) ?? "Spotify 歌单",
            description: nil,
            coverURL: coverURL,
            creator: nonemptyString(entity["subtitle"]),
            tracks: tracks
        )
    }

    private func resolveKuwo(_ input: String) async throws -> ExternalPlaylistDraft {
        guard let id = firstCapture(
            in: input,
            patterns: [
                #"playlist_detail/(\d+)"#,
                #"play_detail/(\d+)"#,
                #"playlist/(\d+)"#,
                #"[?&]pid=(\d+)"#,
                #"^(\d+)$"#,
            ]
        ) else {
            throw ExternalPlaylistImportError.invalidLink("酷我音乐")
        }

        var metadata: [String: Any]?
        var rawTracks: [[String: Any]] = []
        var total = 0
        for page in 1 ... maximumPages {
            var components = URLComponents(string: "https://wapi.kuwo.cn/api/www/playlist/playListInfo")
            components?.queryItems = [
                URLQueryItem(name: "pid", value: id),
                URLQueryItem(name: "pn", value: String(page)),
                URLQueryItem(name: "rn", value: String(pageSize)),
            ]
            guard let url = components?.url else {
                throw ExternalPlaylistImportError.invalidLink("酷我音乐")
            }
            let root = try await fetchJSON(url)
            guard intValue(root["code"]) == 200,
                  let data = root["data"] as? [String: Any]
            else {
                throw ExternalPlaylistImportError.invalidResponse("酷我音乐")
            }
            if metadata == nil {
                metadata = data
                total = intValue(data["total"]) ?? 0
            }
            let pageTracks = data["musicList"] as? [[String: Any]] ?? []
            rawTracks.append(contentsOf: pageTracks)
            if pageTracks.count < pageSize || (total > 0 && rawTracks.count >= total) { break }
        }
        guard let metadata else { throw ExternalPlaylistImportError.invalidResponse("酷我音乐") }
        let tracks = rawTracks.enumerated().compactMap { index, item -> ExternalPlaylistTrack? in
            guard let title = nonemptyString(item["name"]) ?? nonemptyString(item["songName"]) else {
                return nil
            }
            let durationSeconds = intValue(item["duration"])
            return ExternalPlaylistTrack(
                id: index,
                provider: .kuwo,
                externalID: stringValue(item["rid"]) ?? stringValue(item["id"]),
                isrc: nonemptyString(item["isrc"]),
                title: title,
                artist: (nonemptyString(item["artist"]) ?? nonemptyString(item["singer"]) ?? "")
                    .replacingOccurrences(of: "&", with: "/"),
                album: nonemptyString(item["album"]),
                durationMilliseconds: durationSeconds.map { $0 * 1000 },
                preferredSource: nil,
                nativeSong: nil
            )
        }
        guard !tracks.isEmpty else { throw ExternalPlaylistImportError.emptyPlaylist }
        return ExternalPlaylistDraft(
            provider: .kuwo,
            externalID: id,
            name: nonemptyString(metadata["title"]) ?? nonemptyString(metadata["name"]) ?? "酷我音乐歌单",
            description: nonemptyString(metadata["info"]),
            coverURL: normalizedURL(nonemptyString(metadata["img"]) ?? nonemptyString(metadata["pic"])),
            creator: nonemptyString(metadata["userName"]),
            tracks: tracks
        )
    }

    private func resolveText(_ input: String) throws -> ExternalPlaylistDraft {
        let lines = input.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let tracks = lines.enumerated().compactMap { index, line -> ExternalPlaylistTrack? in
            let cleaned = line.replacingOccurrences(
                of: #"^\s*\d+\s*[.、)]\s*"#,
                with: "",
                options: .regularExpression
            )
            let separators = ["\t", " - ", " — ", " – ", "｜", "|"]
            var title = cleaned
            var artist = ""
            for separator in separators {
                let components = cleaned.components(separatedBy: separator)
                if components.count >= 2 {
                    title = components[0].trimmingCharacters(in: .whitespaces)
                    artist = components.dropFirst().joined(separator: separator)
                        .trimmingCharacters(in: .whitespaces)
                    break
                }
            }
            guard !title.isEmpty else { return nil }
            return ExternalPlaylistTrack(
                id: index,
                provider: .text,
                externalID: nil,
                isrc: nil,
                title: title,
                artist: artist,
                album: nil,
                durationMilliseconds: nil,
                preferredSource: nil,
                nativeSong: nil
            )
        }
        guard !tracks.isEmpty else { throw ExternalPlaylistImportError.emptyPlaylist }
        return ExternalPlaylistDraft(
            provider: .text,
            externalID: nil,
            name: "导入歌单",
            description: nil,
            coverURL: nil,
            creator: nil,
            tracks: tracks
        )
    }

    // MARK: - Matching

    private func preferredSearchOrder(for track: ExternalPlaylistTrack) -> [MusicSource] {
        var sources: [MusicSource] = [.netease, .qqmusic, .kugou, .qishui]
        if AppleMusicService.shared.isAuthorized {
            sources.append(.appleMusic)
        }
        if let preferredSource = track.preferredSource,
           let index = sources.firstIndex(of: preferredSource)
        {
            sources.remove(at: index)
            sources.insert(preferredSource, at: 0)
        }
        return sources
    }

    private func search(source: MusicSource, query: String) async throws -> [Song] {
        switch source {
        case .netease:
            try await APIService.shared.searchSongs(keyword: query).async()
        case .qqmusic:
            try await APIService.shared.searchQQSongs(keyword: query, page: 1, num: 15).async()
        case .kugou:
            try await APIService.shared
                .searchKugouSongsWithTotal(keyword: query, page: 1, pageSize: 15)
                .async()
                .songs
        case .qishui:
            try await APIService.shared.searchQishuiSongs(keyword: query, page: 0).async()
        case .appleMusic:
            try await AppleMusicService.shared.searchSongs(term: query, offset: 0, limit: 15).songs
        case .local:
            []
        }
    }

    // MARK: - Networking and parsing

    private func fetchText(_ url: URL) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
            throw ExternalPlaylistImportError.requestFailed(http.statusCode)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw ExternalPlaylistImportError.invalidResponse(url.host ?? "服务")
        }
        return text
    }

    private func fetchJSON(_ url: URL) async throws -> [String: Any] {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.kuwo.cn/", forHTTPHeaderField: "Referer")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
            throw ExternalPlaylistImportError.requestFailed(http.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ExternalPlaylistImportError.invalidResponse(url.host ?? "服务")
        }
        return json
    }

    private func resolvedRedirectInput(_ input: String) async throws -> String {
        guard let url = firstURL(in: input) else { return input }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        if let (_, response) = try? await URLSession.shared.data(for: request),
           let finalURL = response.url
        {
            return finalURL.absoluteString
        }
        return input
    }

    private func firstURL(in input: String) -> URL? {
        guard let range = input.range(
            of: #"https?://[^\s<>"']+"#,
            options: .regularExpression
        ) else { return nil }
        var raw = String(input[range])
        while let last = raw.last, "。，、；;！!)）]】".contains(last) {
            raw.removeLast()
        }
        return URL(string: raw)
    }

    private func firstCapture(in input: String, patterns: [String]) -> String? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else { continue }
            let range = NSRange(input.startIndex..., in: input)
            guard let match = regex.firstMatch(in: input, range: range),
                  match.numberOfRanges > 1,
                  let captureRange = Range(match.range(at: 1), in: input) else { continue }
            return String(input[captureRange])
        }
        return nil
    }

    private func embeddedJSONObject(after marker: String, in text: String) -> [String: Any]? {
        guard let markerRange = text.range(of: marker),
              let start = text[markerRange.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var isInsideString = false
        var isEscaped = false
        var end: String.Index?
        var index = start
        while index < text.endIndex {
            let character = text[index]
            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
            } else if character == "\"" {
                isInsideString = true
            } else if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    end = index
                    break
                }
            }
            index = text.index(after: index)
        }
        guard let end,
              let data = String(text[start ... end]).data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return object
    }

    private func htmlMetaContent(named name: String, in html: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let patterns = [
            #"<meta[^>]+(?:property|name)=["']\#(escaped)["'][^>]+content=["']([^"']+)["'][^>]*>"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']\#(escaped)["'][^>]*>"#,
        ]
        return firstCapture(in: html, patterns: patterns).map(decodeHTMLEntities)
    }

    private func htmlTitle(in html: String) -> String? {
        firstCapture(in: html, patterns: [#"<title[^>]*>([\s\S]*?)</title>"#])
            .map(decodeHTMLEntities)
    }

    private func decodeHTMLEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    private func normalizedURL(_ rawValue: String?) -> URL? {
        guard var value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        if value.hasPrefix("//") {
            value = "https:\(value)"
        } else if value.hasPrefix("http://") {
            value = "https://\(value.dropFirst("http://".count))"
        }
        return URL(string: value)
    }

    private func nonemptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func stringValue(_ value: Any?) -> String? {
        if let string = nonemptyString(value) { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private func platformIdentifier(for song: Song) -> String {
        switch song.musicSource {
        case .netease:
            String(song.id)
        case .qqmusic:
            song.qqMid ?? String(song.id)
        case .qishui:
            song.qishuiTrackId.map(String.init) ?? String(song.id)
        case .kugou:
            song.kugouHash ?? String(song.id)
        case .appleMusic:
            song.appleMusicID ?? String(song.id)
        case .local:
            song.localRelativePath ?? String(song.id)
        }
    }

    private func cleanedPlaylistName(_ value: String) -> String {
        let trimmed = decodeHTMLEntities(value)
            .replacingOccurrences(of: " - Apple Music", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "导入歌单" : trimmed
    }
}
