import Foundation
@preconcurrency import Combine
import FFmpegSwiftSDK
import UIKit

struct AIEqualizerLearningSongMetadata: Sendable {
    let title: String
    let artist: String
}

struct AIEqualizerMeasuredFeatureRecord: Codable, Sendable {
    let schemaVersion: Int
    let songIdentifier: String
    let audioVariant: String
    let outputIdentity: String
    let graphicEQMode: GraphicEQMode
    let capturedAt: Date
    let features: AIEqualizerAudioFeatures

    var storageKey: String {
        "\(schemaVersion)|\(songIdentifier)|\(audioVariant)|\(outputIdentity)|\(graphicEQMode.rawValue)"
    }
}

@MainActor
final class AIEqualizerMeasurementStore {
    private static let schemaVersion = 3
    private static let fileName = "AIEqualizerMeasurements-v3.json"
    private static let maximumEntries = 2_048

    private let storageURL: URL?
    private var records: [String: AIEqualizerMeasuredFeatureRecord]

    init() {
        storageURL = Self.makeStorageURL()
        if let storageURL,
           let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode(
               [String: LossyDecodable<AIEqualizerMeasuredFeatureRecord>].self,
               from: data
           ) {
            records = decoded.compactMapValues(\.value)
        } else {
            records = [:]
        }
        removeInvalidRecords(persistChanges: true)
    }

    var learningSongMetadata: [String: AIEqualizerLearningSongMetadata] {
        var metadata: [String: AIEqualizerLearningSongMetadata] = [:]
        for record in records.values.sorted(by: { $0.capturedAt < $1.capturedAt }) {
            let title = record.features.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            metadata[record.songIdentifier] = AIEqualizerLearningSongMetadata(
                title: title,
                artist: record.features.artist
            )
        }
        return metadata
    }

    func value(
        songIdentifier: String,
        audioVariant: String,
        outputIdentity: String,
        graphicEQMode: GraphicEQMode
    ) -> AIEqualizerAudioFeatures? {
        removeInvalidRecords(persistChanges: true)
        let compatible = records.values.filter {
            $0.schemaVersion == Self.schemaVersion
                && $0.songIdentifier == songIdentifier
                && $0.outputIdentity == outputIdentity
                && $0.graphicEQMode == graphicEQMode
        }
        let exact = compatible
            .filter { $0.audioVariant == audioVariant }
            .max { $0.capturedAt < $1.capturedAt }
        let selected = exact ?? compatible.max { $0.capturedAt < $1.capturedAt }
        guard let selected else { return nil }
        AppLogger.info(
            "[AIEqualizerAgent] Measurement restored song=\(songIdentifier) exactVariant=\(exact != nil) output=\(outputIdentity) mode=\(graphicEQMode.rawValue) capturedAt=\(selected.capturedAt.timeIntervalSince1970)",
            step: "ai-tuning.measurement-restored"
        )
        return selected.features
    }

    func set(
        _ features: AIEqualizerAudioFeatures,
        songIdentifier: String,
        audioVariant: String,
        outputIdentity: String,
        now: Date = Date()
    ) {
        let record = AIEqualizerMeasuredFeatureRecord(
            schemaVersion: Self.schemaVersion,
            songIdentifier: songIdentifier,
            audioVariant: audioVariant,
            outputIdentity: outputIdentity,
            graphicEQMode: features.graphicEQMode,
            capturedAt: now,
            features: features
        )
        records[record.storageKey] = record
        removeInvalidRecords(persistChanges: false)
        if records.count > Self.maximumEntries {
            records = Dictionary(
                uniqueKeysWithValues: records.values
                    .sorted { $0.capturedAt > $1.capturedAt }
                    .prefix(Self.maximumEntries)
                    .map { ($0.storageKey, $0) }
            )
        }
        persist()
    }

    private func removeInvalidRecords(persistChanges: Bool) {
        let previousCount = records.count
        records = records.filter {
            $0.value.schemaVersion == Self.schemaVersion
        }
        if records.count > Self.maximumEntries {
            records = Dictionary(
                uniqueKeysWithValues: records.values
                    .sorted { $0.capturedAt > $1.capturedAt }
                    .prefix(Self.maximumEntries)
                    .map { ($0.storageKey, $0) }
            )
        }
        if persistChanges, records.count != previousCount {
            persist()
        }
    }

    private func persist() {
        guard let storageURL else {
            AppLogger.error(
                "[AIEqualizerAgent] Measurement persistence skipped because storage URL is unavailable",
                step: "ai-tuning.measurement-save-failed"
            )
            return
        }
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            AppLogger.error(
                "[AIEqualizerAgent] Measurement persistence failed entries=\(records.count) error=\(error.localizedDescription)",
                step: "ai-tuning.measurement-save-failed"
            )
        }
    }

    private static func makeStorageURL() -> URL? {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let directory = applicationSupport.appendingPathComponent(
            "Mono",
            isDirectory: true
        )
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            return directory.appendingPathComponent(fileName, isDirectory: false)
        } catch {
            AppLogger.error(
                "[AIEqualizerAgent] Measurement storage directory unavailable error=\(error.localizedDescription)",
                step: "ai-tuning.measurement-storage-failed"
            )
            return nil
        }
    }
}
