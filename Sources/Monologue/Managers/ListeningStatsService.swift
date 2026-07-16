import Foundation

// MARK: - 听歌统计服务

/// 从播放日志（PlayHistory，由 ListeningStatsRecorder 写入真实秒数）
/// 聚合听歌统计。日志独立于「最近播放」列表：清空最近播放不影响这里。
@MainActor
final class ListeningStatsService {
    static let shared = ListeningStatsService()

    // MARK: - 统计周期

    enum Period: String, CaseIterable, Identifiable {
        case day = "今天"
        case week = "本周"
        case month = "本月"
        case year = "今年"
        case all = "全部"

        var id: String { rawValue }

        /// 环比标签；「全部」无环比
        var comparisonLabel: String? {
            switch self {
            case .day: return String(localized: "较昨天")
            case .week: return String(localized: "较上周")
            case .month: return String(localized: "较上月")
            case .year: return String(localized: "较去年")
            case .all: return nil
            }
        }
    }

    /// 走势图粒度
    enum TrendGranularity {
        /// 每天一根柱
        case day
        /// 每月一根柱（「今年」用）
        case month
    }

    // MARK: - 统计结果

    struct Stats {
        /// 总播放次数
        let totalPlays: Int
        /// 总播放时长（秒，真实收听秒数）
        let totalDuration: Int
        /// 上一等长周期总时长（环比基准；无环比为 0）
        let previousDuration: Int
        /// 完整听完（≥95%）的次数
        let completedPlays: Int
        /// 不同歌曲数
        let uniqueSongs: Int
        /// 不同歌手数
        let uniqueArtists: Int
        /// 日均播放时长（秒）
        let dailyAvgDuration: Int
        /// 覆盖天数（有播放记录的天数）
        let activeDays: Int
        /// 走势（随周期自适应：周 7 天 / 月逐日 / 年逐月 / 其他最近 14 天）
        let trend: [DayBucket]
        let trendGranularity: TrendGranularity
        let trendTitle: String
        /// 24 小时收听分布（秒）
        let hourHistogram: [Int]
        /// TOP 歌曲排行
        let topSongs: [SongStat]
        /// TOP 歌手排行
        let topArtists: [ArtistStat]

        var formattedDuration: String { Self.format(seconds: totalDuration) }
        var formattedDailyAvg: String { Self.format(seconds: dailyAvgDuration) }

        /// 分布峰值小时（无数据返回 nil）
        var peakHour: Int? {
            guard let maxValue = hourHistogram.max(), maxValue > 0 else { return nil }
            return hourHistogram.firstIndex(of: maxValue)
        }

        /// 环比百分数；上一周期数据太少（< 1 分钟）时不给出
        var percentChange: Int? {
            guard previousDuration >= 60 else { return nil }
            let change = (Double(totalDuration) - Double(previousDuration)) / Double(previousDuration) * 100
            return max(-999, min(999, Int(change.rounded())))
        }

        static func format(seconds: Int) -> String {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            if hours > 0 {
                return "\(hours) 小时 \(minutes) 分钟"
            }
            return "\(minutes) 分钟"
        }

        static let empty = Stats(
            totalPlays: 0,
            totalDuration: 0,
            previousDuration: 0,
            completedPlays: 0,
            uniqueSongs: 0,
            uniqueArtists: 0,
            dailyAvgDuration: 0,
            activeDays: 0,
            trend: [],
            trendGranularity: .day,
            trendTitle: "",
            hourHistogram: Array(repeating: 0, count: 24),
            topSongs: [],
            topArtists: []
        )
    }

    struct DayBucket: Identifiable {
        let date: Date
        let seconds: Int
        let plays: Int

        var id: Date { date }
    }

    struct SongStat: Identifiable {
        let id: Int
        let name: String
        let artistName: String
        let coverUrl: String?
        let playCount: Int
        let totalDuration: Int // 秒
    }

    struct ArtistStat: Identifiable {
        var id: String { name }
        let name: String
        let playCount: Int
        let totalDuration: Int // 秒
        let representativeCoverUrl: String? // 代表作封面
    }

    // MARK: - 查询

