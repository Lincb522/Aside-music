import Foundation

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
