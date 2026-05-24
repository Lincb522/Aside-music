// NeteaseEmojiPicker.swift
// ncm表情选择器

import SwiftUI

// MARK: - ncm表情数据

enum NeteaseEmojiCategory: String, CaseIterable {
    case face = "表情"
    case gesture = "手势"
    case object = "物品"
    case nature = "自然"

    var emojis: [NeteaseEmoji] {
        switch self {
        case .face: return Self.faceEmojis
        case .gesture: return Self.gestureEmojis
        case .object: return Self.objectEmojis
        case .nature: return Self.natureEmojis
        }
    }

    static let faceEmojis: [NeteaseEmoji] = [
        NeteaseEmoji(String(localized: "[大笑]"), "😄"), NeteaseEmoji(String(localized: "[可爱]"), "🥰"),
        NeteaseEmoji(String(localized: "[憨笑]"), "😁"), NeteaseEmoji(String(localized: "[色]"), "😍"),
        NeteaseEmoji(String(localized: "[亲亲]"), "😘"), NeteaseEmoji(String(localized: "[惊恐]"), "😱"),
        NeteaseEmoji(String(localized: "[流泪]"), "😢"), NeteaseEmoji(String(localized: "[亲]"), "😚"),
        NeteaseEmoji(String(localized: "[呆]"), "😳"), NeteaseEmoji(String(localized: "[哀伤]"), "😞"),
        NeteaseEmoji(String(localized: "[呲牙]"), "😬"), NeteaseEmoji(String(localized: "[吐舌]"), "😛"),
        NeteaseEmoji(String(localized: "[撇嘴]"), "😒"), NeteaseEmoji(String(localized: "[怒]"), "😠"),
        NeteaseEmoji(String(localized: "[奸笑]"), "😏"), NeteaseEmoji(String(localized: "[汗]"), "😅"),
        NeteaseEmoji(String(localized: "[痛苦]"), "😣"), NeteaseEmoji(String(localized: "[惶恐]"), "😨"),
        NeteaseEmoji(String(localized: "[生病]"), "🤒"), NeteaseEmoji(String(localized: "[口罩]"), "😷"),
        NeteaseEmoji(String(localized: "[大哭]"), "😭"), NeteaseEmoji(String(localized: "[晕]"), "😵"),
        NeteaseEmoji(String(localized: "[发怒]"), "😡"), NeteaseEmoji(String(localized: "[开心]"), "😊"),
        NeteaseEmoji(String(localized: "[鬼脸]"), "😜"), NeteaseEmoji(String(localized: "[皱眉]"), "😟"),
        NeteaseEmoji(String(localized: "[流感]"), "🤧"), NeteaseEmoji(String(localized: "[思考]"), "🤔"),
        NeteaseEmoji(String(localized: "[闭嘴]"), "🤐"), NeteaseEmoji(String(localized: "[傻笑]"), "😋"),
        NeteaseEmoji(String(localized: "[悲伤]"), "😥"), NeteaseEmoji(String(localized: "[得意]"), "😎"),
        NeteaseEmoji(String(localized: "[困]"), "😪"), NeteaseEmoji(String(localized: "[害怕]"), "😰"),
        NeteaseEmoji(String(localized: "[睡觉]"), "😴"), NeteaseEmoji(String(localized: "[冷]"), "🥶"),
        NeteaseEmoji(String(localized: "[无语]"), "😑"), NeteaseEmoji(String(localized: "[嘘]"), "🤫"),
        NeteaseEmoji(String(localized: "[翻白眼]"), "🙄"), NeteaseEmoji(String(localized: "[笑哭]"), "🥲"),
    ]

