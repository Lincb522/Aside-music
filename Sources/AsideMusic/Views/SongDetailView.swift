import SwiftUI
import Combine

@MainActor
class SongDetailViewModel: ObservableObject {
    @Published var relatedSongs: [Song] = []
    @Published var isLoading = true
    private var cancellables = Set<AnyCancellable>()
    
    func loadRelatedSongs(artistId: Int) {
        isLoading = true
        APIService.shared.fetchArtistTopSongs(id: artistId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("Error loading related songs: \(error)")
                }
                self?.isLoading = false
            }, receiveValue: { [weak self] songs in
                self?.relatedSongs = songs
            })
            .store(in: &cancellables)
    }
}

struct SongDetailView: View {
    let song: Song
    @StateObject private var viewModel = SongDetailViewModel()
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var playerManager = PlayerManager.shared
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    
    struct Theme {
        static let text = Color.asideTextPrimary
        static let secondaryText = Color.asideTextSecondary
        static let accent = Color.asideIconBackground
    }
    
    var body: some View {
        ZStack {
            AsideBackground()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView(showsIndicators: false) {
                    if !viewModel.relatedSongs.isEmpty {
                        songsListView
                            .padding(.bottom, 100)
                    } else if viewModel.isLoading {
                        AsideLoadingView(text: "LOADING RELATED")
                            .padding(.top, 50)
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
        .onAppear {
            if let artistId = song.artists.first?.id {
                viewModel.loadRelatedSongs(artistId: artistId)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AsideBackButton()
                Spacer()
            }
            
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: song.coverUrl) {
                    Color.gray.opacity(0.3)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .cornerRadius(12)
                .shadow(radius: 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(song.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text)
                        .lineLimit(2)
                    
                    Text(song.artistName)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)
                    
                    if let album = song.album?.name {
                        Text(album)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.secondaryText.opacity(0.8))
                            .lineLimit(1)
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
                        AsideIcon(icon: .play, size: 12, color: .white)
                        Text(LocalizedStringKey("action_play"))
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.accent)
                    .cornerRadius(20)
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
                
                Button(action: {
                    PlayerManager.shared.playNext(song: song)
                }) {
                    AsideIcon(icon: .playNext, size: 14, color: Theme.accent)
                        .padding(8)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .buttonStyle(AsideBouncingButtonStyle())
                
                Button(action: {
                    PlayerManager.shared.addToQueue(song: song)
                }) {
                    AsideIcon(icon: .add, size: 14, color: Theme.accent)
                        .padding(8)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
        }
        .padding(24)
        .padding(.top, DeviceLayout.headerTopPadding - 24)
        .background(.ultraThinMaterial)
    }
    
    private var songsListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(format: NSLocalizedString("more_by_artist", comment: ""), song.artistName))
                .font(.headline)
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
                    })
                        .asButton {
                            PlayerManager.shared.play(song: relatedSong, in: viewModel.relatedSongs)
                        }
                }
            }
        }
    }
}
