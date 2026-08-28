import SwiftUI
import Combine
import QQMusicKit

// MARK: - QQ 歌手详情页（Hero 大图 + Tab）

struct QQArtistDetailView: View {
    let mid: String
    let name: String
    let coverUrl: String?
    
    @StateObject private var viewModel: QQArtistDetailViewModel
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedTab = 0
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedQQMV: QQMVVidItem?
    @State private var selectedAlbumMid: String?
    @State private var selectedAlbumName: String?
    @State private var selectedAlbumCover: String?
    @State private var selectedAlbumArtist: String?
    @State private var showAlbumDetail = false
    @State private var showFullDescription = false
    @State private var scrollOffset: CGFloat = 0
    @State private var artistSearchText = ""
    @State private var isArtistSearching = false
    @State private var isArtistSelectMode = false
    @State private var artistSelectedIds: Set<Int> = []
    @State private var showArtistBatchPlaylist = false

    private let headerImageHeight: CGFloat = 320
    
    init(mid: String, name: String, coverUrl: String?) {
        self.mid = mid
        self.name = name
        self.coverUrl = coverUrl
        _viewModel = StateObject(wrappedValue: QQArtistDetailViewModel(mid: mid))
    }
    
    private var displayName: String { viewModel.resolvedName ?? name }
    
