public struct Hicon {}

#if canImport(UIKit)
import UIKit
public extension UIImage {
    convenience init?(hiconId: String) {
        self.init(named: hiconId, in: Bundle.module, compatibleWith: nil)
    }
}
#endif

#if canImport(AppKit)
import AppKit
public extension NSImage {
    static func hicon(id: String) -> NSImage? {
        Bundle.module.image(forResource: id)
    }
}
#endif
