// iOS 17+ 持久化后端：使用与旧版 @Model 完全一致的镜像实体，
// 嵌套在 SDStore 命名空间内（实体名仍为无限定类名），保证老用户数据无缝复用。

import Foundation
import SwiftData

@available(iOS 17, *)
enum SDStore {
    @Model
    final class CachedSong {
        var id: Int
        @Attribute(.unique) var uniqueKey: String?
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
        var songData: Data?
        var appleMusicISRC: String?
        var kugouAlbumAudioID: Int?
        var kugouAlbumID: Int?
        var kugouHash: String?

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
        var kugouAlbumAudioID: Int?
        var kugouAlbumID: Int?
        var kugouHash: String?

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
        var songId: Int
        @Attribute(.unique) var uniqueKey: String?
        var sourceRaw: String?
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

// MARK: - 镜像模型与快照互转

@available(iOS 17, *)
protocol SDMirrorModel: PersistentModel {
    init(mirrorKey: String)
    var mirrorKey: String { get }
    func applySnapshot(_ s: [String: Any?])
    func makeSnapshot() -> [String: Any?]
}

@available(iOS 17, *)
extension SDStore.CachedSong: SDMirrorModel {
    convenience init(mirrorKey: String) { self.init(id: 0); uniqueKey = mirrorKey }
    var mirrorKey: String { uniqueKey ?? CachedSong.monoMake(from: makeSnapshot()).monoUniqueKey }

    func applySnapshot(_ s: [String: Any?]) {
        typealias V = MonoSnapshotValue
        id = V.int(s, "id"); name = V.string(s, "name"); artistName = V.string(s, "artistName")
        albumName = V.stringOpt(s, "albumName"); coverUrl = V.stringOpt(s, "coverUrl")
        duration = V.intOpt(s, "duration"); cachedAt = V.date(s, "cachedAt")
        lastPlayedAt = V.dateOpt(s, "lastPlayedAt"); playCount = V.int(s, "playCount")
        maxBitrate = V.intOpt(s, "maxBitrate"); fee = V.intOpt(s, "fee")
        canPlay = V.bool(s, "canPlay", default: true); sourceRaw = V.stringOpt(s, "sourceRaw")
        qqMid = V.stringOpt(s, "qqMid"); qishuiTrackId = V.intOpt(s, "qishuiTrackId")
        appleMusicID = V.stringOpt(s, "appleMusicID")
        songData = V.dataOpt(s, "songData")
        uniqueKey = CachedSong.monoMake(from: s).monoUniqueKey
        appleMusicISRC = V.stringOpt(s, "appleMusicISRC")
        kugouAlbumAudioID = V.intOpt(s, "kugouAlbumAudioID")
        kugouAlbumID = V.intOpt(s, "kugouAlbumID")
        kugouHash = V.stringOpt(s, "kugouHash")
    }

    func makeSnapshot() -> [String: Any?] {
        [
            "id": id, "name": name, "artistName": artistName, "albumName": albumName,
            "coverUrl": coverUrl, "duration": duration, "cachedAt": cachedAt,
            "lastPlayedAt": lastPlayedAt, "playCount": playCount, "maxBitrate": maxBitrate,
            "fee": fee, "canPlay": canPlay, "sourceRaw": sourceRaw, "qqMid": qqMid,
            "qishuiTrackId": qishuiTrackId, "appleMusicID": appleMusicID,
            "kugouHash": kugouHash, "kugouAlbumID": kugouAlbumID, "kugouAlbumAudioID": kugouAlbumAudioID, "songData": songData, "appleMusicISRC": appleMusicISRC
        ]
    }
}

@available(iOS 17, *)
extension SDStore.CachedPlaylist: SDMirrorModel {
    convenience init(mirrorKey: String) { self.init(id: Int(mirrorKey) ?? 0) }
    var mirrorKey: String { String(id) }

