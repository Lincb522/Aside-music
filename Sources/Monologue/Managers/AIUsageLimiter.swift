import Foundation
@preconcurrency import Combine

@MainActor
final class AIUsageLimiter: ObservableObject {
    static let shared = AIUsageLimiter()

    @Published private(set) var snapshot = AIUsageSnapshot(
        usedToday: 0,
        usedThisHour: 0,
        lastRequestAt: nil
    )

    private static let storageKey = "ai.eq.usage.request-timestamps"
    private var requestTimestamps: [Date]

    private init() {
        let rawValues = UserDefaults.standard.array(forKey: Self.storageKey) as? [Double] ?? []
        requestTimestamps = rawValues.map { Date(timeIntervalSince1970: $0) }
        refresh()
    }

    func reserveRequest(limits: AIUsageLimits, now: Date = Date()) throws {
        removeExpiredEntries(now: now)
        let current = makeSnapshot(now: now)

        if limits.dailyRequestLimit > 0, current.usedToday >= limits.dailyRequestLimit {
            throw AIEqualizerError.dailyLimitReached(limits.dailyRequestLimit)
        }
        if limits.hourlyRequestLimit > 0, current.usedThisHour >= limits.hourlyRequestLimit {
            throw AIEqualizerError.hourlyLimitReached(limits.hourlyRequestLimit)
        }
        if limits.minimumRequestInterval > 0,
           let last = current.lastRequestAt {
            let remaining = limits.minimumRequestInterval - now.timeIntervalSince(last)
            if remaining > 0 {
                throw AIEqualizerError.requestFrequencyLimited(Int(ceil(remaining)))
            }
        }

        requestTimestamps.append(now)
        persist()
        snapshot = makeSnapshot(now: now)
    }

    func refresh(now: Date = Date()) {
        removeExpiredEntries(now: now)
        snapshot = makeSnapshot(now: now)
    }

    func reset() {
        requestTimestamps.removeAll()
        persist()
        snapshot = AIUsageSnapshot(usedToday: 0, usedThisHour: 0, lastRequestAt: nil)
    }

    private func removeExpiredEntries(now: Date) {
        guard let oldestRetained = Calendar.current.date(byAdding: .day, value: -2, to: now) else { return }
        let originalCount = requestTimestamps.count
        requestTimestamps.removeAll { $0 < oldestRetained }
        if requestTimestamps.count != originalCount { persist() }
    }

    private func makeSnapshot(now: Date) -> AIUsageSnapshot {
        let startOfDay = Calendar.current.startOfDay(for: now)
        let startOfHour = now.addingTimeInterval(-3_600)
        return AIUsageSnapshot(
            usedToday: requestTimestamps.filter { $0 >= startOfDay && $0 <= now }.count,
            usedThisHour: requestTimestamps.filter { $0 >= startOfHour && $0 <= now }.count,
            lastRequestAt: requestTimestamps.max()
        )
    }

    private func persist() {
        UserDefaults.standard.set(
            requestTimestamps.map(\.timeIntervalSince1970),
            forKey: Self.storageKey
        )
    }
}
