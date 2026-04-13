// APIService+QQMusic.swift
// qcm API 桥接层
// 将 QQMusicKit 的 async/await 接口适配到 Monologue 的 Song 模型和 Combine 体系

import Foundation
@preconcurrency import Combine
@preconcurrency import QQMusicKit

// MARK: - qcm配置

extension APIService {
    
    /// qcm客户端（使用默认配置）
    var qqClient: QQMusicClient {
        QQMusicClient.shared
    }

    /// 使用用户凭证执行请求（临时设置 musicId/musicKey，完成后恢复）
    @MainActor
    func withUserSession<T>(_ block: (QQMusicClient) async throws -> T) async throws -> T {
        try await QQUserSession.shared.withUserSession(block)
    }

    /// 根据用户登录状态选择 client 模式执行内容类请求
    /// 已登录 → 用户 session；未登录 → 管理员（默认）
    @MainActor
    private func withContentSession<T>(_ block: (QQMusicClient) async throws -> T) async throws -> T {
        if QQUserSession.shared.isLoggedIn {
            return try await withUserSession(block)
        }
        return try await block(qqClient)
    }
}

// MARK: - qcm搜索

extension APIService {
    
    /// 从搜索结果中提取指定类型的列表
    private static func extractSearchItems(from result: JSON, itemKey: String) -> [JSON] {
        if let body = result["body"] {
            if let items = body[itemKey]?.arrayValue, !items.isEmpty { return items }
        }
        if let items = result[itemKey]?.arrayValue, !items.isEmpty { return items }
        if let arr = result.arrayValue, !arr.isEmpty { return arr }
        return extractJSONArray(from: result)
    }

    /// 搜索 qcm歌曲
    func searchQQSongs(keyword: String, page: Int = 1, num: Int = 30) -> AnyPublisher<[Song], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let result = try await self.qqClient.search(
                keyword: keyword,
                type: .song,
                num: num,
                page: page,
                highlight: false
            )
            let items = Self.extractSearchItems(from: result, itemKey: "item_song")
            return items.compactMap { Self.convertQQSongToSong($0) }
        }
    }
    
    /// 搜索 qcm歌手
    func searchQQArtists(keyword: String, page: Int = 1, num: Int = 30) -> AnyPublisher<[ArtistInfo], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let result = try await self.qqClient.search(
                keyword: keyword,
                type: .singer,
                num: num,
                page: page,
                highlight: false
            )
            let items = Self.extractSearchItems(from: result, itemKey: "singer")
            return items.compactMap { Self.convertQQArtistToArtistInfo($0) }
        }
    }
    
    /// 搜索 qcm歌单
    func searchQQPlaylists(keyword: String, page: Int = 1, num: Int = 30) -> AnyPublisher<[Playlist], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let result = try await self.qqClient.search(
                keyword: keyword,
                type: .songlist,
                num: num,
                page: page,
                highlight: false
            )
            let items = Self.extractSearchItems(from: result, itemKey: "item_songlist")
            return items.compactMap { Self.convertQQPlaylistToPlaylist($0) }
        }
    }
    
    /// 搜索 qcm专辑
    func searchQQAlbums(keyword: String, page: Int = 1, num: Int = 30) -> AnyPublisher<[SearchAlbum], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let result = try await self.qqClient.search(
                keyword: keyword,
                type: .album,
                num: num,
                page: page,
                highlight: false
            )
            let items = Self.extractSearchItems(from: result, itemKey: "item_album")
            return items.compactMap { Self.convertQQAlbumToSearchAlbum($0) }
        }
    }
}

// MARK: - qcm播放 URL

extension APIService {
    
    /// QQ 音质结果（含可选 ekey）
    private struct QQQualityResult {
        let url: String
        let ekey: String?
    }
    
    /// 获取 qcm歌曲播放 URL（仅走普通接口，不走加密）
    ///
    /// - quality 传入指定音质时，会从该档开始自动向下回退
    /// - quality 传入 nil 时，优先使用预缓存的音质，否则查询可用音质从高到低逐个尝试
    /// - prefetchedQuality: 预查询缓存的最佳音质（由 PlayerManager 传入）
    func fetchQQSongUrl(
        mid: String,
        quality: QQMusicQuality? = nil,
        prefetchedQuality: QQMusicQuality? = nil
    ) -> AnyPublisher<SongUrlResult, Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { throw PlaybackError.unavailable }
            if await MainActor.run(body: { OnlineAccessManager.shared.lastTokenStatus }) == .expired {
                throw PlaybackError.tokenExpired
            }
            if await MainActor.run(body: { OnlineAccessManager.shared.lastTokenStatus }) == .missing {
                throw PlaybackError.tokenRequired
            }

