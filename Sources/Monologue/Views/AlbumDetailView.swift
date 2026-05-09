// AlbumDetailView.swift
// 专辑详情页

import SwiftUI

// MARK: - View

struct AlbumDetailView: View {
    let albumId: Int
    let albumName: String?
    let albumCoverUrl: URL?

    @State private var viewModel = AlbumDetailViewModel()
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

    private struct Theme {
        static let text = Color.monologueTextPrimary
        static let secondaryText = Color.monologueTextSecondary
        static let accent = Color.monologueIconBackground
        static let milk = Color.monologueMilk
    }

    private var effectiveCoverUrl: URL? {
        viewModel.albumInfo?.coverUrl?.sized(200) ?? albumCoverUrl?.sized(200)
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            MonologueSheetAwareBackground {
                if MangaStyle.isActive {
                    MangaRootBackdrop()
                } else if MujiStyle.isActive {
                    MujiRootBackdrop()
                } else if NeumorphicStyle.isActive {
                    ThemeRenderBackdrop(theme: .neumorphic)
                } else if SignalStyle.isActive {
                    ThemeRenderBackdrop(theme: .signal)
                } else if SequoiaStyle.isActive {
                    SequoiaRootBackdrop()
                } else if BentoStyle.isActive {
                    BentoRootBackdrop()
                } else if CapsuleStyle.isActive {
                    CapsuleRootBackdrop()
                } else if SettingsManager.shared.coverBgPlaylist {
            PlaylistColorBackground(coverUrl: effectiveCoverUrl)
        } else {
                    ThemedPageBackground()
                }
            }

            ScrollView {
                VStack(spacing: 0) {
                    albumHeaderContent
                    songListSection
                        .padding(.bottom, 100)
                }
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let size = viewModel.albumInfo?.size, size > 0 {
                    if NeumorphicStyle.isActive {
                        NeumorphicPill(text: "\(size)", tint: NeumorphicStyle.sage, icon: .musicNoteList, compact: true)
                    } else if SequoiaStyle.isActive {
                        SequoiaPill(text: "\(size)", icon: .musicNoteList, tint: SequoiaStyle.aqua, selected: false, compact: true)
                    } else if CapsuleStyle.isActive {
                        CapsuleDetailChip(text: "\(size)", icon: .musicNoteList, tint: CapsuleStyle.violet)
                    } else {
                        Text(String(format: NSLocalizedString("songs_count_format", comment: ""), size))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showArtistDetail) {
            if let artistId = selectedArtistId {
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
            viewModel.fetchAlbum(id: albumId)
        }
        .monologueSheet(isPresented: $showAlbumDesc, preset: .standard){
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
            VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                // 封面：优先用详情接口返回的，回退到传入的
                CachedAsyncImage(url: viewModel.albumInfo?.coverUrl?.sized(400) ?? albumCoverUrl?.sized(400)) {
                    Color.gray.opacity(0.1)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.detailCoverSize, height: DeviceLayout.detailCoverSize)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.albumInfo?.name ?? albumName ?? "")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text)
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
                                .font(.system(size: 13))
                                .foregroundColor(Theme.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    // 发行信息
                    HStack(spacing: 8) {
                        if let date = viewModel.albumInfo?.publishDateText, !date.isEmpty {
                            Text(date)
                                .font(.rounded(size: 11))
                                .foregroundColor(Theme.secondaryText.opacity(0.7))
                        }
                        if let company = viewModel.albumInfo?.company, !company.isEmpty {
                            Text(company)
                                .font(.rounded(size: 11))
                                .foregroundColor(Theme.secondaryText.opacity(0.7))
                                .lineLimit(1)
                        }
                    }

                    Spacer().frame(height: 4)

                    HStack(spacing: 8) {
                        Button(action: {
                            if let first = viewModel.songs.first {
                                PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                            }
                        }) {
                            HStack(spacing: 6) {
                                MonologueIcon(icon: .play, size: 12, color: .monologueIconForeground)
                                Text(LocalizedStringKey("play_now"))
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.monologueIconForeground)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Theme.accent)
                            .cornerRadius(20)
                            .shadow(color: Theme.accent.opacity(0.2), radius: 5, x: 0, y: 2)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

                        // 收藏专辑按钮
                        SubscribeButton(
                            isSubscribed: viewModel.isSubscribed,
                            action: { viewModel.toggleSubscription(id: albumId) }
                        )
                        .disabled(viewModel.isTogglingSubscription)
                    }
                }
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 24)
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
                                .overlay(MonologueIcon(icon: .album, size: 28, color: BentoStyle.inkMuted, lineWidth: 1.8))
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
                        MonologueIcon(icon: .play, size: 14, color: BentoStyle.onAccent, lineWidth: 2)
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
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
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
                        MonologueIcon(icon: .play, size: 13, color: SequoiaStyle.onAccent, lineWidth: 1.7)
                        Text(LocalizedStringKey("play_now"))
                            .font(SequoiaStyle.labelFont(12, weight: .semibold))
                    }
                    .foregroundStyle(SequoiaStyle.onAccent)
                    .padding(.horizontal, 15)
                    .frame(height: 38)
                    .background(SequoiaStyle.accentGradient, in: Capsule())
                    .overlay(Capsule().stroke(SequoiaStyle.luminousSeparator.opacity(0.24), lineWidth: 0.55))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
            .overlay(MonologueIcon(icon: .album, size: 30, color: SequoiaStyle.inkMuted, lineWidth: 1.55))
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
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth))
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 3, y: 3))
                .rotationEffect(.degrees(-1.2))

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        MangaSectionMark(kind: .star, tint: MangaStyle.labelYellow, size: 22)
                        MangaLabel(text: "ALBUM", tint: MangaStyle.bubbleBlue, small: true, foreground: MangaStyle.ink)
                    }

                    Text(viewModel.albumInfo?.name ?? albumName ?? "")
                        .font(MangaStyle.titleFont(DeviceLayout.isPad ? 26 : 22, weight: .black))
                        .foregroundStyle(MangaStyle.ink)
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
                        MonologueIcon(icon: .play, size: 13, color: MangaStyle.strokeInk, lineWidth: 2)
                        Text(LocalizedStringKey("play_now"))
                            .font(MangaStyle.labelFont(12, weight: .black))
                    }
                    .foregroundStyle(MangaStyle.strokeInk)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(MangaStyle.labelYellow))
                    .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
                    .background(Capsule().fill(MangaStyle.strokeInk).offset(x: 2, y: 2))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
        .background(MangaCardBackground(cornerRadius: 22, elevated: true, tint: MangaStyle.bubbleWhite))
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
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
                        MonologueIcon(icon: .profile, size: 12, color: NeumorphicStyle.inkSoft, lineWidth: 1.55)
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

    private var mujiAlbumHeaderContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    MujiPill(text: "ALBUM", tint: MujiStyle.indigo)
                    if let date = viewModel.albumInfo?.publishDateText, !date.isEmpty {
                        MujiPill(text: date, tint: MujiStyle.tea)
                    }
                    if let size = viewModel.albumInfo?.size, size > 0 {
                        MujiPill(text: "\(size) \(String(localized: "songs_unit"))", tint: MujiStyle.clay)
                    }
                }

                Text(viewModel.albumInfo?.name ?? albumName ?? "")
                    .font(MujiStyle.titleFont(DeviceLayout.isPad ? 32 : 28, weight: .regular))
                    .foregroundStyle(MujiStyle.ink)
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
                            .font(MujiStyle.labelFont(12, weight: .regular))
                            .foregroundStyle(MujiStyle.inkSoft)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .frame(maxWidth: .infinity, minHeight: DeviceLayout.isPad ? 132 : 116, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 14) {
                CachedAsyncImage(url: viewModel.albumInfo?.coverUrl?.sized(500) ?? albumCoverUrl?.sized(500)) {
                    MujiStyle.surfaceRaised
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 230 : 190, height: DeviceLayout.isPad ? 230 : 190)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(MujiStyle.hairline.opacity(0.62), lineWidth: 0.65)
                )
                .shadow(color: Color.black.opacity(0.055), radius: 10, x: 0, y: 5)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)

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
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.55 : 1)
                .disabled(viewModel.songs.isEmpty)

                SubscribeButton(
                    isSubscribed: viewModel.isSubscribed,
                    action: { viewModel.toggleSubscription(id: albumId) }
                )
                .disabled(viewModel.isTogglingSubscription)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            MujiListDivider()
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    // MARK: - 歌曲列表

    private var songListSection: some View {
        Group {
            if CapsuleStyle.isActive {
                capsuleAlbumSongListSection
            } else {
                defaultAlbumSongListSection
            }
        }
        .monologueSheet(isPresented: $showBatchAddToPlaylist, preset: .standard) {
            BatchAddToPlaylistSheet(songs: albumFilteredSongs.filter { selectedSongIds.contains($0.id) })
        }
    }

    private var capsuleAlbumSongListSection: some View {
        LazyVStack(spacing: 14) {
            if viewModel.isLoading {
                CapsuleDetailSection(title: "TRACKS", icon: .album, tint: CapsuleStyle.violet) {
                    MonologueLoadingView(text: "LOADING TRACKS")
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
                MonologueLoadingView(text: "LOADING TRACKS")
            } else if viewModel.songs.isEmpty {
                albumEmptyState
            } else {
                albumDescriptionCard
                albumSearchBar
                albumSongRows
                NoMoreDataView()
                FloatingBarBottomSpacer()
            }
        }
    }

    private var albumEmptyState: some View {
        VStack(spacing: 14) {
            if NeumorphicStyle.isActive {
                NeumorphicIconBadge(icon: .musicNoteList, tint: NeumorphicStyle.warm, size: 54)
            } else if SequoiaStyle.isActive {
                SequoiaIconBadge(icon: .musicNoteList, tint: SequoiaStyle.violet, size: 54)
            } else {
                MonologueIcon(icon: .musicNoteList, size: 40, color: Theme.secondaryText.opacity(0.3))
            }
            Text(LocalizedStringKey("album_no_songs"))
                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .medium) : .rounded(size: 15)))
                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : Theme.secondaryText))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, (NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 34 : 0)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 24, elevated: false, pressed: true, lightweight: true)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 24, elevated: true, role: .chrome)
            }
        }
        .padding(.horizontal, (NeumorphicStyle.isActive || SequoiaStyle.isActive) ? DeviceLayout.viewHorizontalPadding : 0)
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
                                    .font(MangaStyle.isActive ? MangaStyle.titleFont(16, weight: .black) : (MujiStyle.isActive ? MujiStyle.titleFont(16, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(15, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.titleFont(15, weight: .semibold) : .rounded(size: 15, weight: .semibold)))))
                                    .foregroundColor(MangaStyle.isActive ? MangaStyle.ink : (MujiStyle.isActive ? MujiStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : Theme.text))))
                            }
                            Spacer()
                            MonologueIcon(icon: .chevronRight, size: 12, color: albumDescriptionChevronColor)
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
        if CapsuleStyle.isActive { return CapsuleStyle.bodyFont(13, weight: .semibold) }
        if MangaStyle.isActive { return MangaStyle.bodyFont(13, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.bodyFont(13, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .regular) }
        return .rounded(size: 13, weight: .regular)
    }

    private var albumDescriptionTextColor: Color {
        if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return Theme.secondaryText
    }

    private var albumDescriptionChevronColor: Color {
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
            } else if MangaStyle.isActive {
                MangaCardBackground(cornerRadius: 18, elevated: true, tint: MangaStyle.bubbleWhite)
            } else if MujiStyle.isActive {
                MujiPaperCardBackground(cornerRadius: 12)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 22, elevated: false)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 20, elevated: true, role: .chrome)
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.monologueGlassTint)
                    .monologueGlass(cornerRadius: 20)
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
        AlertManager.shared.show(title: String(localized: "已加入下载"), message: String(localized: "已将 \(selected.count) 首歌曲加入下载队列"), primaryButtonTitle: String(localized: "确定"), primaryAction: {})
        withAnimation { isSelectMode = false; selectedSongIds.removeAll() }
    }
}


