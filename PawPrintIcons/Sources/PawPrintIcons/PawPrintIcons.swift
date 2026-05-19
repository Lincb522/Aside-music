import Foundation

public struct PawPrintIcons {}

#if canImport(UIKit)
import UIKit

public extension UIImage {
    convenience init?(pawPrintIconId: String) {
        self.init(named: pawPrintIconId, in: Bundle.module, compatibleWith: nil)
    }
}
#elseif canImport(AppKit)
import AppKit

public extension NSImage {
    static func pawPrintIcon(id: String) -> NSImage? {
        Bundle.module.image(forResource: id)
    }
}
#endif
