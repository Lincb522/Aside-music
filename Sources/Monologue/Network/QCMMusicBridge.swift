// QQMusicBridge.swift
// qcm数据模型转换
// 将 QQMusicKit 的 JSON 响应转换为 Monologue 的统一模型

import Foundation
import QQMusicKit

// MARK: - qcm → Song 转换

extension APIService {
    
    /// 将 qcm搜索结果转换为 Song
    static func convertQQSongToSong(_ json: JSON) -> Song? {
        let payload = json["songInfo"] ?? json["song_info"] ?? json

        // qcm搜索结果结构：
        // { id, mid, name, singer: [{id, mid, name}], album: {id, mid, name, pmid}, interval, ... }
        let songId = payload["id"]?.intValue ?? payload["songid"]?.intValue
        let name = payload["name"]?.stringValue ?? payload["title"]?.stringValue ?? payload["songname"]?.stringValue
        
        guard let songId = songId, let name = name else {
            AppLogger.debug("[QQBridge] Song 转换失败，原始JSON前100字符: \(String(describing: payload).prefix(200))")
            return nil
        }
        
        let mid = payload["mid"]?.stringValue
        
        // 解析歌手
        var artists: [Artist] = []
        var firstArtistMid: String?  // 保存第一个歌手的 mid
        if let singerArray = payload["singer"]?.arrayValue {
            for (index, singer) in singerArray.enumerated() {
                let singerId = singer["id"]?.intValue ?? 0
                let singerName = singer["name"]?.stringValue ?? ""
                let singerMid = singer["mid"]?.stringValue
                if !singerName.isEmpty {
                    artists.append(Artist(id: singerId, name: singerName))
                }
                // 保存第一个歌手的 mid
                if index == 0, let mid = singerMid, !mid.isEmpty {
                    firstArtistMid = mid
                }
            }
        }
        
        // 解析专辑
        var album: Album?
        let albumMid = payload["album"]?["mid"]?.stringValue ?? payload["album"]?["pmid"]?.stringValue
        if let albumDict = payload["album"] {
            let albumId = albumDict["id"]?.intValue ?? 0
            let albumName = albumDict["name"]?.stringValue ?? ""
            // qcm专辑封面 URL 格式
            let picUrl: String?
            if let pmid = albumDict["pmid"]?.stringValue, !pmid.isEmpty {
                picUrl = "https://y.gtimg.cn/music/photo_new/T002R300x300M000\(pmid).jpg"
            } else if let amid = albumDict["mid"]?.stringValue, !amid.isEmpty {
                picUrl = "https://y.gtimg.cn/music/photo_new/T002R300x300M000\(amid).jpg"
            } else {
                picUrl = nil
            }
            album = Album(id: albumId, name: albumName, picUrl: picUrl)
        }
        
        // 时长（qcm用 interval 秒，ncm用 dt 毫秒）
        let intervalSec = payload["interval"]?.intValue
        let dt = intervalSec.map { $0 * 1000 }
        
        // 是否 VIP（pay.pay_play == 1）
        let fee: Int?
        if let payPlay = payload["pay"]?["pay_play"]?.intValue, payPlay == 1 {
            fee = 1
        } else {
            fee = 0
        }
        
        // MV
        let mvId = payload["mv"]?["id"]?.intValue ?? payload["mv"]?["vid"]?.intValue ?? 0
        
        // 解析最高可用音质（从 file 字段判断）
        let qqMaxQuality: QQMusicQuality? = {
            if let file = payload["file"] {
                // 从 size_new 数组判断高级音质（索引: 0=母带, 1=臻品51, 2=臻品2, 5=OGG640, 6=OGG320）
                if let sizeNew = file["size_new"]?.arrayValue {
                    if sizeNew.count > 0, let s = sizeNew[0].intValue, s > 0 { return .master }
                    if sizeNew.count > 1, let s = sizeNew[1].intValue, s > 0 { return .atmos51 }
                    if sizeNew.count > 2, let s = sizeNew[2].intValue, s > 0 { return .atmos2 }
                    if sizeNew.count > 5, let s = sizeNew[5].intValue, s > 0 { return .ogg640 }
                    if sizeNew.count > 6, let s = sizeNew[6].intValue, s > 0 { return .ogg320 }
                }
                // 从传统 size 字段判断
                if let s = file["size_hires"]?.intValue, s > 0 { return .master }
                if let s = file["size_flac"]?.intValue, s > 0 { return .flac }
                if let s = file["size_320mp3"]?.intValue ?? file["size_320"]?.intValue, s > 0 { return .mp3_320 }
                if let s = file["size_ogg"]?.intValue ?? file["size_192ogg"]?.intValue, s > 0 { return .ogg192 }
                if let s = file["size_128mp3"]?.intValue ?? file["size_128"]?.intValue, s > 0 { return .mp3_128 }
                if let s = file["size_aac"]?.intValue ?? file["size_96aac"]?.intValue, s > 0 { return .aac96 }
            }
            if let payPlay = payload["pay"]?["pay_play"]?.intValue, payPlay == 1 {
                return .flac
            }
            return .mp3_320
        }()
        
        return Song(
            id: songId,
            name: name,
            ar: artists.isEmpty ? nil : artists,
            al: album,
            dt: dt,
            fee: fee,
            mv: mvId,
            h: nil, m: nil, l: nil, sq: nil, hr: nil,
            alia: nil,
            source: .qqmusic,
            qqMid: mid,
            qqAlbumMid: albumMid,
            qqArtistMid: firstArtistMid,
            qqMaxQuality: qqMaxQuality
        )
    }
    
