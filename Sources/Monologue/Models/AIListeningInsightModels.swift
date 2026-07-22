import Foundation

enum AIListeningInsightScope: String, Codable, Sendable {
    case statisticsDay
    case statisticsWeek
    case statisticsMonth
    case statisticsYear
    case statisticsAll
    case reportDay
    case reportWeek
    case reportMonth
    case reportYear
}

struct AIListeningInsightBucket: Codable, Equatable, Sendable {
    let label: String
    let seconds: Int
    let plays: Int
}

struct AIListeningInsightSong: Codable, Equatable, Sendable {
    let name: String
    let artist: String
    let playCount: Int
    let seconds: Int
    let lyricExcerpt: String?
}

struct AIListeningInsightArtist: Codable, Equatable, Sendable {
    let name: String
    let playCount: Int
    let seconds: Int
}

struct AIListeningInsightInput: Codable, Equatable, Sendable {
    let scope: AIListeningInsightScope
    let periodTitle: String
    let totalSeconds: Int
    let previousSeconds: Int
    let totalPlays: Int
    let completedPlays: Int
    let completionRate: Int
    let uniqueSongs: Int
    let uniqueArtists: Int
    let activeDays: Int
    let dailyAverageSeconds: Int
    let peakHour: Int?
    let longestStreakDays: Int?
    let firstListenSongs: Int?
    let buckets: [AIListeningInsightBucket]
    let topSongs: [AIListeningInsightSong]
    let topArtists: [AIListeningInsightArtist]

    var cacheKey: String {
        let bucketKey = buckets.map { "\($0.label):\($0.seconds):\($0.plays)" }.joined(separator: ",")
        let songKey = topSongs.map {
            "\($0.name):\($0.playCount):\($0.seconds):\($0.lyricExcerpt ?? "")"
        }.joined(separator: ",")
        let artistKey = topArtists.map { "\($0.name):\($0.playCount):\($0.seconds)" }.joined(separator: ",")
        return [
            scope.rawValue,
            periodTitle,
            String(totalSeconds),
            String(previousSeconds),
            String(totalPlays),
            String(completedPlays),
            String(uniqueSongs),
            String(uniqueArtists),
            bucketKey,
            songKey,
            artistKey,
        ].joined(separator: "|")
    }

    @MainActor
    static func statistics(
        period: ListeningStatsService.Period,
        stats: ListeningStatsService.Stats
    ) -> AIListeningInsightInput {
        let scope: AIListeningInsightScope
        switch period {
        case .day: scope = .statisticsDay
        case .week: scope = .statisticsWeek
        case .month: scope = .statisticsMonth
        case .year: scope = .statisticsYear
        case .all: scope = .statisticsAll
        }

        return AIListeningInsightInput(
            scope: scope,
            periodTitle: period.rawValue,
            totalSeconds: stats.totalDuration,
            previousSeconds: stats.previousDuration,
            totalPlays: stats.totalPlays,
            completedPlays: stats.completedPlays,
            completionRate: stats.totalPlays > 0
                ? Int((Double(stats.completedPlays) / Double(stats.totalPlays) * 100).rounded())
                : 0,
            uniqueSongs: stats.uniqueSongs,
            uniqueArtists: stats.uniqueArtists,
            activeDays: stats.activeDays,
            dailyAverageSeconds: stats.dailyAvgDuration,
            peakHour: stats.peakHour,
            longestStreakDays: nil,
            firstListenSongs: nil,
            buckets: stats.trend.map {
                AIListeningInsightBucket(
                    label: Self.dateLabel($0.date),
                    seconds: $0.seconds,
                    plays: $0.plays
                )
            },
            topSongs: Self.songs(stats.topSongs),
            topArtists: Self.artists(stats.topArtists)
        )
    }

    @MainActor
    static func report(_ report: ListeningReport) -> AIListeningInsightInput {
        let scope: AIListeningInsightScope
        switch report.kind {
        case .day: scope = .reportDay
        case .week: scope = .reportWeek
        case .month: scope = .reportMonth
        case .year: scope = .reportYear
        }

        return AIListeningInsightInput(
            scope: scope,
            periodTitle: ListeningReportFormatter.periodTitle(
                kind: report.kind,
                interval: report.interval
            ),
            totalSeconds: report.totalSeconds,
            previousSeconds: report.previousSeconds,
            totalPlays: report.totalPlays,
            completedPlays: report.completedPlays,
            completionRate: report.completionRate,
            uniqueSongs: report.uniqueSongs,
            uniqueArtists: report.uniqueArtists,
            activeDays: report.activeDays,
            dailyAverageSeconds: report.dailyAverageSeconds,
            peakHour: report.peakHour,
            longestStreakDays: report.longestStreakDays,
            firstListenSongs: report.firstListenSongs,
            buckets: report.buckets.map {
                AIListeningInsightBucket(
                    label: Self.dateLabel($0.date),
                    seconds: $0.seconds,
                    plays: $0.plays
                )
            },
            topSongs: Self.songs(report.topSongs),
            topArtists: Self.artists(report.topArtists)
        )
    }

    @MainActor
    private static func songs(
        _ values: [ListeningStatsService.SongStat]
    ) -> [AIListeningInsightSong] {
        values.prefix(8).map {
            AIListeningInsightSong(
                name: $0.name,
                artist: $0.artistName,
                playCount: $0.playCount,
                seconds: $0.totalDuration,
                lyricExcerpt: lyricExcerpt(songID: $0.id)
            )
        }
    }

    @MainActor
    private static func lyricExcerpt(songID: Int) -> String? {
        guard let raw = OptimizedCacheManager.shared.getLyrics(songId: songID)?.lyrics else {
            return nil
        }

        let lines = raw.components(separatedBy: .newlines).compactMap { line -> String? in
            let withoutTime = line.replacingOccurrences(
                of: #"\[[^\]]*\]|\([^\)]*\)"#,
                with: "",
                options: .regularExpression
            )
            let normalized = withoutTime
                .replacingOccurrences(of: "　", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalized.count >= 3,
                  !normalized.lowercased().hasPrefix("offset:") else { return nil }
            return normalized
        }

        var unique: [String] = []
        for line in lines where !unique.contains(line) {
            unique.append(line)
            if unique.count == 2 { break }
        }
        guard !unique.isEmpty else { return nil }
        return String(unique.joined(separator: " / ").prefix(56))
    }

    private static func artists(
        _ values: [ListeningStatsService.ArtistStat]
    ) -> [AIListeningInsightArtist] {
        values.prefix(8).map {
            AIListeningInsightArtist(
                name: $0.name,
                playCount: $0.playCount,
                seconds: $0.totalDuration
            )
        }
    }

    private static func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct AIListeningInsightModelOutput: Codable, Equatable, Sendable {
    let headline: String
    let summary: String
    let observations: [String]
}

struct AIListeningInsightResult: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let inputKey: String
    let headline: String
    let summary: String
    let observations: [String]
    let createdAt: Date
}

enum AIListeningInsightPhase: Equatable, Sendable {
    case idle
    case requesting
    case ready
    case failed(String)

    var isWorking: Bool { self == .requesting }
}
