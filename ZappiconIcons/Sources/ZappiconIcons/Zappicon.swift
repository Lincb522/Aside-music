import Foundation
import UIKit

public typealias PlatformImage = UIImage

public struct Zappicon {
    /// Zappicon 图标风格
    public enum Style: String, CaseIterable, Identifiable, Sendable {
        case light
        case regular
        case filled
        case duotone
        case duotoneline

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .light:        return "Light"
            case .regular:      return "Regular"
            case .filled:       return "Filled"
            case .duotone:      return "Duotone"
            case .duotoneline:  return "Duotone Line"
            }
        }
    }

    /// 根据风格前缀和图标名加载图标
    public static func icon(named name: String, style: Style) -> PlatformImage? {
        let assetName = "\(style.rawValue)-\(name)"
        return PlatformImage(named: assetName, in: Bundle.module, compatibleWith: nil)
    }
}

public extension UIImage {
    convenience init?(zappiconId: String) {
        self.init(named: zappiconId, in: Bundle.module, compatibleWith: nil)
    }
}