    /// 将 qcm歌手转换为 ArtistInfo
    static func convertQQArtistToArtistInfo(_ json: JSON) -> ArtistInfo? {
        // 打印原始 JSON 帮助调试字段名
        AppLogger.debug("[QQBridge] 歌手原始JSON: \(json)")
        
        // 尝试多种字段名
        let singerId = json["singerID"]?.intValue
            ?? json["singer_id"]?.intValue
            ?? json["id"]?.intValue
            ?? json["singerid"]?.intValue
            ?? 0
        
        let name = json["singerName"]?.stringValue
            ?? json["singer_name"]?.stringValue
            ?? json["name"]?.stringValue
            ?? json["title"]?.stringValue
        
        guard let name = name, !name.isEmpty else {
            AppLogger.warning("[QQBridge] 歌手转换失败: 无法获取名称")
            return nil
        }
        
        let mid = json["singerMID"]?.stringValue
            ?? json["singer_mid"]?.stringValue
            ?? json["mid"]?.stringValue
        
        let picUrl: String?
        if let raw = json["singerPic"]?.stringValue
            ?? json["singer_pic"]?.stringValue
            ?? json["pic"]?.stringValue
            ?? json["pic_url"]?.stringValue,
           !raw.isEmpty {
            picUrl = raw.replacingOccurrences(of: "http://", with: "https://")
        } else if let singerMid = mid, !singerMid.isEmpty {
            picUrl = "https://y.gtimg.cn/music/photo_new/T001R300x300M000\(singerMid).jpg"
        } else {
            picUrl = nil
        }
        
        let songNum = json["songNum"]?.intValue
            ?? json["song_num"]?.intValue
            ?? json["songnum"]?.intValue
        let albumNum = json["albumNum"]?.intValue
            ?? json["album_num"]?.intValue
            ?? json["albumnum"]?.intValue
        let mvNum = json["mvNum"]?.intValue
            ?? json["mv_num"]?.intValue
            ?? json["mvnum"]?.intValue
        
        return ArtistInfo(
            id: singerId,
            name: name,
            picUrl: picUrl,
            img1v1Url: picUrl,
            cover: nil,
            avatar: nil,
            musicSize: songNum,
            albumSize: albumNum,
            mvSize: mvNum,
            briefDesc: nil,
            alias: nil,
            followed: nil,
            accountId: nil,
            source: .qqmusic,
            qqMid: mid
        )
    }
    
