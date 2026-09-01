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
