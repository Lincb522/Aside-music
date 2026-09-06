import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

func stressControl(_ control: @escaping () -> Void, render: () -> Void) {
    let started = DispatchSemaphore(value: 0)
    let stop = DispatchSemaphore(value: 0)
    let finished = DispatchGroup()
    finished.enter()
    DispatchQueue.global().async {
        started.signal()
        while stop.wait(timeout: .now()) == .timedOut { control() }
        finished.leave()
    }
    require(started.wait(timeout: .now() + 5) == .success, "Control worker did not start")
    render()
    stop.signal()
    require(finished.wait(timeout: .now() + 5) == .success, "Control worker did not finish")
}

func testConfigurationContention() {
    let configuration = RealtimeAudioConfiguration(1)
    let locked = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let finished = DispatchGroup()
    finished.enter()
    DispatchQueue.global().async {
        configuration.update {
            $0 = 2
            locked.signal()
            require(release.wait(timeout: .now() + 5) == .success, "Configuration test timed out")
        }
        finished.leave()
    }
    require(locked.wait(timeout: .now() + 5) == .success, "Configuration was not locked")
    for _ in 0..<100 {
        require(configuration.takePending() == nil, "Render must defer a busy configuration")
    }
    release.signal()
    require(finished.wait(timeout: .now() + 5) == .success, "Configuration did not unlock")
    require(configuration.takePending() == 2, "Deferred configuration was lost")
    configuration.update { $0 = 2 }
    require(configuration.takePending() == nil, "Unchanged settings should not restart DSP ramps")
    print("PASS configuration contention: deferred, no wait, no lost update")
}

func testEQContention(mode: GraphicEQMode, channels: Int) {
    let frames = 128
    let samples = frames * channels
    let data = UnsafeMutablePointer<Float>.allocate(capacity: samples)
    defer { data.deallocate() }
    let buffer = AudioBuffer(data: data, frameCount: frames, channelCount: channels, sampleRate: 48_000)
    let eq = EQFilter()
    eq.setGraphicMode(mode)
    eq.setPreampDB(-12)
    for _ in 0..<200 {
        data.update(repeating: 0.4, count: samples)
        _ = eq.process(buffer)
    }
    var bypassed = 0
    var maximum: Float = 0
    var revision = 0
    stressControl({
        // Both real parameter changes and unchanged app refreshes must leave
        // the safety preamp applied on every block.
        revision += 1
        eq.setAdaptiveGains(Array(repeating: revision.isMultiple(of: 2) ? 0 : 0.01, count: mode.bandCount))
        eq.setPreampDB(-12)
        _ = eq.currentGraphicGains()
    }, render: {
        for _ in 0..<4_000 {
            data.update(repeating: 0.4, count: samples)
            _ = eq.process(buffer)
            for index in 0..<samples {
                require(data[index].isFinite, "Non-finite EQ output")
                maximum = max(maximum, abs(data[index]))
            }
            if abs(data[0]) > 0.2 { bypassed += 1 }
        }
    })
    require(bypassed == 0 && maximum < 0.12, "EQ/preamp bypassed under contention: \(bypassed), peak \(maximum)")
    print("PASS \(mode.bandCount)-band / \(channels)-channel contention: \(bypassed) bypassed blocks, peak \(maximum)")
}

func testLimiterContention() {
    let frames = 128
    let samples = frames * 2
    let data = UnsafeMutablePointer<Float>.allocate(capacity: samples)
    defer { data.deallocate() }
    let repair = AudioRepairEngine()
    let ceiling: Float = -1.5
    let threshold = powf(10, ceiling / 20)
    repair.configureOutputSafety(limiterEnabled: true, ceilingDB: ceiling, outputGainDB: 6)
    data.update(repeating: 0, count: samples)
    repair.process(data, frameCount: frames, channelCount: 2, sampleRate: 48_000)
    var overshoots = 0
    stressControl({
        repair.configureOutputSafety(limiterEnabled: true, ceilingDB: ceiling, outputGainDB: 6)
        _ = repair.repairStats
        _ = repair.outputGainDB
    }, render: {
        for _ in 0..<4_000 {
            for index in 0..<samples { data[index] = (index / 2).isMultiple(of: 2) ? 0.97 : -0.97 }
            repair.process(data, frameCount: frames, channelCount: 2, sampleRate: 48_000)
            for index in 0..<samples {
                require(data[index].isFinite, "Non-finite limiter output")
                if abs(data[index]) > threshold + 0.000_01 { overshoots += 1 }
            }
        }
    })
    require(overshoots == 0, "Limiter bypassed under contention: \(overshoots) samples above ceiling")
    repair.resetStats()
    require(repair.repairStats.totalFramesProcessed == 0, "Statistics reset must be visible before another callback")
    repair.process(data, frameCount: frames, channelCount: 2, sampleRate: 48_000)
    require(repair.repairStats.totalFramesProcessed == Int64(frames), "Statistics did not resume from reset")
    print("PASS limiter contention: 0 samples above \(ceiling) dBFS ceiling")
}