    /// 将 qcm歌单转换为 Playlist
    static func convertQQPlaylistToPlaylist(_ json: JSON) -> Playlist? {
        AppLogger.debug("[QQBridge] 歌单原始JSON: \(json)")
        
        // 歌单 ID：尝试多种字段
        let idValue: Int?
        if let dissid = json["dissid"]?.stringValue, let parsed = Int(dissid) {
            idValue = parsed
        } else if let dissid = json["dissid"]?.intValue {
            idValue = dissid
        } else if let tid = json["tid"]?.stringValue, let parsed = Int(tid) {
            idValue = parsed
        } else if let tid = json["tid"]?.intValue {
            idValue = tid
        } else if let id = json["id"]?.intValue {
            idValue = id
        } else {
            idValue = nil
        }
        
        guard let id = idValue else {
            AppLogger.warning("[QQBridge] 歌单转换失败: 无法获取 ID")
            return nil
        }
        
        let name = json["dissname"]?.stringValue
            ?? json["diss_name"]?.stringValue
            ?? json["title"]?.stringValue
            ?? json["name"]?.stringValue
            ?? ""
        
        let urlKeys = ["cover_url_big", "imgurl", "logo", "cover", "cover_url_medium", "pic_url", "coverImgUrl"]
        var coverUrl = urlKeys.compactMap { json[$0]?.stringValue }.first(where: { !$0.isEmpty })
        coverUrl = coverUrl?.replacingOccurrences(of: "/300?", with: "/600?")
            .replacingOccurrences(of: "/300&", with: "/600&")
            .replacingOccurrences(of: "http://", with: "https://")
        
        let playCountKeys = ["listennum", "listen_num", "accessnum", "access_num", "play_count"]
        let playCount = playCountKeys.compactMap { json[$0]?.intValue }.first ?? 0
        let trackCount = json["song_count"]?.intValue
            ?? json["songcount"]?.intValue
            ?? json["total_song_num"]?.intValue
            ?? 0
        
        // 创建者
        var creator: PlaylistCreator?
        if let creatorObj = json["creator"] ?? json["creator_info"] {
            let creatorName = creatorObj["name"]?.stringValue
                ?? creatorObj["nick"]?.stringValue
                ?? creatorObj["nickname"]?.stringValue
            if let creatorName = creatorName {
                let creatorId = creatorObj["encrypt_uin"]?.intValue
                    ?? creatorObj["creator_uin"]?.intValue
                    ?? 0
                creator = PlaylistCreator(
                    userId: creatorId,
                    nickname: creatorName,
                    avatarUrl: creatorObj["avatarUrl"]?.stringValue ?? creatorObj["avatar"]?.stringValue
                )
            }
        }
        
        return Playlist(
            id: id,
            name: name,
            coverImgUrl: coverUrl,
            picUrl: nil,
            trackCount: trackCount,
            playCount: playCount,
            subscribedCount: nil,
            shareCount: nil,
            commentCount: nil,
            creator: creator,
            description: json["introduction"]?.stringValue ?? json["desc"]?.stringValue,
            tags: nil,
            source: .qqmusic
        )
    }
    
    /// 将 qcm推荐歌单（新版 basic 结构）转换为 Playlist
    /// API 结构: { tid, title, desc, cover: { small_url, medium_url }, play_cnt, song_cnt, creator: { nick, uin, avatar } }
    static func convertQQRecommendPlaylist(_ basic: JSON) -> Playlist? {
        // tid 可能是 Int 或 String
        let idValue: Int?
        if let tid = basic["tid"]?.intValue {
            idValue = tid
        } else if let tidStr = basic["tid"]?.stringValue, let parsed = Int(tidStr) {
            idValue = parsed
        } else {
            idValue = nil
        }
        
        guard let id = idValue else {
            AppLogger.warning("[QQBridge] 推荐歌单转换失败: 无法获取 tid")
            return nil
        }
        
        let name = basic["title"]?.stringValue ?? ""
        
        // 封面：优先大图
        let coverUrl = (basic["cover"]?["big_url"]?.stringValue
            ?? basic["cover"]?["default_url"]?.stringValue
            ?? basic["cover"]?["medium_url"]?.stringValue
            ?? basic["cover"]?["small_url"]?.stringValue)?
            .replacingOccurrences(of: "http://", with: "https://")
        
        let playCount = basic["play_cnt"]?.intValue ?? 0
        let trackCount = basic["song_cnt"]?.intValue ?? 0
        
        // 创建者
        var creator: PlaylistCreator?
        if let creatorObj = basic["creator"] {
            let creatorName = creatorObj["nick"]?.stringValue
                ?? creatorObj["name"]?.stringValue
            if let creatorName = creatorName, !creatorName.isEmpty {
                let creatorUin = creatorObj["uin"]?.intValue ?? 0
                creator = PlaylistCreator(
                    userId: creatorUin,
                    nickname: creatorName,
                    avatarUrl: creatorObj["avatar"]?.stringValue
                )
            }
        }
        
        return Playlist(
            id: id,
            name: name,
            coverImgUrl: coverUrl,
            picUrl: nil,
            trackCount: trackCount,
            playCount: playCount,
            subscribedCount: nil,
            shareCount: nil,
            commentCount: nil,
            creator: creator,
            description: basic["desc"]?.stringValue,
            tags: nil,
            source: .qqmusic
        )
    }
    
