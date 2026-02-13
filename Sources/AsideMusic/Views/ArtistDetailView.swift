import SwiftUI
import Combine

@MainActor
class ArtistDetailViewModel: ObservableObject {
    @Published var artist: ArtistInfo?
    @Published var songs: [Song] = []
    @Published var isLoading = true
    @Published var descResult: ArtistDescResult?
    @Published var isLoadingDesc = false
    private var cancellables = Set<AnyCancellable>()
    
    func loadData(artistId: Int) {
        if artist?.id == artistId && !songs.isEmpty { return }
        
        isLoading = true
        
        let detailPub = APIService.shared.fetchArtistDetail(id: artistId)
        let songsPub = APIService.shared.fetchArtistTopSongs(id: artistId)
        
        Publishers.Zip(detailPub, songsPub)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("Error loading artist data: \(error)")
                }
                self?.isLoading = false
            }, receiveValue: { [weak self] (artist, songs) in
                self?.artist = artist
                self?.songs = songs
            })
            .store(in: &cancellables)
    }
    
    func loadDesc(artistId: Int) {
        guard descResult == nil, !isLoadingDesc else { return }
        isLoadingDesc = true
        
        APIService.shared.fetchArtistDesc(id: artistId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingDesc = false
            }, receiveValue: { [weak self] result in
                self?.descResult = result
            })
            .store(in: &cancellables)
    }
}

struct ArtistDetailView: View {
    let artistId: Int
    @StateObject private var viewModel = ArtistDetailViewModel()
    @ObservedObject var playerManager = PlayerManager.shared
    
    @State private var showFullDescription = false
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    
    struct Theme {
        static let text = Color.asideTextPrimary
        static let secondaryText = Color.asideTextSecondary
        static let accent = Color.asideIconBackground
        static let milk = Color.asideMilk
    }
    
    var body: some View {
        ZStack {
            AsideBackground()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView(showsIndicators: false) {
                    if !viewModel.songs.isEmpty {
                        songsListView
                            .padding(.bottom, 100)
                    } else if viewModel.isLoading {
                        AsideLoadingView(text: "LOADING ARTIST")
                    }
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
            viewModel.loadData(artistId: artistId)
        }
        .sheet(isPresented: $showFullDescription) {
            ArtistBioSheet(viewModel: viewModel, artistId: artistId)
        }
    }
    
    // MARK: - 头部
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AsideBackButton()
                Spacer()
            }
            
            HStack(alignment: .top, spacing: 16) {
                if let artist = viewModel.artist {
                    CachedAsyncImage(url: artist.coverUrl?.sized(600)) {
                        Color.gray.opacity(0.3)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .shadow(radius: 8)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 100)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.artist?.name ?? NSLocalizedString("loading_ellipsis", comment: ""))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text)
                        .lineLimit(2)
                    
                    if let desc = viewModel.artist?.briefDesc {
                        Button(action: {
                            showFullDescription = true
                        }) {
                            HStack(spacing: 4) {
                                Text(desc)
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.secondaryText)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                AsideIcon(icon: .chevronRight, size: 12, color: Theme.secondaryText)
                            }
                        }
                    }
                    
                    Button(action: {
                        if let first = viewModel.songs.first {
                            PlayerManager.shared.play(song: first, in: viewModel.songs)
                        }
                    }) {
                        HStack(spacing: 6) {
                            AsideIcon(icon: .play, size: 12, color: .white)
                            Text(LocalizedStringKey("artist_popular_songs"))
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.accent)
                        .cornerRadius(20)
                    }
                    .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, DeviceLayout.headerTopPadding)
    }
    
    // MARK: - 歌曲列表
    
    private var songsListView: some View {
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


// MARK: - 歌手简介 Sheet

struct ArtistBioSheet: View {
    @ObservedObject var viewModel: ArtistDetailViewModel
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
                        Circle().fill(Color.asideCardBackground)
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
                                Text("\(albumSize) 专辑")
                            }
                                .font(.rounded(size: 12))
                                .foregroundColor(.asideTextSecondary)
                        }
                        if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                            HStack(spacing: 4) {
                                AsideIcon(icon: .musicNote, size: 12, color: .asideTextSecondary)
                                Text("\(musicSize) 歌曲")
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
            
            // 内容区域
            if viewModel.isLoadingDesc {
                Spacer()
                AsideLoadingView(text: "LOADING")
                Spacer()
            } else if let desc = viewModel.descResult {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // 简介概要
                        if let brief = desc.briefDesc, !brief.isEmpty {
                            bioCard {
                                Text(brief)
                                    .font(.rounded(size: 15, weight: .regular))
                                    .foregroundColor(.asideTextPrimary)
                                    .lineSpacing(6)
                            }
                        }
                        
                        // 分段详细介绍
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
                        
                        // 没有任何内容
                        if (desc.briefDesc ?? "").isEmpty && desc.sections.isEmpty {
                            noContentView
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            } else {
                // 回退：用 briefDesc
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
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
            }
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.asideCardBackground.opacity(0.55))
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            viewModel.loadDesc(artistId: artistId)
        }
    }
    
    // MARK: - 卡片容器
    
    private func bioCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.asideCardBackground)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - 无内容
    
    private var noContentView: some View {
        VStack(spacing: 14) {
            AsideIcon(icon: .info, size: 36, color: .asideTextSecondary.opacity(0.3))
            Text("暂无歌手简介")
                .font(.rounded(size: 15))
                .foregroundColor(.asideTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
