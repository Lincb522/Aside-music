import SwiftUI

// MARK: - 听歌统计页面

/// 本地听歌统计 —— 编辑部式排版：
/// 日报/周报/月报/年报入口 + 大数字主指标（含环比）+ 发丝线数据条 +
/// 随周期自适应的走势图 + 24 小时时钟分布 + 序号式 TOP 歌曲/歌手。
/// 数据来自独立播放日志（清空最近播放不受影响）。
struct ListeningStatsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @StateObject private var aiInsightAgent = AIListeningInsightAgent()
    @State private var selectedPeriod: ListeningStatsService.Period = .week
    @State private var stats: ListeningStatsService.Stats = .empty
    @State private var isLoading = true
    @State private var showClearAlert = false
    @State private var showMoreMenu = false
    @State private var presentedReportKind: ListeningReportKind?
    @State private var reportSummaries: [ReportCardSummary] = []
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let _ = settings.globalThemeRevision

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsScrollablePageHeader(
                    title: String(localized: "cloud_sync_listening_stats"),
                    eyebrow: "LISTENING",
                    icon: .chart
                )

                VStack(alignment: .leading, spacing: 26) {
                    if settings.listeningReportsEnabled, !reportSummaries.isEmpty {
                        reportCards
                    }

                    periodPicker

                    if stats.totalPlays == 0 && !isLoading {
                        emptyState
                    } else {
                        heroBlock
                        statsStrip
                        if !isLoading {
                            AIListeningInsightSection(
                                agent: aiInsightAgent,
                                input: .statistics(period: selectedPeriod, stats: stats)
                            )
                        }

                        if stats.trend.contains(where: { $0.seconds > 0 || $0.plays > 0 }) {
                            trendSection
                        }

                        if stats.hourHistogram.contains(where: { $0 > 0 }) {
                            hourSection
                        }

                        if !stats.topSongs.isEmpty {
                            topSongsSection
                        }

                        if !stats.topArtists.isEmpty {
                            topArtistsSection
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 48)
            }
        }
        .scrollIndicators(.hidden)
        .coordinateSpace(name: SettingsPageLayout.scrollCoordinateSpace)
        .themeRenderScrollLayer()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .monoNavigationBackButton()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        showMoreMenu.toggle()
                    }
                } label: {
                    MonoIcon(icon: .more, size: 17, color: .monoTextSecondary)
                        .frame(width: 36, height: 36)
                        .monoGlassCircle(interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "player_more_title"))
            }
        }
        .overlay {
            if showMoreMenu {
                MonoMoreMenuOverlay(
                    isPresented: $showMoreMenu,
                    title: String(localized: "player_more_title"),
                    isDarkBackground: colorScheme == .dark
                ) {
                    listeningStatsMoreMenu
                }
                .zIndex(20)
            }
        }
        .alert(String(localized: "确认清理"), isPresented: $showClearAlert) {
            Button(String(localized: "cancel"), role: .cancel) {}
            Button(String(localized: "清理"), role: .destructive) {
                ListeningStatsService.shared.clearAllData()
                refreshStats()
            }
        } message: {
            Text(String(localized: "将清除所有本地播放统计记录，此操作不可撤销"))
        }
        .task {
            refreshStats()
        }
        .onChange(of: selectedPeriod) { _, _ in
            refreshStats()
        }
        .fullScreenCover(item: $presentedReportKind) { kind in
            ListeningReportView(kind: kind)
        }
        .background(ThemedPageBackground(useRenderLayer: false))
    }

    private var listeningStatsMoreMenu: some View {
        VStack(alignment: .leading, spacing: 16) {
            MonoMoreMenuSection(title: String(localized: "more_menu_reports_section")) {
                MonoMoreMenuGroup {
                    MonoMoreMenuToggleRow(
                        icon: .chart,
                        title: String(localized: "日报 / 周报 / 月报 / 年报"),
                        isOn: $settings.listeningReportsEnabled
                    )

                    if settings.listeningReportsEnabled {
                        MonoMoreMenuDivider()

                        MonoMoreMenuToggleRow(
                            icon: .history,
                            title: String(localized: "每周自动弹出"),
                            isOn: $settings.listeningReportWeeklyPopupEnabled
                        )

                        MonoMoreMenuDivider()

                        MonoMoreMenuToggleRow(
                            icon: .clock,
                            title: String(localized: "每月自动弹出"),
                            isOn: $settings.listeningReportMonthlyPopupEnabled
                        )
                    }
                }
            }

            MonoMoreMenuSection(title: String(localized: "more_menu_data_section")) {
                MonoMoreMenuGroup {
                    MonoMoreMenuRow(
                        icon: .trash,
                        title: String(localized: "清理全部数据"),
                        isDestructive: true
                    ) {
                        showMoreMenu = false
                        showClearAlert = true
                    }
                }
            }
        }
    }

    // MARK: - 报告入口

    private struct ReportCardSummary: Identifiable {
        let kind: ListeningReportKind
        let periodLabel: String
        let durationText: String?

        var id: String { kind.rawValue }
    }

    private var reportCards: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(String(localized: "听歌报告"))
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.monoTextPrimary)

            HStack(spacing: 0) {
                ForEach(Array(reportSummaries.enumerated()), id: \.element.id) { index, summary in
                    reportCard(summary)

                    if index < reportSummaries.count - 1 {
                        Rectangle()
                            .fill(Color.monoTextPrimary.opacity(0.09))
                            .frame(width: 0.5, height: 32)
                    }
                }
            }
            .padding(.vertical, 7)
            .themedPageSurface(cornerRadius: 16, elevated: true, mangaTint: MangaStyle.bubbleWhite)
        }
    }

    private func reportCard(_ summary: ReportCardSummary) -> some View {
        Button {
            presentedReportKind = summary.kind
        } label: {
            VStack(spacing: 6) {
                Text(summary.kind.shortTitle)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.monoTextSecondary)

                Text(summary.durationText ?? "—")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        summary.durationText == nil
                            ? Color.monoTextSecondary.opacity(0.45)
                            : Color.monoTextPrimary
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 55)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(summary.kind.title)，\(summary.periodLabel)")
        .accessibilityValue(summary.durationText ?? String(localized: "暂无记录"))
    }

    // MARK: - 周期选择器（左对齐胶囊分段）

    private var periodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(ListeningStatsService.Period.allCases) { period in
                    let selected = selectedPeriod == period

                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                            selectedPeriod = period
                        }
                    } label: {
                        Text(period.rawValue)
                            .font(.system(size: 13, weight: selected ? .bold : .medium, design: .rounded))
                            .foregroundStyle(
                                selected
                                    ? Color.monoTextPrimary
                                    : Color.monoTextSecondary.opacity(0.8)
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(
                                    selected
                                        ? Color.monoTextPrimary.opacity(0.08)
                                        : Color.clear
                                )
                            )
                            .overlay(
                                Capsule().stroke(
                                    selected
                                        ? Color.monoTextPrimary.opacity(0.1)
                                        : Color.monoTextPrimary.opacity(0.05),
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 主指标（大数字）

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "听歌时长"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.monoTextSecondary)

            Text(stats.formattedDuration)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.monoTextPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())

            if let change = stats.percentChange, let label = selectedPeriod.comparisonLabel {
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 8.5, weight: .heavy))

                    Text("\(label) \(change >= 0 ? "+" : "")\(change)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(Color.monoAccent)
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(
                    Capsule()
                        .fill(Color.monoAccent.opacity(0.12))
                        .overlay(Capsule().stroke(Color.monoAccent.opacity(0.24), lineWidth: 0.8))
                )
                .padding(.top, 2)
            }

            if selectedPeriod != .day, stats.activeDays > 1 {
                Text("日均 \(stats.formattedDailyAvg) · 覆盖 \(stats.activeDays) 天")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.monoTextSecondary.opacity(0.9))
            }
        }
    }

    // MARK: - 数据条（发丝线分隔）

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statCell(value: "\(stats.totalPlays)", label: String(localized: "播放次数"))
            statHairline
            statCell(value: "\(stats.uniqueSongs)", label: String(localized: "不同歌曲"))
            statHairline
            statCell(value: "\(stats.uniqueArtists)", label: String(localized: "不同歌手"))
            statHairline
            statCell(value: "\(stats.completedPlays)", label: String(localized: "听完整首"))
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.monoTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.monoTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statHairline: some View {
        Rectangle()
            .fill(Color.monoTextPrimary.opacity(0.1))
            .frame(width: 0.5, height: 28)
            .padding(.trailing, 12)
    }

    // MARK: - 走势（随周期自适应：周 7 天 / 月逐日 / 年逐月 / 其他 14 天）

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(stats.trendTitle)

            let maxSeconds = max(stats.trend.map(\.seconds).max() ?? 1, 1)
            let compact = stats.trend.count > 16

            HStack(alignment: .bottom, spacing: compact ? 2.5 : 5) {
                ForEach(stats.trend) { bucket in
                    let isCurrent = isCurrentTrendBucket(bucket)

                    VStack(spacing: 5) {
                        statsTrackBar(
                            value: bucket.seconds,
                            maximum: maxSeconds,
                            isHighlighted: isCurrent,
                            height: 64,
                            width: compact ? 5 : (stats.trend.count <= 7 ? 14 : 8)
                        )

                        if !compact {
                            Text(trendLabel(bucket.date))
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(
                                    isCurrent
                                        ? Color.monoAccent
                                        : Color.monoTextSecondary.opacity(0.7)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            if compact {
                compactTrendAxis
            }
        }
    }

    /// 本月逐日走势的稀疏横轴（1 / 8 / 15 / 22 / 月末）
    private var compactTrendAxis: some View {
        HStack {
            Text("1")
            Spacer()
            Text("8")
            Spacer()
            Text("15")
            Spacer()
            Text("22")
            Spacer()
            Text("\(stats.trend.count)")
        }
        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(Color.monoTextSecondary.opacity(0.65))
    }

    /// 当前所在桶（今天 / 本月）高亮
    private func isCurrentTrendBucket(_ bucket: ListeningStatsService.DayBucket) -> Bool {
        let calendar = Calendar.current
        switch stats.trendGranularity {
        case .day:
            return calendar.isDateInToday(bucket.date)
        case .month:
            return calendar.isDate(bucket.date, equalTo: Date(), toGranularity: .month)
        }
    }

    private func trendLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        switch stats.trendGranularity {
        case .day:
            if selectedPeriod == .week {
                let weekday = calendar.component(.weekday, from: date)
                let symbols = [
                    String(localized: "日"), String(localized: "一"), String(localized: "二"),
                    String(localized: "三"), String(localized: "四"), String(localized: "五"),
                    String(localized: "六"),
                ]
                return symbols[(weekday - 1) % 7]
            }
            return "\(calendar.component(.day, from: date))"
        case .month:
            return "\(calendar.component(.month, from: date))"
        }
    }

    // MARK: - 24 小时分布

    private var hourSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                String(localized: "收听时段"),
                trailing: stats.peakHour.map { String(format: String(localized: "峰值 %02d:00"), $0) }
            )

            let maxValue = max(stats.hourHistogram.max() ?? 1, 1)

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    let value = stats.hourHistogram[hour]
                    let isPeak = stats.peakHour == hour

                    statsTrackBar(
                        value: value,
                        maximum: maxValue,
                        isHighlighted: isPeak,
                        height: 44,
                        width: 6
                    )
                        .frame(maxWidth: .infinity)
                }
            }

            HStack {
                Text("0")
                Spacer()
                Text("6")
                Spacer()
                Text("12")
                Spacer()
                Text("18")
                Spacer()
                Text("23")
            }
            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color.monoTextSecondary.opacity(0.65))
        }
    }

    // MARK: - TOP 歌曲（序号发丝线行）

    private var topSongsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(String(localized: "最常听的歌曲"))
                .padding(.bottom, 8)

            ForEach(Array(stats.topSongs.enumerated()), id: \.element.id) { index, song in
                topSongRow(song: song, rank: index + 1)
            }
        }
    }

    private func topSongRow(song: ListeningStatsService.SongStat, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 13, weight: rank <= 3 ? .heavy : .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    rank <= 3
                        ? Color.monoAccent
                        : Color.monoTextSecondary.opacity(0.7)
                )
                .frame(width: 22, alignment: .leading)

            CachedAsyncImage(url: song.coverUrl.flatMap(URL.init(string:)), width: 42, height: 42) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.monoTextPrimary.opacity(0.06))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.monoTextPrimary.opacity(0.07), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.monoTextPrimary)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.monoTextSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(song.playCount) 次")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.monoTextPrimary)

                if song.totalDuration > 0 {
                    Text(formatDuration(song.totalDuration))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.monoTextSecondary)
                }
            }
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.monoTextPrimary.opacity(0.055))
                .frame(height: 0.5)
                .padding(.leading, 34)
        }
    }

    // MARK: - TOP 歌手（序号发丝线行）

    private var topArtistsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(String(localized: "最常听的歌手"))
                .padding(.bottom, 8)

            ForEach(Array(stats.topArtists.enumerated()), id: \.element.id) { index, artist in
                topArtistRow(artist: artist, rank: index + 1)
            }
        }
    }

    private func topArtistRow(artist: ListeningStatsService.ArtistStat, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 13, weight: rank <= 3 ? .heavy : .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    rank <= 3
                        ? Color.monoAccent
                        : Color.monoTextSecondary.opacity(0.7)
                )
                .frame(width: 22, alignment: .leading)

            CachedAsyncImage(url: artist.representativeCoverUrl.flatMap(URL.init(string:)), width: 42, height: 42) {
                Circle()
                    .fill(Color.monoTextPrimary.opacity(0.06))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.monoTextSecondary.opacity(0.5))
                    )
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 42, height: 42)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.monoTextPrimary.opacity(0.07), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(artist.name)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.monoTextPrimary)
                    .lineLimit(1)

                if artist.totalDuration > 0 {
                    Text(formatDuration(artist.totalDuration))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.monoTextSecondary)
                }
            }

            Spacer(minLength: 4)

            Text("\(artist.playCount) 次")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.monoTextPrimary)
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.monoTextPrimary.opacity(0.055))
                .frame(height: 0.5)
                .padding(.leading, 34)
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.list")
                .font(.system(size: 42))
                .foregroundStyle(Color.monoTextSecondary.opacity(0.5))

            Text(String(localized: "暂无播放记录"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.monoTextSecondary)

            Text(String(localized: "播放歌曲后这里会显示你的听歌统计"))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color.monoTextSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    // MARK: - 辅助

    private func statsTrackBar(
        value: Int,
        maximum: Int,
        isHighlighted: Bool,
        height: CGFloat,
        width: CGFloat
    ) -> some View {
        let ratio = CGFloat(value) / CGFloat(max(maximum, 1))
        let cornerRadius = min(2.5, width * 0.34)

        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.monoTextPrimary.opacity(0.065))

            if value > 0 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isHighlighted ? Color.monoAccent : Color.monoTextPrimary.opacity(0.26))
                    .frame(height: max(3, height * ratio))
            }
        }
        .frame(width: width, height: height)
    }

    /// 强调色竖标小节头（与搜索/队列一致的语言）
    private func sectionHeader(_ title: String, trailing: String? = nil) -> some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color.monoAccent)
                .frame(width: 3, height: 13)

            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.monoTextPrimary)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.monoTextSecondary)
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func refreshStats() {
        isLoading = true
        Task {
            let result = ListeningStatsService.shared.fetchStats(for: selectedPeriod)
            let summaries = makeReportSummaries()
            withAnimation(.easeOut(duration: 0.2)) {
                stats = result
                reportSummaries = summaries
                isLoading = false
            }
        }
    }

    private func makeReportSummaries() -> [ReportCardSummary] {
        let service = ListeningReportService.shared
        return ListeningReportKind.allCases.map { kind in
            let interval = service.defaultInterval(for: kind)
            let seconds = service.totalSeconds(in: interval)
            // 年报直接标年份，其余报告优先使用相对日期。
            let label = kind == .year
                ? ListeningReportFormatter.periodTitle(kind: kind, interval: interval)
                : (ListeningReportFormatter.relativeLabel(kind: kind, interval: interval)
                    ?? ListeningReportFormatter.periodTitle(kind: kind, interval: interval))
            return ReportCardSummary(
                kind: kind,
                periodLabel: label,
                durationText: seconds > 0
                    ? ListeningReportFormatter.compactDuration(seconds: seconds)
                    : nil
            )
        }
    }
}