    func applySnapshot(_ s: [String: Any?]) {
        typealias V = MonoSnapshotValue
        id = V.int(s, "id"); name = V.string(s, "name"); coverUrl = V.stringOpt(s, "coverUrl")
        creatorName = V.stringOpt(s, "creatorName"); trackCount = V.intOpt(s, "trackCount")
        playCount = V.intOpt(s, "playCount"); desc = V.stringOpt(s, "desc")
        tagsData = V.stringOpt(s, "tagsData"); cachedAt = V.date(s, "cachedAt")
        lastAccessedAt = V.dateOpt(s, "lastAccessedAt"); trackIdsData = V.stringOpt(s, "trackIdsData")
    }

    func makeSnapshot() -> [String: Any?] {
        [
            "id": id, "name": name, "coverUrl": coverUrl, "creatorName": creatorName,
            "trackCount": trackCount, "playCount": playCount, "desc": desc,
            "tagsData": tagsData, "cachedAt": cachedAt, "lastAccessedAt": lastAccessedAt,
            "trackIdsData": trackIdsData
        ]
    }
}

@available(iOS 17, *)
extension SDStore.CachedArtist: SDMirrorModel {
    convenience init(mirrorKey: String) { self.init(id: Int(mirrorKey) ?? 0) }
    var mirrorKey: String { String(id) }

    func applySnapshot(_ s: [String: Any?]) {
        typealias V = MonoSnapshotValue
        id = V.int(s, "id"); name = V.string(s, "name"); coverUrl = V.stringOpt(s, "coverUrl")
        briefDesc = V.stringOpt(s, "briefDesc"); albumSize = V.intOpt(s, "albumSize")
        musicSize = V.intOpt(s, "musicSize"); cachedAt = V.date(s, "cachedAt")
        lastAccessedAt = V.dateOpt(s, "lastAccessedAt")
    }

    func makeSnapshot() -> [String: Any?] {
        [
            "id": id, "name": name, "coverUrl": coverUrl, "briefDesc": briefDesc,
            "albumSize": albumSize, "musicSize": musicSize, "cachedAt": cachedAt,
            "lastAccessedAt": lastAccessedAt
        ]
    }
}

@available(iOS 17, *)
extension SDStore.PlayHistory: SDMirrorModel {
    convenience init(mirrorKey: String) { self.init(id: UUID(uuidString: mirrorKey) ?? UUID()) }
    var mirrorKey: String { id.uuidString }

    func applySnapshot(_ s: [String: Any?]) {
        typealias V = MonoSnapshotValue
        id = V.uuid(s, "id"); songId = V.int(s, "songId"); songName = V.string(s, "songName")
        artistName = V.string(s, "artistName"); coverUrl = V.stringOpt(s, "coverUrl")
        playedAt = V.date(s, "playedAt"); playDuration = V.int(s, "playDuration")
        completed = V.bool(s, "completed"); trackDuration = V.int(s, "trackDuration")
        effectivePlay = V.bool(s, "effectivePlay")
        qualificationVersion = V.int(s, "qualificationVersion")
        sourceRaw = V.stringOpt(s, "sourceRaw")
        qqMid = V.stringOpt(s, "qqMid"); qqAlbumMid = V.stringOpt(s, "qqAlbumMid")
        qishuiTrackId = V.intOpt(s, "qishuiTrackId")
        appleMusicID = V.stringOpt(s, "appleMusicID")
        appleMusicISRC = V.stringOpt(s, "appleMusicISRC")
        kugouAlbumAudioID = V.intOpt(s, "kugouAlbumAudioID")
        kugouAlbumID = V.intOpt(s, "kugouAlbumID")
        kugouHash = V.stringOpt(s, "kugouHash")
    }

    func makeSnapshot() -> [String: Any?] {
        [
            "id": id, "songId": songId, "songName": songName, "artistName": artistName,
            "coverUrl": coverUrl, "playedAt": playedAt, "playDuration": playDuration,
            "completed": completed, "trackDuration": trackDuration,
            "effectivePlay": effectivePlay, "qualificationVersion": qualificationVersion,
            "sourceRaw": sourceRaw, "qqMid": qqMid,
            "qqAlbumMid": qqAlbumMid, "qishuiTrackId": qishuiTrackId,
            "appleMusicID": appleMusicID, "kugouHash": kugouHash, "kugouAlbumID": kugouAlbumID, "kugouAlbumAudioID": kugouAlbumAudioID, "appleMusicISRC": appleMusicISRC
        ]
    }
}

@available(iOS 17, *)
extension SDStore.SearchHistory: SDMirrorModel {
    convenience init(mirrorKey: String) { self.init(id: UUID(uuidString: mirrorKey) ?? UUID()) }
    var mirrorKey: String { id.uuidString }

