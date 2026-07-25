import SwiftUI

// MARK: - 全局配色 Token

/// 主题向全局界面提供的语义颜色集合。
struct GlobalColorPalette {
    /// 主背景色
    let background: Color
    /// 卡片/面板表面色
    let surface: Color
    /// 主文字色
    let primary: Color
    /// 副文字色
    let secondary: Color
    /// 强调色
    let accent: Color
    /// 强调色渐变
    let accentGradient: [Color]
    /// 分割线
    let separator: Color
    /// 导航栏染色
    let navBarTint: Color
    /// 图标背景（如设置页图标圆底）
    let iconBackground: Color
    /// 图标前景
    let iconForeground: Color
    /// Card 背景（毛玻璃/实色）
    let cardBackground: Color
    /// 悬浮栏填充
    let floatingBarFill: Color
    /// 破坏性操作（红色系）
    let destructive: Color

    /// Monologue 默认配色（当前 App 行为不变）
    static var `default`: GlobalColorPalette {
        GlobalColorPalette(
            background: .monologueBackground,
            surface: Color(light: .white, dark: Color(hex: "1C1C1E")),
            primary: .monologueTextPrimary,
            secondary: .monologueTextSecondary,
            accent: .monologueAccent,
            accentGradient: [.monologueTextPrimary, .monologueTextPrimary.opacity(0.7)],
            separator: .monologueSeparator,
            navBarTint: .monologueAccent,
            iconBackground: .monologueIconBackground,
            iconForeground: .monologueIconForeground,
            cardBackground: Color(light: Color.white.opacity(0.7), dark: Color(hex: "3A3A3C").opacity(0.5)),
            floatingBarFill: .monologueFloatingBarFill,
            destructive: .monologueAccentRed
        )
    }
}

// MARK: - 全局排版 Token

/// 主题向全局界面提供的字体构造器与字距规则。
@MainActor
struct GlobalTypography {
    /// 大标题字体构造器
    let titleFont: (CGFloat) -> Font
    /// 正文字体构造器
    let bodyFont: (CGFloat) -> Font
    /// 标注字体构造器
    let captionFont: (CGFloat) -> Font
    /// 等宽字体构造器
    let monoFont: (CGFloat) -> Font
    /// 字体设计风格
    let fontDesign: Font.Design
    /// 字间距微调
    let letterSpacing: CGFloat

    /// Monologue 默认排版
    static let `default` = GlobalTypography(
        titleFont: { size in .system(size: size, weight: .bold, design: .rounded) },
        bodyFont: { size in .system(size: size, weight: .regular, design: .rounded) },
        captionFont: { size in .system(size: size, weight: .medium, design: .rounded) },
        monoFont: { size in .system(size: size, weight: .medium, design: .monospaced) },
        fontDesign: .rounded,
        letterSpacing: 0
    )
}

// MARK: - 全局形状语言 Token

enum GlobalShadowStyle {
    case none
    case soft        // 默认柔和阴影
    case hard        // 硬边阴影（漫画风等）
    case neon        // 霓虹发光（赛博朋克等）
    case inset       // 内凹（新拟物等）
}

/// 主题的圆角、边框与阴影规则。
struct GlobalShapeLanguage {
    /// 卡片圆角
    let cardRadius: CGFloat
    /// 按钮圆角
    let buttonRadius: CGFloat
    /// Sheet 圆角
    let sheetRadius: CGFloat
    /// 阴影风格
    let shadowStyle: GlobalShadowStyle
    /// 边框宽度（0 = 无边框）
    let borderWidth: CGFloat

    /// Monologue 默认形状
    static let `default` = GlobalShapeLanguage(
        cardRadius: 16,
        buttonRadius: 12,
        sheetRadius: 24,
        shadowStyle: .soft,
        borderWidth: 0
    )
}

// MARK: - 全局图标风格

enum GlobalIconVariant {
    case system         // SF Symbols 默认
    case outlined       // 线框
    case filled         // 填充
    case pixelated      // 像素化
}

/// 主题建议的图标变体、粗细与徽标形状。
struct GlobalIconStyle {
    let variant: GlobalIconVariant
    /// 图标默认粗细
    let weight: Font.Weight
    /// 图标 badge 圆角
    let badgeRadius: CGFloat

    static let `default` = GlobalIconStyle(
        variant: .system,
        weight: .medium,
        badgeRadius: 8
    )
}

// MARK: - 全局动画风格

/// 主题提供的页面、卡片、按钮与列表动效参数。
@MainActor
struct GlobalAnimationStyle {
    /// 页面转场动画
    let pageTransition: AnyTransition
    /// 卡片出现动画
    let cardAppear: Animation
    /// 按钮交互动画
    let buttonPress: Animation
    /// 列表项交错延迟（秒）
    let staggerDelay: Double

    static let `default` = GlobalAnimationStyle(
        pageTransition: .opacity.combined(with: .move(edge: .trailing)),
        cardAppear: .spring(response: 0.5, dampingFraction: 0.82),
        buttonPress: .spring(response: 0.3, dampingFraction: 0.7),
        staggerDelay: 0.06
    )
}
