// PlayerStateTests.swift
// FFmpegSwiftSDKTests
//
// Unit tests for StreamPlayer state machine: verifies state transitions,
// delegate callbacks, and property behavior without actual media playback.

import XCTest
@testable import FFmpegSwiftSDK

// MARK: - Test Delegate

/// A test delegate that records all state changes and errors for verification.
final class TestStreamPlayerDelegate: StreamPlayerDelegate {
    var stateChanges: [PlaybackState] = []
    var errors: [FFmpegError] = []
    var durations: [TimeInterval] = []

    func player(_ player: StreamPlayer, didChangeState state: PlaybackState) {
        stateChanges.append(state)
    }

    func player(_ player: StreamPlayer, didEncounterError error: FFmpegError) {
        errors.append(error)
    }

    func player(_ player: StreamPlayer, didUpdateDuration duration: TimeInterval) {
        durations.append(duration)
    }

    func playerDidTransitionToNextTrack(_ player: StreamPlayer) {}
}

// MARK: - PlaybackState Equatable Tests

final class PlaybackStateTests: XCTestCase {

    func testIdleEquality() {
        XCTAssertEqual(PlaybackState.idle, PlaybackState.idle)
    }

    func testConnectingEquality() {
        XCTAssertEqual(PlaybackState.connecting, PlaybackState.connecting)
    }

    func testPlayingEquality() {
        XCTAssertEqual(PlaybackState.playing, PlaybackState.playing)
    }

    func testPausedEquality() {
        XCTAssertEqual(PlaybackState.paused, PlaybackState.paused)
    }

    func testStoppedEquality() {
        XCTAssertEqual(PlaybackState.stopped, PlaybackState.stopped)
    }

    func testErrorEquality() {
        let error = FFmpegError.connectionTimeout
        XCTAssertEqual(PlaybackState.error(error), PlaybackState.error(error))
    }

    func testDifferentStatesNotEqual() {
        XCTAssertNotEqual(PlaybackState.idle, PlaybackState.connecting)
        XCTAssertNotEqual(PlaybackState.playing, PlaybackState.paused)
        XCTAssertNotEqual(PlaybackState.stopped, PlaybackState.idle)
    }

    func testDifferentErrorsNotEqual() {
        XCTAssertNotEqual(
            PlaybackState.error(.connectionTimeout),
            PlaybackState.error(.networkDisconnected)
        )
    }
}

// MARK: - StreamPlayer State Machine Tests

final class PlayerStateTests: XCTestCase {

    var player: StreamPlayer!
    var testDelegate: TestStreamPlayerDelegate!

    override func setUp() {
        super.setUp()
        player = StreamPlayer()
        testDelegate = TestStreamPlayerDelegate()
        player.delegate = testDelegate
    }

