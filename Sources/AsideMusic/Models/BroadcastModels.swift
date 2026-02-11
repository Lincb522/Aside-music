import Foundation

// MARK: - 广播电台模型（地区 FM 广播）

/// 广播频道
struct BroadcastChannel: Identifiable, Codable, Hashable {
    let id: Int
    let name: String?
    let coverUrl: String?
    let categoryId: Int?
    let regionId: Int?
    let currentProgram: String?
    let score: Double?
    
    // 备用字段名（后端可能返回不同的 key）
    let channelName: String?
    let picUrl: String?
    let programName: String?

    enum CodingKeys: String, CodingKey {
        case id, name, coverUrl, categoryId, regionId, currentProgram, score
        case channelName, picUrl, programName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
        categoryId = try container.decodeIfPresent(Int.self, forKey: .categoryId)
        regionId = try container.decodeIfPresent(Int.self, forKey: .regionId)
        currentProgram = try container.decodeIfPresent(String.self, forKey: .currentProgram)
        score = try container.decodeIfPresent(Double.self, forKey: .score)
        channelName = try container.decodeIfPresent(String.self, forKey: .channelName)
        picUrl = try container.decodeIfPresent(String.self, forKey: .picUrl)
        programName = try container.decodeIfPresent(String.self, forKey: .programName)
    }

    /// 显示名称（兼容多种字段）
    var displayName: String {
        name ?? channelName ?? "未知电台"
    }

    /// 封面图 URL（兼容多种字段）
    var coverImageUrl: URL? {
        if let coverUrl = coverUrl, let url = URL(string: coverUrl) { return url }
        if let picUrl = picUrl, let url = URL(string: picUrl) { return url }
        return nil
    }
    
    /// 当前节目名（兼容多种字段）
    var displayProgram: String? {
        currentProgram ?? programName
    }

    static func == (lhs: BroadcastChannel, rhs: BroadcastChannel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// 广播电台地区
struct BroadcastRegion: Identifiable, Codable, Hashable {
    let id: Int
    let name: String?

    static func == (lhs: BroadcastRegion, rhs: BroadcastRegion) -> Bool {
        lhs.id == rhs.id
    }
}

/// 广播电台分类
struct BroadcastCategory: Identifiable, Codable, Hashable {
    let id: Int
    let name: String?

    static func == (lhs: BroadcastCategory, rhs: BroadcastCategory) -> Bool {
        lhs.id == rhs.id
    }
}
