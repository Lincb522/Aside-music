import SwiftUI

// MARK: - 听歌统计页面

/// 本地听歌统计 — 卡片风格
/// 日/周/月三个维度,展示播放次数、时长、TOP 歌曲/歌手排行
struct ListeningStatsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedPeriod: ListeningStatsService.Period = .day
    @State private var stats: ListeningStatsService.Stats = .empty
    @State private var isLoading = true
    @State private var showClearAlert = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let _ = settings.globalThemeRevision

        ScrollView {
            VStack(spacing: 20) {
                // 周期选择器
                periodPicker

                // 汇总卡片
                summaryCard

                // TOP 歌曲
                if !stats.topSongs.isEmpty {
                    topSongsSection
                }

                // TOP 歌手
                if !stats.topArtists.isEmpty {
                    topArtistsSection
                }

                // 空状态
                if stats.totalPlays == 0 && !isLoading {
                    emptyState
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .navigationTitle(String(localized: "听歌统计"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showClearAlert = true
                    } label: {
                        Label(String(localized: "清理全部数据"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .alert(String(localized: "确认清理"), isPresented: $showClearAlert) {
            Button(String(localized: "取消"), role: .cancel) {}
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
        .background(ThemedPageBackground(useRenderLayer: false))
    }

    // MARK: - 周期选择器

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(ListeningStatsService.Period.allCases) { period in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.rawValue)
                        .font(.system(size: 15, weight: selectedPeriod == period ? .bold : .medium, design: .rounded))
                        .foregroundStyle(selectedPeriod == period ? Color.monologueAccentForeground : .monologueTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedPeriod == period
                                ? AnyShapeStyle(Color.monologueAccent)
                                : AnyShapeStyle(Color.clear)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.monologueTextPrimary.opacity(colorScheme == .dark ? 0.08 : 0.06))
        )
    }

    // MARK: - 汇总卡片

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                statBubble(
                    value: "\(stats.totalPlays)",
                    label: String(localized: "播放次数"),
                    icon: "play.fill"
                )

                statBubble(
                    value: stats.formattedDuration,
                    label: String(localized: "播放时长"),
                    icon: "clock.fill"
                )
            }

            if selectedPeriod != .day {
                statBubble(
                    value: stats.formattedDailyAvg,
                    label: String(localized: "日均时长"),
                    icon: "chart.bar.fill"
                )
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private func statBubble(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.monologueAccent)
                .frame(width: 36, height: 36)
                .background(Color.monologueAccent.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.monologueTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.monologueTextSecondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - TOP 歌曲

    private var topSongsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "最常听的歌曲"))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.monologueTextPrimary)

            VStack(spacing: 8) {
                ForEach(Array(stats.topSongs.enumerated()), id: \.element.id) { index, song in
                    topSongRow(song: song, rank: index + 1)
                }
            }
            .padding(14)
            .background(cardBackground)
        }
    }

    private func topSongRow(song: ListeningStatsService.SongStat, rank: Int) -> some View {
        HStack(spacing: 12) {
            // 排名
            Text("\(rank)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(rank <= 3 ? Color.monologueAccent : .monologueTextSecondary)
                .frame(width: 22)

            // 封面
            CachedAsyncImage(url: song.coverUrl.flatMap(URL.init(string:)), width: 44, height: 44) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.monologueTextPrimary.opacity(0.08))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // 歌曲信息
            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.monologueTextPrimary)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.monologueTextSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // 播放次数
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(song.playCount) 次")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.monologueTextPrimary)

                Text(formatDuration(song.totalDuration))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.monologueTextSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - TOP 歌手

    private var topArtistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "最常听的歌手"))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.monologueTextPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(stats.topArtists.enumerated()), id: \.element.id) { index, artist in
                        artistCard(artist: artist, rank: index + 1)
                    }
                }
            }
        }
    }

    private func artistCard(artist: ListeningStatsService.ArtistStat, rank: Int) -> some View {
        VStack(spacing: 10) {
            // 封面/占位
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: artist.representativeCoverUrl.flatMap(URL.init(string:)), width: 72, height: 72) {
                    Circle()
                        .fill(Color.monologueAccent.opacity(0.14))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.monologueAccent.opacity(0.5))
                        )
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 72, height: 72)
                .clipShape(Circle())

                // 排名角标
                Text("\(rank)")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.monologueAccent, in: Circle())
                    .offset(x: -2, y: -2)
            }

            VStack(spacing: 2) {
                Text(artist.name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.monologueTextPrimary)
                    .lineLimit(1)

                Text("\(artist.playCount) 次")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.monologueTextSecondary)
            }
        }
        .frame(width: 88)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(cardBackground)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.list")
                .font(.system(size: 42))
                .foregroundStyle(Color.monologueTextSecondary.opacity(0.5))

            Text(String(localized: "暂无播放记录"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.monologueTextSecondary)

            Text(String(localized: "播放歌曲后这里会显示你的听歌统计"))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color.monologueTextSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 48)
    }

    // MARK: - 辅助

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.06), radius: 8, x: 0, y: 4)
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
            withAnimation(.easeOut(duration: 0.2)) {
                stats = result
                isLoading = false
            }
        }
    }
}
