// APIService+QishuiMusic.swift
// 汽水音乐 API 桥接层
// 通过自部署 FastAPI 后端访问汽水音乐数据

import Foundation
@preconcurrency import Combine

// MARK: - 汽水音乐配置

extension APIService {

    private static let qishuiBaseURL: String = {
        Bundle.main.infoDictionary?["QISHUI_BASE_URL"] as? String ?? "http://114.66.37.231:8000"
    }()
    
    private static let qishuiSessionID: String = {
        Bundle.main.infoDictionary?["QISHUI_SESSION_ID"] as? String ?? "276bc970d5806bb93266fc917cb42771"
    }()

    private func qishuiURL(_ path: String) -> URL {
        URL(string: Self.qishuiBaseURL + path)!
    }

    /// 构建服务端代理播放 URL（服务端负责下载、解密、转码）
    static func qishuiProxyPlayURL(trackId: Int, quality: String = "highest") -> String {
        "\(qishuiBaseURL)/play/\(trackId)?quality=\(quality)&sessionid_ss=\(qishuiSessionID)"
    }
}

// MARK: - 汽水音乐搜索

extension APIService {

    func searchQishuiSongs(keyword: String, page: Int = 0) -> AnyPublisher<[Song], Error> {
        asyncToPublisher { [weak self] in
            guard let self else { return [] }
            var components = URLComponents(url: self.qishuiURL("/search"), resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "q", value: keyword),
                URLQueryItem(name: "page", value: String(page)),
            ]
            let (data, _) = try await URLSession.shared.data(from: components.url!)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            guard let groups = json["result_groups"] as? [[String: Any]],
                  let firstGroup = groups.first,
                  let items = firstGroup["data"] as? [[String: Any]] else { return [] }

            return items.compactMap { Self.convertQishuiTrackToSong($0) }
        }
    }
}

// MARK: - 汽水音乐播放 URL

extension APIService {

    /// 获取汽水音乐播放信息（加密链接 + 解密密钥，由客户端 StreamPlayer 解密）
    ///
    /// 使用方式：
    /// ```swift
    /// let result = try await fetchQishuiSongUrl(trackId: 123)
    /// streamPlayer.play(url: result.url, decryptionKey: result.decryptionKey)
    /// ```
    func fetchQishuiSongUrl(trackId: Int, quality: String = "highest") -> AnyPublisher<QishuiPlaybackResult, Error> {
        asyncToPublisher { [weak self] in
            guard let self else { throw PlaybackError.unavailable }
            let qualities = try await self._fetchQishuiQualities(trackId: trackId)

            let preferenceOrder = ["lossless", "hi_res", "spatial", "highest", "higher", "medium"]
            let sortedQualities = qualities.sorted { a, b in
                let ai = preferenceOrder.firstIndex(of: a.quality) ?? preferenceOrder.count
                let bi = preferenceOrder.firstIndex(of: b.quality) ?? preferenceOrder.count
                return ai < bi
            }

            let target = sortedQualities.first { $0.quality == quality }
                ?? sortedQualities.first
            guard let target else { throw PlaybackError.unavailable }

            return QishuiPlaybackResult(
                url: target.mainUrl ?? "",
                decryptionKey: target.decryptionKey,
                quality: target.quality,
                bitrate: target.bitrate,
                codec: target.codec,
                format: target.format,
                size: target.size
            )
        }
    }

    func fetchQishuiTrackQualities(trackId: Int) -> AnyPublisher<[QishuiQualityInfo], Error> {
        asyncToPublisher { [weak self] in
            guard let self else { return [] }
            return try await self._fetchQishuiQualities(trackId: trackId)
        }
    }

    private func _fetchQishuiQualities(trackId: Int) async throws -> [QishuiQualityInfo] {
        let url = qishuiURL("/track_url")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "track_id": trackId,
            "sessionid_ss": Self.qishuiSessionID,
        ])
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let qualities = json["qualities"] as? [[String: Any]] else { return [] }
        return qualities.compactMap { QishuiQualityInfo(json: $0) }
    }
}

// MARK: - 汽水音乐歌词

extension APIService {

    func fetchQishuiLyric(trackId: Int) -> AnyPublisher<String, Error> {
        asyncToPublisher { [weak self] in
            guard let self else { return "" }
            let url = self.qishuiURL("/lyric")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["track_id": trackId])
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            return json["content"] as? String ?? ""
        }
    }
}

// MARK: - 汽水音乐签到

extension APIService {

    func qishuiCheckin() -> AnyPublisher<Bool, Error> {
        asyncToPublisher { [weak self] in
            guard let self else { return false }
            let url = self.qishuiURL("/checkin/run_now")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            return json["message"] != nil
        }
    }
}

// MARK: - 数据模型转换

extension APIService {

