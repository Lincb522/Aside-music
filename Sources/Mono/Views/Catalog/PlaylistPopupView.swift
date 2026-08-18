import SwiftUI

private enum QueuePopupPalette {
    /// aside 默认主题（编辑部风格分支）
    static var isAside: Bool {
        GlobalThemeId.persistedOrDefault == .default
    }

    static var accent: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.dogOrange }
        if PureWhiteStyle.isActive { return PureWhiteStyle.accent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if CapsuleStyle.isActive { return CapsuleStyle.accent }
        return .monoAccent
    }

    static var accentForeground: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.onAccent }
        if PetWhiteStyle.isActive { return PetWhiteStyle.onAccent }
        if PureWhiteStyle.isActive { return PureWhiteStyle.onAccent }
        if NeumorphicStyle.isActive {
            return ThemeColorCustomization.readableForegroundColor(
                on: NeumorphicStyle.accent,
                light: Color(hex: "172026"),
                dark: .white
            )
        }
        if CapsuleStyle.isActive {
            return CapsuleStyle.onAccent
        }
        return .monoIconForeground
    }

    static var primaryText: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if PureWhiteStyle.isActive { return PureWhiteStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        return .monoTextPrimary
    }

    static var secondaryText: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkSoft }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
        if PureWhiteStyle.isActive { return PureWhiteStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
        return .monoTextSecondary
    }

    static var mutedText: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkMuted }
        if PureWhiteStyle.isActive { return PureWhiteStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        if CapsuleStyle.isActive { return CapsuleStyle.inkMuted }
        return .monoTextSecondary
    }

    static var separator: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.hairline }
        if PetWhiteStyle.isActive { return PetWhiteStyle.separator }
        if PureWhiteStyle.isActive { return PureWhiteStyle.separator }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator }
        if CapsuleStyle.isActive { return CapsuleStyle.separator }
        return .monoSeparator
    }

    static var pressedSurface: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.controlGlassFill }
        if PetWhiteStyle.isActive { return PetWhiteStyle.surfacePressed }
        if PureWhiteStyle.isActive { return PureWhiteStyle.surfaceTint }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if CapsuleStyle.isActive { return CapsuleStyle.surfaceTint }
        return .monoSeparator
    }
}

