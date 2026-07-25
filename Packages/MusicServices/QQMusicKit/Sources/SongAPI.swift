import Foundation

// MARK: - 歌曲相关 API

public extension QQMusicClient {

    /// 查询歌曲信息
    /// - Parameter value: 歌曲 id 或 mid 列表，逗号分隔
    func querySong(value: String) async throws -> [JSON] {
        try await requestWrapped("/song/query_song", params: ["value": value])
    }

    /// 获取歌曲详情
    /// - Parameter value: 歌曲 id 或 mid
    func songDetail(value: String) async throws -> JSON {
        try await requestWrapped("/song/get_detail", params: ["value": value])
    }

    /// 批量获取歌曲播放链接
    ///
    /// ```swift
    /// let urls = try await client.songURLs(mids: "001yS0N31jFfpK,003OUlho2HcRHC")
    /// ```
    ///
    /// - Parameters:
    ///   - mids: 歌曲 mid 列表，逗号分隔
    ///   - fileType: 文件类型，默认 MP3 128kbps
    /// - Returns: mid -> url 的映射
    func songURLs(mids: String, fileType: SongFileType = .mp3_128) async throws -> [String: JSON] {
        try await requestWrapped("/song/get_song_urls", params: [
            "mid": mids,
            "file_type": fileType.rawValue,
        ])
    }

    /// 获取单首歌曲播放链接（便捷方法）
    /// - Parameters:
    ///   - mid: 歌曲 mid
    ///   - fileType: 文件类型
    /// - Returns: 播放链接，无法获取时返回 nil
    func songURL(mid: String, fileType: SongFileType = .mp3_128) async throws -> String? {
        let result = try await songURLs(mids: mid, fileType: fileType)
        return result[mid]?.stringValue
    }

    // MARK: - 加密歌曲

    /// 批量获取加密歌曲播放链接（返回 url + ekey）
    ///
    /// 加密文件需要使用 ekey 解密后才能播放，格式为 .mflac / .mgg
    ///
    /// ```swift
    /// let urls = try await client.encryptedSongURLs(mids: "001yS0N31jFfpK", fileType: .flac)
    /// // urls["001yS0N31jFfpK"] -> [url, ekey]
    /// ```
    ///
    /// - Parameters:
    ///   - mids: 歌曲 mid 列表，逗号分隔
    ///   - fileType: 加密文件类型
    /// - Returns: mid -> [url, ekey] 的映射
    func encryptedSongURLs(mids: String, fileType: EncryptedSongFileType = .flac) async throws -> [String: EncryptedSongURL] {
        let raw: [String: JSON] = try await requestWrapped("/song/get_song_urls", params: [
            "mid": mids,
            "file_type": "EncryptedSongFileType.\(fileType.rawValue)",
        ])
        var result: [String: EncryptedSongURL] = [:]
        for (mid, value) in raw {
            if let arr = value.arrayValue, arr.count >= 2,
               let url = arr[0].stringValue, let ekey = arr[1].stringValue {
                result[mid] = EncryptedSongURL(url: url, ekey: ekey)
            }
        }
        return result
    }

    /// 获取单首加密歌曲链接（便捷方法）
    /// - Parameters:
    ///   - mid: 歌曲 mid
    ///   - fileType: 加密文件类型
    /// - Returns: 加密歌曲 URL 信息，无法获取时返回 nil
    func encryptedSongURL(mid: String, fileType: EncryptedSongFileType = .flac) async throws -> EncryptedSongURL? {
        let result = try await encryptedSongURLs(mids: mid, fileType: fileType)
        return result[mid]
    }

    /// 获取单首歌曲下载链接（带 _download=1，走解密下载通道）
    /// - Parameters:
    ///   - mid: 歌曲 mid
    ///   - fileType: 文件类型
    /// - Returns: [url, ekey] 结构，ekey 可用于本地 QMC 解密
    func downloadSongURL(mid: String, fileType: SongFileType = .mp3_128) async throws -> EncryptedSongURL? {
        let raw: [String: JSON] = try await requestWrapped("/song/get_song_urls", params: [
            "mid": mid,
            "file_type": fileType.rawValue,
            "_download": "1",
        ])
        guard let value = raw[mid] else { return nil }
        if let arr = value.arrayValue, arr.count >= 2,
           let url = arr[0].stringValue, let ekey = arr[1].stringValue,
           !url.isEmpty {
            return EncryptedSongURL(url: url, ekey: ekey)
        }
        if let url = value.stringValue, !url.isEmpty {
            return EncryptedSongURL(url: url, ekey: "")
        }
        return nil
    }

    /// 获取试听链接
    /// - Parameters:
    ///   - mid: 歌曲 mid
    ///   - vs: 歌曲 vs 字段
    func tryURL(mid: String, vs: String) async throws -> JSON {
        try await requestWrapped("/song/get_try_url", params: ["mid": mid, "vs": vs])
    }

    /// 获取相似歌曲
    /// - Parameter songId: 歌曲 id
    func similarSongs(songId: Int) async throws -> [JSON] {
        try await requestWrapped("/song/get_similar_song", params: ["songid": String(songId)])
    }

    /// 获取歌曲标签
    /// - Parameter songId: 歌曲 id
    func songLabels(songId: Int) async throws -> [JSON] {
        try await requestWrapped("/song/get_lables", params: ["songid": String(songId)])
    }

    /// 获取歌曲相关歌单
    /// - Parameter songId: 歌曲 id
    func relatedSonglist(songId: Int) async throws -> [JSON] {
        try await requestWrapped("/song/get_related_songlist", params: ["songid": String(songId)])
    }

    /// 获取歌曲相关 MV
    /// - Parameter songId: 歌曲 id
    func relatedMV(songId: Int) async throws -> [JSON] {
        try await requestWrapped("/song/get_related_mv", params: ["songid": String(songId)])
    }

    /// 获取歌曲其他版本
    /// - Parameter value: 歌曲 id 或 mid
    func otherVersions(value: String) async throws -> [JSON] {
        try await requestWrapped("/song/get_other_version", params: ["value": value])
    }

    /// 获取歌曲制作信息
    /// - Parameter value: 歌曲 id 或 mid
    func songProducer(value: String) async throws -> [JSON] {
        try await requestWrapped("/song/get_producer", params: ["value": value])
    }

    /// 获取歌曲曲谱
    /// - Parameter mid: 歌曲 mid
    func songSheet(mid: String) async throws -> [JSON] {
        try await requestWrapped("/song/get_sheet", params: ["mid": mid])
    }

    /// 获取歌曲收藏数
    /// - Parameter songIds: 歌曲 id 列表，逗号分隔
    func songFavCount(songIds: String) async throws -> JSON {
        try await requestWrapped("/song/get_fav_num", params: ["songid": songIds])
    }

    /// 查询歌曲可用音质列表（专用路由，非通用路由）
    /// - Parameter mid: 歌曲 mid
    /// - Returns: 包含 qualities 数组的 JSON（每项含 code/name/bitrate/size）
    func songQualities(mid: String) async throws -> JSON {
        try await request("/song/qualities", params: ["mid": mid])
    }
}
