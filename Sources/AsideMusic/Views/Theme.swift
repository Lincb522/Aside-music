import SwiftUI

// MARK: - Theme Colors
// Aside Music 设计系统颜色定义

extension Color {
    // 背景色
    static let asideBackground = Color(hex: "F5F5F7")
    
    // 文字颜色
    static let asideTextPrimary = Color.black
    static let asideTextSecondary = Color.gray
    
    // 主色调
    static let asideBlue = Color(hex: "007AFF")
    static let asideBlueLight = Color(hex: "007AFF").opacity(0.1)
    static let asideOrange = Color(hex: "FF9500")
    static let asideOrangeLight = Color(hex: "FF9500").opacity(0.1)
    
    // 渐变色
    static let asideGradientTop = Color(hex: "F5F5F7")
    static let asideGradientBottom = Color(hex: "E8E8ED")
    
    // 状态颜色
    static let asideAccentYellow = Color(hex: "FFCC00")
    static let asideAccentBlue = Color(hex: "007AFF")
    static let asideAccentGreen = Color(hex: "34C759")
    static let asideAccentRed = Color(hex: "FF3B30")
    
    // 表面颜色
    static let asideMilk = Color.white.opacity(0.8)
}

extension Font {
    static func rounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Map to system rounded to maintain exact behavior
        return Font.system(size: size, weight: weight, design: .rounded)
    }
}

// Keep the hex initializer as a utility
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
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
