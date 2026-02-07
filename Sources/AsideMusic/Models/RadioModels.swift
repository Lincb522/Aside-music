import Foundation
import UIKit

// MARK: - 电台模型

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
        guard let duration = duration else { return "" }
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

    var iconUrl: URL? {
        if let url = pic96x96Url { return URL(string: url) }
        if let url = picWebUrl { return URL(string: url) }
        if let url = pic56x56Url { return URL(string: url) }
        if let url = pic84x84IdUrl { return URL(string: url) }
        return nil
    }

    /// 从 Bundle 加载本地分类图标（根据外观模式选择黑/白版本）
    func localIconImage(for colorScheme: UIUserInterfaceStyle) -> UIImage? {
        let prefix = colorScheme == .dark ? "dark" : "light"
        let filename = "\(prefix)_cat_\(id)"
        let subdir = "CategoryIcons/\(prefix)"
        // 尝试从 main bundle 加载
        if let path = Bundle.main.path(forResource: filename, ofType: "jpg", inDirectory: subdir) {
            return UIImage(contentsOfFile: path)
        }
        // 尝试从 SPM resource bundle 加载
        if let bundle = Bundle.asideResources,
           let url = bundle.url(forResource: filename, withExtension: "jpg", subdirectory: subdir),
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }

    /// 根据分类名称映射到 AsideIcon 图标类型
    var asideIconType: AsideIcon.IconType {
        // 分类名称到图标的映射表
        let mapping: [String: AsideIcon.IconType] = [
            "音乐": .catMusic,
            "音乐播客": .catPodcast,
            "生活": .catLife,
            "情感": .catEmotion,
            "创作|翻唱": .catCreate,
            "创作翻唱": .catCreate,
            "创作": .catCreate,
            "翻唱": .catCreate,
            "二次元": .catAcg,
            "娱乐": .catEntertain,
            "脱口秀": .catTalkshow,
            "有声书": .catBook,
            "知识": .catKnowledge,
            "商业财经": .catBusiness,
            "商业": .catBusiness,
            "财经": .catBusiness,
            "人文历史": .catHistory,
            "历史": .catHistory,
            "新闻资讯": .catNews,
            "新闻": .catNews,
            "资讯": .catNews,
            "亲子": .catParenting,
            "旅途": .catTravel,
            "旅行": .catTravel,
            "相声曲艺": .catCrosstalk,
            "相声": .catCrosstalk,
            "曲艺": .catCrosstalk,
            "美食": .catFood,
            "科技": .catTech,
            "电台": .radio,
            "电音": .catElectronic,
            "明星专区": .catStar,
            "明星": .catStar,
            "广播剧": .catDrama,
            "故事": .catStory,
            "其他": .catOther,
            "文学出版": .catPublish,
            "文学": .catPublish,
            "出版": .catPublish,
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
