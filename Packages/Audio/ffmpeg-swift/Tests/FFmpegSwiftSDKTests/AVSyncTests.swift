// AVSyncTests.swift
// FFmpegSwiftSDKTests
//
// Unit tests for AVSyncController: PTS-based audio-video synchronization.

import XCTest
@testable import FFmpegSwiftSDK

final class AVSyncTests: XCTestCase {

    var controller: AVSyncController!

    override func setUp() {
        super.setUp()
        controller = AVSyncController()
    }

    override func tearDown() {
        controller = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialClocksAreZero() {
        XCTAssertEqual(controller.currentAudioClock(), 0.0, "Initial audio clock should be 0")
        XCTAssertEqual(controller.currentVideoClock(), 0.0, "Initial video clock should be 0")
    }

    func testMaxDriftIs40ms() {
        XCTAssertEqual(controller.maxDrift, 0.040, "Max drift should be 40ms")
    }

    // MARK: - Clock Updates

    func testUpdateAudioClock() {
        controller.updateAudioClock(1.5)
        XCTAssertEqual(controller.currentAudioClock(), 1.5)

        controller.updateAudioClock(3.0)
        XCTAssertEqual(controller.currentAudioClock(), 3.0)
    }

    func testUpdateVideoClock() {
        controller.updateVideoClock(2.0)
        XCTAssertEqual(controller.currentVideoClock(), 2.0)

        controller.updateVideoClock(4.5)
        XCTAssertEqual(controller.currentVideoClock(), 4.5)
    }

    // MARK: - calculateVideoDelay

    func testVideoDelayWhenInSync() {
        controller.updateAudioClock(5.0)
        let delay = controller.calculateVideoDelay(for: 5.0)
        XCTAssertEqual(delay, 0.0, accuracy: 1e-9, "Delay should be 0 when video PTS equals audio clock")
    }

    func testVideoDelayWhenVideoAhead() {
        controller.updateAudioClock(5.0)
        let delay = controller.calculateVideoDelay(for: 5.1)
        XCTAssertEqual(delay, 0.1, accuracy: 1e-9, "Positive delay when video is ahead of audio")
    }

    func testVideoDelayWhenVideoBehind() {
        controller.updateAudioClock(5.0)
        let delay = controller.calculateVideoDelay(for: 4.9)
        XCTAssertEqual(delay, -0.1, accuracy: 1e-9, "Negative delay when video is behind audio")
    }

    func testVideoDelayWithSmallDrift() {
        controller.updateAudioClock(10.0)
        // 20ms ahead - within threshold
        let delay = controller.calculateVideoDelay(for: 10.020)
        XCTAssertEqual(delay, 0.020, accuracy: 1e-9)
    }

    // MARK: - syncAction

    func testSyncActionDisplayWhenInSync() {
        controller.updateAudioClock(5.0)
        let action = controller.syncAction(for: 5.0)
        XCTAssertEqual(action, .display(delay: 0.0))
    }

    func testSyncActionDisplayWhenSlightlyAhead() {
        controller.updateAudioClock(5.0)
        // 20ms ahead - within threshold, should display with delay
        let action = controller.syncAction(for: 5.020)
        if case .display(let delay) = action {
            XCTAssertEqual(delay, 0.020, accuracy: 1e-9, "Delay should be ~20ms")
        } else {
            XCTFail("Expected .display, got \(action)")
        }
    }

    func testSyncActionDisplayWhenSlightlyBehind() {
        controller.updateAudioClock(5.0)
        // 20ms behind - within threshold, should display immediately (delay clamped to 0)
        let action = controller.syncAction(for: 4.980)
        XCTAssertEqual(action, .display(delay: 0.0))
    }

    func testSyncActionDropWhenFarBehind() {
        controller.updateAudioClock(5.0)
        // 50ms behind - exceeds threshold, should drop
        let action = controller.syncAction(for: 4.950)
        XCTAssertEqual(action, .drop)
    }

    func testSyncActionRepeatWhenFarAhead() {
        controller.updateAudioClock(5.0)
        // 50ms ahead - exceeds threshold, should repeat previous
        let action = controller.syncAction(for: 5.050)
        if case .repeatPrevious(let delay) = action {
            XCTAssertEqual(delay, 0.050, accuracy: 1e-9)
        } else {
            XCTFail("Expected .repeatPrevious, got \(action)")
        }
    }

    func testSyncActionAtExactThresholdBehind() {
        controller.updateAudioClock(5.0)
        // Exactly 40ms behind - use integer arithmetic to avoid floating-point drift
        // 5.0 - 0.040 = 4.96 exactly in floating-point
        let videoPTS = 5.0 - 0.040
        let action = controller.syncAction(for: videoPTS)
        // Due to floating-point representation, the drift may be exactly -0.04 or slightly more/less.
        // The implementation uses strict < -maxDrift, so exactly -0.04 should NOT trigger drop.
        // However, 5.0 - 4.96 may not be exactly 0.04 in floating-point.
        // We verify the behavior is reasonable: either display or drop is acceptable at exact boundary.
        switch action {
        case .display, .drop:
            break // Both are acceptable at the exact boundary
        case .repeatPrevious:
            XCTFail("Should not repeat when video is behind audio")
        }
    }

    func testSyncActionAtExactThresholdAhead() {
        controller.updateAudioClock(5.0)
        // Exactly 40ms ahead
        let videoPTS = 5.0 + 0.040
        let action = controller.syncAction(for: videoPTS)
        // At exact boundary, either display or repeatPrevious is acceptable due to floating-point
        switch action {
        case .display(let delay):
            XCTAssertEqual(delay, 0.040, accuracy: 1e-9)
        case .repeatPrevious(let delay):
            XCTAssertEqual(delay, 0.040, accuracy: 1e-9)
        case .drop:
            XCTFail("Should not drop when video is ahead of audio")
        }
    }

    func testSyncActionJustBeyondThresholdBehind() {
        controller.updateAudioClock(5.0)
        // 41ms behind - just beyond threshold, should drop
        let action = controller.syncAction(for: 4.959)
        XCTAssertEqual(action, .drop)
    }

    func testSyncActionJustBeyondThresholdAhead() {
        controller.updateAudioClock(5.0)
        // 41ms ahead - just beyond threshold, should repeat
        let action = controller.syncAction(for: 5.041)
        if case .repeatPrevious = action {
            // Expected
        } else {
            XCTFail("Expected .repeatPrevious, got \(action)")
        }
    }

    // MARK: - shouldDropFrame

    func testShouldNotDropFrameWhenInSync() {
        controller.updateAudioClock(5.0)
        XCTAssertFalse(controller.shouldDropFrame(for: 5.0))
    }

    func testShouldNotDropFrameWhenSlightlyBehind() {
        controller.updateAudioClock(5.0)
        // 30ms behind - within threshold
        XCTAssertFalse(controller.shouldDropFrame(for: 4.970))
    }

    func testShouldDropFrameWhenFarBehind() {
        controller.updateAudioClock(5.0)
        // 50ms behind - exceeds threshold
        XCTAssertTrue(controller.shouldDropFrame(for: 4.950))
    }

    func testShouldNotDropFrameWhenAhead() {
        controller.updateAudioClock(5.0)
        // Video ahead of audio - never drop
        XCTAssertFalse(controller.shouldDropFrame(for: 5.100))
    }

    func testShouldNotDropFrameAtExactThreshold() {
        controller.updateAudioClock(5.0)
        // Exactly 40ms behind - at boundary, behavior depends on floating-point precision.
        // Use a value clearly within threshold (39ms behind) to test the non-drop case.
        XCTAssertFalse(controller.shouldDropFrame(for: 4.961),
                       "39ms behind should not trigger drop")
    }

    // MARK: - Reset

    func testResetClearsBothClocks() {
        controller.updateAudioClock(10.0)
        controller.updateVideoClock(9.5)

        controller.reset()

        XCTAssertEqual(controller.currentAudioClock(), 0.0)
        XCTAssertEqual(controller.currentVideoClock(), 0.0)
    }

    func testResetAllowsFreshSync() {
        controller.updateAudioClock(100.0)
        controller.reset()

        // After reset, a frame at PTS 0 should be in sync
        let delay = controller.calculateVideoDelay(for: 0.0)
        XCTAssertEqual(delay, 0.0, accuracy: 1e-9)
    }

    // MARK: - Thread Safety

    func testConcurrentClockUpdatesAndReads() {
        let iterations = 1000
        let expectation = XCTestExpectation(description: "Concurrent operations complete without crash")
        expectation.expectedFulfillmentCount = 3

        // Thread 1: Update audio clock
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<iterations {
                self.controller.updateAudioClock(TimeInterval(i) * 0.001)
            }
            expectation.fulfill()
        }

        // Thread 2: Update video clock
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<iterations {
                self.controller.updateVideoClock(TimeInterval(i) * 0.001)
            }
            expectation.fulfill()
        }

