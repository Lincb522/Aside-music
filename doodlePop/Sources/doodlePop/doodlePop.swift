import Foundation
import UIKit

public struct DoodlePopIcons {}

public extension UIImage {
    convenience init?(doodlePopIconId: String) {
        self.init(named: doodlePopIconId, in: Bundle.module, compatibleWith: nil)
    }
}