    override func tearDown() {
        player.stop()
        player = nil
        testDelegate = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateIsIdle() {
        XCTAssertEqual(player.state, .idle)
    }

    func testInitialCurrentTimeIsZero() {
        XCTAssertEqual(player.currentTime, 0)
    }

    func testInitialStreamInfoIsNil() {
        XCTAssertNil(player.streamInfo)
    }

    // MARK: - play() State Transition

    func testPlayTransitionsToConnecting() {
        // play() with an invalid URL will transition to connecting, then error
        player.play(url: "invalid://url")

        // Give the background queue time to process
        let expectation = XCTestExpectation(description: "State changes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)

        // First state change should be connecting
        XCTAssertFalse(testDelegate.stateChanges.isEmpty, "Should have state changes")
        if let first = testDelegate.stateChanges.first {
            XCTAssertEqual(first, .connecting, "First state should be connecting")
        }
    }

    func testPlayWithInvalidURLTransitionsToError() {
        player.play(url: "invalid://nonexistent")

        let expectation = XCTestExpectation(description: "Error state reached")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 15.0)

        // Should have transitioned through connecting → error
        let hasError = testDelegate.stateChanges.contains { state in
            if case .error = state { return true }
            return false
        }
        XCTAssertTrue(hasError, "Should reach error state with invalid URL")
    }

    // MARK: - stop() State Transition

    func testStopFromIdleTransitionsToStopped() {
        player.stop()
        XCTAssertEqual(player.state, .stopped)
        XCTAssertEqual(player.lastStopReason, .explicit)
        XCTAssertEqual(testDelegate.stateChanges.last, .stopped)
    }

    func testStopNotifiesDelegate() {
        player.stop()
        XCTAssertTrue(testDelegate.stateChanges.contains(.stopped))
    }

    // MARK: - pause() / resume() Guards

    func testPauseFromIdleDoesNothing() {
        player.pause()
        XCTAssertEqual(player.state, .idle)
        XCTAssertTrue(testDelegate.stateChanges.isEmpty, "No state change expected")
    }

    func testResumeFromIdleDoesNothing() {
        player.resume()
        XCTAssertEqual(player.state, .idle)
        XCTAssertTrue(testDelegate.stateChanges.isEmpty, "No state change expected")
    }

    func testPauseFromStoppedDoesNothing() {
        player.stop()
        let countAfterStop = testDelegate.stateChanges.count
        player.pause()
        XCTAssertEqual(testDelegate.stateChanges.count, countAfterStop,
                       "No additional state change expected")
    }

    func testResumeFromStoppedDoesNothing() {
        player.stop()
        let countAfterStop = testDelegate.stateChanges.count
        player.resume()
        XCTAssertEqual(testDelegate.stateChanges.count, countAfterStop,
                       "No additional state change expected")
    }

    // MARK: - Multiple play/stop Cycles

    func testMultiplePlayStopCycles() {
        // Each play/stop cycle should work correctly
        for _ in 0..<3 {
            player.play(url: "invalid://test")

            let expectation = XCTestExpectation(description: "Cycle")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 5.0)

            player.stop()
            XCTAssertEqual(player.state, .stopped)
        }
    }

    func testStopResetsCurrentTime() {
        player.stop()
        XCTAssertEqual(player.currentTime, 0)
    }

    // MARK: - Delegate Assignment

    func testDelegateIsWeakReference() {
        var delegate: TestStreamPlayerDelegate? = TestStreamPlayerDelegate()
        player.delegate = delegate
        XCTAssertNotNil(player.delegate)

        delegate = nil
        XCTAssertNil(player.delegate)
    }

    // MARK: - EQ Filter Access

    func testEQFilterIsAccessible() {
        // The eqFilter should be accessible for AudioEqualizer wrapping
        let filter = player.eqFilter
        XCTAssertNotNil(filter)

        // Should be able to set gains
        let clamped = filter.setGain(6.0, for: .hz1k)
        XCTAssertEqual(clamped, 6.0)
    }

    // MARK: - State Change Delegate Notifications

    func testDelegateNotifiedOnStop() {
        player.stop()
        XCTAssertEqual(testDelegate.stateChanges, [.stopped])
    }

    func testDelegateNotNotifiedWhenStateUnchanged() {
        // Stopping twice should only notify once for the actual change
        player.stop()
        let count = testDelegate.stateChanges.count
        player.stop()
        // Second stop: state is already .stopped, so didSet won't fire again
        // (oldValue == newValue, no notification)
        XCTAssertEqual(testDelegate.stateChanges.count, count,
                       "Should not notify when state doesn't change")
    }

    // MARK: - play() After stop()

    func testPlayAfterStopTransitionsToConnecting() {
        player.stop()
        XCTAssertEqual(player.state, .stopped)

        testDelegate.stateChanges.removeAll()
        player.play(url: "invalid://test")

        let expectation = XCTestExpectation(description: "Connecting state")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)

        // Should have connecting in the state changes
        XCTAssertTrue(testDelegate.stateChanges.contains(.connecting),
                      "Should transition to connecting after stop + play")
    }
}
