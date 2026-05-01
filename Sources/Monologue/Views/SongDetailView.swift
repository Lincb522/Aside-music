import SwiftUI

struct SongDetailView: View {
    let song: Song
    @State private var viewModel = SongDetailViewModel()
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var playerManager = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    @State private var selectedMlog: MlogItem?

    struct Theme {
        static var text: Color {
            if SequoiaStyle.isActive { return SequoiaStyle.ink }
            if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
            return Color.monologueTextPrimary
        }

        static var secondaryText: Color {
            if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
            if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
            return Color.monologueTextSecondary
        }

        static var accent: Color {
            if SequoiaStyle.isActive { return SequoiaStyle.accent }
            if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
            return Color.monologueIconBackground
        }

        static var accentForeground: Color {
            if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
            if NeumorphicStyle.isActive { return Color(light: .white, dark: .black) }
            return Color.monologueIconForeground
        }

        static var coverFill: Color {
            if SequoiaStyle.isActive { return SequoiaStyle.materialPressed.opacity(0.74) }
            if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
            return Color.gray.opacity(0.3)
        }

        static func titleFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            if SequoiaStyle.isActive { return SequoiaStyle.titleFont(size, weight: weight) }
            if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(size, weight: weight) }
            return .system(size: size, weight: weight, design: .rounded)
        }

        static func bodyFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
            if SequoiaStyle.isActive { return SequoiaStyle.bodyFont(size, weight: weight) }
            if NeumorphicStyle.isActive { return NeumorphicStyle.bodyFont(size, weight: weight) }
            return .system(size: size, weight: weight, design: .rounded)
        }

        static func labelFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
            if SequoiaStyle.isActive { return SequoiaStyle.labelFont(size, weight: weight) }
            if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(size, weight: weight) }
            return .system(size: size, weight: weight, design: .rounded)
        }
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedPageBackground()

            ScrollView {
                VStack(spacing: 0) {
                    songHeaderContent
                    // 音乐百科
                    if !viewModel.wikiBlocks.isEmpty {
                        songWikiSection
                    }

                    // 相似歌曲
                    if !viewModel.simiSongs.isEmpty {
                        simiSongsSection
                    }

                    if !viewModel.relatedSongs.isEmpty {
                        songsListView
                    } else if viewModel.isLoading {
                        MonologueLoadingView(text: "LOADING RELATED")
                            .padding(.top, 50)
                    }
                }
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
                AlbumDetailView(albumId: albumId, albumName: song.al?.name, albumCoverUrl: song.coverUrl)

            }
        }
        .onAppear {
            // 仅ncm歌曲加载相关内容
            if !song.isQQMusic {
                if let artistId = song.artists.first?.id {
                    viewModel.loadRelatedSongs(artistId: artistId)
                }
                viewModel.loadSongWiki(songId: song.id)
                viewModel.loadSimiSongs(songId: song.id)
            }
        }
    }

    // MARK: - Subviews

    private var songHeaderContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: song.coverUrl) {
                    Theme.coverFill
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .cornerRadius(12)
                .overlay {
                    if SequoiaStyle.isActive {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(SequoiaStyle.separator, lineWidth: 0.7)
                    }
                }
                .shadow(color: .black.opacity(SequoiaStyle.isActive ? 0.08 : 0.15), radius: SequoiaStyle.isActive ? 10 : 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text(song.name)
                        .font(Theme.titleFont(20, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .lineLimit(2)

                    Text(song.artistName)
                        .font(Theme.bodyFont(14))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)

                    if let album = song.album?.name {
                        Button(action: {
                            if let albumId = song.al?.id, albumId > 0 {
                                selectedAlbumId = albumId
                                showAlbumDetail = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(album)
                                    .font(Theme.labelFont(12))
                                    .foregroundColor(Theme.secondaryText.opacity(0.8))
                                    .lineLimit(1)
                                if let albumId = song.al?.id, albumId > 0 {
                                    MonologueIcon(icon: .chevronRight, size: 10, color: Theme.secondaryText.opacity(0.5))
                                }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Button(action: {
                    if !viewModel.relatedSongs.isEmpty {
                        PlayerManager.shared.play(song: song, in: viewModel.relatedSongs)
                    } else {
                        PlayerManager.shared.play(song: song, in: [song])
                    }
                }) {
                    HStack(spacing: 6) {
                        MonologueIcon(icon: .play, size: 12, color: Theme.accentForeground)
                        Text(LocalizedStringKey("action_play"))
                            .font(Theme.labelFont(12, weight: .semibold))
                    }
                    .foregroundColor(Theme.accentForeground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.accent)
                    .cornerRadius(20)
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

                Button(action: {
                    PlayerManager.shared.playNext(song: song)
                }) {
                    MonologueIcon(icon: .playNext, size: 14, color: Theme.accent)
                        .padding(8)
                        .background(
                            Circle().fill(SequoiaStyle.isActive ? SequoiaStyle.materialPressed : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)).monologueGlassCircle()
                        )
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.08), radius: 2)
                }
                .buttonStyle(MonologueBouncingButtonStyle())

                Button(action: {
                    PlayerManager.shared.addToQueue(song: song)
                }) {
                    MonologueIcon(icon: .add, size: 14, color: Theme.accent)
                        .padding(8)
                        .background(
                            Circle().fill(SequoiaStyle.isActive ? SequoiaStyle.materialPressed : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)).monologueGlassCircle()
                        )
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.08), radius: 2)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
        }
        .padding(24)
        .padding(.top, 16)
        .background(.clear)
        .themedPageSurface(cornerRadius: 22, elevated: true, mangaTint: MangaStyle.bubbleWhite)
        .padding(.horizontal, ThemedPageStyle.isActive ? 24 : 0)
    }

    private var songsListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(format: NSLocalizedString("more_by_artist", comment: ""), song.artistName))
                .font(Theme.titleFont(17, weight: .semibold))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.relatedSongs.enumerated()), id: \.element.id) { index, relatedSong in
                    SongListRow(song: relatedSong, index: index, onArtistTap: { artistId in
                        selectedArtistId = artistId
                        showArtistDetail = true
                    }, onDetailTap: { detailSong in
                        selectedSongForDetail = detailSong
                        showSongDetail = true
                    }, onAlbumTap: { albumId in
                        selectedAlbumId = albumId
                        showAlbumDetail = true
                    }, onTap: {
                        PlayerManager.shared.play(song: relatedSong, in: viewModel.relatedSongs)
                    })
                }
            }
        }
    }

    // MARK: - 音乐百科

    private var songWikiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("song_wiki_title"))
                .font(.rounded(size: 16, weight: .semibold))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 24)
                .padding(.top, 16)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.wikiBlocks) { block in
                    VStack(alignment: .leading, spacing: 4) {
                        if !block.title.isEmpty {
                            Text(block.title)
                                .font(.rounded(size: 14, weight: .medium))
                                .foregroundColor(Theme.text)
                        }
                        if !block.description.isEmpty {
                            Text(block.description)
                                .font(.rounded(size: 13))
                                .foregroundColor(Theme.secondaryText)
                                .lineSpacing(4)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SequoiaStyle.isActive ? SequoiaStyle.materialList.opacity(0.6) : (NeumorphicStyle.isActive ? Color.clear : Color.monologueGlassTint))
                    .monologueGlass(cornerRadius: 20)
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            )
            .themedOnlyPageSurface(cornerRadius: 18, elevated: false, mangaTint: MangaStyle.bubbleWhite)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - 相似歌曲

    private var simiSongsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("simi_songs_title"))
                .font(.rounded(size: 16, weight: .semibold))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 24)
                .padding(.top, 16)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(viewModel.simiSongs.prefix(10)) { simiSong in
                        Button(action: {
                            PlayerManager.shared.play(song: simiSong, in: viewModel.simiSongs)
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                CachedAsyncImage(url: simiSong.coverUrl?.sized(300)) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(SequoiaStyle.isActive ? SequoiaStyle.materialPressed : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint))
                                        .monologueGlass(cornerRadius: 12)
                                }
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                Text(simiSong.name)
                                    .font(Theme.bodyFont(13))
                                    .foregroundColor(Theme.text)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)

                                Text(simiSong.artistName)
                                    .font(Theme.labelFont(11))
                                    .foregroundColor(Theme.secondaryText)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)
                            }
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }
}
