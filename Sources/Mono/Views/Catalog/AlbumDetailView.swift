// 专辑详情页

import SwiftUI

// MARK: - View

struct AlbumDetailView: View {
    let albumId: Int
    let albumName: String?
    let albumCoverUrl: URL?
    private let initialAlbum: AlbumInfo?

    @StateObject private var viewModel = AlbumDetailViewModel()
    @ObservedObject var playerManager = PlayerManager.shared
    @ObservedObject var subManager = SubscriptionManager.shared
    @ObservedObject private var settings = SettingsManager.shared

    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    @State private var showAlbumDesc = false
    @State private var isSelectMode = false
    @State private var selectedSongIds: Set<Int> = []
    @State private var showBatchAddToPlaylist = false
    @State private var albumSearchText = ""
    @State private var isAlbumSearching = false
    @State private var scrollOffset: CGFloat = 0

    private struct Theme {
        static var text: Color { .monoTextPrimary }
        static var secondaryText: Color { .monoTextSecondary }
        static var accent: Color { .monoIconBackground }
        static var milk: Color { .monoMilk }
    }

    init(albumId: Int, albumName: String?, albumCoverUrl: URL?) {
        self.albumId = albumId
        self.albumName = albumName
        self.albumCoverUrl = albumCoverUrl
        self.initialAlbum = nil
    }

    init(album: AlbumInfo) {
        self.albumId = album.id
        self.albumName = album.name
        self.albumCoverUrl = album.coverUrl
        self.initialAlbum = album
    }

    private var effectiveCoverUrl: URL? {
        viewModel.albumInfo?.coverUrl?.sized(200) ?? albumCoverUrl?.sized(200)
    }

    /// aside(default) 及无独立分支主题走歌手页式 Hero 头部
    private var usesAsideHero: Bool {
        !MangaStyle.isActive && !MinimalWhiteStyle.isActive
            && !NeumorphicStyle.isActive && !SignalStyle.isActive
            && !SequoiaStyle.isActive && !MujiStyle.isActive
            && !CapsuleStyle.isActive && !BentoStyle.isActive
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            MonoSheetAwareBackground {
                if MangaStyle.isActive {
                    MangaRootBackdrop()
                } else if MinimalWhiteStyle.isActive {
                    MinimalWhiteRootBackdrop()
                } else if MujiStyle.isActive {
                    MujiRootBackdrop()
                } else if NeumorphicStyle.isActive {
                    ThemeRenderBackdrop(theme: .neumorphic)
                } else if SignalStyle.isActive {
                    ThemeRenderBackdrop(theme: .default)
                } else if SequoiaStyle.isActive {
                    SequoiaRootBackdrop()
                } else if BentoStyle.isActive {
                    BentoRootBackdrop()
                } else if CapsuleStyle.isActive {
                    CapsuleRootBackdrop()
                } else if SettingsManager.shared.usesPlaylistCoverBackground {
            PlaylistColorBackground(coverUrl: effectiveCoverUrl)
        } else {
                    ThemedPageBackground()
                }
            }

            ScrollView {
                VStack(spacing: 0) {
                    if usesAsideHero {
                        // Hero 头部自带拉伸/视差，不叠加收缩动效
                        albumHeaderContent
                    } else {
                        albumHeaderContent
                            .monoPageHeaderCollapse()
                    }
                    songListSection
                        .padding(.bottom, 100)
                }
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .monoScrollOffset($scrollOffset)
            .ignoresSafeArea(edges: usesAsideHero ? .top : [])
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .monoNavigationBackButton()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let size = viewModel.albumInfo?.size, size > 0, !MinimalWhiteStyle.isActive {
                    if NeumorphicStyle.isActive {
                        NeumorphicPill(text: "\(size)", tint: NeumorphicStyle.sage, icon: .musicNoteList, compact: true)
                    } else if SequoiaStyle.isActive {
                        SequoiaPill(text: "\(size)", icon: .musicNoteList, tint: SequoiaStyle.aqua, selected: false, compact: true)
                    } else if CapsuleStyle.isActive {
                        CapsuleDetailChip(text: "\(size)", icon: .musicNoteList, tint: CapsuleStyle.violet)
                    } else {
                        Text(String(format: NSLocalizedString("songs_count_format", comment: ""), size))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.monoTextSecondary)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showArtistDetail) {
            if let artist = viewModel.albumInfo?.artist,
               artist.source == .appleMusic || artist.source == .kugou {
                ArtistDetailView(artist: artist)
            } else if let artistId = selectedArtistId {
                ArtistDetailView(artistId: artistId)

            }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail {
                SongDetailView(song: song)

            }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let albumId = selectedAlbumId {
                AlbumDetailView(albumId: albumId, albumName: nil, albumCoverUrl: nil)

            }
        }
        .onAppear {
            if let initialAlbum {
                viewModel.fetchAlbum(initialAlbum)
            } else {
                viewModel.fetchAlbum(id: albumId)
            }
        }
        .monoSheet(isPresented: $showAlbumDesc, preset: .standard){
            if let album = viewModel.albumInfo {
                AlbumDescSheet(album: album)
            }
        }
    }

    // MARK: - 头部

    @ViewBuilder
    private var albumHeaderContent: some View {
        if MangaStyle.isActive {
            mangaAlbumHeaderContent
        } else if MinimalWhiteStyle.isActive {
            minimalWhiteAlbumHeaderContent
        } else if NeumorphicStyle.isActive {
            neumorphicAlbumHeaderContent
        } else if SignalStyle.isActive {
            signalAlbumHeaderContent
        } else if SequoiaStyle.isActive {
            sequoiaAlbumHeaderContent
        } else if MujiStyle.isActive {
            mujiAlbumHeaderContent
        } else if CapsuleStyle.isActive {
            capsuleAlbumHeaderContent
        } else if BentoStyle.isActive {
            bentoAlbumHeaderContent
        } else {
            AsideDetailHeroHeader(
                coverUrl: viewModel.albumInfo?.coverUrl?.sized(800) ?? albumCoverUrl?.sized(800),
                title: viewModel.albumInfo?.name ?? albumName ?? "",
                subtitle: viewModel.albumInfo?.artistName,
                onSubtitleTap: (viewModel.albumInfo?.artist?.id).map { artistId in
                    {
                        selectedArtistId = artistId
                        showArtistDetail = true
                    }
                },
                metaItems: asideHeroMetaItems,
                descriptionText: viewModel.albumInfo?.description,
                onDescriptionTap: { showAlbumDesc = true },
                scrollOffset: scrollOffset,
                playAllDisabled: viewModel.songs.isEmpty,
                onPlayAll: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }
            ) {
                // 收藏专辑按钮
                SubscribeButton(
                    isSubscribed: viewModel.isSubscribed,
                    action: { viewModel.toggleSubscription(id: albumId) }
                )
                .disabled(viewModel.isTogglingSubscription)
            }
            .padding(.bottom, DeviceLayout.isPad ? 20 : 12)
            .iPadContentWidth(900)
        }
    }

