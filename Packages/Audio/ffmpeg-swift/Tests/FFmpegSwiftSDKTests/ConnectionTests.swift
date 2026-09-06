// ConnectionTests.swift
// FFmpegSwiftSDKTests
//
// Unit tests for ConnectionManager.
// Validates connection state transitions, timeout behavior, delegate notifications,
// disconnect resource cleanup, and protocol-specific handling.

import XCTest
@testable import FFmpegSwiftSDK
import CFFmpeg

// MARK: - Test Delegate

/// A test spy that records delegate callbacks for verification.
final class MockConnectionManagerDelegate: ConnectionManagerDelegate {
    var stateChanges: [ConnectionState] = []
    var errors: [FFmpegError] = []

    func connectionManager(_ manager: ConnectionManager, didChangeState state: ConnectionState) {
        stateChanges.append(state)
    }

    func connectionManager(_ manager: ConnectionManager, didFailWith error: FFmpegError) {
        errors.append(error)
    }
}

// MARK: - ConnectionManager Tests

final class ConnectionManagerTests: XCTestCase {

    var manager: ConnectionManager!
    var delegate: MockConnectionManagerDelegate!

    override func setUp() {
        super.setUp()
        manager = ConnectionManager()
        delegate = MockConnectionManagerDelegate()
        manager.delegate = delegate
    }

