import Combine
import Foundation
import UIKit

/// Ships complete tuning samples to the cloud training intake shortly after
/// they are produced, independently of the full playlist snapshot sync (which
/// runs at most three times a day and only when playlist auto-sync is on).
///
/// Uploads are batched (≤16 per request), retried with back-off, and each
/// sample is re-sent only when its outcome changed since the last upload.
@MainActor
final class AITrainingSampleUploader {
    static let shared = AITrainingSampleUploader()

    private static let batchSize = 16
    private static let maximumBatchesPerFlush = 4
    private static let debounceInterval: TimeInterval = 20
    private static let backoffIntervals: [TimeInterval] = [60, 300, 1_800, 7_200]
    private static let permanentRejectionReasons: Set<String> = [
        "INVALID_SAMPLE", "INVALID_ID", "UNSUPPORTED_SCHEMA", "MISSING_FEATURES_OR_TARGET",
        "TARGET_ID_MISMATCH", "INVALID_BAND_ENERGY", "INVALID_TARGET_GAINS", "TARGET_NOT_VALIDATED",
        "SELF_GENERATED", "INVALID_POPULATIONTARGET", "INVALID_PERSONALIZEDTARGET", "INVALID_FEEDBACK",
        "INVALID_MANUAL_GAINS", "SAMPLE_TOO_LARGE"
    ]
    /// Samples retained locally after they reached the cloud; older uploaded
    /// samples are pruned so the device store does not grow without bound.
    private static let localRetentionLimit = 200

    private(set) var pendingIDs: Set<String>
    /// Sample id → outcome stamp (outcomeUpdatedAt or capturedAt) last accepted
    /// by the server. A sample whose stamp is unchanged is not re-sent.
    private var uploadedStamps: [String: String]
    private var flushTask: Task<Void, Never>?
    private var isFlushing = false
    private var consecutiveFailures = 0
    private var nextRetryAt: Date?
    private var cancellables: Set<AnyCancellable> = []
    private weak var sampleSource: AIEqualizerProposalCacheStore?

