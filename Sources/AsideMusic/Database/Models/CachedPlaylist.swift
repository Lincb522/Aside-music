import Foundation
import SwiftData

/// 缓存的歌单数据模型
@Model
final class CachedPlaylist {
    @Attribute(.unique) var id: Int
    var name: String
    var coverUrl: String?
    var creatorName: String?
    var trackCount: Int?
    var playCount: Int?
    var desc: String?
    
    /// 标签存储为 JSON 字符串（可选，用于迁移兼容）
    var tagsData: String?
    
    var cachedAt: Date
    var lastAccessedAt: Date?
    
    /// 歌单内歌曲 ID 列表存储为 JSON 字符串（可选，用于迁移兼容）
    var trackIdsData: String?
    
    /// 标签数组（计算属性）
    var tags: [String]? {
        get {
            guard let data = tagsData?.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            if let newValue = newValue,
               let data = try? JSONEncoder().encode(newValue) {
                tagsData = String(data: data, encoding: .utf8)
            } else {
                tagsData = nil
            }
        }
    }
    
    /// 歌曲 ID 数组（计算属性）
    var trackIds: [Int] {
        get {
            guard let data = trackIdsData?.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([Int].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                trackIdsData = String(data: data, encoding: .utf8)
            } else {
                trackIdsData = nil
            }
        }
    }
    
    init(
        id: Int,
        name: String,
        coverUrl: String? = nil,
        creatorName: String? = nil,
        trackCount: Int? = nil,
        playCount: Int? = nil,
        desc: String? = nil,
        tags: [String]? = nil,
        trackIds: [Int] = []
    ) {
        self.id = id
        self.name = name
        self.coverUrl = coverUrl
        self.creatorName = creatorName
        self.trackCount = trackCount
        self.playCount = playCount
        self.desc = desc
        self.cachedAt = Date()
        self.lastAccessedAt = nil
        
        // 初始化存储属性
        self.tagsData = nil
        self.trackIdsData = nil
        
        // 设置计算属性
        self.tags = tags
        self.trackIds = trackIds
    }
    
    /// 从 Playlist 模型创建
    convenience init(from playlist: Playlist, trackIds: [Int] = []) {
        self.init(
            id: playlist.id,
            name: playlist.name,
            coverUrl: playlist.coverUrl?.absoluteString,
            creatorName: playlist.creator?.nickname,
            trackCount: playlist.trackCount,
            playCount: playlist.playCount,
            desc: playlist.description,
            tags: playlist.tags,
            trackIds: trackIds
        )
    }
    
    /// 转换为 Playlist 模型
    func toPlaylist() -> Playlist {
        var creator: Creator? = nil
        if let creatorName = creatorName {
            creator = Creator(nickname: creatorName, avatarUrl: nil)
        }
        
        return Playlist(
            id: id,
            name: name,
            coverImgUrl: coverUrl,
            picUrl: nil,
            trackCount: trackCount,
            playCount: playCount,
            subscribedCount: nil,
            shareCount: nil,
            commentCount: nil,
            creator: creator,
            description: desc,
            tags: tags
        )
    }
    
    /// 记录访问
    func recordAccess() {
        lastAccessedAt = Date()
    }
}
