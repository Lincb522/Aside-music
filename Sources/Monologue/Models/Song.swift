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
    
    /// 播客电台 ID（非 API 字段，手动注入）
    var podcastRadioId: Int?
    
    /// 播客电台名称（非 API 字段，手动注入）
    var podcastRadioName: String?
    
    // MARK: - qcm 扩展字段
    /// 音乐来源平台
    var source: MusicSource?
    /// qcm 歌曲 mid（用于获取播放 URL）
    var qqMid: String?
    /// qcm 专辑 mid
    var qqAlbumMid: String?
    /// qcm 歌手 mid（用于跳转歌手详情页）
    var qqArtistMid: String?
    /// qcm 最高可用音质（从搜索结果 file 字段解析）
    var qqMaxQuality: QQMusicQuality?
    /// qcm 是否为数字专辑（需单独购买，VIP 也不能解锁）
    /// 仅当 `pay.pay_album == 1` 时置 true（勿用 price 字段，易误伤整列表）
    var qqIsDigitalAlbum: Bool?
    /// 本地导入音乐的相对文件路径
    var localRelativePath: String?
    /// 本地导入时间
    var localImportedAt: Date?
    
    // MARK: - 汽水音乐扩展字段
    /// 汽水音乐 track ID
    var qishuiTrackId: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, ar, al, dt, fee, mv
        case h, m, l, sq, hr, alia, privilege
        case source, qqMid, qqAlbumMid, qqArtistMid, qqMaxQuality, qqIsDigitalAlbum
        case localRelativePath, localImportedAt
        case qishuiTrackId
        case podcastCoverUrl
        case podcastRadioId
        case podcastRadioName
    }
    
    // MARK: - 辅助属性
    var artists: [Artist] { ar ?? [] }
    var album: Album? { al }
    
    private var inferredLegacySource: MusicSource? {
        if source == nil, let qishuiTrackId, qishuiTrackId > 0 {
            return .qishui
        }
        
        guard source == nil, let qqMid, !qqMid.isEmpty else { return nil }

        // 兼容旧本地歌单/导入数据：部分 qcm 歌缺少 source，但仍保留 qqMid 与 qcm CDN 封面。
        if let picUrl = al?.picUrl?.lowercased(),
           picUrl.contains("gtimg.cn") || picUrl.contains("qpic.cn") {
            return .qqmusic
        }

        let hasNeteaseStreamMetadata =
            h != nil || m != nil || l != nil || sq != nil || hr != nil || privilege != nil
        return hasNeteaseStreamMetadata ? nil : .qqmusic
    }

    /// 实际音乐来源（默认 ncm）
    var musicSource: MusicSource {
        if let s = source { return s }
        if let inferred = inferredLegacySource { return inferred }
        return .netease
    }
    
    /// 是否为 qcm 歌曲
    var isQQMusic: Bool { musicSource == .qqmusic }

    /// 是否为汽水音乐歌曲
    var isQishui: Bool { musicSource == .qishui }

    /// 是否为本地导入歌曲
    var isLocal: Bool { musicSource == .local }
    
    var artistName: String {
        (ar ?? []).map { $0.name }.joined(separator: ", ")
    }
    
    var coverUrl: URL? {
        // QQ 接口的直接图片字段常只有 180/300px，甚至部分接口不返回图片字段。
        // 歌曲模型已经保留了专辑 MID，优先据此生成稳定的高清 CDN 地址。
        if isQQMusic {
            if let albumMid = qqAlbumMid?.trimmingCharacters(in: .whitespacesAndNewlines),
               !albumMid.isEmpty {
                return URL(string: "https://y.gtimg.cn/music/photo_new/T002R800x800M000\(albumMid).jpg")
            }
            if let picUrl = al?.picUrl, !picUrl.isEmpty,
               let url = URL(string: picUrl.hasPrefix("//") ? "https:\(picUrl)" : picUrl) {
                return url
            }
            if let artistMid = qqArtistMid?.trimmingCharacters(in: .whitespacesAndNewlines),
               !artistMid.isEmpty {
                return URL(string: "https://y.gtimg.cn/music/photo_new/T001R800x800M000\(artistMid).jpg")
            }
        }

        // 优先使用专辑封面（排除空字符串）
        if let picUrl = al?.picUrl, !picUrl.isEmpty {
            return URL(string: picUrl.hasPrefix("//") ? "https:\(picUrl)" : picUrl)
        }
        // 播客节目封面备用
        if let podcastCover = podcastCoverUrl, !podcastCover.isEmpty {
            return URL(string: podcastCover)
        }
        return nil
    }

    var localFileURL: URL? {
        guard let localRelativePath, !localRelativePath.isEmpty else { return nil }
        let fileURL = LocalMusicLibraryManager.musicDirectory.appendingPathComponent(localRelativePath)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    var isVIP: Bool {
        return fee == 1
    }
    
    var maxQuality: SoundQuality {
        var candidates: [SoundQuality] = []

        if let p = privilege {
            candidates.append(contentsOf: [
                p.downloadMaxBrLevel,
                p.playMaxBrLevel,
                p.maxBrLevel,
                p.dlLevel,
                p.plLevel,
                p.flLevel
            ].compactMap { $0 })
        }

        if hr != nil {
            candidates.append(.hires)
        }
        if sq != nil {
            candidates.append(.lossless)
        }
        if h != nil {
            candidates.append(.exhigh)
        }
        if m != nil {
            candidates.append(.higher)
        }
        if l != nil {
            candidates.append(.standard)
        }
        if fee == 8 {
            candidates.append(.lossless)
        }

        return SoundQuality.highest(from: candidates) ?? .standard
    }
    
    var qualityBadge: String? {
        if isLocal {
            return nil
        }
        if isQQMusic {
            return qqMaxQuality?.badgeText
        }
        return maxQuality.badgeText
    }
    
    /// 真正无版权（平台级别下架），VIP Cookie 也无法播放
    var isNoCopyright: Bool {
        if let st = privilege?.st, st < 0 { return true }
        return false
    }

    /// VIP 限制（需要会员才能播放），VIP Cookie 可以播放
    var isVIPRestricted: Bool {
        if let pl = privilege?.pl, pl == 0, let fee = privilege?.fee, fee != 0 {
            return true
        }
        return false
    }

    /// 数字专辑歌曲：
    /// - 网易云：`fee == 4` 或 `privilege.fee == 4`
    /// - qcm：由 `convertQQSongToSong` 在 `pay.pay_album == 1` 时写入 `qqIsDigitalAlbum`
    /// 数字专辑需要另外购买，VIP Cookie 也不能自动解锁。
    var isDigitalAlbum: Bool {
        if fee == 4 { return true }
        if let pfee = privilege?.fee, pfee == 4 { return true }
        if qqIsDigitalAlbum == true { return true }
        return false
    }

    /// 是否为"未购买"的数字专辑（即使是 VIP 也需单独购买）。
    /// - 网易云：数字专辑 + privilege 表明未购（payed == 0 或 pl == 0 或 st < 0）
    /// - qcm：`qqIsDigitalAlbum == true`（仅 pay_album）时标灰；其余数字专辑仍靠播放失败
    ///   由 `UnavailableSongsManager` 标灰。
    var isUnpurchasedDigitalAlbum: Bool {
        if qqIsDigitalAlbum == true { return true }
        guard isDigitalAlbum else { return false }
        guard let privilege else { return false }
        if let payed = privilege.payed, payed == 1 { return false }
        if let pl = privilege.pl, pl == 0 { return true }
        if let st = privilege.st, st < 0 { return true }
        if let payed = privilege.payed, payed == 0 { return true }
        return false
    }

    /// 判断歌曲是否不可用（无版权 或 VIP 限制 或 未购数字专辑）
    var isUnavailable: Bool {
        isNoCopyright || isVIPRestricted || isUnpurchasedDigitalAlbum
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
    /// qcm CDN 只支持固定尺寸，将请求的尺寸向上取到最近的可用值
    private static let qqCDNSizes = [150, 180, 300, 500, 800]

    private static func nearestQQSize(_ requested: Int) -> Int {
        qqCDNSizes.first { $0 >= requested } ?? 800
    }

    func sized(_ size: Int) -> URL {
        resizedArtworkURL(pixelSize: size, preserveLargerRequest: false)
    }

    /// 图片视图按点布局、CDN 按像素返回。加载器调用此方法保证现有 URL
    /// 至少达到目标像素，不会把调用方已经请求的高清图反向降级。
    func artworkURL(atLeastPixelSize size: Int) -> URL {
        resizedArtworkURL(pixelSize: size, preserveLargerRequest: true)
    }

    private func resizedArtworkURL(pixelSize requestedSize: Int, preserveLargerRequest: Bool) -> URL {
        if isFileURL {
            return self
        }

        let targetSize = max(requestedSize, 1)
        var normalizedURL = self
        if scheme == "http", var components = URLComponents(url: self, resolvingAgainstBaseURL: false) {
            components.scheme = "https"
            normalizedURL = components.url ?? self
        }

        let str = normalizedURL.absoluteString
        let host = normalizedURL.host?.lowercased() ?? ""

        // qcm CDN: 替换路径中的 R{w}x{h} 尺寸段（T001/T002/T003 等）
        if str.contains("y.gtimg.cn/music/photo_new/"),
           let range = str.range(of: #"R\d+x\d+"#, options: .regularExpression) {
            let currentSize = String(str[range])
                .dropFirst()
                .split(separator: "x")
                .first
                .flatMap { Int($0) } ?? 0
            let requested = preserveLargerRequest ? max(targetSize, currentSize) : targetSize
            let s = Self.nearestQQSize(requested)
            let replaced = str.replacingCharacters(in: range, with: "R\(s)x\(s)")
            return URL(string: replaced) ?? normalizedURL
        }

        // qcm歌单封面 CDN 主要提供 /300 与 /600 两档。
        if str.contains("qpic.cn") {
            guard let range = str.range(of: #"/\d{2,4}(?=[?&/]|$)"#, options: .regularExpression) else {
                return normalizedURL
            }
            let currentSize = Int(str[range].dropFirst()) ?? 0
            let requested = preserveLargerRequest ? max(targetSize, currentSize) : targetSize
            let s = requested > 300 ? 600 : 300
            return URL(string: str.replacingCharacters(in: range, with: "/\(s)")) ?? normalizedURL
        }

        // qcm 新版推荐歌单使用 imageView2/4/w/300/h/300 参数。
        if host == "music-file.y.qq.com",
           let range = str.range(of: #"/w/\d+/h/\d+"#, options: .regularExpression) {
            let segment = String(str[range])
            let currentSize = segment
                .split(separator: "/")
                .compactMap { Int($0) }
                .max() ?? 0
            let requested = preserveLargerRequest ? max(targetSize, currentSize) : targetSize
            let s = min(requested, 1200)
            return URL(string: str.replacingCharacters(in: range, with: "/w/\(s)/h/\(s)")) ?? normalizedURL
        }

        // qcm其他 CDN（pic.ugcimg.cn 等带 /N 尺寸路径）
        if str.contains("gtimg.cn") || str.contains("ugcimg.cn") {
            var result = str
            if let range = result.range(of: #"/\d{2,4}(?=[?&/]|$)"#, options: .regularExpression) {
                let currentSize = Int(result[range].dropFirst()) ?? 0
                let size = preserveLargerRequest ? max(targetSize, currentSize) : targetSize
                result = result.replacingCharacters(in: range, with: "/\(size)")
            }
            return URL(string: result) ?? normalizedURL
        }

        // ncm CDN
        guard host.contains("music.126.net"),
              var components = URLComponents(url: normalizedURL, resolvingAgainstBaseURL: false) else {
            return normalizedURL
        }
        var queryItems = components.queryItems ?? []
        let currentSize: Int = queryItems
            .first(where: { $0.name == "param" })?
            .value?
            .split(separator: "y")
            .first
            .flatMap { Int($0) } ?? 0
        let size = preserveLargerRequest ? max(targetSize, currentSize) : targetSize
        queryItems.removeAll(where: { $0.name == "param" })
        queryItems.append(URLQueryItem(name: "param", value: "\(size)y\(size)"))
        components.queryItems = queryItems
        return components.url ?? normalizedURL
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