struct PlaylistPopupView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedTab = 0 // 0: 总览, 1: 历史
    @Namespace private var namespace

    fileprivate struct LinearQueueItem: Identifiable {
        enum Role {
            case played
            case current
            case upcoming
        }

        let song: Song
        let role: Role

        var id: Int { song.id }
    }

    private var linearQueueItems: [LinearQueueItem] {
        let rawList = player.currentContextList
        let list = rawList.filter { $0.podcastRadioId == nil }
        guard !list.isEmpty else { return [] }

        let currentIndex: Int
        if let currentSong = player.currentSong,
           let matchedIndex = list.firstIndex(where: { $0.id == currentSong.id }) {
            currentIndex = matchedIndex
        } else if list.indices.contains(player.currentIndexInContext) {
            currentIndex = player.currentIndexInContext
        } else {
            currentIndex = 0
        }

        return list.enumerated().map { index, song in
            let role: LinearQueueItem.Role
            if index < currentIndex {
                role = .played
            } else if index == currentIndex {
                role = .current
            } else {
                role = .upcoming
            }
            return LinearQueueItem(song: song, role: role)
        }
    }

    private var hasLinearQueueContent: Bool {
        !linearQueueItems.isEmpty
    }

    private var upcomingStartIndex: Int {
        if let currentIndex = linearQueueItems.firstIndex(where: { $0.role == .current }) {
            return currentIndex + 1
        }
        return linearQueueItems.count
    }

    /// 待播统计：曲目数 + 总时长（无待播时为 nil）
    private var upcomingStatsText: String? {
        let upcoming = player.contextRemainingSongs.filter { $0.podcastRadioId == nil }
        guard !upcoming.isEmpty else { return nil }

        let totalSeconds = upcoming.reduce(0) { $0 + (($1.dt ?? 0) / 1000) }
        let countText = String(format: NSLocalizedString("queue_upcoming_count", comment: ""), upcoming.count)
        guard totalSeconds >= 60 else { return countText }

        let minutes = totalSeconds / 60
        let durationText: String
        if minutes >= 60 {
            durationText = String(format: NSLocalizedString("queue_duration_hours", comment: ""), minutes / 60, minutes % 60)
        } else {
            durationText = String(format: NSLocalizedString("queue_duration_minutes", comment: ""), minutes)
        }
        return "\(countText) · \(durationText)"
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        VStack(spacing: 0) {
            headerView
                .padding(.top, MinimalWhiteStyle.isActive ? 18 : 24)
                .padding(.bottom, MinimalWhiteStyle.isActive ? 14 : 16)

            if selectedTab == 0 {
                currentQueueView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        historyView
                    }
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: MinimalWhiteStyle.isActive ? 10 : 0) {
            HStack(spacing: MinimalWhiteStyle.isActive ? 4 : 24) {
                tabButton(title: "queue_tab_now_playing", tabIndex: 0)
                tabButton(title: "queue_tab_history", tabIndex: 1)
            }
            .padding(.horizontal, MinimalWhiteStyle.isActive ? 5 : 0)
            .padding(.vertical, MinimalWhiteStyle.isActive ? 5 : 0)
            .background {
                if MinimalWhiteStyle.isActive {
                    MinimalWhiteSurfaceBackground(
                        cornerRadius: MinimalWhiteStyle.chromeRadius,
                        elevated: false,
                        tint: MinimalWhiteStyle.glassFill
                    )
                }
            }

            Spacer()

            Button(action: { player.switchMode() }) {
                HStack(spacing: 6) {
                    MonoIcon(
                        icon: player.mode.monoIcon,
                        size: QueuePopupPalette.isAside ? 14 : 16,
                        color: QueuePopupPalette.isAside ? .monoAccent : QueuePopupPalette.primaryText
                    )
                    Text(modeName(player.mode))
                        .font(.rounded(size: QueuePopupPalette.isAside ? 12.5 : 14, weight: QueuePopupPalette.isAside ? .semibold : .medium))
                }
                .foregroundColor(QueuePopupPalette.primaryText)
                .padding(.horizontal, QueuePopupPalette.isAside ? 13 : 16)
                .padding(.vertical, QueuePopupPalette.isAside ? 7 : 8)
                .background(
                    Group {
                        if MinimalWhiteStyle.isActive {
                            MinimalWhiteCapsuleBackground()
                        } else if PureWhiteStyle.isActive {
                            Capsule()
                                .fill(PureWhiteStyle.surfaceRaised)
                                .overlay(Capsule().stroke(PureWhiteStyle.separator, lineWidth: 1))
                        } else if QueuePopupPalette.isAside {
                            Capsule()
                                .fill(Color.monoTextPrimary.opacity(0.05))
                                .overlay(Capsule().stroke(Color.monoTextPrimary.opacity(0.08), lineWidth: 1))
                        } else {
                            Capsule()
                                .fill(PetWhiteStyle.isActive ? PetWhiteStyle.surfaceRaised : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monoSeparator))
                                .overlay(
                                    Capsule()
                                        .stroke(PetWhiteStyle.isActive ? PetWhiteStyle.stroke : Color.clear, lineWidth: PetWhiteStyle.isActive ? PetWhiteStyle.fineStrokeWidth : 0)
                                )
                        }
                    }
                )
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    private func tabButton(title: String, tabIndex: Int) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tabIndex } }) {
            if MinimalWhiteStyle.isActive {
                Text(LocalizedStringKey(title))
                    .font(MinimalWhiteStyle.labelFont(13, weight: selectedTab == tabIndex ? .semibold : .regular))
                    .foregroundStyle(selectedTab == tabIndex ? MinimalWhiteStyle.ink : MinimalWhiteStyle.inkMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background {
                        if selectedTab == tabIndex {
                            MinimalWhiteCapsuleBackground(selected: true)
                                .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                        }
                    }
            } else if QueuePopupPalette.isAside {
                // aside：与搜索/音乐库页签同语言——短强调色下划线
                VStack(spacing: 6) {
                    Text(LocalizedStringKey(title))
                        .font(.system(size: 17, weight: selectedTab == tabIndex ? .heavy : .medium, design: .rounded))
                        .foregroundColor(
                            selectedTab == tabIndex
                                ? .monoTextPrimary
                                : .monoTextSecondary.opacity(0.8)
                        )

                    if selectedTab == tabIndex {
                        Capsule()
                            .fill(Color.monoAccent)
                            .frame(width: 16, height: 3)
                            .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                    } else {
                        Capsule().fill(Color.clear).frame(width: 16, height: 3)
                    }
                }
                .contentShape(Rectangle())
            } else {
                VStack(spacing: 6) {
                Text(LocalizedStringKey(title))
                    .font(.rounded(size: 18, weight: selectedTab == tabIndex ? .bold : .medium))
                    .foregroundColor(selectedTab == tabIndex ? QueuePopupPalette.primaryText : QueuePopupPalette.secondaryText)

                if selectedTab == tabIndex {
                    Capsule()
                        .fill(PetWhiteStyle.isActive ? PetWhiteStyle.dogOrange : ((NeumorphicStyle.isActive || PureWhiteStyle.isActive) ? QueuePopupPalette.accent : Color.monoIconBackground))
                        .frame(width: 20, height: 4)
                        .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                } else {
                    Capsule().fill(Color.clear).frame(height: 4)
                }
                }
            }
        }
    }

    private var currentQueueView: some View {
        Group {
            if hasLinearQueueContent {
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            if QueuePopupPalette.isAside {
                                Capsule()
                                    .fill(Color.monoAccent)
                                    .frame(width: 3, height: 13)

                                Text(String(localized: "queue_tab_now_playing"))
                                    .font(.rounded(size: 13, weight: .bold))
                                    .foregroundColor(QueuePopupPalette.primaryText)

                                Text("\(linearQueueItems.count)")
                                    .font(.rounded(size: 12, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundColor(QueuePopupPalette.secondaryText.opacity(0.85))

                                if let stats = upcomingStatsText {
                                    Text(stats)
                                        .font(.rounded(size: 11.5, weight: .medium))
                                        .monospacedDigit()
                                        .foregroundColor(QueuePopupPalette.secondaryText.opacity(0.62))
                                        .lineLimit(1)
                                }
                            } else {
                                MonoIcon(icon: .musicNoteList, size: 14, color: QueuePopupPalette.secondaryText, lineWidth: 1.5)

                                Text(String(localized: "queue_tab_now_playing") + " · \(linearQueueItems.count)")
                                    .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(13, weight: .medium) : .rounded(size: 13, weight: .semibold))
                                    .foregroundColor(QueuePopupPalette.secondaryText)

                                if let stats = upcomingStatsText {
                                    Text(stats)
                                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(11.5, weight: .regular) : .rounded(size: 11.5, weight: .medium))
                                        .monospacedDigit()
                                        .foregroundColor(QueuePopupPalette.secondaryText.opacity(0.62))
                                        .lineLimit(1)
                                }
                            }

                            Spacer(minLength: 8)

                            Button(action: {
                                scrollToCurrentSong(using: proxy)
                            }) {
                                Text(NSLocalizedString("queue_locate_current", comment: ""))
                                    .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(12, weight: .regular) : .rounded(size: 12, weight: .medium))
                                    .foregroundColor(QueuePopupPalette.secondaryText)
                            }
                            .buttonStyle(.plain)

                            if !player.contextRemainingSongs.isEmpty {
                                Button(action: {
                                    withAnimation {
                                        player.clearUpcoming()
                                    }
                                }) {
                                    Text(NSLocalizedString("queue_clear", comment: ""))
                                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(12, weight: .regular) : .rounded(size: 12, weight: .medium))
                                        .foregroundColor(QueuePopupPalette.secondaryText)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.bottom, 10)

                        List {
                            ForEach(Array(linearQueueItems.enumerated()), id: \.element.id) { index, item in
                                QueueLinearRow(
                                    song: item.song,
                                    role: item.role,
                                    position: index + 1,
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
                                .moveDisabled(item.role != .upcoming)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(
                                    EdgeInsets(
                                        top: QueuePopupPalette.isAside ? 0 : 4,
                                        leading: DeviceLayout.viewHorizontalPadding,
                                        bottom: QueuePopupPalette.isAside ? 0 : 4,
                                        trailing: DeviceLayout.viewHorizontalPadding
                                    )
                                )
                            }
                            .onMove(perform: moveLinearQueueItems)
                            .deleteDisabled(true)
                        }
                        .listStyle(.plain)
                        .environment(\.editMode, .constant(.active))
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onAppear {
                        scrollToCurrentSong(using: proxy, animated: false)
                    }
                    .onChange(of: player.currentSong?.id) { _, _ in
                        scrollToCurrentSong(using: proxy)
                    }
                }
            } else {
                EmptyStateView(text: "queue_empty", icon: .musicNoteList)
            }
        }
    }

    private func moveLinearQueueItems(from source: IndexSet, to destination: Int) {
        let relativeSource = IndexSet(
            source.compactMap { index in
                index >= upcomingStartIndex ? index - upcomingStartIndex : nil
            }
        )
        guard !relativeSource.isEmpty else { return }

        let upcomingCount = max(linearQueueItems.count - upcomingStartIndex, 0)
        let clampedDestination = max(upcomingStartIndex, min(destination, upcomingStartIndex + upcomingCount))
        player.moveUpcoming(from: relativeSource, to: clampedDestination - upcomingStartIndex)
    }

    private func scrollToCurrentSong(using proxy: ScrollViewProxy, animated: Bool = true) {
        guard let currentSongID = player.currentSong?.id else { return }
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.22)) {
                    proxy.scrollTo(currentSongID, anchor: .center)
                }
            } else {
                proxy.scrollTo(currentSongID, anchor: .center)
            }
        }
    }

    private var historyView: some View {
        Group {
            let musicHistory = player.history.filter { $0.podcastRadioId == nil }
            if musicHistory.isEmpty {
                EmptyStateView(text: "queue_history_empty", icon: .clock)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    QueueSectionHeader(
                        icon: .clock,
                        title: NSLocalizedString("queue_tab_history", comment: ""),
                        count: musicHistory.count,
                        actionTitle: NSLocalizedString("queue_clear", comment: ""),
                        action: confirmClearHistory
                    )
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.bottom, 8)

                    let musicHistory = player.history.filter { $0.podcastRadioId == nil }
                    ForEach(musicHistory) { song in
                        HistoryRow(song: song) {
                            player.playFromQueue(song: song)
                        }
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
    
    private func confirmClearRecentPlayback() {
        AlertManager.shared.show(
            title: NSLocalizedString("queue_clear_recent_title", comment: ""),
            message: NSLocalizedString("queue_clear_recent_message", comment: ""),
            primaryButtonTitle: NSLocalizedString("queue_clear", comment: ""),
            secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: "")
        ) {
            withAnimation {
                player.clearRecentPlaybackStack()
            }
        }
    }
    
    private func confirmClearHistory() {
        AlertManager.shared.show(
            title: NSLocalizedString("queue_clear_history_title", comment: ""),
            message: NSLocalizedString("queue_clear_history_message", comment: ""),
            primaryButtonTitle: NSLocalizedString("queue_clear", comment: ""),
            secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: "")
        ) {
            withAnimation {
                player.clearPlaybackHistory()
            }
        }
    }
}

