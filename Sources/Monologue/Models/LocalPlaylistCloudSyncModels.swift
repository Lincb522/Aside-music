import Foundation

struct LocalPlaylistCloudPlaylist: Codable, Hashable {
    var id: String
    var name: String
    var desc: String?
    var coverUrl: String?
    var createdAt: Date
    var updatedAt: Date
    var isSystem: Bool
    var songs: [Song]
}

struct LocalPlaylistCloudSnapshot: Codable, Hashable {
    var updatedAt: Date
    var deviceId: String
    var deviceName: String
    var playlists: [LocalPlaylistCloudPlaylist]
}

struct LocalPlaylistCloudFetchResponse: Codable {
    var ok: Bool
    var tokenName: String?
    var hasSnapshot: Bool
    var updatedAt: Date?
    var revision: String?
    var playlists: [LocalPlaylistCloudPlaylist]
}

struct LocalPlaylistCloudUploadResponse: Codable {
    var ok: Bool
    var updatedAt: Date
    var revision: String
    var playlistCount: Int
    var songCount: Int
}

struct LocalPlaylistCloudDeleteResponse: Codable {
    var ok: Bool
    var updatedAt: Date
}
