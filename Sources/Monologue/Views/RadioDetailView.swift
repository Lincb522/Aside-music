import SwiftUI

/// 电台详情页面，展示电台信息和节目列表
struct RadioDetailView: View {
    let radioId: Int
    @State private var viewModel: RadioDetailViewModel
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var subManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showRadioPlayer = false
    @State private var isSearchExpanded = false
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool

    init(radioId: Int) {
        self.radioId = radioId
        _viewModel = State(initialValue: RadioDetailViewModel(radioId: radioId))
    }

    var body: some View {
        ZStack {
            MonologueBackground()
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.radioDetail == nil {
                MonologueLoadingView(text: "LOADING")
            } else if let error = viewModel.errorMessage, viewModel.radioDetail == nil {
                errorView(error)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        headerSection
                        programListSection
                    }
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            if viewModel.radioDetail == nil {
                viewModel.fetchDetail()
            }
        }
        .onChange(of: isSearchExpanded) { _, isExpanded in
            if isExpanded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isSearchFieldFocused = true
                }
            } else {
                searchText = ""
                isSearchFieldFocused = false
            }
        }
        .onChange(of: searchText) { _, _ in
            loadAllProgramsForSearchIfNeeded()
        }
        .onChange(of: viewModel.programs.count) { _, _ in
            loadAllProgramsForSearchIfNeeded()
        }
        .fullScreenCover(isPresented: $showRadioPlayer) {
            PodcastPlayerView(radioId: radioId)
        }
    }

    // MARK: - 错误视图

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            MonologueIcon(icon: .warning, size: 40, color: .monologueTextSecondary)
            Text(error)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "radio_retry")) {
                viewModel.fetchDetail()
            }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(.monologueIconForeground)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color.monologueIconBackground)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 40)
    }

    // MARK: - 电台头部信息

    private var headerSection: some View {
        VStack(spacing: 16) {
            if let radio = viewModel.radioDetail {
                CachedAsyncImage(url: radio.coverUrl) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.monologueGlassTint)
                }
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)

                Text(radio.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                HStack(spacing: 16) {
                    if let dj = radio.dj?.nickname {
                        HStack(spacing: 4) {
                            MonologueIcon(icon: .profile, size: 13, color: .monologueTextSecondary)
                            Text(dj)
                        }
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                    if let count = radio.programCount {
                        HStack(spacing: 4) {
                            MonologueIcon(icon: .podcast, size: 13, color: .monologueTextSecondary)
                            Text(String(format: String(localized: "radio_episode_count"), count))
                        }
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                }

                if let desc = radio.desc, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // 操作按钮
                HStack(spacing: 12) {
                    // 订阅按钮
                    SubscribeButton(
                        isSubscribed: subManager.isRadioSubscribed(radio.id),
                        action: { subManager.toggleRadioSubscription(radio) }
                    )

                    // 收音机模式播放按钮
                    Button(action: { showRadioPlayer = true }) {
                        HStack(spacing: 8) {
                            MonologueIcon(icon: .radio, size: 16, color: .monologueIconForeground, lineWidth: 1.4)
                            Text("radio_mode")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.monologueIconForeground)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.monologueIconBackground)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    // MARK: - 节目列表

    private var programListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.programs.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Text("radio_program_list_title")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.monologueTextPrimary)

                        Spacer()

                        Button(action: { viewModel.toggleEpisodeOrder() }) {
                            HStack(spacing: 5) {
                                MonologueIcon(icon: .filter, size: 11, color: .monologueTextSecondary)
                                Text(
                                    viewModel.isAscendingOrder
                                        ? String(localized: "podcast_sort_oldest")
                                        : String(localized: "podcast_sort_latest")
                                )
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.monologueTextSecondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.monologueSeparator.opacity(0.9))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

                        Button(action: toggleSearch) {
                            MonologueIcon(
                                icon: isSearchExpanded ? .close : .search,
                                size: 13,
                                color: .monologueTextSecondary
                            )
                            .frame(width: 32, height: 32)
                            .background(Color.monologueSeparator.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
                        .accessibilityLabel(
                            isSearchExpanded
                                ? String(localized: "podcast_search_cancel")
                                : String(localized: "tab_search")
                        )
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                    if isSearchExpanded {
                        HStack(spacing: 10) {
                            MonologueIcon(icon: .search, size: 14, color: .monologueTextSecondary)

                            TextField(
                                String(localized: "podcast_episode_search_placeholder"),
                                text: $searchText
                            )
                            .monologueTextInputBehavior()
                            .focused($isSearchFieldFocused)

                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    MonologueIcon(icon: .close, size: 12, color: .monologueTextSecondary)
                                        .frame(width: 22, height: 22)
                                        .background(Color.monologueSeparator)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.monologueSeparator.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 10)
                    }
                }
                .padding(.bottom, 12)
            }

            LazyVStack(spacing: 0) {
                if filteredOrderedPrograms.isEmpty && !searchKeyword.isEmpty {
                    VStack(spacing: 12) {
                        MonologueIcon(icon: .search, size: 36, color: .monologueTextSecondary.opacity(0.3))
                        Text("podcast_episode_search_empty")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                }

                ForEach(Array(filteredOrderedPrograms.enumerated()), id: \.element.id) { index, program in
                    programRow(program: program, index: index)
                        .onTapWithHaptic {
                            playProgram(program)
                        }

                    if program.id == filteredOrderedPrograms.last?.id {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                if searchKeyword.isEmpty {
                                    viewModel.loadMorePrograms()
                                } else {
                                    loadAllProgramsForSearchIfNeeded()
                                }
                            }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 16)
                }

                if !viewModel.hasMore && !viewModel.programs.isEmpty {
                    NoMoreDataView()
                }
            }
        }
    }

    // MARK: - 节目行

    /// 当前 player 是否正在播放本电台的内容
    private var isOwnContent: Bool {
        if case .podcast(let id) = player.playSource, id == radioId {
            return true
        }
        return false
    }

    private func programRow(program: RadioProgram, index: Int) -> some View {
        let isCurrentPlaying = isOwnContent && player.currentSong?.id == program.mainSong?.id && player.isPlaying
        let episodeNumber = displayEpisodeNumber(for: index)

        return HStack(spacing: 14) {
            CachedAsyncImage(url: program.programCoverUrl) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.monologueGlassTint)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                Group {
                    if isCurrentPlaying {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                        MonologueIcon(icon: .waveform, size: 16, color: .white, lineWidth: 1.6)
                    }
                }
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(program.name ?? String(localized: "radio_unknown_program"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(isCurrentPlaying ? .monologueAccentBlue : .monologueTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(String(format: String(localized: "radio_episode_label"), episodeNumber))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)

                    if !program.durationText.isEmpty {
                        Text(program.durationText)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                    if let listeners = program.listenerCount, listeners > 0 {
                        Text(String(format: String(localized: "radio_play_count"), formatCount(listeners)))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                }
            }

            Spacer()

            if program.mainSong != nil {
                MonologueIcon(icon: .playCircle, size: 22, color: .monologueTextSecondary, lineWidth: 1.4)
            } else {
                Text("radio_not_playable")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.monologueTextSecondary.opacity(0.6))
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func playProgram(_ program: RadioProgram) {
        guard let song = program.mainSong else { return }
        let songs = viewModel.songsFromPrograms()
        player.playPodcast(song: song, in: songs, radioId: radioId)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: String(localized: "%.1f亿"), Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: String(localized: "%.1f万"), Double(count) / 10_000)
        }
        return "\(count)"
    }

    private var searchKeyword: String {
        searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private var filteredOrderedPrograms: [RadioProgram] {
        let programs = viewModel.orderedPrograms
        guard !searchKeyword.isEmpty else { return programs }

        return programs.enumerated().compactMap { index, program in
            matchesSearch(for: program, index: index) ? program : nil
        }
    }

    private func matchesSearch(for program: RadioProgram, index: Int) -> Bool {
        let episodeNumber = displayEpisodeNumber(for: index)
        let normalizedTitle = (program.name ?? "").lowercased()
        var candidates: [String] = [
            normalizedTitle,
            "\(episodeNumber)",
            "ep\(episodeNumber)",
            "episode \(episodeNumber)",
            String(localized: "第\(episodeNumber)期"),
            String(localized: "第\(episodeNumber)集")
        ]

        if let serialNumber = program.serialNum {
            candidates.append("\(serialNumber)")
            candidates.append("ep\(serialNumber)")
            candidates.append("episode \(serialNumber)")
            candidates.append(String(localized: "第\(serialNumber)期"))
            candidates.append(String(localized: "第\(serialNumber)集"))
        }

        return candidates.contains { !$0.isEmpty && $0.contains(searchKeyword) }
    }

    private func displayEpisodeNumber(for index: Int) -> Int {
        viewModel.displayEpisodeNumber(at: index)
    }

    private func loadAllProgramsForSearchIfNeeded() {
        guard !searchKeyword.isEmpty, viewModel.hasMore, !viewModel.isLoadingMore else { return }
        viewModel.loadMorePrograms()
    }

    private func toggleSearch() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            isSearchExpanded.toggle()
        }
    }
}
