import Foundation
import UIKit

public struct DoodlePopIcons {}

public extension UIImage {
    convenience init?(doodlePopIconId: String) {
        self.init(named: doodlePopIconId, in: Bundle.module, compatibleWith: nil)
    }

    /// 局部深色表面不一定会改变整个窗口的 trait collection，因此允许调用方
    /// 显式解析同一资源里的深色外观，而不是维护第二套图标包。
    convenience init?(doodlePopIconId: String, userInterfaceStyle: UIUserInterfaceStyle) {
        self.init(
            named: doodlePopIconId,
            in: Bundle.module,
            compatibleWith: UITraitCollection(userInterfaceStyle: userInterfaceStyle)
        )
    }
}