    /// 将 qcm专辑转换为 SearchAlbum
    static func convertQQAlbumToSearchAlbum(_ json: JSON) -> SearchAlbum? {
        AppLogger.debug("[QQBridge] 专辑原始JSON: \(json)")
        
        let albumId = json["albumID"]?.intValue
            ?? json["album_id"]?.intValue
            ?? json["albumid"]?.intValue
            ?? json["id"]?.intValue
            ?? 0
        
        let name = json["albumName"]?.stringValue
            ?? json["album_name"]?.stringValue
            ?? json["name"]?.stringValue
            ?? json["title"]?.stringValue
            ?? ""
        
        let midRaw = json["albummid"]?.stringValue
            ?? json["albumMID"]?.stringValue
            ?? json["album_mid"]?.stringValue
            ?? json["mid"]?.stringValue
        let mid = (midRaw?.isEmpty == true) ? nil : midRaw
        
        let picUrl: String?
        if let raw = json["albumPic"]?.stringValue
            ?? json["album_pic"]?.stringValue
            ?? json["pic"]?.stringValue
            ?? json["pic_url"]?.stringValue,
           !raw.isEmpty {
            picUrl = raw.replacingOccurrences(of: "http://", with: "https://")
        } else if let albumMid = mid, !albumMid.isEmpty {
            picUrl = "https://y.gtimg.cn/music/photo_new/T002R300x300M000\(albumMid).jpg"
        } else {
            picUrl = nil
        }
        
        // 歌手 — 尝试多种字段
        var artist: Artist?
        if let singers = json["singer_list"]?.arrayValue ?? json["singer"]?.arrayValue, let first = singers.first {
            let singerName = first["name"]?.stringValue ?? first["singerName"]?.stringValue ?? ""
            let singerId = first["id"]?.intValue ?? first["singerID"]?.intValue ?? 0
            if !singerName.isEmpty {
                artist = Artist(id: singerId, name: singerName)
            }
        }
        if artist == nil {
            if let singerName = json["singerName"]?.stringValue
                ?? json["singer_name"]?.stringValue
                ?? json["singerTransName"]?.stringValue {
                let singerId = json["singerID"]?.intValue ?? json["singer_id"]?.intValue ?? 0
                artist = Artist(id: singerId, name: singerName)
            }
        }
        
        let songCount = json["song_count"]?.intValue
            ?? json["songcount"]?.intValue
            ?? json["size"]?.intValue
            ?? json["total_song_num"]?.intValue
        let publishTime = json["publicTime"]?.stringValue.flatMap { Self.qqDateToTimestamp($0) }
            ?? json["publish_date"]?.stringValue.flatMap { Self.qqDateToTimestamp($0) }
        
        return SearchAlbum(
            id: albumId,
            name: name,
            picUrl: picUrl,
            artist: artist,
            artists: nil,
            size: songCount,
            publishTime: publishTime,
            source: .qqmusic,
            qqMid: mid
        )
    }
    
    /// 将 qcm热搜词转换为 HotSearchItem
    static func convertQQHotkeys(_ json: JSON) -> [HotSearchItem] {
        guard let list = json["hotkey"]?.arrayValue ?? json.arrayValue else {
            return []
        }
        return list.enumerated().compactMap { index, item in
            guard let keyword = item["k"]?.stringValue ?? item["keyword"]?.stringValue,
                  !keyword.isEmpty else { return nil }
            let score = item["n"]?.intValue ?? item["score"]?.intValue ?? (1000 - index)
            return HotSearchItem(
                searchWord: keyword,
                score: score,
                content: nil,
                iconUrl: nil
            )
        }
    }
    
    /// qcm日期字符串转时间戳（复用 APIService+QQMusic 中的缓存 DateFormatter）
    private static func qqDateToTimestamp(_ dateStr: String) -> Int? {
        qqDateStringToTimestamp(dateStr)
    }
}

// MARK: - qcm MV 模型

/// qcm MV 模型（使用 vid 字符串标识）
struct QQMV: Identifiable, Hashable, Sendable {
    let vid: String
    let name: String
    let singerName: String?
    let singerMid: String?
    let coverUrl: String?
    let duration: Int?       // 秒
    let playCount: Int?
    let publishDate: String?
    
    var id: String { vid }
    
    /// 格式化播放量
    var playCountText: String {
        guard let count = playCount else { return "" }
        if count >= 100_000_000 {
            return String(format: String(localized: "%.1f亿"), Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: String(localized: "%.1f万"), Double(count) / 10_000)
        }
        return "\(count)"
    }
    
