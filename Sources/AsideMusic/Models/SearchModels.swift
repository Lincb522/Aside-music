import Foundation

// MARK: - 搜索 & 发现相关模型

struct Banner: Identifiable, Codable {
    var id: String { pic }
    let pic: String
    let targetId: Int
    let targetType: Int
    let titleColor: String?
    let typeTitle: String?
    let url: String?
    
    var imageUrl: URL? { URL(string: pic) }
}

struct BannerResponse: Codable {
    let banners: [Banner]
}

struct TopList: Identifiable, Codable {
    let id: Int
    let name: String
    let coverImgUrl: String
    let updateFrequency: String
    let tracks: [TopListTrack]?
    
    var coverUrl: URL? { URL(string: coverImgUrl) }
}

struct TopListTrack: Codable {
    let first: String
    let second: String
}

struct TopListResponse: Codable {
    let list: [TopList]
}

struct HotSearchResponse: Codable {
    let data: [HotSearchItem]
}

struct HotSearchItem: Codable {
    let searchWord: String
    let score: Int
    let content: String?
}

struct DragonBall: Identifiable, Codable {
    let id: Int
    let name: String
    let iconUrl: String
    let url: String
    
    var imageUrl: URL? { URL(string: iconUrl) }
}

struct DragonBallResponse: Codable {
    let data: [DragonBall]
}

// MARK: - 歌词模型

struct LyricResponse: Codable {
    let lrc: LyricData?
    let tlyric: LyricData?
    let romalrc: LyricData?
    let yrc: LyricData?
    let klyric: LyricData?
    let code: Int
}

struct LyricData: Codable {
    let version: Int?
    let lyric: String?
}

// MARK: - 新歌推荐

struct PersonalizedNewSongResponse: Codable {
    let result: [PersonalizedNewSongResult]
}

struct PersonalizedNewSongResult: Codable {
    let id: Int
    let name: String
    let song: SongDetail
}

// MARK: - 歌曲 URL 相关

struct SongUrlResponse: Codable {
    let data: [SongUrlData]
}

struct SongUrlData: Codable {
    let id: Int
    let url: String?
}

// MARK: - 私人FM

struct PersonalFMResponse: Codable {
    let data: [FMSong]?
    let result: [FMSong]?
}

struct FMSong: Codable {
    let id: Int
    let name: String?
    let album: Album?
    let al: Album?
    let artists: [Artist]?
    let ar: [Artist]?
    let duration: Int?
    let dt: Int?
    let fee: Int?
    let mvid: Int?
    
    let h: SongQuality?
    let m: SongQuality?
    let l: SongQuality?
    let sq: SongQuality?
    let hr: SongQuality?
    let privilege: Privilege?
    
    func toSong() -> Song {
        return Song(
            id: id,
            name: name ?? "Unknown Song",
            ar: ar ?? artists,
            al: al ?? album,
            dt: dt ?? duration,
            fee: fee,
            mv: mvid ?? 0,
            h: h,
            m: m,
            l: l,
            sq: sq,
            hr: hr,
            alia: nil,
            privilege: privilege
        )
    }
}

// MARK: - 每日推荐 & 最近播放

struct DailySongsResponse: Codable {
    let data: DailySongsData
}

struct DailySongsData: Codable {
    let dailySongs: [Song]
}

struct RecentSongResponse: Codable {
    let data: RecentSongData?
}

struct RecentSongData: Codable {
    let list: [RecentSongItem]
}

struct RecentSongItem: Codable {
    let data: Song
    let playTime: Int?
}
