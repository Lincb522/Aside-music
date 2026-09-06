import UIKit
import XCTest
@testable import Mono

final class ArtworkCacheEncodingTests: XCTestCase {
    @MainActor
    func testBackgroundCacheWritePreservesJPEGQualityAndDimensions() async throws {
        for size in [CGSize(width: 192, height: 192), CGSize(width: 384, height: 216)] {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.systemTeal.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                UIColor.systemOrange.setFill()
                context.fill(CGRect(x: 17, y: 23, width: 53, height: 79))
            }
            let expected = try XCTUnwrap(image.jpegData(compressionQuality: 0.92))
            let key = "artwork-encoding-test-\(UUID().uuidString)"
            defer { CacheManager.shared.removeObject(forKey: key) }

            await ImageLoadCoordinator.shared.cacheImageToDisk(image, forKey: key)

            let cached = try XCTUnwrap(CacheManager.shared.getImageData(forKey: key))
            XCTAssertEqual(cached, expected)
            XCTAssertEqual(try XCTUnwrap(UIImage(data: cached)).size, size)
        }
    }
}
