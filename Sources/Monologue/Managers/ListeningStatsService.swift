import Foundation

// MARK: - 听歌统计服务

/// 从 PlayHistory 聚合本地听歌统计数据
/// 支持日/周/月三个维度
@MainActor
final class ListeningStatsService {
    static let shared = ListeningStatsService()

    // MARK: - 统计周期

    enum Period: String, CaseIterable, Identifiable {
        case day = "日"
        case week = "周"
        case month = "月"

        var id: String { rawValue }
    }

    // MARK: - 统计结果

    struct Stats {
        /// 总播放次数
        let totalPlays: Int
        /// 总播放时长（秒）
        let totalDuration: Int
        /// 日均播放时长（秒，仅周/月有意义）
        let dailyAvgDuration: Int
        /// TOP 歌曲排行
        let topSongs: [SongStat]
        /// TOP 歌手排行
        let topArtists: [ArtistStat]

        /// 格式化的总时长
        var formattedDuration: String {
            let hours = totalDuration / 3600
            let minutes = (totalDuration % 3600) / 60
            if hours > 0 {
                return "\(hours) 小时 \(minutes) 分钟"
            }
            return "\(minutes) 分钟"
        }

        /// 格式化的日均时长
        var formattedDailyAvg: String {
            let hours = dailyAvgDuration / 3600
            let minutes = (dailyAvgDuration % 3600) / 60
            if hours > 0 {
                return "\(hours) 小时 \(minutes) 分钟"
            }
            return "\(minutes) 分钟"
        }

        static let empty = Stats(
            totalPlays: 0,
            totalDuration: 0,
            dailyAvgDuration: 0,
            topSongs: [],
            topArtists: []
        )
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
        let startDate = startDate(for: period)
        let now = Date()

        let records = DatabaseManager.shared.store.fetch(
            PlayHistory.self,
            where: { $0.playedAt >= startDate && $0.playedAt <= now },
            sortBy: { $0.playedAt > $1.playedAt }
        )
        guard !records.isEmpty else {
            return .empty
        }

        let totalPlays = records.count
        let totalDuration = records.reduce(0) { $0 + $1.playDuration }

        // 日均
        let days = max(1, Calendar.current.dateComponents([.day], from: startDate, to: now).day ?? 1)
        let dailyAvg = period == .day ? totalDuration : totalDuration / days

        // TOP 歌曲
        var songMap: [Int: (name: String, artist: String, cover: String?, count: Int, duration: Int)] = [:]
        for record in records {
            let existing = songMap[record.songId]
            songMap[record.songId] = (
                name: record.songName,
                artist: record.artistName,
                cover: record.coverUrl ?? existing?.cover,
                count: (existing?.count ?? 0) + 1,
                duration: (existing?.duration ?? 0) + record.playDuration
            )
        }
        let topSongs = songMap
            .sorted { $0.value.count > $1.value.count }
            .prefix(10)
            .map { SongStat(id: $0.key, name: $0.value.name, artistName: $0.value.artist, coverUrl: $0.value.cover, playCount: $0.value.count, totalDuration: $0.value.duration) }

        // TOP 歌手
        var artistMap: [String: (count: Int, duration: Int, cover: String?)] = [:]
        for record in records {
            let name = record.artistName.isEmpty ? "未知歌手" : record.artistName
            let existing = artistMap[name]
            artistMap[name] = (
                count: (existing?.count ?? 0) + 1,
                duration: (existing?.duration ?? 0) + record.playDuration,
                cover: record.coverUrl ?? existing?.cover
            )
        }
        let topArtists = artistMap
            .sorted { $0.value.count > $1.value.count }
            .prefix(10)
            .map { ArtistStat(name: $0.key, playCount: $0.value.count, totalDuration: $0.value.duration, representativeCoverUrl: $0.value.cover) }

        return Stats(
            totalPlays: totalPlays,
            totalDuration: totalDuration,
            dailyAvgDuration: dailyAvg,
            topSongs: topSongs,
            topArtists: topArtists
        )
    }

    // MARK: - 辅助

    private func startDate(for period: Period) -> Date {
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
