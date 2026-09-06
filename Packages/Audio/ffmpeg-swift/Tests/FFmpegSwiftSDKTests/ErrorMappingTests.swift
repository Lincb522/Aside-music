// ErrorMappingTests.swift
// FFmpegSwiftSDKTests
//
// Unit tests for FFmpegError enum and error code mapping.

import XCTest
@testable import FFmpegSwiftSDK

final class ErrorMappingTests: XCTestCase {

    // MARK: - from(code:) Mapping Tests

    func testConnectionRefusedMapsToConnectionFailed() {
        let error = FFmpegError.from(code: -111)
        if case .connectionFailed(let code, let message) = error {
            XCTAssertEqual(code, -111)
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected connectionFailed, got \(error)")
        }
    }

    func testProtocolNotFoundMapsToConnectionFailed() {
        let error = FFmpegError.from(code: FFmpegErrorCode.AVERROR_PROTOCOL_NOT_FOUND)
        if case .connectionFailed(let code, _) = error {
            XCTAssertEqual(code, FFmpegErrorCode.AVERROR_PROTOCOL_NOT_FOUND)
        } else {
            XCTFail("Expected connectionFailed, got \(error)")
        }
    }

    func testNoSuchFileMapsToConnectionFailed() {
        let error = FFmpegError.from(code: -2)
        if case .connectionFailed(let code, _) = error {
            XCTAssertEqual(code, -2)
        } else {
            XCTFail("Expected connectionFailed, got \(error)")
        }
    }

    func testTimeoutMapsToConnectionTimeout() {
        let error = FFmpegError.from(code: -110)
        XCTAssertEqual(error, .connectionTimeout)
    }

    func testInvalidDataMapsToUnsupportedFormat() {
        let error = FFmpegError.from(code: FFmpegErrorCode.AVERROR_INVALIDDATA)
        if case .unsupportedFormat(let codecName) = error {
            XCTAssertFalse(codecName.isEmpty)
        } else {
            XCTFail("Expected unsupportedFormat, got \(error)")
        }
    }

    func testDecoderNotFoundMapsToUnsupportedFormat() {
        let error = FFmpegError.from(code: FFmpegErrorCode.AVERROR_DECODER_NOT_FOUND)
        if case .unsupportedFormat(let codecName) = error {
            XCTAssertFalse(codecName.isEmpty)
        } else {
            XCTFail("Expected unsupportedFormat, got \(error)")
        }
    }

    func testDemuxerNotFoundMapsToUnsupportedFormat() {
        let error = FFmpegError.from(code: FFmpegErrorCode.AVERROR_DEMUXER_NOT_FOUND)
        if case .unsupportedFormat = error {
            // pass
        } else {
            XCTFail("Expected unsupportedFormat, got \(error)")
        }
    }

    func testStreamNotFoundMapsToUnsupportedFormat() {
        let error = FFmpegError.from(code: FFmpegErrorCode.AVERROR_STREAM_NOT_FOUND)
        if case .unsupportedFormat = error {
            // pass
        } else {
            XCTFail("Expected unsupportedFormat, got \(error)")
        }
    }

    func testIOErrorMapsToDecodingFailed() {
        let error = FFmpegError.from(code: -5)
        if case .decodingFailed(let code, let message) = error {
            XCTAssertEqual(code, -5)
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected decodingFailed, got \(error)")
        }
    }

    func testEOFMapsToDecodingFailed() {
        let error = FFmpegError.from(code: FFmpegErrorCode.AVERROR_EOF)
        if case .decodingFailed(let code, _) = error {
            XCTAssertEqual(code, FFmpegErrorCode.AVERROR_EOF)
        } else {
            XCTFail("Expected decodingFailed, got \(error)")
        }
    }

    func testOutOfMemoryMapsToResourceAllocationFailed() {
        let error = FFmpegError.from(code: -12)
        if case .resourceAllocationFailed(let resource) = error {
            XCTAssertFalse(resource.isEmpty)
        } else {
            XCTFail("Expected resourceAllocationFailed, got \(error)")
        }
    }

    func testConnectionResetMapsToNetworkDisconnected() {
        let error = FFmpegError.from(code: -104)
        XCTAssertEqual(error, .networkDisconnected)
    }

    func testBrokenPipeMapsToNetworkDisconnected() {
        let error = FFmpegError.from(code: -32)
        XCTAssertEqual(error, .networkDisconnected)
    }

    func testUnknownCodeMapsToUnknown() {
        let error = FFmpegError.from(code: -99999)
        if case .unknown(let code) = error {
            XCTAssertEqual(code, -99999)
        } else {
            XCTFail("Expected unknown, got \(error)")
        }
    }

    // MARK: - description Tests

    func testDescriptionIsNonEmpty() {
        let errors: [FFmpegError] = [
            .connectionFailed(code: -111, message: "refused"),
            .connectionTimeout,
            .unsupportedFormat(codecName: "vp9"),
            .decodingFailed(code: -5, message: "io error"),
            .resourceAllocationFailed(resource: "memory"),
            .networkDisconnected,
            .unknown(code: -1),
        ]
        for error in errors {
            XCTAssertFalse(error.description.isEmpty, "Description should not be empty for \(error)")
        }
    }

