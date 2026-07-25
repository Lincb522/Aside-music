import SwiftUI

struct PodcastEpisodeListSheet: View {
    @ObservedObject var viewModel: PodcastPlayerViewModel
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    @State private var isSearchExpanded = false
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        let _ = settings.globalThemeRevision

        VStack(spacing: 0) {
            headerSection

            Rectangle()
                .fill(separatorColor)
                .frame(height: 0.5)

            if viewModel.programs.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteIconBadge(icon: .micSlash, size: 54)
                    } else {
                        MonologueIcon(icon: .micSlash, size: 44, color: secondaryTextColor.opacity(0.38))
                    }
                    Text("radio_no_programs")
                        .font(emptyFont)
                        .foregroundColor(secondaryTextColor)
                }
                .padding(.vertical, 44)
                .frame(maxWidth: .infinity)
                .background {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.cardRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    }
                }
                .padding(.horizontal, MinimalWhiteStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
                Spacer()
            } else if filteredPrograms.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteIconBadge(icon: .search, size: 54)
                    } else {
                        MonologueIcon(icon: .search, size: 40, color: secondaryTextColor.opacity(0.38))
                    }
                    Text("podcast_episode_search_empty")
                        .font(emptyFont)
                        .foregroundColor(secondaryTextColor)
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .background {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.cardRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    }
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            Color.clear
                                .frame(height: 0)
                                .id("episode-list-top")

                            ForEach(filteredPrograms, id: \.program.id) { item in
                                let index = item.index
                                let program = item.program

                                episodeRow(program: program, index: index)
                                    .onTapWithHaptic {
                                        viewModel.playProgramAt(index: index)
                                        dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
                                    }

                                if program.id == filteredPrograms.last?.program.id {
                                    Color.clear
                                        .frame(height: 1)
                                        .onAppear { loadMoreIfNeededForSearch() }
                                }
                            }

                            if viewModel.isLoadingMore {
                                HStack(spacing: 8) {
                                    ProgressView().scaleEffect(0.8)
                                    Text("mv_loading_more")
                                        .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(13, weight: .regular) : .rounded(size: 13))
                                        .foregroundColor(secondaryTextColor)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            }

                            if !viewModel.hasMore && !viewModel.programs.isEmpty {
                                NoMoreDataView()
                            }
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 30)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                    .onChange(of: isSearchExpanded) { _, isExpanded in
                        guard isExpanded else { return }
                        scrollToTop(with: proxy)
                    }
                    .onChange(of: searchText) { _, _ in
                        scrollToTop(with: proxy)
                        loadAllProgramsForSearchIfNeeded()
                    }
                }
            }
        }
        .background {
            if NeumorphicStyle.isActive {
                Color.clear
            } else if SequoiaStyle.isActive {
                Color.clear
            } else if MinimalWhiteStyle.isActive {
                Color.clear
            } else {
                Rectangle()
                    .fill(Color.monologueGlassTint)
                    .monologueGlass(cornerRadius: 20)
            }
        }
        .ignoresSafeArea(edges: .bottom)
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
        .onChange(of: viewModel.programs.count) { _, _ in
            loadAllProgramsForSearchIfNeeded()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                if let radio = viewModel.radioDetail {
                    CachedAsyncImage(url: radio.coverUrl) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(coverPlaceholderFill)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        if MinimalWhiteStyle.isActive {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.radioDetail?.name ?? String(localized: "radio_program_list"))
                        .font(headerTitleFont)
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)

                    if let program = viewModel.currentProgram {
                        HStack(spacing: 6) {
                            if viewModel.isRadioPlaying {
                                miniWaveform
                            }
                            Text(program.name ?? String(localized: "radio_unknown_program"))
                                .font(headerCaptionFont)
                                .foregroundColor(secondaryTextColor)
                                .lineLimit(1)
                        }
                    } else if let count = viewModel.radioDetail?.programCount {
                        Text(String(format: String(localized: "radio_total_episodes"), count))
                            .font(headerCaptionFont)
                            .foregroundColor(secondaryTextColor)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: { viewModel.toggleEpisodeOrder() }) {
                        HStack(spacing: 5) {
                            MonologueIcon(icon: .filter, size: 11, color: controlColor)

                            Text(
                                viewModel.isAscendingOrder
                                    ? String(localized: "podcast_sort_oldest")
                                    : String(localized: "podcast_sort_latest")
                            )
                            .font(controlFont)
                            .foregroundColor(controlColor)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .frame(height: 32)
                        .padding(.horizontal, 10)
                        .background {
                            podcastControlBackground(cornerRadius: 16)
                        }
                        .clipShape(Capsule())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

                    Button(action: toggleSearch) {
                        MonologueIcon(
                            icon: isSearchExpanded ? .close : .search,
                            size: 13,
                            color: controlColor
                        )
                        .frame(width: 32, height: 32)
                        .background {
                            podcastControlBackground(cornerRadius: 16)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
                    .accessibilityLabel(
                        isSearchExpanded
                            ? String(localized: "podcast_search_cancel")
                            : String(localized: "tab_search")
                    )

                    if let count = viewModel.radioDetail?.programCount {
                        HStack(spacing: 2) {
                            Text("\(count)")
                                .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(11, weight: .semibold) : .rounded(size: 11, weight: .semibold))
                                .foregroundColor(primaryTextColor)
                                .monospacedDigit()
                                .lineLimit(1)

                            Text("radio_episode_unit")
                                .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(10, weight: .medium) : .rounded(size: 10, weight: .medium))
                                .foregroundColor(secondaryTextColor)
                                .lineLimit(1)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(height: 32)
                        .padding(.horizontal, 9)
                        .background {
                            podcastControlBackground(cornerRadius: 16)
                        }
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            if isSearchExpanded {
                HStack(spacing: 10) {
                    MonologueIcon(icon: .search, size: 14, color: controlColor)

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
                        MonologueIcon(icon: .close, size: 12, color: controlColor)
                            .frame(width: 22, height: 22)
                            .background(searchCloseBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true)
                    } else if SequoiaStyle.isActive {
                        SequoiaSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, role: .list)
                    } else if MinimalWhiteStyle.isActive {
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.cardRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    } else {
                        Color.monologueSeparator.opacity(0.85)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: NeumorphicStyle.isActive ? 16 : 14, style: .continuous))
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.bottom, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                Color.clear
                    .frame(height: 0)
                    .padding(.bottom, 14)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isSearchExpanded)
    }

    // MARK: - Episode Row

    private func episodeRow(program: RadioProgram, index: Int) -> some View {
        let isCurrent = index == viewModel.currentProgramIndex
            && viewModel.isOwnContent
            && player.currentSong?.id == program.mainSong?.id
        let episodeNumber = viewModel.displayEpisodeNumber(for: program, at: index)

        return HStack(spacing: 14) {
            ZStack {
                if isCurrent && viewModel.isRadioPlaying {
                    miniWaveform
                } else if isCurrent {
                    MonologueIcon(icon: .pause, size: 14, color: activeTint, lineWidth: 1.6)
                } else {
                    Text("\(episodeNumber)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(secondaryTextColor.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .allowsTightening(true)
                }
            }
            .frame(width: 42, alignment: .trailing)

            VStack(alignment: .leading, spacing: 3) {
                highlightedTitle(for: program)
                    .font(episodeTitleFont(isCurrent: isCurrent))
                    .foregroundColor(isCurrent ? activeTint : primaryTextColor)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let episodeLabel = matchedEpisodeLabel(for: program, index: index) {
                        Text(episodeLabel)
                            .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(11, weight: .semibold) : .rounded(size: 11, weight: .semibold))
                            .foregroundColor(activeTint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(activeTint.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    if !program.durationText.isEmpty {
                        Text(program.durationText)
                            .font(metaFont)
                            .foregroundColor(secondaryTextColor.opacity(0.78))
                    }
                    if let listeners = program.listenerCount, listeners > 0 {
                        Circle()
                            .fill(secondaryTextColor.opacity(0.32))
                            .frame(width: 3, height: 3)
                        Text("\(formatCount(listeners))" + String(localized: "radio_play_suffix"))
                            .font(metaFont)
                            .foregroundColor(secondaryTextColor.opacity(0.78))
                    }
                }
            }

            Spacer(minLength: 0)

            if isCurrent {
                Text("radio_now_playing")
                    .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(10, weight: .semibold) : .rounded(size: 10, weight: .semibold))
                    .foregroundColor(activeTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(activeTint.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .background {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteSurfaceBackground(
                    cornerRadius: MinimalWhiteStyle.cardRadius,
                    elevated: isCurrent,
                    tint: isCurrent ? MinimalWhiteStyle.glassStrongFill : MinimalWhiteStyle.glassFill
                )
            }
        }
        .padding(.horizontal, MinimalWhiteStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func podcastControlBackground(cornerRadius: CGFloat) -> some View {
        if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(cornerRadius: cornerRadius, elevated: false, pressed: true, lightweight: true)
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(cornerRadius: cornerRadius, elevated: false, pressed: true, role: .list)
        } else if MinimalWhiteStyle.isActive {
            MinimalWhiteCapsuleBackground()
        } else {
            Color.monologueSeparator.opacity(0.9)
        }
    }

    // MARK: - Helpers

    private var miniWaveform: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(activeTint)
                    .frame(width: 2, height: viewModel.isRadioPlaying ? CGFloat([5, 10, 7][i]) : 3)
                    .animation(
                        .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.12),
                        value: viewModel.isRadioPlaying
                    )
            }
        }
        .frame(height: 10)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: String(localized: "count_hundred_million"), Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: String(localized: "count_ten_thousand"), Double(count) / 10_000)
        }
        return "\(count)"
    }

    private var searchKeyword: String {
        searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private var filteredPrograms: [(index: Int, program: RadioProgram)] {
        let allPrograms = Array(viewModel.orderedPrograms.enumerated()).map { (index: $0.offset, program: $0.element) }
        guard !searchKeyword.isEmpty else { return allPrograms }

        return allPrograms.filter { item in
            matchesSearch(for: item.program, index: item.index)
        }
    }

    private func matchesSearch(for program: RadioProgram, index: Int) -> Bool {
        let episodeIndex = viewModel.displayEpisodeNumber(for: program, at: index)
        let normalizedTitle = (program.name ?? "").lowercased()
        let query = searchKeyword

        var candidates: [String] = [
            normalizedTitle,
            "\(episodeIndex)",
            "ep\(episodeIndex)",
            "episode \(episodeIndex)",
            L10n.format("radio_episode_number_format", episodeIndex),
            L10n.format("radio_episode_part_format", episodeIndex)
        ]

        if let serialNumber = program.serialNum {
            candidates.append("\(serialNumber)")
            candidates.append("ep\(serialNumber)")
            candidates.append("episode \(serialNumber)")
            candidates.append(L10n.format("radio_episode_number_format", serialNumber))
            candidates.append(L10n.format("radio_episode_part_format", serialNumber))
        }

        return candidates.contains { !$0.isEmpty && $0.contains(query) }
    }

    private func highlightedTitle(for program: RadioProgram) -> Text {
        let title = program.name ?? String(localized: "radio_unknown_program")
        guard !searchKeyword.isEmpty else { return Text(title) }

        let lowercasedTitle = title.lowercased()
        guard let range = lowercasedTitle.range(of: searchKeyword) else { return Text(title) }

        var attributedTitle = AttributedString(title)
        if let attributedRange = Range(range, in: attributedTitle) {
            attributedTitle[attributedRange].foregroundColor = UIColor(activeTint)
        }

        return Text(attributedTitle)
    }

    private func matchedEpisodeLabel(for program: RadioProgram, index: Int) -> String? {
        guard !searchKeyword.isEmpty else { return nil }

        let displayIndex = viewModel.displayEpisodeNumber(for: program, at: index)
        let candidates = [
            (L10n.format("radio_episode_number_format", displayIndex), "\(displayIndex)"),
            ("EP \(displayIndex)", "ep\(displayIndex)")
        ]

        if let serialNumber = program.serialNum {
            let serialCandidates = [
                (L10n.format("radio_episode_number_format", serialNumber), "\(serialNumber)"),
                ("EP \(serialNumber)", "ep\(serialNumber)")
            ]

            for candidate in serialCandidates where candidate.0.lowercased().contains(searchKeyword) || candidate.1.contains(searchKeyword) {
                return candidate.0
            }
        }

        for candidate in candidates where candidate.0.lowercased().contains(searchKeyword) || candidate.1.contains(searchKeyword) {
            return candidate.0
        }

        return nil
    }

    private func scrollToTop(with proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("episode-list-top", anchor: .top)
            }
        }
    }

    private func loadMoreIfNeededForSearch() {
        guard viewModel.hasMore, !viewModel.isLoadingMore else { return }
        viewModel.loadMorePrograms()
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

    private var activeTint: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        return .monologueAccent
    }

    private var primaryTextColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        return .monologueTextPrimary
    }

    private var secondaryTextColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        return .monologueTextSecondary
    }

    private var controlColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        return .monologueTextSecondary
    }

    private var separatorColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(0.42) }
        if SequoiaStyle.isActive { return SequoiaStyle.separator.opacity(0.72) }
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.hairline }
        return Color.monologueSeparator
    }

    private var coverPlaceholderFill: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.controlGlassFill }
        return SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monologueTextSecondary.opacity(0.08)
    }

    private var searchCloseBackground: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if SequoiaStyle.isActive { return SequoiaStyle.materialPressed }
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.controlGlassFill }
        return Color.monologueSeparator
    }

    private var headerTitleFont: Font {
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(17, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.titleFont(17, weight: .semibold) }
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.titleFont(17, weight: .semibold) }
        return .rounded(size: 17, weight: .bold)
    }

    private var headerCaptionFont: Font {
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .regular) }
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.labelFont(13, weight: .regular) }
        return .rounded(size: 13)
    }

    private var controlFont: Font {
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(11, weight: .medium) }
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.labelFont(11, weight: .medium) }
        return .rounded(size: 11, weight: .medium)
    }

    private var emptyFont: Font {
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(15, weight: .medium) }
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.labelFont(14, weight: .medium) }
        return .rounded(size: 15, weight: .medium)
    }

    private var metaFont: Font {
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(11, weight: .regular) }
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.labelFont(11, weight: .regular) }
        return .rounded(size: 11)
    }

    private func episodeTitleFont(isCurrent: Bool) -> Font {
        if SequoiaStyle.isActive { return SequoiaStyle.bodyFont(15, weight: isCurrent ? .semibold : .regular) }
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.bodyFont(15, weight: isCurrent ? .medium : .regular) }
        return .rounded(size: 15, weight: isCurrent ? .semibold : .regular)
    }
}