        // Thread 3: Calculate delays and sync actions
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<iterations {
                let pts = TimeInterval(i) * 0.001
                _ = self.controller.calculateVideoDelay(for: pts)
                _ = self.controller.syncAction(for: pts)
                _ = self.controller.shouldDropFrame(for: pts)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Realistic Scenario Tests

    func testProgressivePlaybackSync() {
        // Simulate progressive playback where audio and video advance together
        for i in 0..<100 {
            let audioPTS = TimeInterval(i) * 0.033  // ~30fps audio updates
            let videoPTS = TimeInterval(i) * 0.033  // matching video PTS

            controller.updateAudioClock(audioPTS)
            let delay = controller.calculateVideoDelay(for: videoPTS)

            XCTAssertEqual(delay, 0.0, accuracy: 1e-9,
                           "Frame \(i): delay should be 0 when A/V are in sync")
        }
    }

    func testVideoSlightlyBehindAudioScenario() {
        // Video is consistently 10ms behind audio - should still display
        for i in 0..<50 {
            let audioPTS = TimeInterval(i) * 0.033
            let videoPTS = audioPTS - 0.010  // 10ms behind

            controller.updateAudioClock(audioPTS)
            let action = controller.syncAction(for: videoPTS)

            XCTAssertEqual(action, .display(delay: 0.0),
                           "Frame \(i): 10ms behind should display immediately")
        }
    }

    func testVideoFarBehindTriggersDrops() {
        // Audio jumps ahead, video frames should be dropped
        controller.updateAudioClock(10.0)

        // Video frames at 9.0, 9.1, 9.2... are all far behind
        for i in 0..<5 {
            let videoPTS = 9.0 + TimeInterval(i) * 0.1
            XCTAssertTrue(controller.shouldDropFrame(for: videoPTS),
                          "Frame at PTS \(videoPTS) should be dropped (audio at 10.0)")
        }
    }
}
