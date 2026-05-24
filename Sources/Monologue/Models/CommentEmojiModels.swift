import Foundation

struct NeteaseEmoji: Identifiable, Hashable, Sendable {
    let id: String
    let code: String
    let emoji: String
    let name: String
    let imageURL: URL?
    let isVIPOnly: Bool

    init(_ code: String, _ emoji: String) {
        self.id = code
        self.code = code
        self.emoji = emoji
        self.name = code.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        self.imageURL = nil
        self.isVIPOnly = false
    }

    init(id: String, name: String, imageURL: URL?, isVIPOnly: Bool) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.name = trimmedName
        self.code = Self.commentCode(for: trimmedName)
        self.emoji = trimmedName.first.map(String.init) ?? "🙂"
        self.imageURL = imageURL
        self.isVIPOnly = isVIPOnly
    }

    private static func commentCode(for name: String) -> String {
        guard !name.isEmpty else { return "" }
        guard !name.hasPrefix("[") else { return name }
        return "[\(name)]"
    }
}

struct NeteaseEmojiSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let emojis: [NeteaseEmoji]
}

struct CommentEmojiAPIResponse: Decodable {
    struct Payload: Decodable {
        let groups: [Group]?
        let emojis: [Item]?
    }

    struct Group: Decodable {
        let groupId: LosslessString
        let groupName: String
        let emojis: [Item]
    }

    struct Item: Decodable {
        let emojiId: LosslessString
        let emojiGroupId: LosslessString?
        let emojiName: String?
        let name: String?
        let emojiImgUrl: String?
        let vip: Int?
    }

    struct LosslessString: Decodable, Hashable {
        let value: String

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let string = try? container.decode(String.self) {
                value = string
            } else if let int = try? container.decode(Int64.self) {
                value = String(int)
            } else if let double = try? container.decode(Double.self) {
                value = String(Int64(double))
            } else {
                value = ""
            }
        }
    }

    let data: Payload?

    func sections() -> [NeteaseEmojiSection] {
        if let groups = data?.groups, !groups.isEmpty {
            return groups.compactMap { group in
                let emojis = group.emojis.compactMap(Self.emoji(from:))
                guard !emojis.isEmpty else { return nil }
                return NeteaseEmojiSection(
                    id: group.groupId.value,
                    title: group.groupName,
                    emojis: emojis
                )
            }
        }

        if let emojis = data?.emojis?.compactMap(Self.emoji(from:)), !emojis.isEmpty {
            return [
                NeteaseEmojiSection(
                    id: "netease-emojis",
                    title: String(localized: "表情"),
                    emojis: emojis
                )
            ]
        }

        return []
    }

    private static func emoji(from item: Item) -> NeteaseEmoji? {
        let name = (item.emojiName ?? item.name ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let id = item.emojiId.value.isEmpty
            ? "\(item.emojiGroupId?.value ?? "emoji")-\(name)"
            : item.emojiId.value

        return NeteaseEmoji(
            id: id,
            name: name,
            imageURL: item.emojiImgUrl.flatMap(URL.init(string:)),
            isVIPOnly: (item.vip ?? -1) > 0
        )
    }
}
