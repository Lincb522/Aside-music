import Combine
import Foundation

enum MonoLoudnessMode: String, CaseIterable, Codable, Identifiable {
    case track
    case album

    var id: String { rawValue }
}

struct MonoLoudnessRecord: Codable, Identifiable, Sendable {
    let id: String
    let albumKey: String
    let measuredAt: Date
    let integratedLUFS: Float
    let shortTermLUFS: Float
    let momentaryLUFS: Float
    let loudnessRangeLU: Float
    let truePeakDBTP: Float
    let samplePeakDBFS: Float
    let duration: Double
}

@MainActor
final class MonoLoudnessEngine: ObservableObject {
    static let shared = MonoLoudnessEngine()

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: enabledKey)
            applyCurrentRecord()
        }
    }
    @Published var mode: MonoLoudnessMode {
        didSet {
            defaults.set(mode.rawValue, forKey: modeKey)
            applyCurrentRecord()
        }
    }
    @Published var targetLUFS: Float {
        didSet {
            let clamped = min(-10, max(-20, targetLUFS))
            if abs(clamped - targetLUFS) > 0.001 {
                targetLUFS = clamped
                return
            }
            defaults.set(targetLUFS, forKey: targetKey)
            applyCurrentRecord()
        }
    }
    @Published private(set) var currentRecord: MonoLoudnessRecord?
    @Published private(set) var appliedGainDB: Float = 0
    @Published private(set) var recordCount = 0

    private let defaults = UserDefaults.standard
    private let enabledKey = "mono.loudness.enabled"
    private let modeKey = "mono.loudness.mode"
    private let targetKey = "mono.loudness.target-lufs"
    private let storeURL: URL
    private var records: [String: MonoLoudnessRecord] = [:]
    private var cancellables = Set<AnyCancellable>()

    private init() {
        isEnabled = defaults.object(forKey: enabledKey) as? Bool ?? false
        mode = MonoLoudnessMode(rawValue: defaults.string(forKey: modeKey) ?? "") ?? .track
        let storedTarget = defaults.object(forKey: targetKey) as? NSNumber
        targetLUFS = storedTarget?.floatValue ?? -14

        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = support.appendingPathComponent("MonoAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storeURL = directory.appendingPathComponent("loudness-records-v1.json")
        restore()
        installObservers()
    }

    func record(for song: Song) -> MonoLoudnessRecord? {
        records[Self.trackKey(song)]
    }

    func removeAllRecords() {
        records.removeAll()
        recordCount = 0
        currentRecord = nil
        appliedGainDB = 0
        EQManager.shared.setTrackLoudnessGainDB(0)
        persist()
    }

    private func installObservers() {
        PlayerManager.shared.$currentSong
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyCurrentRecord() }
            .store(in: &cancellables)

        AIEqualizerAgent.shared.$measuredFeatures
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] features in
                self?.ingest(features)
            }
            .store(in: &cancellables)
    }

    private func ingest(_ features: AIEqualizerAudioFeatures) {
        guard let song = PlayerManager.shared.currentSong,
              song.id == features.songID,
              features.integratedLUFS.isFinite,
              (-70 ... 0).contains(features.integratedLUFS) else { return }
        let record = MonoLoudnessRecord(
            id: Self.trackKey(song),
            albumKey: Self.albumKey(song),
            measuredAt: Date(),
            integratedLUFS: features.integratedLUFS,
            shortTermLUFS: features.shortTermLUFS,
            momentaryLUFS: features.momentaryLUFS,
            loudnessRangeLU: max(0, features.loudnessRangeLU),
            truePeakDBTP: min(6, features.estimatedTruePeakDBTP),
            samplePeakDBFS: min(0, features.samplePeakDBFS),
            duration: max(0, features.sampleDuration)
        )
        records[record.id] = record
        trimIfNeeded()
        recordCount = records.count
        persist()
        applyCurrentRecord()
    }

    private func applyCurrentRecord() {
        guard let song = PlayerManager.shared.currentSong else {
            currentRecord = nil
            appliedGainDB = 0
            EQManager.shared.setTrackLoudnessGainDB(0)
            return
        }
        let record = records[Self.trackKey(song)]
        currentRecord = record
        guard isEnabled, let record else {
            appliedGainDB = 0
            EQManager.shared.setTrackLoudnessGainDB(0)
            return
        }

        let referenceLUFS: Float
        if mode == .album {
            let albumRecords = records.values.filter { $0.albumKey == record.albumKey }
            let weighted = albumRecords.reduce(into: (energy: Float(0), duration: Float(0))) { result, item in
                let duration = Float(max(1, item.duration))
                result.energy += powf(10, item.integratedLUFS / 10) * duration
                result.duration += duration
            }
            referenceLUFS = weighted.duration > 0
                ? 10 * log10f(max(0.000_000_1, weighted.energy / weighted.duration))
                : record.integratedLUFS
        } else {
            referenceLUFS = record.integratedLUFS
        }

        let requested = targetLUFS - referenceLUFS
        let truePeakCeiling: Float = -1
        let peakSafeGain = truePeakCeiling - record.truePeakDBTP
        let safeGain = min(6, max(-12, min(requested, peakSafeGain)))
        appliedGainDB = safeGain.isFinite ? safeGain : 0
        EQManager.shared.setTrackLoudnessGainDB(appliedGainDB)
    }

    private func restore() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([String: MonoLoudnessRecord].self, from: data) else { return }
        records = decoded
        recordCount = decoded.count
    }

    private func persist() {
        let snapshot = records
        let url = storeURL
        Task.detached(priority: .utility) {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    private func trimIfNeeded() {
        let maximum = 6_000
        guard records.count > maximum else { return }
        let keep = records.values.sorted { $0.measuredAt > $1.measuredAt }.prefix(maximum)
        records = Dictionary(uniqueKeysWithValues: keep.map { ($0.id, $0) })
    }

    private static func trackKey(_ song: Song) -> String {
        "\(song.musicSource.rawValue):\(song.id)"
    }

    private static func albumKey(_ song: Song) -> String {
        if let album = song.album {
            return "\(song.musicSource.rawValue):album:\(album.id):\(album.name)"
        }
        return "\(song.musicSource.rawValue):single:\(song.id)"
    }
}
