import Foundation

// MARK: - 电台模型

/// 播客或电台的基础信息，以平台电台 ID 作为稳定身份。
struct RadioStation: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let picUrl: String?
    let dj: DJUser?
    let programCount: Int?
    let subCount: Int?
    let desc: String?
    let categoryId: Int?
    let category: String?

    var coverUrl: URL? {
        guard let picUrl = picUrl else { return nil }
        return URL(string: picUrl)
    }

    static func == (lhs: RadioStation, rhs: RadioStation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct DJUser: Codable, Hashable {
    let userId: Int?
    let nickname: String?
    let avatarUrl: String?
}

// MARK: - 电台节目模型

/// 电台中的单集节目；封面缺失时回退到主歌曲封面。
struct RadioProgram: Identifiable, Codable {
    let id: Int
    let name: String?
    let duration: Int?
    let listenerCount: Int?
    let coverUrl: String?
    let mainSong: Song?
    let serialNum: Int?
    let createTime: Int?
    let radio: RadioStation?

    var programCoverUrl: URL? {
        if let coverUrl = coverUrl { return URL(string: coverUrl) }
        return mainSong?.coverUrl
    }

    var durationText: String {
        guard let duration = duration, duration > 0 else { return "" }
        let seconds = duration / 1000
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}


// MARK: - 电台分类模型

struct RadioCategory: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    // API 返回的图片 URL 字段（字符串）
    let picWebUrl: String?
    let pic96x96Url: String?
    let pic56x56Url: String?
    let pic84x84IdUrl: String?

    /// 图标 URL（96x96 优先）
    var iconUrl: URL? {
        if let url = pic96x96Url { return URL(string: url) }
        if let url = picWebUrl { return URL(string: url) }
        if let url = pic56x56Url { return URL(string: url) }
        if let url = pic84x84IdUrl { return URL(string: url) }
        return nil
    }

    /// 根据分类名称映射到 MonologueIcon 图标类型
    var monologueIconType: MonologueIcon.IconType {
        // 分类名称到图标的映射表
        let mapping: [String: MonologueIcon.IconType] = [
            String(localized: "音乐"): .catMusic,
            String(localized: "音乐播客"): .catPodcast,
            String(localized: "生活"): .catLife,
            String(localized: "情感"): .catEmotion,
            String(localized: "创作|翻唱"): .catCreate,
            String(localized: "创作翻唱"): .catCreate,
            String(localized: "创作"): .catCreate,
            String(localized: "翻唱"): .catCreate,
            String(localized: "二次元"): .catAcg,
            String(localized: "娱乐"): .catEntertain,
            String(localized: "脱口秀"): .catTalkshow,
            String(localized: "有声书"): .catBook,
            String(localized: "知识"): .catKnowledge,
            String(localized: "商业财经"): .catBusiness,
            String(localized: "商业"): .catBusiness,
            String(localized: "财经"): .catBusiness,
            String(localized: "人文历史"): .catHistory,
            String(localized: "历史"): .catHistory,
            String(localized: "新闻资讯"): .catNews,
            String(localized: "新闻"): .catNews,
            String(localized: "资讯"): .catNews,
            String(localized: "亲子"): .catParenting,
            String(localized: "旅途"): .catTravel,
            String(localized: "旅行"): .catTravel,
            String(localized: "相声曲艺"): .catCrosstalk,
            String(localized: "相声"): .catCrosstalk,
            String(localized: "曲艺"): .catCrosstalk,
            String(localized: "美食"): .catFood,
            String(localized: "科技"): .catTech,
            String(localized: "电台"): .radio,
            String(localized: "电音"): .catElectronic,
            String(localized: "明星专区"): .catStar,
            String(localized: "明星"): .catStar,
            String(localized: "广播剧"): .catDrama,
            String(localized: "故事"): .catStory,
            String(localized: "其他"): .catOther,
            String(localized: "文学出版"): .catPublish,
            String(localized: "文学"): .catPublish,
            String(localized: "出版"): .catPublish,
        ]
        return mapping[name] ?? .catDefault
    }
}

// MARK: - API 响应包装

struct DJPersonalizeResponse: Codable {
    let data: [RadioStation]?
}

struct DJCategoryResponse: Codable {
    let categories: [RadioCategory]?
}

struct DJRecommendResponse: Codable {
    let djRadios: [RadioStation]?
}

struct DJDetailResponse: Codable {
    let data: RadioStation?
}

struct DJProgramResponse: Codable {
    let programs: [RadioProgram]?
    let count: Int?
}

struct DJCategoryHotResponse: Codable {
    let djRadios: [RadioStation]?
    let hasMore: Bool?
}

struct DJToplistResponse: Codable {
    let toplist: [RadioStation]?
}

struct DJSearchResponse: Codable {
    let result: DJSearchResult?
}

struct DJSearchResult: Codable {
    let djRadios: [RadioStation]?
    let djRadiosCount: Int?
}

struct DJHotResponse: Codable {
    let djRadios: [RadioStation]?
    let hasMore: Bool?
}

struct DJSublistResponse: Codable {
    let djRadios: [RadioStation]?
    let count: Int?
    let hasMore: Bool?
    let time: Int?
}
