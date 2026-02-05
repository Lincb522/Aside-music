import SwiftUI
import Combine

// MARK: - ViewModel
class PlaylistDetailViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var playlistDetail: Playlist?
    @Published var isLoading = true
    @Published var isLoadingMore = false
    @Published var hasMore = true
    
    private var cancellables = Set<AnyCancellable>()
    private var currentOffset = 0
    private let limit = 30
    private var playlistId: Int?
    private var isFirstPageLoaded = false
    
    func fetchSongs(playlistId: Int) {
        self.playlistId = playlistId
        isLoading = true
        isLoadingMore = false
        isFirstPageLoaded = false
        currentOffset = 0
        songs = []
        hasMore = true
        
        // Metadata: Stale-While-Revalidate
        APIService.shared.fetchPlaylistDetail(id: playlistId, cachePolicy: .staleWhileRevalidate, ttl: 3600)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] detail in
                self?.playlistDetail = detail
            })
            .store(in: &cancellables)
        
        loadMore()
    }
    
    func loadMore() {
        guard let id = playlistId, !isLoadingMore, hasMore else { return }
        
        // 只有在首页加载完成后，加载更多时才显示 isLoadingMore
        if isFirstPageLoaded && !songs.isEmpty {
            isLoadingMore = true
        }
        
        // For first page, use cache-then-network. For others, network only.
        let policy: APIService.CachePolicy = (currentOffset == 0) ? .staleWhileRevalidate : .networkOnly
        let ttl: TimeInterval? = (currentOffset == 0) ? 3600 : nil
        
        APIService.shared.fetchPlaylistTracks(id: id, limit: limit, offset: currentOffset, cachePolicy: policy, ttl: ttl)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                // 首页加载完成后才关闭 isLoading
                if self.currentOffset == 0 || !self.isFirstPageLoaded {
                    self.isLoading = false
                    self.isFirstPageLoaded = true
                }
                self.isLoadingMore = false
                if case .failure(let error) = completion {
                    print("[PlaylistDetail] Failed to load tracks: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] fetchedSongs in
                guard let self = self else { return }
                
                // If offset is 0, we are refreshing the list (or loading first page)
                if self.currentOffset == 0 {
                    self.songs = fetchedSongs
                    self.currentOffset = fetchedSongs.count
                    self.isFirstPageLoaded = true
                    self.isLoading = false
                } else {
                    // Filter duplicates before appending
                    let newSongs = fetchedSongs.filter { newSong in
                        !self.songs.contains(where: { $0.id == newSong.id })
                    }
                    self.songs.append(contentsOf: newSongs)
                    self.currentOffset += fetchedSongs.count
                }
                
                if fetchedSongs.isEmpty || fetchedSongs.count < self.limit {
                    self.hasMore = false
                } else {
                    self.hasMore = true 
                }
            })
            .store(in: &cancellables)
    }
    
    func setSongs(_ songs: [Song]) {
        self.songs = songs
        self.isLoading = false
        self.isFirstPageLoaded = true
        self.hasMore = false
    }
    
    // Helper to get current full list for context
    func getCurrentList() -> [Song] {
        return songs
    }
}

// MARK: - Main View
struct PlaylistDetailView: View {
    let playlist: Playlist
    let initialSongs: [Song]?
    
    @StateObject private var viewModel = PlaylistDetailViewModel()
    
    // Subscribe to PlayerManager updates
    @ObservedObject var playerManager = PlayerManager.shared
    
    // Navigation States
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    
    // Scroll State
    @State private var scrollOffset: CGFloat = 0
    
    init(playlist: Playlist, songs: [Song]? = nil) {
        self.playlist = playlist
        self.initialSongs = songs
    }
    
    // Colors
    struct Theme {
        static let cream = Color.clear // Was Color.white
        static let milk = Color.white.opacity(0.8) // Was Color.white
        static let accent = Color.black
        static let text = Color.black
        static let secondaryText = Color.gray
        static let softShadow = Color.clear
    }

    var body: some View {
        ZStack {
            // Background
            AsideBackground()
            
            VStack(spacing: 0) {
                // Fixed Header
                cleanHeader
                
                // Scrollable Song List
                ScrollView(showsIndicators: false) {
                    songListSection
                        .padding(.bottom, 100) // For MiniPlayer
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if let songs = initialSongs {
                viewModel.setSongs(songs)
            } else {
                viewModel.fetchSongs(playlistId: playlist.id)
            }
        }
    }
    
    // MARK: - Components
    
    // Completely redesigned header to match DailyRecommendView & ArtistDetailView
    private var cleanHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Back Button Row
            HStack {
                AsideBackButton()
                
                Spacer()
                
                // Track Count Badge
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
            
            // Main Content Row (Horizontal Layout)
            HStack(alignment: .top, spacing: 16) {
                // Left: Cover Art
                CachedAsyncImage(url: playlist.coverUrl?.sized(400)) {
                    Color.gray.opacity(0.1)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // Right: Info & Actions
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(viewModel.playlistDetail?.name ?? playlist.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Subtitle (Creator)
                if let creator = viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname {
                    Text(String(format: NSLocalizedString("created_by_format", comment: ""), creator))
                        .font(.system(size: 13))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)
                }
                
                // DEBUG: Show height info
                // Text("H: \(UIScreen.main.bounds.height) P: \(DeviceLayout.headerTopPadding)")
                //    .font(.caption2)
                //    .foregroundColor(.red)
                
                Spacer().frame(height: 4)
                    
                    // Play All Button (Compact)
                    Button(action: {
                        if let first = viewModel.songs.first {
                            PlayerManager.shared.play(song: first, in: viewModel.songs)
                        }
                    }) {
                        HStack(spacing: 6) {
                            AsideIcon(icon: .play, size: 12, color: .white)
                            Text(LocalizedStringKey("play_now"))
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.accent)
                        .cornerRadius(20)
                        .shadow(color: Theme.accent.opacity(0.2), radius: 5, x: 0, y: 2)
                    }
                    .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
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
                
                Color.clear.frame(height: 100)
            }
        }
    }
}

// MARK: - Utilities
// extension Color { ... }

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Appended content removed as user will manually add the file to project

