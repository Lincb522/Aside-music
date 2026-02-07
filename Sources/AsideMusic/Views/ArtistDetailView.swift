import SwiftUI
import Combine

class ArtistDetailViewModel: ObservableObject {
    @Published var artist: ArtistInfo?
    @Published var songs: [Song] = []
    @Published var isLoading = true
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
                    print("Error loading artist data: \(error)")
                }
                self?.isLoading = false
            }, receiveValue: { [weak self] (artist, songs) in
                self?.artist = artist
                self?.songs = songs
            })
            .store(in: &cancellables)
    }
}

struct ArtistDetailView: View {
    let artistId: Int
    @StateObject private var viewModel = ArtistDetailViewModel()
    @ObservedObject var playerManager = PlayerManager.shared
    
    @State private var showFullDescription = false
    
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
        .onAppear {
            viewModel.loadData(artistId: artistId)
        }
        .sheet(isPresented: $showFullDescription) {
            if let artist = viewModel.artist {
                VStack(alignment: .leading, spacing: 16) {
                    Text(LocalizedStringKey("artist_details"))
                        .font(.headline)
                        .padding(.top)
                    
                    ScrollView {
                        Text(artist.briefDesc ?? NSLocalizedString("no_description", comment: ""))
                            .font(.body)
                            .foregroundColor(Theme.text)
                            .padding()
                    }
                }
                .padding()
                .presentationDetents([.medium, .large])
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
    
    private var songsListView: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.songs.enumerated()), id: \.element.id) { index, song in
                SongListRow(song: song, index: index)
                    .asButton {
                        PlayerManager.shared.play(song: song, in: viewModel.songs)
                    }
            }
        }
        .padding(.vertical, 10)
    }
    

}