    /// 格式化时长
    var durationText: String {
        guard let sec = duration, sec > 0 else { return "" }
        let minutes = sec / 60
        let seconds = sec % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - QQ MV 转换

extension APIService {
    
    /// 将 qcm搜索 MV 结果转换为 QQMV
    static func convertQQSearchMV(_ json: JSON) -> QQMV? {
        AppLogger.debug("[QQBridge] MV原始JSON: \(json)")
        
        let vid = json["mv_vid"]?.stringValue
            ?? json["vid"]?.stringValue
            ?? json["v_id"]?.stringValue
            ?? json["id"]?.stringValue
        
        guard let vid = vid, !vid.isEmpty else {
            AppLogger.warning("[QQBridge] MV转换失败: 无法获取 vid")
            return nil
        }
        
        let name = json["mvname"]?.stringValue
            ?? json["mv_name"]?.stringValue
            ?? json["title_main"]?.stringValue
            ?? json["title"]?.stringValue
            ?? json["name"]?.stringValue
            ?? ""
        
        // 歌手
        var singerName: String?
        var singerMid: String?
        let singerArray = json["singer_list"]?.arrayValue
            ?? json["singers"]?.arrayValue
            ?? json["singer"]?.arrayValue
            ?? json["singer_info"]?.arrayValue
        if let singers = singerArray, !singers.isEmpty {
            let names = singers.compactMap {
                $0["name"]?.stringValue
                    ?? $0["singerName"]?.stringValue
                    ?? $0["singer_name"]?.stringValue
                    ?? $0["title"]?.stringValue
            }.filter { !$0.isEmpty }
            if !names.isEmpty {
                singerName = names.joined(separator: " / ")
            }
            singerMid = singers.first?["mid"]?.stringValue
                ?? singers.first?["singerMID"]?.stringValue
                ?? singers.first?["singer_mid"]?.stringValue
        }
        if singerName == nil {
            singerName = json["singername"]?.stringValue
                ?? json["singerName"]?.stringValue
                ?? json["singer_name"]?.stringValue
                ?? json["singer"]?.stringValue
        }
        if singerMid == nil {
            singerMid = json["singermid"]?.stringValue
                ?? json["singerMID"]?.stringValue
                ?? json["singer_mid"]?.stringValue
        }
        
        // 封面
        let coverUrl = json["mv_pic_url"]?.stringValue
            ?? json["pic_url"]?.stringValue
            ?? json["pic"]?.stringValue
            ?? json["cover"]?.stringValue
            ?? json["cover_pic"]?.stringValue
        
        // 时长（秒）
        let duration = json["duration"]?.intValue ?? json["interval"]?.intValue
        
        // 播放量
        let playCount = json["play_count"]?.intValue
            ?? json["listennum"]?.intValue
            ?? json["playcnt"]?.intValue
        
        // 发布日期
        let publishDate = json["publish_date"]?.stringValue
            ?? json["publicTime"]?.stringValue
            ?? json["pubdate"]?.stringValue
        
        return QQMV(
            vid: vid,
            name: name,
            singerName: singerName,
            singerMid: singerMid,
            coverUrl: coverUrl,
            duration: duration,
            playCount: playCount,
            publishDate: publishDate
        )
    }
    
    /// 将 qcm MV 详情转换为 QQMV
    static func convertQQDetailMV(_ json: JSON) -> QQMV? {
        guard let vid = json["vid"]?.stringValue ?? json["mv_vid"]?.stringValue,
              !vid.isEmpty else {
            return nil
        }
        let name = json["name"]?.stringValue ?? json["title"]?.stringValue ?? ""
        
        var singerName: String?
        var singerMid: String?
        if let singers = json["singers"]?.arrayValue ?? json["singer"]?.arrayValue, let first = singers.first {
            singerName = first["name"]?.stringValue
            singerMid = first["mid"]?.stringValue
        }
        
        let coverUrl = json["cover_pic"]?.stringValue ?? json["pic"]?.stringValue
        let duration = json["duration"]?.intValue
        let playCount = json["playcnt"]?.intValue ?? json["play_count"]?.intValue
        let publishDate = json["pubdate"]?.stringValue ?? json["publish_date"]?.stringValue
        
        return QQMV(
            vid: vid,
            name: name,
            singerName: singerName,
            singerMid: singerMid,
            coverUrl: coverUrl,
            duration: duration,
            playCount: playCount,
            publishDate: publishDate
        )
    }
}

// MARK: - qcm音质映射

extension APIService {
    
    /// 将 Monologue 的 SoundQuality 映射到 qcm的 SongFileType
    static func mapToQQFileType(_ quality: SoundQuality) -> SongFileType {
        switch quality {
        case .standard:
            return .mp3_128
        case .higher:
            return .mp3_128
        case .exhigh:
            return .mp3_320
        case .lossless:
            return .flac
        case .hires:
            return .master
        case .jyeffect:
            return .flac
        case .sky:
            return .flac
        case .jymaster:
            return .master
        case .none:
            return .mp3_128
        }
    }
}
