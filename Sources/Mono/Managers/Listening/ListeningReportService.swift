import Combine
import Foundation
import SwiftUI
import UIKit

// MARK: - 报告类型

enum ListeningReportKind: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year

    var id: String { rawValue }

    /// 报告页标题
    var title: String {
        switch self {
        case .day: return String(localized: "听歌日报")
        case .week: return String(localized: "听歌周报")
        case .month: return String(localized: "听歌月报")
        case .year: return String(localized: "听歌年报")
        }
    }

    /// 入口卡片短标签
    var shortTitle: String {
        switch self {
        case .day: return String(localized: "日报")
        case .week: return String(localized: "周报")
        case .month: return String(localized: "月报")
        case .year: return String(localized: "年报")
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }

    /// 环比标签
    var comparisonLabel: String {
        switch self {
        case .day: return String(localized: "较前一天")
        case .week: return String(localized: "较上周")
        case .month: return String(localized: "较上月")
        case .year: return String(localized: "较去年")
        }
    }
}

// MARK: - 报告数据

struct ListeningReport {
    struct Bucket: Identifiable {
        /// 桶起点（日报为小时，周/月报为自然日，年报为月份第一天）
        let date: Date
        let seconds: Int
        let plays: Int

        var id: Date { date }
    }

    let kind: ListeningReportKind
    let interval: DateInterval
    /// 周期尚未结束（进行中）
    let isOngoing: Bool

    let totalSeconds: Int
    let totalPlays: Int
    let completedPlays: Int
    let uniqueSongs: Int
    let uniqueArtists: Int
    /// 有播放记录的天数
    let activeDays: Int
    /// 周期覆盖天数（进行中截至今天）
    let coveredDays: Int
    /// 上一周期总时长（环比基准）
    let previousSeconds: Int

    /// 日报 24 桶（小时）、周报 7 桶（天）、月报每天一桶、年报 12 桶（月）
    let buckets: [Bucket]
    let hourHistogram: [Int]
    let topSongs: [ListeningStatsService.SongStat]
    let topArtists: [ListeningStatsService.ArtistStat]
    /// 周期内最长连续听歌天数
    let longestStreakDays: Int
    /// 周期内第一次听到的歌曲数（全历史范围判定首听）
    let firstListenSongs: Int

    var isEmpty: Bool { totalPlays == 0 }

    var peakHour: Int? {
        guard let maxValue = hourHistogram.max(), maxValue > 0 else { return nil }
        return hourHistogram.firstIndex(of: maxValue)
    }

    var busiestBucket: Bucket? {
        buckets.max { $0.seconds < $1.seconds }.flatMap { $0.seconds > 0 ? $0 : nil }
    }

    /// 完整播放率（0~100）
    var completionRate: Int {
        guard totalPlays > 0 else { return 0 }
        return Int((Double(completedPlays) / Double(totalPlays) * 100).rounded())
    }

    /// 日均时长（按活跃天数）
    var dailyAverageSeconds: Int {
        guard activeDays > 0 else { return 0 }
        return totalSeconds / activeDays
    }

    /// 环比百分数；上一周期数据太少（< 1 分钟）时不给出
    var percentChange: Int? {
        guard previousSeconds >= 60 else { return nil }
        let change = (Double(totalSeconds) - Double(previousSeconds)) / Double(previousSeconds) * 100
        return max(-999, min(999, Int(change.rounded())))
    }
}

// MARK: - 报告数据服务

/// 从播放日志聚合日报 / 周报 / 月报 / 年报。日期与时区跟随系统，
/// 周周期固定为周一至周日；interval 为 [start, end) 半开区间。
@MainActor
final class ListeningReportService {
    static let shared = ListeningReportService()

    private init() {}

    // MARK: - 周期计算

    /// 包含指定日期的完整周期
    func interval(for kind: ListeningReportKind, containing date: Date) -> DateInterval {
        let calendar = ListeningStatisticsCalendar.current
        return calendar.dateInterval(of: kind.calendarComponent, for: date)
            ?? DateInterval(start: date, duration: 0)
    }