            let availableInfos: [QQSongQualityInfo]?
            do {
                let infos = try await self.queryQQSongQualities(mid: mid)
                availableInfos = infos
                if !infos.isEmpty {
                    AppLogger.info("[QQMusic] 可用音质: \(infos.map { $0.quality.displayName }.joined(separator: " > "))")
                }
            } catch {
                availableInfos = nil
                AppLogger.warning("[QQMusic] 音质查询失败，按回退链盲试: \(error.localizedDescription)")
            }

            let candidates = self.buildQQPlaybackCandidates(
                preferred: quality,
                prefetched: prefetchedQuality,
                availableInfos: availableInfos
            )

            if candidates.isEmpty {
                let fallbackQuality = quality ?? prefetchedQuality ?? .mp3_320
                AppLogger.warning("[QQMusic] 无可用音质信息，兜底尝试: \(fallbackQuality.displayName)")
                if let result = await self.tryQQQuality(mid: mid, quality: fallbackQuality) {
                    return SongUrlResult(url: result.url, isUnblocked: false, qmcEkey: result.ekey, actualQQQuality: fallbackQuality)
                }
                throw PlaybackError.unavailable
            }

            for candidate in candidates {
                AppLogger.info("[QQMusic] 尝试: \(candidate.displayName)")
                if let result = await self.tryQQQuality(mid: mid, quality: candidate) {
                    AppLogger.success("[QQMusic] \(candidate.displayName) 获取成功")
                    return SongUrlResult(url: result.url, isUnblocked: false, qmcEkey: result.ekey, actualQQQuality: candidate)
                }
            }

            AppLogger.error("[QQMusic] 所有回退音质均无法获取播放 URL: \(mid)")
            throw PlaybackError.unavailable
        }
    }
    
    /// 获取 qcm歌曲下载 URL（走 _download=1 解密下载通道）
    ///
    /// 后端路由: `/song/get_song_urls?mid=xxx&file_type=MASTER&_download=1`
    /// 返回 url + ekey，客户端下载后用 ekey 本地 QMC 解密
    func fetchQQDownloadUrl(
        mid: String,
        quality: QQMusicQuality
    ) -> AnyPublisher<SongUrlResult, Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { throw PlaybackError.unavailable }

            let candidates = QQMusicQuality.fallbackCandidates(from: quality)

            for candidate in candidates {
                AppLogger.info("[QQMusic Download] 尝试下载音质: \(candidate.displayName)")
                do {
                    if let result = try await self.withContentSession({ client in
                        try await client.downloadSongURL(mid: mid, fileType: candidate.fileType)
                    }), !result.url.isEmpty {
                        AppLogger.success("[QQMusic Download] \(candidate.displayName) 获取成功 (ekey: \(result.ekey.prefix(16))...)")
                        return SongUrlResult(
                            url: result.url,
                            isUnblocked: false,
                            qmcEkey: result.ekey.isEmpty ? nil : result.ekey,
                            actualQQQuality: candidate
                        )
                    }
                } catch {
                    AppLogger.warning("[QQMusic Download] \(candidate.displayName) 失败: \(error.localizedDescription)")
                }
            }

            AppLogger.error("[QQMusic Download] 所有音质均无法获取下载 URL: \(mid)")
            throw PlaybackError.unavailable
        }
    }

    /// 查询 qcm歌曲可用音质
    func prefetchQQQualities(mid: String) async throws -> [QQSongQualityInfo] {
        try await queryQQSongQualities(mid: mid)
    }
    
    /// 查询 qcm歌曲可用音质（内部 async 版本）
    private func queryQQSongQualities(mid: String) async throws -> [QQSongQualityInfo] {
        let result = try await self.withContentSession { client in
            try await client.songQualities(mid: mid)
        }
        guard let qualities = result["qualities"]?.arrayValue else { return [] }
        return qualities.compactMap { item -> QQSongQualityInfo? in
            guard let code = item["code"]?.stringValue,
                  let quality = QQMusicQuality(rawValue: code) else { return nil }
            return QQSongQualityInfo(
                quality: quality,
                name: item["name"]?.stringValue ?? quality.displayName,
                bitrate: item["bitrate"]?.intValue ?? 0,
                size: item["size"]?.intValue ?? 0
            )
        }
    }
    
    private func buildQQPlaybackCandidates(
        preferred: QQMusicQuality?,
        prefetched: QQMusicQuality?,
        availableInfos: [QQSongQualityInfo]?
    ) -> [QQMusicQuality] {
        var candidates = QQMusicQuality.fallbackCandidates(from: preferred)
        
        if let availableInfos {
            let available = Set(availableInfos.map(\.quality))
            let premiumList: Set<QQMusicQuality> = [.master, .atmos2, .atmos51]
            candidates = candidates.filter { available.contains($0) || premiumList.contains($0) }
        }
        
        if let prefetched,
           let index = candidates.firstIndex(of: prefetched) {
            candidates.remove(at: index)
            candidates.insert(prefetched, at: 0)
        }
        
        return candidates
    }

    /// 当开启 QMC 解密时，把所有“支持加密接口”的可用音质提前。
    /// 这样即便当前默认是 MP3/AAC，也会先尝试这首歌可用的 OGG/FLAC/MASTER 等加密流。
    /// 尝试获取指定音质的播放 URL（仅走普通接口，不走加密）
    private func tryQQQuality(
        mid: String,
        quality: QQMusicQuality
    ) async -> QQQualityResult? {
        do {
            if let url = try await qqClient.songURL(mid: mid, fileType: quality.fileType),
               !url.isEmpty {
                AppLogger.success("[QQMusic] \(quality.displayName) 获取成功")
                return QQQualityResult(url: url, ekey: nil)
            }
        } catch {
            AppLogger.debug("[QQMusic] \(quality.displayName) 获取失败: \(error.localizedDescription)")
        }
        AppLogger.warning("[QQMusic] \(quality.displayName) 返回空")
        return nil
    }
    
}


