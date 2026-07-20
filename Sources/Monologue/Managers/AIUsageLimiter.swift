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

    /// 预留一次请求配额。返回的时间戳作为凭据，请求未真正消耗
    /// 服务端资源时可通过 `releaseReservation` 返还。
    @discardableResult
    func reserveRequest(limits: AIUsageLimits, now: Date = Date()) throws -> Date {
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
        return now
    }

    /// 网络抖动等未触达模型的失败不应吞掉配额，否则重试会把
    /// 每日/每小时额度成倍消耗在没有产出的请求上。
    func releaseReservation(_ reservation: Date) {
        guard let index = requestTimestamps.lastIndex(of: reservation) else { return }
        requestTimestamps.remove(at: index)
        persist()
        snapshot = makeSnapshot(now: Date())
    }

    /// 判定失败是否应返还配额：请求从未到达服务端（传输层错误），
    /// 或服务端明确拒绝处理（408/425/429/5xx）。已产出内容但解析
    /// 失败的请求照常计费，与真实 token 消耗保持一致。
    nonisolated static func shouldRefundReservation(for error: Error) -> Bool {
        if error is URLError { return true }
        if let aiError = error as? AIEqualizerError,
           case let .httpStatus(code, _) = aiError {
            return code == 408 || code == 425 || code == 429 || (500...599).contains(code)
        }
        return false
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
