import Foundation

public struct BlobIcons {}

#if canImport(UIKit)
import UIKit

public extension UIImage {
    convenience init?(blobIconId: String) {
        self.init(named: blobIconId, in: Bundle.module, compatibleWith: nil)
    }
}
#elseif canImport(AppKit)
import AppKit

public extension NSImage {
    static func blobIcon(id: String) -> NSImage? {
        Bundle.module.image(forResource: id)
    }
}
#endif
