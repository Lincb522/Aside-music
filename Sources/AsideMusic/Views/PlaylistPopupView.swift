import SwiftUI

struct PlaylistPopupView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var player = PlayerManager.shared
    @State private var selectedTab = 0 // 0: 当前, 1: 历史
    @Namespace private var namespace

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.top, 24)
                .padding(.bottom, 16)

            ScrollView {
                LazyVStack(spacing: 0) {
                    if selectedTab == 0 {
                        currentQueueView
                    } else {
                        historyView
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .background(sheetBackground.ignoresSafeArea(edges: .bottom))
    }

    /// 面板背景 — 使用通用弥散背景
    @ViewBuilder
    private var sheetBackground: some View {
        AsideBackground()
    }

    private var headerView: some View {
        HStack(spacing: 0) {
            HStack(spacing: 24) {
                tabButton(title: "queue_tab_now_playing", tabIndex: 0)
                tabButton(title: "queue_tab_history", tabIndex: 1)
            }

            Spacer()

            Button(action: { player.switchMode() }) {
                HStack(spacing: 6) {
                    AsideIcon(icon: player.mode.asideIcon, size: 16, color: .asideTextPrimary)
                    Text(modeName(player.mode))
                        .font(.rounded(size: 14, weight: .medium))
                }
                .foregroundColor(.asideTextPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.asideSeparator)
                )
            }
        }
        .padding(.horizontal, 24)
    }

    private func tabButton(title: String, tabIndex: Int) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tabIndex } }) {
            VStack(spacing: 6) {
                Text(LocalizedStringKey(title))
                    .font(.rounded(size: 18, weight: selectedTab == tabIndex ? .bold : .medium))
                    .foregroundColor(selectedTab == tabIndex ? .asideTextPrimary : .asideTextSecondary)

                if selectedTab == tabIndex {
                    Capsule()
                        .fill(Color.asideIconBackground)
                        .frame(width: 20, height: 4)
                        .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                } else {
                    Capsule().fill(Color.clear).frame(height: 4)
                }
            }
        }
    }

    private var currentQueueView: some View {
        VStack(spacing: 0) {
            if let currentSong = player.currentSong {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey("queue_playing"))
                        .font(.rounded(size: 11, weight: .bold))
                        .foregroundColor(.asideTextSecondary)
                        .tracking(1.5)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)

                    NowPlayingRow(song: currentSong)
                }

                // 分隔线
                Rectangle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.asideSeparator)
                    .frame(height: 0.5)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }

            if !player.upcomingSongs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(format: NSLocalizedString("queue_up_next", comment: ""), player.upcomingSongs.count))
                        .font(.rounded(size: 11, weight: .bold))
                        .foregroundColor(.asideTextSecondary)
                        .tracking(1.5)
                        .padding(.horizontal, 24)

                    ForEach(Array(player.upcomingSongs.enumerated()), id: \.offset) { index, song in
                        let canRemove = player.isUpcomingIndexInUserQueue(at: index)

                        QueueRow(
                            song: song,
                            isCurrent: false,
                            isFromUserQueue: canRemove,
                            action: {
                                player.playFromQueue(song: song)
                            },
                            removeAction: canRemove ? {
                                withAnimation {
                                    player.removeFromUpcoming(at: index)
                                }
                            } : nil
                        )
                    }
                }
            } else if player.currentSong == nil {
                EmptyStateView(text: "queue_empty", icon: .musicNoteList)
            }
        }
    }

    private var historyView: some View {
        Group {
            if player.history.isEmpty {
                EmptyStateView(text: "queue_history_empty", icon: .clock)
            } else {
                ForEach(player.history) { song in
                    HistoryRow(song: song) {
                        player.playFromQueue(song: song)
                    }
                }
            }
        }
    }

    private func modeName(_ mode: PlayerManager.PlayMode) -> String {
        switch mode {
        case .sequence: return NSLocalizedString("mode_sequence", comment: "")
        case .loopSingle: return NSLocalizedString("mode_loop_one", comment: "")
        case .shuffle: return NSLocalizedString("mode_shuffle", comment: "")
        }
    }
}

// MARK: - 正在播放行（高亮）
struct NowPlayingRow: View {
    let song: Song
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var player = PlayerManager.shared

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: song.coverUrl) {
                Color.gray.opacity(0.2)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 52, height: 52)
            .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(song.name)
                    .font(.rounded(size: 16, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(1)
                Text(song.artistName)
                    .font(.rounded(size: 13, weight: .medium))
                    .foregroundColor(.asideTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 2) {
                ForEach(0..<3) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.asideIconBackground)
                        .frame(width: 3, height: player.isPlaying ? CGFloat([8, 14, 10][i]) : 4)
                        .animation(
                            player.isPlaying ?
                                .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.1) :
                                .easeInOut(duration: 0.2),
                            value: player.isPlaying
                        )
                }
            }
            .frame(width: 20)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.asideSeparator.opacity(0.3))
                .padding(.horizontal, 12)
        )
    }
}

// MARK: - 队列行
struct QueueRow: View {
    let song: Song
    let isCurrent: Bool
    var isFromUserQueue: Bool = false
    let action: () -> Void
    var removeAction: (() -> Void)? = nil

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: song.coverUrl) {
                    Color.gray.opacity(0.2)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(song.name)
                            .font(.rounded(size: 15, weight: .medium))
                            .foregroundColor(.asideTextPrimary)
                            .lineLimit(1)

                        if isFromUserQueue {
                            Text(LocalizedStringKey("player_queue"))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.asideIconForeground)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.asideIconBackground.opacity(0.6))
                                .cornerRadius(3)
                        }
                    }
                    Text(song.artistName)
                        .font(.rounded(size: 12, weight: .regular))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if let removeAction = removeAction {
                    Button(action: removeAction) {
                        AsideIcon(icon: .xmark, size: 12, color: .asideTextSecondary.opacity(0.5))
                            .padding(8)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 24)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 历史行
struct HistoryRow: View {
    let song: Song
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: song.coverUrl) {
                    Color.gray.opacity(0.2)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(.rounded(size: 15, weight: .medium))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)
                    Text(song.artistName)
                        .font(.rounded(size: 12, weight: .regular))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                }
                Spacer()
                AsideIcon(icon: .play, size: 24, color: .asideTextSecondary.opacity(0.5))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 24)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 空状态
struct EmptyStateView: View {
    let text: String
    let icon: AsideIcon.IconType

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 100)
            AsideIcon(icon: icon, size: 48, color: .asideTextSecondary.opacity(0.3))
            Text(LocalizedStringKey(text))
                .font(.rounded(size: 16, weight: .medium))
                .foregroundColor(.asideTextSecondary)
            Spacer()
        }
    }
}

// MARK: - 播放模式图标
extension PlayerManager.PlayMode {
    var asideIcon: AsideIcon.IconType {
        switch self {
        case .sequence: return .repeatMode
        case .loopSingle: return .repeatOne
        case .shuffle: return .shuffle
        }
    }
}
