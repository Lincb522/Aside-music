import SwiftUI

struct SongDetailView: View {
    let song: Song

    @StateObject private var viewModel = SongDetailViewModel()
    @ObservedObject private var settings = SettingsManager.shared

    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false

    struct Theme {
        static var text: Color {
            if SignalStyle.isActive { return SignalStyle.ink }
            if SequoiaStyle.isActive { return SequoiaStyle.ink }
            if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
            return Color.monoTextPrimary
        }

        static var secondaryText: Color {
            if SignalStyle.isActive { return SignalStyle.inkSoft }
            if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
            if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
            return Color.monoTextSecondary
        }

        static var accent: Color {
            if SignalStyle.isActive { return SignalStyle.accent }
            if SequoiaStyle.isActive { return SequoiaStyle.accent }
            if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
            return Color.monoIconBackground
        }

        static var accentForeground: Color {
            if SignalStyle.isActive { return SignalStyle.onAccent }
            if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
            if NeumorphicStyle.isActive { return Color(light: .white, dark: .black) }
            return Color.monoIconForeground
        }

        static var coverFill: Color {
            if SignalStyle.isActive { return SignalStyle.controlPressed }
            if SequoiaStyle.isActive { return SequoiaStyle.materialPressed.opacity(0.74) }
            if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
            return Color.gray.opacity(0.3)
        }
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        GeometryReader { viewport in
            let contentWidth = min(max(viewport.size.width, 1), 680)
            let heroHeight = resolvedHeroHeight(
                contentWidth: contentWidth,
                viewportHeight: max(viewport.size.height, 1)
            )

            ZStack {
                if SignalStyle.isActive {
                    SignalRootBackdrop()
                } else {
                    PlaylistColorBackground(coverUrl: song.coverUrl?.sized(720))
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if SignalStyle.isActive {
                            signalHeroSection(height: heroHeight)
                                .monoPageHeaderCollapse()
                        } else {
                            heroSection(height: heroHeight)
                                .monoPageHeaderCollapse()
                        }
                        platformContent
                        similarSongsSection
                        artistSongsSection
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.bottom, 120)
                }
                .frame(maxWidth: .infinity)
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
                .ignoresSafeArea(edges: .top)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .monoNavigationBackButton()
        .navigationDestination(isPresented: $showArtistDetail) {
            if let artistId = selectedArtistId {
                ArtistDetailView(artistId: artistId)
            }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let selectedSongForDetail {
                SongDetailView(song: selectedSongForDetail)
            }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let albumId = selectedAlbumId {
                AlbumDetailView(
                    albumId: albumId,
                    albumName: song.al?.name,
                    albumCoverUrl: song.coverUrl
                )

            }
        }
        .task(id: song.platformIdentity.cacheKey) {
            viewModel.load(song: song)
        }
        .onDisappear {
            viewModel.cancelLoading()
        }
    }

    // MARK: - Hero

    private func heroSection(height: CGFloat) -> some View {
        GeometryReader { hero in
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: song.coverUrl?.sized(1_000)) {
                    Theme.coverFill
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: hero.size.width, height: hero.size.height)
                .clipped()
                .blur(radius: 24)
                .scaleEffect(1.12)

                CachedAsyncImage(url: song.coverUrl?.sized(1_000)) {
                    Theme.coverFill
                }
                .aspectRatio(contentMode: .fit)
                .padding(.vertical, min(30, hero.size.height * 0.07))
                .frame(width: hero.size.width, height: hero.size.height)

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.04), location: 0),
                        .init(color: .clear, location: 0.28),
                        .init(color: .black.opacity(0.24), location: 0.52),
                        .init(color: .black.opacity(0.95), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        if let alias = song.alia?.first, !alias.isEmpty {
                            Text(alias)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }

                        Text(song.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            guard let artistID = song.artists.first?.id, artistID > 0 else { return }
                            selectedArtistId = artistID
                            showArtistDetail = true
                        } label: {
                            Text(song.artistName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.78))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .disabled((song.artists.first?.id ?? 0) <= 0)
                    }

