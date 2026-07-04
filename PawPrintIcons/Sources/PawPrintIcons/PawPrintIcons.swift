import Foundation
import UIKit

public struct PawPrintIcons {}

public extension UIImage {
    convenience init?(pawPrintIconId: String) {
        self.init(named: pawPrintIconId, in: Bundle.module, compatibleWith: nil)
    }
}
