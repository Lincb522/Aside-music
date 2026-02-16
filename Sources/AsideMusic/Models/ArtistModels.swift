import Foundation

// MARK: - Artist Detail Models

struct ArtistInfo: Identifiable, Codable {
    let id: Int
    let name: String
    let picUrl: String?
    let img1v1Url: String?
    let musicSize: Int?
    let albumSize: Int?
    let mvSize: Int?
    let briefDesc: String?
    let alias: [String]?
    let followed: Bool?
    let accountId: Int?
    
    var coverUrl: URL? {
        if let urlStr = img1v1Url ?? picUrl {
            return URL(string: urlStr)
        }
        return nil
    }
}

struct ArtistDetailResponse: Codable {
    let code: Int
    let data: ArtistDetailData?
}

struct ArtistDetailData: Codable {
    let artist: ArtistInfo?
}

struct ArtistSongsResponse: Codable {
    let code: Int
    let songs: [Song]?
    let total: Int?
    let more: Bool?
}

struct ArtistAlbumsResponse: Codable {
    let code: Int
    let hotAlbums: [AlbumInfo]?
    let more: Bool?
}

struct AlbumInfo: Identifiable, Codable {
    let id: Int
    let name: String
    let picUrl: String?
    let publishTime: Int?
    let size: Int?
    let artist: ArtistInfo?
    let artists: [Artist]?
    let description: String?
    let company: String?
    let subType: String?
    
    var coverUrl: URL? {
        if let urlStr = picUrl {
            return URL(string: urlStr)
        }
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

struct AlbumDetailResponse: Codable {
    let code: Int
    let album: AlbumInfo?
    let songs: [Song]?
}

// MARK: - Artist Description

struct ArtistDescSection: Identifiable {
    let id = UUID()
    let title: String
    let content: String
}

struct ArtistDescResult {
    let briefDesc: String?
    let sections: [ArtistDescSection]
}

// MARK: - Album Detail Result

struct AlbumDetailResult {
    let album: AlbumInfo?
    let songs: [Song]
}

