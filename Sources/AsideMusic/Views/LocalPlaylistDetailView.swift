import SwiftUI

/// 本地歌单详情页
struct LocalPlaylistDetailView: View {
    let playlistId: String
    
    @ObservedObject private var manager = LocalPlaylistManager.shared
    @ObservedObject private var playerManager = PlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showDeleteAlert = false
    
    private var playlist: LocalPlaylist? {
        manager.playlists.first { $0.id == playlistId }
    }
    
    typealias Theme = PlaylistDetailView.Theme
    
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
        .alert("重命名歌单", isPresented: $showRenameAlert) {
            TextField("歌单名称", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("确定") {
                if let p = playlist, !renameText.isEmpty {
                    manager.renamePlaylist(p, name: renameText)
                }
            }
        }
        .alert("删除歌单", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let p = playlist {
                    manager.deletePlaylist(p)
                    dismiss()
                }
            }
        } message: {
            if let p = playlist {
                Text("确定删除「\(p.name)」？此操作不可恢复。")
            }
        }
    }

    // MARK: - Header
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AsideBackButton()
                Spacer()
                if let p = playlist {
                    Text("\(p.trackCount) 首")
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
            
            if let p = playlist {
                HStack(alignment: .top, spacing: 16) {
                    // 封面
                    Group {
                        if let url = p.displayCoverUrl {
                            CachedAsyncImage(url: url.sized(400)) {
                                coverPlaceholder
                            }
                            .aspectRatio(contentMode: .fill)
                        } else {
                            coverPlaceholder
                        }
                    }
                    .frame(width: 120, height: 120)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(p.name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.text)
                            .lineLimit(2)
                        
                        if let desc = p.desc, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 13))
                                .foregroundColor(Theme.secondaryText)
                                .lineLimit(1)
                        }
                        
                        Text("本地歌单")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText.opacity(0.6))
                        
                        Spacer().frame(height: 4)
                        
                        HStack(spacing: 8) {
                            // 播放全部
                            Button(action: {
                                let songs = p.songs
                                if let first = songs.first {
                                    PlayerManager.shared.play(song: first, in: songs)
                                }
                            }) {
                                HStack(spacing: 6) {
                                    AsideIcon(icon: .play, size: 12, color: .asideIconForeground)
                                    Text("播放")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(.asideIconForeground)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Theme.accent)
                                .cornerRadius(20)
                            }
                            .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
                            
                            // 重命名
                            Button(action: {
                                renameText = p.name
                                showRenameAlert = true
                            }) {
                                AsideIcon(icon: .settings, size: 14, color: Theme.secondaryText)
                                    .frame(width: 32, height: 32)
                                    .background(Color.asideCardBackground)
                                    .cornerRadius(16)
                            }
                            .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
                            
                            // 删除歌单
                            Button(action: {
                                showDeleteAlert = true
                            }) {
                                AsideIcon(icon: .trash, size: 14, color: Theme.secondaryText)
                                    .frame(width: 32, height: 32)
                                    .background(Color.asideCardBackground)
                                    .cornerRadius(16)
                            }
                            .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, DeviceLayout.headerTopPadding)
    }
    
    private var coverPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.asideCardBackground)
            AsideIcon(icon: .musicNoteList, size: 36, color: .asideTextSecondary.opacity(0.3))
        }
    }
    
    // MARK: - Song List
    
    private var songListSection: some View {
        LazyVStack(spacing: 0) {
            if let p = playlist {
                let songs = p.songs
                if songs.isEmpty {
                    VStack(spacing: 16) {
                        AsideIcon(icon: .musicNoteList, size: 40, color: .asideTextSecondary.opacity(0.3))
                        Text("还没有歌曲")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
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
                            PlayerManager.shared.play(song: song, in: songs)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation {
                                    manager.removeSong(id: song.id, from: p)
                                }
                            } label: {
                                Label("移除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            
            Color.clear.frame(height: 100)
        }
    }
}
