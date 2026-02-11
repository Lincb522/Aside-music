import Foundation

// MARK: - Core Models

struct Song: Identifiable, Codable {
    let id: Int
    let name: String
    let ar: [Artist]?
    let al: Album?
    let dt: Int?
    let fee: Int?
    let mv: Int?
    
    let h: SongQuality?
    let m: SongQuality?
    let l: SongQuality?
    let sq: SongQuality?
    let hr: SongQuality?
    
    let alia: [String]?
    var privilege: Privilege?
    
    /// 播客节目封面（非 API 字段，手动注入）
    var podcastCoverUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, ar, al, dt, fee, mv
        case h, m, l, sq, hr, alia, privilege
    }
    
    // MARK: - 辅助属性
    var artists: [Artist] { ar ?? [] }
    var album: Album? { al }
    
    var artistName: String {
        (ar ?? []).map { $0.name }.joined(separator: ", ")
    }
    
    var coverUrl: URL? {
        // 优先使用专辑封面（排除空字符串）
        if let picUrl = al?.picUrl, !picUrl.isEmpty {
            return URL(string: picUrl)
        }
        // 播客节目封面备用
        if let podcastCover = podcastCoverUrl, !podcastCover.isEmpty {
            return URL(string: podcastCover)
        }
        return nil
    }
    
    var isVIP: Bool {
        return fee == 1
    }
    
    var maxQuality: SoundQuality {
        if let p = privilege, let level = p.playMaxBrLevel {
            return level
        }
        if let p = privilege, let level = p.maxBrLevel {
            return level
        }
        
        if hr != nil {
            return .hires
        }
        if sq != nil {
            return .lossless
        }
        
        if fee == 8 {
            return .lossless
        }
        
        return .standard 
    }
    
    var qualityBadge: String? {
        return maxQuality.badgeText
    }
    
    /// 判断歌曲是否无版权（灰色歌曲）
    /// st < 0 表示无版权，常见值：-200 无版权
    var isUnavailable: Bool {
        // 优先检查 privilege.st
        if let st = privilege?.st, st < 0 {
            return true
        }
        // 备用检查：pl = 0 且 fee != 0 通常也表示无法播放
        if let pl = privilege?.pl, pl == 0, let fee = privilege?.fee, fee != 0 {
            return true
        }
        return false
    }
}

struct SongQuality: Codable {
    let br: Int
    let fid: Int?
    let size: Int?
    let vd: Double?
    let sr: Int?
}

struct Privilege: Codable {
    let id: Int?
    let fee: Int?
    let payed: Int?
    let st: Int?
    let pl: Int?
    let dl: Int?
    let sp: Int?
    let cp: Int?
    let subp: Int?
    let cs: Bool?
    let maxbr: Int?
    let fl: Int?
    let toast: Bool?
    let flag: Int?
    let preSell: Bool?
    let playMaxBr: Int?
    let downloadMaxBr: Int?
    
    let maxBrLevel: SoundQuality?
    let playMaxBrLevel: SoundQuality?
    let downloadMaxBrLevel: SoundQuality?
    let plLevel: SoundQuality?
    let dlLevel: SoundQuality?
    let flLevel: SoundQuality?
    
    let rscl: Int?
    let freeTrialPrivilege: FreeTrialPrivilege?
    let chargeInfoList: [ChargeInfo]?
}

struct FreeTrialPrivilege: Codable {
    let resConsumable: Bool
    let userConsumable: Bool
    let listenType: Int?
}

struct ChargeInfo: Codable {
    let rate: Int
    let chargeUrl: String?
    let chargeMessage: String?
    let chargeType: Int
}

struct Artist: Codable {
    let id: Int
    let name: String
}

struct Album: Codable {
    let id: Int
    let name: String
    let picUrl: String?
}

struct Playlist: Identifiable, Codable {
    let id: Int
    let name: String
    let coverImgUrl: String?
    let picUrl: String?
    let trackCount: Int?
    let playCount: Int?
    let subscribedCount: Int?
    let shareCount: Int?
    let commentCount: Int?
    let creator: Creator?
    let description: String?
    let tags: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, coverImgUrl, picUrl, trackCount
        case playCount = "playcount"
        case playCountCamel = "playCount"
        case subscribedCount, shareCount, commentCount, creator, description, tags
    }
    
    init(id: Int, name: String, coverImgUrl: String?, picUrl: String?, trackCount: Int?, playCount: Int?, subscribedCount: Int?, shareCount: Int?, commentCount: Int?, creator: Creator?, description: String?, tags: [String]?) {
        self.id = id
        self.name = name
        self.coverImgUrl = coverImgUrl
        self.picUrl = picUrl
        self.trackCount = trackCount
        self.playCount = playCount
        self.subscribedCount = subscribedCount
        self.shareCount = shareCount
        self.commentCount = commentCount
        self.creator = creator
        self.description = description
        self.tags = tags
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        coverImgUrl = try container.decodeIfPresent(String.self, forKey: .coverImgUrl)
        picUrl = try container.decodeIfPresent(String.self, forKey: .picUrl)
        trackCount = try container.decodeIfPresent(Int.self, forKey: .trackCount)
        
        if let count = try container.decodeIfPresent(Int.self, forKey: .playCount) {
            playCount = count
        } else {
            playCount = try container.decodeIfPresent(Int.self, forKey: .playCountCamel)
        }
        
        subscribedCount = try container.decodeIfPresent(Int.self, forKey: .subscribedCount)
        shareCount = try container.decodeIfPresent(Int.self, forKey: .shareCount)
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount)
        creator = try container.decodeIfPresent(Creator.self, forKey: .creator)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(coverImgUrl, forKey: .coverImgUrl)
        try container.encodeIfPresent(picUrl, forKey: .picUrl)
        try container.encodeIfPresent(trackCount, forKey: .trackCount)
        try container.encodeIfPresent(playCount, forKey: .playCount)
        try container.encodeIfPresent(subscribedCount, forKey: .subscribedCount)
        try container.encodeIfPresent(shareCount, forKey: .shareCount)
        try container.encodeIfPresent(commentCount, forKey: .commentCount)
        try container.encodeIfPresent(creator, forKey: .creator)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(tags, forKey: .tags)
    }
    
    var coverUrl: URL? {
        if let url = coverImgUrl { return URL(string: url) }
        if let url = picUrl { return URL(string: url) }
        return nil
    }
}

