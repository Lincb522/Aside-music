import Foundation
import UIKit

public struct BlobIcons {}

public extension UIImage {
    convenience init?(blobIconId: String) {
        self.init(named: blobIconId, in: Bundle.module, compatibleWith: nil)
    }
}