func testLimiterReleaseContinuity() {
    let blockPatterns = [[128], [512], [1024], [2048], [4096], [17, 128, 511, 1024, 37, 4096]]
    let data = UnsafeMutablePointer<Float>.allocate(capacity: 4096 * 2)
    defer { data.deallocate() }
    var maximumBoundaryStep: Float = 0
    var maximumReferenceError: Float = 0

    for rate in [44_100, 48_000, 96_000] {
        for channels in [1, 2] {
            for pattern in blockPatterns {
                let repair = AudioRepairEngine()
                repair.isSoftLimiterEnabled = true
                repair.limiterThreshold = 0.8
                // A one-frame peak sets the gain to 0.4 without involving
                // other repair stages or the inter-sample peak detector.
                data.update(repeating: 2, count: channels)
                repair.process(data, frameCount: 1, channelCount: channels, sampleRate: rate)

                let totalFrames = rate * 5 / 2
                var renderedFrames = 0
                var block = 0
                var previous: Float = 0.2 * 0.4
                let maximumStep = Float(0.2 * 0.6 * (1 - exp(-1 / (Double(rate) * 0.12))))
                while renderedFrames < totalFrames {
                    let frames = min(pattern[block % pattern.count], totalFrames - renderedFrames)
                    for frame in 0..<frames {
                        data[frame * channels] = 0.2
                        if channels == 2 { data[frame * channels + 1] = -0.1 }
                    }
                    repair.process(data, frameCount: frames, channelCount: channels, sampleRate: rate)
                    for frame in 0..<frames {
                        let value = data[frame * channels]
                        let step = value - previous
                        let elapsed = Double(renderedFrames + frame + 1) / Double(rate)
                        let expected = Float(0.2 * (1 - 0.6 * exp(-elapsed / 0.12)))
                        let error = abs(value - expected)
                        maximumReferenceError = max(maximumReferenceError, error)
                        if frame == 0 { maximumBoundaryStep = max(maximumBoundaryStep, abs(step)) }
                        require(value.isFinite && step >= -0.000_000_1, "Limiter release reversed or became non-finite")
                        require(step <= maximumStep + 0.000_000_1, "Limiter release jumped: rate=\(rate), frames=\(frames), frame=\(frame), step=\(step)")
                        require(error < 0.000_000_2, "Limiter release depends on callback boundaries: \(error)")
                        if channels == 2 {
                            require(data[frame * channels + 1] == -value * 0.5, "Limiter release changed stereo balance")
                        }
                        previous = value
                    }
                    renderedFrames += frames
                    block += 1
                }
                require(previous == 0.2, "Limiter release failed to return to unity")
            }
        }
    }
    print("PASS limiter release: fixed/variable blocks, mono/stereo, 44.1/48/96 kHz; max boundary step \(maximumBoundaryStep), reference error \(maximumReferenceError)")
}

func testLimiterReleaseRetrigger() {
    let frames = 512
    let data = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
    defer { data.deallocate() }
    let repair = AudioRepairEngine()
    repair.isSoftLimiterEnabled = true
    repair.limiterThreshold = 0.8
    for block in 0..<120 {
        data.update(repeating: 0.2, count: frames * 2)
        if block.isMultiple(of: 10) {
            // A peak in either channel must retain the existing output ceiling
            // even when it interrupts a release at a different frame position.
            let peakFrame = [0, frames / 2, frames - 1][(block / 10) % 3]
            data[peakFrame * 2 + (block / 10) % 2] = block.isMultiple(of: 20) ? 2 : -2
        }
        repair.process(data, frameCount: frames, channelCount: 2, sampleRate: 48_000)
        for index in 0..<(frames * 2) {
            require(data[index].isFinite && abs(data[index]) <= 0.800_001, "Retriggered limiter exceeded its ceiling")
        }
    }
    print("PASS limiter retrigger: repeated positive/negative stereo peaks remain below ceiling")
}