// MARK: - qcm推荐

extension APIService {
    
    /// 获取 qcm推荐歌单（已登录用户走用户 session 获取个性化推荐）
    func fetchQQRecommendPlaylists() -> AnyPublisher<[Playlist], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let result = try await self.withContentSession { client in
                try await client.recommendSonglist()
            }
            AppLogger.debug("[QQMusic] 推荐歌单原始响应 keys: \(result.objectValue?.keys.joined(separator: ",") ?? String(localized: "非对象"))")
            
            // API 返回结构: { List: [{ Playlist: { basic: { tid, title, cover, ... } } }] }
            let listArray: [JSON]
            if let arr = result["List"]?.arrayValue, !arr.isEmpty {
                listArray = arr
            } else if let arr = result["list"]?.arrayValue, !arr.isEmpty {
                listArray = arr
            } else if let arr = result["Playlist"]?.arrayValue, !arr.isEmpty {
                listArray = arr
            } else if let arr = result["playlist"]?.arrayValue, !arr.isEmpty {
                listArray = arr
            } else if let arr = result["data"]?.arrayValue, !arr.isEmpty {
                listArray = arr
            } else {
                listArray = Self.extractJSONArray(from: result)
            }
            
            // 每个元素可能是 { Playlist: { basic: {...} } } 嵌套结构，需要展开到 basic 层
            let playlists = listArray.compactMap { item -> Playlist? in
                // 新版 API: item.Playlist.basic 包含歌单信息
                if let basic = item["Playlist"]?["basic"] {
                    return Self.convertQQRecommendPlaylist(basic)
                }
                // 兜底：直接尝试旧的扁平结构
                return Self.convertQQPlaylistToPlaylist(item)
            }
            AppLogger.info("[QQMusic] 推荐歌单: 原始\(listArray.count)条, 转换\(playlists.count)条")
            return playlists
        }
    }
    
    /// 获取 qcm推荐新歌（已登录用户走用户 session）
    func fetchQQRecommendNewSongs() -> AnyPublisher<[Song], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let result = try await self.withContentSession { client in
                try await client.recommendNewSong()
            }
            AppLogger.debug("[QQMusic] 推荐新歌原始响应 keys: \(result.objectValue?.keys.joined(separator: ",") ?? String(localized: "非对象"))")
            let songArray: [JSON]
            if let arr = result["songlist"]?.arrayValue, !arr.isEmpty {
                songArray = arr
            } else if let lanlist = result["lanlist"]?.arrayValue,
                      let first = lanlist.first,
                      let arr = first["songlist"]?.arrayValue, !arr.isEmpty {
                songArray = arr
            } else if let arr = result["list"]?.arrayValue, !arr.isEmpty {
                songArray = arr
            } else {
                songArray = Self.extractJSONArray(from: result)
            }
            let songs = songArray.compactMap { Self.convertQQSongToSong($0) }
            AppLogger.info("[QQMusic] 推荐新歌: 原始\(songArray.count)条, 转换\(songs.count)条")
            return songs
        }
    }
    
    /// 获取 qcm歌单分类标签
    func fetchQQPlaylistCategories() -> AnyPublisher<[(id: Int, name: String)], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let result = try await self.qqClient.requestWrapped("/recommend/get_songlist_categories") as JSON
            guard let groups = result["v_group"]?.arrayValue else { return [] }
            var categories: [(id: Int, name: String)] = []
            var seenIds = Set<Int>()
            for group in groups {
                if let items = group["v_item"]?.arrayValue {
                    for item in items {
                        if let id = item["id"]?.intValue, let name = item["name"]?.stringValue, !seenIds.contains(id) {
                            seenIds.insert(id)
                            categories.append((id: id, name: name))
                        }
                    }
                }
            }
            return categories
        }
    }

    /// 按分类获取 qcm歌单列表（支持分页）
    func fetchQQPlaylistsByCategory(categoryId: Int, sortId: Int = 5, page: Int = 0, size: Int = 30) -> AnyPublisher<(playlists: [Playlist], hasMore: Bool), Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return (playlists: [], hasMore: false) }
            let result: JSON = try await self.qqClient.requestWrapped("/recommend/get_songlist_by_category", params: [
                "category_id": String(categoryId),
                "sort_id": String(sortId),
                "page": String(page),
                "size": String(size),
            ])
            guard let list = result["v_playlist"]?.arrayValue else { return (playlists: [], hasMore: false) }
            let playlists: [Playlist] = list.compactMap { json -> Playlist? in
                guard let obj = json.objectValue else { return nil }
                let id = obj["dissid"]?.intValue ?? obj["tid"]?.intValue ?? 0
                let name = obj["title"]?.stringValue ?? obj["diss_name"]?.stringValue ?? ""
                let cover = obj["cover_url_big"]?.stringValue ?? obj["cover_url_medium"]?.stringValue ?? obj["logo"]?.stringValue ?? obj["diss_cover"]?.stringValue ?? ""
                let count = obj["song_cnt"]?.intValue ?? obj["cur_song_num"]?.intValue ?? 0
                let playCount = obj["access_num"]?.intValue ?? obj["listennum"]?.intValue ?? 0
                guard id > 0 else { return nil }
                return Playlist(id: id, name: name, coverImgUrl: cover, picUrl: nil, trackCount: count, playCount: playCount, subscribedCount: nil, shareCount: nil, commentCount: nil, creator: nil, description: nil, tags: nil, source: .qqmusic)
            }
            let total = result["total"]?.intValue ?? 0
            return (playlists: playlists, hasMore: playlists.count >= size || total > (page + 1) * size)
        }
    }
}