    func applySnapshot(_ s: [String: Any?]) {
        typealias V = MonoSnapshotValue
        id = V.uuid(s, "id"); keyword = V.string(s, "keyword")
        searchedAt = V.date(s, "searchedAt"); resultCount = V.int(s, "resultCount")
    }

    func makeSnapshot() -> [String: Any?] {
        ["id": id, "keyword": keyword, "searchedAt": searchedAt, "resultCount": resultCount]
    }
}

@available(iOS 17, *)
extension SDStore.CachedLyrics: SDMirrorModel {
    convenience init(mirrorKey: String) { self.init(songId: Int(mirrorKey) ?? 0) }
    var mirrorKey: String { uniqueKey ?? "\(sourceRaw ?? MusicSource.netease.rawValue):\(songId)" }

    func applySnapshot(_ s: [String: Any?]) {
        typealias V = MonoSnapshotValue
        songId = V.int(s, "songId")
        sourceRaw = V.stringOpt(s, "sourceRaw")
        uniqueKey = "\(sourceRaw ?? MusicSource.netease.rawValue):\(songId)"
        lyrics = V.string(s, "lyrics")
        translatedLyrics = V.stringOpt(s, "translatedLyrics"); cachedAt = V.date(s, "cachedAt")
    }

    func makeSnapshot() -> [String: Any?] {
        ["songId": songId, "sourceRaw": sourceRaw, "lyrics": lyrics, "translatedLyrics": translatedLyrics, "cachedAt": cachedAt]
    }
}

@available(iOS 17, *)
extension SDStore.DownloadedSong: SDMirrorModel {
    convenience init(mirrorKey: String) { self.init(uniqueKey: mirrorKey) }
    var mirrorKey: String { uniqueKey }

    func applySnapshot(_ s: [String: Any?]) {
        typealias V = MonoSnapshotValue
        uniqueKey = V.string(s, "uniqueKey", default: uniqueKey)
        id = V.int(s, "id"); name = V.string(s, "name"); artistName = V.string(s, "artistName")
        albumName = V.stringOpt(s, "albumName"); coverUrl = V.stringOpt(s, "coverUrl")
        duration = V.intOpt(s, "duration"); statusRaw = V.string(s, "statusRaw", default: "waiting")
        progress = V.double(s, "progress"); qualityRaw = V.string(s, "qualityRaw")
        localPath = V.stringOpt(s, "localPath"); fileSize = V.int64(s, "fileSize")
        downloadedAt = V.dateOpt(s, "downloadedAt"); createdAt = V.date(s, "createdAt")
        qqMid = V.stringOpt(s, "qqMid"); isQQMusic = V.bool(s, "isQQMusic")
        qqQualityRaw = V.stringOpt(s, "qqQualityRaw"); isQishui = V.bool(s, "isQishui")
        qishuiTrackId = V.intOpt(s, "qishuiTrackId"); qishuiQualityRaw = V.stringOpt(s, "qishuiQualityRaw")
    }

    func makeSnapshot() -> [String: Any?] {
        [
            "uniqueKey": uniqueKey, "id": id, "name": name, "artistName": artistName,
            "albumName": albumName, "coverUrl": coverUrl, "duration": duration,
            "statusRaw": statusRaw, "progress": progress, "qualityRaw": qualityRaw,
            "localPath": localPath, "fileSize": fileSize, "downloadedAt": downloadedAt,
            "createdAt": createdAt, "qqMid": qqMid, "isQQMusic": isQQMusic,
            "qqQualityRaw": qqQualityRaw, "isQishui": isQishui,
            "qishuiTrackId": qishuiTrackId, "qishuiQualityRaw": qishuiQualityRaw
        ]
    }
}

@available(iOS 17, *)
extension SDStore.LocalPlaylist: SDMirrorModel {
    convenience init(mirrorKey: String) { self.init(id: mirrorKey) }
    var mirrorKey: String { id }

