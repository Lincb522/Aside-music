// NeteaseEmojiPicker.swift
// 网易云音乐表情选择器

import SwiftUI

// MARK: - 网易云表情数据

/// 网易云表情定义
struct NeteaseEmoji: Identifiable {
    let id: String
    let code: String      // 表情代码，如 [大笑]
    let emoji: String     // 对应的 Unicode emoji
    
    init(_ code: String, _ emoji: String) {
        self.id = code
        self.code = code
        self.emoji = emoji
    }
}

/// 网易云表情分类
enum NeteaseEmojiCategory: String, CaseIterable {
    case face = "表情"
    case gesture = "手势"
    case symbol = "符号"
    
    var emojis: [NeteaseEmoji] {
        switch self {
        case .face:
            return Self.faceEmojis
        case .gesture:
            return Self.gestureEmojis
        case .symbol:
            return Self.symbolEmojis
        }
    }
    
    // 表情类
    static let faceEmojis: [NeteaseEmoji] = [
        NeteaseEmoji("[大笑]", "😄"),
        NeteaseEmoji("[可爱]", "🥰"),
        NeteaseEmoji("[憨笑]", "😁"),
        NeteaseEmoji("[色]", "😍"),
        NeteaseEmoji("[亲亲]", "😘"),
        NeteaseEmoji("[惊恐]", "😱"),
        NeteaseEmoji("[流泪]", "😢"),
        NeteaseEmoji("[亲]", "😚"),
        NeteaseEmoji("[呆]", "😳"),
        NeteaseEmoji("[哀伤]", "😞"),
        NeteaseEmoji("[呲牙]", "😬"),
        NeteaseEmoji("[吐舌]", "😛"),
        NeteaseEmoji("[撇嘴]", "😒"),
        NeteaseEmoji("[怒]", "😠"),
        NeteaseEmoji("[奸笑]", "😏"),
        NeteaseEmoji("[汗]", "😅"),
        NeteaseEmoji("[痛苦]", "😣"),
        NeteaseEmoji("[惶恐]", "😨"),
        NeteaseEmoji("[生病]", "🤒"),
        NeteaseEmoji("[口罩]", "😷"),
        NeteaseEmoji("[大哭]", "😭"),
        NeteaseEmoji("[晕]", "😵"),
        NeteaseEmoji("[发怒]", "😡"),
        NeteaseEmoji("[开心]", "😊"),
        NeteaseEmoji("[鬼脸]", "😜"),
        NeteaseEmoji("[皱眉]", "😟"),
        NeteaseEmoji("[流感]", "🤧"),
        NeteaseEmoji("[爱心]", "❤️"),
        NeteaseEmoji("[心碎]", "💔"),
        NeteaseEmoji("[钟情]", "💕"),
        NeteaseEmoji("[星星]", "⭐"),
        NeteaseEmoji("[生气]", "💢"),
        NeteaseEmoji("[便便]", "💩"),
        NeteaseEmoji("[强]", "👍"),
        NeteaseEmoji("[弱]", "👎"),
        NeteaseEmoji("[拜]", "🙏"),
        NeteaseEmoji("[牵手]", "🤝"),
        NeteaseEmoji("[跳舞]", "💃"),
        NeteaseEmoji("[禁止]", "🚫"),
        NeteaseEmoji("[这边]", "👉"),
        NeteaseEmoji("[爱意]", "💗"),
        NeteaseEmoji("[示爱]", "💓"),
        NeteaseEmoji("[嘴唇]", "💋"),
        NeteaseEmoji("[狗]", "🐶"),
        NeteaseEmoji("[猫]", "🐱"),
        NeteaseEmoji("[猪]", "🐷"),
        NeteaseEmoji("[兔子]", "🐰"),
        NeteaseEmoji("[小鸡]", "🐤"),
        NeteaseEmoji("[公鸡]", "🐓"),
        NeteaseEmoji("[幽灵]", "👻"),
        NeteaseEmoji("[圣诞]", "🎅"),
        NeteaseEmoji("[外星]", "👽"),
        NeteaseEmoji("[钻石]", "💎"),
        NeteaseEmoji("[礼物]", "🎁"),
        NeteaseEmoji("[男孩]", "👦"),
        NeteaseEmoji("[女孩]", "👧"),
        NeteaseEmoji("[蛋糕]", "🎂"),
        NeteaseEmoji("[18]", "🔞"),
        NeteaseEmoji("[圈]", "⭕"),
        NeteaseEmoji("[叉]", "❌"),
    ]
    