// MARK: - qcm歌手列表

extension APIService {
    
    /// 获取 qcm歌手列表（热门）
    func fetchQQSingerList(area: AreaType = .all, sex: SexType = .all, genre: GenreType = .all) -> AnyPublisher<[ArtistInfo], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let results = try await self.qqClient.singerList(area: area, sex: sex, genre: genre)
            let artists = results.compactMap { Self.convertQQArtistToArtistInfo($0) }
            AppLogger.info("[QQMusic] 歌手列表: 原始\(results.count)条, 转换\(artists.count)条")
            return artists
        }
    }
    
    /// 获取 qcm歌手列表（分页，支持首字母索引）
    func fetchQQSingerListIndex(
        area: AreaType = .all,
        sex: SexType = .all,
        genre: GenreType = .all,
        index: Int = -100,
        sin: Int = 0,
        curPage: Int = 1
    ) -> AnyPublisher<(artists: [ArtistInfo], total: Int), Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return ([], 0) }
            let result = try await self.qqClient.singerListIndex(
                area: area, sex: sex, genre: genre,
                index: index, sin: sin, curPage: curPage
            )
            let singerArray = Self.extractJSONArray(from: result)
            let total = result["total"]?.intValue ?? singerArray.count
            let artists = singerArray.compactMap { Self.convertQQArtistToArtistInfo($0) }
            AppLogger.info("[QQMusic] 歌手列表(分页): 原始\(singerArray.count)条, 转换\(artists.count)条, total=\(total)")
            return (artists, total)
        }
    }
}

