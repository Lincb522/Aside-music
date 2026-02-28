import Foundation

// MARK: - Playlist Models

struct Playlist: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let coverImgUrl: String?
    let picUrl: String?
    let trackCount: Int?
    let playCount: Int?
    let subscribedCount: Int?
    let shareCount: Int?
    let commentCount: Int?
    let creator: PlaylistCreator?
    let description: String?
    let tags: [String]?
    
    // MARK: - 跨平台扩展字段
    var source: MusicSource?
    var isTopList: Bool = false
    
    var isQQMusic: Bool { source == .qqmusic }
    
    var coverUrl: URL? {
        if let urlStr = coverImgUrl ?? picUrl {
            return URL(string: urlStr)
        }
        return nil
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.id == rhs.id
    }
    
    // 自定义解码：兼容 recommend/resource 返回的 playcount（全小写）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        coverImgUrl = try container.decodeIfPresent(String.self, forKey: .coverImgUrl)
        picUrl = try container.decodeIfPresent(String.self, forKey: .picUrl)
        trackCount = try container.decodeIfPresent(Int.self, forKey: .trackCount)
        // playCount: 优先取 playCount，回退取 playcount（recommend/resource 接口）
        playCount = try container.decodeIfPresent(Int.self, forKey: .playCount)
            ?? (try container.decodeIfPresent(Int.self, forKey: .playcount))
        subscribedCount = try container.decodeIfPresent(Int.self, forKey: .subscribedCount)
        shareCount = try container.decodeIfPresent(Int.self, forKey: .shareCount)
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount)
        creator = try container.decodeIfPresent(PlaylistCreator.self, forKey: .creator)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        source = try container.decodeIfPresent(MusicSource.self, forKey: .source)
        isTopList = try container.decodeIfPresent(Bool.self, forKey: .isTopList) ?? false
    }
    
    // 手动初始化（代码中直接构造用）
    init(id: Int, name: String, coverImgUrl: String?, picUrl: String?, trackCount: Int?, playCount: Int?, subscribedCount: Int?, shareCount: Int?, commentCount: Int?, creator: PlaylistCreator?, description: String?, tags: [String]?, source: MusicSource? = nil, isTopList: Bool = false) {
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
        self.source = source
        self.isTopList = isTopList
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, coverImgUrl, picUrl, trackCount
        case playCount, playcount
        case subscribedCount, shareCount, commentCount
        case creator, description, tags, source, isTopList
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
        try container.encodeIfPresent(source, forKey: .source)
        if isTopList { try container.encode(isTopList, forKey: .isTopList) }
    }
}

struct PlaylistCreator: Codable, Hashable {
    let userId: Int
    let nickname: String?
    let avatarUrl: String?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(userId)
    }
}

struct PlaylistCategory: Codable, Identifiable {
    let name: String
    let id: Int
    let category: Int?
    let hot: Bool?
    
    var idString: String { "\(id)_\(name)" }
}

struct PlaylistDetailResponse: Codable {
    let code: Int
    let playlist: PlaylistDetail?
}

struct PlaylistDetail: Codable {
    let id: Int
    let name: String
    let coverImgUrl: String?
    let description: String?
    let creator: PlaylistCreator?
    let trackCount: Int?
    let playCount: Int?
    let subscribedCount: Int?
    let shareCount: Int?
    let commentCount: Int?
    let tags: [String]?
    let trackIds: [TrackId]?
    let tracks: [Song]?
}

struct TrackId: Codable {
    let id: Int
    let v: Int?
    let t: Int?
    let at: Int?
}

// MARK: - Top List (Charts)

struct TopList: Identifiable, Codable {
    let id: Int
    let name: String
    let coverImgUrl: String?
    let updateFrequency: String
    
    var coverUrl: URL? {
        if let urlStr = coverImgUrl {
            return URL(string: urlStr)
        }
        return nil
    }
}

struct TopListResponse: Codable {
    let code: Int
    let list: [TopList]
}
