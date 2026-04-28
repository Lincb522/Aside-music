import SwiftUI

/// 电台专属播放列表弹窗 — 独立于音乐播放列表
struct PodcastPlaylistPopupView: View {
    @ObservedObject private var player = PlayerManager.shared
    @State private var searchText = ""
    @State private var isSearchExpanded = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.top, 24)
                .padding(.bottom, 14)

            if isSearchExpanded {
                searchFieldView
            }

            Rectangle()
                .fill(Color.monologueSeparator)
                .frame(height: 0.5)

            if player.context.isEmpty {
                emptyView
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(queueItems) { item in
                            PodcastQueueRow(
                                song: item.song,
                                role: item.role,
                                radioName: item.song.podcastRadioName,
                                action: {
                                    player.playFromQueue(song: item.song)
                                },
                                removeAction: item.role == .current ? nil : {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        player.removeFromContext(songID: item.song.id)
                                    }
                                }
                            )
                            .id(item.id)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(
                                EdgeInsets(
                                    top: 4,
                                    leading: DeviceLayout.viewHorizontalPadding,
                                    bottom: 4,
                                    trailing: DeviceLayout.viewHorizontalPadding
                                )
                            )
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .onAppear { scrollToCurrent(proxy: proxy, animated: false) }
                    .onChange(of: player.currentSong?.id) { _, _ in
                        scrollToCurrent(proxy: proxy)
                    }
                }
            }
        }
        .background(Color.clear)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(radioName)
                    .font(.rounded(size: 18, weight: .bold))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(1)

                Text(String(format: String(localized: "podcast_playlist_count"), player.context.count))
                    .font(.rounded(size: 13, weight: .medium))
                    .foregroundColor(.monologueTextSecondary)
            }

            Spacer()

            // 播放模式与搜索按钮
            HStack(spacing: 8) {
                // 搜索按钮
                Button(action: toggleSearch) {
                    MonologueIcon(
                        icon: isSearchExpanded ? .close : .search,
                        size: 14,
                        color: .monologueTextSecondary
                    )
                    .frame(width: 32, height: 32)
                    .background(Color.monologueSeparator.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))

                // 播放模式
                HStack(spacing: 6) {
                    MonologueIcon(icon: .repeatMode, size: 16, color: .monologueTextSecondary)
                    Text(NSLocalizedString("mode_sequence", comment: ""))
                        .font(.rounded(size: 14, weight: .medium))
                }
                .foregroundColor(.monologueTextSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.monologueSeparator)
                )
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    private var searchFieldView: some View {
        HStack(spacing: 10) {
            MonologueIcon(icon: .search, size: 14, color: .monologueTextSecondary)

            TextField(
                String(localized: "podcast_episode_search_placeholder"),
                text: $searchText
            )
            .monologueTextInputBehavior()
            .focused($isSearchFieldFocused)

            Button {
                if searchText.isEmpty {
                    toggleSearch()
                } else {
                    searchText = ""
                }
            } label: {
                MonologueIcon(icon: .close, size: 12, color: .monologueTextSecondary)
                    .frame(width: 22, height: 22)
                    .background(Color.monologueSeparator)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.monologueSeparator.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, 12)
    }

    private func toggleSearch() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            isSearchExpanded.toggle()
            if isSearchExpanded {
                isSearchFieldFocused = true
            } else {
                searchText = ""
                isSearchFieldFocused = false
            }
        }
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 100)
            MonologueIcon(icon: .radio, size: 48, color: .monologueTextSecondary.opacity(0.3))
            Text(LocalizedStringKey("podcast_playlist_empty"))
                .font(.rounded(size: 16, weight: .medium))
                .foregroundColor(.monologueTextSecondary)
            Spacer()
        }
    }

    // MARK: - Data

    private var radioName: String {
        if case .podcast = player.playSource {
            return player.currentSong?.podcastRadioName
                ?? player.context.first?.podcastRadioName
                ?? String(localized: "radio_program_list")
        }
        return String(localized: "radio_program_list")
    }

    fileprivate struct QueueItem: Identifiable {
        enum Role { case played, current, upcoming }
        let song: Song
        let role: Role
        let originalIndex: Int
        var id: Int { song.id }
    }

    private var queueItems: [QueueItem] {
        let rawList = player.context
        let list = rawList.filter { $0.podcastRadioId != nil }
        guard !list.isEmpty else { return [] }

        let currentIndex: Int
        if let currentSong = player.currentSong,
           let matchedIndex = list.firstIndex(where: { $0.id == currentSong.id }) {
            currentIndex = matchedIndex
        } else if list.indices.contains(player.contextIndex) {
            currentIndex = player.contextIndex
        } else {
            currentIndex = 0
        }

        let items = list.enumerated().map { index, song in
            let role: QueueItem.Role
            if index < currentIndex {
                role = .played
            } else if index == currentIndex {
                role = .current
            } else {
                role = .upcoming
            }
            return QueueItem(song: song, role: role, originalIndex: index)
        }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if keyword.isEmpty {
            return items
        }

        return items.filter { item in
            matchesSearch(for: item.song, index: item.originalIndex, searchKeyword: keyword)
        }
    }

    private func matchesSearch(for song: Song, index: Int, searchKeyword: String) -> Bool {
        let isAscending = UserDefaults.standard.bool(forKey: AppConfig.StorageKeys.podcastSortAscending)
        let totalCount = player.context.count
        let displayEpisodeNumber = isAscending ? (index + 1) : max(totalCount - index, 1)

        let normalizedTitle = (song.name).lowercased()
        var candidates: [String] = [
            normalizedTitle,
            "\(displayEpisodeNumber)",
            "ep\(displayEpisodeNumber)",
            "episode \(displayEpisodeNumber)",
            String(localized: "第\(displayEpisodeNumber)期"),
            String(localized: "第\(displayEpisodeNumber)集")
        ]

        return candidates.contains { !$0.isEmpty && $0.contains(searchKeyword) }
    }


    private func scrollToCurrent(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let id = player.currentSong?.id else { return }
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.22)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            } else {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }
}

