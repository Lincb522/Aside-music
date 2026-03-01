import SwiftUI

// MARK: - 歌手详情页（参考网易云风格：大图 Hero + Tab 切换）

struct ArtistDetailView: View {
    let artistId: Int
    @State private var viewModel = ArtistDetailViewModel()
    @ObservedObject var playerManager = PlayerManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab = 0 // 0: 音乐, 1: 专辑, 2: 视频, 3: 相似
    @State private var showFullDescription = false
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    @State private var selectedMV: MVIdItem?
    @State private var headerImageHeight: CGFloat = 320
    @State private var scrollOffset: CGFloat = 0

    // 从封面提取的颜色
    @State private var dominantColor: Color = .clear
    @State private var isAppeared = false

    var body: some View {
        ZStack {
            // 背景色
            (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7"))
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Hero 大图区域（弹性拉伸）
                    heroSection

                    // 信息区域（名字、粉丝、关注按钮、播放按钮）
                    infoSection
                        .padding(.horizontal, 24)
                        .padding(.top, -40)

                    // Tab 栏
                    tabBar
                        .padding(.top, 20)

                    // Tab 内容
                    tabContent
                        .padding(.top, 8)
                        .padding(.bottom, 120)
                }
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                min(geometry.contentOffset.y + geometry.contentInsets.top, 0)
            } action: { _, offset in
                scrollOffset = offset
            }
            .ignoresSafeArea(edges: .top)

            // 顶部返回按钮（悬浮）
            VStack {
                HStack {
                    AsideBackButton()
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, DeviceLayout.headerTopPadding)
                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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
        .fullScreenCover(item: $selectedMV) { item in
            MVPlayerView(mvId: item.id)
        }
        .sheet(isPresented: $showFullDescription) {
            ArtistBioSheet(viewModel: viewModel, artistId: artistId)
        }
        .onAppear {
            viewModel.loadData(artistId: artistId)
            withAnimation(.easeOut(duration: 0.5)) { isAppeared = true }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 1 { viewModel.loadAlbums(artistId: artistId) }
            if newTab == 2 { viewModel.loadMVs(artistId: artistId) }
            if newTab == 3 { viewModel.loadSimiArtists(artistId: artistId) }
        }
    }
}


// MARK: - Hero 大图

extension ArtistDetailView {

    private var heroSection: some View {
        let stretchHeight = headerImageHeight - scrollOffset
        
        return ZStack(alignment: .bottom) {
            // 歌手大图（弹性拉伸）
            if let artist = viewModel.artist, let coverUrl = artist.coverUrl?.sized(800) {
                CachedAsyncImage(url: coverUrl) {
                    Rectangle().fill(Color.asideGlassTint)
                }
                .aspectRatio(contentMode: .fill)
                .frame(height: stretchHeight)
                .clipped()
                .backgroundExtensionEffect()
            } else {
                Rectangle()
                    .fill(Color.asideGlassTint)
                    .frame(height: stretchHeight)
            }

            // 底部渐变遮罩
            LinearGradient(
                colors: [
                    .clear,
                    .clear,
                    (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7")).opacity(0.6),
                    (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7"))
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
}

// MARK: - 信息区域

extension ArtistDetailView {

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.artist?.name ?? "")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
                .lineLimit(2)

            // 粉丝数 + 简介
            HStack(spacing: 16) {
                if viewModel.fansCount > 0 {
                    Text(String(format: NSLocalizedString("artist_fans_count", comment: ""), formatFansCount(viewModel.fansCount)))
                        .font(.rounded(size: 13))
                        .foregroundColor(.asideTextSecondary)
                }

                if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                    Text(String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize))
                        .font(.rounded(size: 13))
                        .foregroundColor(.asideTextSecondary)
                }

                if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                    Text(String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize))
                        .font(.rounded(size: 13))
                        .foregroundColor(.asideTextSecondary)
                }
            }

            // 简介（可点击展开）
            if let desc = viewModel.artist?.briefDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(spacing: 4) {
                        Text(desc)
                            .font(.rounded(size: 13))
                            .foregroundColor(.asideTextSecondary)
                            .lineLimit(1)
                        AsideIcon(icon: .chevronRight, size: 10, color: .asideTextSecondary)
                    }
                }
            }