    func testConnectionFailedDescriptionContainsCodeAndMessage() {
        let error = FFmpegError.connectionFailed(code: -111, message: "Connection refused")
        XCTAssertTrue(error.description.contains("-111"))
        XCTAssertTrue(error.description.contains("Connection refused"))
    }

    func testUnsupportedFormatDescriptionContainsCodecName() {
        let error = FFmpegError.unsupportedFormat(codecName: "vp9")
        XCTAssertTrue(error.description.contains("vp9"))
    }

    // MARK: - ffmpegCode Tests

    func testFfmpegCodeReturnsOriginalCode() {
        // Test codes that carry the original code in their associated values
        let codesWithOriginal: [Int32] = [-111, -2, -5, -99999]
        for code in codesWithOriginal {
            let error = FFmpegError.from(code: code)
            XCTAssertEqual(error.ffmpegCode, code,
                "ffmpegCode should return the original code \(code) for error \(error)")
        }
    }

    func testFfmpegCodeForCasesWithCanonicalCodes() {
        // Cases without associated codes return their canonical FFmpeg error code.
        // E.g., both ECONNRESET (-104) and EPIPE (-32) map to .networkDisconnected,
        // which returns the canonical ECONNRESET code.
        let error104 = FFmpegError.from(code: -104)
        XCTAssertEqual(error104.ffmpegCode, -104)

        let error32 = FFmpegError.from(code: -32)
        // .networkDisconnected returns canonical code ECONNRESET (-104)
        XCTAssertEqual(error32.ffmpegCode, FFmpegErrorCode.AVERROR_ECONNRESET)

        // ENOMEM maps to .resourceAllocationFailed with canonical code
        let error12 = FFmpegError.from(code: -12)
        XCTAssertEqual(error12.ffmpegCode, FFmpegErrorCode.AVERROR_ENOMEM)
    }

    func testFfmpegCodeForConnectionTimeout() {
        let error = FFmpegError.connectionTimeout
        XCTAssertEqual(error.ffmpegCode, -110)
    }

    func testFfmpegCodeForNetworkDisconnected() {
        // networkDisconnected returns ECONNRESET code
        let error = FFmpegError.networkDisconnected
        XCTAssertEqual(error.ffmpegCode, -104)
    }

    func testFfmpegCodeForResourceAllocationFailed() {
        let error = FFmpegError.resourceAllocationFailed(resource: "codec context")
        XCTAssertEqual(error.ffmpegCode, -12)
    }

    func testFfmpegCodeForUnsupportedFormat() {
        let error = FFmpegError.unsupportedFormat(codecName: "vp9")
        XCTAssertEqual(error.ffmpegCode, FFmpegErrorCode.AVERROR_DECODER_NOT_FOUND)
    }

    // MARK: - Error Protocol Conformance

    func testConformsToErrorProtocol() {
        let error: Error = FFmpegError.unknown(code: -1)
        XCTAssertNotNil(error)
    }

    func testCanBeThrownAndCaught() {
        func throwingFunction() throws {
            throw FFmpegError.connectionTimeout
        }

        XCTAssertThrowsError(try throwingFunction()) { error in
            XCTAssertTrue(error is FFmpegError)
            if let ffError = error as? FFmpegError {
                XCTAssertEqual(ffError, .connectionTimeout)
            }
        }
    }

    // MARK: - isUnrecoverable Tests

    func testConnectionFailedIsUnrecoverable() {
        let error = FFmpegError.connectionFailed(code: -111, message: "refused")
        XCTAssertTrue(error.isUnrecoverable)
    }

    func testConnectionTimeoutIsUnrecoverable() {
        XCTAssertTrue(FFmpegError.connectionTimeout.isUnrecoverable)
    }

    func testResourceAllocationFailedIsUnrecoverable() {
        let error = FFmpegError.resourceAllocationFailed(resource: "memory")
        XCTAssertTrue(error.isUnrecoverable)
    }

    func testNetworkDisconnectedIsUnrecoverable() {
        XCTAssertTrue(FFmpegError.networkDisconnected.isUnrecoverable)
    }

    func testUnsupportedFormatIsUnrecoverable() {
        let error = FFmpegError.unsupportedFormat(codecName: "vp9")
        XCTAssertTrue(error.isUnrecoverable)
    }

    func testDecodingFailedIsRecoverable() {
        let error = FFmpegError.decodingFailed(code: -5, message: "frame error")
        XCTAssertFalse(error.isUnrecoverable)
    }

    func testUnknownErrorIsUnrecoverable() {
        let error = FFmpegError.unknown(code: -99999)
        XCTAssertTrue(error.isUnrecoverable)
    }

    // MARK: - Edge Cases

    func testFromCodeWithZeroReturnsUnknown() {
        // Zero is not a negative error code, but from(code:) should handle it gracefully
        let error = FFmpegError.from(code: 0)
        if case .unknown(let code) = error {
            XCTAssertEqual(code, 0)
        } else {
            XCTFail("Expected unknown for code 0, got \(error)")
        }
    }

    func testFromCodeWithInt32MinReturnsUnknown() {
        let error = FFmpegError.from(code: Int32.min)
        if case .unknown(let code) = error {
            XCTAssertEqual(code, Int32.min)
        } else {
            XCTFail("Expected unknown for Int32.min, got \(error)")
        }
    }
}
