import Foundation

public struct Solar {
    public enum Style: String, CaseIterable, Identifiable, Sendable {
        case line
        case filled
        case broken
        case duoline
        case duotone
        case mono

        public var id: String { rawValue }
        public var displayName: String {
            switch self {
            case .line:     return "Line"
            case .filled:   return "Filled"
            case .broken:   return "Broken"
            case .duoline:  return "Duoline"
            case .duotone:  return "Duotone"
            case .mono:     return "Mono"
            }
        }
    }
}

#if canImport(UIKit)
import UIKit
public extension UIImage {
    convenience init?(solarId: String) {
        self.init(named: solarId, in: Bundle.module, compatibleWith: nil)
    }
}
#endif
