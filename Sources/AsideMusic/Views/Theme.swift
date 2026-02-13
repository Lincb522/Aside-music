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
    
    static var asideCardBackground: Color {
        Color(light: .white, dark: Color(hex: "2C2C2E"))
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