    static let gestureEmojis: [NeteaseEmoji] = [
        NeteaseEmoji(String(localized: "[强]"), "👍"), NeteaseEmoji(String(localized: "[弱]"), "👎"),
        NeteaseEmoji(String(localized: "[拜]"), "🙏"), NeteaseEmoji(String(localized: "[握手]"), "🤝"),
        NeteaseEmoji(String(localized: "[鼓掌]"), "👏"), NeteaseEmoji(String(localized: "[拳头]"), "✊"),
        NeteaseEmoji("[OK]", "👌"), NeteaseEmoji(String(localized: "[胜利]"), "✌️"),
        NeteaseEmoji(String(localized: "[抱拳]"), "🤜"), NeteaseEmoji(String(localized: "[勾引]"), "👆"),
        NeteaseEmoji(String(localized: "[拳]"), "👊"), NeteaseEmoji(String(localized: "[差劲]"), "👎"),
        NeteaseEmoji(String(localized: "[赞]"), "👍"), NeteaseEmoji(String(localized: "[爱你]"), "🤟"),
        NeteaseEmoji("[NO]", "🙅"), NeteaseEmoji(String(localized: "[保佑]"), "🙏"),
        NeteaseEmoji(String(localized: "[举手]"), "🙋"), NeteaseEmoji(String(localized: "[作揖]"), "🙇"),
        NeteaseEmoji(String(localized: "[牵手]"), "🤝"), NeteaseEmoji(String(localized: "[跳舞]"), "💃"),
    ]

    static let objectEmojis: [NeteaseEmoji] = [
        NeteaseEmoji(String(localized: "[爱心]"), "❤️"), NeteaseEmoji(String(localized: "[心碎]"), "💔"),
        NeteaseEmoji(String(localized: "[钟情]"), "💕"), NeteaseEmoji(String(localized: "[爱意]"), "💗"),
        NeteaseEmoji(String(localized: "[示爱]"), "💓"), NeteaseEmoji(String(localized: "[嘴唇]"), "💋"),
        NeteaseEmoji(String(localized: "[星星]"), "⭐"), NeteaseEmoji(String(localized: "[生气]"), "💢"),
        NeteaseEmoji(String(localized: "[便便]"), "💩"), NeteaseEmoji(String(localized: "[钻石]"), "💎"),
        NeteaseEmoji(String(localized: "[礼物]"), "🎁"), NeteaseEmoji(String(localized: "[蛋糕]"), "🎂"),
        NeteaseEmoji(String(localized: "[音乐]"), "🎵"), NeteaseEmoji(String(localized: "[麦克风]"), "🎤"),
        NeteaseEmoji(String(localized: "[耳机]"), "🎧"), NeteaseEmoji(String(localized: "[咖啡]"), "☕"),
        NeteaseEmoji(String(localized: "[啤酒]"), "🍺"), NeteaseEmoji(String(localized: "[干杯]"), "🍻"),
        NeteaseEmoji(String(localized: "[菜刀]"), "🔪"), NeteaseEmoji(String(localized: "[炸弹]"), "💣"),
        NeteaseEmoji(String(localized: "[药丸]"), "💊"), NeteaseEmoji(String(localized: "[足球]"), "⚽"),
        NeteaseEmoji(String(localized: "[篮球]"), "🏀"), NeteaseEmoji("[18]", "🔞"),
    ]

    static let natureEmojis: [NeteaseEmoji] = [
        NeteaseEmoji(String(localized: "[太阳]"), "☀️"), NeteaseEmoji(String(localized: "[月亮]"), "🌙"),
        NeteaseEmoji(String(localized: "[彩虹]"), "🌈"), NeteaseEmoji(String(localized: "[雪花]"), "❄️"),
        NeteaseEmoji(String(localized: "[闪电]"), "⚡"), NeteaseEmoji(String(localized: "[火]"), "🔥"),
        NeteaseEmoji(String(localized: "[玫瑰]"), "🌹"), NeteaseEmoji(String(localized: "[凋谢]"), "🥀"),
        NeteaseEmoji(String(localized: "[狗]"), "🐶"), NeteaseEmoji(String(localized: "[猫]"), "🐱"),
        NeteaseEmoji(String(localized: "[猪]"), "🐷"), NeteaseEmoji(String(localized: "[兔子]"), "🐰"),
        NeteaseEmoji(String(localized: "[小鸡]"), "🐤"), NeteaseEmoji(String(localized: "[公鸡]"), "🐓"),
        NeteaseEmoji(String(localized: "[幽灵]"), "👻"), NeteaseEmoji(String(localized: "[圣诞]"), "🎅"),
        NeteaseEmoji(String(localized: "[外星]"), "👽"), NeteaseEmoji(String(localized: "[男孩]"), "👦"),
        NeteaseEmoji(String(localized: "[女孩]"), "👧"), NeteaseEmoji(String(localized: "[禁止]"), "🚫"),
        NeteaseEmoji(String(localized: "[圈]"), "⭕"), NeteaseEmoji(String(localized: "[叉]"), "❌"),
        NeteaseEmoji(String(localized: "[这边]"), "👉"), NeteaseEmoji("[100]", "💯"),
    ]
}

