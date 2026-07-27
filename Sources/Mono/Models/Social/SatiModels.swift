import Foundation

// MARK: - 助眠解压模型

struct SatiTag: Identifiable, Codable, Hashable {
    let tag: String
    let tagDesc: String
    let text: String?

    var id: String { tag }
}

struct SatiResource: Identifiable, Codable, Hashable {
    let id: Int
    let djProgramId: Int?
    let trackId: Int?
    let name: String
    let pic: String?
    let dynamicEffectUrl: String?
    let category: String?
    let resourceType: Int?

    var playableTrackId: Int {
        trackId ?? djProgramId ?? id
    }

    var coverUrl: URL? {
        guard let pic, !pic.isEmpty else { return nil }
        return URL(string: pic)
    }

    var categoryTitle: String {
        Self.categoryTitle(for: category)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case djProgramId
        case trackId
        case name
        case pic
        case dynamicEffectUrl
        case category
        case resourceType
    }

    init(
        id: Int,
        djProgramId: Int?,
        trackId: Int?,
        name: String,
        pic: String?,
        dynamicEffectUrl: String?,
        category: String?,
        resourceType: Int?
    ) {
        self.id = id
        self.djProgramId = djProgramId
        self.trackId = trackId
        self.name = name
        self.pic = pic
        self.dynamicEffectUrl = dynamicEffectUrl
        self.category = category
        self.resourceType = resourceType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        djProgramId = try container.decodeFlexibleInt(forKey: .djProgramId)
        trackId = try container.decodeFlexibleInt(forKey: .trackId)
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        pic = try? container.decodeIfPresent(String.self, forKey: .pic)
        dynamicEffectUrl = try? container.decodeIfPresent(String.self, forKey: .dynamicEffectUrl)
        category = try? container.decodeIfPresent(String.self, forKey: .category)
        resourceType = try container.decodeFlexibleInt(forKey: .resourceType)
    }

    static func categoryTitle(for category: String?) -> String {
        switch category {
        case "RCMD": return "热门"
        case "sleep": return "助眠"
        case "meditation": return "冥想"
        case "starGoodNight": return "明星哄睡"
        case "lightmusic": return "轻音乐"
        case "goodnightStory": return "晚安故事"
        case "dokodemo": return "任意门"
        case "cloudStudyRoom": return "云上自习室"
        case "relax": return "解压"
        case "naturalMusic": return "空灵乐器"
        default:
            return category?.isEmpty == false ? category! : "助眠解压"
        }
    }
}

struct SatiScene: Codable, Hashable {
    let sceneId: String?
    let text: String?
    let startTime: String?
    let endTime: String?
}

struct SatiTimesceneData: Codable, Hashable {
    let sceneVO: SatiScene?
    let voiceSatiResourceVOList: [SatiResource]?

    var resources: [SatiResource] {
        voiceSatiResourceVOList ?? []
    }
}

enum MeditationContentSource: Hashable {
    case radio(RadioStation)
    case sati(SatiResource)
}

struct MeditationContentItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String?
    let coverURL: URL?
    let category: String?
    let source: MeditationContentSource
}

enum MeditationPlaybackSource: Hashable {
    private static let satiRadioId = -8_602_400
    private static let satiRadioName = "助眠解压"

    case radio(RadioStation)
    case sati(resources: [SatiResource], startResource: SatiResource)

    var radio: RadioStation {
        switch self {
        case .radio(let radio):
            return radio
        case .sati(_, let startResource):
            return RadioStation(
                id: Self.satiRadioId,
                name: Self.satiRadioName,
                picUrl: startResource.pic,
                dj: nil,
                programCount: nil,
                subCount: nil,
                desc: startResource.categoryTitle,
                categoryId: nil,
                category: Self.satiRadioName
            )
        }
    }

    var preferredStartSongID: Int? {
        switch self {
        case .radio:
            return nil
        case .sati(_, let startResource):
            return startResource.playableTrackId
        }
    }

    var normalizedSatiResources: [SatiResource] {
        guard case .sati(let resources, let startResource) = self else { return [] }
        var seen = Set<Int>()
        var result: [SatiResource] = []

        for resource in [startResource] + resources {
            let key = resource.playableTrackId
            guard key > 0, seen.insert(key).inserted else { continue }
            result.append(resource)
        }

        return result
    }
}

extension SatiResource {
    func asSong(radioId: Int, radioName: String) -> Song {
        var song = Song(
            id: playableTrackId,
            name: name,
            ar: nil,
            al: Album(id: 0, name: radioName, picUrl: pic),
            dt: nil,
            fee: nil,
            mv: nil,
            h: nil,
            m: nil,
            l: nil,
            sq: nil,
            hr: nil,
            alia: nil
        )
        song.podcastCoverUrl = pic
        song.podcastRadioId = radioId
        song.podcastRadioName = radioName
        song.source = .netease
        return song
    }

    func asRadioProgram(serialNum: Int, radio: RadioStation) -> RadioProgram {
        RadioProgram(
            id: djProgramId ?? playableTrackId,
            name: name,
            duration: nil,
            listenerCount: nil,
            coverUrl: pic,
            mainSong: asSong(radioId: radio.id, radioName: radio.name),
            serialNum: serialNum,
            createTime: nil,
            radio: radio
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }
}
