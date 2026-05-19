import Foundation

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
        #if canImport(UIKit)
        return PlatformImage(named: assetName, in: Bundle.module, compatibleWith: nil)
        #elseif canImport(AppKit)
        return Bundle.module.image(forResource: assetName)
        #else
        return nil
        #endif
    }
}

#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage

public extension UIImage {
    convenience init?(zappiconId: String) {
        self.init(named: zappiconId, in: Bundle.module, compatibleWith: nil)
    }
}
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage

public extension NSImage {
    static func zappicon(id: String) -> NSImage? {
        Bundle.module.image(forResource: id)
    }
}
#endif