// MARK: - qcm排行榜

extension APIService {
    
    /// 获取 qcm排行榜分类
    /// API 返回结构: { group: [{ groupId, groupName, toplist: [{topId, title, ...}] }] }
    func fetchQQTopCategory() -> AnyPublisher<[QQTopListGroup], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let rawResult = try await self.qqClient.topCategory()
            let results = rawResult["group"]?.arrayValue ?? rawResult.arrayValue ?? []
            AppLogger.debug("[QQMusic] 排行榜原始: \(results.count)组")
            
            var groups: [QQTopListGroup] = []
            for (index, group) in results.enumerated() {
                let groupId = group["groupId"]?.intValue ?? group["group_id"]?.intValue ?? index
                let groupName = group["groupName"]?.stringValue ?? group["group_name"]?.stringValue ?? String(localized: "排行榜")
                
                var items: [QQTopListItem] = []
                if let toplist = group["toplist"]?.arrayValue ?? group["list"]?.arrayValue {
                    items = toplist.compactMap { Self.convertQQTopListItem($0) }
                } else if let item = Self.convertQQTopListItem(group) {
                    items.append(item)
                }
                
                if !items.isEmpty {
                    groups.append(QQTopListGroup(groupId: groupId, groupName: groupName, items: items))
                }
            }
            AppLogger.info("[QQMusic] 排行榜分类: \(groups.count)组, 共\(groups.flatMap(\.items).count)条")
            return groups
        }
    }
    
    
    /// 将 QQ 排行榜 JSON 转为模型
    static func convertQQTopListItem(_ json: JSON) -> QQTopListItem? {
        let topId = json["topId"]?.intValue ?? json["topID"]?.intValue
            ?? json["top_id"]?.intValue ?? json["id"]?.intValue
        guard let topId = topId else { return nil }
        
        let title = json["title"]?.stringValue ?? json["name"]?.stringValue
            ?? json["ListName"]?.stringValue ?? ""
        
        var coverUrl = json["headPicUrl"]?.stringValue ?? json["frontPicUrl"]?.stringValue
        if coverUrl == nil || coverUrl?.isEmpty == true {
            coverUrl = json["cover"]?.stringValue ?? json["pic"]?.stringValue
        }
        
        let intro = json["intro"]?.stringValue ?? json["updateTips"]?.stringValue ?? ""
        let period = json["period"]?.stringValue ?? ""
        let updateTime = json["updateTime"]?.stringValue ?? ""
        
        return QQTopListItem(
            topId: topId,
            title: title,
            coverUrl: coverUrl,
            intro: intro,
            period: period,
            updateTime: updateTime
        )
    }
}

/// qcm排行榜项
struct QQTopListItem: Identifiable, Codable, Hashable {
    let topId: Int
    let title: String
    let coverUrl: String?
    let intro: String
    let period: String
    let updateTime: String
    
    var id: Int { topId }
    
    var coverURL: URL? {
        guard let str = coverUrl, !str.isEmpty else { return nil }
        return URL(string: str)
    }
}

struct QQTopListGroup: Identifiable, Codable, Hashable {
    let groupId: Int
    let groupName: String
    let items: [QQTopListItem]
    
    var id: Int { groupId }
}

// MARK: - qcm歌词

extension APIService {
    
    /// 获取 qcm歌词
    func fetchQQLyric(mid: String) -> AnyPublisher<QQLyricResponse, Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return QQLyricResponse(lyric: nil, qrc: nil, trans: nil) }
            let result = try await self.qqClient.lyric(
                value: mid,
                qrc: true,
                trans: true,
                roma: false
            )
            return QQLyricResponse(
                lyric: result.lyric,
                qrc: result.qrc,
                trans: result.trans
            )
        }
    }
}

/// qcm歌词响应
struct QQLyricResponse: Sendable {
    let lyric: String?
    let qrc: String?
    let trans: String?
}

// MARK: - qcm热搜

extension APIService {
    
    /// 获取 qcm热搜词
    func fetchQQHotSearch() -> AnyPublisher<[HotSearchItem], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            do {
                let result = try await self.qqClient.hotkey()
                return Self.convertQQHotkeys(result)
            } catch {
                AppLogger.error("[QQMusic] 获取热搜失败: \(error)")
                return []
            }
        }
    }
}

// MARK: - qcm歌曲音质查询

extension APIService {
    
