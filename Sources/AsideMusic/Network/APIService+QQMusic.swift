// APIService+QQMusic.swift
// QQ 音乐 API 桥接层
// 将 QQMusicKit 的 async/await 接口适配到 AsideMusic 的 Song 模型和 Combine 体系

import Foundation
import Combine
import QQMusicKit

// MARK: - QQ 音乐配置

extension APIService {
    
    /// QQ 音乐客户端（使用默认配置）
    var qqClient: QQMusicClient {
        QQMusicClient.shared
    }
}

// MARK: - QQ 音乐搜索

extension APIService {
    
    /// 搜索 QQ 音乐歌曲
    func searchQQSongs(keyword: String, page: Int = 1, num: Int = 30) -> AnyPublisher<[Song], Error> {
        Future<[Song], Error> { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }
            Task {
                do {
                    let results = try await self.qqClient.search(
                        keyword: keyword,
                        type: .song,
                        num: num,
                        page: page,
                        highlight: false
                    )
                    let songs = results.compactMap { Self.convertQQSongToSong($0) }
                    promise(.success(songs))
                } catch {
                    AppLogger.error("[QQMusic] 搜索失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// 搜索 QQ 音乐歌手
    func searchQQArtists(keyword: String, page: Int = 1, num: Int = 30) -> AnyPublisher<[ArtistInfo], Error> {
        Future<[ArtistInfo], Error> { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }
            Task {
                do {
                    let results = try await self.qqClient.search(
                        keyword: keyword,
                        type: .singer,
                        num: num,
                        page: page,
                        highlight: false
                    )
                    let artists = results.compactMap { Self.convertQQArtistToArtistInfo($0) }
                    promise(.success(artists))
                } catch {
                    AppLogger.error("[QQMusic] 搜索歌手失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// 搜索 QQ 音乐歌单
    func searchQQPlaylists(keyword: String, page: Int = 1, num: Int = 30) -> AnyPublisher<[Playlist], Error> {
        Future<[Playlist], Error> { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }
            Task {
                do {
                    let results = try await self.qqClient.search(
                        keyword: keyword,
                        type: .songlist,
                        num: num,
                        page: page,
                        highlight: false
                    )
                    let playlists = results.compactMap { Self.convertQQPlaylistToPlaylist($0) }
                    promise(.success(playlists))
                } catch {
                    AppLogger.error("[QQMusic] 搜索歌单失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// 搜索 QQ 音乐专辑
    func searchQQAlbums(keyword: String, page: Int = 1, num: Int = 30) -> AnyPublisher<[SearchAlbum], Error> {
        Future<[SearchAlbum], Error> { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }
            Task {
                do {
                    let results = try await self.qqClient.search(
                        keyword: keyword,
                        type: .album,
                        num: num,
                        page: page,
                        highlight: false
                    )
                    let albums = results.compactMap { Self.convertQQAlbumToSearchAlbum($0) }
                    promise(.success(albums))
                } catch {
                    AppLogger.error("[QQMusic] 搜索专辑失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}

// MARK: - QQ 音乐播放 URL

extension APIService {
    
    /// 获取 QQ 音乐歌曲播放 URL
    func fetchQQSongUrl(mid: String, fileType: SongFileType = .mp3_128) -> AnyPublisher<SongUrlResult, Error> {
        Future<SongUrlResult, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(PlaybackError.unavailable))
                return
            }
            Task {
                // 先尝试用户指定的音质
                do {
                    if let url = try await self.qqClient.songURL(mid: mid, fileType: fileType),
                       !url.isEmpty {
                        promise(.success(SongUrlResult(url: url, isUnblocked: false)))
                        return
                    }
                } catch {
                    AppLogger.warning("[QQMusic] \(fileType.displayName) 请求失败，尝试降级: \(error.localizedDescription)")
                }
                
                // 降级尝试较低音质（catch 异常 + 空 URL 都走这里）
                if let fallbackUrl = await self.qqFallbackURL(mid: mid, excluding: fileType) {
                    promise(.success(SongUrlResult(url: fallbackUrl, isUnblocked: false)))
                } else {
                    AppLogger.error("[QQMusic] 所有音质均无法获取播放 URL: \(mid)")
                    promise(.failure(PlaybackError.unavailable))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// QQ 音乐音质降级策略（每个音质独立 catch，不会因单个失败中断）
    private func qqFallbackURL(mid: String, excluding: SongFileType? = nil) async -> String? {
        let fallbackTypes: [SongFileType] = [.mp3_320, .mp3_128, .aac96]
        for type in fallbackTypes {
            if type == excluding { continue }
            do {
                if let url = try await qqClient.songURL(mid: mid, fileType: type), !url.isEmpty {
                    AppLogger.info("[QQMusic] 降级到 \(type.displayName) 成功")
                    return url
                }
            } catch {
                AppLogger.warning("[QQMusic] 降级 \(type.displayName) 失败: \(error.localizedDescription)")
                continue
            }
        }
        return nil
    }
}

// MARK: - QQ 音乐歌词

extension APIService {
    
    /// 获取 QQ 音乐歌词
    func fetchQQLyric(mid: String) -> AnyPublisher<QQLyricResponse, Error> {
        Future<QQLyricResponse, Error> { [weak self] promise in
            guard let self = self else {
                promise(.success(QQLyricResponse(lyric: nil, trans: nil)))
                return
            }
            Task {
                do {
                    let result = try await self.qqClient.lyric(
                        value: mid,
                        qrc: false,
                        trans: true,
                        roma: false
                    )
                    promise(.success(QQLyricResponse(
                        lyric: result.lyric,
                        trans: result.trans
                    )))
                } catch {
                    AppLogger.error("[QQMusic] 获取歌词失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}

/// QQ 音乐歌词响应
struct QQLyricResponse {
    let lyric: String?
    let trans: String?
}

// MARK: - QQ 音乐热搜

extension APIService {
    
    /// 获取 QQ 音乐热搜词
    func fetchQQHotSearch() -> AnyPublisher<[HotSearchItem], Error> {
        Future<[HotSearchItem], Error> { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }
            Task {
                do {
                    let result = try await self.qqClient.hotkey()
                    let items = Self.convertQQHotkeys(result)
                    promise(.success(items))
                } catch {
                    AppLogger.error("[QQMusic] 获取热搜失败: \(error)")
                    promise(.success([]))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}


// MARK: - QQ 音乐歌手详情

extension APIService {
    
    /// 获取 QQ 音乐歌手歌曲
    func fetchQQSingerSongs(mid: String, page: Int = 1, num: Int = 30) -> AnyPublisher<[Song], Error> {
        Future<[Song], Error> { [weak self] promise in
            guard let self = self else { promise(.success([])); return }
            Task {
                do {
                    let results = try await self.qqClient.singerSongs(mid: mid, num: num, page: page)
                    if let first = results.first {
                        AppLogger.debug("[QQMusic] 歌手歌曲第一条: \(first)")
                    }
                    let songs = results.compactMap { Self.convertQQSongToSong($0) }
                    AppLogger.info("[QQMusic] 歌手歌曲: 原始\(results.count)条, 转换成功\(songs.count)条")
                    promise(.success(songs))
                } catch {
                    AppLogger.error("[QQMusic] 获取歌手歌曲失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// 获取 QQ 音乐歌手信息
    func fetchQQSingerInfo(mid: String) -> AnyPublisher<JSON, Error> {
        Future<JSON, Error> { [weak self] promise in
            guard let self = self else { promise(.failure(PlaybackError.unavailable)); return }
            Task {
                do {
                    let result = try await self.qqClient.singerInfo(mid: mid)
                    promise(.success(result))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}

// MARK: - QQ 音乐歌手专辑 & MV

extension APIService {
    
    /// 获取 QQ 音乐歌手专辑列表
    func fetchQQSingerAlbums(mid: String, num: Int = 20, begin: Int = 0) -> AnyPublisher<[AlbumInfo], Error> {
        Future<[AlbumInfo], Error> { [weak self] promise in
            guard let self = self else { promise(.success([])); return }
            Task {
                do {
                    let result = try await self.qqClient.singerAlbums(mid: mid, number: num, begin: begin)
                    AppLogger.debug("[QQMusic] 歌手专辑原始: \(result)")
                    let albumArray = Self.extractJSONArray(from: result)
                    if albumArray.isEmpty {
                        AppLogger.warning("[QQMusic] 歌手专辑: 无法提取数组，原始keys: \(result.objectValue?.keys.joined(separator: ",") ?? "非对象")")
                    }
                    let albums: [AlbumInfo] = albumArray.compactMap { Self.convertQQSingerAlbum($0) }
                    AppLogger.info("[QQMusic] 歌手专辑: 原始\(albumArray.count)条, 转换\(albums.count)条")
                    promise(.success(albums))
                } catch {
                    AppLogger.error("[QQMusic] 获取歌手专辑失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// 将 QQ 歌手专辑 JSON 转换为 AlbumInfo（独立方法，避免编译器超时）
    private static func convertQQSingerAlbum(_ json: JSON) -> AlbumInfo? {
        AppLogger.debug("[QQMusic] 歌手专辑项: \(json)")
        let albumMid: String = json["albumMID"]?.stringValue ?? json["album_mid"]?.stringValue
            ?? json["mid"]?.stringValue ?? json["albumMid"]?.stringValue ?? ""
        let albumId: Int = json["albumID"]?.intValue ?? json["album_id"]?.intValue
            ?? json["id"]?.intValue ?? json["albumid"]?.intValue ?? 0
        let name: String = json["albumName"]?.stringValue ?? json["album_name"]?.stringValue
            ?? json["name"]?.stringValue ?? json["title"]?.stringValue ?? ""
        guard !name.isEmpty else { return nil }
        
        // 封面：优先用 API 返回的 pic，否则从 mid 生成
        var picUrl: String? = json["albumPic"]?.stringValue ?? json["album_pic"]?.stringValue
        if picUrl == nil || picUrl?.isEmpty == true { picUrl = json["pic"]?.stringValue }
        if picUrl == nil || picUrl?.isEmpty == true { picUrl = json["pic_url"]?.stringValue }
        if picUrl == nil || picUrl?.isEmpty == true { picUrl = json["picUrl"]?.stringValue }
        if picUrl == nil || picUrl?.isEmpty == true { picUrl = json["cover"]?.stringValue }
        if (picUrl == nil || picUrl?.isEmpty == true), !albumMid.isEmpty {
            picUrl = "https://y.gtimg.cn/music/photo_new/T002R300x300M000\(albumMid).jpg"
        }
        
        let publishDate: String? = json["publicTime"]?.stringValue ?? json["publish_date"]?.stringValue
        let publishDate2: String? = publishDate ?? json["pub_time"]?.stringValue ?? json["aDate"]?.stringValue
        let publishTime: Int? = publishDate2.flatMap { qqDateStringToTimestamp($0) }
        let songCount: Int? = json["song_count"]?.intValue ?? json["total_song_num"]?.intValue
        let songCount2: Int? = songCount ?? json["size"]?.intValue ?? json["songcount"]?.intValue
        
        // 歌手
        var singerName: String?
        let singerArr: [JSON]? = json["singer_list"]?.arrayValue ?? json["singer"]?.arrayValue ?? json["singers"]?.arrayValue
        if let first = singerArr?.first {
            singerName = first["name"]?.stringValue ?? first["singerName"]?.stringValue
        }
        if singerName == nil {
            singerName = json["singerName"]?.stringValue ?? json["singer_name"]?.stringValue
        }
        let artist: Artist? = singerName.map { Artist(id: 0, name: $0) }
        let artistInfo: ArtistInfo? = singerName.map { ArtistInfo(id: 0, name: $0, picUrl: nil, img1v1Url: nil, cover: nil, avatar: nil, musicSize: nil, albumSize: nil, mvSize: nil, briefDesc: nil, alias: nil, followed: nil, accountId: nil) }
        
        return AlbumInfo(
            id: albumId,
            name: name,
            picUrl: picUrl,
            publishTime: publishTime,
            size: songCount2,
            artist: artistInfo,
            artists: artist.map { [$0] },
            description: nil,
            company: nil,
            subType: nil
        )
    }
    
    /// 获取 QQ 音乐歌手 MV 列表
    func fetchQQSingerMVs(mid: String, num: Int = 20, begin: Int = 0) -> AnyPublisher<[QQMV], Error> {
        Future<[QQMV], Error> { [weak self] promise in
            guard let self = self else { promise(.success([])); return }
            Task {
                do {
                    let result = try await self.qqClient.singerMVs(mid: mid, number: num, begin: begin)
                    AppLogger.debug("[QQMusic] 歌手MV原始: \(result)")
                    let mvArray = Self.extractJSONArray(from: result)
                    if mvArray.isEmpty {
                        AppLogger.warning("[QQMusic] 歌手MV: 无法提取数组，原始keys: \(result.objectValue?.keys.joined(separator: ",") ?? "非对象")")
                    }
                    if let first = mvArray.first {
                        AppLogger.debug("[QQMusic] 歌手MV第一项: \(first)")
                    }
                    let mvs = mvArray.compactMap { Self.convertQQSingerMV($0, singerMid: mid) }
                    AppLogger.info("[QQMusic] 歌手MV: 原始\(mvArray.count)条, 转换\(mvs.count)条")
                    promise(.success(mvs))
                } catch {
                    AppLogger.error("[QQMusic] 获取歌手MV失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// QQ 日期字符串 → 毫秒时间戳
    static func qqDateStringToTimestamp(_ dateStr: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            return Int(date.timeIntervalSince1970 * 1000)
        }
        return nil
    }
    
    /// 从 JSON 中递归提取第一个数组（适配不同 API 返回结构）
    static func extractJSONArray(from json: JSON) -> [JSON] {
        // 直接是数组
        if let arr = json.arrayValue, !arr.isEmpty { return arr }
        // 是对象，尝试常见 key
        if let obj = json.objectValue {
            let priorityKeys = ["albumList", "list", "mvList", "data", "songlist", "songs", "items"]
            for key in priorityKeys {
                if let arr = obj[key]?.arrayValue, !arr.isEmpty { return arr }
            }
            // 遍历所有 key，找第一个非空数组
            for (_, value) in obj {
                if let arr = value.arrayValue, !arr.isEmpty { return arr }
            }
        }
        return []
    }
    
    /// 将歌手 MV 列表项转换为 QQMV（字段名可能跟搜索 MV 不同）
    static func convertQQSingerMV(_ json: JSON, singerMid: String? = nil) -> QQMV? {
        // vid 提取
        let vid: String? = json["vid"]?.stringValue
            ?? json["mv_vid"]?.stringValue
            ?? json["v_id"]?.stringValue
            ?? json["id"]?.stringValue
        
        guard let vid = vid, !vid.isEmpty else {
            AppLogger.warning("[QQBridge] 歌手MV转换失败: 无法获取 vid")
            return nil
        }
        
        let name: String = json["title"]?.stringValue
            ?? json["name"]?.stringValue
            ?? json["mv_name"]?.stringValue
            ?? ""
        
        // 歌手
        var singerName: String?
        var sMid: String? = singerMid
        let singerArr: [JSON]? = json["singer_list"]?.arrayValue ?? json["singer"]?.arrayValue ?? json["singers"]?.arrayValue
        if let first = singerArr?.first {
            singerName = first["name"]?.stringValue ?? first["singerName"]?.stringValue ?? first["title"]?.stringValue
            if sMid == nil { sMid = first["mid"]?.stringValue }
        }
        if singerName == nil {
            singerName = json["singer_name"]?.stringValue ?? json["singerName"]?.stringValue
        }
        
        // 封面 — 拆分 ?? 链避免编译器超时
        var coverUrl: String? = json["pic"]?.stringValue
        if coverUrl == nil || coverUrl?.isEmpty == true { coverUrl = json["mv_pic_url"]?.stringValue }
        if coverUrl == nil || coverUrl?.isEmpty == true { coverUrl = json["pic_url"]?.stringValue }
        if coverUrl == nil || coverUrl?.isEmpty == true { coverUrl = json["cover"]?.stringValue }
        if coverUrl == nil || coverUrl?.isEmpty == true { coverUrl = json["cover_pic"]?.stringValue }
        if coverUrl == nil || coverUrl?.isEmpty == true { coverUrl = json["picurl"]?.stringValue }
        if coverUrl == nil || coverUrl?.isEmpty == true { coverUrl = json["picUrl"]?.stringValue }
        
        // 如果没有封面，留空
        if coverUrl?.isEmpty == true { coverUrl = nil }
        
        let duration: Int? = json["duration"]?.intValue ?? json["interval"]?.intValue
        let playCount: Int? = json["play_count"]?.intValue ?? json["listennum"]?.intValue
        let playCount2: Int? = playCount ?? json["playcnt"]?.intValue ?? json["listen_num"]?.intValue
        let publishDate: String? = json["publish_date"]?.stringValue ?? json["publicTime"]?.stringValue
            ?? json["pubdate"]?.stringValue
        
        return QQMV(
            vid: vid,
            name: name,
            singerName: singerName,
            singerMid: sMid,
            coverUrl: coverUrl,
            duration: duration,
            playCount: playCount2,
            publishDate: publishDate
        )
    }
}

// MARK: - QQ 音乐专辑详情

extension APIService {
    
    /// 获取 QQ 音乐专辑歌曲
    func fetchQQAlbumSongs(albumMid: String, page: Int = 1, num: Int = 50) -> AnyPublisher<[Song], Error> {
        Future<[Song], Error> { [weak self] promise in
            guard let self = self else { promise(.success([])); return }
            Task {
                do {
                    let results = try await self.qqClient.albumSongs(value: albumMid, num: num, page: page)
                    if let first = results.first {
                        AppLogger.debug("[QQMusic] 专辑歌曲第一条: \(first)")
                    }
                    let songs = results.compactMap { Self.convertQQSongToSong($0) }
                    AppLogger.info("[QQMusic] 专辑歌曲: 原始\(results.count)条, 转换成功\(songs.count)条")
                    promise(.success(songs))
                } catch {
                    AppLogger.error("[QQMusic] 获取专辑歌曲失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// 获取 QQ 音乐专辑详情
    func fetchQQAlbumDetail(albumMid: String) -> AnyPublisher<JSON, Error> {
        Future<JSON, Error> { [weak self] promise in
            guard let self = self else { promise(.failure(PlaybackError.unavailable)); return }
            Task {
                do {
                    let result = try await self.qqClient.albumDetail(value: albumMid)
                    promise(.success(result))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}

// MARK: - QQ 音乐 MV 搜索与播放

extension APIService {
    
    /// 搜索 QQ 音乐 MV
    func searchQQMVs(keyword: String, page: Int = 1, num: Int = 30) -> AnyPublisher<[QQMV], Error> {
        Future<[QQMV], Error> { [weak self] promise in
            guard let self = self else { promise(.success([])); return }
            Task {
                do {
                    let results = try await self.qqClient.search(
                        keyword: keyword,
                        type: .mv,
                        num: num,
                        page: page,
                        highlight: false
                    )
                    let mvs = results.compactMap { Self.convertQQSearchMV($0) }
                    promise(.success(mvs))
                } catch {
                    AppLogger.error("[QQMusic] 搜索MV失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// 获取 QQ 音乐 MV 播放 URL
    func fetchQQMVUrl(vid: String) -> AnyPublisher<String?, Error> {
        Future<String?, Error> { [weak self] promise in
            guard let self = self else { promise(.success(nil)); return }
            Task {
                do {
                    let result = try await self.qqClient.mvURLs(vids: vid)
                    // 打印完整返回结构用于调试
                    AppLogger.debug("[QQMusic] MV URL 原始返回: \(result)")
                    
                    // 递归搜索 freeflow_url
                    if let url = Self.extractMVUrl(from: result) {
                        AppLogger.info("[QQMusic] MV URL 提取成功: \(url.prefix(80))...")
                        promise(.success(url))
                        return
                    }
                    
                    AppLogger.warning("[QQMusic] MV URL 为空: vid=\(vid)")
                    promise(.success(nil))
                } catch {
                    AppLogger.error("[QQMusic] 获取MV URL失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// 从 MV URL 响应中递归提取播放链接
    private static func extractMVUrl(from json: JSON) -> String? {
        // 直接是字符串（URL）
        if let str = json.stringValue, str.hasPrefix("http") {
            return str
        }
        
        // 包含 freeflow_url 数组
        if let urls = json["freeflow_url"]?.arrayValue {
            for u in urls {
                if let str = u.stringValue, !str.isEmpty, str.hasPrefix("http") {
                    return str
                }
            }
        }
        
        // 包含 url 字段
        if let url = json["url"]?.stringValue, !url.isEmpty, url.hasPrefix("http") {
            return url
        }
        
        // 遍历字典的值（优先 mp4 > hls > 其他）
        if let obj = json.objectValue {
            // 优先检查 mp4
            if let mp4 = obj["mp4"], let url = extractMVUrl(from: mp4) { return url }
            // 再检查 hls
            if let hls = obj["hls"], let url = extractMVUrl(from: hls) { return url }
            // 遍历其他 key
            for (key, value) in obj where key != "mp4" && key != "hls" {
                if let url = extractMVUrl(from: value) { return url }
            }
        }
        
        // 遍历数组
        if let arr = json.arrayValue {
            for item in arr {
                if let url = extractMVUrl(from: item) { return url }
            }
        }
        
        return nil
    }
    
    /// 获取 QQ 音乐 MV 详情
    func fetchQQMVDetail(vid: String) -> AnyPublisher<QQMV?, Error> {
        Future<QQMV?, Error> { [weak self] promise in
            guard let self = self else { promise(.success(nil)); return }
            Task {
                do {
                    let result = try await self.qqClient.mvDetail(vids: vid)
                    // 详情可能在数组中
                    if let arr = result.arrayValue, let first = arr.first {
                        promise(.success(Self.convertQQDetailMV(first)))
                    } else if let obj = result.objectValue, let first = obj.values.first {
                        promise(.success(Self.convertQQDetailMV(first)))
                    } else {
                        promise(.success(Self.convertQQDetailMV(result)))
                    }
                } catch {
                    AppLogger.error("[QQMusic] 获取MV详情失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}

// MARK: - QQ 音乐歌单详情

extension APIService {
    
    /// 获取 QQ 音乐歌单歌曲
    func fetchQQPlaylistSongs(playlistId: Int, page: Int = 1, num: Int = 50) -> AnyPublisher<[Song], Error> {
        Future<[Song], Error> { [weak self] promise in
            guard let self = self else { promise(.success([])); return }
            Task {
                do {
                    let result = try await self.qqClient.songlistDetail(
                        songlistId: playlistId, num: num, page: page, onlySong: true
                    )
                    AppLogger.debug("[QQMusic] 歌单歌曲原始响应: \(result)")
                    // 歌单详情返回的歌曲在 songlist 字段中
                    let songArray: [JSON]
                    if let songs = result["songlist"]?.arrayValue {
                        songArray = songs
                    } else if let songs = result["songs"]?.arrayValue {
                        songArray = songs
                    } else if let arr = result.arrayValue {
                        songArray = arr
                    } else {
                        songArray = []
                    }
                    let songs = songArray.compactMap { Self.convertQQSongToSong($0) }
                    promise(.success(songs))
                } catch {
                    AppLogger.error("[QQMusic] 获取歌单歌曲失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// 获取 QQ 音乐歌单详情（封面、描述等）
    func fetchQQPlaylistDetail(playlistId: Int) -> AnyPublisher<JSON, Error> {
        Future<JSON, Error> { [weak self] promise in
            guard let self = self else { promise(.failure(PlaybackError.unavailable)); return }
            Task {
                do {
                    let result = try await self.qqClient.songlistDetail(
                        songlistId: playlistId, num: 0, page: 1, onlySong: false
                    )
                    promise(.success(result))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}
