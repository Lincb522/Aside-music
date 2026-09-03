import Foundation
import UIKit

public struct MonoGlyphIcons {}

public extension UIImage {
    convenience init?(monoGlyphIconId: String) {
        let currentStyle = UITraitCollection.current.userInterfaceStyle
        self.init(
            monoGlyphIconId: monoGlyphIconId,
            userInterfaceStyle: currentStyle == .dark ? .dark : .light
        )
    }

    convenience init?(monoGlyphIconId: String, userInterfaceStyle: UIUserInterfaceStyle) {
        let traits = UITraitCollection(userInterfaceStyle: userInterfaceStyle)
        guard let resolvedImage = UIImage(
            named: monoGlyphIconId,
            in: Bundle.module,
            compatibleWith: traits
        ) else {
            return nil
        }

        // Copying the selected raster detaches it from UIImageAsset without
        // synchronously running ColorSync during SwiftUI scene updates.
        guard let cgImage = resolvedImage.cgImage else {
            return nil
        }

        self.init(
            cgImage: cgImage,
            scale: resolvedImage.scale,
            orientation: resolvedImage.imageOrientation
        )
    }
}