    func applySnapshot(_ s: [String: Any?]) {
        typealias V = MonoSnapshotValue
        id = V.string(s, "id"); name = V.string(s, "name"); desc = V.stringOpt(s, "desc")
        coverUrl = V.stringOpt(s, "coverUrl"); createdAt = V.date(s, "createdAt")
        updatedAt = V.date(s, "updatedAt"); songsData = V.dataOpt(s, "songsData")
        isSystem = V.bool(s, "isSystem")
    }

    func makeSnapshot() -> [String: Any?] {
        [
            "id": id, "name": name, "desc": desc, "coverUrl": coverUrl,
            "createdAt": createdAt, "updatedAt": updatedAt,
            "songsData": songsData, "isSystem": isSystem
        ]
    }
}

// MARK: - 后端实现

@available(iOS 17, *)
@MainActor
final class SwiftDataBackend: MonoStoreBackend {
    let container: ModelContainer
    private let context: ModelContext

    /// 每个实体一份唯一键索引，避免逐条谓词查询
    private var indices: [String: [String: AnyObject]] = [:]

    private static var allModelTypes: [any PersistentModel.Type] {
        [
            SDStore.CachedSong.self, SDStore.CachedPlaylist.self, SDStore.CachedArtist.self,
            SDStore.PlayHistory.self, SDStore.SearchHistory.self, SDStore.CachedLyrics.self,
            SDStore.DownloadedSong.self, SDStore.LocalPlaylist.self
        ]
    }

    init(storeURL: URL? = nil) throws {
        let schema = Schema(Self.allModelTypes)
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = container.mainContext
        context.autosaveEnabled = false
        try preload(SDStore.CachedSong.self, "CachedSong")
        try preload(SDStore.CachedPlaylist.self, "CachedPlaylist")
        try preload(SDStore.CachedArtist.self, "CachedArtist")
        try preload(SDStore.PlayHistory.self, "PlayHistory")
        try preload(SDStore.SearchHistory.self, "SearchHistory")
        try preload(SDStore.CachedLyrics.self, "CachedLyrics")
        try preload(SDStore.DownloadedSong.self, "DownloadedSong")
        try preload(SDStore.LocalPlaylist.self, "LocalPlaylist")
        try flush()
    }

    // MARK: - MonoStoreBackend

    func loadAll(entityName: String) -> [[String: Any?]] {
        switch entityName {
        case "CachedSong": return loadAllTyped(SDStore.CachedSong.self, entityName)
        case "CachedPlaylist": return loadAllTyped(SDStore.CachedPlaylist.self, entityName)
        case "CachedArtist": return loadAllTyped(SDStore.CachedArtist.self, entityName)
        case "PlayHistory": return loadAllTyped(SDStore.PlayHistory.self, entityName)
        case "SearchHistory": return loadAllTyped(SDStore.SearchHistory.self, entityName)
        case "CachedLyrics": return loadAllTyped(SDStore.CachedLyrics.self, entityName)
        case "DownloadedSong": return loadAllTyped(SDStore.DownloadedSong.self, entityName)
        case "LocalPlaylist": return loadAllTyped(SDStore.LocalPlaylist.self, entityName)
        default: return []
        }
    }

    func upsert(entityName: String, uniqueKey: String, snapshot: [String: Any?]) {
        switch entityName {
        case "CachedSong": upsertTyped(SDStore.CachedSong.self, entityName, uniqueKey, snapshot)
        case "CachedPlaylist": upsertTyped(SDStore.CachedPlaylist.self, entityName, uniqueKey, snapshot)
        case "CachedArtist": upsertTyped(SDStore.CachedArtist.self, entityName, uniqueKey, snapshot)
        case "PlayHistory": upsertTyped(SDStore.PlayHistory.self, entityName, uniqueKey, snapshot)
        case "SearchHistory": upsertTyped(SDStore.SearchHistory.self, entityName, uniqueKey, snapshot)
        case "CachedLyrics": upsertTyped(SDStore.CachedLyrics.self, entityName, uniqueKey, snapshot)
        case "DownloadedSong": upsertTyped(SDStore.DownloadedSong.self, entityName, uniqueKey, snapshot)
        case "LocalPlaylist": upsertTyped(SDStore.LocalPlaylist.self, entityName, uniqueKey, snapshot)
        default: break
        }
    }

