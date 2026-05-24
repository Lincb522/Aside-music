#if os(macOS)
import SwiftUI
import HiconIcons

// MARK: - macOS 主框架

struct MacContentView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @State private var currentTab: Tab = .home
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var showNormalPlayer = false
    @State private var showPersonalFM = false
    @State private var showRadioPlayer = false
    @State private var radioPlayerRadioId: Int? = nil
    @StateObject private var alertManager = AlertManager.shared

    @State private var sidebarHovered: Tab? = nil
    @State private var showSearch = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            ThemedPageBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                macTitleBar
                
                HStack(spacing: 0) {
                    MacSidebarView(
                        currentTab: $currentTab,
                        hoveredTab: $sidebarHovered,
                        onSearch: { showSearch = true },
                        onSettings: { showSettings = true }
                    )
                    
                    macMainContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if player.currentSong != nil {
                    MacPlayerBar(onSongTap: handleSongTap)
                }
            }

            if alertManager.isPresented {
                MonologueAlertView(
                    title: alertManager.title,
                    message: alertManager.message,
                    primaryButtonTitle: alertManager.primaryButtonTitle,
                    secondaryButtonTitle: alertManager.secondaryButtonTitle,
                    primaryAction: { alertManager.primaryAction?() },
                    secondaryAction: {
                        alertManager.secondaryAction?()
                        alertManager.dismiss()
                    },
                    isPresented: $alertManager.isPresented,
                    inputMode: alertManager.inputMode,
                    inputText: $alertManager.inputText,
                    inputPlaceholder: alertManager.inputPlaceholder,
                    isSecureInput: alertManager.isSecureInput,
                    inputAction: { text in
                        alertManager.inputAction?(text)
                        alertManager.dismiss()
                    }
                )
                .zIndex(999)
            }
        }
        .monologueSheet(isPresented: $showNormalPlayer, preset: .detail) {
            MacNowPlayingView()
                .frame(minWidth: 560, minHeight: 700)
        }
        .monologueSheet(isPresented: $showPersonalFM, preset: .detail) {
            PersonalFMView()
                .frame(minWidth: 480, minHeight: 640)
        }
        .monologueSheet(isPresented: $showRadioPlayer, preset: .detail) {
            if let radioId = radioPlayerRadioId {
                PodcastPlayerView(radioId: radioId)
                    .frame(minWidth: 480, minHeight: 640)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("OpenFMPlayer"))) { _ in
            showPersonalFM = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("OpenNormalPlayer"))) { _ in
            showNormalPlayer = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("OpenRadioPlayer"))) { notification in
            if let radioId = notification.object as? Int, radioId > 0 {
                radioPlayerRadioId = radioId
                showRadioPlayer = true
            }
        }
        .onChange(of: systemColorScheme) { _, newScheme in
            if settings.themeMode == "system" {
                settings.activeColorScheme = newScheme
            }
        }
    }

    // MARK: - Title Bar

    private var macTitleBar: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 78, height: 52)

            Text("Mono")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.6))

            Spacer()

            HStack(spacing: 4) {
                macTitleButton(icon: "magnifyingglass") { showSearch.toggle() }
                macTitleButton(icon: "gearshape") { showSettings.toggle() }
            }
            .padding(.trailing, 16)
        }
        .frame(height: 52)
        .background(.ultraThinMaterial.opacity(0.5))
    }

    private func macTitleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(Color.primary.opacity(0.05))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var macMainContent: some View {
        ZStack {
            switch currentTab {
            case .home:
                NavigationStack { MacHomeView() }
            case .podcast:
                NavigationStack { PodcastView() }
            case .library:
                NavigationStack { MacLibraryView() }
            case .profile:
                NavigationStack { MacProfileView() }
            }

            if showSearch {
                MacSearchOverlay(isPresented: $showSearch)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(100)
            }

            if showSettings {
                MacSettingsOverlay(isPresented: $showSettings)
                    .transition(.move(edge: .trailing))
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showSearch)
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: showSettings)
    }

    private func handleSongTap() {
        switch player.playSource {
        case .fm:
            showPersonalFM = true
        case .podcast(let radioId):
            radioPlayerRadioId = radioId
            showRadioPlayer = true
        case .normal:
            showNormalPlayer = true
        }
    }
}

// MARK: - Sidebar

struct MacSidebarView: View {
    @Binding var currentTab: Tab
    @Binding var hoveredTab: Tab?
    var onSearch: () -> Void
    var onSettings: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let sidebarWidth: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarGroup(title: String(localized: "browse_section")) {
                sidebarRow(.home, icon: "house.fill", label: String(localized: "tabbar_home"))
                sidebarRow(.podcast, icon: "waveform.circle.fill", label: String(localized: "tabbar_podcast"))
            }
            .padding(.top, 8)

            sidebarDivider

            sidebarGroup(title: String(localized: "library_section")) {
                sidebarRow(.library, icon: "square.stack.3d.up.fill", label: String(localized: "tabbar_library"))
                sidebarRow(.profile, icon: "person.crop.circle.fill", label: String(localized: "tabbar_profile"))
            }

