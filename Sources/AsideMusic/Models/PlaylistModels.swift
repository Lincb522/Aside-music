import Foundation

// MARK: - 歌单相关模型

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

struct PlaylistDetailResponse: Codable {
    let playlist: Playlist
}

struct PlaylistTrackResponse: Codable {
    let songs: [Song]
}

struct RecommendResourceResponse: Codable {
    let recommend: [Playlist]
}

struct UserPlaylistResponse: Codable {
    let playlist: [Playlist]
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
