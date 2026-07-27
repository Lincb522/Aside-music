import Foundation

/// 一言（Hitokoto）接口不可用时的兜底标语。
enum HitokotoFallbackSlogan {
    static var text: String {
        String(localized: "hitokoto_fallback_slogan")
    }
}
