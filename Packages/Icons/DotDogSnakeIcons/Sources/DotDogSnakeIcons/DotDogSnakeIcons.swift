import Foundation
import UIKit

public struct DotDogSnakeIcons {}

public extension UIImage {
    convenience init?(dotDogSnakeIconId: String) {
        self.init(named: dotDogSnakeIconId, in: Bundle.module, compatibleWith: nil)
    }

    convenience init?(dotDogSnakeIconId: String, userInterfaceStyle: UIUserInterfaceStyle) {
        self.init(
            named: dotDogSnakeIconId,
            in: Bundle.module,
            compatibleWith: UITraitCollection(userInterfaceStyle: userInterfaceStyle)
        )
    }
}
