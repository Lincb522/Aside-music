// CloudDiskView.swift
// 我的云盘页面 — 浏览、播放、删除云盘歌曲

import SwiftUI
import Combine

struct CloudDiskView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playerManager = PlayerManager.shared
    
    @State private var songs: [CloudSong] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMore = false
    @State private var totalCount = 0
    @State private var usedSpace = ""
    @State private var totalSpace = ""
    @State private var offset = 0
    @State private var showDeleteConfirm = false
    @State private var songToDelete: CloudSong? = nil
    
    private let pageSize = 30
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                    .padding(.top, DeviceLayout.headerTopPadding)
                
                if isLoading && songs.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(.asideTextSecondary)
                    Spacer()
                } else if songs.isEmpty {
                    emptyState
                } else {
                    songList
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { loadFirstPage() }
        .alert(NSLocalizedString("cloud_delete_title", comment: ""), isPresented: $showDeleteConfirm) {
            Button(NSLocalizedString("cloud_delete_action", comment: ""), role: .destructive) {
                if let song = songToDelete {
                    deleteSong(song)
                }
            }
            Button(NSLocalizedString("alert_cancel", comment: ""), role: .cancel) {
                songToDelete = nil
            }
        } message: {
            Text(String(format: NSLocalizedString("cloud_delete_message", comment: ""), songToDelete?.songName ?? ""))
        }
    }
    
    // MARK: - 顶部栏
    
    private var headerSection: some View {
        HStack {
            AsideBackButton(style: .dismiss)
            
            Spacer()
            
            Text(LocalizedStringKey("cloud_title"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
            
            Spacer()
            
            // 占位，保持标题居中
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - 空状态
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            AsideIcon(icon: .cloud, size: 48, color: .asideTextSecondary.opacity(0.3), lineWidth: 1.4)
            Text(LocalizedStringKey("cloud_empty"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary)
            Spacer()
        }
    }
    
    // MARK: - 歌曲列表
    
    private var songList: some View {
        VStack(spacing: 0) {
            // 统计信息
            HStack {
                Text(String(format: NSLocalizedString("cloud_song_count", comment: ""), totalCount))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
                Spacer()
                if !usedSpace.isEmpty && !totalSpace.isEmpty {
                    Text("\(formatBytes(usedSpace)) / \(formatBytes(totalSpace))")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            
            // 全部播放按钮
            Button {
                let allSongs = songs.map { $0.toSong() }
                if let first = allSongs.first {
                    playerManager.play(song: first, in: allSongs)
                }
            } label: {
                HStack(spacing: 8) {
                    AsideIcon(icon: .play, size: 16, color: .asideIconForeground, lineWidth: 1.6)
                    Text(LocalizedStringKey("cloud_play_all"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.asideIconForeground)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.asideGlassTint)
                .clipShape(Capsule())
                .glassEffect(.regular, in: .capsule)
            }
            .buttonStyle(AsideBouncingButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(songs) { song in
                        cloudSongRow(song)
                            .onAppear {
                                // 加载更多
                                if song.id == songs.last?.id && hasMore && !isLoadingMore {
                                    loadMore()
                                }
                            }
                    }
                    
                    if isLoadingMore {
                        ProgressView()
                            .tint(.asideTextSecondary)
                            .padding(.vertical, 20)
                    }
                }
                .padding(.bottom, 120)
            }
        }
    }
    
    // MARK: - 单行歌曲
    
    private func cloudSongRow(_ song: CloudSong) -> some View {
        let isCurrent = playerManager.currentSong?.id == song.songId
        
        return Button {
            let s = song.toSong()
            let allSongs = songs.map { $0.toSong() }
            playerManager.play(song: s, in: allSongs)
        } label: {
            HStack(spacing: 14) {
                // 封面
                if let coverUrl = song.simpleSong?.coverUrl {
                    CachedAsyncImage(url: coverUrl) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.asideCardBackground)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.asideCardBackground)
                        .frame(width: 48, height: 48)
                        .overlay(
                            AsideIcon(icon: .cloud, size: 20, color: .asideTextSecondary.opacity(0.4), lineWidth: 1.4)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.songName)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(isCurrent ? .asideTextPrimary : .asideTextPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(song.bitrateText)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.asideTextPrimary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.asideTextPrimary, lineWidth: 0.5)
                            )
                        
                        Text("\(song.artist) · \(song.fileSizeText)")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if isCurrent {
                    PlayingVisualizerView(isAnimating: playerManager.isPlaying, color: .asideTextPrimary)
                        .frame(width: 20)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(isCurrent ? Color.asideTextPrimary.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98, opacity: 0.8))
        .contextMenu {
            Button {
                playerManager.playNext(song: song.toSong())
            } label: {
                Label(NSLocalizedString("cloud_play_next", comment: ""), systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            
            Button {
                playerManager.addToQueue(song: song.toSong())
            } label: {
                Label(NSLocalizedString("cloud_add_queue", comment: ""), systemImage: "text.append")
            }
            
            Divider()
            
            Button(role: .destructive) {
                songToDelete = song
                showDeleteConfirm = true
            } label: {
                Label(NSLocalizedString("cloud_delete_from", comment: ""), systemImage: "trash")
            }
        }
    }
    
    // MARK: - 数据加载
    
    private func loadFirstPage() {
        guard songs.isEmpty else { return }
        isLoading = true
        offset = 0
        
        CloudDiskCancellableStore.shared.cancellables.removeAll()
        
        APIService.shared.fetchCloudSongs(limit: pageSize, offset: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    AppLogger.error("加载云盘失败: \(error)")
                }
            }, receiveValue: { response in
                songs = response.data
                totalCount = response.count
                hasMore = response.hasMore
                usedSpace = response.size
                totalSpace = response.maxSize
                offset = response.data.count
            })
            .store(in: &CloudDiskCancellableStore.shared.cancellables)
    }
    
    private func loadMore() {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        
        APIService.shared.fetchCloudSongs(limit: pageSize, offset: offset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isLoadingMore = false
                if case .failure(let error) = completion {
                    AppLogger.error("加载更多云盘歌曲失败: \(error)")
                }
            }, receiveValue: { response in
                songs.append(contentsOf: response.data)
                hasMore = response.hasMore
                offset += response.data.count
            })
            .store(in: &CloudDiskCancellableStore.shared.cancellables)
    }
    
    private func deleteSong(_ song: CloudSong) {
        APIService.shared.deleteCloudSong(ids: [song.songId])
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.error("删除云盘歌曲失败: \(error)")
                }
            }, receiveValue: { response in
                if response.code == 200 {
                    songs.removeAll { $0.songId == song.songId }
                    totalCount = max(totalCount - 1, 0)
                }
                songToDelete = nil
            })
            .store(in: &CloudDiskCancellableStore.shared.cancellables)
    }
    
    // MARK: - 工具方法
    
    /// 将字节字符串格式化为可读大小
    private func formatBytes(_ str: String) -> String {
        guard let bytes = Int64(str) else { return str }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Cancellable 存储

private class CloudDiskCancellableStore: @unchecked Sendable {
    static let shared = CloudDiskCancellableStore()
    var cancellables = Set<AnyCancellable>()
}
