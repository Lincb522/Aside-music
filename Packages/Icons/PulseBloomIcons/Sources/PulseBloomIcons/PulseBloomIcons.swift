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

        // Detach the chosen luminosity variant from UIImageAsset. SwiftUI's
        // Image and UIKit's TabBar may otherwise resolve the asset again using
        // the host appearance after this initializer returns.
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = max(resolvedImage.scale, 3)
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: resolvedImage.size, format: format)
        var fixedImage: UIImage?
        traits.performAsCurrent {
            fixedImage = renderer.image { _ in
                resolvedImage.draw(in: CGRect(origin: .zero, size: resolvedImage.size))
            }
        }
        guard let fixedImage, let cgImage = fixedImage.cgImage else {
            return nil
        }

        self.init(
            cgImage: cgImage,
            scale: fixedImage.scale,
            orientation: fixedImage.imageOrientation
        )
    }
}
