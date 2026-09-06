import Combine
import XCTest
@testable import Mono

@MainActor
final class PagePerformanceStateTests: XCTestCase {
    func testReplacingCatalogRequestCancelsPreviousSubscription() {
        let scope = LibraryRequestScope()
        var didCancel = false
        let first = scope.begin()
        scope.cancellable = AnyCancellable { didCancel = true }

        let second = scope.begin()
        XCTAssertTrue(didCancel)
        XCTAssertFalse(scope.isCurrent(first))
        XCTAssertTrue(scope.isCurrent(second))
        XCTAssertTrue(scope.isRunning)

        scope.finish(first)
        XCTAssertTrue(scope.isRunning)
        scope.finish(second)
        XCTAssertFalse(scope.isRunning)
    }

    func testCancellingCatalogRequestInvalidatesQueuedResults() {
        let scope = LibraryRequestScope()
        let request = scope.begin()
        scope.cancel()

        XCTAssertFalse(scope.isCurrent(request))
        XCTAssertFalse(scope.isRunning)
        XCTAssertNil(scope.cancellable)
        XCTAssertNil(scope.task)
    }
}
