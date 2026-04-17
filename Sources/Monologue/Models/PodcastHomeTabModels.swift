import Foundation

// MARK: - 播客首页 Tab 数据模型（/podcast/home/tab）

struct PodcastHomeTabResponse: Codable {
    let code: Int
    let data: PodcastHomeTabData?
}

struct PodcastHomeTabData: Codable {
    let blockVOS: [PodcastBlock]?
}

struct PodcastBlock: Codable {
    let blockCode: String?
    let showType: String?
    let uiElement: PodcastBlockUI?
    let creatives: [PodcastCreative]?
}

struct PodcastCreative: Codable {
    let creativeId: String?
    let uiElement: PodcastCreativeUI?
    let creativeExtInfoVO: PodcastCreativeExtInfo?
    let resources: [PodcastResource]?
}

struct PodcastResource: Codable {
    let resourceId: String?
    let uiElement: PodcastCreativeUI?
    let resourceExtInfo: PodcastCreativeExtInfo?

    var asCreative: PodcastCreative {
        PodcastCreative(
            creativeId: resourceId,
            uiElement: uiElement,
            creativeExtInfoVO: resourceExtInfo,
            resources: nil
        )
    }
}

struct PodcastBlockUI: Codable {
    let mainTitle: PodcastTitle?
}

struct PodcastTitle: Codable {
    let title: String?
}



struct PodcastCreativeUI: Codable {
    let mainTitle: PodcastTitle?
    let image: PodcastImage?
}

struct PodcastImage: Codable {
    let imageUrl: String?
}

struct PodcastCreativeExtInfo: Codable {
    // 节目推荐 (RCMD_FOR_YOU / NEWEST_GOOD_VOICE_BLOCK)
    let djProgram: PodcastDJProgram?
    let playCount: Int?

    // 热门播客 (HOTTEST_VOICELIST_BLOCK)
    let radio: RadioStation?
    let voiceCount: Int?
    let subed: Bool?
}

struct PodcastDJProgram: Codable, Identifiable {
    let id: Int
    let name: String?
    let duration: Int?
    let radio: PodcastDJRadio?
    let dj: DJUser?
    let coverUrl: String?
    let mainSong: Song?

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

struct PodcastDJRadio: Codable {
    let id: Int?
    let name: String?
    let picUrl: String?
}
