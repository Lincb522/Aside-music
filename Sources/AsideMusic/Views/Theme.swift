import SwiftUI

// MARK: - Theme Colors
// Aside Music 设计系统颜色定义 - 支持深色/浅色自适应

extension Color {
    static var asideBackground: Color {
        Color(light: Color(hex: "F5F5F7"), dark: Color(hex: "0A0A0A"))
    }
        
    static let asideTextPrimary = Color.primary
    static let asideTextSecondary = Color.secondary
    
    static let asideBlue = Color(hex: "007AFF")
    static let asideBlueLight = Color(hex: "007AFF").opacity(0.1)
    static let asideOrange = Color(hex: "FF9500")
    static let asideOrangeLight = Color(hex: "FF9500").opacity(0.1)
    
    static var asideGradientTop: Color {
        Color(light: Color(hex: "F5F5F7"), dark: Color(hex: "1C1C1E"))
    }
    static var asideGradientBottom: Color {
        Color(light: Color(hex: "E8E8ED"), dark: Color(hex: "000000"))
    }
    
    /// 主强调色（与 asideIconBackground 一致，用于 EQ 等交互组件）
    static var asideAccent: Color {
        Color(light: .black, dark: .white)
    }
    
    static let asideAccentYellow = Color(hex: "FFCC00")
    static let asideAccentBlue = Color(hex: "007AFF")
    static let asideAccentGreen = Color(hex: "34C759")
    static let asideAccentRed = Color(hex: "FF3B30")
    
    static var asideMilk: Color {
        Color(light: Color.white.opacity(0.8), dark: Color.white.opacity(0.1))
    }
    
    @available(*, deprecated, message: "使用 .glassEffect() 替代")
    static var asideCardBackground: Color {
        Color(light: Color.white.opacity(0.7), dark: Color(hex: "3A3A3C").opacity(0.5))
    }
    
    /// 毛玻璃卡片叠加色（浅色白色半透明，深色浅灰半透明）
    @available(*, deprecated, message: "使用 .glassEffect() 替代")
    static var asideGlassOverlay: Color {
        Color(light: Color.white.opacity(0.55), dark: Color(hex: "3A3A3C").opacity(0.4))
    }
    
    /// Sheet 面板背景叠加色
    @available(*, deprecated, message: "使用 .glassEffect() 替代")
    static var asideSheetOverlay: Color {
        Color(light: Color.white.opacity(0.45), dark: Color(hex: "2C2C2E").opacity(0.45))
    }
    
    static var asideSeparator: Color {
        Color(light: Color.black.opacity(0.1), dark: Color.white.opacity(0.1))
    }
    
    static var asideIconBackground: Color {
        Color(light: .black, dark: .white)
    }
    
    static var asideIconForeground: Color {
        Color(light: .white, dark: .black)
    }
}

// MARK: - 自适应颜色构造器

extension Color {
    /// 根据浅色/深色模式返回不同颜色
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

extension Font {
    static func rounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Hex 颜色初始化

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - 毛玻璃卡片背景

/// 毛玻璃卡片背景 — .ultraThinMaterial + 颜色叠加
/// 浅色：白色磨砂半透明；深色：浅灰色磨砂半透明
struct AsideGlassCardBackground: View {
    var cornerRadius: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

// MARK: - View 扩展：毛玻璃卡片修饰器

extension View {
    /// 给视图添加毛玻璃卡片背景（替代纯色 asideCardBackground）
    func asideGlassCard(cornerRadius: CGFloat = 16) -> some View {
        self.background(
            AsideGlassCardBackground(cornerRadius: cornerRadius)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }
}
