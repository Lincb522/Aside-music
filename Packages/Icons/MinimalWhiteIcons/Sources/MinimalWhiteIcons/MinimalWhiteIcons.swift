import Foundation
import UIKit

public struct MinimalWhiteIcons {}

public extension UIImage {
    convenience init?(minimalWhiteIconId: String) {
        self.init(named: minimalWhiteIconId, in: Bundle.module, compatibleWith: nil)
    }
}
