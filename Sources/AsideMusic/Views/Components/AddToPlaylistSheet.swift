import SwiftUI

/// 添加歌曲到本地歌单的选择器
struct AddToPlaylistSheet: View {
    let song: Song
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = LocalPlaylistManager.shared
    @State private var showCreateNew = false
    @State private var newPlaylistName = ""
    
    typealias Theme = PlaylistDetailView.Theme
    
    var body: some View {
        NavigationStack {
            ZStack {
                AsideBackground().ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // 歌曲信息
                        HStack(spacing: 12) {
                            CachedAsyncImage(url: song.coverUrl?.sized(200)) {
                                RoundedRectangle(cornerRadius: 8).fill(Color.asideCardBackground)
                            }
                            .frame(width: 48, height: 48)
                            .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(song.name)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(.asideTextPrimary)
                                    .lineLimit(1)
                                Text(song.artistName)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(.asideTextSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.asideGlassOverlay))
                        )

                        // 新建歌单
                        Button(action: { showCreateNew = true }) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.asideIconBackground)
                                        .frame(width: 44, height: 44)
                                    AsideIcon(icon: .add, size: 18, color: .asideIconForeground)
                                }
                                Text("新建歌单")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(.asideTextPrimary)
                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.asideGlassOverlay))
                            )
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                        
                        // 歌单列表
                        ForEach(manager.playlists, id: \.id) { playlist in
                            let contains = playlist.containsSong(id: song.id)
                            Button(action: {
                                if !contains {
                                    manager.addSong(song, to: playlist)
                                    dismiss()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    // 封面
                                    Group {
                                        if let url = playlist.displayCoverUrl {
                                            CachedAsyncImage(url: url.sized(200)) {
                                                playlistPlaceholder
                                            }
                                            .aspectRatio(contentMode: .fill)
                                        } else {
                                            playlistPlaceholder
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .cornerRadius(10)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name)
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(.asideTextPrimary)
                                            .lineLimit(1)
                                        Text("\(playlist.trackCount) 首")
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundColor(.asideTextSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if contains {
                                        AsideIcon(icon: .checkmark, size: 14, color: .asideTextSecondary)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.asideGlassOverlay))
                                )
                                .opacity(contains ? 0.6 : 1)
                            }
                            .buttonStyle(AsideBouncingButtonStyle())
                            .contentShape(RoundedRectangle(cornerRadius: 14))
                            .disabled(contains)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("添加到歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("新建歌单", isPresented: $showCreateNew) {
                TextField("歌单名称", text: $newPlaylistName)
                Button("取消", role: .cancel) { newPlaylistName = "" }
                Button("创建") {
                    guard !newPlaylistName.isEmpty else { return }
                    let newPlaylist = manager.createPlaylist(name: newPlaylistName)
                    manager.addSong(song, to: newPlaylist)
                    newPlaylistName = ""
                    dismiss()
                }
            }
        }
    }
    
    private var playlistPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.asideCardBackground)
            AsideIcon(icon: .musicNoteList, size: 18, color: .asideTextSecondary.opacity(0.4))
        }
    }
}
