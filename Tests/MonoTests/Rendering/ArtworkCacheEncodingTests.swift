import UIKit
import XCTest
@testable import Mono

final class ArtworkCacheEncodingTests: XCTestCase {
    @MainActor
    func testConcurrentViewLoadsShareTheSameDecodedImage() async throws {
        let coordinator = ImageLoadCoordinator()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mono-artwork-test-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 384, height: 192), format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 384, height: 192))
        }
        try XCTUnwrap(image.pngData()).write(to: url)

        let images = await withTaskGroup(of: UIImage?.self, returning: [UIImage].self) { group in
            for _ in 0..<16 {
                group.addTask {
                    await coordinator.loadCachedImage(url: url, maxSize: 64)
                }
            }
            var images: [UIImage] = []
            for await image in group {
                if let image { images.append(image) }
            }
            return images
        }
        await coordinator.cancelAll()

        let first = try XCTUnwrap(images.first)
        XCTAssertEqual(images.count, 16)
        XCTAssertTrue(images.allSatisfy { $0 === first })
        XCTAssertEqual(first.size, CGSize(width: 192, height: 96))
    }

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
