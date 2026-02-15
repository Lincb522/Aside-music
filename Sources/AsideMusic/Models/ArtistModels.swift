import Foundation

// MARK: - 艺术家 & 专辑相关模型

struct ArtistInfo: Identifiable, Codable {
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

struct ArtistDetailResponse: Codable {
    let data: ArtistDetailData
}

struct ArtistDetailData: Codable {
    let artist: ArtistInfo
}

struct ArtistDescSection: Identifiable {
    let id = UUID()
    let title: String
    let content: String
}

struct ArtistDescResult {
    let briefDesc: String?
    let sections: [ArtistDescSection]
}

struct ArtistTopSongsResponse: Codable {
    let songs: [Song]
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

// MARK: - 专辑详情

struct AlbumInfo: Identifiable, Codable {
    let id: Int
    let name: String
    let picUrl: String?
    let artist: Artist?
    let artists: [Artist]?
    let size: Int?
    let description: String?
    let publishTime: Int?
    let company: String?
    let subType: String?
    
    var coverUrl: URL? {
        if let url = picUrl { return URL(string: url) }
        return nil
    }
    
    var artistName: String {
        if let artists = artists, !artists.isEmpty {
            return artists.map { $0.name }.joined(separator: " / ")
        }
        return artist?.name ?? ""
    }
    
    var publishDateText: String {
        guard let ts = publishTime else { return "" }
        let date = Date(timeIntervalSince1970: Double(ts) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct AlbumDetailResult {
    let album: AlbumInfo?
    let songs: [Song]
}
