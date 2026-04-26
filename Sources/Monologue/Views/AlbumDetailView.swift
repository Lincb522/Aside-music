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
        ZStack {
            MonologueSheetAwareBackground {
                if MangaStyle.isActive {
                    MangaRootBackdrop()
                } else if MujiStyle.isActive {
                    MujiRootBackdrop()
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
        }
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let size = viewModel.albumInfo?.size, size > 0 {
                    Text(String(format: NSLocalizedString("songs_count_format", comment: ""), size))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
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
        } else if MujiStyle.isActive {
            mujiAlbumHeaderContent
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .background(MangaCardBackground(cornerRadius: 22, elevated: true, tint: MangaStyle.bubbleWhite))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 12)
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
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    // MARK: - 歌曲列表

    private var songListSection: some View {
        LazyVStack(spacing: 0) {
            if viewModel.isLoading {
                MonologueLoadingView(text: "LOADING TRACKS")
            } else if viewModel.songs.isEmpty {
                VStack(spacing: 14) {
                    MonologueIcon(icon: .musicNoteList, size: 40, color: Theme.secondaryText.opacity(0.3))
                    Text(LocalizedStringKey("album_no_songs"))
                        .font(.rounded(size: 15))
                        .foregroundColor(Theme.secondaryText)
                }
                .padding(.top, 40)
            } else {
                // 专辑简介（如果有）
                if let desc = viewModel.albumInfo?.description, !desc.isEmpty {
                    Button(action: { showAlbumDesc = true }) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(LocalizedStringKey("album_desc"))
                                    .font(MangaStyle.isActive ? MangaStyle.titleFont(16, weight: .black) : (MujiStyle.isActive ? MujiStyle.titleFont(16, weight: .regular) : .rounded(size: 15, weight: .semibold)))
                                    .foregroundColor(MangaStyle.isActive ? MangaStyle.ink : (MujiStyle.isActive ? MujiStyle.ink : Theme.text))
                                Spacer()
                                MonologueIcon(icon: .chevronRight, size: 12, color: MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkSoft : Theme.secondaryText))
                            }

                            Text(desc)
                                .font(MangaStyle.isActive ? MangaStyle.bodyFont(13, weight: .bold) : (MujiStyle.isActive ? MujiStyle.bodyFont(13, weight: .regular) : .rounded(size: 13, weight: .regular)))
                                .foregroundColor(MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkSoft : Theme.secondaryText))
                                .lineLimit(3)
                                .lineSpacing(4)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background {
                            if MangaStyle.isActive {
                                MangaCardBackground(cornerRadius: 18, elevated: true, tint: MangaStyle.bubbleWhite)
                            } else if MujiStyle.isActive {
                                MujiPaperCardBackground(cornerRadius: 12)
                            } else {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.monologueGlassTint)
                                    .monologueGlass(cornerRadius: 20)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.vertical, 12)
                }

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

                NoMoreDataView()
                FloatingBarBottomSpacer()
            }
        }
        .monologueSheet(isPresented: $showBatchAddToPlaylist, preset: .standard){
            BatchAddToPlaylistSheet(songs: albumFilteredSongs.filter { selectedSongIds.contains($0.id) })
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
                    RoundedRectangle(cornerRadius: 10).fill(Color.monologueGlassTint)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 3) {
                    Text(album.name)
                        .font(.rounded(size: 20, weight: .bold))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(album.artistName)
                            .font(.rounded(size: 12))
                            .foregroundColor(.monologueTextSecondary)

                        if !album.publishDateText.isEmpty {
                            Text("·")
                                .foregroundColor(.monologueTextSecondary.opacity(0.5))
                            Text(album.publishDateText)
                                .font(.rounded(size: 12))
                                .foregroundColor(.monologueTextSecondary)
                        }
                    }
                }

                Spacer()

                Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                    MonologueIcon(icon: .close, size: 20, color: .monologueTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.monologueSeparator)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color.monologueSeparator)
                .frame(height: 0.5)

            // 内容
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let desc = album.description, !desc.isEmpty {
                        Text(desc)
                            .font(.rounded(size: 15, weight: .regular))
                            .foregroundColor(.monologueTextPrimary)
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .monologueGlass(cornerRadius: 20)
                    } else {
                        VStack(spacing: 14) {
                            MonologueIcon(icon: .info, size: 36, color: .monologueTextSecondary.opacity(0.3))
                            Text(LocalizedStringKey("album_no_desc"))
                                .font(.rounded(size: 15))
                                .foregroundColor(.monologueTextSecondary)
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
        }
        .background {
            MonologueSheetAwareBackground {
                ThemedPageBackground()
            }
        }
    }
}
