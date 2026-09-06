// EQFilterTests.swift
// FFmpegSwiftSDKTests
//
// Unit tests for EQFilter: Biquad peaking EQ filter implementation.

import XCTest
@testable import FFmpegSwiftSDK

final class EQFilterTests: XCTestCase {

    // MARK: - Helpers

    /// Creates an AudioBuffer filled with the given value.
    private func makeBuffer(
        value: Float = 1.0,
        frameCount: Int = 1024,
        channelCount: Int = 2,
        sampleRate: Int = 44100
    ) -> AudioBuffer {
        let totalSamples = frameCount * channelCount
        let data = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)
        for i in 0..<totalSamples {
            data[i] = value
        }
        return AudioBuffer(data: data, frameCount: frameCount, channelCount: channelCount, sampleRate: sampleRate)
    }

    /// Creates an AudioBuffer with a sine wave.
    private func makeSineBuffer(
        frequency: Float = 440.0,
        frameCount: Int = 1024,
        channelCount: Int = 1,
        sampleRate: Int = 44100
    ) -> AudioBuffer {
        let totalSamples = frameCount * channelCount
        let data = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)
        for frame in 0..<frameCount {
            let sample = sinf(2.0 * Float.pi * frequency * Float(frame) / Float(sampleRate))
            for ch in 0..<channelCount {
                data[frame * channelCount + ch] = sample
            }
        }
        return AudioBuffer(data: data, frameCount: frameCount, channelCount: channelCount, sampleRate: sampleRate)
    }

    /// Deallocates an AudioBuffer's data pointer.
    private func freeBuffer(_ buffer: AudioBuffer) {
        buffer.data.deallocate()
    }

    // MARK: - Initialization Tests

    func testInitialGainsAreZero() {
        let filter = EQFilter()
        for band in EQBand.allCases {
            XCTAssertEqual(filter.gain(for: band), 0.0, "Initial gain for \(band) should be 0 dB")
        }
    }

    // MARK: - setGain Tests

    func testSetGainReturnsClampedValue() {
        let filter = EQFilter()

        // Within range
        XCTAssertEqual(filter.setGain(6.0, for: .hz125), 6.0)
        XCTAssertEqual(filter.gain(for: .hz125), 6.0)

        // Above max
        XCTAssertEqual(filter.setGain(20.0, for: .hz1k), 12.0)
        XCTAssertEqual(filter.gain(for: .hz1k), 12.0)

        // Below min
        XCTAssertEqual(filter.setGain(-20.0, for: .hz8k), -12.0)
        XCTAssertEqual(filter.gain(for: .hz8k), -12.0)

        // Exact boundaries
        XCTAssertEqual(filter.setGain(-12.0, for: .hz125), -12.0)
        XCTAssertEqual(filter.setGain(12.0, for: .hz125), 12.0)
    }

    func testSetGainUpdatesOnlySpecifiedBand() {
        let filter = EQFilter()
        filter.setGain(6.0, for: .hz125)

        XCTAssertEqual(filter.gain(for: .hz125), 6.0)
        XCTAssertEqual(filter.gain(for: .hz1k), 0.0)
        XCTAssertEqual(filter.gain(for: .hz8k), 0.0)
    }

    // MARK: - Reset Tests

    func testResetClearsAllGains() {
        let filter = EQFilter()
        filter.setGain(6.0, for: .hz125)
        filter.setGain(-3.0, for: .hz1k)
        filter.setGain(9.0, for: .hz8k)

        filter.reset()

        for band in EQBand.allCases {
            XCTAssertEqual(filter.gain(for: band), 0.0, "Gain for \(band) should be 0 after reset")
        }
    }

    // MARK: - Zero Gain Identity Tests

    func testZeroGainProducesIdentityOutput() {
        let filter = EQFilter()
        let input = makeSineBuffer(frequency: 440.0, frameCount: 1024, channelCount: 2, sampleRate: 44100)
        defer { freeBuffer(input) }

        let output = filter.process(input)
        defer { freeBuffer(output) }

        let totalSamples = input.frameCount * input.channelCount
        for i in 0..<totalSamples {
            XCTAssertEqual(
                output.data[i], input.data[i],
                accuracy: 1e-6,
                "Sample \(i): output should equal input at 0 dB gain"
            )
        }
    }

    func testZeroGainIdentityMono() {
        let filter = EQFilter()
        let input = makeSineBuffer(frequency: 1000.0, frameCount: 512, channelCount: 1, sampleRate: 48000)
        defer { freeBuffer(input) }

        let output = filter.process(input)
        defer { freeBuffer(output) }

        let totalSamples = input.frameCount * input.channelCount
        for i in 0..<totalSamples {
            XCTAssertEqual(output.data[i], input.data[i], accuracy: 1e-6)
        }
    }

    // MARK: - Process Output Tests

    func testProcessReturnsNewBuffer() {
        let filter = EQFilter()
        let input = makeBuffer(value: 0.5, frameCount: 256, channelCount: 2, sampleRate: 44100)
        defer { freeBuffer(input) }

        let output = filter.process(input)
        defer { freeBuffer(output) }

        // Output should be a different pointer
        XCTAssertNotEqual(output.data, input.data, "process() must return a new buffer")

        // Metadata should match
        XCTAssertEqual(output.frameCount, input.frameCount)
        XCTAssertEqual(output.channelCount, input.channelCount)
        XCTAssertEqual(output.sampleRate, input.sampleRate)
    }

    func testProcessDoesNotModifyInput() {
        let filter = EQFilter()
        filter.setGain(6.0, for: .hz1k)

        let input = makeSineBuffer(frequency: 1000.0, frameCount: 512, channelCount: 1, sampleRate: 44100)
        let totalSamples = input.frameCount * input.channelCount

        // Save a copy of input data
        let inputCopy = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)
        inputCopy.initialize(from: input.data, count: totalSamples)
        defer { inputCopy.deallocate() }

        let output = filter.process(input)
        defer { freeBuffer(output); freeBuffer(input) }

        // Input should be unchanged
        for i in 0..<totalSamples {
            XCTAssertEqual(input.data[i], inputCopy[i], "process() must not modify input buffer")
        }
    }

    // MARK: - Non-Zero Gain Effect Tests

    func testNonZeroGainChangesOutput() {
        let filter = EQFilter()
        filter.setGain(12.0, for: .hz1k)

        // Use a sine wave at the mid band center frequency (1000 Hz)
        let input = makeSineBuffer(frequency: 1000.0, frameCount: 4096, channelCount: 1, sampleRate: 44100)
        defer { freeBuffer(input) }

        let output = filter.process(input)
        defer { freeBuffer(output) }

        // With +12dB gain at 1000Hz, the output should differ from input
        var hasDifference = false
        for i in 0..<(input.frameCount * input.channelCount) {
            if abs(output.data[i] - input.data[i]) > 1e-6 {
                hasDifference = true
                break
            }
        }
        XCTAssertTrue(hasDifference, "Non-zero gain should produce different output")
    }

    // MARK: - Thread Safety Tests

    func testConcurrentGainSetAndProcess() {
        let filter = EQFilter()
        let iterations = 100
        let expectation = XCTestExpectation(description: "Concurrent operations complete without crash")
        expectation.expectedFulfillmentCount = 2

        // Thread 1: repeatedly set gains
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<iterations {
                let gain = Float(i % 24) - 12.0
                filter.setGain(gain, for: .hz125)
                filter.setGain(gain, for: .hz1k)
                filter.setGain(gain, for: .hz8k)
            }
            expectation.fulfill()
        }

        // Thread 2: repeatedly process buffers
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<iterations {
                let input = UnsafeMutablePointer<Float>.allocate(capacity: 256)
                for j in 0..<256 { input[j] = Float(j) / 256.0 }
                let buffer = AudioBuffer(data: input, frameCount: 128, channelCount: 2, sampleRate: 44100)
                let output = filter.process(buffer)
                output.data.deallocate()
                input.deallocate()
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Biquad Coefficient Tests

    func testBiquadUnityCoefficientsAtZeroGain() {
        // At 0 dB gain, the peaking EQ should produce unity coefficients
        let coeffs = BiquadCoefficients.peakingEQ(
            gainDB: 0.0,
            centerFrequency: 1000.0,
            sampleRate: 44100.0
        )

        // At 0 dB: A = 1, so b0 = 1 + alpha, b2 = 1 - alpha, a0 = 1 + alpha, a2 = 1 - alpha
        // After normalization: b0/a0 = 1, b1/a0 = a1/a0, b2/a0 = a2/a0
        XCTAssertEqual(coeffs.b0, 1.0, accuracy: 1e-6, "b0 should be 1.0 at 0 dB")
        XCTAssertEqual(coeffs.b2, coeffs.a2, accuracy: 1e-6, "b2 should equal a2 at 0 dB (both normalized)")

        // b1 and a1 are both -2*cos(w0), so after normalization b1/a0 == a1/a0
        // Since b1 == a1 in the unnormalized form, after dividing by a0 they remain equal
        // But b1/a0 is stored as b1, and a1/a0 is stored as a1, so they should be equal
        XCTAssertEqual(coeffs.b1, coeffs.a1, accuracy: 1e-6, "b1 should equal a1 at 0 dB")
    }

    func testBiquadUnityPassthrough() {
        let unity = BiquadCoefficients.unity
        XCTAssertEqual(unity.b0, 1.0)
        XCTAssertEqual(unity.b1, 0.0)
        XCTAssertEqual(unity.b2, 0.0)
        XCTAssertEqual(unity.a1, 0.0)
        XCTAssertEqual(unity.a2, 0.0)
    }
}
