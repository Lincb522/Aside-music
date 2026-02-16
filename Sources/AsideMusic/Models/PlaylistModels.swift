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
