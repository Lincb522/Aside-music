import Foundation

public struct DotDogSnakeIcons {}

#if canImport(UIKit)
import UIKit

public extension UIImage {
    convenience init?(dotDogSnakeIconId: String) {
        self.init(named: dotDogSnakeIconId, in: Bundle.module, compatibleWith: nil)
    }
}
#elseif canImport(AppKit)
import AppKit

public extension NSImage {
    static func dotDogSnakeIcon(id: String) -> NSImage? {
        Bundle.module.image(forResource: id)
    }
}
#endif
