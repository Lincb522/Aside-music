import Foundation
import UIKit

public struct MinimalWhiteIcons {}

public extension UIImage {
    convenience init?(minimalWhiteIconId: String) {
        self.init(named: minimalWhiteIconId, in: Bundle.module, compatibleWith: nil)
    }

    convenience init?(minimalWhiteIconId: String, userInterfaceStyle: UIUserInterfaceStyle) {
        self.init(
            named: minimalWhiteIconId,
            in: Bundle.module,
            compatibleWith: UITraitCollection(userInterfaceStyle: userInterfaceStyle)
        )
    }
}