struct Creator: Codable {
    let userId: Int?
    let nickname: String?
    let avatarUrl: String?
}

struct UserProfile: Codable {
    let userId: Int
    let nickname: String
    let avatarUrl: String
    let eventCount: Int?
    let follows: Int?
    let followeds: Int?
    let signature: String?
}

struct Banner: Identifiable, Codable {
    var id: String { pic }
    let pic: String
    let targetId: Int
    let targetType: Int
    let titleColor: String?
    let typeTitle: String?
    
    var imageUrl: URL? { URL(string: pic) }
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

// MARK: - API Response Wrappers

struct BannerResponse: Codable {
    let banners: [Banner]
}

struct TopListResponse: Codable {
    let list: [TopList]
}

struct PersonalizedNewSongResponse: Codable {
    let result: [PersonalizedNewSongResult]
}

struct PersonalizedNewSongResult: Codable {
    let id: Int
    let name: String
    let song: SongDetail 
}

struct SongDetail: Codable {
    let id: Int
    let name: String
    let artists: [Artist]?
    let ar: [Artist]?
    let album: Album?
    let al: Album?
    let duration: Int?
    let dt: Int?
    let fee: Int?
    let mvid: Int?
    
    let h: SongQuality?
    let m: SongQuality?
    let l: SongQuality?
    let sq: SongQuality?
    let hr: SongQuality?
    
    func toSong() -> Song {
        return Song(
            id: id,
            name: name,
            ar: ar ?? artists,
            al: al ?? album,
            dt: dt ?? duration,
            fee: fee,
            mv: mvid,
            h: h,
            m: m,
            l: l,
            sq: sq,
            hr: hr,
            alia: nil
        )
    }
}

struct PlaylistTrackResponse: Codable {
    let songs: [Song]
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

struct DailySongsResponse: Codable {
    let data: DailySongsData
}
struct DailySongsData: Codable {
    let dailySongs: [Song]
}

struct RecommendResourceResponse: Codable {
    let recommend: [Playlist]
}

struct UserPlaylistResponse: Codable {
    let playlist: [Playlist]
}

struct LoginStatusResponse: Codable {
    let data: LoginStatusData
}
struct LoginStatusData: Codable {
    let profile: UserProfile?
}

struct LoginResponse: Codable {
    let code: Int
    let cookie: String?
    let profile: UserProfile?
}

struct QRKeyResponse: Codable {
    let data: QRKeyData
}
struct QRKeyData: Codable {
    let unikey: String
}

struct QRCreateResponse: Codable {
    let data: QRCreateData
}
struct QRCreateData: Codable {
    let qrimg: String
    let qrurl: String
}

struct QRCheckResponse: Codable {
    let code: Int
    let message: String
    let cookie: String?
}

struct SimpleResponse: Codable {
    let code: Int
    let message: String?
}

struct ArtistDetailResponse: Codable {
    let data: ArtistDetailData
}

struct ArtistDetailData: Codable {
    let artist: ArtistInfo
}

struct ArtistInfo: Codable {
    let id: Int
    let name: String
    let cover: String?
    let picUrl: String?
    let img1v1Url: String?
    let briefDesc: String?
    let albumSize: Int?
    let musicSize: Int?
    
    var coverUrl: URL? {
        if let url = cover { return URL(string: url) }
        if let url = picUrl { return URL(string: url) }
        if let url = img1v1Url { return URL(string: url) }
        return nil
    }
}

struct ArtistTopSongsResponse: Codable {
    let songs: [Song]
}

struct PlaylistDetailResponse: Codable {
    let playlist: Playlist
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

struct SongUrlResponse: Codable {
    let data: [SongUrlData]
}
struct SongUrlData: Codable {
    let id: Int
    let url: String?
}

// MARK: - Playlist Square Models

struct PlaylistCatlistResponse: Codable {
    let sub: [PlaylistCategory]
    let categories: [String: String]
    let all: PlaylistCategory?
}

struct PlaylistHotCatResponse: Codable {
    let tags: [PlaylistCategory]
}

struct PlaylistCategory: Identifiable, Codable, Hashable {
    let name: String
    let id: Int?
    let category: Int?
    let hot: Bool?
    
    var idString: String { name }
}

struct TopPlaylistResponse: Codable {
    let playlists: [Playlist]
    let total: Int
}

struct TopArtistsResponse: Codable {
    let artists: [ArtistInfo]
}

struct SearchArtistResponse: Codable {
    let result: SearchArtistResult
}

struct SearchArtistResult: Codable {
    let artists: [ArtistInfo]?
    let artistCount: Int?
}

// MARK: - Lyric Models

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

// MARK: - Extensions
extension URL {
    func sized(_ size: Int) -> URL {
        let absoluteString = self.absoluteString
        let separator = absoluteString.contains("?") ? "&" : "?"
        return URL(string: absoluteString + "\(separator)param=\(size)y\(size)") ?? self
    }
}
