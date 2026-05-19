import Foundation

public struct IconExportIcons {}

#if canImport(UIKit)
import UIKit

public extension UIImage {
    convenience init?(iconExportId: String) {
        self.init(named: iconExportId, in: Bundle.module, compatibleWith: nil)
    }
}
#elseif canImport(AppKit)
import AppKit

public extension NSImage {
    static func iconExport(id: String) -> NSImage? {
        Bundle.module.image(forResource: id)
    }
}
#endif