    /// 查询歌曲可用音质列表
    /// - Parameter mid: 歌曲 mid
    /// - Returns: 该歌曲支持的音质列表（按 bitrate 从高到低排序）
    func fetchQQSongQualities(mid: String) -> AnyPublisher<[QQSongQualityInfo], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let result = try await self.withContentSession { client in
                try await client.songQualities(mid: mid)
            }
            guard let qualities = result["qualities"]?.arrayValue else {
                AppLogger.warning("[QQMusic] 歌曲音质查询: 无 qualities 字段")
                return []
            }
            let infos = qualities.compactMap { item -> QQSongQualityInfo? in
                guard let code = item["code"]?.stringValue,
                      let quality = QQMusicQuality(rawValue: code) else { return nil }
                return QQSongQualityInfo(
                    quality: quality,
                    name: item["name"]?.stringValue ?? quality.displayName,
                    bitrate: item["bitrate"]?.intValue ?? 0,
                    size: item["size"]?.intValue ?? 0
                )
            }
            AppLogger.info("[QQMusic] 歌曲音质: \(infos.count)种可用")
            return infos
        }
    }
}

/// 歌曲可用音质信息
struct QQSongQualityInfo: Identifiable, Sendable {
    let quality: QQMusicQuality
    let name: String
    let bitrate: Int
    let size: Int
    
    var id: String { quality.rawValue }
    
    var sizeText: String {
        if size >= 1_048_576 {
            return String(format: "%.1f MB", Double(size) / 1_048_576)
        } else if size >= 1024 {
            return String(format: "%.0f KB", Double(size) / 1024)
        }
        return "\(size) B"
    }
}


// MARK: - qcm歌手详情

extension APIService {
    
    /// 获取 qcm歌手歌曲
    func fetchQQSingerSongs(mid: String, page: Int = 1, num: Int = 30) -> AnyPublisher<[Song], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let begin = (page - 1) * num
            let result = try await self.qqClient.singerSongsList(mid: mid, number: num, begin: begin)
            let songArray = Self.extractJSONArray(from: result)
            if let first = songArray.first {
                AppLogger.debug("[QQMusic] 歌手歌曲第一条: \(first)")
            }
            let songs = songArray.compactMap { Self.convertQQSongToSong($0) }
            AppLogger.info("[QQMusic] 歌手歌曲: 原始\(songArray.count)条, 转换成功\(songs.count)条")
            return songs
        }
    }
    
    /// 获取 qcm歌手信息
    func fetchQQSingerInfo(mid: String) -> AnyPublisher<JSON, Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { throw PlaybackError.unavailable }
            return try await self.qqClient.singerInfo(mid: mid)
        }
    }

    /// 获取 qcm歌手简介（wiki 页面 → singerTabDetail → singerDesc）
    func fetchQQSingerDesc(mid: String) -> AnyPublisher<String, Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { throw PlaybackError.unavailable }

            // 1. 从 singerDesc 取 wikiurl，抓取完整 wiki 页面内容
            var wikiUrl: String?
            do {
                let desc = try await self.qqClient.singerDesc(mids: mid)
                for item in desc {
                    if let d = item["desc"]?.stringValue ?? item["brief"]?.stringValue
                        ?? item["wiki"]?.stringValue ?? item["SingerDesc"]?.stringValue,
                       !d.isEmpty {
                        return d
                    }
                    if let url = item["basic_info"]?["wikiurl"]?.stringValue, !url.isEmpty {
                        wikiUrl = url
                    }
                }
            } catch {
                AppLogger.error("[QQMusic] singerDesc 请求失败: \(error)")
            }

            // 2. 抓取 wiki 页面提取纯文本简介
            if let urlStr = wikiUrl, let url = URL(string: urlStr) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let html = String(data: data, encoding: .utf8) {
                        let text = Self.extractWikiText(from: html)
                        if !text.isEmpty {
                            return text
                        }
                    }
                } catch {
                    AppLogger.error("[QQMusic] wiki 页面抓取失败: \(error)")
                }
            }

            // 3. fallback: singerTabDetail wiki tab 摘要
            do {
                let wikiItems = try await self.qqClient.singerTabDetail(mid: mid, tabType: .wiki, page: 1, num: 10)
                for item in wikiItems {
                    if let list = item["SingerInfoList"]?.arrayValue {
                        for entry in list {
                            if let content = entry["Content"]?.stringValue, !content.isEmpty {
                                return content
                            }
                        }
                    }
                }
            } catch {
                AppLogger.error("[QQMusic] singerTabDetail wiki 请求失败: \(error)")
            }

            return ""
        }
    }

    /// 从 qcm wiki HTML 页面提取纯文本简介
    private static func extractWikiText(from html: String) -> String {
        // 尝试提取 <div class="intro__body"> 或 JSON 数据中的简介
        // wiki 页面通常在 window.__INITIAL_DATA__ 或 <meta name="description"> 中包含简介

        // 方案1: meta description
        if let range = html.range(of: "name=\"description\"\\s+content=\"([^\"]+)\"",
                                   options: .regularExpression) {
            let match = String(html[range])
            if let contentRange = match.range(of: "content=\""),
               let endRange = match.range(of: "\"", range: match.index(contentRange.upperBound, offsetBy: 0)..<match.endIndex) {
                let content = String(match[contentRange.upperBound..<endRange.lowerBound])
                let decoded = content.replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#39;", with: "'")
                if decoded.count > 20 {
                    return decoded
                }
            }
        }

        // 方案2: 简单 HTML 标签清理，提取正文段落
        var text = html
        // 移除 script/style 块
        text = text.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>",
                                          with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>",
                                          with: "", options: .regularExpression)
        // 移除所有 HTML 标签
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // 清理空白
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 从中找到较长的中文段落（简介通常是最长的连续中文文本）
        let paragraphs = text.components(separatedBy: "  ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 50 }

        if let longest = paragraphs.max(by: { $0.count < $1.count }) {
            return longest
        }

        return ""
    }
}