// MARK: - 表情选择器视图

struct NeteaseEmojiPicker: View {
    let onSelect: (String) -> Void
    @ObservedObject private var settings = SettingsManager.shared

    @State private var sections: [NeteaseEmojiSection] = NeteaseEmojiSection.fallbackSections
    @State private var selectedSectionID: String = NeteaseEmojiSection.fallbackSections.first?.id ?? ""
    @State private var didLoadRemoteEmojis = false
    @State private var isLoadingRemoteEmojis = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    private var selectedSection: NeteaseEmojiSection {
        sections.first { $0.id == selectedSectionID }
            ?? sections.first
            ?? NeteaseEmojiSection.fallbackSections[0]
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.monologueSeparator)
                .frame(height: 0.5)

            categoryTabs
            emojiGrid
        }
        .frame(height: 220)
        .background(.clear).monologueGlass(cornerRadius: 16)
        .task {
            await loadRemoteEmojisIfNeeded()
        }
    }

    // MARK: - 分类标签

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(sections) { section in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedSectionID = section.id
                        }
                    } label: {
                        Text(section.title)
                            .font(.system(size: 13, weight: selectedSectionID == section.id ? .bold : .medium, design: .rounded))
                            .foregroundColor(selectedSectionID == section.id ? .monologueTextPrimary : .monologueTextSecondary)
                            .lineLimit(1)
                            .frame(minWidth: 68)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .background(
                                selectedSectionID == section.id ?
                                Color.monologueTextPrimary.opacity(0.06) : Color.clear
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color.monologueTextPrimary.opacity(0.02))
    }

    // MARK: - 表情网格

    private var emojiGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(selectedSection.emojis) { emoji in
                    Button {
                        onSelect(emoji.code)
                    } label: {
                        emojiCell(emoji)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    @ViewBuilder
    private func emojiCell(_ emoji: NeteaseEmoji) -> some View {
        if let imageURL = emoji.imageURL {
            CachedAsyncImage(url: imageURL.sized(96), width: 32, height: 32) {
                Text(emoji.emoji)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.monologueTextPrimary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .frame(width: 32, height: 32)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .accessibilityLabel(emoji.name)
        } else {
            Text(emoji.emoji)
                .font(.system(size: 28))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .accessibilityLabel(emoji.name)
        }
    }

    @MainActor
    private func loadRemoteEmojisIfNeeded() async {
        guard !didLoadRemoteEmojis, !isLoadingRemoteEmojis else { return }
        didLoadRemoteEmojis = true
        isLoadingRemoteEmojis = true

        defer { isLoadingRemoteEmojis = false }

        do {
            let remoteSections = try await APIService.shared.fetchCommentEmojiSections().async()
            guard !remoteSections.isEmpty else { return }
            sections = remoteSections
            selectedSectionID = remoteSections.first?.id ?? selectedSectionID
            AppLogger.info("[CommentEmoji] loaded sections=\(remoteSections.count) emojis=\(remoteSections.reduce(0) { $0 + $1.emojis.count })")
        } catch {
            AppLogger.warning("[CommentEmoji] load remote emojis failed, using fallback: \(error)")
        }
    }
}

extension NeteaseEmojiSection {
    static var fallbackSections: [NeteaseEmojiSection] {
        NeteaseEmojiCategory.allCases.map { category in
            NeteaseEmojiSection(
                id: category.rawValue,
                title: category.rawValue,
                emojis: category.emojis
            )
        }
    }
}
