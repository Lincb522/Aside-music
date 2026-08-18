import AVFoundation
import Foundation

private final class MonoMicrophoneSampleCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Float] = []
    private(set) var sampleRate: Double = 48_000

    init(capacity: Int = 480_000) {
        samples.reserveCapacity(capacity)
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        lock.lock()
        sampleRate = buffer.format.sampleRate
        if samples.count < 480_000 {
            samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: min(count, 480_000 - samples.count)))
        }
        lock.unlock()
    }

    func snapshot() -> (samples: [Float], sampleRate: Double) {
        lock.lock()
        defer { lock.unlock() }
        return (samples, sampleRate)
    }
}

struct MonoEnvironmentMeasurement: Codable, Sendable {
    let measuredAt: Date
    let noiseFloorDBFS: Float
    let bandLevelsDBFS: [Float]
    let suggestedMaskingCurve: [Float]
}

@MainActor
final class MonoListeningEnvironmentEngine: ObservableObject {
    static let shared = MonoListeningEnvironmentEngine()

    @Published private(set) var isMeasuring = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var measurement: MonoEnvironmentMeasurement?
    @Published private(set) var errorMessage: String?

    private let duration: TimeInterval = 8
    private var audioEngine: AVAudioEngine?
    private var collector: MonoMicrophoneSampleCollector?
    private var measurementTask: Task<Void, Never>?
    private let storeURL: URL

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = support.appendingPathComponent("MonoAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storeURL = directory.appendingPathComponent("environment-measurement-v1.json")
        if let data = try? Data(contentsOf: storeURL),
           let restored = try? JSONDecoder().decode(MonoEnvironmentMeasurement.self, from: data) {
            measurement = restored
        }
    }

    func start() {
        guard !isMeasuring else { return }
        let permission: @Sendable (Bool) -> Void = { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                if granted {
                    self.beginCapture()
                } else {
                    self.errorMessage = String(localized: "sound_environment_microphone_denied")
                }
            }
        }
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: permission)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(permission)
        }
    }

    func cancel() {
        finishCapture(analyze: false)
    }

    func applySuggestion() {
        guard let measurement else { return }
        EQManager.shared.installEnvironmentCompensation(measurement.suggestedMaskingCurve)
    }

    func clearMeasurement() {
        guard !isMeasuring else { return }
        measurement = nil
        EQManager.shared.clearEnvironmentCompensation()
        try? FileManager.default.removeItem(at: storeURL)
    }

    private func beginCapture() {
        errorMessage = nil
        progress = 0
        isMeasuring = true
        measurementTask?.cancel()
        measurementTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let activated = await PlayerManager.shared.activateAudioSessionForRecording(
                reason: "listening environment measurement"
            )
            guard !Task.isCancelled, activated else {
                self.errorMessage = String(localized: "sound_environment_start_failed")
                self.finishCapture(analyze: false)
                return
            }
            do {
                let engine = AVAudioEngine()
                let collector = MonoMicrophoneSampleCollector()
                self.audioEngine = engine
                self.collector = collector
                engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { buffer, _ in
                    collector.append(buffer)
                }
                try engine.start()
                let started = Date()
                while !Task.isCancelled {
                    let elapsed = Date().timeIntervalSince(started)
                    self.progress = min(1, elapsed / self.duration)
                    if elapsed >= self.duration { break }
                    try? await Task.sleep(for: .milliseconds(100))
                }
                self.finishCapture(analyze: !Task.isCancelled)
            } catch {
                self.errorMessage = error.localizedDescription
                self.finishCapture(analyze: false)
            }
        }
    }

    private func finishCapture(analyze: Bool) {
        measurementTask?.cancel()
        measurementTask = nil
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        let snapshot = collector?.snapshot()
        collector = nil
        isMeasuring = false
        progress = analyze ? 1 : 0
        PlayerManager.shared.lastAppliedAudioSessionOptions = nil
        PlayerManager.shared.reapplyAudioSessionOptions(reason: "listening environment measurement finished")

        guard analyze, let snapshot, snapshot.samples.count >= 8_192 else { return }
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Self.analyze(samples: snapshot.samples, sampleRate: snapshot.sampleRate)
            }.value
            guard let self else { return }
            self.measurement = result
            self.persist(result)
        }
    }

    private func persist(_ value: MonoEnvironmentMeasurement) {
        let url = storeURL
        Task.detached(priority: .utility) {
            guard let data = try? JSONEncoder().encode(value) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    private nonisolated static func analyze(samples: [Float], sampleRate: Double) -> MonoEnvironmentMeasurement {
        let sanitized = samples.filter(\.isFinite)
        let meanSquare = sanitized.reduce(Double(0)) { $0 + Double($1 * $1) }
            / Double(max(sanitized.count, 1))
        let noiseFloor = Float(20 * log10(max(sqrt(meanSquare), 0.000_1)))
        let centers: [Double] = [31.25, 62.5, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
        let windowCount = min(sanitized.count, 65_536)
        let window = Array(sanitized.suffix(windowCount))
        let levels = centers.map { center in
            goertzelLevel(samples: window, sampleRate: sampleRate, frequency: min(center, sampleRate * 0.45))
        }
        let valid = levels.filter { $0.isFinite }
        let median = valid.sorted().dropFirst(valid.count / 2).first ?? noiseFloor
        let curve = levels.map { level -> Float in
            // Attenuate bands currently masked by ambient energy. Never boost a
            // noisy room and keep the laboratory suggestion deliberately mild.
            min(0, max(-3, -(level - median) * 0.22))
        }
        return MonoEnvironmentMeasurement(
            measuredAt: Date(),
            noiseFloorDBFS: noiseFloor,
            bandLevelsDBFS: levels,
            suggestedMaskingCurve: curve
        )
    }

    private nonisolated static func goertzelLevel(
        samples: [Float],
        sampleRate: Double,
        frequency: Double
    ) -> Float {
        guard samples.isEmpty == false, sampleRate > 0 else { return -80 }
        let omega = 2 * Double.pi * frequency / sampleRate
        let coefficient = 2 * cos(omega)
        var previous = 0.0
        var previous2 = 0.0
        let denominator = Double(max(samples.count - 1, 1))
        for (index, sample) in samples.enumerated() {
            let hann = 0.5 - 0.5 * cos(2 * Double.pi * Double(index) / denominator)
            let current = Double(sample) * hann + coefficient * previous - previous2
            previous2 = previous
            previous = current
        }
        let power = previous2 * previous2 + previous * previous - coefficient * previous * previous2
        let amplitude = sqrt(max(power, 0)) / Double(max(samples.count, 1)) * 2
        return Float(20 * log10(max(amplitude, 0.000_1)))
    }
}
