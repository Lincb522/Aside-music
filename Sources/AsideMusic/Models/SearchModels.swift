import Foundation

// MARK: - Search Models
// Note: SearchResponse and SearchResult are defined in APIService+Search.swift

struct SearchSuggestionResponse: Codable {
    let code: Int
    let result: SearchSuggestionResult?
}

struct SearchSuggestionResult: Codable {
    let allMatch: [SearchSuggestion]?
}

struct SearchSuggestion: Codable, Identifiable {
    let keyword: String
    let type: Int?
    
    var id: String { keyword }
}

// MARK: - Hot Search

struct HotSearchResponse: Codable {
    let code: Int
    let data: [HotSearchItem]?
}

struct HotSearchItem: Codable, Identifiable {
    let searchWord: String
    let score: Int?
    let content: String?
    let iconUrl: String?
    
    var id: String { searchWord }
}

// MARK: - Banner

struct Banner: Identifiable, Codable {
    let targetId: Int
    let targetType: Int
    let typeTitle: String?
    let url: String?
    let pic: String?
    
    var imageUrl: URL? {
        if let pic = pic { return URL(string: pic) }
        return nil
    }
    
    var id: String { pic ?? "\(targetId)_\(targetType)_\(url ?? "")" }
}

struct BannerResponse: Codable {
    let code: Int
    let banners: [Banner]?
}

// MARK: - Daily Recommend

struct DailyRecommendResponse: Codable {
    let code: Int
    let data: DailyRecommendData?
}

struct DailyRecommendData: Codable {
    let dailySongs: [Song]?
}

// MARK: - Recommend Playlists

struct RecommendPlaylistResponse: Codable {
    let code: Int
    let recommend: [Playlist]?
}

// MARK: - Song URL

struct SongUrlResponse: Codable {
    let code: Int
    let data: [SongUrlData]
}

struct SongUrlData: Codable {
    let id: Int
    let url: String?
    let br: Int?
    let size: Int?
    let type: String?
    let level: String?
}

// MARK: - Lyric

struct LyricResponse: Codable {
    let code: Int
    let lrc: LyricContent?
    let tlyric: LyricContent?
    let romalrc: LyricContent?
    let yrc: LyricContent?
    let klyric: LyricContent?
}

struct LyricContent: Codable {
    let version: Int?
    let lyric: String?
}

// MARK: - Dragon Ball (Homepage Icons)

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



// MARK: - Search Default

struct SearchDefaultResult {
    /// 显示在搜索框的关键词
    let showKeyword: String
    /// 实际搜索用的关键词
    let realkeyword: String
}

// MARK: - Search Multimatch

struct SearchMultimatchResult {
    let artist: ArtistInfo?
    let album: SearchAlbum?
    let playlist: Playlist?
}

// MARK: - Song Chorus

struct SongChorusResult {
    /// 副歌开始时间（秒）
    let startTime: TimeInterval?
    /// 副歌结束时间（秒）
    let endTime: TimeInterval?
}

// MARK: - Song Wiki

struct SongWikiBlock: Identifiable {
    let id = UUID()
    let type: String
    let title: String
    let description: String
}

// MARK: - Related Playlist

struct RelatedPlaylist: Identifiable {
    let id: Int
    let name: String
    let coverImgUrl: String?
    let creatorName: String
    
    var coverUrl: URL? {
        coverImgUrl.flatMap { URL(string: $0) }
    }
}