func testGainRampToNeutral() {
    let frames = 128
    let data = UnsafeMutablePointer<Float>.allocate(capacity: frames)
    defer { data.deallocate() }
    let repair = AudioRepairEngine()
    repair.outputGainDB = -6
    for _ in 0..<200 {
        data.update(repeating: 0.2, count: frames)
        repair.process(data, frameCount: frames, channelCount: 1, sampleRate: 48_000)
    }
    var previous = data[frames - 1]
    require(abs(previous - 0.2 * powf(10, -6 / 20)) < 0.000_01, "Initial gain did not settle")
    repair.outputGainDB = 0
    for _ in 0..<200 {
        data.update(repeating: 0.2, count: frames)
        repair.process(data, frameCount: frames, channelCount: 1, sampleRate: 48_000)
        for index in 0..<frames {
            require(abs(data[index] - previous) < 0.000_1, "Gain jumped while returning to neutral")
            previous = data[index]
        }
    }
    require(abs(previous - 0.2) < 0.000_01, "Neutral target prevented the final ramp from completing")
    print("PASS output gain ramp: continuous through return to neutral")
}

func testPlanAndFormatChanges() {
    let frames = 128
    let data = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
    defer { data.deallocate() }
    let eq = EQFilter()
    var bands = [ParametricEQBand(frequency: 700, gainDB: -2), ParametricEQBand(frequency: 3_000, gainDB: 1)]
    for rate in [44_100, 48_000, 96_000] {
        for mode in [GraphicEQMode.tenBand, .thirtyTwoBand] {
            eq.setGraphicMode(mode, gains: Array(repeating: 1, count: mode.bandCount))
            eq.setCalibrationGains(Array(repeating: -0.5, count: mode.bandCount))
            eq.setHearingCorrection(left: [1, 0, -1], right: [-1, 0, 1])
            eq.setPreampDB(-6)
            eq.setDynamicEQ(enabled: true, bands: DynamicEQBand.monoDefaults)
            eq.setMonoEnhance(MonoEnhanceConfiguration(isEnabled: true, vocalFocus: 0.2, stageWidth: 0.6))
            for iteration in 0..<80 {
                // Reordering/replacing PEQ bands must preserve matched history
                // and safely recycle removed runtime slots.
                bands.reverse()
                if iteration.isMultiple(of: 3) { bands[0] = ParametricEQBand(frequency: 700, gainDB: -2) }
                eq.setParametricBands(iteration.isMultiple(of: 7) ? [] : bands)
                for channels in [1, 2] {
                    for index in 0..<(frames * channels) { data[index] = 0.1 * sinf(Float(index) * 0.1) }
                    let buffer = AudioBuffer(data: data, frameCount: frames, channelCount: channels, sampleRate: rate)
                    let result = eq.process(buffer)
                    require(result.frameCount == frames && result.channelCount == channels, "DSP changed PCM shape")
                    for index in 0..<(frames * channels) {
                        require(data[index].isFinite && abs(data[index]) < 1, "Invalid output after plan/format switch")
                    }
                }
            }
            require(eq.currentGraphicMode() == mode && eq.currentGraphicGains().count == mode.bandCount, "Control state is stale")
        }
    }
    eq.reset()
    require(eq.currentGraphicGains().allSatisfy { $0 == 0 }, "Reset did not clear control gains")
    print("PASS plan/format changes: 10/32 bands, mono/stereo, 44.1/48/96 kHz")
}

func testEffectTransition() {
    let frames = 16
    let dry = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
    let wet = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
    defer { dry.deallocate(); wet.deallocate() }
    dry.update(repeating: 0.1, count: frames * 2)
    wet.update(repeating: 0.5, count: frames * 2)
    let remaining = AudioEffectTransition.mix(
        wetData: wet, dryData: dry, wetFrameCount: frames, dryFrameCount: frames,
        wetChannelCount: 2, dryChannelCount: 2, durationFrames: 12, remainingFrames: 4, fadingIn: false
    )
    require(remaining == 0, "Fade-out did not finish")
    for index in 8..<(frames * 2) { require(wet[index] == dry[index], "Old effect returned after fade-out") }
    wet.update(repeating: 0.5, count: frames * 2)
    let fadeInRemaining = AudioEffectTransition.mix(
        wetData: wet, dryData: dry, wetFrameCount: frames, dryFrameCount: frames,
        wetChannelCount: 2, dryChannelCount: 2, durationFrames: 12, remainingFrames: 4, fadingIn: true
    )
    require(fadeInRemaining == 0 && wet[frames * 2 - 1] == 0.5, "Fade-in lost the fully wet tail")
    print("PASS fade-in/out: exact final mix through the end of a block")
}

testConfigurationContention()
testEQCoefficientContinuity()
testDynamicEQContinuity()
testEQLayoutContinuity()
testEQLayoutLatestUpdate()
testLimiterReleaseContinuity()
testLimiterReleaseRetrigger()
testEQContention(mode: .tenBand, channels: 1)
testEQContention(mode: .thirtyTwoBand, channels: 2)
testLimiterContention()
testGainRampToNeutral()
testPlanAndFormatChanges()
testEffectTransition()
