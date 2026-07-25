import Foundation
import SwiftUI
import UIKit

// MARK: - 颜色辅助

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
    }

    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
