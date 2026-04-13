// NewSongExpressView.swift
// 新歌速递页面 — 全新卡片式设计

import SwiftUI

struct NewSongExpressView: View {
    @State private var viewModel = NewSongExpressViewModel()
    @ObservedObject private var playerManager = PlayerManager.shared
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    @State private var isSelectMode = false
    @State private var selectedSongIds: Set<Int> = []
    @State private var showBatchAddToPlaylist = false
    @State private var newSongSearch = ""
    @State private var isNewSongSearching = false
    
    var body: some View {
        ZStack {
            MonologueBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                typeSelector
                    .padding(.top, 8)
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.monologueTextSecondary)
                    Spacer()
                } else if viewModel.songs.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // 完整列表
                            fullListSection
                        }
                        .padding(.bottom, 120)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle(LocalizedStringKey("new_song_express"))
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let shuffled = viewModel.songs.shuffled()
                    if let first = shuffled.first {
                        playerManager.playReplacingContext(song: first, in: shuffled)
                    }
                } label: {
                    MonologueIcon(icon: .shuffle, size: 16)
                }
                .opacity(viewModel.songs.isEmpty ? 0.3 : 1)
                .disabled(viewModel.songs.isEmpty)
            }
        }
        .navigationDestination(isPresented: $showArtistDetail) {
            if let id = selectedArtistId { ArtistDetailView(artistId: id) }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail { SongDetailView(song: song) }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let id = selectedAlbumId { AlbumDetailView(albumId: id, albumName: nil, albumCoverUrl: nil) }
        }
        .onAppear {
            if viewModel.songs.isEmpty {
                viewModel.loadSongs(type: 0)
            }
        }
    }
    
    // MARK: - 语种选择
    
    private var typeSelector: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(NewSongExpressViewModel.songTypes) { type in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.loadSongs(type: type.id)
                        }
                    } label: {
                        let isSelected = viewModel.selectedType == type.id
                        Text(LocalizedStringKey(type.nameKey))
                            .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                            .foregroundColor(isSelected ? .monologueIconForeground : .monologueTextSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isSelected ? Color.monologueAccent : Color.clear)
                            )
                            .clipShape(Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
    }
    
    // MARK: - 空状态
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            MonologueIcon(icon: .musicNote, size: 40, color: .monologueTextSecondary.opacity(0.3))
            Text(LocalizedStringKey("empty_no_results"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
        }
    }
    
    // MARK: - 完整列表
    
    private var fullListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 播放全部按钮
            HStack {
                Button(action: {
                    if let first = viewModel.songs.first {
                        playerManager.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }) {
                    HStack(spacing: 6) {
                        MonologueIcon(icon: .play, size: 12, color: .monologueTextPrimary)
                        Text(LocalizedStringKey("artist_play_all"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.monologueTextPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.monologueTextPrimary.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                
                Spacer()
                
                Text(String(format: NSLocalizedString("songs_count_format", comment: ""), viewModel.songs.count))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            
            PlaylistSearchBar(
                searchText: $newSongSearch,
                isSearching: $isNewSongSearching,
                isSelectMode: $isSelectMode,
                selectedIds: $selectedSongIds,
                songs: newSongFiltered,
                onBatchQueue: {
                    let selected = newSongFiltered.filter { selectedSongIds.contains($0.id) }
                    SongBatchActionHelper.addToQueue(selected) {
                        isSelectMode = false
                        selectedSongIds.removeAll()
                    }
                },
                onBatchDownload: { newSongBatchDownload() },
                onBatchCollect: { showBatchAddToPlaylist = true }
            )
            
            LazyVStack(spacing: 0) {
                ForEach(Array(newSongFiltered.enumerated()), id: \.element.id) { index, song in
                    SongListRow(
                        song: song,
                        index: index,
                        isSelecting: isSelectMode,
                        isSelected: selectedSongIds.contains(song.id),
                        onArtistTap: { id in
                            selectedArtistId = id
                            showArtistDetail = true
                        },
                        onDetailTap: { s in
                            selectedSongForDetail = s
                            showSongDetail = true
                        },
                        onAlbumTap: { id in
                            selectedAlbumId = id
                            showAlbumDetail = true
                        },
                        onTap: {
                            if isSelectMode {
                                if selectedSongIds.contains(song.id) {
                                    selectedSongIds.remove(song.id)
                                } else {
                                    selectedSongIds.insert(song.id)
                                }
                            } else {
                                playerManager.play(song: song, in: newSongFiltered)
                            }
                        }
                    )
                }
                
                NoMoreDataView()
            }
        }
        .monologueSheet(isPresented: $showBatchAddToPlaylist, preset: .standard){
            BatchAddToPlaylistSheet(songs: newSongFiltered.filter { selectedSongIds.contains($0.id) })
        }
    }
    
    private var newSongFiltered: [Song] { viewModel.songs.filtered(by: newSongSearch) }
    
    private func newSongBatchDownload() {
        let selected = newSongFiltered.filter { selectedSongIds.contains($0.id) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
            }
        }
        AlertManager.shared.show(title: String(localized: "已加入下载"), message: String(localized: "已将 \(selected.count) 首歌曲加入下载队列"), primaryButtonTitle: String(localized: "确定"), primaryAction: {})
        withAnimation { isSelectMode = false; selectedSongIds.removeAll() }
    }
}
