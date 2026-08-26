import CryptoKit
import Foundation
@preconcurrency import Combine
@preconcurrency import MetricKit

struct CrashDiagnosticRecord: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let receivedAt: Date
    let periodStart: Date
    let periodEnd: Date
    let appVersion: String
    let terminationReason: String?
    let exceptionType: String?
    let exceptionCode: String?
    let signal: Int?
    let diagnosticJSON: String

    var exportText: String {
        """
        Mono Crash Diagnostic
        receivedAt=\(receivedAt.formatted(.iso8601))
        periodStart=\(periodStart.formatted(.iso8601))
        periodEnd=\(periodEnd.formatted(.iso8601))
        appVersion=\(appVersion)
        terminationReason=\(terminationReason ?? "unavailable")
        exceptionType=\(exceptionType ?? "unavailable")
        exceptionCode=\(exceptionCode ?? "unavailable")
        signal=\(signal.map(String.init) ?? "unavailable")

        \(diagnosticJSON)
        """
    }
}

private struct CrashDiagnosticsArchive: Codable, Sendable {
    let version: Int
    let records: [CrashDiagnosticRecord]
    let dismissedIDs: [String]
}

private actor CrashDiagnosticsPersistence {
    private var latestRevision: UInt64 = 0

    func save(_ archive: CrashDiagnosticsArchive, to url: URL, revision: UInt64) {
        guard revision >= latestRevision else { return }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(archive)
            try data.write(to: url, options: .atomic)
            latestRevision = revision
        } catch {
            AppLogger.error(
                "[CrashDiagnostics] Failed to persist diagnostics: \(error.localizedDescription)",
                category: .app,
                event: "crash_diagnostics_persist_failed"
            )
        }
    }
}

@MainActor
final class CrashDiagnosticsStore: NSObject, ObservableObject {
    static let shared = CrashDiagnosticsStore()

    @Published private(set) var records: [CrashDiagnosticRecord]

    private static let maximumRecords = 30
    private static let maximumDismissedIDs = 120
    private let storageURL: URL?
    private let persistence = CrashDiagnosticsPersistence()
    private var persistenceRevision: UInt64 = 0
    private var persistenceTask: Task<Void, Never>?
    private var isStarted = false
    private var dismissedIDs: [String]

    private override init() {
        let url = Self.makeStorageURL()
        let archive = Self.loadArchive(from: url)
        storageURL = url
        records = Array(
            archive.records
                .sorted { $0.periodEnd > $1.periodEnd }
                .prefix(Self.maximumRecords)
        )
        dismissedIDs = Array(archive.dismissedIDs.suffix(Self.maximumDismissedIDs))
        super.init()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        let manager = MXMetricManager.shared
        manager.add(self)
        DispatchQueue.global(qos: .utility).async {
            let records = Self.makeRecords(from: MXMetricManager.shared.pastDiagnosticPayloads)
            Task { @MainActor in
                CrashDiagnosticsStore.shared.ingest(records)
            }
        }
    }

    func clear() {
        guard !records.isEmpty else { return }
        dismissedIDs = Self.appendingUniqueIDs(
            records.map(\.id),
            to: dismissedIDs,
            limit: Self.maximumDismissedIDs
        )
        records = []
        persist()
    }

    func exportURL(for record: CrashDiagnosticRecord) -> URL? {
        writeExport(
            record.exportText,
            fileName: "mono-crash-\(record.id.prefix(12)).log"
        )
    }

    func exportAllURL() -> URL? {
        guard !records.isEmpty else { return nil }
        let text = records.map(\.exportText).joined(separator: "\n\n---\n\n")
        return writeExport(text, fileName: "mono-crash-diagnostics.log")
    }

    fileprivate func ingest(_ candidates: [CrashDiagnosticRecord]) {
        guard !candidates.isEmpty else { return }
        let knownIDs = Set(records.map(\.id)).union(dismissedIDs)
        var imported: [CrashDiagnosticRecord] = []
        for record in candidates where !knownIDs.contains(record.id) {
            if !imported.contains(where: { $0.id == record.id }) {
                imported.append(record)
            }
        }

        guard !imported.isEmpty else { return }
        let merged = (records + imported).sorted { $0.periodEnd > $1.periodEnd }
        let retained = Array(merged.prefix(Self.maximumRecords))
        let retainedIDs = Set(retained.map(\.id))
        let displacedIDs = merged.lazy.map(\.id).filter { !retainedIDs.contains($0) }
        dismissedIDs = Self.appendingUniqueIDs(
            displacedIDs,
            to: dismissedIDs,
            limit: Self.maximumDismissedIDs
        )
        records = retained
        persist()

        AppLogger.info(
            "[CrashDiagnostics] Imported \(imported.count) crash diagnostics",
            category: .app,
            event: "crash_diagnostics_imported",
            context: ["count": String(imported.count)]
        )
    }

