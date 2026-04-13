import SwiftUI

// MARK: - Theme Colors
// Monologue 设计系统颜色定义 - 支持深色/浅色自适应

extension Color {
    static var monologueBackground: Color {
        Color(light: Color(hex: "F5F5F7"), dark: Color(hex: "0A0A0A"))
    }
        
    static let monologueTextPrimary = Color.primary
    static let monologueTextSecondary = Color.secondary
    
    static let monologueBlue = Color(hex: "007AFF")
    static let monologueBlueLight = Color(hex: "007AFF").opacity(0.1)
    static let monologueOrange = Color(hex: "FF9500")
    static let monologueOrangeLight = Color(hex: "FF9500").opacity(0.1)
    
    static var monologueGradientTop: Color {
        Color(light: Color(hex: "F5F5F7"), dark: Color(hex: "1C1C1E"))
    }
    static var monologueGradientBottom: Color {
        Color(light: Color(hex: "E8E8ED"), dark: Color(hex: "000000"))
    }
    
    /// 主强调色（与 monologueIconBackground 一致，用于 EQ 等交互组件）
    static var monologueAccent: Color {
        Color(light: .black, dark: .white)
    }
    
    /// 设置页系统 Toggle 激活色
    static var monologueToggleTint: Color {
        Color(light: Color.black.opacity(0.88), dark: Color.white.opacity(0.9))
    }
    
    static let monologueAccentYellow = Color(hex: "FFCC00")
    static let monologueAccentBlue = Color(hex: "007AFF")
    static let monologueAccentGreen = Color(hex: "34C759")
    static let monologueAccentRed = Color(hex: "FF3B30")
    
    static var monologueMilk: Color {
        Color(light: Color.white.opacity(0.8), dark: Color.white.opacity(0.1))
    }

    /// Liquid Glass 专用染色 — 兼顾玻璃效果与无 glassEffect 时的可见兜底
    static var monologueGlassTint: Color {
        Color(light: Color.white.opacity(0.45), dark: Color.white.opacity(0.12))
    }
    
    /// 悬浮栏专用填充色 — 更通透的玻璃质感
    static var monologueFloatingBarFill: Color {
        Color(light: Color.white.opacity(0.18), dark: Color(hex: "1C1C1E").opacity(0.45))
    }
    
    @available(*, deprecated, message: "使用 .glassEffect() 替代")
    static var monologueCardBackground: Color {
        Color(light: Color.white.opacity(0.7), dark: Color(hex: "3A3A3C").opacity(0.5))
    }
    
    /// 毛玻璃卡片叠加色（浅色白色半透明，深色浅灰半透明）
    @available(*, deprecated, message: "使用 .glassEffect() 替代")
    static var monologueGlassOverlay: Color {
        Color(light: Color.white.opacity(0.55), dark: Color(hex: "3A3A3C").opacity(0.4))
    }
    
    /// Sheet 面板背景叠加色
    @available(*, deprecated, message: "使用 .glassEffect() 替代")
    static var monologueSheetOverlay: Color {
        Color(light: Color.white.opacity(0.45), dark: Color(hex: "2C2C2E").opacity(0.45))
    }

    /// 新通用 Sheet 面板主表面（顶部）
    static var monologueSheetSurfaceTop: Color {
        Color(light: Color(hex: "FFFFFF").opacity(0.98), dark: Color(hex: "242734").opacity(0.98))
    }

    /// 新通用 Sheet 面板主表面（底部）
    static var monologueSheetSurfaceBottom: Color {
        Color(light: Color(hex: "F3F6FB").opacity(0.98), dark: Color(hex: "161922").opacity(0.98))
    }

    /// 新通用 Sheet 面板顶部高光
    static var monologueSheetHighlight: Color {
        Color(light: Color.white.opacity(0.82), dark: Color.white.opacity(0.08))
    }

    /// 新通用 Sheet 面板内侧柔光
    static var monologueSheetInnerGlow: Color {
        Color(light: Color(hex: "DCE9FF").opacity(0.42), dark: Color(hex: "4A5B86").opacity(0.18))
    }

    /// 新通用 Sheet 面板描边
    static var monologueSheetStroke: Color {
        Color(light: Color.white.opacity(0.72), dark: Color.white.opacity(0.08))
    }

    /// 新通用 Sheet 阴影色
    static var monologueSheetShadow: Color {
        Color(light: Color.black.opacity(0.12), dark: Color.black.opacity(0.34))
    }

    /// 新通用 Sheet 顶部拖拽把手
    static var monologueSheetHandle: Color {
        Color(light: Color.black.opacity(0.14), dark: Color.white.opacity(0.16))
    }
    
    static var monologueSeparator: Color {
        Color(light: Color.black.opacity(0.1), dark: Color.white.opacity(0.1))
    }
    
    static var monologueIconBackground: Color {
        Color(light: .black, dark: .white)
    }
    
    static var monologueIconForeground: Color {
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

// MARK: - Color → Hex

extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - 毛玻璃卡片背景

/// 毛玻璃卡片背景 — iOS 26: glassEffect，低版本: ultraThinMaterial + 颜色叠加
struct MonologueGlassCardBackground: View {
    var cornerRadius: CGFloat = 20

    var body: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.monologueGlassTint)
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.monologueMilk)
                )
        }
    }
}

// MARK: - View 扩展：毛玻璃卡片修饰器

extension View {
    /// 给视图添加毛玻璃卡片背景（替代纯色 monologueCardBackground）
    func monologueGlassCard(cornerRadius: CGFloat = 20) -> some View {
        self.background(
            MonologueGlassCardBackground(cornerRadius: cornerRadius)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }
}
