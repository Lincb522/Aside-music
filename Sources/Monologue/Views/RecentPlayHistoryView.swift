import SwiftUI

/// 最近播放 - 完整列表页
struct RecentPlayHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    @ObservedObject private var playerManager = PlayerManager.shared
    
    let songs: [Song]
    
    @State private var isSelectMode = false
    @State private var selectedSongIds: Set<Int> = []
    @State private var showBatchAddToPlaylist = false
    @State private var recentSearch = ""
    @State private var isRecentSearching = false
    
    private var recentFiltered: [Song] { songs.filtered(by: recentSearch) }
    
    var body: some View {
        ZStack {
            MonologueBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        PlaylistSearchBar(
                            searchText: $recentSearch,
                            isSearching: $isRecentSearching,
                            isSelectMode: $isSelectMode,
                            selectedIds: $selectedSongIds,
                            songs: recentFiltered,
                            onBatchQueue: {
                                let selected = recentFiltered.filter { selectedSongIds.contains($0.id) }
                                SongBatchActionHelper.addToQueue(selected) {
                                    isSelectMode = false
                                    selectedSongIds.removeAll()
                                }
                            },
                            onBatchDownload: { recentBatchDownload() },
                            onBatchCollect: { showBatchAddToPlaylist = true }
                        )
                        
                        LazyVStack(spacing: 0) {
                            ForEach(Array(recentFiltered.enumerated()), id: \.element.id) { index, song in
                                SongListRow(
                                    song: song,
                                    index: index,
                                    isSelecting: isSelectMode,
                                    isSelected: selectedSongIds.contains(song.id),
                                    onArtistTap: nil,
                                    onDetailTap: nil,
                                    onAlbumTap: nil,
                                    onTap: {
                                        if isSelectMode {
                                            if selectedSongIds.contains(song.id) {
                                                selectedSongIds.remove(song.id)
                                            } else {
                                                selectedSongIds.insert(song.id)
                                            }
                                        } else {
                                            playerManager.play(song: song, in: recentFiltered)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    Color.clear.frame(height: 120)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle(LocalizedStringKey("profile_recently_played"))
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let first = songs.first {
                        playerManager.playReplacingContext(song: first, in: songs)
                    }
                } label: {
                    HStack(spacing: 6) {
                        MonologueIcon(icon: .play, size: 12, color: .monologueTextPrimary)
                        Text(LocalizedStringKey("artist_play_all"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.monologueTextPrimary)
                    }
                }
                .disabled(songs.isEmpty)
            }
        }
        .monologueSheet(isPresented: $showBatchAddToPlaylist, preset: .standard){
            BatchAddToPlaylistSheet(songs: recentFiltered.filter { selectedSongIds.contains($0.id) })
        }
    }
    
    private func recentBatchDownload() {
        let selected = recentFiltered.filter { selectedSongIds.contains($0.id) }
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
