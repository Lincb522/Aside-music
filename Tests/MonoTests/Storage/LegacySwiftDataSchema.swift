import Foundation
import SwiftData

// Previous persisted schema, retained to exercise real SQLite migration.
@available(iOS 17, *)
enum LegacySwiftDataSchema {
    @Model
    final class CachedSong {
        @Attribute(.unique) var id: Int
        var name: String
        var artistName: String
        var albumName: String?
        var coverUrl: String?
        var duration: Int?
        var cachedAt: Date
        var lastPlayedAt: Date?
        var playCount: Int
        var maxBitrate: Int?
        var fee: Int?
        var canPlay: Bool
        var sourceRaw: String?
        var qqMid: String?
        var qishuiTrackId: Int?
        var appleMusicID: String?
        var appleMusicISRC: String?

        init(id: Int) {
            self.id = id
            self.name = ""
            self.artistName = ""
            self.cachedAt = Date()
            self.playCount = 0
            self.canPlay = true
        }
    }

    @Model
    final class CachedPlaylist {
        @Attribute(.unique) var id: Int
        var name: String
        var coverUrl: String?
        var creatorName: String?
        var trackCount: Int?
        var playCount: Int?
        var desc: String?
        var tagsData: String?
        var cachedAt: Date
        var lastAccessedAt: Date?
        var trackIdsData: String?

        init(id: Int) {
            self.id = id
            self.name = ""
            self.cachedAt = Date()
        }
    }

    @Model
    final class CachedArtist {
        @Attribute(.unique) var id: Int
        var name: String
        var coverUrl: String?
        var briefDesc: String?
        var albumSize: Int?
        var musicSize: Int?
        var cachedAt: Date
        var lastAccessedAt: Date?

        init(id: Int) {
            self.id = id
            self.name = ""
            self.cachedAt = Date()
        }
    }

    @Model
    final class PlayHistory {
        @Attribute(.unique) var id: UUID
        var songId: Int
        var songName: String
        var artistName: String
        var coverUrl: String?
        var playedAt: Date
        var playDuration: Int
        var completed: Bool
        var trackDuration: Int = 0
        var effectivePlay: Bool = false
        var qualificationVersion: Int = 0
        var sourceRaw: String?
        var qqMid: String?
        var qqAlbumMid: String?
        var qishuiTrackId: Int?
        var appleMusicID: String?
        var appleMusicISRC: String?

        init(id: UUID) {
            self.id = id
            self.songId = 0
            self.songName = ""
            self.artistName = ""
            self.playedAt = Date()
            self.playDuration = 0
            self.completed = false
            self.trackDuration = 0
            self.effectivePlay = false
            self.qualificationVersion = 0
        }
    }

    @Model
    final class SearchHistory {
        @Attribute(.unique) var id: UUID
        var keyword: String
        var searchedAt: Date
        var resultCount: Int

        init(id: UUID) {
            self.id = id
            self.keyword = ""
            self.searchedAt = Date()
            self.resultCount = 0
        }
    }

    @Model
    final class CachedLyrics {
        @Attribute(.unique) var songId: Int
        var lyrics: String
        var translatedLyrics: String?
        var cachedAt: Date

        init(songId: Int) {
            self.songId = songId
            self.lyrics = ""
            self.cachedAt = Date()
        }
    }

    @Model
    final class DownloadedSong {
        @Attribute(.unique) var uniqueKey: String
        var id: Int
        var name: String
        var artistName: String
        var albumName: String?
        var coverUrl: String?
        var duration: Int?
        var statusRaw: String
        var progress: Double
        var qualityRaw: String
        var localPath: String?
        var fileSize: Int64
        var downloadedAt: Date?
        var createdAt: Date
        var qqMid: String?
        var isQQMusic: Bool
        var qqQualityRaw: String?
        var isQishui: Bool = false
        var qishuiTrackId: Int?
        var qishuiQualityRaw: String?

        init(uniqueKey: String) {
            self.uniqueKey = uniqueKey
            self.id = 0
            self.name = ""
            self.artistName = ""
            self.statusRaw = "waiting"
            self.progress = 0
            self.qualityRaw = ""
            self.fileSize = 0
            self.createdAt = Date()
            self.qqMid = nil
            self.isQQMusic = false
            self.isQishui = false
        }
    }

    @Model
    final class LocalPlaylist {
        @Attribute(.unique) var id: String
        var name: String
        var desc: String?
        var coverUrl: String?
        var createdAt: Date
        var updatedAt: Date
        var songsData: Data?
        var isSystem: Bool = false

        init(id: String) {
            self.id = id
            self.name = ""
            self.createdAt = Date()
            self.updatedAt = Date()
            self.isSystem = false
        }
    }
}
