import Foundation

func testEQCoefficientContinuity() {
    let frames = 512
    let data = UnsafeMutablePointer<Float>.allocate(capacity: frames)
    defer { data.deallocate() }
    let buffer = AudioBuffer(data: data, frameCount: frames, channelCount: 1, sampleRate: 48_000)
    var maximumStep: Float = 0
    for parametric in [false, true] {
        let eq = EQFilter()
        var band = ParametricEQBand(type: .highShelf, frequency: 8_000, gainDB: -3)
        var gains = Array(repeating: Float(0), count: 10)
        gains[9] = -6
        if parametric { eq.setParametricBands([band]) }
        else { eq.setGraphicMode(.tenBand, gains: gains) }
        for _ in 0..<300 {
            data.update(repeating: 0.2, count: frames)
            _ = eq.process(buffer)
        }
        var previous = data[frames - 1]
        band.gainDB = 3
        gains[9] = 6
        if parametric { eq.setParametricBands([band]) }
        else { eq.setGraphicMode(.tenBand, gains: gains) }
        for _ in 0..<80 {
            data.update(repeating: 0.2, count: frames)
            _ = eq.process(buffer)
            for frame in 0..<frames {
                maximumStep = max(maximumStep, abs(data[frame] - previous))
                require(abs(data[frame] - 0.2) < 0.000_01, "Changing shelf coefficients injected a pulse into constant input")
                previous = data[frame]
            }
        }
        // Continuity must not be implemented by bypassing the requested EQ.
        var inputEnergy: Float = 0
        var outputEnergy: Float = 0
        for block in 0..<80 {
            for frame in 0..<frames {
                data[frame] = 0.1 * sinf(Float(2 * Double.pi * 20_000 * Double(block * frames + frame) / 48_000))
                if block > 40 { inputEnergy += data[frame] * data[frame] }
            }
            _ = eq.process(buffer)
            if block > 40 {
                for frame in 0..<frames { outputEnergy += data[frame] * data[frame] }
            }
        }
        require(outputEnergy > inputEnergy * 1.3, "Shelf continuity bypassed the requested high-frequency boost")
    }
    print("PASS graphic/parametric coefficient continuity: maximum sample step \(maximumStep), EQ boost retained")
}

func testDynamicEQContinuity() {
    let frames = 512
    let data = UnsafeMutablePointer<Float>.allocate(capacity: frames)
    defer { data.deallocate() }
    let eq = EQFilter()
    eq.setDynamicEQ(enabled: true, bands: [DynamicEQBand(
        frequency: 8_000, q: 1, thresholdDB: -30, ratio: 4,
        maxReductionDB: 6, attackMS: 10, releaseMS: 600
    )])
    let buffer = AudioBuffer(data: data, frameCount: frames, channelCount: 1, sampleRate: 48_000)
    for block in 0..<200 {
        for frame in 0..<frames {
            data[frame] = 0.2 + 0.5 * sinf(Float(2 * Double.pi * 8_000 * Double(block * frames + frame) / 48_000))
        }
        _ = eq.process(buffer)
    }
    var largestError: Float = 0
    for block in 0..<80 {
        data.update(repeating: 0.2, count: frames)
        _ = eq.process(buffer)
        if block >= 10 {
            for frame in 0..<frames {
                largestError = max(largestError, abs(data[frame] - 0.2))
                require(abs(data[frame] - 0.2) < 0.000_01, "Dynamic EQ release injected a callback-boundary pulse")
            }
        }
    }
    print("PASS dynamic EQ release without control writes: maximum constant-input error \(largestError)")
}

func testEQLayoutContinuity() {
    let data = UnsafeMutablePointer<Float>.allocate(capacity: 4096 * 2)
    defer { data.deallocate() }
    var maximumStep: Float = 0
    for rate in [44_100, 48_000, 96_000] {
        for channels in [1, 2] {
            let eq = EQFilter()
            eq.setGraphicMode(.tenBand, gains: Array(repeating: 2, count: 10))
            eq.setPreampDB(-6)
            let warmup = AudioBuffer(data: data, frameCount: 512, channelCount: channels, sampleRate: rate)
            for _ in 0..<400 {
                data.update(repeating: 0.2, count: 512 * channels)
                _ = eq.process(warmup)
            }
            var previous = data[(512 - 1) * channels]
            for mode in [GraphicEQMode.thirtyTwoBand, .tenBand] {
                eq.setGraphicMode(mode, gains: Array(repeating: 2, count: mode.bandCount))
                for block in 0..<180 {
                    let frames = [17, 128, 511, 1024, 4096][block % 5]
                    data.update(repeating: 0.2, count: frames * channels)
                    _ = eq.process(AudioBuffer(data: data, frameCount: frames, channelCount: channels, sampleRate: rate))
                    for frame in 0..<frames {
                        let value = data[frame * channels]
                        maximumStep = max(maximumStep, abs(value - previous))
                        require(value.isFinite && abs(value - previous) < 0.000_5, "EQ layout handoff jumped or reset the safety preamp")
                        if channels == 2 { require(value == data[frame * channels + 1], "Layout handoff changed stereo balance") }
                        previous = value
                    }
                }
            }
        }
    }
    print("PASS 10/32 layout handoff: variable blocks, mono/stereo, 44.1/48/96 kHz; maximum sample step \(maximumStep)")
}

func testEQLayoutLatestUpdate() {
    let frames = 128
    let data = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
    defer { data.deallocate() }
    let eq = EQFilter()
    let buffer = AudioBuffer(data: data, frameCount: frames, channelCount: 2, sampleRate: 48_000)
    // All updates arrive before the first 40 ms handoff has completed.
    for block in 0..<9 {
        let mode: GraphicEQMode = block.isMultiple(of: 2) ? .thirtyTwoBand : .tenBand
        eq.setGraphicMode(mode, gains: Array(repeating: block.isMultiple(of: 2) ? 3 : -2, count: mode.bandCount))
        eq.setPreampDB(-3)
        data.update(repeating: 0.2, count: frames * 2)
        _ = eq.process(buffer)
    }
    eq.setGraphicMode(.tenBand, gains: Array(repeating: 0, count: 10))
    eq.setPreampDB(-9)
    for _ in 0..<400 {
        data.update(repeating: 0.2, count: frames * 2)
        _ = eq.process(buffer)
    }
    let expected = Float(0.2) * powf(10, -9 / 20)
    for sample in 0..<(frames * 2) {
        require(abs(data[sample] - expected) < 0.000_1, "A control update arriving during layout handoff was lost")
    }
    print("PASS rapid layout updates: final EQ and preamp configuration retained")
}