    private var displayCoverUrl: URL? {
        if let resolved = viewModel.resolvedCoverUrl, let url = URL(string: resolved) { return url }
        if let c = coverUrl, let url = URL(string: c) { return url }
        return nil
    }
    
    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteRootBackdrop()
            } else if NeumorphicStyle.isActive {
                ThemeRenderBackdrop(theme: .neumorphic)
            } else if ThemedPageStyle.isActive {
                ThemedPageBackground()
                    .ignoresSafeArea()
            } else {
                QQDetailPalette.pageBase(for: colorScheme)
                    .ignoresSafeArea()
            }

            ScrollView {
                if NeumorphicStyle.isActive {
                    neumorphicQQArtistDetailBody
                        .iPadContentWidth(900)
                } else if MinimalWhiteStyle.isActive {
                    minimalWhiteQQArtistDetailBody
                        .iPadContentWidth(900)
                } else {
                    VStack(spacing: 0) {
                        heroSection

                        infoSection
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                            .padding(.top, -40)

                        tabBar
                            .padding(.top, 20)

                        tabContent
                            .padding(.top, 8)
                            .padding(.bottom, 120)
                    }
                    .iPadContentWidth(900)
                }
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .monoScrollOffset($scrollOffset)
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .monoNavigationBackButton()
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail {
                SongDetailView(song: song)
            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let albumMid = selectedAlbumMid {
                QQMusicDetailView(detailType: .album(
                    mid: albumMid,
                    name: selectedAlbumName ?? "",
                    coverUrl: selectedAlbumCover,
                    artistName: selectedAlbumArtist
                ))
            } else {
                EmptyView()
            }
        }
        .fullScreenCover(item: $selectedQQMV) { item in
            QQMVPlayerView(vid: item.vid)
        }
        .monoSheet(isPresented: $showFullDescription, preset: .standard){
            if let desc = viewModel.resolvedDesc {
                QQArtistBioSheet(name: displayName, coverUrl: displayCoverUrl, desc: desc)
            }
        }
        .monoSheet(isPresented: $showArtistBatchPlaylist, preset: .standard){
            BatchAddToPlaylistSheet(songs: artistFilteredSongs.filter { artistSelectedIds.contains($0.id) })
        }
        .onAppear {
            viewModel.loadSongs()
            viewModel.loadInfo()
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 1 { viewModel.loadAlbums() }
            if newTab == 2 { viewModel.loadMVs() }
        }
    }

    private var minimalWhiteQQArtistDetailBody: some View {
        VStack(spacing: 24) {
            minimalWhiteQQArtistHeroCard
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, DeviceLayout.headerTopPadding + 16)

            tabBar

            tabContent
                .padding(.top, 2)
                .padding(.bottom, 120)
        }
    }

    private var minimalWhiteQQArtistHeroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                CachedAsyncImage(url: displayCoverUrl) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(MinimalWhiteStyle.controlGlassFill)
                        .overlay(MonoIcon(icon: .profile, size: 38, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.6))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 168 : 132, height: DeviceLayout.isPad ? 168 : 132)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                )

                VStack(alignment: .leading, spacing: 12) {
                    PlatformBadgeLabel(text: "QCM", source: .qqmusic, fontSize: 10)

                    Text(displayName)
                        .font(MinimalWhiteStyle.titleFont(DeviceLayout.isPad ? 30 : 26, weight: .semibold))
                        .foregroundStyle(MinimalWhiteStyle.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)

                    HStack(spacing: 8) {
                        if let fans = viewModel.fansCount, fans > 0 {
                            minimalWhiteQQPill(String(format: String(localized: "qq_fans_count"), formatCount(fans)))
                        }
                        if let ac = viewModel.albumCount, ac > 0 {
                            minimalWhiteQQPill(String(format: String(localized: "qq_album_count"), ac))
                        }
                        if let sc = viewModel.songCount, sc > 0 {
                            minimalWhiteQQPill(String(format: String(localized: "qq_song_count"), sc))
                        }
                    }
                    .lineLimit(1)

                    Spacer(minLength: 0)
                }
            }

            if let desc = viewModel.resolvedDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(spacing: 8) {
                        Text(desc)
                            .font(MinimalWhiteStyle.bodyFont(13, weight: .regular))
                            .foregroundStyle(MinimalWhiteStyle.inkMuted)
                            .lineLimit(1)

                        MinimalWhiteDisclosureGlyph()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                if let first = viewModel.songs.first {
                    PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                }
            }) {
                HStack(spacing: 8) {
                    MonoIcon(icon: .play, size: 14, color: MinimalWhiteStyle.onAccent)
                    Text("qq_play_all")
                        .font(MinimalWhiteStyle.labelFont(14, weight: .semibold))
                }
                .foregroundStyle(MinimalWhiteStyle.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(MinimalWhiteStyle.ink, in: Capsule(style: .continuous))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
            .opacity(viewModel.songs.isEmpty ? 0.45 : 1)
            .disabled(viewModel.songs.isEmpty)
        }
        .padding(18)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.chromeRadius,
                elevated: true,
                tint: MinimalWhiteStyle.glassStrongFill
            )
        )
    }

    private func minimalWhiteQQPill(_ text: String) -> some View {
        Text(text)
            .font(MinimalWhiteStyle.labelFont(11, weight: .regular))
            .foregroundStyle(MinimalWhiteStyle.inkMuted)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(MinimalWhiteCapsuleBackground())
    }

    // MARK: - 新拟物 QCM 歌手详情

    private var neumorphicQQArtistDetailBody: some View {
        VStack(spacing: 15) {
            neumorphicQQArtistConsole
            neumorphicQQArtistTabDock
            tabContent
                .padding(.top, 2)
        }
        .padding(.top, DeviceLayout.headerTopPadding + 18)
        .padding(.bottom, 120)
    }

    private var neumorphicQQArtistConsole: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 15) {
                    neumorphicQQArtistIdentityBlock
                    neumorphicQQArtistPortrait
                        .frame(width: DeviceLayout.isPad ? 150 : 122)
                }

                VStack(alignment: .leading, spacing: 14) {
                    neumorphicQQArtistPortrait
                        .frame(maxWidth: .infinity, alignment: .center)
                    neumorphicQQArtistIdentityBlock
                }
            }

            neumorphicQQArtistMetricGrid
        }
        .padding(15)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 32,
                elevated: true,
                tint: NeumorphicStyle.sage.opacity(0.052),
                lightweight: true
            )
        )
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    private var neumorphicQQArtistIdentityBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                NeumorphicPill(text: "QCM", tint: NeumorphicStyle.sage, icon: .headphones, selected: true, compact: true)
                NeumorphicPill(text: "ARTIST", tint: NeumorphicStyle.accent, compact: true)
            }

            Text(displayName)
                .font(NeumorphicStyle.titleFont(DeviceLayout.isPad ? 34 : 29, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let desc = viewModel.resolvedDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(spacing: 8) {
                        Text(desc)
                            .font(NeumorphicStyle.bodyFont(13, weight: .medium))
                            .foregroundStyle(NeumorphicStyle.inkSoft)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)

                        MonoIcon(icon: .chevronRight, size: 10, color: NeumorphicStyle.inkMuted, lineWidth: 1.6)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        NeumorphicSurfaceBackground(
                            cornerRadius: 17,
                            elevated: false,
                            pressed: true,
                            tint: NeumorphicStyle.surfacePressed,
                            lightweight: true
                        )
                    )
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                if let first = viewModel.songs.first {
                    PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                }
            }) {
                NeumorphicPlayPill(title: String(localized: "qq_play_all"), tint: NeumorphicStyle.sage)
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
            .opacity(viewModel.songs.isEmpty ? 0.5 : 1)
            .disabled(viewModel.songs.isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var neumorphicQQArtistPortrait: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(NeumorphicStyle.surfacePressed)
                .frame(width: DeviceLayout.isPad ? 150 : 122, height: DeviceLayout.isPad ? 150 : 122)
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: DeviceLayout.isPad ? 75 : 61,
                        elevated: true,
                        tint: NeumorphicStyle.surfaceRaised,
                        lightweight: true
                    )
                )

            CachedAsyncImage(url: displayCoverUrl?.sized(700)) {
                Circle()
                    .fill(NeumorphicStyle.surfacePressed)
                    .overlay(MonoIcon(icon: .personCircle, size: 32, color: NeumorphicStyle.inkMuted.opacity(0.5), lineWidth: 1.8))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: DeviceLayout.isPad ? 132 : 106, height: DeviceLayout.isPad ? 132 : 106)
            .clipShape(Circle())
            .overlay(Circle().stroke(NeumorphicStyle.separator.opacity(0.36), lineWidth: 0.7))

            HStack(spacing: 4) {
                Capsule().fill(NeumorphicStyle.sage.opacity(0.82)).frame(width: 10, height: 4)
                Capsule().fill(NeumorphicStyle.accent.opacity(0.65)).frame(width: 18, height: 4)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 13,
                    elevated: true,
                    tint: NeumorphicStyle.sage.opacity(0.12),
                    lightweight: true
                )
            )
            .offset(x: 4, y: 3)
        }
        .frame(height: DeviceLayout.isPad ? 160 : 132)
    }

    private var neumorphicQQArtistMetricGrid: some View {
        let songCount = viewModel.songCount ?? (viewModel.songs.isEmpty ? nil : viewModel.songs.count)

        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 9),
            GridItem(.flexible(), spacing: 9),
            GridItem(.flexible(), spacing: 9)
        ], spacing: 9) {
            if let songCount, songCount > 0 {
                neumorphicQQArtistMetricTile(
                    title: String(localized: "qq_tab_music"),
                    value: "\(songCount)",
                    icon: .musicNoteList,
                    tint: NeumorphicStyle.sage
                )
            }

            if let albumCount = viewModel.albumCount, albumCount > 0 {
                neumorphicQQArtistMetricTile(
                    title: String(localized: "qq_tab_album"),
                    value: "\(albumCount)",
                    icon: .album,
                    tint: NeumorphicStyle.accent
                )
            }

            if let fans = viewModel.fansCount, fans > 0 {
                neumorphicQQArtistMetricTile(
                    title: String(localized: "粉丝"),
                    value: formatCount(fans),
                    icon: .like,
                    tint: NeumorphicStyle.warm
                )
            }
        }
    }

    private func neumorphicQQArtistMetricTile(title: String, value: String, icon: MonoIcon.IconType, tint: Color) -> some View {
        HStack(spacing: 9) {
            MonoIcon(icon: icon, size: 14, color: tint, lineWidth: 1.65)
                .frame(width: 30, height: 30)
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: 13,
                        elevated: false,
                        pressed: true,
                        tint: tint.opacity(0.1),
                        lightweight: true
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(NeumorphicStyle.labelFont(10, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(NeumorphicSurfaceBackground(cornerRadius: 18, elevated: false, pressed: true, lightweight: true))
    }

    private var neumorphicQQArtistTabDock: some View {
        HStack(spacing: 7) {
            neumorphicQQArtistTabDockItem(String(localized: "qq_tab_music"), index: 0, icon: .musicNoteList, tint: NeumorphicStyle.sage)
            neumorphicQQArtistTabDockItem(String(localized: "qq_tab_album"), index: 1, icon: .album, tint: NeumorphicStyle.accent)
            neumorphicQQArtistTabDockItem(String(localized: "qq_tab_video"), index: 2, icon: .mv, tint: NeumorphicStyle.warm)
        }
        .padding(6)
        .background(NeumorphicSurfaceBackground(cornerRadius: 23, elevated: true, lightweight: true))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    private func neumorphicQQArtistTabDockItem(_ title: String, index: Int, icon: MonoIcon.IconType, tint: Color) -> some View {
        let selected = selectedTab == index

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 7) {
                MonoIcon(icon: icon, size: 14, color: selected ? tint : NeumorphicStyle.inkMuted, lineWidth: 1.65)
                Text(title)
                    .font(NeumorphicStyle.labelFont(11, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 17,
                    elevated: selected,
                    pressed: !selected,
                    tint: selected ? tint.opacity(0.14) : NeumorphicStyle.surface,
                    lightweight: true
                )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Hero 大图

    private var heroSection: some View {
        let stretchHeight = headerImageHeight - scrollOffset

        return ZStack(alignment: .bottom) {
            if let url = displayCoverUrl {
                CachedAsyncImage(url: url) {
                    Rectangle().fill(QQDetailPalette.placeholderFill)
                }
                .aspectRatio(contentMode: .fill)
                .frame(height: stretchHeight)
                .clipped()
                .monoBackgroundExtension()
            } else {
                Rectangle()
                    .fill(QQDetailPalette.placeholderFill)
                    .frame(height: stretchHeight)
            }

            let pageBase = QQDetailPalette.pageBase(for: colorScheme)
            LinearGradient(
                colors: [
                    .clear, .clear,
                    pageBase.opacity(0.62),
                    pageBase
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: stretchHeight)
        }
        .frame(height: stretchHeight)
        .padding(.bottom, scrollOffset)
        .offset(y: scrollOffset)
    }
    
    // MARK: - 信息区域
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                Text(displayName)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(QQDetailPalette.primaryText)
                    .lineLimit(2)
                Spacer()
                
                PlatformBadgeLabel(text: "QCM", source: .qqmusic, fontSize: 11)
            }
            
            // 统计信息
            HStack(spacing: 16) {
                if let fans = viewModel.fansCount, fans > 0 {
                    Text(String(format: String(localized: "qq_fans_count"), formatCount(fans)))
                        .font(.rounded(size: 13))
                        .foregroundColor(QQDetailPalette.secondaryText)
                }
                if let ac = viewModel.albumCount, ac > 0 {
                    Text(String(format: String(localized: "qq_album_count"), ac))
                        .font(.rounded(size: 13))
                        .foregroundColor(QQDetailPalette.secondaryText)
                }
                if let sc = viewModel.songCount, sc > 0 {
                    Text(String(format: String(localized: "qq_song_count"), sc))
                        .font(.rounded(size: 13))
                        .foregroundColor(QQDetailPalette.secondaryText)
                }
            }
            
            // 简介（可点击展开）
            if let desc = viewModel.resolvedDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(spacing: 4) {
                        Text(desc)
                            .font(.rounded(size: 13))
                            .foregroundColor(QQDetailPalette.secondaryText)
                            .lineLimit(1)
                        MonoIcon(icon: .chevronRight, size: 10, color: QQDetailPalette.secondaryText)
                    }
                }
            }
            
            // 播放全部
            HStack(spacing: 12) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }) {
                    HStack(spacing: 8) {
                        MonoIcon(icon: .play, size: 14, color: QQDetailPalette.accentForeground)
                        Text("qq_play_all")
                            .font(.rounded(size: 14, weight: .bold))
                            .foregroundColor(QQDetailPalette.accentForeground)
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(QQDetailPalette.accent))
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.5 : 1)
                .disabled(viewModel.songs.isEmpty)
                Spacer()
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Tab 栏
    
    private var tabBar: some View {
        HStack(spacing: MinimalWhiteStyle.isActive ? 4 : 28) {
            tabItem(String(localized: "qq_tab_music"), index: 0)
            tabItem(String(localized: "qq_tab_album"), index: 1)
            tabItem(String(localized: "qq_tab_video"), index: 2)
        }
        .padding(.horizontal, MinimalWhiteStyle.isActive ? 6 : DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, MinimalWhiteStyle.isActive ? 6 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteSurfaceBackground(
                    cornerRadius: MinimalWhiteStyle.chromeRadius,
                    elevated: false,
                    tint: MinimalWhiteStyle.glassFill
                )
            }
        }
        .padding(.horizontal, MinimalWhiteStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
    }
    
    private func tabItem(_ title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        }) {
            if MinimalWhiteStyle.isActive {
                Text(title)
                    .font(MinimalWhiteStyle.labelFont(13, weight: selectedTab == index ? .semibold : .regular))
                    .foregroundStyle(selectedTab == index ? MinimalWhiteStyle.ink : MinimalWhiteStyle.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selectedTab == index {
                            MinimalWhiteCapsuleBackground(selected: true)
                        }
                    }
            } else {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.rounded(size: 17, weight: selectedTab == index ? .bold : .medium))
                        .foregroundColor(selectedTab == index ? QQDetailPalette.primaryText : QQDetailPalette.secondaryText)
                    Capsule()
                        .fill(selectedTab == index ? QQDetailPalette.accent : Color.clear)
                        .frame(width: 20, height: 3)
                }
            }
        }
    }
    
    // MARK: - Tab 内容
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: songsTab
        case 1: albumsTab
        case 2: mvsTab
        default: EmptyView()
        }
    }
    
    private var artistFilteredSongs: [Song] {
        viewModel.songs.filtered(by: artistSearchText)
    }
    
    private var songsTab: some View {
        Group {
            if viewModel.isLoading && viewModel.songs.isEmpty {
                loadingView
            } else if viewModel.songs.isEmpty {
                emptyView(String(localized: "qq_no_songs"))
            } else {
                VStack(spacing: 0) {
                    PlaylistSearchBar(
                        searchText: $artistSearchText,
                        isSearching: $isArtistSearching,
                        onSearchActivated: { viewModel.loadAllSongs() },
                        isSelectMode: $isArtistSelectMode,
                        selectedIds: $artistSelectedIds,
                        songs: artistFilteredSongs,
                        onBatchQueue: {
                            let selected = artistFilteredSongs.filter { artistSelectedIds.contains($0.id) }
                            SongBatchActionHelper.addToQueue(selected) {
                                isArtistSelectMode = false
                                artistSelectedIds.removeAll()
                            }
                        },
                        onBatchDownload: { batchDownload(from: artistFilteredSongs, ids: artistSelectedIds, reset: { isArtistSelectMode = false; artistSelectedIds.removeAll() }) },
                        onBatchCollect: { showArtistBatchPlaylist = true }
                    )
                    
                    LazyVStack(spacing: 0) {
                        ForEach(Array(artistFilteredSongs.enumerated()), id: \.element.id) { index, song in
                            SongListRow(song: song, index: index, isSelecting: isArtistSelectMode, isSelected: artistSelectedIds.contains(song.id), onArtistTap: { _ in }, onDetailTap: { s in
                                selectedSongForDetail = s
                                showSongDetail = true
                            }, onAlbumTap: { _ in }, onTap: {
                                if isArtistSelectMode {
                                    if artistSelectedIds.contains(song.id) {
                                        artistSelectedIds.remove(song.id)
                                    } else {
                                        artistSelectedIds.insert(song.id)
                                    }
                                } else {
                                    PlayerManager.shared.play(song: song, in: artistFilteredSongs)
                                }
                            })
                            .onAppear {
                                if !isArtistSearching && index == viewModel.songs.count - 3 { viewModel.loadMoreSongs() }
                            }
                        }
                    }
                }
                .padding(.vertical, MinimalWhiteStyle.isActive ? 8 : 10)
                .background {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.chromeRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    }
                }
                .padding(.horizontal, MinimalWhiteStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
            }
        }
    }
    
    private var albumsTab: some View {
        Group {
            if viewModel.isLoadingAlbums && viewModel.albums.isEmpty {
                loadingView
            } else if viewModel.albums.isEmpty {
                emptyView(String(localized: "qq_no_albums"))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.albums) { album in
                        qqAlbumRow(album)
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 8)
            }
        }
    }
    
    private func qqAlbumRow(_ album: AlbumInfo) -> some View {
        Button(action: {
            // 从 picUrl 反推 mid（格式: ...M000{mid}.jpg）
            let albumMid = extractMidFromPicUrl(album.picUrl)
            selectedAlbumMid = albumMid
            selectedAlbumName = album.name
            selectedAlbumCover = album.picUrl
            selectedAlbumArtist = album.artistName
            showAlbumDetail = true
        }) {
            HStack(spacing: 14) {
                if let coverUrl = album.coverUrl {
                    CachedAsyncImage(url: coverUrl) {
                        RoundedRectangle(cornerRadius: 10).fill(QQDetailPalette.placeholderFill)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(QQDetailPalette.placeholderFill)
                        .frame(width: 72, height: 72)
                        .overlay(MonoIcon(icon: .album, size: 24, color: QQDetailPalette.mutedText.opacity(0.36)))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(album.name)
                        .font(.rounded(size: 16, weight: .medium))
                        .foregroundColor(QQDetailPalette.primaryText)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        if !album.publishDateText.isEmpty {
                            Text(album.publishDateText)
                                .font(.rounded(size: 12))
                                .foregroundColor(QQDetailPalette.secondaryText)
                        }
                        if let size = album.size, size > 0 {
                            Text("\(size) Tracks")
                                .font(.rounded(size: 12))
                                .foregroundColor(QQDetailPalette.secondaryText)
                        }
                    }
                }
                Spacer(minLength: 0)
                MonoIcon(icon: .chevronRight, size: 12, color: QQDetailPalette.mutedText.opacity(0.5))
            }
            .padding(12)
            .background(
                Group {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.cardRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(QQDetailPalette.placeholderFill)
                            .monoGlass(cornerRadius: 20)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
    }
    
    private var mvsTab: some View {
        Group {
            if viewModel.isLoadingMVs && viewModel.mvs.isEmpty {
                loadingView
            } else if viewModel.mvs.isEmpty {
                emptyView(String(localized: "qq_no_videos"))
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ]
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.mvs) { mv in
                        qqMVCard(mv: mv)
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 8)
            }
        }
    }
    
    private func qqMVCard(mv: QQMV) -> some View {
        Button(action: {
            selectedQQMV = QQMVVidItem(vid: mv.vid)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    if let urlStr = mv.coverUrl, let url = URL(string: urlStr) {
                        CachedAsyncImage(url: url) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(QQDetailPalette.placeholderFill)
                        }
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(QQDetailPalette.placeholderFill)
                            .frame(height: 100)
                    }
                    if !mv.durationText.isEmpty {
                        Text(mv.durationText)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.clear).monoGlass(cornerRadius: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(6)
                    }
                }
                Text(mv.name)
                    .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(13, weight: .medium) : .rounded(size: 13, weight: .medium))
                    .foregroundColor(QQDetailPalette.primaryText)
                    .lineLimit(1)
            }
            .padding(MinimalWhiteStyle.isActive ? 8 : 0)
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
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
    }
    
    // MARK: - 辅助
    
    private var loadingView: some View {
        VStack {
            Spacer().frame(height: 60)
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: QQDetailPalette.secondaryText))
            Spacer().frame(height: 60)
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
    
    private func emptyView(_ text: String) -> some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            if MinimalWhiteStyle.isActive {
                MinimalWhiteIconBadge(icon: .musicNoteList, size: 52)
            }
            Text(text)
                .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(14, weight: .medium) : .rounded(size: 15))
                .foregroundColor(QQDetailPalette.secondaryText)
            Spacer().frame(height: 60)
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
    
    private func formatCount(_ count: Int) -> String {
        L10n.compactCount(count)
    }
    
    /// 从 picUrl 中提取 mid（格式: ...M000{mid}.jpg）
    private func extractMidFromPicUrl(_ picUrl: String?) -> String {
        guard let url = picUrl else { return "" }
        // 匹配 M000 后面到 .jpg 之间的字符串
        if let range = url.range(of: "M000") {
            let afterM000 = url[range.upperBound...]
            if let dotRange = afterM000.range(of: ".") {
                return String(afterM000[..<dotRange.lowerBound])
            }
        }
        return ""
    }
    
    private func batchDownload(from songs: [Song], ids: Set<Int>, reset: @escaping () -> Void) {
        let selected = songs.filter { ids.contains($0.id) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
            }
        }
        AlertManager.shared.show(title: String(localized: "download_batch_added_title"), message: L10n.format("download_batch_queue_added_format", selected.count), primaryButtonTitle: String(localized: "common_confirm"), primaryAction: {})
        withAnimation { reset() }
    }
}