// MARK: - Section Header
private struct QueueSectionHeader: View {
    let icon: MonoIcon.IconType
    let title: String
    var count: Int? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision

        HStack(spacing: 8) {
            if QueuePopupPalette.isAside {
                Capsule()
                    .fill(Color.monoAccent)
                    .frame(width: 3, height: 13)

                Text(title)
                    .font(.rounded(size: 13, weight: .bold))
                    .foregroundColor(QueuePopupPalette.primaryText)

                if let count {
                    Text("\(count)")
                        .font(.rounded(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(QueuePopupPalette.secondaryText.opacity(0.85))
                }
            } else {
                MonoIcon(icon: icon, size: 14, color: QueuePopupPalette.secondaryText, lineWidth: 1.5)

                Text(title)
                    .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(12, weight: .medium) : .rounded(size: 11, weight: .bold))
                    .foregroundColor(QueuePopupPalette.secondaryText)
                    .tracking(MinimalWhiteStyle.isActive ? 0 : 1.4)

                if let count {
                    Text("\(count)")
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(11, weight: .regular) : .rounded(size: 11, weight: .semibold))
                        .foregroundColor(QueuePopupPalette.secondaryText.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background {
                            if MinimalWhiteStyle.isActive {
                                MinimalWhiteCapsuleBackground()
                            } else {
                                Capsule()
                                    .fill(QueuePopupPalette.pressedSurface.opacity(NeumorphicStyle.isActive ? 0.9 : 0.45))
                            }
                        }
                }
            }

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(12, weight: .regular) : .rounded(size: 12, weight: .medium))
                        .foregroundColor(QueuePopupPalette.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Shelf Section
private struct QueueShelf: View {
    let title: String
    let count: Int
    let icon: MonoIcon.IconType
    let songs: [Song]
    var actionTitle: String? = nil
    var headerAction: (() -> Void)? = nil
    let action: (Song) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            QueueSectionHeader(
                icon: icon,
                title: title,
                count: count,
                actionTitle: actionTitle,
                action: headerAction
            )
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(songs) { song in
                        QueueShelfCard(song: song, icon: icon) {
                            action(song)
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }
}

private struct QueueShelfCard: View {
    let song: Song
    let icon: MonoIcon.IconType
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsManager.shared

    private var cardBackground: Color {
        if MinimalWhiteStyle.isActive {
            return MinimalWhiteStyle.glassFill
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.surfacePressed
        }
        return colorScheme == .dark ? Color.white.opacity(0.05) : Color.monoSeparator.opacity(0.24)
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        Button(action: action) {
            HStack(spacing: 8) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : Color.gray.opacity(0.18))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(13, weight: .medium) : .rounded(size: 13, weight: .semibold))
                        .foregroundColor(QueuePopupPalette.primaryText)
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(11, weight: .regular) : .rounded(size: 11, weight: .medium))
                        .foregroundColor(QueuePopupPalette.secondaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Circle()
                    .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : (NeumorphicStyle.isActive ? QueuePopupPalette.accent.opacity(0.18) : Color.black.opacity(colorScheme == .dark ? 0.22 : 0.10)))
                    .frame(width: 22, height: 22)
                    .overlay {
                        MonoIcon(
                            icon: icon,
                            size: 9,
                            color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (NeumorphicStyle.isActive ? QueuePopupPalette.accent : (colorScheme == .dark ? .white : .monoTextPrimary)),
                            lineWidth: 1.4
                        )
                    }
            }
            .frame(width: 164, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Group {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.cardRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cardBackground)
                    }
                }
            )
            .background {
                if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 14, elevated: false)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 线性队列行
private struct QueueLinearRow: View {
    let song: Song
    let role: PlaylistPopupView.LinearQueueItem.Role
    var position: Int = 0
    let action: () -> Void
    var removeAction: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared

    private var isCurrent: Bool {
        role == .current
    }

    private var isPlayed: Bool {
        role == .played
    }

    private var capsuleTint: Color {
        switch role {
        case .current:
            return CapsuleStyle.accent
        case .played:
            return CapsuleStyle.inkMuted
        case .upcoming:
            return CapsuleStyle.cyan
        }
    }

    @ViewBuilder
    private var leadingIndicator: some View {
        switch role {
        case .current:
            PlayingVisualizerView(
                isAnimating: player.isPlaying,
                color: CapsuleStyle.isActive ? CapsuleStyle.onAccent : ((NeumorphicStyle.isActive || PureWhiteStyle.isActive) ? QueuePopupPalette.accent : QueuePopupPalette.primaryText)
            )
                .frame(width: 18, height: 18)
        case .played:
            MonoIcon(icon: .history, size: 12, color: QueuePopupPalette.mutedText.opacity(0.62), lineWidth: 1.5)
                .frame(width: 18, height: 18)
        case .upcoming:
            MonoIcon(icon: .play, size: 12, color: QueuePopupPalette.mutedText.opacity(0.42), lineWidth: 1.5)
                .frame(width: 18, height: 18)
        }
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        Group {
            if CapsuleStyle.isActive {
                capsuleQueueRow
            } else if PetWhiteStyle.isActive {
                petWhiteQueueRow
            } else if PureWhiteStyle.isActive {
                pureWhiteQueueRow
            } else if MinimalWhiteStyle.isActive {
                minimalWhiteQueueRow
            } else if QueuePopupPalette.isAside {
                asideQueueRow
            } else {
                defaultQueueRow
            }
        }
    }