    // 手势类
    static let gestureEmojis: [NeteaseEmoji] = [
        NeteaseEmoji("[握手]", "🤝"),
        NeteaseEmoji("[鼓掌]", "👏"),
        NeteaseEmoji("[拳头]", "✊"),
        NeteaseEmoji("[OK]", "👌"),
        NeteaseEmoji("[胜利]", "✌️"),
        NeteaseEmoji("[抱拳]", "🤜"),
        NeteaseEmoji("[勾引]", "👆"),
        NeteaseEmoji("[拳]", "👊"),
        NeteaseEmoji("[差劲]", "👎"),
        NeteaseEmoji("[赞]", "👍"),
        NeteaseEmoji("[爱你]", "🤟"),
        NeteaseEmoji("[NO]", "🙅"),
        NeteaseEmoji("[保佑]", "🙏"),
        NeteaseEmoji("[举手]", "🙋"),
        NeteaseEmoji("[作揖]", "🙇"),
    ]
    
    // 符号类
    static let symbolEmojis: [NeteaseEmoji] = [
        NeteaseEmoji("[太阳]", "☀️"),
        NeteaseEmoji("[月亮]", "🌙"),
        NeteaseEmoji("[星星]", "⭐"),
        NeteaseEmoji("[彩虹]", "🌈"),
        NeteaseEmoji("[雪花]", "❄️"),
        NeteaseEmoji("[闪电]", "⚡"),
        NeteaseEmoji("[火]", "🔥"),
        NeteaseEmoji("[音乐]", "🎵"),
        NeteaseEmoji("[麦克风]", "🎤"),
        NeteaseEmoji("[耳机]", "🎧"),
        NeteaseEmoji("[咖啡]", "☕"),
        NeteaseEmoji("[啤酒]", "🍺"),
        NeteaseEmoji("[干杯]", "🍻"),
        NeteaseEmoji("[玫瑰]", "🌹"),
        NeteaseEmoji("[凋谢]", "🥀"),
        NeteaseEmoji("[菜刀]", "🔪"),
        NeteaseEmoji("[炸弹]", "💣"),
        NeteaseEmoji("[药丸]", "💊"),
        NeteaseEmoji("[足球]", "⚽"),
        NeteaseEmoji("[篮球]", "🏀"),
    ]
}

// MARK: - 表情选择器视图

struct NeteaseEmojiPicker: View {
    let onSelect: (String) -> Void
    
    @State private var selectedCategory: NeteaseEmojiCategory = .face
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    
    var body: some View {
        VStack(spacing: 0) {
            // 分隔线
            Rectangle()
                .fill(Color.asideSeparator)
                .frame(height: 0.5)
            
            // 分类标签
            categoryTabs
            
            // 表情网格
            emojiGrid
        }
        .frame(height: 200)
        .background(.clear).glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
    
    // MARK: - 分类标签
    
    private var categoryTabs: some View {
        HStack(spacing: 0) {
            ForEach(NeteaseEmojiCategory.allCases, id: \.rawValue) { category in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedCategory = category
                    }
                } label: {
                    Text(category.rawValue)
                        .font(.rounded(size: 13, weight: selectedCategory == category ? .semibold : .medium))
                        .foregroundColor(selectedCategory == category ? .asideTextPrimary : .asideTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedCategory == category ?
                            Color.asideTextPrimary.opacity(0.06) : Color.clear
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.asideTextPrimary.opacity(0.02))
    }
    
    // MARK: - 表情网格
    
    private var emojiGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(selectedCategory.emojis) { emoji in
                    Button {
                        onSelect(emoji.code)
                    } label: {
                        Text(emoji.emoji)
                            .font(.system(size: 26))
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.asideTextPrimary.opacity(0.04))
                            )
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - 预览

#Preview {
    VStack {
        Spacer()
        NeteaseEmojiPicker { emoji in
            AppLogger.debug("选择了: \(emoji)")
        }
    }
    .background(Color.asideBackground)
}
