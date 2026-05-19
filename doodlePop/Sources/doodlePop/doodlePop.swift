import Foundation

public struct DoodlePopIcons {}

#if canImport(UIKit)
import UIKit

public extension UIImage {
    convenience init?(doodlePopIconId: String) {
        self.init(named: doodlePopIconId, in: Bundle.module, compatibleWith: nil)
    }
}
#elseif canImport(AppKit)
import AppKit

public extension NSImage {
    static func doodlePopIcon(id: String) -> NSImage? {
        Bundle.module.image(forResource: id)
    }
}
#endif