// MARK: - 专辑简介 Sheet

struct AlbumDescSheet: View {
    let album: AlbumInfo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss

    var body: some View {
        VStack(spacing: 0) {
            // 头部：专辑封面 + 名字
            HStack(spacing: 14) {
                CachedAsyncImage(url: album.coverUrl?.sized(200)) {
                    RoundedRectangle(cornerRadius: NeumorphicStyle.isActive ? 14 : (SequoiaStyle.isActive ? 14 : 10))
                        .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monologueGlassTint))
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
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(album.artistName)
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .rounded(size: 12)))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))

                        if !album.publishDateText.isEmpty {
                            Text("·")
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted.opacity(0.6) : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted.opacity(0.6) : .monologueTextSecondary.opacity(0.5)))
                            Text(album.publishDateText)
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .rounded(size: 12)))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))
                        }
                    }
                }

                Spacer()

                Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                    MonologueIcon(icon: .close, size: 20, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))
                        .frame(width: 32, height: 32)
                        .background {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true)
                            } else if SequoiaStyle.isActive {
                                SequoiaSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, role: .list)
                            } else {
                                Circle().fill(Color.monologueSeparator)
                            }
                        }
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Rectangle()
                .fill(NeumorphicStyle.isActive ? NeumorphicStyle.separator.opacity(0.45) : (SequoiaStyle.isActive ? SequoiaStyle.separator : Color.monologueSeparator))
                .frame(height: 0.5)

            // 内容
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let desc = album.description, !desc.isEmpty {
                        Text(desc)
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .regular) : (SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .regular) : .rounded(size: 15, weight: .regular)))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary))
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
                                        .fill(Color.monologueGlassTint)
                                        .monologueGlass(cornerRadius: 20)
                                }
                            }
                    } else {
                        VStack(spacing: 14) {
                            if NeumorphicStyle.isActive {
                                NeumorphicIconBadge(icon: .info, tint: NeumorphicStyle.sage, size: 52)
                            } else if SequoiaStyle.isActive {
                                SequoiaIconBadge(icon: .info, tint: SequoiaStyle.aqua, size: 52)
                            } else {
                                MonologueIcon(icon: .info, size: 36, color: .monologueTextSecondary.opacity(0.3))
                            }
                            Text(LocalizedStringKey("album_no_desc"))
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .medium) : .rounded(size: 15)))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))
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
            MonologueSheetAwareBackground {
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