            // 播放全部按钮
            HStack(spacing: 12) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.play(song: first, in: viewModel.songs)
                    }
                }) {
                    HStack(spacing: 8) {
                        AsideIcon(icon: .play, size: 14, color: .asideIconForeground)
                        Text(LocalizedStringKey("artist_play_all"))
                            .font(.rounded(size: 14, weight: .bold))
                            .foregroundColor(.asideIconForeground)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.asideIconBackground))
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.5 : 1)
                .disabled(viewModel.songs.isEmpty)

                Spacer()
            }
            .padding(.top, 4)
        }
    }

    private func formatFansCount(_ count: Int) -> String {
        if count >= 10000 {
            let wan = Double(count) / 10000.0
            return wan >= 100 ? "\(Int(wan))万" : String(format: "%.1f万", wan)
        }
        return "\(count)"
    }
}


// MARK: - Tab 栏

extension ArtistDetailView {

    private var tabBar: some View {
        HStack(spacing: 28) {
            tabItem(NSLocalizedString("artist_tab_music", comment: ""), index: 0)
            tabItem(NSLocalizedString("artist_tab_album", comment: ""), index: 1)
            tabItem(NSLocalizedString("artist_tab_video", comment: ""), index: 2)
            tabItem(NSLocalizedString("artist_tab_similar", comment: ""), index: 3)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tabItem(_ title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.rounded(size: 17, weight: selectedTab == index ? .bold : .medium))
                    .foregroundColor(selectedTab == index ? .asideTextPrimary : .asideTextSecondary)

                Capsule()
                    .fill(selectedTab == index ? Color.asideIconBackground : Color.clear)
                    .frame(width: 20, height: 3)
            }
        }
    }
}

// MARK: - Tab 内容

extension ArtistDetailView {

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            songsTab
        case 1:
            albumsTab
        case 2:
            mvsTab
        case 3:
            simiArtistsTab
        default:
            EmptyView()
        }
    }

    // MARK: 音乐 Tab

    private var songsTab: some View {
        Group {
            if viewModel.isLoading && viewModel.songs.isEmpty {
                loadingPlaceholder
            } else if viewModel.songs.isEmpty {
                emptyPlaceholder(NSLocalizedString("artist_no_songs", comment: ""))
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.songs.enumerated()), id: \.element.id) { index, song in
                        SongListRow(song: song, index: index, onArtistTap: { artistId in
                            selectedArtistId = artistId
                            showArtistDetail = true
                        }, onDetailTap: { detailSong in
                            selectedSongForDetail = detailSong
                            showSongDetail = true
                        }, onAlbumTap: { albumId in
                            selectedAlbumId = albumId
                            showAlbumDetail = true
                        })
                        .asButton {
                            PlayerManager.shared.play(song: song, in: viewModel.songs)
                        }
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: 专辑 Tab

    private var albumsTab: some View {
        Group {
            if viewModel.isLoadingAlbums && viewModel.albums.isEmpty {
                loadingPlaceholder
            } else if viewModel.albums.isEmpty {
                emptyPlaceholder(NSLocalizedString("artist_no_albums", comment: ""))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.albums) { album in
                        albumRow(album)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
        }
    }

    private func albumRow(_ album: AlbumInfo) -> some View {
        Button(action: {
            selectedAlbumId = album.id
            showAlbumDetail = true
        }) {
            HStack(spacing: 14) {
                // 专辑封面
                if let coverUrl = album.coverUrl {
                    CachedAsyncImage(url: coverUrl) {
                        RoundedRectangle(cornerRadius: 10).fill(Color.asideGlassTint)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.asideGlassTint)
                        .frame(width: 72, height: 72)
                        .overlay(AsideIcon(icon: .album, size: 24, color: .asideTextSecondary.opacity(0.3)))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(album.name)
                        .font(.rounded(size: 16, weight: .medium))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if !album.publishDateText.isEmpty {
                            Text(album.publishDateText)
                                .font(.rounded(size: 12))
                                .foregroundColor(.asideTextSecondary)
                        }
                        if let size = album.size, size > 0 {
                            Text("\(size) Tracks")
                                .font(.rounded(size: 12))
                                .foregroundColor(.asideTextSecondary)
                        }
                    }
                }

                Spacer(minLength: 0)

                AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary.opacity(0.4))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.asideGlassTint)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
    }

    // MARK: 视频 Tab

    private var mvsTab: some View {
        Group {
            if viewModel.isLoadingMVs && viewModel.mvs.isEmpty {
                loadingPlaceholder
            } else if viewModel.mvs.isEmpty {
                emptyPlaceholder(NSLocalizedString("artist_no_videos", comment: ""))
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ]
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.mvs) { mv in
                        MVGridCard(mv: mv) {
                            selectedMV = MVIdItem(id: mv.id)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
        }
    }

    // MARK: 相似歌手 Tab

    private var simiArtistsTab: some View {
        Group {
            if viewModel.isLoadingSimi && viewModel.simiArtists.isEmpty {
                loadingPlaceholder
            } else if viewModel.simiArtists.isEmpty {
                emptyPlaceholder(NSLocalizedString("artist_no_similar", comment: ""))
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ]
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(viewModel.simiArtists) { artist in
                        Button(action: {
                            selectedArtistId = artist.id
                            showArtistDetail = true
                        }) {
                            VStack(spacing: 10) {
                                if let coverUrl = artist.coverUrl?.sized(300) {
                                    CachedAsyncImage(url: coverUrl) {
                                        Circle().fill(Color.asideGlassTint)
                                    }
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 90, height: 90)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.asideGlassTint)
                                        .frame(width: 90, height: 90)
                                        .overlay(AsideIcon(icon: .personCircle, size: 32, color: .asideTextSecondary.opacity(0.3)))
                                }
                                
                                Text(artist.name)
                                    .font(.rounded(size: 13, weight: .medium))
                                    .foregroundColor(.asideTextPrimary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
        }
    }

    // MARK: 占位视图

    private var loadingPlaceholder: some View {
        VStack {
            Spacer().frame(height: 60)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .asideTextSecondary))
            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity)
    }

    private func emptyPlaceholder(_ text: String) -> some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            Text(text)
                .font(.rounded(size: 15))
                .foregroundColor(.asideTextSecondary)
            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity)
    }
}