    /// 报告页默认展示的周期：
    /// 日报 / 周报 / 月报优先上一个已完结周期（无记录则回落到进行中周期），年报为今年。
    func defaultInterval(for kind: ListeningReportKind, now: Date = Date()) -> DateInterval {
        let current = interval(for: kind, containing: now)
        guard kind != .year else { return current }

        let previous = interval(for: kind, containing: current.start.addingTimeInterval(-1))
        if totalSeconds(in: previous) > 0 {
            return previous
        }
        return current
    }

    /// 相邻周期；返回 nil 表示越界（未来周期或早于最早记录）
    func neighborInterval(
        of interval: DateInterval,
        kind: ListeningReportKind,
        offset: Int,
        now: Date = Date()
    ) -> DateInterval? {
        guard offset != 0 else { return interval }
        let calendar = ListeningStatisticsCalendar.current
        guard let shifted = calendar.date(
            byAdding: kind.calendarComponent,
            value: offset,
            to: interval.start
        ) else { return nil }

        let candidate = self.interval(for: kind, containing: shifted)

        // 不允许翻到未来
        guard candidate.start <= now else { return nil }
        // 不早于最早一条播放记录所在周期
        if let earliest = earliestPlayDate() {
            let earliestPeriod = self.interval(for: kind, containing: earliest)
            guard candidate.start >= earliestPeriod.start else { return nil }
        } else {
            // 无任何记录时只保留当前周期
            let currentPeriod = self.interval(for: kind, containing: now)
            guard candidate.start == currentPeriod.start else { return nil }
        }
        return candidate
    }

