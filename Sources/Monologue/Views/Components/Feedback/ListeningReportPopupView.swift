import SwiftUI

// MARK: - 听歌报告弹窗

struct ListeningReportPopupOverlay: View {
    @ObservedObject private var center = ListeningReportCenter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var presentedKind: ListeningReportKind?

    var body: some View {
        ZStack {
            if let pending = center.pending {
                Color.black.opacity(0.46)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { center.dismissPending() }

                ListeningReportPopupCard(
                    pending: pending,
                    onOpenReport: {
                        center.dismissPending()
                        presentedKind = pending.kind
                    },
                    onDismiss: { center.dismissPending() }
                )
                .transition(
                    reduceMotion
                        ? .opacity
                        : .scale(scale: 0.96).combined(with: .opacity)
                )
            }
        }
        .animation(.easeOut(duration: 0.22), value: center.pending?.id)
        .fullScreenCover(item: $presentedKind) { kind in
            ListeningReportView(kind: kind)
        }
    }
}

private struct ListeningReportPopupCard: View {
    let pending: ListeningReportCenter.PendingPopup
    let onOpenReport: () -> Void
    let onDismiss: () -> Void

    @ObservedObject private var settings = SettingsManager.shared

    private var report: ListeningReport { pending.report }

    private var cardTitle: String {
        switch pending.kind {
        case .day: return String(localized: "听歌日报")
        case .week: return String(localized: "上周听歌报告")
        case .month: return String(localized: "上月听歌报告")
        case .year: return String(localized: "年度听歌报告")
        }
    }

    private var canDisableAutomaticPopup: Bool {
        pending.kind == .week || pending.kind == .month
    }

    var body: some View {
        VStack(spacing: 0) {
            coverPreview

            reportPreview
                .padding(.horizontal, 20)
                .padding(.top, 20)

            actions
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: 374)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.24), radius: 8, y: 5)
        .padding(.horizontal, 22)
    }

    // MARK: - 封面预览

    private var coverPreview: some View {
        ZStack(alignment: .bottomLeading) {
            popupArtwork

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.18), location: 0),
                    .init(color: .clear, location: 0.35),
                    .init(color: .black.opacity(0.88), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                HStack {
                    Text(ListeningReportFormatter.periodTitle(kind: pending.kind, interval: report.interval))
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Capsule().fill(Color.black.opacity(0.28)))

                    Spacer()

                    Button(action: onDismiss) {
                        MonologueIcon(icon: .close, size: 10, color: .white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.black.opacity(0.28)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.9))
                    .accessibilityLabel(String(localized: "关闭"))
                }

                Spacer(minLength: 18)

                HStack(alignment: .bottom, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(cardTitle)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.72))

                        if let topSong = report.topSongs.first {
                            Text(topSong.name)
                                .font(.system(size: 25, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.76)

                            Text(topSong.artistName)
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.72))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    if !report.topSongs.isEmpty {
                        Text("01")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white.opacity(0.2))
                    }
                }
            }
            .padding(17)
        }
        .frame(height: 238)
        .clipped()
    }

    @ViewBuilder
    private var popupArtwork: some View {
        if let url = report.topSongs.first?.coverUrl.flatMap(URL.init(string:)) {
            CachedAsyncImage(
                url: url,
                placeholder: { artworkFallback },
                contentMode: .fill,
                width: 374,
                height: 238
            )
            .frame(maxWidth: .infinity)
            .frame(height: 238)
            .clipped()
        } else {
            artworkFallback
        }
    }

    private var artworkFallback: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.monologueAccent.opacity(0.86),
                    Color.monologueTextPrimary.opacity(0.82),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            MonologueIcon(icon: .waveform, size: 62, color: .white.opacity(0.18), lineWidth: 1.2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 238)
    }

    // MARK: - 数据预览

    private var reportPreview: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 6) {
                Text(pending.insight.headline)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(1)

                Text(pending.insight.summary)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
                    .lineSpacing(3)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle()
                .fill(Color.monologueSeparator)
                .frame(height: 0.5)

            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "听歌时长"))
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                    compactDuration(report.totalSeconds)
                        .monospacedDigit()
                        .foregroundColor(.monologueTextPrimary)
                }

                Spacer(minLength: 4)

                miniTrend
                    .frame(width: 96, height: 48)
            }

            HStack(spacing: 7) {
                Text(String(format: String(localized: "%d 次播放"), report.totalPlays))
                Text("·")
                Text(String(format: String(localized: "%d 首歌曲"), report.uniqueSongs))
                Text("·")
                Text(String(format: String(localized: "%d 位歌手"), report.uniqueArtists))
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.monologueTextSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
        }
    }

    private func compactDuration(_ seconds: Int) -> Text {
        func number(_ value: Int) -> Text {
            Text("\(value)")
                .font(.system(size: 31, weight: .heavy, design: .rounded))
        }
        func unit(_ value: String) -> Text {
            Text(value)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
        }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return number(hours) + unit(String(localized: " 小时 ")) + number(minutes) + unit(String(localized: " 分钟"))
        }
        return number(minutes) + unit(String(localized: " 分钟"))
    }

    private var miniTrend: some View {
        let visibleBuckets: [ListeningReport.Bucket]
        if report.buckets.count > 12 {
            visibleBuckets = stride(from: 0, to: report.buckets.count, by: 3).map { report.buckets[$0] }
        } else {
            visibleBuckets = report.buckets
        }
        let maximum = max(visibleBuckets.map(\.seconds).max() ?? 1, 1)
        let visiblePeakDate = visibleBuckets.max { lhs, rhs in
            lhs.seconds < rhs.seconds
        }?.date

        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(visibleBuckets) { bucket in
                let ratio = CGFloat(bucket.seconds) / CGFloat(maximum)

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(Color.monologueTextPrimary.opacity(0.065))

                    if bucket.seconds > 0 {
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(
                                bucket.date == visiblePeakDate
                                    ? Color.monologueAccent
                                    : Color.monologueTextPrimary.opacity(0.24)
                            )
                            .frame(height: max(3, 44 * ratio))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
        }
    }

    // MARK: - 操作

    private var actions: some View {
        VStack(spacing: 11) {
            Button(action: onOpenReport) {
                HStack {
                    Text(String(localized: "查看完整报告"))
                    Spacer()
                    MonologueIcon(icon: .chevronRight, size: 10, color: Color(light: .white, dark: .black))
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Color(light: .white, dark: .black))
                .padding(.horizontal, 17)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.monologueAccent))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))

            HStack(spacing: 0) {
                Button(action: onDismiss) {
                    Text(String(localized: "稍后再看"))
                        .frame(maxWidth: .infinity)
                }

                if canDisableAutomaticPopup {
                    Rectangle()
                        .fill(Color.monologueTextPrimary.opacity(0.1))
                        .frame(width: 0.5, height: 14)

                    Button {
                        if pending.kind == .week {
                            settings.listeningReportWeeklyPopupEnabled = false
                        } else if pending.kind == .month {
                            settings.listeningReportMonthlyPopupEnabled = false
                        }
                        onDismiss()
                    } label: {
                        Text(String(localized: "不再自动弹出"))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            .foregroundColor(.monologueTextSecondary)
            .buttonStyle(.plain)
        }
    }
}
