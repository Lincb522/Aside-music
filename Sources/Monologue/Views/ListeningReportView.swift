import SwiftUI

// MARK: - 听歌报告页

/// 日、周、月、年四种周期共用同一套报告结构。
struct ListeningReportView: View {
    let kind: ListeningReportKind

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var settings = SettingsManager.shared
    @StateObject private var aiInsightAgent = AIListeningInsightAgent()

    @State private var interval: DateInterval?
    @State private var report: ListeningReport?
    @State private var contentVisible = false

    var body: some View {
        let _ = settings.globalThemeRevision

        GeometryReader { proxy in
            let pageWidth = min(proxy.size.width, 760)

            ZStack(alignment: .top) {
                ThemedPageBackground(useRenderLayer: false)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    if let report {
                        VStack(spacing: 0) {
                            reportCover(
                                report,
                                width: pageWidth,
                                topInset: proxy.safeAreaInsets.top
                            )

                            if report.isEmpty {
                                emptyState
                                    .frame(maxWidth: 660)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 56)
                            } else {
                                reportBody(report)
                                    .frame(maxWidth: 680)
                                    .padding(.horizontal, 22)
                                    .padding(.top, 34)
                                    .padding(.bottom, 64)
                                    .opacity(contentVisible ? 1 : 0)
                                    .offset(y: contentVisible ? 0 : 12)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .ignoresSafeArea(edges: .top)
                .simultaneousGesture(periodSwipeGesture)

                floatingTopBar
                    .frame(maxWidth: pageWidth)
                    .padding(.top, max(proxy.safeAreaInsets.top, 8))
            }
        }
        .task { loadDefaultPeriod() }
    }

    // MARK: - 顶部封面

    private var floatingTopBar: some View {
        HStack {
            Text(kind.title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.monologueTextPrimary)
                .padding(.horizontal, 13)
                .frame(height: 36)
                .background(Capsule().fill(.regularMaterial))

            Spacer()

            Button { dismiss() } label: {
                MonologueIcon(icon: .close, size: 11, color: .monologueTextPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.regularMaterial))
                    .contentShape(Circle())
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.9))
            .accessibilityLabel(String(localized: "关闭"))
        }
        .padding(.horizontal, 18)
    }

    private func reportCover(_ report: ListeningReport, width: CGFloat, topInset: CGFloat) -> some View {
        let height = min(max(width * 0.98, 410), 540)
        let topSong = report.topSongs.first

        return ZStack(alignment: .bottomLeading) {
            coverArtwork(topSong, width: width, height: height)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.2), location: 0),
                    .init(color: .clear, location: 0.32),
                    .init(color: .black.opacity(0.18), location: 0.55),
                    .init(color: .black.opacity(0.9), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                periodNavigator
                    .padding(.top, topInset + 58)

                Spacer(minLength: 20)

                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(ListeningReportFormatter.periodTitle(kind: kind, interval: report.interval))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white.opacity(0.72))