    /// 周期唯一键（弹窗去重用）："2026-W28" / "2026-06"
    func periodKey(for kind: ListeningReportKind, interval: DateInterval) -> String {
        let calendar = ListeningStatisticsCalendar.current
        switch kind {
        case .day:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: interval.start)
        case .week:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: interval.start)
            return String(format: "%04d-W%02d", components.yearForWeekOfYear ?? 0, components.weekOfYear ?? 0)
        case .month:
            let components = calendar.dateComponents([.year, .month], from: interval.start)
            return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
        case .year:
            let year = calendar.component(.year, from: interval.start)
            return String(format: "%04d", year)
        }
    }

    // MARK: - 快速汇总

    /// 指定区间的总收听秒数（入口卡片 / 弹窗门槛用）
    func totalSeconds(in interval: DateInterval) -> Int {
        let records = records(in: interval)
        return records.reduce(0) { $0 + $1.playDuration }
    }

    /// 最早一条播放记录时间
    func earliestPlayDate() -> Date? {
        DatabaseManager.shared.store
            .fetchAll(PlayHistory.self)
            .filter { ListeningPlaybackPolicy.isEffective($0) }
            .map(\.playedAt)
            .min()
    }

    // MARK: - 报告聚合

    func report(kind: ListeningReportKind, interval: DateInterval, now: Date = Date()) -> ListeningReport {
        let calendar = ListeningStatisticsCalendar.current
        let records = records(in: interval)
        let isOngoing = interval.end > now

        let totalSeconds = records.reduce(0) { $0 + $1.playDuration }
        let totalPlays = records.count
        let completedPlays = records.filter(\.completed).count
        let uniqueSongs = Set(records.map { ListeningPlaybackPolicy.identityKey(for: $0) }).count
        let uniqueArtists = Set(
            records.map { $0.artistName.isEmpty ? String(localized: "search_unknown_artist") : $0.artistName }
        ).count

        // 活跃天数 + 覆盖天数
        let activeDayKeys = Set(records.map { calendar.startOfDay(for: $0.playedAt) })
        let coverageEnd = min(interval.end, now)
        let coveredDays = max(
            1,
            (calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: interval.start),
                to: calendar.startOfDay(for: coverageEnd)
            ).day ?? 0) + 1
        )

        // 环比：上一等长周期
        let previousInterval = self.interval(for: kind, containing: interval.start.addingTimeInterval(-1))
        let previousSeconds = self.totalSeconds(in: previousInterval)

        // 分桶
        let buckets = makeBuckets(kind: kind, interval: interval, records: records, calendar: calendar)

        // 24 小时分布
        var hourHistogram = Array(repeating: 0, count: 24)
        for record in records {
            let hour = calendar.component(.hour, from: record.playedAt)
            hourHistogram[hour] += record.playDuration
        }

        // 连续听歌天数
        let longestStreak = longestStreakDays(activeDays: activeDayKeys, calendar: calendar)

        // 首听歌曲：全历史范围内第一次播放落在本周期
        let firstListenSongs = firstListenCount(in: interval)

        return ListeningReport(
            kind: kind,
            interval: interval,
            isOngoing: isOngoing,
            totalSeconds: totalSeconds,
            totalPlays: totalPlays,
            completedPlays: completedPlays,
            uniqueSongs: uniqueSongs,
            uniqueArtists: uniqueArtists,
            activeDays: activeDayKeys.count,
            coveredDays: coveredDays,
            previousSeconds: previousSeconds,
            buckets: buckets,
            hourHistogram: hourHistogram,
            topSongs: ListeningStatsService.topSongs(from: records, limit: 5),
            topArtists: ListeningStatsService.topArtists(from: records, limit: 5),
            longestStreakDays: longestStreak,
            firstListenSongs: firstListenSongs
        )
    }

    // MARK: - 私有

    private func records(in interval: DateInterval) -> [PlayHistory] {
        let now = Date()
        return DatabaseManager.shared.store.fetch(
            PlayHistory.self,
            where: { record in
                record.playedAt >= interval.start
                    && record.playedAt < interval.end
                    && record.playedAt <= now
                    && ListeningPlaybackPolicy.isEffective(record)
            }
        )
    }

    private func makeBuckets(
        kind: ListeningReportKind,
        interval: DateInterval,
        records: [PlayHistory],
        calendar: Calendar
    ) -> [ListeningReport.Bucket] {
        switch kind {
        case .day:
            var byHour: [Date: (seconds: Int, plays: Int)] = [:]
            for record in records {
                let components = calendar.dateComponents([.year, .month, .day, .hour], from: record.playedAt)
                guard let hour = calendar.date(from: components) else { continue }
                let existing = byHour[hour] ?? (0, 0)
                byHour[hour] = (existing.seconds + record.playDuration, existing.plays + 1)
            }

            var buckets: [ListeningReport.Bucket] = []
            var cursor = interval.start
            while cursor < interval.end {
                let value = byHour[cursor] ?? (0, 0)
                buckets.append(.init(date: cursor, seconds: value.seconds, plays: value.plays))
                guard let next = calendar.date(byAdding: .hour, value: 1, to: cursor) else { break }
                cursor = next
            }
            return buckets

        case .week, .month:
            var byDay: [Date: (seconds: Int, plays: Int)] = [:]
            for record in records {
                let day = calendar.startOfDay(for: record.playedAt)
                let existing = byDay[day] ?? (0, 0)
                byDay[day] = (existing.seconds + record.playDuration, existing.plays + 1)
            }

            var buckets: [ListeningReport.Bucket] = []
            var cursor = calendar.startOfDay(for: interval.start)
            while cursor < interval.end {
                let value = byDay[cursor] ?? (0, 0)
                buckets.append(.init(date: cursor, seconds: value.seconds, plays: value.plays))
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            return buckets

        case .year:
            var byMonth: [Date: (seconds: Int, plays: Int)] = [:]
            for record in records {
                let components = calendar.dateComponents([.year, .month], from: record.playedAt)
                guard let monthStart = calendar.date(from: components) else { continue }
                let existing = byMonth[monthStart] ?? (0, 0)
                byMonth[monthStart] = (existing.seconds + record.playDuration, existing.plays + 1)
            }

            var buckets: [ListeningReport.Bucket] = []
            var cursor = interval.start
            while cursor < interval.end {
                let value = byMonth[cursor] ?? (0, 0)
                buckets.append(.init(date: cursor, seconds: value.seconds, plays: value.plays))
                guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
                cursor = next
            }
            return buckets
        }
    }

    private func longestStreakDays(activeDays: Set<Date>, calendar: Calendar) -> Int {
        guard !activeDays.isEmpty else { return 0 }
        let sorted = activeDays.sorted()
        var longest = 1
        var current = 1
        for index in 1..<sorted.count {
            let gap = calendar.dateComponents([.day], from: sorted[index - 1], to: sorted[index]).day ?? 0
            if gap == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    private func firstListenCount(in interval: DateInterval) -> Int {
        var firstPlayBySong: [String: Date] = [:]
        for record in DatabaseManager.shared.store.fetchAll(PlayHistory.self)
        where ListeningPlaybackPolicy.isEffective(record) {
            let key = ListeningPlaybackPolicy.identityKey(for: record)
            if let existing = firstPlayBySong[key] {
                if record.playedAt < existing {
                    firstPlayBySong[key] = record.playedAt
                }
            } else {
                firstPlayBySong[key] = record.playedAt
            }
        }
        return firstPlayBySong.values.filter {
            $0 >= interval.start && $0 < interval.end
        }.count
    }
}

// MARK: - 报告弹窗调度

/// 新的一周 / 一月开始后，把上一周期的报告以弹窗推给用户。
/// 与更新日志、专属问候错峰：它们在场时等待，全部关闭后再弹。
@MainActor
final class ListeningReportCenter: ObservableObject {
    static let shared = ListeningReportCenter()

    struct PendingPopup: Identifiable {
        let kind: ListeningReportKind
        let report: ListeningReport
        let insight: AIListeningInsightResult

        var id: String {
            "\(kind.rawValue)-\(report.interval.start.timeIntervalSince1970)"
        }
    }

    @Published var pending: PendingPopup?

    /// 已展示或已放弃展示的周周期键；只在弹窗真正进入展示状态后写入，
    /// 避免沿用“数据尚未恢复也算已读”的旧记录。
    private static let weeklySeenKey = "listeningReportWeeklyPresentedPeriodV2"
    private static let monthlySeenKey = "listeningReportMonthlySeenPeriod"

    /// 弹窗门槛：上一周期收听不足时不打扰
    private static let weeklyMinSeconds = 300
    private static let monthlyMinSeconds = 900

    private var didPresentThisLaunch = false
    private var foregroundObserver: NSObjectProtocol?
    private var dayChangeObserver: NSObjectProtocol?
    private var presentTask: Task<Void, Never>?

    private init() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                ListeningReportCenter.shared.evaluateIfNewDay()
            }
        }
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                ListeningReportCenter.shared.evaluateIfNewDay()
            }
        }
    }

    // MARK: - 触发

    /// 冷启动（欢迎页关闭后）调用
    func presentOnLaunchIfEligible() {
        guard !didPresentThisLaunch else { return }
        didPresentThisLaunch = true
        scheduleEvaluation()
    }

    private func evaluateIfNewDay() {
        guard didPresentThisLaunch else { return }
        scheduleEvaluation()
    }

    /// 云端听歌记录可能晚于主界面恢复；合并完成后补一次评估。
    func retryAfterHistoryRestore() {
        guard didPresentThisLaunch, pending == nil else { return }
        scheduleEvaluation()
    }

    private func scheduleEvaluation() {
        guard pending == nil, presentTask == nil else { return }

        presentTask = Task { @MainActor [weak self] in
            defer { self?.presentTask = nil }

            // 等主界面首帧稳定
            try? await Task.sleep(nanoseconds: 1_100_000_000)

            // 只避让已经出现的弹窗；后台生成问候不应阻塞听歌报告。
            var waitedTicks = 0
            while ChangelogManager.shared.pendingRelease != nil
                || SpecialGreetingManager.shared.pending != nil,
                waitedTicks < 360
            {
                try? await Task.sleep(nanoseconds: 500_000_000)
                waitedTicks += 1
            }

            guard let self, !Task.isCancelled, self.pending == nil else { return }
            guard let candidate = self.duePopup() else { return }

            withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                self.pending = candidate
            }
            self.markHandled(candidate, now: Date())
            self.enrichInsight(for: candidate)
        }
    }

    /// 计算当前应弹出的报告；月报优先于周报
    private func duePopup(now: Date = Date()) -> PendingPopup? {
        let settings = SettingsManager.shared
        guard settings.listeningReportsEnabled else { return nil }

        let service = ListeningReportService.shared
        let defaults = UserDefaults.standard

        let currentMonth = service.interval(for: .month, containing: now)
        let lastMonth = service.interval(for: .month, containing: currentMonth.start.addingTimeInterval(-1))
        let monthKey = service.periodKey(for: .month, interval: lastMonth)

        let currentWeek = service.interval(for: .week, containing: now)
        let lastWeek = service.interval(for: .week, containing: currentWeek.start.addingTimeInterval(-1))
        let weekKey = service.periodKey(for: .week, interval: lastWeek)

        if settings.listeningReportMonthlyPopupEnabled,
           defaults.string(forKey: Self.monthlySeenKey) != monthKey
        {
            let seconds = service.totalSeconds(in: lastMonth)
            if seconds >= Self.monthlyMinSeconds {
                let report = service.report(kind: .month, interval: lastMonth, now: now)
                return PendingPopup(
                    kind: .month,
                    report: report,
                    insight: AIListeningInsightAgent.shared.fallbackResult(for: .report(report))
                )
            }
        }

        if settings.listeningReportWeeklyPopupEnabled,
           defaults.string(forKey: Self.weeklySeenKey) != weekKey
        {
            let seconds = service.totalSeconds(in: lastWeek)
            if seconds >= Self.weeklyMinSeconds {
                let report = service.report(kind: .week, interval: lastWeek, now: now)
                return PendingPopup(
                    kind: .week,
                    report: report,
                    insight: AIListeningInsightAgent.shared.fallbackResult(for: .report(report))
                )
            }
        }

        return nil
    }

    private func enrichInsight(for popup: PendingPopup) {
        let popupID = popup.id
        let input = AIListeningInsightInput.report(popup.report)
        Task { @MainActor [weak self] in
            let insight = await AIListeningInsightAgent.shared.automaticInsight(for: input)
            guard let self, self.pending?.id == popupID else { return }
            self.pending = PendingPopup(
                kind: popup.kind,
                report: popup.report,
                insight: insight
            )
        }
    }

    private func markHandled(_ popup: PendingPopup, now: Date) {
        let service = ListeningReportService.shared
        let defaults = UserDefaults.standard
        let key = service.periodKey(for: popup.kind, interval: popup.report.interval)
        switch popup.kind {
        case .month:
            defaults.set(key, forKey: Self.monthlySeenKey)
            let currentWeek = service.interval(for: .week, containing: now)
            if ListeningStatisticsCalendar.current.isDate(now, inSameDayAs: currentWeek.start) {
                let previousWeek = service.interval(for: .week, containing: currentWeek.start.addingTimeInterval(-1))
                defaults.set(service.periodKey(for: .week, interval: previousWeek), forKey: Self.weeklySeenKey)
            }
        case .week:
            defaults.set(key, forKey: Self.weeklySeenKey)
        case .day, .year:
            break
        }
    }

    func dismissPending() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            pending = nil
        }
    }

    /// 开发者弹窗预览：直接展示指定类型的报告弹窗，
    /// 不校验开关与门槛，也不写入已读周期。
    func presentPreview(kind: ListeningReportKind) {
        let service = ListeningReportService.shared
        let interval = service.defaultInterval(for: kind)
        let report = service.report(kind: kind, interval: interval)
        let insight = AIListeningInsightAgent.shared.fallbackResult(for: .report(report))
        withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
            pending = PendingPopup(kind: kind, report: report, insight: insight)
        }
    }

}

