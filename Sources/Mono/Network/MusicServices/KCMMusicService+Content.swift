import Foundation

extension KCMMusicService {
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

    static func comment(from item: [String: Any]) -> Comment? {
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

    static func commentTimestamp(_ rawValue: String?) -> Int {
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

}
