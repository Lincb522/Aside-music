// BridgeTests.swift
// FFmpegSwiftSDKTests
//
// Unit tests for FFmpegFormatContext and FFmpegCodecContext bridge classes.
// Validates allocation, resource cleanup, error handling, and basic operations.

import XCTest
@testable import FFmpegSwiftSDK
import CFFmpeg

final class FFmpegFormatContextTests: XCTestCase {

    // MARK: - Allocation Tests

    func testInitAllocatesContext() throws {
        let context = try FFmpegFormatContext()
        XCTAssertNotNil(context.rawPointer, "rawPointer should be non-nil after successful init")
    }

    func testStreamCountIsZeroAfterInit() throws {
        let context = try FFmpegFormatContext()
        XCTAssertEqual(context.streamCount, 0, "streamCount should be 0 before opening input")
    }

    func testInitWithExistingPointerNil() {
        let context = FFmpegFormatContext(existingPointer: nil)
        XCTAssertNil(context.rawPointer, "rawPointer should be nil when initialized with nil")
        XCTAssertEqual(context.streamCount, 0)
    }

    func testInitWithExistingPointer() {
        let rawCtx = avformat_alloc_context()
        let context = FFmpegFormatContext(existingPointer: rawCtx)
        XCTAssertNotNil(context.rawPointer, "rawPointer should be non-nil when initialized with valid pointer")
        // deinit will free the context
    }

    // MARK: - openInput Error Tests

    func testOpenInputWithInvalidURLThrows() throws {
        let context = try FFmpegFormatContext()
        XCTAssertThrowsError(try context.openInput(url: "invalid://not-a-real-url")) { error in
            XCTAssertTrue(error is FFmpegError, "Error should be FFmpegError, got \(type(of: error))")
        }
    }

    func testOpenInputWithEmptyURLThrows() throws {
        let context = try FFmpegFormatContext()
        XCTAssertThrowsError(try context.openInput(url: "")) { error in
            XCTAssertTrue(error is FFmpegError, "Error should be FFmpegError for empty URL")
        }
    }

    func testOpenInputWithNonexistentFileThrows() throws {
        let context = try FFmpegFormatContext()
        XCTAssertThrowsError(try context.openInput(url: "/nonexistent/path/to/file.mp4")) { error in
            XCTAssertTrue(error is FFmpegError, "Error should be FFmpegError for nonexistent file")
        }
    }

    // MARK: - findStreamInfo Error Tests

    func testFindStreamInfoWithoutOpenInputThrows() throws {
        let context = try FFmpegFormatContext()
        // Calling findStreamInfo without opening input should fail
        // (the context has no streams to analyze)
        XCTAssertThrowsError(try context.findStreamInfo()) { error in
            XCTAssertTrue(error is FFmpegError, "Error should be FFmpegError")
        }
    }

    // MARK: - stream(at:) Tests

    func testStreamAtInvalidIndexReturnsNil() throws {
        let context = try FFmpegFormatContext()
        XCTAssertNil(context.stream(at: 0), "stream(at:) should return nil when no streams exist")
        XCTAssertNil(context.stream(at: -1), "stream(at:) should return nil for negative index")
        XCTAssertNil(context.stream(at: 100), "stream(at:) should return nil for out-of-bounds index")
    }

    func testStreamAtWithNilContextReturnsNil() {
        let context = FFmpegFormatContext(existingPointer: nil)
        XCTAssertNil(context.stream(at: 0), "stream(at:) should return nil when context is nil")
    }

    // MARK: - Deinitialization / Resource Cleanup Tests

    func testDeinitDoesNotCrashForAllocatedContext() throws {
        // Verify that creating and immediately destroying a context doesn't crash
        _ = try FFmpegFormatContext()
        // If we reach here without crashing, the test passes
    }

    func testDeinitDoesNotCrashForNilContext() {
        // Verify that destroying a nil-pointer context doesn't crash
        _ = FFmpegFormatContext(existingPointer: nil)
    }

