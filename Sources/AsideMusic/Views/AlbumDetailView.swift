// AlbumDetailView.swift
// 专辑详情页

import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
class AlbumDetailViewModel: ObservableObject {
    @Published var albumInfo: AlbumInfo?
    @Published var songs: [Song] = []
    @Published var isLoading = true
    
    private var cancellables = Set<AnyCancellable>()
    
    func fetchAlbum(id: Int) {
        guard isLoading else { return }
        
        APIService.shared.fetchAlbumDetail(id: id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    AppLogger.error("专辑详情加载失败: \(error)")
                }
            }, receiveValue: { [weak self] result in
                self?.albumInfo = result.album
                self?.songs = result.songs
            })
            .store(in: &cancellables)
    }
}

// MARK: - View

struct AlbumDetailView: View {
    let albumId: Int
    let albumName: String?
    let albumCoverUrl: URL?
    
    @StateObject private var viewModel = AlbumDetailViewModel()
    @ObservedObject var playerManager = PlayerManager.shared
    
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    
    private struct Theme {
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
            viewModel.fetchAlbum(id: albumId)
        }
    }
    
    // MARK: - 头部
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AsideBackButton()
                
                Spacer()
                
                if let size = viewModel.albumInfo?.size, size > 0 {
                    Text(String(format: NSLocalizedString("songs_count_format", comment: ""), size))
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
                // 封面：优先用详情接口返回的，回退到传入的
                CachedAsyncImage(url: viewModel.albumInfo?.coverUrl?.sized(400) ?? albumCoverUrl?.sized(400)) {
                    Color.gray.opacity(0.1)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
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
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, DeviceLayout.headerTopPadding)
    }
    
    // MARK: - 歌曲列表
    
    private var songListSection: some View {
        LazyVStack(spacing: 0) {
            if viewModel.isLoading {
                AsideLoadingView(text: "LOADING TRACKS")
            } else if viewModel.songs.isEmpty {
                VStack(spacing: 14) {
                    AsideIcon(icon: .musicNoteList, size: 40, color: Theme.secondaryText.opacity(0.3))
                    Text("暂无歌曲")
                        .font(.rounded(size: 15))
                        .foregroundColor(Theme.secondaryText)
                }
                .padding(.top, 40)
            } else {
                // 专辑简介（如果有）
                if let desc = viewModel.albumInfo?.description, !desc.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(desc)
                            .font(.rounded(size: 13))
                            .foregroundColor(Theme.secondaryText)
                            .lineLimit(3)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                
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
                        PlayerManager.shared.play(song: song, in: viewModel.songs)
                    }
                }
                
                NoMoreDataView()
                Color.clear.frame(height: 100)
            }
        }
    }
}
