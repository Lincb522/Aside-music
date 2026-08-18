import Foundation
import HealthKit

struct MonoHearingPoint: Identifiable, Sendable {
    var id: Double { frequency }
    let frequency: Double
    let leftDBHL: Double?
    let rightDBHL: Double?
}

@MainActor
final class MonoHearingProfileEngine: ObservableObject {
    static let shared = MonoHearingProfileEngine()

    @Published private(set) var isHealthDataAvailable = HKHealthStore.isHealthDataAvailable()
    @Published private(set) var isRequestingAuthorization = false
    @Published private(set) var isLoading = false
    @Published private(set) var audiogramDate: Date?
    @Published private(set) var points: [MonoHearingPoint] = []
    @Published private(set) var leftCorrection: [Float] = Array(repeating: 0, count: 10)
    @Published private(set) var rightCorrection: [Float] = Array(repeating: 0, count: 10)
    @Published private(set) var averageExposureDBASPL: Double?
    @Published private(set) var exposureDurationHours: Double = 0
    @Published private(set) var errorMessage: String?

    private let healthStore = HKHealthStore()

    private init() {}

    func requestAccessAndRefresh() {
        guard isHealthDataAvailable else {
            errorMessage = String(localized: "sound_hearing_health_unavailable")
            return
        }
        isRequestingAuthorization = true
        errorMessage = nil
        var readTypes: Set<HKObjectType> = [HKObjectType.audiogramSampleType()]
        if let exposure = HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure) {
            readTypes.insert(exposure)
        }
        healthStore.requestAuthorization(toShare: [], read: readTypes) { [weak self] success, error in
            Task { @MainActor in
                guard let self else { return }
                self.isRequestingAuthorization = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard success else {
                    self.errorMessage = String(localized: "sound_hearing_health_denied")
                    return
                }
                self.refresh()
            }
        }
    }

    func refresh() {
        guard isHealthDataAvailable else { return }
        isLoading = true
        errorMessage = nil
        loadLatestAudiogram()
        loadRecentExposure()
    }

    func applyCorrection() {
        guard points.isEmpty == false else { return }
        EQManager.shared.installHearingCorrection(
            left: leftCorrection,
            right: rightCorrection
        )
    }

    func removeCorrection() {
        EQManager.shared.clearHearingCorrection()
    }

    private func loadLatestAudiogram() {
        let type = HKObjectType.audiogramSampleType()
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: type,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, error in
            let sample = samples?.first as? HKAudiogramSample
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }
                guard let sample else {
                    self.points = []
                    self.leftCorrection = Array(repeating: 0, count: 10)
                    self.rightCorrection = Array(repeating: 0, count: 10)
                    self.audiogramDate = nil
                    self.isLoading = false
                    return
                }
                let decoded = Self.decode(sample)
                self.points = decoded
                self.audiogramDate = sample.endDate
                self.leftCorrection = Self.makeCorrection(from: decoded, ear: \MonoHearingPoint.leftDBHL)
                self.rightCorrection = Self.makeCorrection(from: decoded, ear: \MonoHearingPoint.rightDBHL)
                self.isLoading = false
            }
        }
        healthStore.execute(query)
    }

    private func loadRecentExposure() {
        guard let type = HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure) else { return }
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date().addingTimeInterval(-604_800)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { [weak self] _, samples, _ in
            let values = (samples as? [HKQuantitySample]) ?? []
            let unit = HKUnit.decibelAWeightedSoundPressureLevel()
            var weightedEnergy = 0.0
            var totalSeconds = 0.0
            for sample in values {
                let duration = max(1, sample.endDate.timeIntervalSince(sample.startDate))
                let decibels = sample.quantity.doubleValue(for: unit)
                guard decibels.isFinite else { continue }
                weightedEnergy += pow(10, decibels / 10) * duration
                totalSeconds += duration
            }
            let average = totalSeconds > 0
                ? 10 * log10(max(0.000_000_1, weightedEnergy / totalSeconds))
                : nil
            Task { @MainActor in
                self?.averageExposureDBASPL = average
                self?.exposureDurationHours = totalSeconds / 3_600
            }
        }
        healthStore.execute(query)
    }

    private nonisolated static func decode(_ sample: HKAudiogramSample) -> [MonoHearingPoint] {
        let frequencyUnit = HKUnit.hertz()
        let sensitivityUnit = HKUnit.decibelHearingLevel()
        return sample.sensitivityPoints.compactMap { point in
            let frequency = point.frequency.doubleValue(for: frequencyUnit)
            guard frequency.isFinite, frequency > 0 else { return nil }
            return MonoHearingPoint(
                frequency: frequency,
                leftDBHL: point.leftEarSensitivity?.doubleValue(for: sensitivityUnit),
                rightDBHL: point.rightEarSensitivity?.doubleValue(for: sensitivityUnit)
            )
        }
        .sorted { $0.frequency < $1.frequency }
    }

    private nonisolated static func makeCorrection(
        from points: [MonoHearingPoint],
        ear: KeyPath<MonoHearingPoint, Double?>
    ) -> [Float] {
        let usable = points.compactMap { point -> (Double, Double)? in
            guard let value = point[keyPath: ear], value.isFinite else { return nil }
            return (point.frequency, value)
        }
        guard usable.isEmpty == false else { return Array(repeating: 0, count: 10) }
        let frequencies = [31.25, 62.5, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
        var curve = frequencies.map { frequency -> Float in
            let loss = interpolatedValue(at: frequency, samples: usable)
            // Hearing thresholds are not ordinary EQ targets. Apply only a
            // restrained fraction above 10 dB HL and leave final safety to the
            // output limiter.
            return Float(min(6, max(0, (loss - 10) * 0.12)))
        }
        if curve.count > 2 {
            let source = curve
            for index in 1..<(curve.count - 1) {
                curve[index] = source[index] * 0.6 + (source[index - 1] + source[index + 1]) * 0.2
            }
        }
        return curve
    }

    private nonisolated static func interpolatedValue(
        at frequency: Double,
        samples: [(Double, Double)]
    ) -> Double {
        guard let first = samples.first, let last = samples.last else { return 0 }
        if frequency <= first.0 { return first.1 }
        if frequency >= last.0 { return last.1 }
        guard let upperIndex = samples.firstIndex(where: { $0.0 >= frequency }), upperIndex > 0 else {
            return first.1
        }
        let lower = samples[upperIndex - 1]
        let upper = samples[upperIndex]
        let span = log2(upper.0 / lower.0)
        guard span > 0 else { return lower.1 }
        let progress = log2(frequency / lower.0) / span
        return lower.1 + (upper.1 - lower.1) * progress
    }
}
