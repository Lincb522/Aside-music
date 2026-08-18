import SwiftUI

struct MonoSessionPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var session = MonoSessionManager.shared
    @StateObject private var suite = MonoNextSuiteManager.shared
    @StateObject private var search = SearchViewModel()
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared

    @State private var inviteCode = ""
    @State private var chatText = ""
    @State private var roomSearchQuery = ""
    @State private var isSeeking = false
    @State private var seekValue: Double = 0
    @State private var showsQueueSearch = false
    @State private var isQueueCollapsed = false
    @FocusState private var inviteFocused: Bool
    @FocusState private var chatFocused: Bool
    @FocusState private var searchFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let layout = MonoSessionViewport(size: proxy.size)

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    topBar(horizontalInset: layout.horizontalInset)

                    if session.room == nil {
                        lobby
                            .frame(width: min(560, layout.innerWidth))
                            .frame(maxHeight: .infinity)
                    } else if layout.usesTwoColumns {
                        landscapeRoom(layout: layout)
                    } else {
                        portraitRoom(layout: layout)
                    }
                }
                .frame(width: layout.viewportWidth, height: proxy.size.height, alignment: .top)
                .clipped()

                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .background { sessionBackdrop }
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var sessionBackdrop: some View {
        ZStack {
            Color(red: 0.025, green: 0.028, blue: 0.035)

            if let url = player.currentSong?.coverUrl?.sized(900) {
                CachedAsyncImage(url: url) {
                    Color.clear
                }
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(1.28)
                .blur(radius: 78)
                .saturation(0.72)
                .opacity(0.34)
                .clipped()
            }

            LinearGradient(
                colors: [Color.black.opacity(0.22), Color.black.opacity(0.72), Color.black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func topBar(horizontalInset: CGFloat) -> some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                MonoIcon(icon: .chevronLeft, size: 16, color: .white)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "common_back"))

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "mono_session_title"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(roomStatusText)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let room = session.room {
                ShareLink(item: room.inviteCode) {
                    MonoIcon(icon: .share, size: 16, color: .white)
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "mono_session_share"))

                Button {
                    session.leaveRoom()
                } label: {
                    MonoIcon(icon: .close, size: 15, color: .white.opacity(0.66))
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "mono_session_leave"))
            }
        }
        .padding(.horizontal, horizontalInset)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var lobby: some View {
        ScrollView {
            VStack(spacing: 26) {
                cover(size: 220)
                    .padding(.top, 22)

                VStack(spacing: 7) {
                    Text(String(localized: "mono_session_title"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.monoTextPrimary)

                    Text(String(localized: "mono_session_lobby_description"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.monoTextSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    Button {
                        enableSessionIfNeeded()
                        Task { await session.createRoom() }
                    } label: {
                        HStack(spacing: 9) {
                            if isConnecting {
                                ProgressView().tint(accentControlForeground)
                            } else {
                                MonoIcon(icon: .headphones, size: 17, color: accentControlForeground)
                            }
                            Text(String(localized: "mono_session_create"))
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(accentControlForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.monoIconBackground)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isConnecting)

                    HStack(spacing: 10) {
                        TextField(String(localized: "mono_session_code"), text: $inviteCode)
                            .focused($inviteFocused)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .submitLabel(.join)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 15)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.monoTextPrimary.opacity(0.06))
                            )
                            .monoOnSubmit(text: $inviteCode) { _ in
                                joinRoom()
                            }

                        Button {
                            MonoTextInputCommitter.commit(text: $inviteCode) { _ in
                                joinRoom()
                            }
                        } label: {
                            Text(String(localized: "mono_session_join"))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.monoTextPrimary)
                                .frame(width: 76, height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.monoTextPrimary.opacity(0.09))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnecting)
                    }

                    if case .failed(let message) = session.connectionState {
                        Text(message)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.red.opacity(0.86))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.monoTextPrimary.opacity(0.045))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.monoSeparator.opacity(0.65), lineWidth: 0.5)
                }
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func portraitRoom(layout: MonoSessionViewport) -> some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(spacing: 18) {
                    playerPanel(coverSize: min(286, max(190, layout.availableHeight * 0.3)))
                    sessionDeck(chatHeight: min(320, max(240, layout.availableHeight * 0.34)))
                }
                .frame(width: layout.innerWidth)
                .frame(width: layout.viewportWidth, alignment: .center)
                .padding(.bottom, 28)
            }
            .frame(width: layout.viewportWidth)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: chatFocused) { _, isFocused in
                guard isFocused else { return }
                Task { @MainActor in
                    await Task.yield()
                    if reduceMotion {
                        reader.scrollTo("mono-session-chat-composer", anchor: .bottom)
                    } else {
                        withAnimation(.easeOut(duration: 0.22)) {
                            reader.scrollTo("mono-session-chat-composer", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private func landscapeRoom(layout: MonoSessionViewport) -> some View {
        HStack(spacing: 22) {
            ScrollView {
                VStack(spacing: 20) {
                    playerPanel(coverSize: layout.landscapeCoverSize)
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .frame(width: layout.playerColumnWidth)

            sessionDeck(chatHeight: 300)
                .frame(width: layout.deckColumnWidth)
                .frame(maxHeight: .infinity)
        }
        .padding(.bottom, 22)
        .frame(width: layout.innerWidth)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func sessionDeck(chatHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            participantsStrip

            Rectangle()
                .fill(Color.white.opacity(0.075))
                .frame(height: 0.5)

            queuePanel

            Rectangle()
                .fill(Color.white.opacity(0.075))
                .frame(height: 0.5)

            chatPanel
                .frame(height: chatHeight)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                }
                .environment(\.colorScheme, .dark)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.11), lineWidth: 0.7)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func playerPanel(coverSize: CGFloat) -> some View {
        VStack(spacing: 17) {
            cover(size: coverSize)

            VStack(spacing: 4) {
                Text(player.currentSong?.name ?? String(localized: "mono_suite_no_track"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.monoTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(player.currentSong?.artistName ?? String(localized: "mono_session_waiting_track"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.monoTextSecondary)
                    .lineLimit(1)
            }

            progressSection
            playbackControls

            Text(session.role == .host
                 ? String(localized: "mono_session_host_control")
                 : (session.membersCanControlPlayback
                    ? String(localized: "mono_session_member_playback_control")
                    : String(localized: "mono_session_listener_follow")))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.monoTextSecondary)

            if let error = session.controlErrorText {
                Text(error)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.red.opacity(0.86))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func cover(size: CGFloat) -> some View {
        Group {
            if let url = player.currentSong?.coverUrl?.sized(800) {
                CachedAsyncImage(url: url, width: size, height: size) {
                    coverPlaceholder(size: size)
                }
                .aspectRatio(contentMode: .fill)
            } else {
                coverPlaceholder(size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.14), radius: 8, y: 5)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: player.currentSong?.id)
    }

    private func coverPlaceholder(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.monoTextPrimary.opacity(0.07))
            .frame(width: size, height: size)
            .overlay {
                MonoIcon(icon: .musicNote, size: min(36, size * 0.17), color: .monoTextSecondary)
            }
    }

    private var progressSection: some View {
        VStack(spacing: 5) {
            Slider(
                value: Binding(
                    get: {
                        if isSeeking || session.pendingSeekPosition != nil {
                            return seekValue
                        }
                        return min(timePublisher.currentTime, max(timePublisher.duration, 1))
                    },
                    set: { seekValue = $0 }
                ),
                in: 0...max(timePublisher.duration, 1),
                onEditingChanged: { editing in
                    guard session.canControlPlayback else { return }
                    isSeeking = editing
                    if !editing {
                        session.seekRoom(to: seekValue)
                    }
                }
            )
            .tint(.monoAccent)
            .disabled(
                !session.canControlPlayback
                    || timePublisher.duration <= 0
                    || session.isPlaybackControlPending
            )

            HStack {
                Text(
                    formatTime(
                        isSeeking || session.pendingSeekPosition != nil
                            ? seekValue
                            : timePublisher.currentTime
                    )
                )
                Spacer()
                Text(formatTime(timePublisher.duration))
            }
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .foregroundStyle(Color.monoTextSecondary)
            .monospacedDigit()
        }
        .frame(maxWidth: 420)
    }

    private var playbackControls: some View {
        HStack(spacing: 30) {
            controlButton(icon: .previous, size: 20, isEnabled: session.canControlPlayback) {
                session.changeTrack(by: -1)
            }

            Button {
                session.toggleRoomPlayback()
            } label: {
                Group {
                    if session.isPlaybackControlPending {
                        ProgressView()
                            .tint(accentControlForeground)
                    } else {
                        MonoIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 23,
                            color: accentControlForeground
                        )
                    }
                }
                .frame(width: 58, height: 58)
                .background(Circle().fill(accentControlFill))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
            .disabled(!session.canControlPlayback || session.isPlaybackControlPending)
            .opacity(session.canControlPlayback ? 1 : 0.42)

            controlButton(icon: .next, size: 20, isEnabled: session.canControlPlayback) {
                session.changeTrack(by: 1)
            }
        }
    }

    private func controlButton(
        icon: MonoIcon.IconType,
        size: CGFloat,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: size, color: .monoTextPrimary)
                .frame(width: 46, height: 46)
                .contentShape(Circle())
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
    }

    private var participantsStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "mono_session_members"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.monoTextPrimary)
                Spacer()

                if session.role == .host {
                    Button {
                        session.setMembersCanControlPlayback(!session.membersCanControlPlayback)
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        HStack(spacing: 7) {
                            Text(String(localized: "mono_session_members_playback_control"))
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.68))

                            Capsule()
                                .fill(
                                    session.membersCanControlPlayback
                                        ? accentControlFill
                                        : Color.white.opacity(0.12)
                                )
                                .frame(width: 34, height: 20)
                                .overlay {
                                    Capsule()
                                        .stroke(
                                            session.membersCanControlPlayback
                                                ? accentControlForeground.opacity(0.22)
                                                : Color.white.opacity(0.14),
                                            lineWidth: 0.7
                                        )
                                }
                                .overlay(alignment: session.membersCanControlPlayback ? .trailing : .leading) {
                                    Circle()
                                        .fill(
                                            session.membersCanControlPlayback
                                                ? accentControlForeground
                                                : Color.white.opacity(0.78)
                                        )
                                        .frame(width: 16, height: 16)
                                        .shadow(color: Color.black.opacity(0.2), radius: 1.5, y: 1)
                                        .padding(2)
                                }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(
                        session.membersCanControlPlayback
                            ? String(localized: "settings_on")
                            : String(localized: "settings_off")
                    )
                }

                Text("\(session.room?.participants.count ?? 0)/16")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.monoTextSecondary)
                    .monospacedDigit()
            }

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(session.room?.participants ?? []) { participant in
                        participantView(participant)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var queuePanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "mono_session_queue"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(session.sharedQueue.count)")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.44))
                        .monospacedDigit()
                }

                Spacer(minLength: 8)

                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        isQueueCollapsed = false
                        showsQueueSearch.toggle()
                    }
                    searchFocused = showsQueueSearch
                    if !showsQueueSearch {
                        dismissKeyboard()
                    }
                } label: {
                    MonoIcon(
                        icon: showsQueueSearch ? .close : .search,
                        size: 14,
                        color: .white.opacity(0.86)
                    )
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "mono_session_search"))

                Button {
                    let willCollapse = !isQueueCollapsed
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        isQueueCollapsed = willCollapse
                        if willCollapse {
                            showsQueueSearch = false
                        }
                    }
                    if willCollapse {
                        dismissKeyboard()
                    }
                } label: {
                    MonoIcon(
                        icon: isQueueCollapsed ? .chevronDown : .chevronUp,
                        size: 13,
                        color: .white.opacity(0.86)
                    )
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isQueueCollapsed
                        ? String(localized: "mono_session_queue_expand")
                        : String(localized: "mono_session_queue_collapse")
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isQueueCollapsed {
                Group {
                    if showsQueueSearch {
                        queueSearchPanel
                    } else {
                        roomQueueList
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var queueSearchPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 9) {
                MonoIcon(icon: .search, size: 14, color: .white.opacity(0.46))
                TextField(String(localized: "mono_session_search"), text: $roomSearchQuery)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .monoOnSubmit(text: $roomSearchQuery) { _ in
                        performRoomSearch()
                    }

                if isQueueSearching {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white.opacity(0.72))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.075))
            )

            if search.hasSearched {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(roomSearchResults.enumerated()), id: \.offset) { _, song in
                            searchSongRow(song)
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
                .frame(maxHeight: 260)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 13)
    }

    private var roomQueueList: some View {
        Group {
            if session.sharedQueue.isEmpty {
                Text(String(localized: "mono_session_queue_empty"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(session.sharedQueue.enumerated()), id: \.offset) { index, song in
                            roomQueueRow(song, index: index)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 236)
            }
        }
    }

    private func searchSongRow(_ song: Song) -> some View {
        let added = session.sharedQueue.contains { sameSong($0, song) }
        return Button {
            guard !added else { return }
            session.addSongToQueue(song)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            sessionSongRow(
                song,
                leadingText: nil,
                trailingIcon: added ? .checkmark : .add,
                trailingColor: added ? .white.opacity(0.36) : .white.opacity(0.82),
                showsSource: true
            )
        }
        .buttonStyle(.plain)
        .disabled(added)
    }

    private func roomQueueRow(_ song: Song, index: Int) -> some View {
        let current = sameSong(player.currentSong, song)
        let pending = sameSong(session.pendingTrackRequest, song)
        return Button {
            session.playSongFromQueue(song)
        } label: {
            sessionSongRow(
                song,
                leadingText: current ? nil : String(format: "%02d", index + 1),
                trailingIcon: current ? (player.isPlaying ? .pause : .play) : nil,
                trailingColor: .white.opacity(current ? 0.94 : 0.42),
                showsLoading: pending
            )
        }
        .buttonStyle(.plain)
        .disabled(!session.canControlPlayback || pending)
        .contextMenu {
            if session.role == .host, !current {
                Button(role: .destructive) {
                    session.removeSongFromQueue(song)
                } label: {
                    Text(String(localized: "lib_delete"))
                }
            }
        }
    }

    private func sessionSongRow(
        _ song: Song,
        leadingText: String?,
        trailingIcon: MonoIcon.IconType?,
        trailingColor: Color,
        showsLoading: Bool = false,
        showsSource: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            if let leadingText {
                Text(leadingText)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.32))
                    .monospacedDigit()
                    .frame(width: 22)
            }

            CachedAsyncImage(url: song.coverUrl?.sized(100)) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            }
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(song.artistName)
                        .lineLimit(1)

                    if showsSource {
                        Text(song.musicSource.shortName)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                }
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
            }

            Spacer(minLength: 6)

            if showsLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white.opacity(0.82))
                    .frame(width: 30, height: 30)
            } else if let trailingIcon {
                MonoIcon(icon: trailingIcon, size: 13, color: trailingColor)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
        }
        .padding(.horizontal, 7)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }

    private func participantView(_ participant: MonoSessionParticipant) -> some View {
        VStack(spacing: 6) {
            sessionAvatar(participant: participant, size: 40)

            Text(participant.displayName)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color.monoTextSecondary)
                .lineLimit(1)
                .frame(maxWidth: 70)
        }
    }

    private var chatPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(String(localized: "mono_session_chat"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.monoTextPrimary)
                Spacer()
                Text(String(format: String(localized: "mono_session_member_count"), session.room?.participants.count ?? 0))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.monoTextSecondary)

                Text(String(localized: "mono_session_chat_notice"))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }
            .padding(.horizontal, 15)
            .frame(height: 48)

            Rectangle()
                .fill(Color.monoSeparator.opacity(0.65))
                .frame(height: 0.5)

            chatMessages

            if let error = session.chatErrorText {
                Text(error)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.red.opacity(0.86))
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
            }

            chatComposer
        }
    }

    private var chatMessages: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(spacing: 11) {
                    if session.chatMessages.isEmpty {
                        Text(String(localized: "mono_session_chat_empty"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.monoTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 28)
                    } else {
                        ForEach(session.chatMessages) { message in
                            chatBubble(message)
                                .id(message.id)
                        }
                    }
                }
                .padding(14)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: session.chatMessages.count) { _, _ in
                guard let lastID = session.chatMessages.last?.id else { return }
                if reduceMotion {
                    reader.scrollTo(lastID, anchor: .bottom)
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        reader.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func chatBubble(_ message: MonoSessionChatMessage) -> some View {
        let mine = message.senderID == DeviceIdentifier.uuid
        let participant = session.room?.participants.first { $0.id == message.senderID }
        return HStack {
            if mine { Spacer(minLength: 42) }

            if !mine {
                sessionAvatar(
                    participant: participant,
                    fallbackAvatarURL: message.senderAvatarURL,
                    size: 30
                )
                    .alignmentGuide(.top) { $0[.top] }
            }

            VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(message.senderName)
                    Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.monoTextSecondary)

                Text(message.text)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(mine ? accentControlForeground : Color.monoTextPrimary)
                    .multilineTextAlignment(mine ? .trailing : .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(mine ? accentControlFill : Color.monoTextPrimary.opacity(0.07))
                    )
            }

            if mine {
                sessionAvatar(
                    participant: participant,
                    fallbackAvatarURL: message.senderAvatarURL,
                    size: 30
                )
                    .alignmentGuide(.top) { $0[.top] }
            } else {
                Spacer(minLength: 42)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var chatComposer: some View {
        HStack(spacing: 9) {
            TextField(String(localized: "mono_session_chat_placeholder"), text: $chatText, axis: .vertical)
                .focused($chatFocused)
                .lineLimit(1...3)
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .textFieldStyle(.plain)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.monoTextPrimary.opacity(0.06))
                )
                .submitLabel(.send)
                .monoOnSubmit(text: $chatText) { _ in
                    sendChat()
                }

            Button {
                MonoTextInputCommitter.commit(text: $chatText) { _ in
                    sendChat()
                }
            } label: {
                MonoIcon(icon: .send, size: 16, color: accentControlForeground)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(accentControlFill))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
            .disabled(chatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(10)
        .id("mono-session-chat-composer")
    }

    private var roomStatusText: String {
        if let room = session.room {
            return String(format: String(localized: "mono_session_room_status"), room.inviteCode, room.participants.count)
        }
        switch session.connectionState {
        case .connecting: return String(localized: "mono_session_connecting")
        case .connected: return String(localized: "mono_session_connected")
        case .failed(let message): return message
        case .disconnected, .inRoom: return String(localized: "mono_session_ready")
        }
    }

    private var isConnecting: Bool {
        if case .connecting = session.connectionState { return true }
        return false
    }

    private func enableSessionIfNeeded() {
        if !suite.isEnabled(.session) {
            suite.setEnabled(.session, enabled: true)
        }
    }

    private func sendChat() {
        let message = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        Task {
            if await session.sendChat(message) {
                chatText = ""
                chatFocused = false
            }
        }
    }

    private var isQueueSearching: Bool {
        search.isNeteaseLoading || search.isQQLoading || search.isQishuiLoading
    }

    /// Interleave platforms so one provider cannot occupy the entire visible result set.
    private var roomSearchResults: [Song] {
        let platformResults = [
            search.neteaseResults,
            search.qqResults,
            search.qishuiResults
        ]
        let largestResultCount = platformResults.map(\.count).max() ?? 0
        guard largestResultCount > 0 else { return [] }

        var results: [Song] = []
        results.reserveCapacity(platformResults.reduce(0) { $0 + $1.count })
        for index in 0..<largestResultCount {
            for songs in platformResults where songs.indices.contains(index) {
                results.append(songs[index])
            }
        }
        return results
    }

    private func performRoomSearch() {
        let keyword = roomSearchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        searchFocused = false
        search.performSearch(keyword: keyword)
    }

    private func joinRoom() {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        dismissKeyboard()
        enableSessionIfNeeded()
        Task { await session.joinRoom(inviteCode: code) }
    }

    private func dismissKeyboard() {
        inviteFocused = false
        chatFocused = false
        searchFocused = false
    }

    private var accentControlFill: Color {
        Color.monoIconBackground
    }

    private var accentControlForeground: Color {
        ThemeColorCustomization.readableForegroundColor(
            on: accentControlFill,
            colorScheme: .dark,
            light: Color(hex: "111821"),
            dark: .white
        )
    }

    @ViewBuilder
    private func sessionAvatar(
        participant: MonoSessionParticipant?,
        fallbackAvatarURL: String? = nil,
        size: CGFloat
    ) -> some View {
        let isHost = participant?.role == .host
        let fill = isHost ? accentControlFill : Color.white.opacity(0.09)
        let foreground = isHost ? accentControlForeground : Color.white.opacity(0.72)

        Group {
            if let source = participant?.avatarURL ?? fallbackAvatarURL,
               let url = URL(string: source) {
                CachedAsyncImage(url: url, width: size, height: size) {
                    avatarPlaceholder(fill: fill, foreground: foreground, size: size)
                }
                .aspectRatio(contentMode: .fill)
            } else {
                avatarPlaceholder(fill: fill, foreground: foreground, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(
                    isHost ? accentControlForeground.opacity(0.34) : Color.white.opacity(0.12),
                    lineWidth: 0.8
                )
        }
    }

    private func avatarPlaceholder(
        fill: Color,
        foreground: Color,
        size: CGFloat
    ) -> some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay {
                MonoIcon(
                    icon: .profile,
                    size: max(12, size * 0.42),
                    color: foreground
                )
            }
    }

    private func sameSong(_ lhs: Song?, _ rhs: Song) -> Bool {
        guard let lhs else { return false }
        return lhs.id == rhs.id && lhs.musicSource == rhs.musicSource
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let value = Int(seconds)
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

private struct MonoSessionViewport {
    let viewportWidth: CGFloat
    let availableHeight: CGFloat
    let horizontalInset: CGFloat
    let innerWidth: CGFloat
    let usesTwoColumns: Bool
    let playerColumnWidth: CGFloat
    let deckColumnWidth: CGFloat
    let landscapeCoverSize: CGFloat

    init(size: CGSize) {
        let availableWidth = max(1, size.width)
        availableHeight = max(1, size.height)
        usesTwoColumns = availableWidth >= 760
        viewportWidth = min(availableWidth, usesTwoColumns ? 1120 : availableWidth)
        horizontalInset = viewportWidth < 350 ? 12 : (viewportWidth < 760 ? 16 : 28)
        innerWidth = max(1, viewportWidth - horizontalInset * 2)

        if usesTwoColumns {
            let usable = max(1, innerWidth - 22)
            deckColumnWidth = min(470, max(340, usable * 0.45))
            playerColumnWidth = max(300, usable - deckColumnWidth)
            landscapeCoverSize = min(320, max(210, playerColumnWidth - 86))
        } else {
            playerColumnWidth = innerWidth
            deckColumnWidth = innerWidth
            landscapeCoverSize = min(286, max(190, innerWidth - 72))
        }
    }
}