// MARK: - qcm歌手专辑 & MV

extension APIService {
    
    /// 获取 qcm歌手专辑列表
    func fetchQQSingerAlbums(mid: String, num: Int = 20, begin: Int = 0) -> AnyPublisher<[AlbumInfo], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let result = try await self.qqClient.singerAlbums(mid: mid, number: num, begin: begin)
            AppLogger.debug("[QQMusic] 歌手专辑原始: \(result)")
            let albumArray = Self.extractJSONArray(from: result)
            if albumArray.isEmpty {
                AppLogger.warning("[QQMusic] 歌手专辑: 无法提取数组，原始keys: \(result.objectValue?.keys.joined(separator: ",") ?? String(localized: "非对象"))")
            }
            let albums: [AlbumInfo] = albumArray.compactMap { Self.convertQQSingerAlbum($0) }
            AppLogger.info("[QQMusic] 歌手专辑: 原始\(albumArray.count)条, 转换\(albums.count)条")
            return albums
        }
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
            subType: nil,
            qqAlbumMid: albumMid.isEmpty ? nil : albumMid
        )
    }
    
    /// 获取 qcm歌手 MV 列表
    func fetchQQSingerMVs(mid: String, num: Int = 20, begin: Int = 0) -> AnyPublisher<[QQMV], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let result = try await self.qqClient.singerMVs(mid: mid, number: num, begin: begin)
            AppLogger.debug("[QQMusic] 歌手MV原始: \(result)")
            let mvArray = Self.extractJSONArray(from: result)
            if mvArray.isEmpty {
                AppLogger.warning("[QQMusic] 歌手MV: 无法提取数组，原始keys: \(result.objectValue?.keys.joined(separator: ",") ?? String(localized: "非对象"))")
            }
            if let first = mvArray.first {
                AppLogger.debug("[QQMusic] 歌手MV第一项: \(first)")
            }
            let mvs = mvArray.compactMap { Self.convertQQSingerMV($0, singerMid: mid) }
            AppLogger.info("[QQMusic] 歌手MV: 原始\(mvArray.count)条, 转换\(mvs.count)条")
            return mvs
        }
    }
    
    private static let qqDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    /// QQ 日期字符串 → 毫秒时间戳
    static func qqDateStringToTimestamp(_ dateStr: String) -> Int? {
        if let date = qqDateFormatter.date(from: dateStr) {
            return Int(date.timeIntervalSince1970 * 1000)
        }
        return nil
    }
    
    /// 从 JSON 中提取首个非空数组（适配常见 QQ 接口结构）
    static func extractJSONArray(from json: JSON) -> [JSON] {
        // 直接是数组
        if let arr = json.arrayValue, !arr.isEmpty { return arr }
        // 是对象，尝试常见 key
        if let obj = json.objectValue {
            let priorityKeys = [
                "songList", "song_list",
                "albumList", "album_list",
                "mvList", "mv_list",
                "list", "data", "songlist", "songs", "items"
            ]
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

// MARK: - qcm专辑详情

extension APIService {
    
    /// 获取 qcm专辑歌曲
    func fetchQQAlbumSongs(albumMid: String, page: Int = 1, num: Int = 50) -> AnyPublisher<[Song], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let result: JSON = try await self.qqClient.requestWrapped(
                "/album/get_song",
                params: [
                    "value": albumMid,
                    "num": String(num),
                    "page": String(page)
                ]
            )
            let songArray = Self.extractJSONArray(from: result)
            if let first = songArray.first {
                AppLogger.debug("[QQMusic] 专辑歌曲第一条: \(first)")
            }
            let songs = songArray.compactMap { Self.convertQQSongToSong($0) }
            AppLogger.info("[QQMusic] 专辑歌曲: 原始\(songArray.count)条, 转换成功\(songs.count)条")
            return songs
        }
    }
    
    /// 获取 qcm专辑详情
    func fetchQQAlbumDetail(albumMid: String) -> AnyPublisher<JSON, Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { throw PlaybackError.unavailable }
            return try await self.qqClient.albumDetail(value: albumMid)
        }
    }
}

