import SwiftUI

// MARK: - Main View
struct PlaylistDetailView: View {
    let playlist: Playlist
    let initialSongs: [Song]?
    
    @StateObject private var viewModel = PlaylistDetailViewModel()
    
    @ObservedObject var playerManager = PlayerManager.shared
    @ObservedObject var subManager = SubscriptionManager.shared
    
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    
    @State private var scrollOffset: CGFloat = 0
    
    init(playlist: Playlist, songs: [Song]? = nil) {
        self.playlist = playlist
        self.initialSongs = songs
    }
    
    struct Theme {
        static let cream = Color.clear
        static let milk = Color.asideMilk
        static let accent = Color.asideIconBackground // 黑/白自适应
        static let text = Color.asideTextPrimary
        static let secondaryText = Color.asideTextSecondary
        static let softShadow = Color.clear
    }

    var body: some View {
        ZStack {
            AsideBackground()
            
            VStack(spacing: 0) {
                cleanHeader
                
                ScrollView(showsIndicators: false) {
                    songListSection
                        .padding(.bottom, 100)
                }
            }
        }
        .navigationBarHidden(true)
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
            if let songs = initialSongs {
                viewModel.setSongs(songs)
            } else {
                viewModel.fetchSongs(playlistId: playlist.id)
            }
        }
    }
    
    // MARK: - Components
    
    private var cleanHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AsideBackButton()
                
                Spacer()
                
                if let count = viewModel.playlistDetail?.trackCount ?? playlist.trackCount {
                    Text(String(format: NSLocalizedString("songs_count_format", comment: ""), count))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.milk)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.secondaryText.opacity(0.2), lineWidth: 0.5)
                        )
                }
            }
            
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(400)) {
                    Color.gray.opacity(0.1)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.playlistDetail?.name ?? playlist.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                if let creator = viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname {
                    Text(String(format: NSLocalizedString("created_by_format", comment: ""), creator))
                        .font(.system(size: 13))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer().frame(height: 4)
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            if let first = viewModel.songs.first {
                                PlayerManager.shared.play(song: first, in: viewModel.songs)
                            }
                        }) {
                            HStack(spacing: 6) {
                                AsideIcon(icon: .play, size: 12, color: .asideIconForeground)
                                Text(LocalizedStringKey("play_now"))
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.asideIconForeground)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Theme.accent)
                            .cornerRadius(20)
                            .shadow(color: Theme.accent.opacity(0.2), radius: 5, x: 0, y: 2)
                        }
                        .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))

                        // 收藏歌单按钮（非自己创建的歌单才显示）
                        if playlist.creator?.userId != APIService.shared.currentUserId {
                            SubscribeButton(
                                isSubscribed: subManager.isPlaylistSubscribed(playlist.id),
                                action: { subManager.togglePlaylistSubscription(id: playlist.id) }
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, DeviceLayout.headerTopPadding)
    }
    
    private var songListSection: some View {
        LazyVStack(spacing: 0) {
            if viewModel.isLoading {
                AsideLoadingView(text: "LOADING TRACKS")
            } else {
                ForEach(Array(viewModel.songs.enumerated()), id: \.element.id) { index, song in
                    SongListRow(
                        song: song,
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
                        }
                    )
                    .asButton {
                        PlayerManager.shared.play(song: song, in: viewModel.getCurrentList())
                    }
                }
                
                if viewModel.isLoadingMore {
                    AsideLoadingView(text: "LOADING MORE", centered: false)
                        .padding()
                }
                if viewModel.hasMore && !viewModel.isLoading && !viewModel.isLoadingMore {
                    Color.clear.frame(height: 20).onAppear { viewModel.loadMore() }
                }
                if !viewModel.hasMore && !viewModel.songs.isEmpty && !viewModel.isLoading {
                    NoMoreDataView()
                }
                
                Color.clear.frame(height: 100)
            }
        }
    }
}

// MARK: - Utilities

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}