    /// 获取指定周期的统计数据
    func fetchStats(for period: Period) -> Stats {
        let calendar = Calendar.current
        let now = Date()
        let startDate = startDate(for: period)

        let records = DatabaseManager.shared.store.fetch(
            PlayHistory.self,
            where: { record in
                guard record.playedAt <= now else { return false }
                guard record.playDuration > 0 else { return false }
                if let startDate {
                    return record.playedAt >= startDate
                }
                return true
            },
            sortBy: { $0.playedAt > $1.playedAt }
        )
        guard !records.isEmpty else {
            return .empty
        }

        let totalPlays = records.count
        let totalDuration = records.reduce(0) { $0 + $1.playDuration }
        let completedPlays = records.filter(\.completed).count
        let uniqueSongs = Set(records.map(\.songId)).count
        let uniqueArtists = Set(
            records.map { $0.artistName.isEmpty ? String(localized: "未知歌手") : $0.artistName }
        ).count

        // 活跃天数 + 日均
        let dayKeys = Set(records.map { calendar.startOfDay(for: $0.playedAt) })
        let activeDays = max(1, dayKeys.count)
        let dailyAvg = period == .day ? totalDuration : totalDuration / activeDays

        // 环比：上一等长周期总时长
        let previousDuration = previousPeriodDuration(for: period, currentStart: startDate)

        // 走势（随周期自适应）
        let (trend, granularity, trendTitle) = makeTrend(
            for: period,
            records: records,
            calendar: calendar,
            now: now
        )

        // 24 小时分布（按所选周期内的记录）
        var hourHistogram = Array(repeating: 0, count: 24)
        for record in records {
            let hour = calendar.component(.hour, from: record.playedAt)
            hourHistogram[hour] += record.playDuration
        }

        return Stats(
            totalPlays: totalPlays,
            totalDuration: totalDuration,
            previousDuration: previousDuration,
            completedPlays: completedPlays,
            uniqueSongs: uniqueSongs,
            uniqueArtists: uniqueArtists,
            dailyAvgDuration: dailyAvg,
            activeDays: activeDays,
            trend: trend,
            trendGranularity: granularity,
            trendTitle: trendTitle,
            hourHistogram: hourHistogram,
            topSongs: Self.topSongs(from: records, limit: 10),
            topArtists: Self.topArtists(from: records, limit: 10)
        )
    }

    // MARK: - 共享聚合（统计页与周月年报共用）

    /// 按播放次数（次数相同看时长）聚合 TOP 歌曲
    static func topSongs(from records: [PlayHistory], limit: Int) -> [SongStat] {
        var songMap: [Int: (name: String, artist: String, cover: String?, count: Int, duration: Int)] = [:]
        for record in records where record.playDuration > 0 {
            let existing = songMap[record.songId]
            songMap[record.songId] = (
                name: record.songName,
                artist: record.artistName,
                cover: record.coverUrl ?? existing?.cover,
                count: (existing?.count ?? 0) + 1,
                duration: (existing?.duration ?? 0) + record.playDuration
            )
        }
        return songMap
            .sorted {
                $0.value.count != $1.value.count
                    ? $0.value.count > $1.value.count
                    : $0.value.duration > $1.value.duration
            }
            .prefix(limit)
            .map {
                SongStat(
                    id: $0.key,
                    name: $0.value.name,
                    artistName: $0.value.artist,
                    coverUrl: $0.value.cover,
                    playCount: $0.value.count,
                    totalDuration: $0.value.duration
                )
            }
    }

    /// 按播放次数（次数相同看时长）聚合 TOP 歌手
    static func topArtists(from records: [PlayHistory], limit: Int) -> [ArtistStat] {
        var artistMap: [String: (count: Int, duration: Int, cover: String?)] = [:]
        for record in records where record.playDuration > 0 {
            let name = record.artistName.isEmpty ? String(localized: "未知歌手") : record.artistName
            let existing = artistMap[name]
            artistMap[name] = (
                count: (existing?.count ?? 0) + 1,
                duration: (existing?.duration ?? 0) + record.playDuration,
                cover: record.coverUrl ?? existing?.cover
            )
        }
        return artistMap
            .sorted {
                $0.value.count != $1.value.count
                    ? $0.value.count > $1.value.count
                    : $0.value.duration > $1.value.duration
            }
            .prefix(limit)
            .map {
                ArtistStat(
                    name: $0.key,
                    playCount: $0.value.count,
                    totalDuration: $0.value.duration,
                    representativeCoverUrl: $0.value.cover
                )
            }
    }

    // MARK: - 辅助

