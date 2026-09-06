import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let data = UnsafeMutablePointer<Float>.allocate(capacity: 4096 * 2)
defer { data.deallocate() }

func render(_ graph: AudioFilterGraph, rate: Int = 48_000, channels: Int = 2, frames: Int = 512) -> Float {
    data.update(repeating: 0.1, count: frames * channels)
    let output = graph.process(AudioBuffer(data: data, frameCount: frames, channelCount: channels, sampleRate: rate))
    require(output.frameCount == frames && output.channelCount == channels && output.sampleRate == rate, "Graph changed the PCM format")
    for index in 0..<(frames * channels) {
        require(output.data[index].isFinite, "Graph emitted non-finite samples")
    }
    return output.data[0]
}

func awaitOutput(_ graph: AudioFilterGraph, expected: Float, rate: Int = 48_000, channels: Int = 2) {
    let deadline = Date().addingTimeInterval(10)
    var stable = 0
    while Date() < deadline {
        let output = render(graph, rate: rate, channels: channels)
        if graph.isReadyForDiagnostics(sampleRate: rate, channelCount: channels), abs(output - expected) < 0.000_5 {
            stable += 1
            if stable == 10 { return }
        } else {
            stable = 0
        }
        // Only the test driver yields to the independent rebuild worker.
        Thread.sleep(forTimeInterval: 0.001)
    }
    fatalError("Prepared graph failed to converge to \(expected) at \(rate) Hz / \(channels) channels")
}

let graph = AudioFilterGraph()
graph.setBassGain(6)
awaitOutput(graph, expected: 0.1 * powf(10, 6 / 20))
for _ in 0..<1000 {
    require(render(graph) > 0.18, "Uncontended graph bypassed the bass stage")
}
let started = DispatchSemaphore(value: 0)
let stop = DispatchSemaphore(value: 0)
let finished = DispatchGroup()
finished.enter()
DispatchQueue.global().async {
    started.signal()
    while stop.wait(timeout: .now()) == .timedOut { graph.setBassGain(6) }
    finished.leave()
}
require(started.wait(timeout: .now() + 5) == .success, "Control worker did not start")
var bypassed = 0
for _ in 0..<10_000 {
    if render(graph) < 0.18 { bypassed += 1 }
}
stop.signal()
require(finished.wait(timeout: .now() + 5) == .success, "Control worker did not finish")
require(bypassed == 0, "Control contention bypassed \(bypassed) complete PCM blocks")
print("PASS prepared-graph contention: 0/10000 bypassed blocks")

// Superseded builds, pending handoffs and retired graphs must still make
// progress when commands arrive before the preceding handoff has finished.
for iteration in 0..<80 {
    if iteration.isMultiple(of: 7) { graph.reset() }
    graph.applyMonoTuning(.neutral, bassGain: Float(iteration % 9), trebleGain: 0,
                          surroundLevel: 0, reverbLevel: 0, stereoWidth: 1)
    _ = render(graph)
}
graph.setBassGain(3)
awaitOutput(graph, expected: 0.1 * powf(10, 3 / 20))
for (rate, channels) in [(96_000, 1), (44_100, 2), (48_000, 2)] {
    awaitOutput(graph, expected: 0.1 * powf(10, 3 / 20), rate: rate, channels: channels)
}
graph.reset()
awaitOutput(graph, expected: 0.1)
graph.setBassGain(6)
awaitOutput(graph, expected: 0.1 * powf(10, 6 / 20))
print("PASS graph replacement/reset/format changes: latest configuration applied, retired graphs handed back")