// MARK: - qcm MV 搜索与播放

extension APIService {
    
    /// 搜索 qcm MV
    func searchQQMVs(keyword: String, page: Int = 1, num: Int = 30) -> AnyPublisher<[QQMV], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let result = try await self.qqClient.search(
                keyword: keyword,
                type: .mv,
                num: num,
                page: page,
                highlight: false
            )
            let items = Self.extractSearchItems(from: result, itemKey: "item_mv")
            return items.compactMap { Self.convertQQSearchMV($0) }
        }
    }
    
    /// 获取 qcm MV 播放 URL
    func fetchQQMVUrl(vid: String) -> AnyPublisher<String?, Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return nil }
            let result = try await self.qqClient.mvURLs(vids: vid)
            AppLogger.debug("[QQMusic] MV URL 原始返回: \(result)")
            
            if let url = Self.extractMVUrl(from: result) {
                AppLogger.info("[QQMusic] MV URL 提取成功: \(url.prefix(80))...")
                return url
            }
            
            AppLogger.warning("[QQMusic] MV URL 为空: vid=\(vid)")
            return nil
        }
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
    
    /// 获取 qcm MV 详情
    func fetchQQMVDetail(vid: String) -> AnyPublisher<QQMV?, Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return nil }
            let result = try await self.qqClient.mvDetail(vids: vid)
            if let arr = result.arrayValue, let first = arr.first {
                return Self.convertQQDetailMV(first)
            } else if let obj = result.objectValue, let first = obj.values.first {
                return Self.convertQQDetailMV(first)
            } else {
                return Self.convertQQDetailMV(result)
            }
        }
    }
}

// MARK: - qcm歌单详情

extension APIService {
    
    /// 获取 qcm歌单歌曲
    func fetchQQPlaylistSongs(playlistId: Int, page: Int = 1, num: Int = 50) -> AnyPublisher<[Song], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let result = try await self.qqClient.songlistDetail(
                songlistId: playlistId, num: num, page: page, onlySong: true
            )
            AppLogger.debug("[QQMusic] 歌单歌曲原始响应: \(result)")
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
            return songArray.compactMap { Self.convertQQSongToSong($0) }
        }
    }
    
    /// 获取 qcm歌单详情（封面、描述等）
    func fetchQQPlaylistDetail(playlistId: Int) -> AnyPublisher<JSON, Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { throw PlaybackError.unavailable }
            return try await self.qqClient.songlistDetail(
                songlistId: playlistId, num: 0, page: 1, onlySong: false
            )
        }
    }
    
    /// 获取 qcm排行榜歌曲（通过 topDetail 获取）
    func fetchQQTopSongs(topId: Int, page: Int = 1, num: Int = 100) -> AnyPublisher<[Song], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            let result = try await self.qqClient.topDetail(topId: topId, num: num, page: page)
            let songArray: [JSON]
            if let songs = result["songInfoList"]?.arrayValue {
                songArray = songs
            } else if let songs = result["songlist"]?.arrayValue {
                songArray = songs
            } else if let arr = result.arrayValue {
                songArray = arr
            } else {
                songArray = Self.extractJSONArray(from: result)
            }
            let songs = songArray.compactMap { Self.convertQQSongToSong($0) }
            AppLogger.info("[QQMusic] 排行榜歌曲: 原始\(songArray.count)条, 转换\(songs.count)条")
            return songs
        }
    }
}

