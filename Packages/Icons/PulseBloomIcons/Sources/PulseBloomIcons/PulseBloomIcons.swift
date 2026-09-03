import Foundation
import UIKit

public struct PulseBloomIcons {}

public extension UIImage {
    convenience init?(pulseBloomIconId: String) {
        let currentStyle = UITraitCollection.current.userInterfaceStyle
        self.init(
            pulseBloomIconId: pulseBloomIconId,
            userInterfaceStyle: currentStyle == .dark ? .dark : .light
        )
    }

    convenience init?(pulseBloomIconId: String, userInterfaceStyle: UIUserInterfaceStyle) {
        let traits = UITraitCollection(userInterfaceStyle: userInterfaceStyle)
        guard let resolvedImage = UIImage(
            named: pulseBloomIconId,
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
