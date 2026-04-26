#if os(macOS)
import SwiftUI

struct MacLibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab = 0
    private let tabs = [
        (String(localized: "我的歌单"), "music.note.list"),
        (String(localized: "发现"), "sparkles"),
        (String(localized: "歌手"), "person.2.fill"),
        (String(localized: "排行榜"), "chart.bar.fill"),
    ]

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            ZStack {
                ThemedPageBackground().ignoresSafeArea()

                VStack(spacing: 0) {
                    macLibraryHeader
                    macLibraryContent
                }
            }
            .navigationDestination(for: LibraryViewModel.NavigationDestination.self) { destination in
                switch destination {
                case .playlist(let playlist):
                    PlaylistDetailView(playlist: playlist)
                case .artist(let id):
                    ArtistDetailView(artistId: id)
                case .artistInfo(let artist):
                    if artist.source == .qqmusic, let mid = artist.qqMid {
                        QQMusicDetailView(detailType: .artist(
                            mid: mid, name: artist.name,
                            coverUrl: artist.picUrl ?? artist.img1v1Url
                        ))
                    } else {
                        ArtistDetailView(artistId: artist.id)
                    }
                case .qqArtist(let mid, let name, let coverUrl):
                    QQMusicDetailView(detailType: .artist(mid: mid, name: name, coverUrl: coverUrl))
                case .radioDetail(let id):
                    RadioDetailView(radioId: id)
                case .localPlaylist(let id):
                    LocalPlaylistDetailView(playlistId: id)
                }
            }
        }
    }

    // MARK: - Header

    private var macLibraryHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Text("音乐库")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()
            }

            HStack(spacing: 4) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { idx, tab in
                    MacTabPill(
                        title: tab.0,
                        icon: tab.1,
                        isActive: selectedTab == idx
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedTab = idx
                            viewModel.currentTab = LibraryViewModel.LibraryTab.allCases[idx]
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Content

    @ViewBuilder
    private var macLibraryContent: some View {
        ScrollView {
            switch selectedTab {
            case 0: macMyPlaylists
            case 1: macDiscoverGrid
            case 2: macArtistGrid
            case 3: macChartsGrid
            default: EmptyView()
            }
        }
        .scrollIndicators(.hidden)
    }

    private var macMyPlaylists: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 5), spacing: 16) {
            ForEach(viewModel.userPlaylists) { playlist in
                MacPlaylistCard(playlist: playlist) {
                    viewModel.navigationPath.append(
                        LibraryViewModel.NavigationDestination.playlist(playlist)
                    )
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 80)
        .onAppear {
            if viewModel.userPlaylists.isEmpty {
                viewModel.fetchPlaylists()
            }
        }
    }

    private var macDiscoverGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 5), spacing: 16) {
            ForEach(viewModel.squarePlaylists) { playlist in
                MacPlaylistCard(playlist: playlist) {
                    viewModel.navigationPath.append(
                        LibraryViewModel.NavigationDestination.playlist(playlist)
                    )
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 80)
        .onAppear {
            if viewModel.squarePlaylists.isEmpty {
                viewModel.fetchSquareData()
            }
        }
    }

    private var macArtistGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 6), spacing: 16) {
            ForEach(viewModel.topArtists) { artist in
                MacArtistCard(artist: artist) {
                    viewModel.navigationPath.append(
                        LibraryViewModel.NavigationDestination.artist(artist.id)
                    )
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 80)
        .onAppear {
            if viewModel.topArtists.isEmpty {
                viewModel.fetchArtistData()
            }
        }
    }

    private var macChartsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
            ForEach(viewModel.topLists) { topList in
                let playlist = Playlist(
                    id: topList.id, name: topList.name,
                    coverImgUrl: topList.coverImgUrl, picUrl: nil,
                    trackCount: nil, playCount: nil,
                    subscribedCount: nil, shareCount: nil, commentCount: nil,
                    creator: nil, description: nil, tags: nil,
                    source: nil, isTopList: true
                )
                MacPlaylistCard(playlist: playlist) {
                    viewModel.navigationPath.append(
                        LibraryViewModel.NavigationDestination.playlist(playlist)
                    )
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 80)
        .onAppear {
            if viewModel.topLists.isEmpty {
                viewModel.fetchTopLists()
            }
        }
    }
}

// MARK: - Tab Pill

struct MacTabPill: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isActive ? (colorScheme == .dark ? .black : .white) : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isActive ? Color.primary : (isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04)))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Artist Card

struct MacArtistCard: View {
    let artist: ArtistInfo
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                CachedAsyncImage(url: URL(string: artist.picUrl ?? "")) {
                    Circle().fill(Color.primary.opacity(0.06))
                }
                .aspectRatio(1, contentMode: .fill)
                .clipShape(Circle())
                .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 10 : 4, y: isHovered ? 4 : 2)
                .scaleEffect(isHovered ? 1.05 : 1.0)

                Text(artist.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
#endif