    private init() {
        let defaults = UserDefaults.standard
        pendingIDs = Set(defaults.stringArray(forKey: AppConfig.StorageKeys.trainingSampleUploadPending) ?? [])
        uploadedStamps = defaults.dictionary(forKey: AppConfig.StorageKeys.trainingSampleUploadStamps) as? [String: String] ?? [:]
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.scheduleFlush(after: 3) }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in self?.scheduleFlush(after: 0) }
            .store(in: &cancellables)
    }

    func attach(sampleSource: AIEqualizerProposalCacheStore) {
        self.sampleSource = sampleSource
        if !pendingIDs.isEmpty {
            scheduleFlush(after: 5)
        }
    }

    /// Marks a sample as changed (new, or its outcome was updated).
    func enqueue(sampleID: UUID) {
        pendingIDs.insert(sampleID.uuidString.lowercased())
        persistState()
        scheduleFlush(after: Self.debounceInterval)
    }

    func forget(sampleIDs: [UUID]) {
        for id in sampleIDs {
            let key = id.uuidString.lowercased()
            pendingIDs.remove(key)
            uploadedStamps.removeValue(forKey: key)
        }
        persistState()
    }

    func forgetAll() {
        pendingIDs.removeAll()
        uploadedStamps.removeAll()
        persistState()
    }

    func scheduleFlush(after delay: TimeInterval) {
        guard !pendingIDs.isEmpty else { return }
        if let nextRetryAt, nextRetryAt > Date().addingTimeInterval(delay) {
            // Back-off owns the timer while the last attempt failed.
            guard flushTask == nil else { return }
            let wait = nextRetryAt.timeIntervalSinceNow
            flushTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(1, wait)))
                guard let self, !Task.isCancelled else { return }
                self.flushTask = nil
                await self.flush()
            }
            return
        }
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard let self, !Task.isCancelled else { return }
            self.flushTask = nil
            await self.flush()
        }
    }

    func flush() async {
        guard !isFlushing else { return }
        guard OnlineAccessManager.shared.canUseOnlineFeatures else { return }
        guard let sampleSource else { return }
        guard !pendingIDs.isEmpty else { return }
        isFlushing = true
        defer { isFlushing = false }

        var batches = 0
        while batches < Self.maximumBatchesPerFlush, !pendingIDs.isEmpty {
            let candidates = sampleSource.trainingSamples(withIDs: pendingIDs)
            // Drop ids whose sample no longer exists locally or whose outcome the
            // server already has.
            var toSend: [CloudAIEqualizerTrainingSample] = []
            for id in pendingIDs {
                guard let sample = candidates[id] else {
                    pendingIDs.remove(id)
                    continue
                }
                if uploadedStamps[id] == Self.stamp(for: sample) {
                    pendingIDs.remove(id)
                    continue
                }
                if AIEqualizerProposalCacheStore.isSelfGenerated(sample.target) {
                    pendingIDs.remove(id)
                    continue
                }
                toSend.append(sample)
                if toSend.count >= Self.batchSize { break }
            }
            guard !toSend.isEmpty else {
                persistState()
                break
            }
            do {
                let response = try await APIService.shared.uploadTrainingSamples(toSend)
                for accepted in response.accepted {
                    let key = accepted.id.lowercased()
                    pendingIDs.remove(key)
                    if let sample = candidates[key] {
                        uploadedStamps[key] = Self.stamp(for: sample)
                    }
                }
                var rateLimited = 0
                for rejected in response.rejected {
                    guard let key = rejected.id?.lowercased() else { continue }
                    if Self.permanentRejectionReasons.contains(rejected.reason) {
                        pendingIDs.remove(key)
                        AppLogger.warning(
                            "[TrainingSamples] Server rejected sample \(key) reason=\(rejected.reason)",
                            step: "training-samples.rejected"
                        )
                    } else {
                        rateLimited += 1
                    }
                }
                consecutiveFailures = 0
                nextRetryAt = nil
                batches += 1
                persistState()
                AppLogger.info(
                    "[TrainingSamples] Uploaded batch stored=\(response.stored) updated=\(response.updated) rejected=\(response.rejected.count) accountSamples=\(response.accountSampleCount) pending=\(pendingIDs.count)",
                    step: "training-samples.uploaded"
                )
                sampleSource.pruneUploadedTrainingSamples(
                    keeping: Self.localRetentionLimit,
                    protecting: pendingIDs
                )
                if rateLimited > 0 {
                    scheduleRetry()
                    break
                }
            } catch {
                consecutiveFailures += 1
                persistState()
                AppLogger.warning(
                    "[TrainingSamples] Upload failed attempt=\(consecutiveFailures) pending=\(pendingIDs.count) error=\(error.localizedDescription)",
                    step: "training-samples.upload-failed"
                )
                scheduleRetry()
                break
            }
        }
        if !pendingIDs.isEmpty, nextRetryAt == nil {
            scheduleFlush(after: Self.debounceInterval)
        }
    }

    private func scheduleRetry() {
        let index = min(consecutiveFailures, Self.backoffIntervals.count - 1)
        nextRetryAt = Date().addingTimeInterval(Self.backoffIntervals[max(0, index)])
        scheduleFlush(after: 0)
    }

    private static func stamp(for sample: CloudAIEqualizerTrainingSample) -> String {
        let date = sample.outcomeUpdatedAt ?? sample.capturedAt
        return "\(ISO8601DateFormatter().string(from: date))|\(sample.feedback?.rawValue ?? "")|\(sample.manualGainsDB?.count ?? 0)"
    }

    private func persistState() {
        let defaults = UserDefaults.standard
        defaults.set(Array(pendingIDs), forKey: AppConfig.StorageKeys.trainingSampleUploadPending)
        if uploadedStamps.count > Self.localRetentionLimit * 4 {
            // Keep the stamp table bounded; anything this old is pruned locally anyway.
            let keep = uploadedStamps.sorted { $0.value > $1.value }.prefix(Self.localRetentionLimit * 2)
            uploadedStamps = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
        }
        defaults.set(uploadedStamps, forKey: AppConfig.StorageKeys.trainingSampleUploadStamps)
    }
}
