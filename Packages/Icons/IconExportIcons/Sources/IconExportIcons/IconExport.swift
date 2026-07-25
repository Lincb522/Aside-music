import Foundation
import UIKit

public struct IconExportIcons {}

public extension UIImage {
    convenience init?(iconExportId: String) {
        self.init(named: iconExportId, in: Bundle.module, compatibleWith: nil)
    }
}
