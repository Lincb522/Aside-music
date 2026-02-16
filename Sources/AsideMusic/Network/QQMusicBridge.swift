// QQMusicBridge.swift
// QQ 音乐数据模型转换
// 将 QQMusicKit 的 JSON 响应转换为 AsideMusic 的统一模型

import Foundation
import QQMusicKit

// MARK: - QQ 音乐 → Song 转换

extension APIService {
    
    /// 将 QQ 音乐搜索结果转换为 Song
    static func convertQQSongToSong(_ json: JSON) -> Song? {
        // QQ 音乐搜索结果结构：
        // { id, mid, name, singer: [{id, mid, name}], album: {id, mid, name, pmid}, interval, ... }
        guard let songId = json["id"]?.intValue,
              let name = json["name"]?.stringValue ?? json["title"]?.stringValue else {
            return nil
        }
        
        let mid = json["mid"]?.stringValue
        
        // 解析歌手
        var artists: [Artist] = []
        if let singerArray = json["singer"]?.arrayValue {
            for singer in singerArray {
                let singerId = singer["id"]?.intValue ?? 0
                let singerName = singer["name"]?.stringValue ?? ""
                if !singerName.isEmpty {
                    artists.append(Artist(id: singerId, name: singerName))
                }
            }
        }
        
        // 解析专辑
        var album: Album?
        let albumMid = json["album"]?["mid"]?.stringValue ?? json["album"]?["pmid"]?.stringValue
        if let albumDict = json["album"] {
            let albumId = albumDict["id"]?.intValue ?? 0
            let albumName = albumDict["name"]?.stringValue ?? ""
            // QQ 音乐专辑封面 URL 格式
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
        
        // 时长（QQ 音乐用 interval 秒，网易云用 dt 毫秒）
        let intervalSec = json["interval"]?.intValue
        let dt = intervalSec.map { $0 * 1000 }
        
        // 是否 VIP（pay.pay_play == 1）
        let fee: Int?
        if let payPlay = json["pay"]?["pay_play"]?.intValue, payPlay == 1 {
            fee = 1
        } else {
            fee = 0
        }
        
        // MV
        let mvId = json["mv"]?["id"]?.intValue ?? json["mv"]?["vid"]?.intValue ?? 0
        
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
            qqAlbumMid: albumMid
        )
    }
    
    /// 将 QQ 音乐歌手转换为 ArtistInfo
    static func convertQQArtistToArtistInfo(_ json: JSON) -> ArtistInfo? {
        guard let singerId = json["singerID"]?.intValue ?? json["id"]?.intValue ?? json["singerMID"]?.stringValue.flatMap({ _ in json["singerID"]?.intValue }),
              let name = json["singerName"]?.stringValue ?? json["name"]?.stringValue else {
            return nil
        }
        
        let mid = json["singerMID"]?.stringValue ?? json["mid"]?.stringValue
        let picUrl: String?
        if let singerMid = mid, !singerMid.isEmpty {
            picUrl = "https://y.gtimg.cn/music/photo_new/T001R300x300M000\(singerMid).jpg"
        } else {
            picUrl = json["singerPic"]?.stringValue
        }
        
        return ArtistInfo(
            id: singerId,
            name: name,
            picUrl: picUrl,
            img1v1Url: picUrl,
            musicSize: json["songNum"]?.intValue,
            albumSize: json["albumNum"]?.intValue,
            mvSize: json["mvNum"]?.intValue,
            briefDesc: nil,
            alias: nil,
            followed: nil,
            accountId: nil
        )
    }
    
    /// 将 QQ 音乐歌单转换为 Playlist
    static func convertQQPlaylistToPlaylist(_ json: JSON) -> Playlist? {
        guard let dissid = json["dissid"]?.stringValue ?? json["tid"]?.stringValue,
              let id = Int(dissid) ?? json["dissid"]?.intValue ?? json["tid"]?.intValue else {
            return nil
        }
        let name = json["dissname"]?.stringValue ?? json["title"]?.stringValue ?? ""
        let coverUrl = json["imgurl"]?.stringValue ?? json["cover"]?.stringValue
        let playCount = json["listennum"]?.intValue ?? json["accessnum"]?.intValue ?? 0
        let trackCount = json["song_count"]?.intValue ?? 0
        
        // 创建者
        var creator: PlaylistCreator?
        if let creatorName = json["creator"]?["name"]?.stringValue {
            let creatorId = json["creator"]?["encrypt_uin"]?.intValue ?? 0
            creator = PlaylistCreator(
                userId: creatorId,
                nickname: creatorName,
                avatarUrl: json["creator"]?["avatarUrl"]?.stringValue
            )
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
            description: json["introduction"]?.stringValue,
            tags: nil
        )
    }
    
    /// 将 QQ 音乐专辑转换为 SearchAlbum
    static func convertQQAlbumToSearchAlbum(_ json: JSON) -> SearchAlbum? {
        guard let albumId = json["albumID"]?.intValue ?? json["id"]?.intValue else {
            return nil
        }
        let name = json["albumName"]?.stringValue ?? json["name"]?.stringValue ?? ""
        let mid = json["albumMID"]?.stringValue ?? json["mid"]?.stringValue
        
        let picUrl: String?
        if let albumMid = mid, !albumMid.isEmpty {
            picUrl = "https://y.gtimg.cn/music/photo_new/T002R300x300M000\(albumMid).jpg"
        } else {
            picUrl = nil
        }
        
        // 歌手
        var artist: Artist?
        if let singerName = json["singerName"]?.stringValue ?? json["singer_name"]?.stringValue {
            let singerId = json["singerID"]?.intValue ?? json["singer_id"]?.intValue ?? 0
            artist = Artist(id: singerId, name: singerName)
        }
        
        let songCount = json["song_count"]?.intValue ?? json["size"]?.intValue
        let publishTime = json["publicTime"]?.stringValue.flatMap { Self.qqDateToTimestamp($0) }
        
        return SearchAlbum(
            id: albumId,
            name: name,
            picUrl: picUrl,
            artist: artist,
            artists: nil,
            size: songCount,
            publishTime: publishTime
        )
    }
    
    /// 将 QQ 音乐热搜词转换为 HotSearchItem
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
    
    /// QQ 音乐日期字符串转时间戳
    private static func qqDateToTimestamp(_ dateStr: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            return Int(date.timeIntervalSince1970 * 1000)
        }
        return nil
    }
}

// MARK: - QQ 音乐音质映射

extension APIService {
    
    /// 将 AsideMusic 的 SoundQuality 映射到 QQ 音乐的 SongFileType
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