// MARK: - Podcast Queue Row

private struct PodcastQueueRow: View {
    let song: Song
    let role: PodcastPlaylistPopupView.QueueItem.Role
    let radioName: String?
    let action: () -> Void
    var removeAction: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var player = PlayerManager.shared

    private var isCurrent: Bool { role == .current }
    private var isPlayed: Bool { role == .played }

    @ViewBuilder
    private var leadingIndicator: some View {
        switch role {
        case .current:
            PlayingVisualizerView(isAnimating: player.isPlaying, color: .monologueAccentBlue)
                .frame(width: 18, height: 18)
        case .played:
            MonologueIcon(icon: .history, size: 12, color: .monologueTextSecondary.opacity(0.58), lineWidth: 1.5)
                .frame(width: 18, height: 18)
        case .upcoming:
            MonologueIcon(icon: .play, size: 12, color: .monologueTextSecondary.opacity(0.38), lineWidth: 1.5)
                .frame(width: 18, height: 18)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: action) {
                HStack(spacing: 12) {
                    leadingIndicator

                    CachedAsyncImage(url: song.coverUrl) {
                        Color.gray.opacity(0.2)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 46, height: 46)
                    .clipShape(.rect(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.name)
                            .font(.rounded(size: 15, weight: isCurrent ? .bold : .medium))
                            .foregroundColor(
                                isCurrent
                                    ? .monologueAccentBlue
                                    : .monologueTextPrimary.opacity(isPlayed ? 0.72 : 1)
                            )
                            .lineLimit(1)

                        if let radioName, !radioName.isEmpty {
                            Text(radioName)
                                .font(.rounded(size: 12, weight: .medium))
                                .foregroundColor(.monologueTextSecondary.opacity(isPlayed ? 0.7 : 1))
                                .lineLimit(1)
                        } else {
                            Text(song.artistName)
                                .font(.rounded(size: 12, weight: .medium))
                                .foregroundColor(.monologueTextSecondary.opacity(isPlayed ? 0.7 : 1))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if let removeAction, !isCurrent {
                Button(action: removeAction) {
                    MonologueIcon(icon: .xmark, size: 11, color: .monologueTextSecondary.opacity(0.5), lineWidth: 1.6)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isCurrent
                        ? (colorScheme == .dark ? Color.monologueAccentBlue.opacity(0.14) : Color.monologueAccentBlue.opacity(0.08))
                        : Color.monologueSeparator.opacity(colorScheme == .dark ? 0.14 : 0.22)
                )
                .monologueGlassConditional(isActive: isCurrent, cornerRadius: 14)
        }
        .opacity(isPlayed ? 0.78 : 1)
    }
}