    /// Hero 头部元信息：发行时间 + 发行公司
    private var asideHeroMetaItems: [String] {
        var items: [String] = []
        if let date = viewModel.albumInfo?.publishDateText, !date.isEmpty {
            items.append(date)
        }
        if let company = viewModel.albumInfo?.company, !company.isEmpty {
            items.append(company)
        }
        return items
    }

    private var minimalWhiteAlbumHeaderContent: some View {
        let album = viewModel.albumInfo
        let coverURL = album?.coverUrl?.sized(900) ?? albumCoverUrl?.sized(900)
        let coverSize: CGFloat = DeviceLayout.isPad ? 190 : 146
        let heroHeight: CGFloat = DeviceLayout.isPad ? 414 : 358

        return ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: coverURL) {
                MinimalWhiteStyle.surfaceTint
            }
            .aspectRatio(contentMode: .fill)
            .frame(height: heroHeight)
            .frame(maxWidth: .infinity)
            .blur(radius: 18)
            .opacity(0.18)
            .clipped()
            .overlay {
                LinearGradient(
                    colors: [
                        MinimalWhiteStyle.paper.opacity(0.36),
                        MinimalWhiteStyle.paper.opacity(0.82),
                        MinimalWhiteStyle.paper
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom, spacing: 18) {
                    CachedAsyncImage(url: coverURL) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(MinimalWhiteStyle.controlGlassFill)
                            .overlay(MonoIcon(icon: .album, size: 32, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.55))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: coverSize, height: coverSize)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth)
                    )
                    .shadow(color: MinimalWhiteStyle.ink.opacity(0.11), radius: 22, x: 0, y: 12)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(album?.name ?? albumName ?? "")
                            .font(MinimalWhiteStyle.titleFont(DeviceLayout.isPad ? 34 : 27, weight: .semibold))
                            .foregroundStyle(MinimalWhiteStyle.ink)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        if let artistName = album?.artistName, !artistName.isEmpty {
                            Button {
                                if let artistId = album?.artist?.id {
                                    selectedArtistId = artistId
                                    showArtistDetail = true
                                }
                            } label: {
                                Text(artistName)
                                    .font(MinimalWhiteStyle.labelFont(12, weight: .regular))
                                    .foregroundStyle(MinimalWhiteStyle.inkMuted)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                        }

                        minimalWhiteAlbumMetaLine
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let description = album?.description, !description.isEmpty {
                    Button(action: { showAlbumDesc = true }) {
                        HStack(alignment: .center, spacing: 12) {
                            Text(description)
                                .font(MinimalWhiteStyle.bodyFont(13, weight: .regular))
                                .foregroundStyle(MinimalWhiteStyle.inkSoft)
                                .lineLimit(2)
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            MonoIcon(icon: .chevronRight, size: 12, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.55)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(MinimalWhiteSurfaceBackground(cornerRadius: 15, elevated: false, tint: MinimalWhiteStyle.glassStrongFill))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    Button {
                        if let first = viewModel.songs.first {
                            PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                        }
                    } label: {
                        HStack(spacing: 7) {
                            MonoIcon(icon: .play, size: 13, color: MinimalWhiteStyle.onAccent, lineWidth: 1.75)
                            Text(LocalizedStringKey("play_now"))
                                .font(MinimalWhiteStyle.labelFont(13, weight: .semibold))
                        }
                        .foregroundStyle(MinimalWhiteStyle.onAccent)
                        .padding(.horizontal, 18)
                        .frame(height: 40)
                        .background(MinimalWhiteStyle.ink, in: Capsule(style: .continuous))
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    .opacity(viewModel.songs.isEmpty ? 0.55 : 1)
                    .disabled(viewModel.songs.isEmpty)

                    SubscribeButton(
                        isSubscribed: viewModel.isSubscribed,
                        action: { viewModel.toggleSubscription(id: albumId) }
                    )
                    .disabled(viewModel.isTogglingSubscription)

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.bottom, 22)
            .iPadContentWidth(900)
        }
        .frame(height: heroHeight)
        .padding(.top, DeviceLayout.headerTopPadding)
        .background(MinimalWhiteStyle.paper)
    }

    private var minimalWhiteAlbumMetadataItems: [String] {
        var items: [String] = []
        if let size = viewModel.albumInfo?.size, size > 0 {
            items.append("\(size) \(String(localized: "songs_unit"))")
        }
        if let date = viewModel.albumInfo?.publishDateText, !date.isEmpty {
            items.append(date)
        }
        if let company = viewModel.albumInfo?.company, !company.isEmpty {
            items.append(company)
        }
        return items
    }

    private var minimalWhiteAlbumMetaLine: some View {
        HStack(spacing: 7) {
            ForEach(Array(minimalWhiteAlbumMetadataItems.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Circle()
                        .fill(MinimalWhiteStyle.inkMuted.opacity(0.32))
                        .frame(width: 3, height: 3)
                }

                Text(item)
                    .font(MinimalWhiteStyle.labelFont(11, weight: .regular))
                    .foregroundStyle(MinimalWhiteStyle.inkMuted)
                    .lineLimit(1)
            }
        }
    }

    private var bentoAlbumHeaderContent: some View {
        VStack(spacing: BentoStyle.blockSpacing) {
            BentoBlock(fill: BentoStyle.surface, radius: BentoStyle.blockRadiusLarge, padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        CachedAsyncImage(url: viewModel.albumInfo?.coverUrl?.sized(500) ?? albumCoverUrl?.sized(500)) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(BentoStyle.buckwheat.opacity(0.5))
                                .overlay(MonoIcon(icon: .album, size: 28, color: BentoStyle.inkMuted, lineWidth: 1.8))
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: DeviceLayout.isPad ? 160 : 120, height: DeviceLayout.isPad ? 160 : 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("ALBUM")
                                .font(BentoStyle.labelFont(10, weight: .heavy))
                                .foregroundStyle(BentoStyle.tomato)
                                .tracking(1.4)

                            Text(viewModel.albumInfo?.name ?? albumName ?? "")
                                .font(BentoStyle.displayFont(20, weight: .heavy))
                                .foregroundStyle(BentoStyle.ink)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)

                            if let artistName = viewModel.albumInfo?.artistName, !artistName.isEmpty {
                                Button {
                                    if let artistId = viewModel.albumInfo?.artist?.id {
                                        selectedArtistId = artistId
                                        showArtistDetail = true
                                    }
                                } label: {
                                    Text(artistName)
                                        .font(BentoStyle.labelFont(11, weight: .regular))
                                        .foregroundStyle(BentoStyle.inkSoft)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 8) {
                        if let size = viewModel.albumInfo?.size, size > 0 {
                            bentoAlbumPill(text: "\(size) \(String(localized: "songs_unit"))", tint: BentoStyle.matcha)
                        }
                        if let date = viewModel.albumInfo?.publishDateText, !date.isEmpty {
                            bentoAlbumPill(text: date, tint: BentoStyle.nori)
                        }
                        if let company = viewModel.albumInfo?.company, !company.isEmpty {
                            bentoAlbumPill(text: company, tint: BentoStyle.mustard)
                        }
                    }
                }
            }

            HStack(spacing: BentoStyle.blockSpacing) {
                Button {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                } label: {
                    HStack(spacing: 6) {
                        MonoIcon(icon: .play, size: 14, color: BentoStyle.onAccent, lineWidth: 2)
                        Text(LocalizedStringKey("play_now"))
                            .font(BentoStyle.bodyFont(13, weight: .heavy))
                    }
                    .foregroundStyle(BentoStyle.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(BentoStyle.tomato))
                }
                .buttonStyle(BentoPressStyle())
                .disabled(viewModel.songs.isEmpty)
                .opacity(viewModel.songs.isEmpty ? 0.55 : 1)

                SubscribeButton(
                    isSubscribed: viewModel.isSubscribed,
                    action: { viewModel.toggleSubscription(id: albumId) }
                )
                .disabled(viewModel.isTogglingSubscription)
            }
        }
        .padding(.horizontal, BentoStyle.blockSpacing)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .iPadContentWidth(900)
    }

    private func bentoAlbumPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(BentoStyle.labelFont(11, weight: .heavy))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.14)))
    }

    @ViewBuilder
    private var capsuleAlbumHeaderContent: some View {
        let album = viewModel.albumInfo
        let size = album?.size ?? 0
        let chips = [
            size > 0 ? "\(size) \(String(localized: "songs_unit"))" : nil,
            album?.publishDateText.isEmpty == false ? album?.publishDateText : nil,
            album?.company?.isEmpty == false ? album?.company : nil
        ].compactMap { $0 }

        CapsuleDetailHeader(
            eyebrow: "ALBUM",
            title: album?.name ?? albumName ?? "",
            subtitle: album?.artistName ?? "",
            coverURL: album?.coverUrl?.sized(500) ?? albumCoverUrl?.sized(500),
            fallbackIcon: .album,
            tint: CapsuleStyle.violet,
            chips: chips
        ) {
            HStack(spacing: 10) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }) {
                    CapsuleDetailActionPill(
                        title: String(localized: "play_now"),
                        icon: .play,
                        tint: CapsuleStyle.violet
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.55 : 1)
                .disabled(viewModel.songs.isEmpty)

                SubscribeButton(
                    isSubscribed: viewModel.isSubscribed,
                    action: { viewModel.toggleSubscription(id: albumId) }
                )
                .disabled(viewModel.isTogglingSubscription)

                if let description = album?.description, !description.isEmpty {
                    Button(action: { showAlbumDesc = true }) {
                        CapsuleDetailIconButton(icon: .info, tint: CapsuleStyle.cyan)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
                }
            }
        }
    }

    private var sequoiaAlbumHeaderContent: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 15) {
                CachedAsyncImage(url: viewModel.albumInfo?.coverUrl?.sized(500) ?? albumCoverUrl?.sized(500)) {
                    sequoiaAlbumCoverPlaceholder
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 168 : 126, height: DeviceLayout.isPad ? 168 : 126)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(SequoiaStyle.luminousSeparator.opacity(0.56), lineWidth: 0.7)
                )
                .background(SequoiaSurfaceBackground(cornerRadius: 24, elevated: true, role: .chrome))

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        SequoiaPill(text: "ALBUM", icon: .album, tint: SequoiaStyle.violet, selected: true, compact: true)
                        if let size = viewModel.albumInfo?.size, size > 0 {
                            SequoiaPill(text: "\(size) \(String(localized: "songs_unit"))", tint: SequoiaStyle.aqua, compact: true)
                        }
                    }

                    Text(viewModel.albumInfo?.name ?? albumName ?? "")
                        .font(SequoiaStyle.titleFont(DeviceLayout.isPad ? 28 : 23, weight: .semibold))
                        .foregroundStyle(SequoiaStyle.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let artistName = viewModel.albumInfo?.artistName, !artistName.isEmpty {
                        Button(action: {
                            if let artistId = viewModel.albumInfo?.artist?.id {
                                selectedArtistId = artistId
                                showArtistDetail = true
                            }
                        }) {
                            Text(artistName)
                                .font(SequoiaStyle.labelFont(12, weight: .medium))
                                .foregroundStyle(SequoiaStyle.inkSoft)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 7) {
                        if let date = viewModel.albumInfo?.publishDateText, !date.isEmpty {
                            SequoiaPill(text: date, tint: SequoiaStyle.green, compact: true)
                        }
                        if let company = viewModel.albumInfo?.company, !company.isEmpty {
                            SequoiaPill(text: company, tint: SequoiaStyle.graphite, compact: true)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: DeviceLayout.isPad ? 168 : 126, alignment: .topLeading)
            }

            HStack(spacing: 10) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }) {
                    HStack(spacing: 7) {
                        MonoIcon(icon: .play, size: 13, color: SequoiaStyle.onAccent, lineWidth: 1.7)
                        Text(LocalizedStringKey("play_now"))
                            .font(SequoiaStyle.labelFont(12, weight: .semibold))
                    }
                    .foregroundStyle(SequoiaStyle.onAccent)
                    .padding(.horizontal, 15)
                    .frame(height: 38)
                    .background(SequoiaStyle.accentGradient, in: Capsule())
                    .overlay(Capsule().stroke(SequoiaStyle.luminousSeparator.opacity(0.24), lineWidth: 0.55))
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.55 : 1)
                .disabled(viewModel.songs.isEmpty)

                SubscribeButton(
                    isSubscribed: viewModel.isSubscribed,
                    action: { viewModel.toggleSubscription(id: albumId) }
                )
                .disabled(viewModel.isTogglingSubscription)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: DeviceLayout.isPad ? 264 : 232, alignment: .topLeading)
        .background(SequoiaGlassBand(tint: SequoiaStyle.violet, cornerRadius: 26))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var sequoiaAlbumCoverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(SequoiaStyle.materialList)
            .overlay(MonoIcon(icon: .album, size: 30, color: SequoiaStyle.inkMuted, lineWidth: 1.55))
    }

    private var mangaAlbumHeaderContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                CachedAsyncImage(url: viewModel.albumInfo?.coverUrl?.sized(500) ?? albumCoverUrl?.sized(500)) {
                    MangaStyle.paperCool
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 170 : 124, height: DeviceLayout.isPad ? 170 : 124)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: MangaStyle.cardRadius, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth))
                .background(RoundedRectangle(cornerRadius: MangaStyle.cardRadius, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 3, y: 3))
                .rotationEffect(.degrees(-1.2))

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        MangaSectionMark(kind: .star, tint: MangaStyle.labelYellow, size: 22)
                        MangaLabel(text: "ALBUM", tint: MangaStyle.bubbleBlue, small: true, foreground: MangaStyle.ink)
                    }

                    MangaMisprintTitle(text: viewModel.albumInfo?.name ?? albumName ?? "", size: DeviceLayout.isPad ? 26 : 22)
                        .fixedSize(horizontal: false, vertical: true)

                    if let artistName = viewModel.albumInfo?.artistName, !artistName.isEmpty {
                        Button(action: {
                            if let artistId = viewModel.albumInfo?.artist?.id {
                                selectedArtistId = artistId
                                showArtistDetail = true
                            }
                        }) {
                            Text(artistName)
                                .font(MangaStyle.bodyFont(12, weight: .bold))
                                .foregroundStyle(MangaStyle.inkSub)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 7) {
                        if let date = viewModel.albumInfo?.publishDateText, !date.isEmpty {
                            MangaLabel(text: date, tint: MangaStyle.mint, small: true)
                        }
                        if let size = viewModel.albumInfo?.size, size > 0 {
                            MangaLabel(text: "\(size) \(String(localized: "songs_unit"))", tint: MangaStyle.paperCool, small: true, foreground: MangaStyle.ink)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: DeviceLayout.isPad ? 170 : 124, alignment: .topLeading)
            }

            HStack(spacing: 10) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }) {
                    HStack(spacing: 7) {
                        MonoIcon(icon: .play, size: 13, color: MangaStyle.onStrokeInk, lineWidth: 2)
                        Text(LocalizedStringKey("play_now"))
                            .font(MangaStyle.labelFont(12, weight: .black))
                            .tracking(0.6)
                    }
                    .foregroundStyle(MangaStyle.onStrokeInk)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(MangaStyle.strokeInk))
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(MangaStyle.accentPink)
                            .offset(x: 2.5, y: 2.5)
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.55 : 1)
                .disabled(viewModel.songs.isEmpty)

                SubscribeButton(
                    isSubscribed: viewModel.isSubscribed,
                    action: { viewModel.toggleSubscription(id: albumId) }
                )
                .disabled(viewModel.isTogglingSubscription)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: DeviceLayout.isPad ? 266 : 232, alignment: .topLeading)
        .background(
            // 专辑详情页唯一焦点分格：保留厚墨框错版投影
            MangaCardBackground(cornerRadius: MangaStyle.cardRadius + 4, elevated: true, tint: MangaStyle.bubbleWhite, poster: true)
        )
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var signalAlbumHeaderContent: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 15) {
                CachedAsyncImage(url: viewModel.albumInfo?.coverUrl?.sized(500) ?? albumCoverUrl?.sized(500)) {
                    SignalStyle.controlPressed
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 170 : 128, height: DeviceLayout.isPad ? 170 : 128)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .background(SignalSurfaceBackground(cornerRadius: 26, elevated: true, fill: SignalStyle.control))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(SignalStyle.separator.opacity(0.68), lineWidth: 0.8)
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        SignalPill(text: "ALBUM", tint: SignalStyle.accent, selected: true, compact: true)
                        if let size = viewModel.albumInfo?.size, size > 0 {
                            SignalPill(text: "\(size) \(String(localized: "songs_unit"))", tint: SignalStyle.olive, compact: true)
                        }
                    }

                    Text(viewModel.albumInfo?.name ?? albumName ?? "")
                        .font(SignalStyle.titleFont(DeviceLayout.isPad ? 28 : 23, weight: .bold))
                        .foregroundStyle(SignalStyle.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let artistName = viewModel.albumInfo?.artistName, !artistName.isEmpty {
                        Button(action: {
                            if let artistId = viewModel.albumInfo?.artist?.id {
                                selectedArtistId = artistId
                                showArtistDetail = true
                            }
                        }) {
                            Text(artistName)
                                .font(SignalStyle.labelFont(12, weight: .medium))
                                .foregroundStyle(SignalStyle.inkSoft)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 7) {
                        if let date = viewModel.albumInfo?.publishDateText, !date.isEmpty {
                            SignalPill(text: date, tint: SignalStyle.violet, compact: true)
                        }
                        if let company = viewModel.albumInfo?.company, !company.isEmpty {
                            SignalPill(text: company, tint: SignalStyle.amber, compact: true)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: DeviceLayout.isPad ? 170 : 128, alignment: .topLeading)
            }

            HStack(spacing: 10) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }) {
                    SignalPlayPill(title: String(localized: "play_now"))
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.55 : 1)
                .disabled(viewModel.songs.isEmpty)

                SubscribeButton(
                    isSubscribed: viewModel.isSubscribed,
                    action: { viewModel.toggleSubscription(id: albumId) }
                )
                .disabled(viewModel.isTogglingSubscription)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, minHeight: DeviceLayout.isPad ? 270 : 238, alignment: .topLeading)
        .background(SignalSurfaceBackground(cornerRadius: 30, elevated: true, fill: SignalStyle.paper))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var neumorphicAlbumHeaderContent: some View {
        let coverSize: CGFloat = DeviceLayout.isPad ? 174 : 130

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: viewModel.albumInfo?.coverUrl?.sized(500) ?? albumCoverUrl?.sized(500)) {
                    NeumorphicStyle.surfacePressed
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: coverSize, height: coverSize)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(NeumorphicStyle.separator.opacity(0.32), lineWidth: 0.8)
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        NeumorphicPill(text: "ALBUM", tint: NeumorphicStyle.warm, selected: true, compact: true)
                        if let size = viewModel.albumInfo?.size, size > 0 {
                            NeumorphicPill(text: "\(size) \(String(localized: "songs_unit"))", tint: NeumorphicStyle.sage, compact: true)
                        }
                    }

                    Text(viewModel.albumInfo?.name ?? albumName ?? "")
                        .font(NeumorphicStyle.titleFont(DeviceLayout.isPad ? 28 : 23, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    neumorphicAlbumMetadataCard

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: coverSize, alignment: .topLeading)
            }

            HStack(spacing: 10) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }) {
                    NeumorphicPlayPill(title: String(localized: "play_now"), tint: NeumorphicStyle.accent)
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.55 : 1)
                .disabled(viewModel.songs.isEmpty)

                SubscribeButton(
                    isSubscribed: viewModel.isSubscribed,
                    action: { viewModel.toggleSubscription(id: albumId) }
                )
                .disabled(viewModel.isTogglingSubscription)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: DeviceLayout.isPad ? 270 : 238, alignment: .topLeading)
        .background(NeumorphicSurfaceBackground(cornerRadius: 28, elevated: true))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var neumorphicAlbumMetadataCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let artistName = viewModel.albumInfo?.artistName, !artistName.isEmpty {
                Button(action: {
                    if let artistId = viewModel.albumInfo?.artist?.id {
                        selectedArtistId = artistId
                        showArtistDetail = true
                    }
                }) {
                    HStack(spacing: 6) {
                        MonoIcon(icon: .profile, size: 12, color: NeumorphicStyle.inkSoft, lineWidth: 1.55)
                        Text(artistName)
                            .font(NeumorphicStyle.labelFont(12, weight: .medium))
                            .foregroundStyle(NeumorphicStyle.inkSoft)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 7) {
                if let date = viewModel.albumInfo?.publishDateText, !date.isEmpty {
                    NeumorphicPill(text: date, tint: NeumorphicStyle.accent, compact: true)
                }
                if let company = viewModel.albumInfo?.company, !company.isEmpty {
                    NeumorphicPill(text: company, tint: NeumorphicStyle.sage, compact: true)
                }
            }

            if !hasNeumorphicAlbumMetadata {
                Text(LocalizedStringKey("album_no_desc"))
                    .font(NeumorphicStyle.labelFont(12, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 18,
                elevated: false,
                pressed: true,
                tint: NeumorphicStyle.surfacePressed,
                lightweight: true
            )
        )
    }

    private var hasNeumorphicAlbumMetadata: Bool {
        let hasArtist = viewModel.albumInfo?.artistName.isEmpty == false
        let hasDate = viewModel.albumInfo?.publishDateText.isEmpty == false
        let hasCompany = viewModel.albumInfo?.company?.isEmpty == false
        return hasArtist || hasDate || hasCompany
    }

    /// Muji：唱片特辑页 —— 眉题行 + 跨页封面 + 衬线标题 + 署名行
    private var mujiAlbumHeaderContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 眉题行
            HStack(alignment: .center, spacing: 8) {
                MujiDotMark()

                Text("ALBUM")
                    .font(MujiStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(MujiStyle.clay)
                    .tracking(2.2)
                    .fixedSize()

                Spacer(minLength: 8)

                if let size = viewModel.albumInfo?.size, size > 0 {
                    Text("\(size) \(String(localized: "songs_unit"))")
                        .font(MujiStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(MujiStyle.inkMuted)
                        .tracking(1.1)
                        .fixedSize()
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            // 跨页封面
            CachedAsyncImage(url: viewModel.albumInfo?.coverUrl?.sized(800) ?? albumCoverUrl?.sized(800)) {
                Rectangle().fill(MujiStyle.wash(MujiStyle.clay))
            }
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: DeviceLayout.isPad ? 300 : 216)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: MujiStyle.ink.opacity(0.08), radius: 12, x: 0, y: 6)
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 14)

            // 标题与署名
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.albumInfo?.name ?? albumName ?? "")
                    .font(MujiStyle.titleFont(DeviceLayout.isPad ? 30 : 26, weight: .regular))
                    .foregroundStyle(MujiStyle.ink)
                    .lineSpacing(4)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    if let artistName = viewModel.albumInfo?.artistName, !artistName.isEmpty {
                        Button(action: {
                            if let artistId = viewModel.albumInfo?.artist?.id {
                                selectedArtistId = artistId
                                showArtistDetail = true
                            }
                        }) {
                            Text(artistName)
                                .font(MujiStyle.labelFont(11, weight: .medium))
                                .foregroundStyle(MujiStyle.inkSoft)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }

                    if let date = viewModel.albumInfo?.publishDateText, !date.isEmpty {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(MujiStyle.clay.opacity(0.85))
                                .frame(width: 3.5, height: 3.5)

                            Text(date)
                                .font(MujiStyle.labelFont(10.5, weight: .semibold))
                                .foregroundStyle(MujiStyle.inkMuted)
                                .tracking(0.8)
                                .monospacedDigit()
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)

            // 动作行
            HStack(spacing: 10) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }) {
                    MujiActionPill(
                        title: String(localized: "play_now"),
                        icon: .play,
                        selected: true,
                        tint: MujiStyle.clay
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.55 : 1)
                .disabled(viewModel.songs.isEmpty)

                SubscribeButton(
                    isSubscribed: viewModel.isSubscribed,
                    action: { viewModel.toggleSubscription(id: albumId) }
                )
                .disabled(viewModel.isTogglingSubscription)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)

            MujiListDivider()
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 18)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - 歌曲列表

    private var songListSection: some View {
        Group {
            if MinimalWhiteStyle.isActive {
                minimalWhiteAlbumSongListSection
            } else if CapsuleStyle.isActive {
                capsuleAlbumSongListSection
            } else {
                defaultAlbumSongListSection
            }
        }
        .monoSheet(isPresented: $showBatchAddToPlaylist, preset: .standard) {
            BatchAddToPlaylistSheet(songs: albumFilteredSongs.filter { selectedSongIds.contains($0.id) })
        }
    }

    private var minimalWhiteAlbumSongListSection: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            MinimalWhiteSectionTitle(title: String(localized: "歌曲")) {
                if !albumFilteredSongs.isEmpty {
                    Text("\(albumFilteredSongs.count)")
                        .font(MinimalWhiteStyle.labelFont(12, weight: .medium))
                        .foregroundStyle(MinimalWhiteStyle.inkMuted)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            if viewModel.isLoading {
                MonoLoadingView(text: "")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.cardRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    )
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            } else if viewModel.songs.isEmpty {
                albumEmptyState
            } else {
                VStack(spacing: 0) {
                    albumSearchBar
                        .padding(.bottom, 6)

                    Rectangle()
                        .fill(MinimalWhiteStyle.hairline)
                        .frame(height: MinimalWhiteStyle.strokeWidth)

                    albumSongRows

                    Rectangle()
                        .fill(MinimalWhiteStyle.hairline)
                        .frame(height: MinimalWhiteStyle.strokeWidth)

                    NoMoreDataView()
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                FloatingBarBottomSpacer()
            }
        }
        .padding(.top, 0)
        .background(MinimalWhiteStyle.paper)
    }

    private var capsuleAlbumSongListSection: some View {
        LazyVStack(spacing: 14) {
            if viewModel.isLoading {
                CapsuleDetailSection(title: "TRACKS", icon: .album, tint: CapsuleStyle.violet) {
                    MonoLoadingView(text: "LOADING TRACKS")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                }
            } else if viewModel.songs.isEmpty {
                CapsuleDetailSection(title: "TRACKS", icon: .album, tint: CapsuleStyle.violet) {
                    CapsuleDetailEmptyState(title: "album_no_songs", icon: .musicNoteList, tint: CapsuleStyle.violet)
                }
            } else {
                albumDescriptionCard

                CapsuleDetailSection(
                    title: "TRACKS",
                    subtitle: String(format: NSLocalizedString("songs_count_format", comment: ""), albumFilteredSongs.count),
                    icon: .musicNoteList,
                    tint: CapsuleStyle.violet
                ) {
                    albumSearchBar
                        .padding(.horizontal, -DeviceLayout.viewHorizontalPadding)

                    albumSongRows

                    NoMoreDataView()
                }

                FloatingBarBottomSpacer()
            }
        }
    }

    private var defaultAlbumSongListSection: some View {
        LazyVStack(spacing: 0) {
            if viewModel.isLoading {
                MonoLoadingView(text: "LOADING TRACKS")
            } else if viewModel.songs.isEmpty {
                albumEmptyState
            } else {
                // Aside 的 Hero 头部已经承载专辑简介，避免歌曲列表前重复显示一份。
                if !usesAsideHero {
                    albumDescriptionCard
                }
                albumSearchBar
                albumSongRows
                NoMoreDataView()
                FloatingBarBottomSpacer()
            }
        }
    }

    private var albumEmptyState: some View {
        VStack(spacing: 14) {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteIconBadge(icon: .musicNoteList, size: 54)
            } else if NeumorphicStyle.isActive {
                NeumorphicIconBadge(icon: .musicNoteList, tint: NeumorphicStyle.warm, size: 54)
            } else if SequoiaStyle.isActive {
                SequoiaIconBadge(icon: .musicNoteList, tint: SequoiaStyle.violet, size: 54)
            } else {
                MonoIcon(icon: .musicNoteList, size: 40, color: Theme.secondaryText.opacity(0.3))
            }
            Text(LocalizedStringKey("album_no_songs"))
                .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.bodyFont(15, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .medium) : .rounded(size: 15))))
                .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : Theme.secondaryText)))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, (MinimalWhiteStyle.isActive || NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 34 : 0)
        .background {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteSurfaceBackground(
                    cornerRadius: MinimalWhiteStyle.cardRadius,
                    elevated: false,
                    tint: MinimalWhiteStyle.glassFill
                )
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 24, elevated: false, pressed: true, lightweight: true)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 24, elevated: true, role: .chrome)
            }
        }
        .padding(.horizontal, (MinimalWhiteStyle.isActive || NeumorphicStyle.isActive || SequoiaStyle.isActive) ? DeviceLayout.viewHorizontalPadding : 0)
        .padding(.top, 40)
    }

    private var albumDescriptionCard: some View {
        Group {
            if let albumDescription = viewModel.albumInfo?.description, !albumDescription.isEmpty {
                Button(action: { showAlbumDesc = true }) {
                    VStack(alignment: .leading, spacing: CapsuleStyle.isActive ? 12 : 10) {
                        HStack {
                            if CapsuleStyle.isActive {
                                CapsuleDetailChip(
                                    text: String(localized: "album_desc"),
                                    icon: .info,
                                    tint: CapsuleStyle.cyan,
                                    selected: true
                                )
                            } else {
                                Text(LocalizedStringKey("album_desc"))
                                    .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.titleFont(15, weight: .semibold) : (MangaStyle.isActive ? MangaStyle.titleFont(16, weight: .black) : (MujiStyle.isActive ? MujiStyle.titleFont(16, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(15, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.titleFont(15, weight: .semibold) : .rounded(size: 15, weight: .semibold))))))
                                    .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.ink : (MangaStyle.isActive ? MangaStyle.ink : (MujiStyle.isActive ? MujiStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : Theme.text)))))
                            }
                            Spacer()
                            MonoIcon(icon: .chevronRight, size: 12, color: albumDescriptionChevronColor)
                        }

                        Text(albumDescription)
                            .font(albumDescriptionFont)
                            .foregroundColor(albumDescriptionTextColor)
                            .lineLimit(3)
                            .lineSpacing(4)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(albumDescriptionBackground)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, CapsuleStyle.isActive ? 0 : DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, CapsuleStyle.isActive ? 0 : 12)
            }
        }
    }

    private var albumSearchBar: some View {
        PlaylistSearchBar(
            searchText: $albumSearchText,
            isSearching: $isAlbumSearching,
            isSelectMode: $isSelectMode,
            selectedIds: $selectedSongIds,
            songs: albumFilteredSongs,
            onBatchQueue: {
                let selected = albumFilteredSongs.filter { selectedSongIds.contains($0.id) }
                SongBatchActionHelper.addToQueue(selected) {
                    isSelectMode = false
                    selectedSongIds.removeAll()
                }
            },
            onBatchDownload: { albumBatchDownload() },
            onBatchCollect: { showBatchAddToPlaylist = true }
        )
    }

    private var albumSongRows: some View {
        ForEach(Array(albumFilteredSongs.enumerated()), id: \.element.id) { index, song in
            SongListRow(
                song: song,
                index: index,
                isSelecting: isSelectMode,
                isSelected: selectedSongIds.contains(song.id),
                onArtistTap: initialAlbum?.source == .appleMusic || initialAlbum?.source == .kugou ? nil : { artistId in
                    selectedArtistId = artistId
                    showArtistDetail = true
                },
                onDetailTap: { detailSong in
                    selectedSongForDetail = detailSong
                    showSongDetail = true
                },
                onAlbumTap: initialAlbum?.source == .appleMusic || initialAlbum?.source == .kugou ? nil : { albumId in
                    selectedAlbumId = albumId
                    showAlbumDetail = true
                },
                onTap: {
                    if isSelectMode {
                        if selectedSongIds.contains(song.id) {
                            selectedSongIds.remove(song.id)
                        } else {
                            selectedSongIds.insert(song.id)
                        }
                    } else {
                        PlayerManager.shared.play(song: song, in: albumFilteredSongs)
                    }
                }
            )
        }
    }

    private var albumDescriptionFont: Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.bodyFont(13, weight: .regular) }
        if CapsuleStyle.isActive { return CapsuleStyle.bodyFont(13, weight: .semibold) }
        if MangaStyle.isActive { return MangaStyle.bodyFont(13, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.bodyFont(13, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .regular) }
        return .rounded(size: 13, weight: .regular)
    }

    private var albumDescriptionTextColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return Theme.secondaryText
    }

    private var albumDescriptionChevronColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if CapsuleStyle.isActive { return CapsuleStyle.cyan }
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        return Theme.secondaryText
    }

    private var albumDescriptionBackground: some View {
        Group {
            if CapsuleStyle.isActive {
                CapsuleSurfaceBackground(cornerRadius: 26, elevated: true, tint: CapsuleStyle.surface.opacity(0.9))
            } else if MinimalWhiteStyle.isActive {
                MinimalWhiteSurfaceBackground(
                    cornerRadius: MinimalWhiteStyle.cardRadius,
                    elevated: false,
                    tint: MinimalWhiteStyle.glassFill
                )
            } else if MangaStyle.isActive {
                // 去卡片化：简介作引文，左侧粗墨竖线
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(MangaStyle.strokeInk.opacity(0.85))
                        .frame(width: 3)
                    Spacer()
                }
                .padding(.vertical, 2)
            } else if MujiStyle.isActive {
                // Muji：简介作引文，左侧陶土竖线
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(MujiStyle.clay.opacity(0.8))
                        .frame(width: 2)
                    Spacer()
                }
                .padding(.vertical, 4)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 22, elevated: false)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 20, elevated: true, role: .chrome)
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.monoGlassTint)
                    .monoGlass(cornerRadius: 20)
            }
        }
    }

    private var albumFilteredSongs: [Song] { viewModel.songs.filtered(by: albumSearchText) }

    private func albumBatchDownload() {
        let selected = albumFilteredSongs.filter { selectedSongIds.contains($0.id) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
            }
        }
        AlertManager.shared.show(title: String(localized: "download_batch_added_title"), message: L10n.format("download_batch_queue_added_format", selected.count), primaryButtonTitle: String(localized: "common_confirm"), primaryAction: {})
        withAnimation { isSelectMode = false; selectedSongIds.removeAll() }
    }
}


