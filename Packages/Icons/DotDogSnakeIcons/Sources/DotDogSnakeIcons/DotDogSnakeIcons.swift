import Foundation
import UIKit

public struct DotDogSnakeIcons {}

public extension UIImage {
    convenience init?(dotDogSnakeIconId: String) {
        self.init(named: dotDogSnakeIconId, in: Bundle.module, compatibleWith: nil)
    }
}