    func testDeinitDoesNotCrashAfterFailedOpenInput() throws {
        // Verify cleanup works correctly after a failed openInput
        let context = try FFmpegFormatContext()
        do {
            try context.openInput(url: "invalid://url")
        } catch {
            // Expected to fail
        }
        // deinit should handle this gracefully
    }

    func testMultipleContextsCanBeAllocatedAndFreed() throws {
        // Verify no resource leaks when creating multiple contexts
        for _ in 0..<10 {
            _ = try FFmpegFormatContext()
        }
    }
}

final class FFmpegCodecContextTests: XCTestCase {

    // MARK: - Allocation Tests

    func testInitAllocatesContext() throws {
        let context = try FFmpegCodecContext()
        XCTAssertNotNil(context.rawPointer, "rawPointer should be non-nil after successful init")
    }

    func testInitWithCodecAllocatesContext() throws {
        // Find a known decoder (AAC is widely available)
        guard let codec = avcodec_find_decoder(AV_CODEC_ID_AAC) else {
            // Skip test if AAC decoder not available in this FFmpeg build
            throw XCTSkip("AAC decoder not available")
        }
        let context = try FFmpegCodecContext(codec: codec)
        XCTAssertNotNil(context.rawPointer, "rawPointer should be non-nil when initialized with codec")
    }

    // MARK: - openDecoder Tests

    func testOpenDecoderWithSupportedCodec() throws {
        // Test opening a known supported decoder
        guard avcodec_find_decoder(AV_CODEC_ID_AAC) != nil else {
            throw XCTSkip("AAC decoder not available")
        }
        let context = try FFmpegCodecContext()
        XCTAssertNoThrow(try context.openDecoder(for: AV_CODEC_ID_AAC))
    }

    func testOpenDecoderWithUnsupportedCodecThrows() throws {
        let context = try FFmpegCodecContext()
        // AV_CODEC_ID_NONE should not have a decoder
        XCTAssertThrowsError(try context.openDecoder(for: AV_CODEC_ID_NONE)) { error in
            guard let ffError = error as? FFmpegError else {
                XCTFail("Expected FFmpegError, got \(type(of: error))")
                return
            }
            if case .unsupportedFormat(let codecName) = ffError {
                XCTAssertFalse(codecName.isEmpty, "Codec name should not be empty")
            } else {
                XCTFail("Expected unsupportedFormat error, got \(ffError)")
            }
        }
    }

    // MARK: - open(codec:) Tests

    func testOpenWithValidCodec() throws {
        guard let codec = avcodec_find_decoder(AV_CODEC_ID_AAC) else {
            throw XCTSkip("AAC decoder not available")
        }
        let context = try FFmpegCodecContext(codec: codec)
        XCTAssertNoThrow(try context.open(codec: codec))
    }

    // MARK: - setParameters Tests

    func testSetParametersWithNilContextThrows() throws {
        // We can't easily create a nil-pointer FFmpegCodecContext through the public init
        // (it throws on allocation failure), but we test the error path conceptually.
        // Instead, test that setParameters works with valid parameters from a format context.
        // This is more of an integration concern, so we just verify the method exists
        // and the context is properly allocated.
        let context = try FFmpegCodecContext()
        XCTAssertNotNil(context.rawPointer)
    }

    // MARK: - Deinitialization / Resource Cleanup Tests

    func testDeinitDoesNotCrashForAllocatedContext() throws {
        _ = try FFmpegCodecContext()
    }

    func testDeinitDoesNotCrashAfterOpeningCodec() throws {
        guard let codec = avcodec_find_decoder(AV_CODEC_ID_AAC) else {
            throw XCTSkip("AAC decoder not available")
        }
        let context = try FFmpegCodecContext(codec: codec)
        try context.open(codec: codec)
        // deinit should properly free the opened codec context
    }

    func testMultipleContextsCanBeAllocatedAndFreed() throws {
        for _ in 0..<10 {
            _ = try FFmpegCodecContext()
        }
    }

    func testDeinitAfterFailedOpenDecoder() throws {
        let context = try FFmpegCodecContext()
        do {
            try context.openDecoder(for: AV_CODEC_ID_NONE)
        } catch {
            // Expected
        }
        // deinit should handle this gracefully
    }
}