// MARK: - 歌手简介 Sheet

struct ArtistBioSheet: View {
    var viewModel: ArtistDetailViewModel
    let artistId: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 拖拽指示条
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.asideTextSecondary.opacity(0.25))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            // 头部：歌手头像 + 名字
            HStack(spacing: 14) {
                if let artist = viewModel.artist {
                    CachedAsyncImage(url: artist.coverUrl?.sized(200)) {
                        Circle().fill(Color.asideGlassTint)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.artist?.name ?? "")
                        .font(.rounded(size: 20, weight: .bold))
                        .foregroundColor(.asideTextPrimary)

                    HStack(spacing: 12) {
                        if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                            HStack(spacing: 4) {
                                AsideIcon(icon: .album, size: 12, color: .asideTextSecondary)
                                Text(String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize))
                            }
                            .font(.rounded(size: 12))
                            .foregroundColor(.asideTextSecondary)
                        }
                        if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                            HStack(spacing: 4) {
                                AsideIcon(icon: .musicNote, size: 12, color: .asideTextSecondary)
                                Text(String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize))
                            }
                            .font(.rounded(size: 12))
                            .foregroundColor(.asideTextSecondary)
                        }
                    }
                }

                Spacer()

                Button(action: { dismiss() }) {
                    AsideIcon(icon: .close, size: 20, color: .asideTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.asideSeparator)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color.asideSeparator)
                .frame(height: 0.5)

            if viewModel.isLoadingDesc {
                Spacer()
                AsideLoadingView(text: "LOADING")
                Spacer()
            } else if let desc = viewModel.descResult {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if let brief = desc.briefDesc, !brief.isEmpty {
                            bioCard {
                                Text(brief)
                                    .font(.rounded(size: 15, weight: .regular))
                                    .foregroundColor(.asideTextPrimary)
                                    .lineSpacing(6)
                            }
                        }

                        ForEach(desc.sections) { section in
                            bioCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(section.title)
                                        .font(.rounded(size: 16, weight: .semibold))
                                        .foregroundColor(.asideTextPrimary)
                                    Text(section.content)
                                        .font(.rounded(size: 14, weight: .regular))
                                        .foregroundColor(.asideTextSecondary)
                                        .lineSpacing(5)
                                }
                            }
                        }

                        if (desc.briefDesc ?? "").isEmpty && desc.sections.isEmpty {
                            noContentView
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if let brief = viewModel.artist?.briefDesc, !brief.isEmpty {
                            bioCard {
                                Text(brief)
                                    .font(.rounded(size: 15, weight: .regular))
                                    .foregroundColor(.asideTextPrimary)
                                    .lineSpacing(6)
                            }
                        } else {
                            noContentView
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background { AsideBackground() }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            viewModel.loadDesc(artistId: artistId)
        }
    }

    private func bioCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private var noContentView: some View {
        VStack(spacing: 14) {
            AsideIcon(icon: .info, size: 36, color: .asideTextSecondary.opacity(0.3))
            Text(LocalizedStringKey("artist_no_bio"))
                .font(.rounded(size: 15))
                .foregroundColor(.asideTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
