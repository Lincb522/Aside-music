import UIKit

public struct Hicon {}

public extension UIImage {
    convenience init?(hiconId: String) {
        self.init(named: hiconId, in: Bundle.module, compatibleWith: nil)
    }
}