                    heroActions
                    heroMetadata
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
            }
        }
        .frame(height: height)
        .clipped()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func signalHeroSection(height: CGFloat) -> some View {
        GeometryReader { hero in
            let coverSize = min(hero.size.width * 0.52, hero.size.height * 0.36, 230)

            VStack(spacing: 14) {
                Spacer(minLength: 58)

                ZStack {
                    SignalScreenBackground(cornerRadius: 15)

                    CachedAsyncImage(url: song.coverUrl?.sized(1_000)) {
                        Theme.coverFill
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: coverSize - 20, height: coverSize - 20)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                }
                .frame(width: coverSize, height: coverSize)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(SignalStyle.separator.opacity(0.74), lineWidth: 0.8)
                }
                .shadow(color: Color.black.opacity(0.24), radius: 18, y: 8)

                VStack(spacing: 6) {
                    if let alias = song.alia?.first, !alias.isEmpty {
                        Text(alias)
                            .font(SignalStyle.labelFont(10, weight: .medium))
                            .foregroundStyle(SignalStyle.inkMuted)
                            .lineLimit(1)
                    }

                    Text(song.name)
                        .font(SignalStyle.titleFont(23, weight: .bold))
                        .foregroundStyle(SignalStyle.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Button {
                        guard let artistID = song.artists.first?.id, artistID > 0 else { return }
                        selectedArtistId = artistID
                        showArtistDetail = true
                    } label: {
                        Text(song.artistName)
                            .font(SignalStyle.bodyFont(13, weight: .medium))
                            .foregroundStyle(SignalStyle.inkSoft)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .disabled((song.artists.first?.id ?? 0) <= 0)
                }

                heroActions

                heroMetadata
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .frame(width: hero.size.width, height: hero.size.height)
            .background {
                ZStack {
                    LinearGradient(
                        colors: [Color.white.opacity(0.018), .clear, SignalStyle.surfaceInset.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
        .frame(height: height)
        .clipped()
        .accessibilityElement(children: .contain)
    }

    private func resolvedHeroHeight(contentWidth: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        let aspectHeight = contentWidth / (DeviceLayout.isPad ? 1.08 : 0.86)
        let viewportLimit = viewportHeight * (DeviceLayout.isPad ? 0.58 : 0.56)
        let absoluteLimit: CGFloat = DeviceLayout.isPad ? 520 : 480
        return max(280, min(aspectHeight, viewportLimit, absoluteLimit))
    }

    private var heroActions: some View {
        SongDetailHeroActions(
            song: song,
            playbackContext: viewModel.relatedSongs.isEmpty
                ? [song]
                : [song] + viewModel.relatedSongs
        )
    }

    @ViewBuilder
    private var heroMetadata: some View {
        let items = metadataItems
        if !items.isEmpty {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.label)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.56))
                        Text(item.value)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if index < items.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 0.8, height: 34)
                            .padding(.horizontal, 12)
                    }
                }
            }
            .padding(.top, 15)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.white.opacity(0.13)).frame(height: 0.8)
            }
        }
    }

    // MARK: - Platform content

    private var platformContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 9) {
                MonoIcon(icon: .infoCircle, size: 16, color: Theme.secondaryText)
                Text(
                    String(
                        format: NSLocalizedString("song_detail_platform_information", comment: ""),
                        song.musicSource.displayName
                    )
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            }

            if !viewModel.platformDetail.attributes.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 138), spacing: 12)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(viewModel.platformDetail.attributes) { attribute in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(attribute.label)
                                .font(SignalStyle.isActive ? SignalStyle.labelFont(10, weight: .medium) : .caption)
                                .foregroundStyle(Theme.secondaryText)
                            Text(attribute.value)
                                .font(SignalStyle.isActive ? SignalStyle.bodyFont(13, weight: .semibold) : .subheadline.weight(.semibold))
                                .foregroundStyle(Theme.text)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background {
                            if SignalStyle.isActive {
                                SignalSurfaceBackground(cornerRadius: 10, elevated: false, pressed: true, fill: SignalStyle.control)
                            } else {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.text.opacity(0.055))
                            }
                        }
                    }
                }
            }

            ForEach(viewModel.platformDetail.sections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    Text(section.title)
                        .font(SignalStyle.isActive ? SignalStyle.titleFont(18, weight: .bold) : .title3.weight(.bold))
                        .foregroundStyle(Theme.text)
                    Text(section.body)
                        .font(SignalStyle.isActive ? SignalStyle.bodyFont(14, weight: .regular) : .body)
                        .foregroundStyle(Theme.text.opacity(0.88))
                        .lineSpacing(6)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(SignalStyle.isActive ? 15 : 0)
                .background {
                    if SignalStyle.isActive {
                        SignalSurfaceBackground(cornerRadius: 12, elevated: false, fill: SignalStyle.surface)
                    }
                }
            }

            if viewModel.isPlatformDetailLoading,
               viewModel.platformDetail.sections.isEmpty {
                platformContentSkeleton
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
    }

    private var platformContentSkeleton: some View {
        VStack(alignment: .leading, spacing: 13) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Theme.text.opacity(0.12))
                .frame(width: 112, height: 22)
            ForEach([1.0, 0.96, 0.88, 0.72], id: \.self) { width in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.text.opacity(0.08))
                    .frame(maxWidth: .infinity)
                    .frame(height: 15)
                    .scaleEffect(x: width, anchor: .leading)
            }
        }
        .accessibilityLabel(String(localized: "song_detail_platform_loading"))
    }

    // MARK: - Recommendations

    @ViewBuilder
    private var similarSongsSection: some View {
        if !viewModel.simiSongs.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(String(localized: "simi_songs_title"))

                ScrollView(.horizontal) {
                    HStack(spacing: 14) {
                        ForEach(viewModel.simiSongs.prefix(10)) { simiSong in
                            Button {
                                PlayerManager.shared.play(song: simiSong, in: viewModel.simiSongs)
                                selectedSongForDetail = simiSong
                                showSongDetail = true
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    CachedAsyncImage(url: simiSong.coverUrl?.sized(300)) {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Theme.text.opacity(0.08))
                                    }
                                    .frame(width: 124, height: 124)
                                    .clipShape(RoundedRectangle(cornerRadius: SignalStyle.isActive ? 8 : 12, style: .continuous))
                                    .overlay {
                                        if SignalStyle.isActive {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(SignalStyle.separator.opacity(0.72), lineWidth: 0.7)
                                        }
                                    }

                                    Text(simiSong.name)
                                        .font(SignalStyle.isActive ? SignalStyle.bodyFont(13, weight: .semibold) : .subheadline.weight(.medium))
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)
                                        .frame(width: 124, alignment: .leading)

                                    Text(simiSong.artistName)
                                        .font(SignalStyle.isActive ? SignalStyle.labelFont(10, weight: .medium) : .caption)
                                        .foregroundStyle(Theme.secondaryText)
                                        .lineLimit(1)
                                        .frame(width: 124, alignment: .leading)
                                }
                            }
                            .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
            }
            .padding(.top, 34)
        }
    }

    @ViewBuilder
    private var artistSongsSection: some View {
        if !viewModel.relatedSongs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(
                    String(format: NSLocalizedString("more_by_artist", comment: ""), song.artistName)
                )

                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.relatedSongs.enumerated()), id: \.element.id) { index, relatedSong in
                        SongListRow(
                            song: relatedSong,
                            index: index,
                            onArtistTap: { artistId in
                                selectedArtistId = artistId
                                showArtistDetail = true
                            },
                            onDetailTap: { detailSong in
                                selectedSongForDetail = detailSong
                                showSongDetail = true
                            },
                            onAlbumTap: { albumId in
                                selectedAlbumId = albumId
                                showAlbumDetail = true
                            },
                            onTap: {
                                PlayerManager.shared.play(song: relatedSong, in: viewModel.relatedSongs)
                            }
                        )
                    }
                }
            }
            .padding(.top, 30)
        } else if viewModel.isRelatedLoading {
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Theme.text.opacity(0.1))
                    .frame(width: 150, height: 20)
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.text.opacity(0.06))
                        .frame(height: 58)
                }
            }
            .accessibilityLabel(String(localized: "song_detail_related_loading"))
            .padding(.horizontal, 20)
            .padding(.top, 30)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Group {
            if SignalStyle.isActive {
                SignalSectionTitle(title: title)
            } else {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.text)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Values and actions

    private var metadataItems: [SongDetailMetadataItem] {
        var items: [SongDetailMetadataItem] = []

        if let duration = formattedDuration(milliseconds: song.dt) {
            items.append(
                SongDetailMetadataItem(
                    label: String(localized: "song_detail_duration"),
                    value: duration
                )
            )
        }

        if let releaseDate = normalizedContent(viewModel.platformDetail.releaseDate) {
            items.append(
                SongDetailMetadataItem(
                    label: String(localized: "song_detail_release_date"),
                    value: releaseDate
                )
            )
        }

        if let album = normalizedContent(song.album?.name) {
            items.append(
                SongDetailMetadataItem(
                    label: String(localized: "song_detail_album"),
                    value: album
                )
            )
        }

        return items
    }

    private func formattedDuration(milliseconds: Int?) -> String? {
        guard let milliseconds, milliseconds > 0 else { return nil }
        let seconds = milliseconds / 1_000
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func normalizedContent(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

}

private struct SongDetailMetadataItem: Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

/// Keeps playback and collection updates inside the three hero controls so
/// their state changes do not invalidate the image-heavy detail page.
private struct SongDetailHeroActions: View {
    let song: Song
    let playbackContext: [Song]

    @ObservedObject private var playerManager = PlayerManager.shared
    @ObservedObject private var likeManager = LikeManager.shared

    var body: some View {
        HStack(spacing: 10) {
            Button(action: togglePlayback) {
                actionLabel(
                    icon: isCurrentSongPlaying ? .pause : .play,
                    title: isCurrentSongPlaying
                        ? String(localized: "action_pause")
                        : String(localized: "action_play")
                )
            }
            .buttonStyle(SongDetailHeroButtonStyle())

            Button {
                likeManager.toggleLike(
                    songId: song.id,
                    isQQMusic: song.isQQMusic,
                    song: song
                )
            } label: {
                actionLabel(
                    icon: isLiked ? .liked : .like,
                    title: isLiked
                        ? String(localized: "song_detail_collected")
                        : String(localized: "action_favorite")
                )
            }
            .buttonStyle(SongDetailHeroButtonStyle())

            if let shareURL {
                ShareLink(item: shareURL, subject: Text(song.name), message: Text(song.artistName)) {
                    actionLabel(icon: .share, title: String(localized: "action_share"))
                }
                .buttonStyle(SongDetailHeroButtonStyle())
            }
        }
    }

    private func actionLabel(icon: MonoIcon.IconType, title: String) -> some View {
        HStack(spacing: 7) {
            MonoIcon(icon: icon, size: 15, color: SignalStyle.isActive ? SignalStyle.accent : .white)
            Text(title)
                .font(SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .bold) : .subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(SignalStyle.isActive ? SignalStyle.ink : .white)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background {
            if SignalStyle.isActive {
                SignalSurfaceBackground(cornerRadius: 9, elevated: false, pressed: true, fill: SignalStyle.control)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.25))
            }
        }
        .overlay {
            if !SignalStyle.isActive {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: SignalStyle.isActive ? 9 : 14, style: .continuous))
    }

    private var isLiked: Bool {
        likeManager.isLiked(id: song.id, isQQMusic: song.isQQMusic)
    }

    private var isCurrentSongPlaying: Bool {
        PlayerManager.matchesPlaybackTarget(playerManager.currentSong, expected: song)
            && playerManager.isPlaying
    }

    private func togglePlayback() {
        if PlayerManager.matchesPlaybackTarget(playerManager.currentSong, expected: song) {
            playerManager.togglePlayPause()
        } else {
            playerManager.play(song: song, in: playbackContext)
        }
    }

    private var shareURL: URL? {
        guard var components = URLComponents(string: SecureConfig.officialWebsiteBaseURL) else {
            return nil
        }
        let route = "/song"
        components.path = components.path.hasSuffix("/")
            ? "\(components.path)\(route.dropFirst())"
            : "\(components.path)\(route)"
        components.queryItems = [
            URLQueryItem(name: "platform", value: song.platformIdentity.platform),
            URLQueryItem(name: "song_id", value: song.platformIdentity.platformSongID),
        ]
        return components.url
    }
}

/// Opacity-only press feedback stays on the compositor and avoids rerasterizing
/// the cover and blur layers behind the controls.
private struct SongDetailHeroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed && !EdgeSwipeGuard.shared.isSwiping

        configuration.label
            .opacity(isPressed ? 0.76 : 1)
            .animation(.linear(duration: 0.06), value: isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && !EdgeSwipeGuard.shared.isSwiping {
                    HapticManager.shared.light()
                }
            }
    }
}
