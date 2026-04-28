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
    @State private var songToDelete: CloudSong? = nil
    @State private var isEnrichingMetadata = false
    @State private var pendingMetadataRefresh = false
    @State private var pendingForcedQQRefresh = false
    
    private let pageSize = 30

    private struct Theme {
        static var accent: Color {
            MangaStyle.isActive ? MangaStyle.accentPink : (MujiStyle.isActive ? MujiStyle.clay : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : Color.monologueIconBackground))
        }
        static var accentForeground: Color {
            MangaStyle.isActive ? MangaStyle.ink : (MujiStyle.isActive ? MujiStyle.paper : (NeumorphicStyle.isActive ? Color(light: .white, dark: .black) : Color.monologueIconForeground))
        }
        static var text: Color {
            NeumorphicStyle.isActive ? NeumorphicStyle.ink : Color.monologueTextPrimary
        }
        static var secondaryText: Color {
            NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : Color.monologueTextSecondary
        }
    }
    
    var body: some View {
        ZStack {
            ThemedPageBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if isLoading && songs.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(.monologueTextSecondary)
                    Spacer()
                } else if songs.isEmpty {
                    emptyState
                } else {
                    songList
                }
            }
        }
        .themedNavigationChrome(title: String(localized: "cloud_title"), eyebrow: "CLOUD", icon: .cloud)
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { MonologueIcon(icon: .xmark, size: 16) }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        triggerMetadataEnrichment(forceQQMetadata: true)
                    } label: {
                        Label(
                            NSLocalizedString("cloud_refresh_metadata", comment: ""),
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .disabled(isEnrichingMetadata)
                    
                    if isEnrichingMetadata {
                        Button {} label: {
                            Label(
                                NSLocalizedString("cloud_syncing_metadata", comment: ""),
                                systemImage: "hourglass"
                            )
                        }
                        .disabled(true)
                    }
                } label: {
                    MonologueIcon(icon: .more, size: 16)
                }
            }
        }
        .onAppear { loadFirstPage() }
        
    }
    
    // MARK: - 空状态
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            MonologueIcon(icon: .cloud, size: 48, color: .monologueTextSecondary.opacity(0.3), lineWidth: 1.4)
            Text(LocalizedStringKey("cloud_empty"))
                .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .medium) : .system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Theme.secondaryText)
            Spacer()
        }
    }
    
    // MARK: - 歌曲列表
    
    private var songList: some View {
        VStack(spacing: 0) {
            // 统计信息
            HStack {
                Text(String(format: NSLocalizedString("cloud_song_count", comment: ""), totalCount))
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .system(size: 13, design: .rounded))
                    .foregroundColor(Theme.secondaryText)
                if isEnrichingMetadata {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.monologueTextSecondary)
                        Text(LocalizedStringKey("cloud_syncing_metadata"))
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .system(size: 12, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                }
                Spacer()
                if !usedSpace.isEmpty && !totalSpace.isEmpty {
                    Text("\(formatBytes(usedSpace)) / \(formatBytes(totalSpace))")
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .system(size: 13, design: .rounded))
                        .foregroundColor(Theme.secondaryText)
                }
            }
            .padding(.horizontal, ThemedPageStyle.isActive ? 16 : 24)
            .padding(.vertical, 12)
            .themedOnlyPageSurface(cornerRadius: ThemedPageStyle.compactSurfaceCornerRadius, elevated: false)
            .padding(.horizontal, ThemedPageStyle.horizontalInset)
            
            // 全部播放按钮
            Button {
                let allSongs = songs.map { $0.toSong() }
                if let first = allSongs.first {
                    playerManager.playReplacingContext(song: first, in: allSongs)
                }
            } label: {
                if NeumorphicStyle.isActive {
                    NeumorphicPlayPill(title: String(localized: "cloud_play_all"), tint: NeumorphicStyle.accent)
                } else {
                    HStack(spacing: 8) {
                        MonologueIcon(icon: .play, size: 16, color: Theme.accentForeground, lineWidth: 1.6)
                        Text(LocalizedStringKey("cloud_play_all"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.accentForeground)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.accent)
                    .clipShape(Capsule())
                    .overlay {
                        if MangaStyle.isActive {
                            Capsule()
                                .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                        }
                    }
                    .shadow(color: Theme.accent.opacity(0.18), radius: 6, x: 0, y: 2)
                }
            }
            .buttonStyle(MonologueBouncingButtonStyle())
            .padding(.horizontal, ThemedPageStyle.isActive ? DeviceLayout.viewHorizontalPadding : 24)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView {
                LazyVStack(spacing: ThemedPageStyle.listSpacing) {
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
                            .tint(.monologueTextSecondary)
                            .padding(.vertical, 20)
                    }
                }
                .padding(.horizontal, ThemedPageStyle.horizontalInset)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
    }
    
    // MARK: - 单行歌曲
    
    private func cloudSongRow(_ song: CloudSong) -> some View {
        let isCurrent = playerManager.currentSong?.id == song.songId
        
        return Button {
            playCloudSong(song)
        } label: {
            HStack(spacing: 14) {
                // 封面
                if let coverUrl = song.simpleSong?.coverUrl {
                    CachedAsyncImage(url: coverUrl) {
                        RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                            .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: DeviceLayout.listRowCoverSmall, height: DeviceLayout.listRowCoverSmall)
                    .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                    .overlay(coverStroke)
                } else {
                    RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                        .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
                        .frame(width: DeviceLayout.listRowCoverSmall, height: DeviceLayout.listRowCoverSmall)
                        .overlay(
                            MonologueIcon(icon: .cloud, size: 20, color: Theme.secondaryText.opacity(0.5), lineWidth: 1.4)
                        )
                        .overlay(coverStroke)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.songName)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .semibold) : .system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(isCurrent && NeumorphicStyle.isActive ? NeumorphicStyle.accent : Theme.text)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        if NeumorphicStyle.isActive {
                            NeumorphicPill(text: song.bitrateText, tint: Theme.accent, selected: isCurrent, compact: true)
                        } else {
                            Text(song.bitrateText)
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(Theme.accent)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: MangaStyle.isActive ? 6 : 2)
                                        .stroke(Theme.accent, lineWidth: 0.5)
                                )
                        }
                        
                        Text("\(song.artist) · \(song.fileSizeText)")
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .system(size: 12, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if isCurrent {
                    PlayingVisualizerView(isAnimating: playerManager.isPlaying, color: NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueTextPrimary)
                        .frame(width: 20)
                }
            }
            .padding(.horizontal, ThemedPageStyle.isActive ? 16 : 24)
            .padding(.vertical, 8)
            .background(isCurrent ? Color.monologueTextPrimary.opacity(0.05) : Color.clear)
            .themedOnlyPageSurface(
                cornerRadius: ThemedPageStyle.compactSurfaceCornerRadius,
                elevated: isCurrent,
                mangaTint: isCurrent ? MangaStyle.labelYellow.opacity(0.92) : MangaStyle.bubbleWhite
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98, opacity: 0.8))
        .contextMenu {
            Button {
                addCloudSongToPlayNext(song)
            } label: {
                Label(NSLocalizedString("cloud_play_next", comment: ""), systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            
            Button {
                addCloudSongToQueue(song)
            } label: {
                Label(NSLocalizedString("cloud_add_queue", comment: ""), systemImage: "text.append")
            }
            
            Divider()
            
            Button(role: .destructive) {
                AlertManager.shared.show(
                    title: NSLocalizedString("cloud_delete_title", comment: ""),
                    message: String(format: NSLocalizedString("cloud_delete_message", comment: ""), song.songName),
                    primaryButtonTitle: NSLocalizedString("cloud_delete_action", comment: ""),
                    secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                    primaryAction: { deleteSong(song) }
                )
            } label: {
                Label(NSLocalizedString("cloud_delete_from", comment: ""), systemImage: "trash")
            }
        }
    }

    private var coverRadius: CGFloat {
        NeumorphicStyle.isActive ? 14 : 10
    }

    @ViewBuilder
    private var coverStroke: some View {
        if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.5), lineWidth: 0.7)
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
                triggerMetadataEnrichment(for: response.data)
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
                triggerMetadataEnrichment(for: response.data)
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

    private func playCloudSong(_ cloudSong: CloudSong) {
        Task {
            let resolvedSong = await resolveCloudSongForPlayback(cloudSong)
            await MainActor.run {
                let allSongs = songs.map { $0.songId == resolvedSong.songId ? resolvedSong.toSong() : $0.toSong() }
                playerManager.play(song: resolvedSong.toSong(), in: allSongs)
            }
        }
    }

    private func addCloudSongToPlayNext(_ cloudSong: CloudSong) {
        Task {
            let resolvedSong = await resolveCloudSongForPlayback(cloudSong)
            await MainActor.run {
                playerManager.playNext(song: resolvedSong.toSong())
            }
        }
    }

    private func addCloudSongToQueue(_ cloudSong: CloudSong) {
        Task {
            let resolvedSong = await resolveCloudSongForPlayback(cloudSong)
            await MainActor.run {
                playerManager.addToQueue(song: resolvedSong.toSong())
            }
        }
    }

    private func resolveCloudSongForPlayback(_ cloudSong: CloudSong) async -> CloudSong {
        let song = cloudSong.toSong()
        let needsMetadata = cloudSong.simpleSong == nil
            || song.coverUrl == nil
            || (song.qqMid?.isEmpty ?? true)

        guard needsMetadata else { return cloudSong }

        AppLogger.info("播放前补全云盘歌曲元数据: \(cloudSong.songName) - \(cloudSong.artist)")
        let enrichedSongs = await APIService.shared.enrichCloudSongsMetadata([cloudSong], forceQQMetadata: true)
        guard let resolvedSong = enrichedSongs.first else { return cloudSong }

        await MainActor.run {
            applyEnrichedSongs([resolvedSong], scopedTo: [cloudSong.songId])
        }

        return resolvedSong
    }

    private func triggerMetadataEnrichment(for targetSongs: [CloudSong]? = nil, forceQQMetadata: Bool = false) {
        let songsToEnrich = targetSongs ?? songs
        guard !songsToEnrich.isEmpty else { return }

        if isEnrichingMetadata {
            pendingMetadataRefresh = true
            pendingForcedQQRefresh = pendingForcedQQRefresh || forceQQMetadata
            AppLogger.info("云盘元数据补全已排队，等待当前任务结束")
            return
        }

        isEnrichingMetadata = true
        pendingMetadataRefresh = false
        pendingForcedQQRefresh = false
        let scopedIDs = Set(songsToEnrich.map(\.songId))
        AppLogger.info("开始补全云盘元数据: \(songsToEnrich.count) 首，forceQQ=\(forceQQMetadata)")

        Task {
            let enrichedSongs = await APIService.shared.enrichCloudSongsMetadata(
                songsToEnrich,
                forceQQMetadata: forceQQMetadata
            )
            await MainActor.run {
                applyEnrichedSongs(enrichedSongs, scopedTo: scopedIDs)
                isEnrichingMetadata = false
                AppLogger.info("云盘元数据补全完成: \(enrichedSongs.count) 首")

                if pendingMetadataRefresh {
                    let shouldForceQQRefresh = pendingForcedQQRefresh
                    pendingMetadataRefresh = false
                    pendingForcedQQRefresh = false
                    triggerMetadataEnrichment(forceQQMetadata: shouldForceQQRefresh)
                }
            }
        }
    }

    private func applyEnrichedSongs(_ enrichedSongs: [CloudSong], scopedTo scopedIDs: Set<Int>) {
        guard !enrichedSongs.isEmpty else { return }

        let enrichedByID = Dictionary(uniqueKeysWithValues: enrichedSongs.map { ($0.songId, $0) })
        songs = songs.map { existingSong in
            guard scopedIDs.contains(existingSong.songId),
                  let enrichedSong = enrichedByID[existingSong.songId] else {
                return existingSong
            }
            return enrichedSong
        }

        syncPlayerMetadataIfNeeded(using: enrichedByID)
    }

    private func syncPlayerMetadataIfNeeded(using enrichedByID: [Int: CloudSong]) {
        let enrichedSongs = enrichedByID.mapValues { $0.toSong() }
        playerManager.context = playerManager.context.map { enrichedSongs[$0.id] ?? $0 }
        playerManager.shuffledContext = playerManager.shuffledContext.map { enrichedSongs[$0.id] ?? $0 }

        guard let currentSong = playerManager.currentSong,
              let enrichedCurrentSong = enrichedSongs[currentSong.id] else { return }

        let needsCover = currentSong.coverUrl == nil && enrichedCurrentSong.coverUrl != nil
        let needsQQMid = (currentSong.qqMid?.isEmpty ?? true) && !(enrichedCurrentSong.qqMid?.isEmpty ?? true)
        let needsName = currentSong.name.isEmpty && !enrichedCurrentSong.name.isEmpty
        let needsArtist = currentSong.artistName.isEmpty && !enrichedCurrentSong.artistName.isEmpty
        let needsLyricsRetry = !LyricViewModel.shared.hasLyrics

        guard needsCover || needsQQMid || needsName || needsArtist || needsLyricsRetry else { return }

        if needsCover || needsQQMid || needsName || needsArtist {
            playerManager.currentSong = enrichedCurrentSong
            playerManager.loadSongExtras(for: enrichedCurrentSong)
            playerManager.updateNowPlayingArtwork(for: enrichedCurrentSong)
            playerManager.syncWidgetState()
        }

        playerManager.fetchLyricsForSong(enrichedCurrentSong)
    }
}

// MARK: - Cancellable 存储

private class CloudDiskCancellableStore: @unchecked Sendable {
    static let shared = CloudDiskCancellableStore()
    var cancellables = Set<AnyCancellable>()
}