    // aside：编辑部式序号行，去卡片化，当前行用强调色竖标 + 律动条
    private var asideQueueRow: some View {
        HStack(spacing: 10) {
            Button(action: action) {
                HStack(spacing: 12) {
                    ZStack {
                        if isCurrent {
                            PlayingVisualizerView(
                                isAnimating: player.isPlaying,
                                color: .monoAccent
                            )
                            .frame(width: 18, height: 18)
                        } else {
                            Text("\(position)")
                                .font(.rounded(size: 13, weight: .semibold))
                                .monospacedDigit()
                                .foregroundColor(
                                    QueuePopupPalette.secondaryText.opacity(isPlayed ? 0.45 : 0.7)
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    .frame(width: 26, height: 18)

                    CachedAsyncImage(url: song.coverUrl) {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.monoTextPrimary.opacity(0.06))
                            .overlay(
                                MonoIcon(icon: .musicNote, size: 14, color: QueuePopupPalette.secondaryText.opacity(0.6), lineWidth: 1.5)
                            )
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.monoTextPrimary.opacity(0.07), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 3.5) {
                        Text(song.name)
                            .font(.rounded(size: 14.5, weight: isCurrent ? .bold : .medium))
                            .foregroundColor(
                                isCurrent
                                    ? QueuePopupPalette.primaryText
                                    : QueuePopupPalette.primaryText.opacity(isPlayed ? 0.62 : 0.95)
                            )
                            .lineLimit(1)

                        Text(song.artistName.isEmpty ? String(localized: "search_unknown_artist") : song.artistName)
                            .font(.rounded(size: 11.5, weight: .medium))
                            .foregroundColor(QueuePopupPalette.secondaryText.opacity(isPlayed ? 0.55 : 0.9))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isCurrent {
                        Capsule()
                            .fill(Color.monoAccent)
                            .frame(width: 3, height: 24)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let removeAction, !isCurrent {
                Button(action: removeAction) {
                    MonoIcon(icon: .xmark, size: 10, color: QueuePopupPalette.mutedText.opacity(0.5), lineWidth: 1.6)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 7.5)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.monoTextPrimary.opacity(0.055))
                .frame(height: 0.5)
                .padding(.leading, 38)
        }
        .opacity(isPlayed ? 0.85 : 1)
    }

    private var pureWhiteQueueRow: some View {
        HStack(spacing: 10) {
            Button(action: action) {
                HStack(spacing: 12) {
                    leadingIndicator

                    CachedAsyncImage(url: song.coverUrl) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(PureWhiteStyle.surfaceTint)
                            .overlay(MonoIcon(icon: .musicNote, size: 16, color: PureWhiteStyle.inkMuted, lineWidth: 1.5))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(PureWhiteStyle.separator, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.name)
                            .font(PureWhiteStyle.bodyFont(15, weight: isCurrent ? .black : .semibold))
                            .foregroundStyle(PureWhiteStyle.ink.opacity(isPlayed ? 0.6 : 1))
                            .lineLimit(1)

                        Text(song.artistName.isEmpty ? String(localized: "search_unknown_artist") : song.artistName)
                            .font(PureWhiteStyle.labelFont(12, weight: .semibold))
                            .foregroundStyle(PureWhiteStyle.inkSoft.opacity(isPlayed ? 0.6 : 1))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isCurrent {
                        Capsule(style: .continuous)
                            .fill(PureWhiteStyle.accent)
                            .frame(width: 22, height: 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if let removeAction, !isCurrent {
                Button(action: removeAction) {
                    MonoIcon(icon: .xmark, size: 11, color: PureWhiteStyle.inkMuted, lineWidth: 1.6)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(PureWhiteStyle.surfaceTint)
                                .overlay(Circle().stroke(PureWhiteStyle.separator, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background {
            if isCurrent {
                // 行高很紧凑，角落短线会压到头部指示器和尾部按钮，关掉
                PureWhiteSurfaceBackground(
                    cornerRadius: PureWhiteStyle.cardRadius,
                    elevated: true,
                    tint: PureWhiteStyle.surfaceRaised,
                    showsCornerMarks: false
                )
            } else {
                RoundedRectangle(cornerRadius: PureWhiteStyle.cardRadius, style: .continuous)
                    .fill(PureWhiteStyle.surface.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: PureWhiteStyle.cardRadius, style: .continuous)
                            .stroke(PureWhiteStyle.separator.opacity(0.7), lineWidth: PureWhiteStyle.fineStrokeWidth)
                    )
            }
        }
        .opacity(isPlayed ? 0.78 : 1)
    }

    private var minimalWhiteQueueRow: some View {
        HStack(spacing: 10) {
            Button(action: action) {
                HStack(spacing: 12) {
                    leadingIndicator

                    CachedAsyncImage(url: song.coverUrl) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(MinimalWhiteStyle.controlGlassFill)
                            .overlay(MonoIcon(icon: .musicNote, size: 16, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.5))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.name)
                            .font(MinimalWhiteStyle.bodyFont(15, weight: isCurrent ? .semibold : .medium))
                            .foregroundStyle(MinimalWhiteStyle.ink.opacity(isPlayed ? 0.58 : 1))
                            .lineLimit(1)

                        Text(song.artistName.isEmpty ? String(localized: "search_unknown_artist") : song.artistName)
                            .font(MinimalWhiteStyle.labelFont(12, weight: .regular))
                            .foregroundStyle(MinimalWhiteStyle.inkMuted.opacity(isPlayed ? 0.58 : 1))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isCurrent {
                        MinimalWhiteIconBadge(icon: .musicNoteList, size: 34, selected: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if let removeAction, !isCurrent {
                Button(action: removeAction) {
                    MonoIcon(icon: .xmark, size: 11, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.6)
                        .frame(width: 32, height: 32)
                        .background(MinimalWhiteCircleBackground())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.cardRadius,
                elevated: isCurrent,
                tint: isCurrent ? MinimalWhiteStyle.glassStrongFill : MinimalWhiteStyle.glassFill
            )
        )
        .opacity(isPlayed ? 0.74 : 1)
    }

    private var defaultQueueRow: some View {
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
                            .foregroundColor(isCurrent ? QueuePopupPalette.primaryText : QueuePopupPalette.primaryText.opacity(isPlayed ? 0.72 : 1))
                            .lineLimit(1)

                        Text(song.artistName)
                            .font(.rounded(size: 12, weight: .medium))
                            .foregroundColor(QueuePopupPalette.secondaryText.opacity(isPlayed ? 0.7 : 1))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if let removeAction, !isCurrent {
                Button(action: removeAction) {
                    MonoIcon(icon: .xmark, size: 11, color: QueuePopupPalette.mutedText.opacity(0.55), lineWidth: 1.6)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(
                    cornerRadius: 14,
                    elevated: isCurrent,
                    pressed: !isCurrent,
                    tint: isCurrent ? NeumorphicStyle.accent.opacity(0.18) : NeumorphicStyle.surface
                )
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isCurrent
                            ? (colorScheme == .dark ? Color.white.opacity(0.08) : Color.monoSeparator.opacity(0.34))
                            : Color.monoSeparator.opacity(colorScheme == .dark ? 0.14 : 0.22)
                    )
                    .monoGlassConditional(isActive: isCurrent, cornerRadius: 14)
            }
        }
        .opacity(isPlayed ? 0.78 : 1)
    }

    private var petWhiteQueueRow: some View {
        HStack(spacing: 10) {
            Button(action: action) {
                HStack(spacing: 12) {
                    leadingIndicator

                    CachedAsyncImage(url: song.coverUrl) {
                        PetWhiteStyle.mint.opacity(0.22)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(PetWhiteStyle.stroke, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.name)
                            .font(PetWhiteStyle.bodyFont(15, weight: isCurrent ? .bold : .semibold))
                            .foregroundStyle(PetWhiteStyle.ink.opacity(isPlayed ? 0.72 : 1))
                            .lineLimit(1)

                        Text(song.artistName.isEmpty ? String(localized: "search_unknown_artist") : song.artistName)
                            .font(PetWhiteStyle.labelFont(12))
                            .foregroundStyle(PetWhiteStyle.inkSoft.opacity(isPlayed ? 0.68 : 1))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if let removeAction, !isCurrent {
                Button(action: removeAction) {
                    PetWhitePackIcon(icon: .xmark, size: 12, visualScale: 1.02, fallbackColor: PetWhiteStyle.inkMuted)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            if isCurrent {
                PetWhiteSurfaceBackground(
                    cornerRadius: PetWhiteStyle.cardRadius,
                    elevated: false,
                    tint: PetWhiteStyle.butter.opacity(0.42),
                    accent: PetWhiteStyle.butter
                )
            }
        }
        .opacity(isPlayed ? 0.78 : 1)
    }

    private var capsuleQueueRow: some View {
        HStack(spacing: 10) {
            Button(action: action) {
                HStack(spacing: 12) {
                    capsuleRoleBadge

                    capsuleQueueArtwork

                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.name)
                            .font(CapsuleStyle.bodyFont(15, weight: isCurrent ? .bold : .semibold))
                            .foregroundStyle(CapsuleStyle.ink.opacity(isPlayed ? 0.72 : 1))
                            .lineLimit(1)

                        Text(song.artistName.isEmpty ? String(localized: "search_unknown_artist") : song.artistName)
                            .font(CapsuleStyle.labelFont(12, weight: .medium))
                            .foregroundStyle(CapsuleStyle.inkSoft.opacity(isPlayed ? 0.66 : 1))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isCurrent {
                        Capsule()
                            .fill(CapsuleStyle.accent.opacity(0.13))
                            .frame(width: 44, height: 30)
                            .overlay(
                                MonoIcon(icon: .musicNoteList, size: 13, color: CapsuleStyle.accent, lineWidth: 1.8)
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(CapsulePressStyle())

            if let removeAction, !isCurrent {
                Button(action: removeAction) {
                    MonoIcon(icon: .xmark, size: 11, color: CapsuleStyle.inkMuted, lineWidth: 1.7)
                        .frame(width: 32, height: 32)
                        .background(Capsule().fill(CapsuleStyle.surfaceTint.opacity(0.88)))
                        .overlay(Capsule().stroke(CapsuleStyle.separator.opacity(0.42), lineWidth: 0.7))
                }
                .buttonStyle(CapsulePressStyle())
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 66)
        .background {
            capsuleQueueBackground
        }
        .opacity(isPlayed ? 0.72 : 1)
        .themeRenderRowLayer()
    }

    private var capsuleRoleBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(isCurrent ? capsuleTint : capsuleTint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(capsuleTint.opacity(isCurrent ? 0.34 : 0.18), lineWidth: 0.7)
                )

            if isCurrent {
                PlayingVisualizerView(isAnimating: player.isPlaying, color: CapsuleStyle.onAccent)
                    .scaleEffect(0.78)
            } else {
                MonoIcon(
                    icon: isPlayed ? .history : .play,
                    size: 12,
                    color: capsuleTint.opacity(isPlayed ? 0.72 : 0.95),
                    lineWidth: 1.7
                )
            }
        }
        .frame(width: 28, height: 34)
    }

    private var capsuleQueueArtwork: some View {
        CachedAsyncImage(url: song.coverUrl, width: 48, height: 48) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(capsuleTint.opacity(0.14))
                .overlay(MonoIcon(icon: .musicNote, size: 17, color: capsuleTint.opacity(0.68), lineWidth: 1.7))
        }
        .aspectRatio(contentMode: .fill)
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.36), lineWidth: 0.8)
        )
    }

    private var capsuleQueueBackground: some View {
        ZStack(alignment: .leading) {
            CapsuleSurfaceBackground(
                cornerRadius: 26,
                elevated: isCurrent,
                tint: isCurrent ? CapsuleStyle.surfaceRaised : CapsuleStyle.surfaceRaised.opacity(0.82)
            )

            if isCurrent {
                LinearGradient(
                    colors: [
                        CapsuleStyle.accent.opacity(0.16),
                        CapsuleStyle.cyan.opacity(0.08),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
        }
    }
}

// MARK: - 队列行
struct QueueRow: View {
    let song: Song
    let isCurrent: Bool
    let action: () -> Void
    var removeAction: (() -> Void)? = nil
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision

        Button(action: action) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: song.coverUrl) {
                    MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : Color.gray.opacity(0.2)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: MinimalWhiteStyle.isActive ? 48 : 44, height: MinimalWhiteStyle.isActive ? 48 : 44)
                .clipShape(RoundedRectangle(cornerRadius: MinimalWhiteStyle.isActive ? 12 : 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.bodyFont(15, weight: isCurrent ? .semibold : .medium) : .rounded(size: 15, weight: .medium))
                        .foregroundColor(QueuePopupPalette.primaryText)
                        .lineLimit(1)
                    Text(song.artistName)
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(12, weight: .regular) : .rounded(size: 12, weight: .regular))
                        .foregroundColor(QueuePopupPalette.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                if let removeAction = removeAction {
                    Button(action: removeAction) {
                        MonoIcon(icon: .xmark, size: 12, color: QueuePopupPalette.mutedText.opacity(0.55))
                            .padding(8)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, MinimalWhiteStyle.isActive ? 10 : DeviceLayout.viewHorizontalPadding)
            .background {
                if MinimalWhiteStyle.isActive {
                    MinimalWhiteSurfaceBackground(
                        cornerRadius: MinimalWhiteStyle.cardRadius,
                        elevated: isCurrent,
                        tint: isCurrent ? MinimalWhiteStyle.glassStrongFill : MinimalWhiteStyle.glassFill
                    )
                }
            }
        }
        .padding(.horizontal, MinimalWhiteStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 历史行
struct HistoryRow: View {
    let song: Song
    let action: () -> Void
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision

        if CapsuleStyle.isActive {
            Button(action: action) {
                HStack(spacing: 12) {
                    CachedAsyncImage(url: song.coverUrl, width: 48, height: 48) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(CapsuleStyle.surfaceTint)
                            .overlay(MonoIcon(icon: .musicNote, size: 17, color: CapsuleStyle.inkMuted.opacity(0.66), lineWidth: 1.7))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.34), lineWidth: 0.8)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.name)
                            .font(CapsuleStyle.bodyFont(15, weight: .semibold))
                            .foregroundStyle(CapsuleStyle.ink)
                            .lineLimit(1)

                        Text(song.artistName.isEmpty ? String(localized: "search_unknown_artist") : song.artistName)
                            .font(CapsuleStyle.labelFont(12, weight: .medium))
                            .foregroundStyle(CapsuleStyle.inkSoft)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    MonoIcon(icon: .play, size: 13, color: CapsuleStyle.accent, lineWidth: 1.8)
                        .frame(width: 34, height: 34)
                        .background(Capsule().fill(CapsuleStyle.accent.opacity(0.12)))
                }
                .padding(.horizontal, 10)
                .frame(height: 66)
                .background(CapsuleSurfaceBackground(cornerRadius: 26, elevated: false, tint: CapsuleStyle.surfaceRaised.opacity(0.82)))
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, 4)
            .buttonStyle(CapsulePressStyle())
            .themeRenderRowLayer()
        } else if SettingsManager.shared.globalThemeId == .default {
            // aside：与队列行同语言的发丝线行
            Button(action: action) {
                HStack(spacing: 12) {
                    CachedAsyncImage(url: song.coverUrl) {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.monoTextPrimary.opacity(0.06))
                            .overlay(
                                MonoIcon(icon: .musicNote, size: 14, color: Color.monoTextSecondary.opacity(0.6), lineWidth: 1.5)
                            )
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.monoTextPrimary.opacity(0.07), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 3.5) {
                        Text(song.name)
                            .font(.rounded(size: 14.5, weight: .medium))
                            .foregroundColor(.monoTextPrimary.opacity(0.95))
                            .lineLimit(1)

                        Text(song.artistName.isEmpty ? String(localized: "search_unknown_artist") : song.artistName)
                            .font(.rounded(size: 11.5, weight: .medium))
                            .foregroundColor(.monoTextSecondary.opacity(0.9))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    MonoIcon(icon: .play, size: 11, color: .monoTextSecondary.opacity(0.55), lineWidth: 1.6)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(Color.monoTextPrimary.opacity(0.05))
                        )
                }
                .padding(.vertical, 7.5)
                .contentShape(Rectangle())
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.monoTextPrimary.opacity(0.055))
                        .frame(height: 0.5)
                        .padding(.leading, 54)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .buttonStyle(.plain)
        } else {
            Button(action: action) {
                HStack(spacing: 12) {
                    CachedAsyncImage(url: song.coverUrl) {
                        MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : Color.gray.opacity(0.2)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: MinimalWhiteStyle.isActive ? 48 : 44, height: MinimalWhiteStyle.isActive ? 48 : 44)
                    .clipShape(RoundedRectangle(cornerRadius: MinimalWhiteStyle.isActive ? 12 : 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.name)
                            .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.bodyFont(15, weight: .medium) : .rounded(size: 15, weight: .medium))
                            .foregroundColor(QueuePopupPalette.primaryText)
                            .lineLimit(1)
                        Text(song.artistName)
                            .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(12, weight: .regular) : .rounded(size: 12, weight: .regular))
                            .foregroundColor(QueuePopupPalette.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    MonoIcon(icon: .play, size: MinimalWhiteStyle.isActive ? 13 : 24, color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (NeumorphicStyle.isActive ? QueuePopupPalette.accent.opacity(0.72) : QueuePopupPalette.secondaryText.opacity(0.5)))
                        .frame(width: MinimalWhiteStyle.isActive ? 34 : 24, height: MinimalWhiteStyle.isActive ? 34 : 24)
                        .background {
                            if MinimalWhiteStyle.isActive {
                                MinimalWhiteCircleBackground()
                            }
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, MinimalWhiteStyle.isActive ? 10 : DeviceLayout.viewHorizontalPadding)
                .background {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.cardRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    }
                }
            }
            .padding(.horizontal, MinimalWhiteStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - 空状态
struct EmptyStateView: View {
    let text: String
    let icon: MonoIcon.IconType
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision

        VStack(spacing: 16) {
            Spacer()
                .frame(height: 100)
            if MinimalWhiteStyle.isActive {
                MinimalWhiteIconBadge(icon: icon, size: 54)
            } else {
                MonoIcon(icon: icon, size: 48, color: QueuePopupPalette.mutedText.opacity(0.36))
            }
            Text(LocalizedStringKey(text))
                .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.bodyFont(15, weight: .medium) : .rounded(size: 16, weight: .medium))
                .foregroundColor(QueuePopupPalette.secondaryText)
            Spacer()
        }
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
    }
}

// MARK: - 播放模式图标
extension PlayerManager.PlayMode {
    var monoIcon: MonoIcon.IconType {
        switch self {
        case .sequence: return .repeatMode
        case .loopSingle: return .repeatOne
        case .shuffle: return .shuffle
        }
    }
}