// MARK: - 专辑简介 Sheet

struct AlbumDescSheet: View {
    let album: AlbumInfo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monoSheetDismiss) private var monoSheetDismiss

    var body: some View {
        VStack(spacing: 0) {
            // 头部：专辑封面 + 名字
            HStack(spacing: 14) {
                CachedAsyncImage(url: album.coverUrl?.sized(200)) {
                    RoundedRectangle(cornerRadius: NeumorphicStyle.isActive ? 14 : (SequoiaStyle.isActive ? 14 : 10))
                        .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monoGlassTint))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: NeumorphicStyle.isActive ? 14 : (SequoiaStyle.isActive ? 14 : 10), style: .continuous))
                .overlay {
                    if NeumorphicStyle.isActive {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.7)
                    } else if SequoiaStyle.isActive {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(album.name)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(20, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.titleFont(20, weight: .semibold) : .rounded(size: 20, weight: .bold)))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monoTextPrimary))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(album.artistName)
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .rounded(size: 12)))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monoTextSecondary))

                        if !album.publishDateText.isEmpty {
                            Text("·")
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted.opacity(0.6) : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted.opacity(0.6) : .monoTextSecondary.opacity(0.5)))
                            Text(album.publishDateText)
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .rounded(size: 12)))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monoTextSecondary))
                        }
                    }
                }

                Spacer()

                Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss) }) {
                    MonoIcon(icon: .close, size: 20, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monoTextSecondary))
                        .frame(width: 32, height: 32)
                        .background {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true)
                            } else if SequoiaStyle.isActive {
                                SequoiaSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, role: .list)
                            } else {
                                Circle().fill(Color.monoSeparator)
                            }
                        }
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Rectangle()
                .fill(NeumorphicStyle.isActive ? NeumorphicStyle.separator.opacity(0.45) : (SequoiaStyle.isActive ? SequoiaStyle.separator : Color.monoSeparator))
                .frame(height: 0.5)

            // 内容
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let desc = album.description, !desc.isEmpty {
                        Text(desc)
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .regular) : (SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .regular) : .rounded(size: 15, weight: .regular)))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monoTextPrimary))
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(cornerRadius: 22, elevated: false)
                            } else if SequoiaStyle.isActive {
                                SequoiaSurfaceBackground(cornerRadius: 22, elevated: true, role: .chrome)
                            } else {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Color.monoGlassTint)
                                        .monoGlass(cornerRadius: 20)
                                }
                            }
                    } else {
                        VStack(spacing: 14) {
                            if NeumorphicStyle.isActive {
                                NeumorphicIconBadge(icon: .info, tint: NeumorphicStyle.sage, size: 52)
                            } else if SequoiaStyle.isActive {
                                SequoiaIconBadge(icon: .info, tint: SequoiaStyle.aqua, size: 52)
                            } else {
                                MonoIcon(icon: .info, size: 36, color: .monoTextSecondary.opacity(0.3))
                            }
                            Text(LocalizedStringKey("album_no_desc"))
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .medium) : .rounded(size: 15)))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monoTextSecondary))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .background {
            MonoSheetAwareBackground {
                if NeumorphicStyle.isActive {
                    ThemeRenderBackdrop(theme: .neumorphic)
                } else if SequoiaStyle.isActive {
                    SequoiaRootBackdrop()
                } else {
                    ThemedPageBackground()
                }
            }
        }
    }
}
