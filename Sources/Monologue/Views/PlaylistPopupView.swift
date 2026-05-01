import SwiftUI

private enum QueuePopupPalette {
    static var accent: Color {
        return NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueAccent
    }

    static var accentForeground: Color {
        if NeumorphicStyle.isActive {
            return ThemeColorCustomization.readableForegroundColor(
                on: NeumorphicStyle.accent,
                light: Color(hex: "172026"),
                dark: .white
            )
        }
        return .monologueIconForeground
    }

    static var primaryText: Color {
        return NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary
    }

    static var secondaryText: Color {
        return NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary
    }

    static var mutedText: Color {
        return NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary
    }

    static var separator: Color {
        return NeumorphicStyle.isActive ? NeumorphicStyle.separator : .monologueSeparator
    }

    static var pressedSurface: Color {
        return NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : .monologueSeparator
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

    var body: some View {
        let _ = settings.globalThemeRevision

        VStack(spacing: 0) {
            headerView
                .padding(.top, 24)
                .padding(.bottom, 16)

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
        HStack(spacing: 0) {
            HStack(spacing: 24) {
                tabButton(title: "queue_tab_now_playing", tabIndex: 0)
                tabButton(title: "queue_tab_history", tabIndex: 1)
            }

            Spacer()

            Button(action: { player.switchMode() }) {
                HStack(spacing: 6) {
                    MonologueIcon(icon: player.mode.monologueIcon, size: 16, color: QueuePopupPalette.primaryText)
                    Text(modeName(player.mode))
                        .font(.rounded(size: 14, weight: .medium))
                }
                .foregroundColor(QueuePopupPalette.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueSeparator)
                )
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    private func tabButton(title: String, tabIndex: Int) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tabIndex } }) {
            VStack(spacing: 6) {
                Text(LocalizedStringKey(title))
                    .font(.rounded(size: 18, weight: selectedTab == tabIndex ? .bold : .medium))
                    .foregroundColor(selectedTab == tabIndex ? QueuePopupPalette.primaryText : QueuePopupPalette.secondaryText)

                if selectedTab == tabIndex {
                    Capsule()
                        .fill(NeumorphicStyle.isActive ? QueuePopupPalette.accent : Color.monologueIconBackground)
                        .frame(width: 20, height: 4)
                        .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                } else {
                    Capsule().fill(Color.clear).frame(height: 4)
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
                            MonologueIcon(icon: .musicNoteList, size: 14, color: QueuePopupPalette.secondaryText, lineWidth: 1.5)

                            Text(String(localized: "queue_tab_now_playing") + " · \(linearQueueItems.count)")
                                .font(.rounded(size: 13, weight: .semibold))
                                .foregroundColor(QueuePopupPalette.secondaryText)

                            Spacer()

                            if !player.contextRemainingSongs.isEmpty {
                                Button(action: {
                                    withAnimation {
                                        player.clearUpcoming()
                                    }
                                }) {
                                    Text(NSLocalizedString("queue_clear", comment: ""))
                                        .font(.rounded(size: 12, weight: .medium))
                                        .foregroundColor(QueuePopupPalette.secondaryText)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.bottom, 10)

                        List {
                            ForEach(linearQueueItems) { item in
                                QueueLinearRow(
                                    song: item.song,
                                    role: item.role,
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
                                        top: 4,
                                        leading: DeviceLayout.viewHorizontalPadding,
                                        bottom: 4,
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
    let icon: MonologueIcon.IconType
    let title: String
    var count: Int? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision

        HStack(spacing: 8) {
            MonologueIcon(icon: icon, size: 14, color: QueuePopupPalette.secondaryText, lineWidth: 1.5)

            Text(title)
                .font(.rounded(size: 11, weight: .bold))
                .foregroundColor(QueuePopupPalette.secondaryText)
                .tracking(1.4)

            if let count {
                Text("\(count)")
                    .font(.rounded(size: 11, weight: .semibold))
                    .foregroundColor(QueuePopupPalette.secondaryText.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(QueuePopupPalette.pressedSurface.opacity(NeumorphicStyle.isActive ? 0.9 : 0.45))
                    )
            }

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.rounded(size: 12, weight: .medium))
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
    let icon: MonologueIcon.IconType
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
    let icon: MonologueIcon.IconType
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsManager.shared

    private var cardBackground: Color {
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.surfacePressed
        }
        return colorScheme == .dark ? Color.white.opacity(0.05) : Color.monologueSeparator.opacity(0.24)
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        Button(action: action) {
            HStack(spacing: 8) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.gray.opacity(0.18))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(.rounded(size: 13, weight: .semibold))
                        .foregroundColor(QueuePopupPalette.primaryText)
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(.rounded(size: 11, weight: .medium))
                        .foregroundColor(QueuePopupPalette.secondaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Circle()
                    .fill(NeumorphicStyle.isActive ? QueuePopupPalette.accent.opacity(0.18) : Color.black.opacity(colorScheme == .dark ? 0.22 : 0.10))
                    .frame(width: 22, height: 22)
                    .overlay {
                        MonologueIcon(
                            icon: icon,
                            size: 9,
                            color: NeumorphicStyle.isActive ? QueuePopupPalette.accent : (colorScheme == .dark ? .white : .monologueTextPrimary),
                            lineWidth: 1.4
                        )
                    }
            }
            .frame(width: 164, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardBackground)
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

    @ViewBuilder
    private var leadingIndicator: some View {
        switch role {
        case .current:
            PlayingVisualizerView(isAnimating: player.isPlaying, color: NeumorphicStyle.isActive ? QueuePopupPalette.accent : QueuePopupPalette.primaryText)
                .frame(width: 18, height: 18)
        case .played:
            MonologueIcon(icon: .history, size: 12, color: QueuePopupPalette.mutedText.opacity(0.62), lineWidth: 1.5)
                .frame(width: 18, height: 18)
        case .upcoming:
            MonologueIcon(icon: .play, size: 12, color: QueuePopupPalette.mutedText.opacity(0.42), lineWidth: 1.5)
                .frame(width: 18, height: 18)
        }
    }

    var body: some View {
        let _ = settings.globalThemeRevision

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
                    MonologueIcon(icon: .xmark, size: 11, color: QueuePopupPalette.mutedText.opacity(0.55), lineWidth: 1.6)
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
                            ? (colorScheme == .dark ? Color.white.opacity(0.08) : Color.monologueSeparator.opacity(0.34))
                            : Color.monologueSeparator.opacity(colorScheme == .dark ? 0.14 : 0.22)
                    )
                    .monologueGlassConditional(isActive: isCurrent, cornerRadius: 14)
            }
        }
        .opacity(isPlayed ? 0.78 : 1)
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
                    Color.gray.opacity(0.2)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(.rounded(size: 15, weight: .medium))
                        .foregroundColor(QueuePopupPalette.primaryText)
                        .lineLimit(1)
                    Text(song.artistName)
                        .font(.rounded(size: 12, weight: .regular))
                        .foregroundColor(QueuePopupPalette.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                if let removeAction = removeAction {
                    Button(action: removeAction) {
                        MonologueIcon(icon: .xmark, size: 12, color: QueuePopupPalette.mutedText.opacity(0.55))
                            .padding(8)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        }
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
                        .foregroundColor(QueuePopupPalette.primaryText)
                        .lineLimit(1)
                    Text(song.artistName)
                        .font(.rounded(size: 12, weight: .regular))
                        .foregroundColor(QueuePopupPalette.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                MonologueIcon(icon: .play, size: 24, color: NeumorphicStyle.isActive ? QueuePopupPalette.accent.opacity(0.72) : QueuePopupPalette.secondaryText.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 空状态
struct EmptyStateView: View {
    let text: String
    let icon: MonologueIcon.IconType
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision

        VStack(spacing: 16) {
            Spacer()
                .frame(height: 100)
            MonologueIcon(icon: icon, size: 48, color: QueuePopupPalette.mutedText.opacity(0.36))
            Text(LocalizedStringKey(text))
                .font(.rounded(size: 16, weight: .medium))
                .foregroundColor(QueuePopupPalette.secondaryText)
            Spacer()
        }
    }
}

// MARK: - 播放模式图标
extension PlayerManager.PlayMode {
    var monologueIcon: MonologueIcon.IconType {
        switch self {
        case .sequence: return .repeatMode
        case .loopSingle: return .repeatOne
        case .shuffle: return .shuffle
        }
    }
}
