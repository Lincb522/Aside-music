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
            if MangaStyle.isActive {
                MangaRootBackdrop()
            } else if MujiStyle.isActive {
                MujiRootBackdrop()
            } else {
                ThemedPageBackground()
                    .ignoresSafeArea()
            }

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
                .font(MangaStyle.isActive ? MangaStyle.bodyFont(14, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(14, weight: .regular) : .system(size: 14, design: .rounded)))
                .foregroundColor(MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkSoft : .monologueTextSecondary))
                .multilineTextAlignment(.center)
            Button(String(localized: "radio_retry")) {
                viewModel.fetchDetail()
            }
            .font(MangaStyle.isActive ? MangaStyle.labelFont(15, weight: .black) : (MujiStyle.isActive ? MujiStyle.labelFont(15, weight: .semibold) : .system(size: 15, weight: .medium, design: .rounded)))
            .foregroundColor(MangaStyle.isActive ? MangaStyle.strokeInk : (MujiStyle.isActive ? MujiStyle.onTint : .monologueIconForeground))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(MangaStyle.isActive ? MangaStyle.labelYellow : (MujiStyle.isActive ? MujiStyle.clay : Color.monologueIconBackground), in: Capsule())
        }
        .padding(.horizontal, 40)
    }

    // MARK: - 电台头部信息

    private var headerSection: some View {
        VStack(spacing: 16) {
            if let radio = viewModel.radioDetail {
                CachedAsyncImage(url: radio.coverUrl) {
                    RoundedRectangle(cornerRadius: MangaStyle.isActive ? 14 : (MujiStyle.isActive ? 10 : 20))
                        .fill(MangaStyle.isActive ? MangaStyle.paperCool : (MujiStyle.isActive ? MujiStyle.surfaceRaised : Color.monologueGlassTint))
                }
                .frame(width: MangaStyle.isActive ? 150 : 160, height: MangaStyle.isActive ? 150 : 160)
                .clipShape(RoundedRectangle(cornerRadius: MangaStyle.isActive ? 14 : (MujiStyle.isActive ? 10 : 20), style: .continuous))
                .overlay {
                    if MangaStyle.isActive {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                    } else if MujiStyle.isActive {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(MujiStyle.hairline.opacity(0.62), lineWidth: 0.65)
                    }
                }
                .background {
                    if MangaStyle.isActive {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(MangaStyle.strokeInk)
                            .offset(x: 3, y: 3)
                    }
                }
                .shadow(color: .black.opacity((MangaStyle.isActive || MujiStyle.isActive) ? 0.055 : 0.15), radius: (MangaStyle.isActive || MujiStyle.isActive) ? 10 : 12, x: 0, y: (MangaStyle.isActive || MujiStyle.isActive) ? 5 : 6)

                Text(radio.name)
                    .font(MangaStyle.isActive ? MangaStyle.titleFont(24, weight: .black) : (MujiStyle.isActive ? MujiStyle.titleFont(24, weight: .regular) : .system(size: 20, weight: .bold, design: .rounded)))
                    .foregroundColor(MangaStyle.isActive ? MangaStyle.ink : (MujiStyle.isActive ? MujiStyle.ink : .monologueTextPrimary))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                HStack(spacing: 16) {
                    if let dj = radio.dj?.nickname {
                        HStack(spacing: 4) {
                            MonologueIcon(icon: .profile, size: 13, color: MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkSoft : .monologueTextSecondary))
                            Text(dj)
                        }
                            .font(MangaStyle.isActive ? MangaStyle.bodyFont(13, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : .system(size: 13, design: .rounded)))
                            .foregroundColor(MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkSoft : .monologueTextSecondary))
                    }
                    if let count = radio.programCount {
                        HStack(spacing: 4) {
                            MonologueIcon(icon: .podcast, size: 13, color: MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkSoft : .monologueTextSecondary))
                            Text(String(format: String(localized: "radio_episode_count"), count))
                        }
                            .font(MangaStyle.isActive ? MangaStyle.bodyFont(13, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : .system(size: 13, design: .rounded)))
                            .foregroundColor(MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkSoft : .monologueTextSecondary))
                    }
                }

                if let desc = radio.desc, !desc.isEmpty {
                    Text(desc)
                        .font(MangaStyle.isActive ? MangaStyle.bodyFont(13, weight: .bold) : (MujiStyle.isActive ? MujiStyle.bodyFont(13, weight: .regular) : .system(size: 13, design: .rounded)))
                        .foregroundColor(MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkSoft : .monologueTextSecondary))
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
                        if MangaStyle.isActive {
                            MangaLabel(text: String(localized: "radio_mode"), tint: MangaStyle.labelYellow, small: false)
                        } else if MujiStyle.isActive {
                            MujiActionPill(title: String(localized: "radio_mode"), icon: .radio, selected: true, tint: MujiStyle.indigo)
                        } else {
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
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                }
                .padding(.top, 4)

                if MangaStyle.isActive {
                    MangaListDivider()
                        .padding(.top, 6)
                } else if MujiStyle.isActive {
                    MujiListDivider()
                        .padding(.top, 6)
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .background {
            if MangaStyle.isActive && viewModel.radioDetail != nil {
                MangaCardBackground(cornerRadius: 22, elevated: true, tint: MangaStyle.bubbleWhite)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: - 节目列表

    private var programListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.programs.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Text("radio_program_list_title")
                            .font(MujiStyle.isActive ? MujiStyle.titleFont(18, weight: .regular) : .system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(MujiStyle.isActive ? MujiStyle.ink : .monologueTextPrimary)

                        Spacer()

                        Button(action: { viewModel.toggleEpisodeOrder() }) {
                            HStack(spacing: 5) {
                                MonologueIcon(icon: .filter, size: 11, color: MujiStyle.isActive ? MujiStyle.inkSoft : .monologueTextSecondary)
                                Text(
                                    viewModel.isAscendingOrder
                                        ? String(localized: "podcast_sort_oldest")
                                        : String(localized: "podcast_sort_latest")
                                )
                                .font(MujiStyle.isActive ? MujiStyle.labelFont(11, weight: .regular) : .system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(MujiStyle.isActive ? MujiStyle.inkSoft : .monologueTextSecondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(MujiStyle.isActive ? MujiStyle.surface.opacity(0.84) : Color.monologueSeparator.opacity(0.9), in: Capsule())
                            .overlay(Capsule().stroke(MujiStyle.isActive ? MujiStyle.hairline.opacity(0.45) : Color.clear, lineWidth: 0.6))
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

                        Button(action: toggleSearch) {
                            MonologueIcon(
                                icon: isSearchExpanded ? .close : .search,
                                size: 13,
                                color: MujiStyle.isActive ? MujiStyle.inkSoft : .monologueTextSecondary
                            )
                            .frame(width: 32, height: 32)
                            .background(MujiStyle.isActive ? MujiStyle.surface.opacity(0.84) : Color.monologueSeparator.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(MujiStyle.isActive ? MujiStyle.hairline.opacity(0.45) : Color.clear, lineWidth: 0.6)
                            )
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
                            MonologueIcon(icon: .search, size: 14, color: MujiStyle.isActive ? MujiStyle.inkMuted : .monologueTextSecondary)

                            TextField(
                                String(localized: "podcast_episode_search_placeholder"),
                                text: $searchText
                            )
                            .monologueTextInputBehavior()
                            .focused($isSearchFieldFocused)

                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    MonologueIcon(icon: .close, size: 12, color: MujiStyle.isActive ? MujiStyle.inkSoft : .monologueTextSecondary)
                                        .frame(width: 22, height: 22)
                                        .background(MujiStyle.isActive ? MujiStyle.surfaceRaised : Color.monologueSeparator)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(MujiStyle.isActive ? MujiStyle.surface.opacity(0.84) : Color.monologueSeparator.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(MujiStyle.isActive ? MujiStyle.hairline.opacity(0.48) : Color.clear, lineWidth: 0.6)
                        )
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
                    .fill(MujiStyle.isActive ? MujiStyle.surfaceRaised : Color.monologueGlassTint)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                if MujiStyle.isActive {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(MujiStyle.hairline.opacity(0.55), lineWidth: 0.6)
                }
            }
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
                    .font(MujiStyle.isActive ? MujiStyle.bodyFont(14, weight: .regular) : .system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(isCurrentPlaying ? (MujiStyle.isActive ? MujiStyle.clay : .monologueAccentBlue) : (MujiStyle.isActive ? MujiStyle.ink : .monologueTextPrimary))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(String(format: String(localized: "radio_episode_label"), episodeNumber))
                        .font(MujiStyle.isActive ? MujiStyle.labelFont(12, weight: .regular) : .system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(MujiStyle.isActive ? MujiStyle.inkSoft : .monologueTextSecondary)

                    if !program.durationText.isEmpty {
                        Text(program.durationText)
                            .font(MujiStyle.isActive ? MujiStyle.labelFont(12, weight: .regular) : .system(size: 12, design: .rounded))
                            .foregroundColor(MujiStyle.isActive ? MujiStyle.inkSoft : .monologueTextSecondary)
                    }
                    if let listeners = program.listenerCount, listeners > 0 {
                        Text(String(format: String(localized: "radio_play_count"), formatCount(listeners)))
                            .font(MujiStyle.isActive ? MujiStyle.labelFont(12, weight: .regular) : .system(size: 12, design: .rounded))
                            .foregroundColor(MujiStyle.isActive ? MujiStyle.inkSoft : .monologueTextSecondary)
                    }
                }
            }

            Spacer()

            if program.mainSong != nil {
                MonologueIcon(icon: .playCircle, size: 22, color: MujiStyle.isActive ? MujiStyle.inkSoft : .monologueTextSecondary, lineWidth: 1.4)
            } else {
                Text("radio_not_playable")
                    .font(MujiStyle.isActive ? MujiStyle.labelFont(11, weight: .regular) : .system(size: 11, design: .rounded))
                    .foregroundColor(MujiStyle.isActive ? MujiStyle.inkMuted : .monologueTextSecondary.opacity(0.6))
            }
        }
        .padding(.horizontal, MujiStyle.isActive ? 12 : DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, MujiStyle.isActive ? 11 : 10)
        .background {
            if MujiStyle.isActive {
                MujiPaperCardBackground(cornerRadius: 10)
            }
        }
        .padding(.horizontal, MujiStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
        .padding(.vertical, MujiStyle.isActive ? 5 : 0)
        .contentShape(Rectangle())
    }

    private func playProgram(_ program: RadioProgram) {
        let songs = viewModel.songsFromPrograms()
        guard let song = songs.first(where: { $0.id == program.mainSong?.id }) else { return }
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