            Spacer()

            VStack(spacing: 2) {
                sidebarActionRow(icon: "magnifyingglass", label: String(localized: "search_title"), action: onSearch)
                sidebarActionRow(icon: "gearshape", label: String(localized: "settings_title"), action: onSettings)
            }
            .padding(.bottom, 16)
        }
        .frame(width: sidebarWidth)
        .background(sidebarBackground)
    }

    // MARK: - Group

    @ViewBuilder
    private func sidebarGroup(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.tertiary)
                .tracking(1.2)
                .padding(.horizontal, 24)
                .padding(.bottom, 6)

            content()
        }
    }

    // MARK: - Row

    private func sidebarRow(_ tab: Tab, icon: String, label: String) -> some View {
        let isActive = currentTab == tab
        let isHover = hoveredTab == tab

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                currentTab = tab
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? Color.accentColor : Color.primary.opacity(isHover ? 0.08 : 0.04))
                        .frame(width: 30, height: 30)

                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isActive ? .white : .secondary)
                }

                Text(label)
                    .font(.system(size: 13, weight: isActive ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isActive ? .primary : .secondary)

                Spacer()

                if isActive {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.08) : (isHover ? Color.primary.opacity(0.03) : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hover in
            withAnimation(.easeOut(duration: 0.15)) {
                hoveredTab = hover ? tab : nil
            }
        }
    }

    private func sidebarActionRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 30)

                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    // MARK: - Styling

    private var sidebarDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
    }

    private var sidebarBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).opacity(0.3)
            Rectangle().fill(.ultraThinMaterial.opacity(0.4))
        }
    }
}

// MARK: - Player Bar

struct MacPlayerBar: View {
    var onSongTap: () -> Void

    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @State private var isProgressHovered = false
    @State private var showPlaylist = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            macProgressBar
                .frame(height: isProgressHovered ? 6 : 3)
                .animation(.spring(response: 0.2), value: isProgressHovered)

            HStack(spacing: 0) {
                songInfoSection
                    .frame(width: 260)

                Spacer()

                controlsSection

                Spacer()

                rightSection
                    .frame(width: 260)
            }
            .padding(.horizontal, 20)
            .frame(height: 72)
        }
        .background(playerBarBackground)
    }

    // MARK: - Progress

    private var macProgressBar: some View {
        GeometryReader { geo in
            let progress = player.duration > 0 ? min(max(player.currentTime / player.duration, 0), 1) : 0

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.primary.opacity(0.06))

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.8), Color.accentColor],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(progress))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        player.seek(to: Double(fraction) * player.duration)
                    }
            )
            .onHover { isProgressHovered = $0 }
        }
    }

    // MARK: - Song Info

    private var songInfoSection: some View {
        Group {
            if let song = player.currentSong {
                HStack(spacing: 14) {
                    Button(action: onSongTap) {
                        CachedAsyncImage(url: song.coverUrl) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(song.name)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .lineLimit(1)

                        Text(song.artistName)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        HStack(spacing: 24) {
            PlayerBarButton(icon: "shuffle", size: 12, isActive: player.mode == .shuffle) {
                player.switchMode()
            }

            PlayerBarButton(icon: "backward.fill", size: 14) {
                player.previous()
            }

            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 40, height: 40)

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .black : .white))
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(colorScheme == .dark ? .black : .white)
                            .offset(x: player.isPlaying ? 0 : 1.5)
                    }
                }
            }
            .buttonStyle(.plain)

            PlayerBarButton(icon: "forward.fill", size: 14) {
                player.next()
            }

            PlayerBarButton(icon: "repeat", size: 12, isActive: player.mode == .loopSingle) {
                player.switchMode()
            }
        }
    }

    // MARK: - Right Section

    private var rightSection: some View {
        HStack(spacing: 14) {
            Spacer(minLength: 0)

            timeDisplay

            PlayerBarButton(icon: "list.bullet", size: 13) {
                showPlaylist.toggle()
            }
            .popover(isPresented: $showPlaylist) {
                if player.isPlayingPodcast {
                    PodcastPlaylistPopupView()
                        .frame(width: 360, height: 480)
                } else {
                    PlaylistPopupView()
                        .frame(width: 360, height: 480)
                }
            }
        }
    }

    private var timeDisplay: some View {
        HStack(spacing: 4) {
            Text(formatTime(player.currentTime))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)

            Text("/")
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)

            Text(formatTime(player.duration))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .leading)
        }
    }

    private var playerBarBackground: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(Color(nsColor: .windowBackgroundColor).opacity(0.3))
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "0:00" }
        let total = Int(seconds)
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}

// MARK: - Player Bar Button

private struct PlayerBarButton: View {
    let icon: String
    var size: CGFloat = 13
    var isActive: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(isActive ? Color.primary : (isHovered ? Color.primary.opacity(0.7) : Color.secondary))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
#endif