    static func convertQishuiTrackToSong(_ item: [String: Any]) -> Song? {
        guard let entity = item["entity"] as? [String: Any],
              let track = entity["track"] as? [String: Any] else { return nil }

        guard let idStr = track["id"] as? String,
              let trackId = Int(idStr) else { return nil }

        let name = track["name"] as? String ?? ""

        var artists: [Artist] = []
        if let singerArray = track["artists"] as? [[String: Any]] {
            for singer in singerArray {
                let singerId = (singer["id"] as? String).flatMap { Int($0) } ?? 0
                let singerName = singer["name"] as? String ?? ""
                if !singerName.isEmpty {
                    artists.append(Artist(id: singerId, name: singerName))
                }
            }
        }

        var album: Album?
        if let albumDict = track["album"] as? [String: Any] {
            let albumId = (albumDict["id"] as? String).flatMap { Int($0) } ?? 0
            let albumName = albumDict["name"] as? String ?? ""
            let coverUrl = buildQishuiCoverUrl(albumDict["url_cover"] as? [String: Any])
            album = Album(id: albumId, name: albumName, picUrl: coverUrl)
        }

        let durationMs = track["duration"] as? Int

        var hrQ: SongQuality?, sqQ: SongQuality?, hQ: SongQuality?, mQ: SongQuality?, lQ: SongQuality?
        if let bitRates = track["bit_rates"] as? [[String: Any]] {
            let qualities = Set(bitRates.compactMap { $0["quality"] as? String })
            if qualities.contains("hi_res") || qualities.contains("spatial") {
                hrQ = SongQuality(br: 320000, fid: nil, size: nil, vd: nil, sr: nil)
            }
            if qualities.contains("lossless") {
                sqQ = SongQuality(br: 820000, fid: nil, size: nil, vd: nil, sr: nil)
            }
            if qualities.contains("highest") {
                hQ = SongQuality(br: 260000, fid: nil, size: nil, vd: nil, sr: nil)
            }
            if qualities.contains("higher") {
                mQ = SongQuality(br: 132000, fid: nil, size: nil, vd: nil, sr: nil)
            }
            if qualities.contains("medium") {
                lQ = SongQuality(br: 64000, fid: nil, size: nil, vd: nil, sr: nil)
            }
        }

        return Song(
            id: trackId,
            name: name,
            ar: artists.isEmpty ? nil : artists,
            al: album,
            dt: durationMs,
            fee: 0,
            mv: 0,
            h: hQ, m: mQ, l: lQ, sq: sqQ, hr: hrQ,
            alia: nil,
            source: .qishui,
            qishuiTrackId: trackId
        )
    }

    static func buildQishuiCoverUrl(_ urlCover: [String: Any]?) -> String? {
        guard let cover = urlCover,
              let uri = cover["uri"] as? String,
              let urls = cover["urls"] as? [String],
              let base = urls.first else { return nil }
        return base + uri + "~300x300.webp"
    }
}

// MARK: - 汽水音乐音质模型

struct QishuiQualityInfo: Identifiable, Sendable {
    let quality: String
    let bitrate: Int
    let codec: String
    let format: String
    let size: Int
    let mainUrl: String?
    let decryptionKey: String?

    var id: String { quality }

    var displayName: String { soundQuality.displayName }

    var soundQuality: SoundQuality {
        switch quality {
        case "lossless": return .lossless
        case "hi_res": return .hires
        case "spatial": return .sky
        case "highest": return .exhigh
        case "higher": return .higher
        case "medium": return .standard
        default: return .standard
        }
    }

    var sizeText: String {
        if size >= 1_048_576 {
            return String(format: "%.1f MB", Double(size) / 1_048_576)
        }
        return String(format: "%.0f KB", Double(size) / 1024)
    }

    init?(json: [String: Any]) {
        guard let q = json["quality"] as? String else { return nil }
        self.quality = q
        self.bitrate = json["bitrate"] as? Int ?? 0
        self.codec = json["codec"] as? String ?? ""
        self.format = json["format"] as? String ?? ""
        self.size = json["size"] as? Int ?? 0
        self.mainUrl = json["main_url"] as? String
        self.decryptionKey = json["decryption_key"] as? String
    }
}

// MARK: - 汽水音乐播放结果

struct QishuiPlaybackResult: Sendable {
    let url: String
    let decryptionKey: String?
    let quality: String
    let bitrate: Int
    let codec: String
    let format: String
    let size: Int

    var isEncrypted: Bool { decryptionKey != nil }

    var soundQuality: SoundQuality {
        switch quality {
        case "lossless": return .lossless
        case "hi_res": return .hires
        case "spatial": return .sky
        case "highest": return .exhigh
        case "higher": return .higher
        case "medium": return .standard
        default: return .standard
        }
    }
}
