import Foundation

// MARK: - Core Song Models

struct Song: Identifiable, Codable, Hashable, Equatable {
    static func == (lhs: Song, rhs: Song) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    
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
    
    // MARK: - QQ 音乐扩展字段
    /// 音乐来源平台
    var source: MusicSource?
    /// QQ 音乐歌曲 mid（用于获取播放 URL）
    var qqMid: String?
    /// QQ 音乐专辑 mid
    var qqAlbumMid: String?
    /// QQ 音乐歌手 mid（用于跳转歌手详情页）
    var qqArtistMid: String?
    /// QQ 音乐最高可用音质（从搜索结果 file 字段解析）
    var qqMaxQuality: QQMusicQuality?
    
    enum CodingKeys: String, CodingKey {
        case id, name, ar, al, dt, fee, mv
        case h, m, l, sq, hr, alia, privilege
        case source, qqMid, qqAlbumMid, qqArtistMid, qqMaxQuality
    }
    
    // MARK: - 辅助属性
    var artists: [Artist] { ar ?? [] }
    var album: Album? { al }
    
    /// 实际音乐来源（默认网易云）
    var musicSource: MusicSource { source ?? .netease }
    
    /// 是否为 QQ 音乐歌曲
    var isQQMusic: Bool { musicSource == .qqmusic }
    
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
        if isQQMusic {
            return qqMaxQuality?.badgeText
        }
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

// MARK: - Extensions

extension URL {
    func sized(_ size: Int) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        var items = (components.queryItems ?? []).filter { $0.name != "param" && $0.name != "thumbnail" }
        items.append(URLQueryItem(name: "param", value: "\(size)y\(size)"))
        components.queryItems = items.isEmpty ? nil : items
        return components.url ?? self
    }
}

// MARK: - Personalized New Song

struct PersonalizedNewSongResult: Codable {
    let id: Int
    let name: String
    let song: SongDetail
}

// MARK: - Recent Song

struct RecentSongItem: Codable {
    let data: Song
    let playTime: Int?
}

// MARK: - FM Song

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