    /// 周期起点；「全部」返回 nil
    private func startDate(for period: Period) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        switch period {
        case .day:
            return calendar.startOfDay(for: now)
        case .week:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            return calendar.date(from: components) ?? now
        case .month:
            let components = calendar.dateComponents([.year, .month], from: now)
            return calendar.date(from: components) ?? now
        case .year:
            let components = calendar.dateComponents([.year], from: now)
            return calendar.date(from: components) ?? now
        case .all:
            return nil
        }
    }

    /// 上一等长周期（昨天 / 上周 / 上月 / 去年）的总时长
    private func previousPeriodDuration(for period: Period, currentStart: Date?) -> Int {
        guard period != .all, let currentStart else { return 0 }
        let calendar = Calendar.current

        let component: Calendar.Component
        switch period {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        case .all: return 0
        }

        guard let previousStart = calendar.date(byAdding: component, value: -1, to: currentStart) else {
            return 0
        }
        let records = DatabaseManager.shared.store.fetch(
            PlayHistory.self,
            where: {
                $0.playedAt >= previousStart
                    && $0.playedAt < currentStart
                    && $0.playDuration > 0
            }
        )
        return records.reduce(0) { $0 + $1.playDuration }
    }

    /// 走势分桶：周 → 本周 7 天；月 → 本月逐日；年 → 逐月；今天/全部 → 最近 14 天
    private func makeTrend(
        for period: Period,
        records: [PlayHistory],
        calendar: Calendar,
        now: Date
    ) -> ([DayBucket], TrendGranularity, String) {
        switch period {
        case .week, .month:
            guard let interval = calendar.dateInterval(of: period == .week ? .weekOfYear : .month, for: now)
            else { return ([], .day, "") }

            var byDay: [Date: (seconds: Int, plays: Int)] = [:]
            for record in records {
                let day = calendar.startOfDay(for: record.playedAt)
                let existing = byDay[day] ?? (0, 0)
                byDay[day] = (existing.seconds + record.playDuration, existing.plays + 1)
            }

            var buckets: [DayBucket] = []
            var cursor = calendar.startOfDay(for: interval.start)
            while cursor < interval.end {
                let value = byDay[cursor] ?? (0, 0)
                buckets.append(DayBucket(date: cursor, seconds: value.seconds, plays: value.plays))
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            let title = period == .week ? String(localized: "本周走势") : String(localized: "本月走势")
            return (buckets, .day, title)

        case .year:
            guard let interval = calendar.dateInterval(of: .year, for: now) else { return ([], .month, "") }

            var byMonth: [Date: (seconds: Int, plays: Int)] = [:]
            for record in records {
                let components = calendar.dateComponents([.year, .month], from: record.playedAt)
                guard let monthStart = calendar.date(from: components) else { continue }
                let existing = byMonth[monthStart] ?? (0, 0)
                byMonth[monthStart] = (existing.seconds + record.playDuration, existing.plays + 1)
            }

            var buckets: [DayBucket] = []
            var cursor = interval.start
            while cursor < interval.end {
                let value = byMonth[cursor] ?? (0, 0)
                buckets.append(DayBucket(date: cursor, seconds: value.seconds, plays: value.plays))
                guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
                cursor = next
            }
            return (buckets, .month, String(localized: "月度分布"))

        case .day, .all:
            // 无论今天还是全部，两周窗口都比单日更有上下文
            let trendStart = calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: now)) ?? now
            let trendRecords = DatabaseManager.shared.store.fetch(
                PlayHistory.self,
                where: {
                    $0.playedAt >= trendStart
                        && $0.playedAt <= now
                        && $0.playDuration > 0
                }
            )

            var byDay: [Date: (seconds: Int, plays: Int)] = [:]
            for record in trendRecords {
                let day = calendar.startOfDay(for: record.playedAt)
                let existing = byDay[day] ?? (0, 0)
                byDay[day] = (existing.seconds + record.playDuration, existing.plays + 1)
            }

            var buckets: [DayBucket] = []
            for offset in 0..<14 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: trendStart) else { continue }
                let value = byDay[day] ?? (0, 0)
                buckets.append(DayBucket(date: day, seconds: value.seconds, plays: value.plays))
            }
            return (buckets, .day, String(localized: "最近 14 天"))
        }
    }

    /// 清理所有统计数据
    func clearAllData() {
        let store = DatabaseManager.shared.store
        store.deleteAll(PlayHistory.self)
        store.save()
    }

    /// 清理 N 个月前的数据
    func clearOldData(monthsAgo: Int = 12) {
        let store = DatabaseManager.shared.store
        let cutoff = Calendar.current.date(byAdding: .month, value: -monthsAgo, to: Date()) ?? Date()
        store.deleteAll(PlayHistory.self) { $0.playedAt < cutoff }
        store.save()
    }
}