    private nonisolated static func makeRecords(
        from payloads: [MXDiagnosticPayload]
    ) -> [CrashDiagnosticRecord] {
        payloads.flatMap { payload in
            (payload.crashDiagnostics ?? []).compactMap { diagnostic in
                makeRecord(diagnostic, payload: payload)
            }
        }
    }

    private nonisolated static func makeRecord(
        _ diagnostic: MXCrashDiagnostic,
        payload: MXDiagnosticPayload
    ) -> CrashDiagnosticRecord? {
        let data = diagnostic.jsonRepresentation()
        guard let diagnosticJSON = prettyJSONString(from: data) else { return nil }

        let fingerprintSource = """
        \(payload.timeStampBegin.timeIntervalSince1970)
        \(payload.timeStampEnd.timeIntervalSince1970)
        \(diagnostic.applicationVersion)
        \(diagnosticJSON)
        """
        let fingerprint = SHA256.hash(data: Data(fingerprintSource.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        return CrashDiagnosticRecord(
            id: fingerprint,
            receivedAt: Date(),
            periodStart: payload.timeStampBegin,
            periodEnd: payload.timeStampEnd,
            appVersion: diagnostic.applicationVersion,
            terminationReason: diagnostic.terminationReason,
            exceptionType: diagnostic.exceptionType?.stringValue,
            exceptionCode: diagnostic.exceptionCode?.stringValue,
            signal: diagnostic.signal?.intValue,
            diagnosticJSON: diagnosticJSON
        )
    }

    private func persist() {
        guard let storageURL else { return }
        persistenceRevision &+= 1
        let revision = persistenceRevision
        let archive = CrashDiagnosticsArchive(
            version: 1,
            records: records,
            dismissedIDs: dismissedIDs
        )
        persistenceTask?.cancel()
        persistenceTask = Task {
            await persistence.save(archive, to: storageURL, revision: revision)
        }
    }

    private func writeExport(_ text: String, fileName: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            AppLogger.error(
                "[CrashDiagnostics] Failed to write export: \(error.localizedDescription)",
                category: .app,
                event: "crash_diagnostics_export_failed"
            )
            return nil
        }
    }

    private static func loadArchive(from url: URL?) -> CrashDiagnosticsArchive {
        let empty = CrashDiagnosticsArchive(version: 1, records: [], dismissedIDs: [])
        guard let url, let data = try? Data(contentsOf: url) else { return empty }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CrashDiagnosticsArchive.self, from: data)
        } catch {
            AppLogger.error(
                "[CrashDiagnostics] Failed to load diagnostics: \(error.localizedDescription)",
                category: .app,
                event: "crash_diagnostics_load_failed"
            )
            return empty
        }
    }

    private static func appendingUniqueIDs<S: Sequence>(
        _ identifiers: S,
        to existing: [String],
        limit: Int
    ) -> [String] where S.Element == String {
        Array(
            (existing + Array(identifiers))
                .reduce(into: [String]()) { result, identifier in
                    if !result.contains(identifier) {
                        result.append(identifier)
                    }
                }
                .suffix(limit)
        )
    }

    private nonisolated static func prettyJSONString(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
              ) else {
            return String(data: data, encoding: .utf8)
        }
        return String(data: prettyData, encoding: .utf8)
    }

    private static func makeStorageURL() -> URL? {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }

        let directory = applicationSupport
            .appendingPathComponent("Mono", isDirectory: true)
            .appendingPathComponent("Diagnostics", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            return directory.appendingPathComponent("crash-diagnostics-v1.json")
        } catch {
            AppLogger.error(
                "[CrashDiagnostics] Storage directory unavailable: \(error.localizedDescription)",
                category: .app,
                event: "crash_diagnostics_storage_failed"
            )
            return nil
        }
    }
}

extension CrashDiagnosticsStore: MXMetricManagerSubscriber {
    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let records = Self.makeRecords(from: payloads)
        Task { @MainActor in
            CrashDiagnosticsStore.shared.ingest(records)
        }
    }
}
