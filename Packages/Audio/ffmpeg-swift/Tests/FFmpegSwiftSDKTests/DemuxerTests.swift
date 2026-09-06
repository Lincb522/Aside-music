// DemuxerTests.swift
// FFmpegSwiftSDKTests
//
// Unit tests for the Demuxer class.
// Tests stream discovery, packet reading, error handling, and StreamInfo construction.

import XCTest
@testable import FFmpegSwiftSDK
import CFFmpeg

final class DemuxerTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDemuxerInitSetsStreamIndicesToNegativeOne() throws {
        let context = try FFmpegFormatContext()
        let demuxer = Demuxer(formatContext: context, url: "test://url")

        XCTAssertEqual(demuxer.currentAudioStreamIndex, -1,
                       "Audio stream index should be -1 before findStreams()")
        XCTAssertEqual(demuxer.currentVideoStreamIndex, -1,
                       "Video stream index should be -1 before findStreams()")
    }

    // MARK: - findStreams() Error Tests

    func testFindStreamsWithNilContextThrows() {
        let context = FFmpegFormatContext(existingPointer: nil)
        let demuxer = Demuxer(formatContext: context, url: "test://url")

        XCTAssertThrowsError(try demuxer.findStreams()) { error in
            guard let ffError = error as? FFmpegError else {
                XCTFail("Expected FFmpegError, got \(type(of: error))")
                return
            }
            if case .resourceAllocationFailed(let resource) = ffError {
                XCTAssertTrue(resource.contains("AVFormatContext"),
                              "Error should mention AVFormatContext")
            } else {
                XCTFail("Expected resourceAllocationFailed, got \(ffError)")
            }
        }
    }

    func testFindStreamsWithEmptyContextReturnsNoStreams() throws {
        // A freshly allocated context has no streams
        let context = try FFmpegFormatContext()
        let demuxer = Demuxer(formatContext: context, url: "test://empty")

        let info = try demuxer.findStreams()

        XCTAssertEqual(info.url, "test://empty")
        XCTAssertFalse(info.hasAudio, "Should have no audio in empty context")
        XCTAssertFalse(info.hasVideo, "Should have no video in empty context")
        XCTAssertNil(info.audioCodec)
        XCTAssertNil(info.videoCodec)
        XCTAssertNil(info.sampleRate)
        XCTAssertNil(info.channelCount)
        XCTAssertNil(info.width)
        XCTAssertNil(info.height)
        XCTAssertEqual(demuxer.currentAudioStreamIndex, -1)
        XCTAssertEqual(demuxer.currentVideoStreamIndex, -1)
    }

    // MARK: - readNextPacket() Error Tests

    func testReadNextPacketWithNilContextThrows() {
        let context = FFmpegFormatContext(existingPointer: nil)
        let demuxer = Demuxer(formatContext: context, url: "test://url")

        XCTAssertThrowsError(try demuxer.readNextPacket()) { error in
            guard let ffError = error as? FFmpegError else {
                XCTFail("Expected FFmpegError, got \(type(of: error))")
                return
            }
            if case .resourceAllocationFailed(let resource) = ffError {
                XCTAssertTrue(resource.contains("AVFormatContext"),
                              "Error should mention AVFormatContext")
            } else {
                XCTFail("Expected resourceAllocationFailed, got \(ffError)")
            }
        }
    }

    func testReadNextPacketWithNilContextThrowsResourceError() {
        // Reading from a nil context should throw a resource allocation error
        // (not crash). We only test the nil-context path here since calling
        // av_read_frame on an allocated-but-unopened context is undefined behavior.
        let context = FFmpegFormatContext(existingPointer: nil)
        let demuxer = Demuxer(formatContext: context, url: "test://nil")

        XCTAssertThrowsError(try demuxer.readNextPacket()) { error in
            guard let ffError = error as? FFmpegError else {
                XCTFail("Expected FFmpegError, got \(type(of: error))")
                return
            }
            if case .resourceAllocationFailed = ffError {
                // Expected
            } else {
                XCTFail("Expected resourceAllocationFailed, got \(ffError)")
            }
        }
    }

    // MARK: - StreamInfo Model Tests

    func testStreamInfoInitialization() {
        let info = StreamInfo(
            url: "rtmp://example.com/live",
            hasAudio: true,
            hasVideo: true,
            audioCodec: "aac",
            videoCodec: "h264",
            sampleRate: 44100,
            channelCount: 2, bitDepth: nil,
            width: 1920,
            height: 1080,
            duration: 120.5
        )

        XCTAssertEqual(info.url, "rtmp://example.com/live")
        XCTAssertTrue(info.hasAudio)
        XCTAssertTrue(info.hasVideo)
        XCTAssertEqual(info.audioCodec, "aac")
        XCTAssertEqual(info.videoCodec, "h264")
        XCTAssertEqual(info.sampleRate, 44100)
        XCTAssertEqual(info.channelCount, 2)
        XCTAssertEqual(info.width, 1920)
        XCTAssertEqual(info.height, 1080)
        XCTAssertEqual(info.duration, 120.5)
    }

    func testStreamInfoForLiveStream() {
        let info = StreamInfo(
            url: "rtmp://live.example.com/stream",
            hasAudio: true,
            hasVideo: true,
            audioCodec: "aac",
            videoCodec: "h264",
            sampleRate: 48000,
            channelCount: 2, bitDepth: nil,
            width: 1280,
            height: 720,
            duration: nil
        )

        XCTAssertNil(info.duration, "Duration should be nil for live streams")
        XCTAssertTrue(info.hasAudio)
        XCTAssertTrue(info.hasVideo)
    }

    func testStreamInfoAudioOnly() {
        let info = StreamInfo(
            url: "http://example.com/audio.mp3",
            hasAudio: true,
            hasVideo: false,
            audioCodec: "mp3",
            videoCodec: nil,
            sampleRate: 44100,
            channelCount: 2, bitDepth: nil,
            width: nil,
            height: nil,
            duration: 300.0
        )

        XCTAssertTrue(info.hasAudio)
        XCTAssertFalse(info.hasVideo)
        XCTAssertEqual(info.audioCodec, "mp3")
        XCTAssertNil(info.videoCodec)
        XCTAssertNil(info.width)
        XCTAssertNil(info.height)
    }

    func testStreamInfoVideoOnly() {
        let info = StreamInfo(
            url: "http://example.com/video.h264",
            hasAudio: false,
            hasVideo: true,
            audioCodec: nil,
            videoCodec: "h264",
            sampleRate: nil,
            channelCount: nil, bitDepth: nil,
            width: 3840,
            height: 2160,
            duration: 60.0
        )

        XCTAssertFalse(info.hasAudio)
        XCTAssertTrue(info.hasVideo)
        XCTAssertNil(info.audioCodec)
        XCTAssertEqual(info.videoCodec, "h264")
        XCTAssertNil(info.sampleRate)
        XCTAssertNil(info.channelCount)
    }

    // MARK: - findStreams() Repeated Calls

    func testFindStreamsCanBeCalledMultipleTimes() throws {
        let context = try FFmpegFormatContext()
        let demuxer = Demuxer(formatContext: context, url: "test://repeated")

        // First call
        let info1 = try demuxer.findStreams()
        XCTAssertFalse(info1.hasAudio)
        XCTAssertFalse(info1.hasVideo)

        // Second call should reset and produce the same result
        let info2 = try demuxer.findStreams()
        XCTAssertFalse(info2.hasAudio)
        XCTAssertFalse(info2.hasVideo)
        XCTAssertEqual(info1.url, info2.url)
    }

    // MARK: - URL Preservation

    func testFindStreamsPreservesURL() throws {
        let testURL = "rtsp://camera.example.com:554/stream1"
        let context = try FFmpegFormatContext()
        let demuxer = Demuxer(formatContext: context, url: testURL)

        let info = try demuxer.findStreams()
        XCTAssertEqual(info.url, testURL, "StreamInfo should preserve the original URL")
    }

    // MARK: - Network Error Detection

    func testIsNetworkErrorReturnsTrueForConnectionReset() {
        XCTAssertTrue(Demuxer.isNetworkError(FFmpegErrorCode.AVERROR_ECONNRESET),
                       "ECONNRESET should be detected as a network error")
    }

    func testIsNetworkErrorReturnsTrueForBrokenPipe() {
        XCTAssertTrue(Demuxer.isNetworkError(FFmpegErrorCode.AVERROR_EPIPE),
                       "EPIPE should be detected as a network error")
    }

    func testIsNetworkErrorReturnsTrueForIOError() {
        XCTAssertTrue(Demuxer.isNetworkError(FFmpegErrorCode.AVERROR_EIO),
                       "EIO should be detected as a network error")
    }

    func testIsNetworkErrorReturnsTrueForTimeout() {
        XCTAssertTrue(Demuxer.isNetworkError(FFmpegErrorCode.AVERROR_ETIMEDOUT),
                       "ETIMEDOUT should be detected as a network error")
    }

    func testIsNetworkErrorReturnsFalseForEOF() {
        XCTAssertFalse(Demuxer.isNetworkError(FFmpegErrorCode.AVERROR_EOF),
                        "EOF should not be detected as a network error")
    }

    func testIsNetworkErrorReturnsFalseForOutOfMemory() {
        XCTAssertFalse(Demuxer.isNetworkError(FFmpegErrorCode.AVERROR_ENOMEM),
                        "ENOMEM should not be detected as a network error")
    }

    func testIsNetworkErrorReturnsFalseForDecoderNotFound() {
        XCTAssertFalse(Demuxer.isNetworkError(FFmpegErrorCode.AVERROR_DECODER_NOT_FOUND),
                        "DECODER_NOT_FOUND should not be detected as a network error")
    }

    func testIsNetworkErrorReturnsFalseForUnknownCode() {
        XCTAssertFalse(Demuxer.isNetworkError(-999),
                        "Unknown error code should not be detected as a network error")
    }
}
