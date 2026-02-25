import SwiftUI
import Combine

/// 添加歌曲到本地歌单的选择器
struct AddToPlaylistSheet: View {
    let song: Song
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = LocalPlaylistManager.shared
    @State private var showCreateNew = false
    @State private var newPlaylistName = ""
    @State private var playlistToDelete: LocalPlaylist?
    @State private var showDeleteAlert = false
    
    // 网易云歌单
    @State private var neteaseUserPlaylists: [Playlist] = []
    @State private var isLoadingNetease = false
    @State private var showCreateNetease = false
    @State private var newNeteasePlaylistName = ""
    @State private var isNeteasePrivate = false
    
    typealias Theme = PlaylistDetailView.Theme
    
    var body: some View {
        NavigationStack {
            ZStack {
                AsideBackground().ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // 歌曲信息
                        HStack(spacing: 12) {
                            CachedAsyncImage(url: song.coverUrl?.sized(200)) {
                                RoundedRectangle(cornerRadius: 8).fill(Color.asideGlassTint).glassEffect(.regular, in: .rect(cornerRadius: 8))
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
                            Color.clear // glassEffect applied via modifier
                        )

                        // 本地歌单区域
                        localPlaylistSection
                        
                        // 网易云歌单区域（仅非 QQ 音乐歌曲显示）
                        if !song.isQQMusic {
                            neteasePlaylistSection
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(NSLocalizedString("add_to_playlist_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("alert_cancel", comment: "")) { dismiss() }
                }
            }
            .alert(NSLocalizedString("add_to_playlist_create", comment: ""), isPresented: $showCreateNew) {
                TextField(NSLocalizedString("add_to_playlist_name", comment: ""), text: $newPlaylistName)
                Button(NSLocalizedString("alert_cancel", comment: ""), role: .cancel) { newPlaylistName = "" }
                Button(NSLocalizedString("lib_create", comment: "")) {
                    guard !newPlaylistName.isEmpty else { return }
                    let newPlaylist = manager.createPlaylist(name: newPlaylistName)
                    manager.addSong(song, to: newPlaylist)
                    newPlaylistName = ""
                    dismiss()
                }
            }
            .alert(NSLocalizedString("create_netease_playlist", comment: ""), isPresented: $showCreateNetease) {
                TextField(NSLocalizedString("create_netease_playlist_name", comment: ""), text: $newNeteasePlaylistName)
                Button(NSLocalizedString("alert_cancel", comment: ""), role: .cancel) { newNeteasePlaylistName = "" }
                Button(NSLocalizedString("lib_create", comment: "")) {
                    guard !newNeteasePlaylistName.isEmpty else { return }
                    createNeteasePlaylist(name: newNeteasePlaylistName)
                    newNeteasePlaylistName = ""
                }
            }
            .onAppear {
                if !song.isQQMusic {
                    loadNeteaseUserPlaylists()
                }
            }
        }
    }
    
    // MARK: - 本地歌单区域
    
    private var localPlaylistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("local_playlist_section"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.asideTextSecondary)
                .padding(.leading, 4)
            
            // 新建本地歌单
            Button(action: { showCreateNew = true }) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.asideIconBackground)
                            .frame(width: 44, height: 44)
                        AsideIcon(icon: .add, size: 18, color: .asideIconForeground)
                    }
                    Text(LocalizedStringKey("add_to_playlist_new"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    Spacer()
                }
                .padding(12)
                .background(
                    Color.clear // glassEffect applied via modifier
                )
            }
            .buttonStyle(AsideBouncingButtonStyle())
            .contentShape(RoundedRectangle(cornerRadius: 14))
            
            // 本地歌单列表
            ForEach(manager.playlists, id: \.id) { playlist in
                let contains = playlist.containsSong(id: song.id)
                Button(action: {
                    if !contains {
                        manager.addSong(song, to: playlist)
                        dismiss()
                    }
                }) {
                    HStack(spacing: 12) {
                        Group {
                            if let url = playlist.displayCoverUrl {
                                CachedAsyncImage(url: url.sized(200)) { playlistPlaceholder }
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
                        Color.clear // glassEffect applied via modifier
                    )
                    .opacity(contains ? 0.6 : 1)
                }
                .buttonStyle(AsideBouncingButtonStyle())
                .contentShape(RoundedRectangle(cornerRadius: 14))
                .disabled(contains)
            }
        }
    }
    
    // MARK: - 网易云歌单区域
    
    private var neteasePlaylistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("netease_playlist_section"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.asideTextSecondary)
                .padding(.leading, 4)
            
            // 创建网易云歌单
            Button(action: { showCreateNetease = true }) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.asideIconBackground)
                            .frame(width: 44, height: 44)
                        AsideIcon(icon: .add, size: 18, color: .asideIconForeground)
                    }
                    Text(LocalizedStringKey("create_netease_playlist"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    Spacer()
                }
                .padding(12)
                .background(
                    Color.clear // glassEffect applied via modifier
                )
            }
            .buttonStyle(AsideBouncingButtonStyle())
            .contentShape(RoundedRectangle(cornerRadius: 14))
            
            if isLoadingNetease {
                HStack {
                    Spacer()
                    ProgressView().tint(.asideTextSecondary)
                    Spacer()
                }
                .padding(.vertical, 12)
            } else {
                // 只显示用户自己创建的歌单
                ForEach(neteaseUserPlaylists) { playlist in
                    Button(action: {
                        addToNeteasePlaylist(pid: playlist.id)
                    }) {
                        HStack(spacing: 12) {
                            CachedAsyncImage(url: playlist.coverUrl?.sized(200)) {
                                neteasePlaylistPlaceholder
                            }
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .cornerRadius(10)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(.asideTextPrimary)
                                    .lineLimit(1)
                                if let count = playlist.trackCount {
                                    Text(String(format: NSLocalizedString("songs_count_format", comment: ""), count))
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundColor(.asideTextSecondary)
                                }
                            }
                            Spacer()
                            AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary.opacity(0.5))
                        }
                        .padding(12)
                        .background(
                            Color.clear // glassEffect applied via modifier
                        )
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }
    
    // MARK: - 网易云歌单操作
    
    private func loadNeteaseUserPlaylists() {
        guard let uid = APIService.shared.currentUserId else { return }
        isLoadingNetease = true
        AddToPlaylistCancellableStore.shared.cancellables.removeAll()
        
        APIService.shared.fetchUserPlaylists(uid: uid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in
                isLoadingNetease = false
            }, receiveValue: { playlists in
                // 只保留用户自己创建的歌单
                neteaseUserPlaylists = playlists.filter { $0.creator?.userId == uid }
            })
            .store(in: &AddToPlaylistCancellableStore.shared.cancellables)
    }
    
    private func createNeteasePlaylist(name: String) {
        APIService.shared.createPlaylist(name: name, privacy: isNeteasePrivate ? 10 : 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.error("创建网易云歌单失败: \(error)")
                }
            }, receiveValue: { playlist in
                if let playlist = playlist {
                    // 创建成功后添加歌曲
                    addToNeteasePlaylist(pid: playlist.id)
                }
            })
            .store(in: &AddToPlaylistCancellableStore.shared.cancellables)
    }
    
    private func addToNeteasePlaylist(pid: Int) {
        APIService.shared.modifyPlaylistTracks(op: "add", pid: pid, trackIds: [song.id])
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.error("添加到网易云歌单失败: \(error)")
                }
            }, receiveValue: { response in
                if response.code == 200 {
                    dismiss()
                }
            })
            .store(in: &AddToPlaylistCancellableStore.shared.cancellables)
    }
    
    private var playlistPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.asideGlassTint)
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
            AsideIcon(icon: .musicNoteList, size: 18, color: .asideTextSecondary.opacity(0.4))
        }
    }
    
    private var neteasePlaylistPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.asideGlassTint)
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
            AsideIcon(icon: .cloud, size: 18, color: .asideTextSecondary.opacity(0.4))
        }
    }
}

private class AddToPlaylistCancellableStore: @unchecked Sendable {
    static let shared = AddToPlaylistCancellableStore()
    var cancellables = Set<AnyCancellable>()
}