    func delete(entityName: String, uniqueKey: String) {
        switch entityName {
        case "CachedSong": deleteTyped(SDStore.CachedSong.self, entityName, uniqueKey)
        case "CachedPlaylist": deleteTyped(SDStore.CachedPlaylist.self, entityName, uniqueKey)
        case "CachedArtist": deleteTyped(SDStore.CachedArtist.self, entityName, uniqueKey)
        case "PlayHistory": deleteTyped(SDStore.PlayHistory.self, entityName, uniqueKey)
        case "SearchHistory": deleteTyped(SDStore.SearchHistory.self, entityName, uniqueKey)
        case "CachedLyrics": deleteTyped(SDStore.CachedLyrics.self, entityName, uniqueKey)
        case "DownloadedSong": deleteTyped(SDStore.DownloadedSong.self, entityName, uniqueKey)
        case "LocalPlaylist": deleteTyped(SDStore.LocalPlaylist.self, entityName, uniqueKey)
        default: break
        }
    }

    func deleteAll(entityName: String) {
        switch entityName {
        case "CachedSong": deleteAllTyped(SDStore.CachedSong.self, entityName)
        case "CachedPlaylist": deleteAllTyped(SDStore.CachedPlaylist.self, entityName)
        case "CachedArtist": deleteAllTyped(SDStore.CachedArtist.self, entityName)
        case "PlayHistory": deleteAllTyped(SDStore.PlayHistory.self, entityName)
        case "SearchHistory": deleteAllTyped(SDStore.SearchHistory.self, entityName)
        case "CachedLyrics": deleteAllTyped(SDStore.CachedLyrics.self, entityName)
        case "DownloadedSong": deleteAllTyped(SDStore.DownloadedSong.self, entityName)
        case "LocalPlaylist": deleteAllTyped(SDStore.LocalPlaylist.self, entityName)
        default: break
        }
    }

    func flush() throws {
        if context.hasChanges { try context.save() }
    }

    func storeSizeBytes() -> Int64 {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return 0
        }
        let dbPath = appSupport.appendingPathComponent("default.store")
        let attributes = try? fileManager.attributesOfItem(atPath: dbPath.path)
        return (attributes?[.size] as? Int64) ?? 0
    }

    // MARK: - 泛型实现

    private func preload<M: SDMirrorModel>(_ type: M.Type, _ entityName: String) throws {
        let all = try context.fetch(FetchDescriptor<M>())
        var index: [String: M] = [:]
        for model in all {
            // Backfill keys added by the platform identity migration.
            model.applySnapshot(model.makeSnapshot())
            index[model.mirrorKey] = model
        }
        indices[entityName] = index
    }

    private func index<M: SDMirrorModel>(_ type: M.Type, _ entityName: String) -> [String: M] {
        (indices[entityName] as? [String: M]) ?? [:]
    }

    private func loadAllTyped<M: SDMirrorModel>(_ type: M.Type, _ entityName: String) -> [[String: Any?]] {
        index(type, entityName).values.map { $0.makeSnapshot() }
    }

    private func upsertTyped<M: SDMirrorModel>(_ type: M.Type, _ entityName: String, _ uniqueKey: String, _ snapshot: [String: Any?]) {
        var idx = index(type, entityName)
        if let existing = idx[uniqueKey] {
            existing.applySnapshot(snapshot)
        } else {
            let model = M(mirrorKey: uniqueKey)
            model.applySnapshot(snapshot)
            context.insert(model)
            idx[uniqueKey] = model
            indices[entityName] = idx
        }
    }

    private func deleteTyped<M: SDMirrorModel>(_ type: M.Type, _ entityName: String, _ uniqueKey: String) {
        var idx = index(type, entityName)
        if let existing = idx.removeValue(forKey: uniqueKey) {
            context.delete(existing)
            indices[entityName] = idx
        }
    }

    private func deleteAllTyped<M: SDMirrorModel>(_ type: M.Type, _ entityName: String) {
        for model in index(type, entityName).values {
            context.delete(model)
        }
        indices[entityName] = [String: M]()
    }
}