// MARK: - 周期标签格式化

enum ListeningReportFormatter {
    /// 周期主标签："7月14日" / "7月6日 – 7月12日" / "2026年6月" / "2026年"
    static func periodTitle(kind: ListeningReportKind, interval: DateInterval) -> String {
        let calendar = ListeningStatisticsCalendar.current
        switch kind {
        case .day:
            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日"
            return formatter.string(from: interval.start)
        case .week:
            let endDay = interval.end.addingTimeInterval(-1)
            let startYear = calendar.component(.year, from: interval.start)
            let currentYear = calendar.component(.year, from: Date())
            let formatter = DateFormatter()
            formatter.dateFormat = startYear == currentYear ? "M月d日" : "yyyy年M月d日"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "M月d日"
            return "\(formatter.string(from: interval.start)) – \(endFormatter.string(from: endDay))"
        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年M月"
            return formatter.string(from: interval.start)
        case .year:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年"
            return formatter.string(from: interval.start)
        }
    }

    /// 相对标签：今天 / 昨天 / 本周 / 上周 / 本月 / 上月 / 今年 / 去年。
    @MainActor
    static func relativeLabel(kind: ListeningReportKind, interval: DateInterval, now: Date = Date()) -> String? {
        let service = ListeningReportService.shared
        let current = service.interval(for: kind, containing: now)
        let previous = service.interval(for: kind, containing: current.start.addingTimeInterval(-1))

        if interval.start == current.start {
            switch kind {
            case .day: return String(localized: "今天")
            case .week: return String(localized: "本周")
            case .month: return String(localized: "本月")
            case .year: return String(localized: "今年")
            }
        }
        if interval.start == previous.start {
            switch kind {
            case .day: return String(localized: "昨天")
            case .week: return String(localized: "上周")
            case .month: return String(localized: "上月")
            case .year: return String(localized: "去年")
            }
        }
        return nil
    }