                        Text(topSong?.name ?? kind.title)
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)

                        if let topSong {
                            HStack(spacing: 7) {
                                Text(topSong.artistName)
                                    .lineLimit(1)
                                Text("·")
                                Text(String(format: String(localized: "%d 次播放"), topSong.playCount))
                                    .monospacedDigit()
                            }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.74))
                        }
                    }

                    Spacer(minLength: 0)

                    if topSong != nil {
                        Text("01")
                            .font(.system(size: 46, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white.opacity(0.22))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    @ViewBuilder
    private func coverArtwork(
        _ song: ListeningStatsService.SongStat?,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        if let url = song?.coverUrl.flatMap(URL.init(string:)) {
            CachedAsyncImage(
                url: url,
                placeholder: { coverFallback },
                contentMode: .fill,
                width: width,
                height: height
            )
            .frame(width: width, height: height)
            .clipped()
        } else {
            coverFallback
                .frame(width: width, height: height)
        }
    }

    private var coverFallback: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.monologueAccent.opacity(0.86),
                    Color.monologueTextPrimary.opacity(0.86),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            MonologueIcon(icon: .waveform, size: 86, color: .white.opacity(0.17), lineWidth: 1.2)
        }
    }

    // MARK: - 周期导航

    private var periodNavigator: some View {
        HStack(spacing: 12) {
            periodButton(
                icon: .chevronLeft,
                accessibilityLabel: String(localized: "上一期"),
                enabled: canGoPrevious
            ) { shiftPeriod(-1) }

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                if let relative = interval.flatMap({ ListeningReportFormatter.relativeLabel(kind: kind, interval: $0) }) {
                    Text(relative)
                } else {
                    Text(kind.shortTitle)
                }
                if report?.isOngoing == true {
                    Circle()
                        .fill(Color.monologueAccent)
                        .frame(width: 5, height: 5)
                }
            }
            .font(.system(size: 11.5, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(Capsule().fill(Color.black.opacity(0.28)))

            Spacer(minLength: 4)

            periodButton(
                icon: .chevronRight,
                accessibilityLabel: String(localized: "下一期"),
                enabled: canGoNext
            ) { shiftPeriod(1) }
        }
        .padding(.horizontal, 20)
    }

    private func periodButton(
        icon: MonologueIcon.IconType,
        accessibilityLabel: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: 12, color: enabled ? .white : .white.opacity(0.28))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.black.opacity(enabled ? 0.28 : 0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.9))
        .disabled(!enabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private var canGoPrevious: Bool {
        guard let interval else { return false }
        return ListeningReportService.shared.neighborInterval(of: interval, kind: kind, offset: -1) != nil
    }

    private var canGoNext: Bool {
        guard let interval else { return false }
        return ListeningReportService.shared.neighborInterval(of: interval, kind: kind, offset: 1) != nil
    }

    private var periodSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.6 else { return }
                if value.translation.width < -36, canGoNext {
                    shiftPeriod(1)
                } else if value.translation.width > 36, canGoPrevious {
                    shiftPeriod(-1)
                }
            }
    }

    private func shiftPeriod(_ offset: Int) {
        guard let interval,
              let next = ListeningReportService.shared.neighborInterval(
                of: interval,
                kind: kind,
                offset: offset
              )
        else { return }

        HapticManager.shared.light()
        let nextReport = ListeningReportService.shared.report(kind: kind, interval: next)
        if reduceMotion {
            self.interval = next
            report = nextReport
        } else {
            withAnimation(.easeOut(duration: 0.22)) {
                self.interval = next
                report = nextReport
            }
        }
    }

    private func loadDefaultPeriod() {
        guard interval == nil else { return }
        let defaultInterval = ListeningReportService.shared.defaultInterval(for: kind)
        interval = defaultInterval
        report = ListeningReportService.shared.report(kind: kind, interval: defaultInterval)

        if reduceMotion {
            contentVisible = true
        } else {
            withAnimation(.easeOut(duration: 0.28)) {
                contentVisible = true
            }
        }
    }

    // MARK: - 报告正文

    private func reportBody(_ report: ListeningReport) -> some View {
        VStack(alignment: .leading, spacing: 34) {
            listeningSummary(report)

            if kind == .week || kind == .month {
                reportDivider
                AIListeningInsightSection(
                    agent: aiInsightAgent,
                    input: .report(report)
                )
            }

            reportDivider

            trendSection(report)

            if kind != .day, report.hourHistogram.contains(where: { $0 > 0 }) {
                reportDivider
                listeningClock(report)
            }

            if report.topSongs.count > 1 {
                reportDivider
                songRanking(report)
            }

            if !report.topArtists.isEmpty {
                reportDivider
                artistRanking(report)
            }

            reportDivider
            reportFacts(report)
            footer
        }
    }

    // MARK: 收听摘要

    private func listeningSummary(_ report: ListeningReport) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(String(localized: "听歌时长"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)

                    durationText(report.totalSeconds, numberSize: 42, unitSize: 15)
                        .monospacedDigit()
                        .foregroundColor(.monologueTextPrimary)
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 0)

                if let change = report.percentChange {
                    comparisonLabel(change)
                }
            }

            HStack(spacing: 0) {
                summaryMetric(value: "\(report.totalPlays)", label: String(localized: "播放次数"))
                summaryHairline
                summaryMetric(value: "\(report.uniqueSongs)", label: String(localized: "不同歌曲"))
                summaryHairline
                summaryMetric(value: "\(report.uniqueArtists)", label: String(localized: "不同歌手"))
                summaryHairline
                summaryMetric(value: "\(report.completionRate)%", label: String(localized: "完整播放率"))
            }
        }
    }

    private func durationText(_ seconds: Int, numberSize: CGFloat, unitSize: CGFloat) -> Text {
        func number(_ value: Int) -> Text {
            Text("\(value)")
                .font(.system(size: numberSize, weight: .heavy, design: .rounded))
        }
        func unit(_ value: String) -> Text {
            Text(value)
                .font(.system(size: unitSize, weight: .semibold, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
        }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return number(hours) + unit(String(localized: " 小时 ")) + number(minutes) + unit(String(localized: " 分钟"))
        }
        if minutes > 0 {
            return number(minutes) + unit(String(localized: " 分钟"))
        }
        return number(seconds) + unit(String(localized: " 秒"))
    }

    private func comparisonLabel(_ change: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .heavy))
            Text("\(kind.comparisonLabel) \(change >= 0 ? "+" : "")\(change)%")
                .monospacedDigit()
        }
        .font(.system(size: 11.5, weight: .bold, design: .rounded))
        .foregroundColor(.monologueAccent)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Capsule().fill(Color.monologueAccent.opacity(0.11)))
    }

    private func summaryMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.monologueTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryHairline: some View {
        Rectangle()
            .fill(Color.monologueTextPrimary.opacity(0.1))
            .frame(width: 0.5, height: 31)
            .padding(.horizontal, 10)
    }

    // MARK: 趋势

    private func trendSection(_ report: ListeningReport) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionHeading(
                trendTitle,
                detail: report.busiestBucket.map {
                    String(format: String(localized: "峰值 %@"), ListeningReportFormatter.busiestBucketLabel(kind: kind, date: $0.date))
                }
            )

            reportTrendChart(report)
                .frame(height: kind == .day ? 126 : 148)
        }
    }

    private var trendTitle: String {
        switch kind {
        case .day: return String(localized: "每小时收听")
        case .week, .month: return String(localized: "每日收听")
        case .year: return String(localized: "每月收听")
        }
    }

    private func reportTrendChart(_ report: ListeningReport) -> some View {
        let maximum = max(report.buckets.map(\.seconds).max() ?? 1, 1)
        let peakDate = report.busiestBucket?.date

        return GeometryReader { proxy in
            let count = max(report.buckets.count, 1)
            let columnWidth = proxy.size.width / CGFloat(count)
            let trackWidth = min(14, max(4, columnWidth * 0.56))
            let plotHeight = max(56, proxy.size.height - 27)

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(report.buckets.enumerated()), id: \.element.id) { index, bucket in
                    let peak = bucket.date == peakDate
                    let showLabel = shouldShowTrendLabel(index: index, total: report.buckets.count)

                    VStack(spacing: 8) {
                        fixedTrackBar(
                            value: bucket.seconds,
                            maximum: maximum,
                            isPeak: peak,
                            height: plotHeight,
                            width: trackWidth
                        )

                        Text(showLabel ? ListeningReportFormatter.bucketAxisLabel(kind: kind, date: bucket.date) : "")
                            .font(.system(size: 9, weight: peak ? .bold : .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(peak ? .monologueAccent : .monologueTextSecondary)
                            .frame(height: 12)
                    }
                    .frame(width: columnWidth)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(ListeningReportFormatter.busiestBucketLabel(kind: kind, date: bucket.date))
                    .accessibilityValue(ListeningReportFormatter.compactDuration(seconds: bucket.seconds))
                }
            }
        }
    }

    private func shouldShowTrendLabel(index: Int, total: Int) -> Bool {
        switch kind {
        case .day: return index % 6 == 0 || index == total - 1
        case .week, .year: return true
        case .month: return index == 0 || index % 7 == 0 || index == total - 1
        }
    }

    // MARK: 收听时钟

    private func listeningClock(_ report: ListeningReport) -> some View {
        let maximum = max(report.hourHistogram.max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 18) {
            sectionHeading(
                String(localized: "一天中的收听时段"),
                detail: report.peakHour.map { String(format: String(localized: "峰值 %02d:00"), $0) }
            )

            GeometryReader { proxy in
                let columnWidth = proxy.size.width / 24
                let trackWidth = min(8, max(4, columnWidth * 0.54))

                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        let value = report.hourHistogram[hour]
                        fixedTrackBar(
                            value: value,
                            maximum: maximum,
                            isPeak: report.peakHour == hour,
                            height: 54,
                            width: trackWidth
                        )
                        .frame(width: columnWidth)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String(format: "%02d:00", hour))
                        .accessibilityValue(ListeningReportFormatter.compactDuration(seconds: value))
                    }
                }
            }
            .frame(height: 54)

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
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(.monologueTextSecondary)
        }
    }

    // MARK: 歌曲排行

    private func songRanking(_ report: ListeningReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading(String(localized: "常听歌曲"))
                .padding(.bottom, 6)

            ForEach(Array(report.topSongs.dropFirst().prefix(4).enumerated()), id: \.element.id) { index, song in
                HStack(spacing: 13) {
                    Text("\(index + 2)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.monologueTextSecondary)
                        .frame(width: 22, alignment: .leading)

                    CachedAsyncImage(url: song.coverUrl.flatMap(URL.init(string:)), width: 50, height: 50) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.monologueTextPrimary.opacity(0.06))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.name)
                            .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.monologueTextPrimary)
                            .lineLimit(1)
                        Text(song.artistName)
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Text(String(format: String(localized: "%d 次"), song.playCount))
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.monologueTextSecondary)
                }
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.monologueTextPrimary.opacity(0.07))
                        .frame(height: 0.5)
                        .padding(.leading, 35)
                }
            }
        }
    }

    // MARK: 歌手排行

    private func artistRanking(_ report: ListeningReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading(String(localized: "常听歌手"))

            if let first = report.topArtists.first {
                HStack(spacing: 16) {
                    CachedAsyncImage(
                        url: first.representativeCoverUrl.flatMap(URL.init(string:)),
                        width: 76,
                        height: 76
                    ) {
                        Circle()
                            .fill(Color.monologueTextPrimary.opacity(0.07))
                            .overlay(
                                MonologueIcon(icon: .profile, size: 22, color: .monologueTextSecondary)
                            )
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 76, height: 76)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 5) {
                        Text(first.name)
                            .font(.system(size: 23, weight: .heavy, design: .rounded))
                            .foregroundColor(.monologueTextPrimary)
                            .lineLimit(1)
                        Text(String(format: String(localized: "%d 次播放 · %@"), first.playCount, ListeningReportFormatter.compactDuration(seconds: first.totalDuration)))
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                }
            }

            HStack(alignment: .top, spacing: 18) {
                ForEach(Array(report.topArtists.dropFirst().prefix(4).enumerated()), id: \.element.id) { index, artist in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(format: "%02d", index + 2))
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(.monologueAccent)
                        Text(artist.name)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.monologueTextPrimary)
                            .lineLimit(2)
                        Text(String(format: String(localized: "%d 次"), artist.playCount))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: 报告事实

    private func reportFacts(_ report: ListeningReport) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading(String(localized: "收听概览"))

            Grid(horizontalSpacing: 18, verticalSpacing: 0) {
                GridRow {
                    fact(value: ListeningReportFormatter.compactDuration(seconds: report.dailyAverageSeconds), label: String(localized: "日均时长"))
                    fact(value: "\(report.completionRate)%", label: String(localized: "完整播放率"))
                }

                Divider()
                    .gridCellColumns(2)
                    .overlay(Color.monologueTextPrimary.opacity(0.08))
                    .padding(.vertical, 15)

                GridRow {
                    fact(value: "\(report.activeDays)", label: String(localized: "活跃天数"))
                    fact(value: "\(report.longestStreakDays)", label: String(localized: "连续天数"))
                }
            }
        }
    }

    private func fixedTrackBar(
        value: Int,
        maximum: Int,
        isPeak: Bool,
        height: CGFloat,
        width: CGFloat
    ) -> some View {
        let ratio = CGFloat(value) / CGFloat(max(maximum, 1))
        let cornerRadius = min(3, width * 0.36)

        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.monologueTextPrimary.opacity(0.065))

            if value > 0 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isPeak ? Color.monologueAccent : Color.monologueTextPrimary.opacity(0.26))
                    .frame(height: max(3, height * ratio))
            }
        }
        .frame(width: width, height: height)
    }

    private func fact(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 25, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.monologueTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeading(_ title: String, detail: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(.monologueTextPrimary)
            Spacer(minLength: 8)
            if let detail {
                Text(detail)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.monologueTextSecondary)
            }
        }
    }

    private var reportDivider: some View {
        Rectangle()
            .fill(Color.monologueTextPrimary.opacity(0.09))
            .frame(height: 0.5)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(String(localized: "数据仅保存在本机"))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
            Text(String(localized: "Monologue 听歌报告"))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.monologueTextSecondary.opacity(0.65))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            MonologueIcon(icon: .waveform, size: 36, color: .monologueTextSecondary)
            Text(String(localized: "这个周期还没有听歌记录"))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.monologueTextPrimary)
            Text(String(localized: "播放音乐后，报告会在这里生成"))
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