    override func tearDown() {
        manager.disconnect()
        manager = nil
        delegate = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateIsIdle() {
        XCTAssertEqual(manager.state, .idle, "Initial state should be idle")
    }

    func testTimeoutIntervalIsTenSeconds() {
        XCTAssertEqual(manager.timeoutInterval, 10.0, "Timeout interval should be 10 seconds")
    }

    // MARK: - Connect with Invalid URLs

    func testConnectWithEmptyURLFails() async {
        do {
            _ = try await manager.connect(url: "")
            XCTFail("Expected connect to throw for empty URL")
        } catch {
            XCTAssertTrue(error is FFmpegError, "Error should be FFmpegError, got \(type(of: error))")
        }
    }

    func testConnectWithInvalidURLFails() async {
        do {
            _ = try await manager.connect(url: "not-a-valid-url")
            XCTFail("Expected connect to throw for invalid URL")
        } catch {
            XCTAssertTrue(error is FFmpegError, "Error should be FFmpegError")
        }
    }

    func testConnectWithInvalidProtocolFails() async {
        do {
            _ = try await manager.connect(url: "invalid://some-host/stream")
            XCTFail("Expected connect to throw for invalid protocol")
        } catch {
            XCTAssertTrue(error is FFmpegError, "Error should be FFmpegError")
        }
    }

    func testConnectWithNonexistentFileFails() async {
        do {
            _ = try await manager.connect(url: "/nonexistent/path/to/media.mp4")
            XCTFail("Expected connect to throw for nonexistent file")
        } catch {
            XCTAssertTrue(error is FFmpegError, "Error should be FFmpegError")
        }
    }

    // MARK: - State Transitions on Failure

    func testStateTransitionsToConnectingThenFailedOnError() async {
        do {
            _ = try await manager.connect(url: "invalid://url")
            XCTFail("Expected connect to throw")
        } catch {
            // Verify state transitions: idle -> connecting -> failed
            XCTAssertTrue(delegate.stateChanges.count >= 2,
                          "Should have at least 2 state changes, got \(delegate.stateChanges.count)")

            if delegate.stateChanges.count >= 1 {
                XCTAssertEqual(delegate.stateChanges[0], .connecting,
                               "First state change should be .connecting")
            }

            // Final state should be .failed
            if case .failed = manager.state {
                // Expected
            } else {
                XCTFail("Final state should be .failed, got \(manager.state)")
            }
        }
    }

    func testDelegateReceivesErrorOnFailedConnect() async {
        do {
            _ = try await manager.connect(url: "invalid://url")
            XCTFail("Expected connect to throw")
        } catch {
            XCTAssertFalse(delegate.errors.isEmpty,
                           "Delegate should receive at least one error")
        }
    }

    // MARK: - Disconnect

    func testDisconnectFromIdleState() {
        manager.disconnect()
        // Should transition to disconnected (or stay idle if already idle)
        // The implementation transitions to disconnected only if not already idle
        XCTAssertEqual(manager.state, .idle,
                       "Disconnecting from idle should remain idle")
    }

    func testDisconnectAfterFailedConnect() async {
        do {
            _ = try await manager.connect(url: "invalid://url")
        } catch {
            // Expected
        }

        manager.disconnect()
        XCTAssertEqual(manager.state, .disconnected,
                       "State should be disconnected after disconnect()")
    }

    func testDisconnectCanBeCalledMultipleTimes() {
        manager.disconnect()
        manager.disconnect()
        manager.disconnect()
        // Should not crash
    }

    func testDisconnectAfterDisconnectRemainsDisconnected() async {
        // First, get into a non-idle state
        do {
            _ = try await manager.connect(url: "invalid://url")
        } catch {
            // Expected
        }

        manager.disconnect()
        XCTAssertEqual(manager.state, .disconnected)

        manager.disconnect()
        XCTAssertEqual(manager.state, .disconnected,
                       "Multiple disconnects should keep state as disconnected")
    }

    // MARK: - Delegate State Change Tracking

    func testDelegateReceivesConnectingStateOnConnect() async {
        do {
            _ = try await manager.connect(url: "invalid://url")
        } catch {
            // Expected
        }

        XCTAssertTrue(delegate.stateChanges.contains(.connecting),
                       "Delegate should receive .connecting state change")
    }

    func testDelegateReceivesDisconnectedStateOnDisconnect() async {
        // Get into a non-idle state first
        do {
            _ = try await manager.connect(url: "invalid://url")
        } catch {
            // Expected
        }

        delegate.stateChanges.removeAll()
        manager.disconnect()

        XCTAssertTrue(delegate.stateChanges.contains(.disconnected),
                       "Delegate should receive .disconnected state change")
    }

    // MARK: - Protocol Detection (via connect behavior with invalid hosts)

    // Note: Tests with unreachable network IPs (e.g., 192.0.2.1) are excluded
    // because they depend on the 10-second timeout and may cause CI instability.
    // The protocol-specific timeout option logic is validated through the
    // property tests in URLValidationPropertyTests.

    func testConnectWithRTMPInvalidHostFails() async {
        // RTMP URL with invalid hostname - should fail quickly (DNS resolution failure)
        do {
            _ = try await manager.connect(url: "rtmp://this-host-does-not-exist.invalid/live/test")
            XCTFail("Expected connect to throw for invalid RTMP host")
        } catch {
            XCTAssertTrue(error is FFmpegError, "Error should be FFmpegError")
        }
    }

    func testConnectWithRTSPInvalidSchemeFails() async {
        // RTSP URL with completely invalid format
        do {
            _ = try await manager.connect(url: "rtsp://")
            XCTFail("Expected connect to throw for empty RTSP URL")
        } catch {
            XCTAssertTrue(error is FFmpegError, "Error should be FFmpegError")
        }
    }

    func testConnectWithHTTPInvalidHostFails() async {
        // HTTP URL with invalid hostname
        do {
            _ = try await manager.connect(url: "http://this-host-does-not-exist.invalid/stream.m3u8")
            XCTFail("Expected connect to throw for invalid HLS host")
        } catch {
            XCTAssertTrue(error is FFmpegError, "Error should be FFmpegError")
        }
    }

    // MARK: - ConnectionState Equatable

    func testConnectionStateEquatable() {
        XCTAssertEqual(ConnectionState.idle, ConnectionState.idle)
        XCTAssertEqual(ConnectionState.connecting, ConnectionState.connecting)
        XCTAssertEqual(ConnectionState.connected, ConnectionState.connected)
        XCTAssertEqual(ConnectionState.disconnected, ConnectionState.disconnected)
        XCTAssertNotEqual(ConnectionState.idle, ConnectionState.connecting)
        XCTAssertNotEqual(ConnectionState.connected, ConnectionState.disconnected)

        let error1 = FFmpegError.connectionTimeout
        let error2 = FFmpegError.connectionTimeout
        XCTAssertEqual(ConnectionState.failed(error1), ConnectionState.failed(error2))
    }
}