    /// 时长文本："12 小时 34 分钟" / "34 分钟"
    static func duration(seconds: Int) -> String {
        ListeningStatsService.Stats.format(seconds: seconds)
    }

    /// 紧凑时长："8h 24m" / "24m"
    static func compactDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// 桶标签（走势图横轴）
    static func bucketAxisLabel(kind: ListeningReportKind, date: Date) -> String {
        let calendar = ListeningStatisticsCalendar.current
        switch kind {
        case .day:
            return String(format: "%02d", calendar.component(.hour, from: date))
        case .week:
            let weekday = calendar.component(.weekday, from: date)
            let symbols = [
                String(localized: "日"), String(localized: "一"), String(localized: "二"),
                String(localized: "三"), String(localized: "四"), String(localized: "五"),
                String(localized: "六"),
            ]
            return symbols[(weekday - 1) % 7]
        case .month:
            return "\(calendar.component(.day, from: date))"
        case .year:
            return "\(calendar.component(.month, from: date))"
        }
    }

    /// 峰值桶说明："周三" / "18日" / "3月"
    static func busiestBucketLabel(kind: ListeningReportKind, date: Date) -> String {
        let calendar = ListeningStatisticsCalendar.current
        switch kind {
        case .day:
            return String(format: "%02d:00", calendar.component(.hour, from: date))
        case .week:
            let weekday = calendar.component(.weekday, from: date)
            let names = [
                String(localized: "周日"), String(localized: "周一"), String(localized: "周二"),
                String(localized: "周三"), String(localized: "周四"), String(localized: "周五"),
                String(localized: "周六"),
            ]
            return names[(weekday - 1) % 7]
        case .month:
            return "\(calendar.component(.day, from: date))日"
        case .year:
            return "\(calendar.component(.month, from: date))月"
        }
    }
}
