import SwiftUI

/// 下载管理页面
struct DownloadManageView: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0  // 0=已下载, 1=下载中
    @State private var showDeleteAllAlert = false
    @State private var totalSize: String = "计算中..."
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                    .padding(.top, DeviceLayout.headerTopPadding)
                
                tabBar
                    .padding(.top, 16)
                
                if selectedTab == 0 {
                    downloadedList
                } else {
                    downloadingList
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { updateTotalSize() }
        .alert("确认删除", isPresented: $showDeleteAllAlert) {
            Button("删除全部", role: .destructive) {
                downloadManager.deleteAll()
                updateTotalSize()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除所有已下载的歌曲，此操作不可撤销")
        }
    }
    
    // MARK: - 顶部栏
    private var headerSection: some View {
        HStack {
            AsideBackButton(style: .dismiss)
            
            Spacer()
            
            Text("下载管理")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
            
            Spacer()
            
            // 删除全部按钮
            Button {
                showDeleteAllAlert = true
            } label: {
                AsideIcon(icon: .trash, size: 18, color: .asideTextSecondary, lineWidth: 1.4)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 标签栏
    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "已下载", index: 0)
            tabButton(title: "下载中", index: 1)
        }
        .padding(.horizontal, 20)
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: selectedTab == index ? .bold : .medium, design: .rounded))
                    .foregroundColor(selectedTab == index ? .asideTextPrimary : .asideTextSecondary)
                
                Rectangle()
                    .fill(selectedTab == index ? Color.asideAccentBlue : Color.clear)
                    .frame(height: 2)
                    .frame(width: 40)
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }
    
    // MARK: - 已下载列表
    private var downloadedList: some View {
        let songs = downloadManager.fetchAllDownloaded()
        
        return Group {
            if songs.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    AsideIcon(icon: .download, size: 40, color: .asideTextSecondary.opacity(0.3), lineWidth: 1.4)
                    Text("暂无下载")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }
                Spacer()
            } else {
                VStack(spacing: 0) {
                    // 存储信息
                    HStack {
                        Text("\(songs.count) 首歌曲")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                        Spacer()
                        Text(totalSize)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(songs, id: \.id) { song in
                                downloadedRow(song: song)
                            }
                        }
                        .padding(.bottom, 120)
                    }
                }
            }
        }
    }
    
    private func downloadedRow(song: DownloadedSong) -> some View {
        HStack(spacing: 14) {
            // 封面
            if let urlStr = song.coverUrl, let url = URL(string: urlStr) {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 10).fill(Color.asideGlassTint).glassEffect(.regular, in: .rect(cornerRadius: 10))
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.asideGlassTint)
                    .frame(width: 48, height: 48)
                    .glassEffect(.regular, in: .rect(cornerRadius: 10))
                    .overlay(AsideIcon(icon: .musicNote, size: 20, color: .asideTextSecondary, lineWidth: 1.4))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if let badge = song.quality.badgeText {
                        Text(badge)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.asideTextPrimary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.asideTextPrimary, lineWidth: 0.5)
                            )
                    }
                    Text("\(song.artistName) · \(song.fileSizeText)")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapWithHaptic {
            // 播放已下载歌曲
            let s = song.toSong()
            PlayerManager.shared.play(song: s, in: downloadManager.fetchAllDownloaded().map { $0.toSong() })
        }
        .contextMenu {
            Button(role: .destructive) {
                downloadManager.deleteDownload(songId: song.id, isQQ: song.isQQMusic)
                updateTotalSize()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    // MARK: - 下载中列表
    private var downloadingList: some View {
        let tasks = downloadManager.fetchDownloading()
        
        return Group {
            if tasks.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    AsideIcon(icon: .download, size: 40, color: .asideTextSecondary.opacity(0.3), lineWidth: 1.4)
                    Text("没有正在下载的任务")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(tasks, id: \.id) { song in
                            downloadingRow(song: song)
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
        }
    }
    
    private func downloadingRow(song: DownloadedSong) -> some View {
        let progress = downloadManager.downloadingTasks[song.uniqueKey]?.progress ?? song.progress
        
        return HStack(spacing: 14) {
            // 封面
            if let urlStr = song.coverUrl, let url = URL(string: urlStr) {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 10).fill(Color.asideGlassTint).glassEffect(.regular, in: .rect(cornerRadius: 10))
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.asideGlassTint)
                    .frame(width: 48, height: 48)
                    .glassEffect(.regular, in: .rect(cornerRadius: 10))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(song.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(1)
                
                // 进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.asideSeparator.opacity(0.3))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.asideAccentBlue)
                            .frame(width: geo.size.width * progress, height: 3)
                    }
                }
                .frame(height: 3)
                
                Text(song.status == .failed ? "下载失败" : "\(Int(progress * 100))%")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(song.status == .failed ? .asideAccentRed : .asideTextSecondary)
            }
            
            Spacer()
            
            // 取消按钮
            Button {
                downloadManager.cancelDownload(songId: song.id, isQQ: song.isQQMusic)
            } label: {
                AsideIcon(icon: .close, size: 14, color: .asideTextSecondary, lineWidth: 1.4)
                    .frame(width: 32, height: 32)
                    .background(Color.asideGlassTint)
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
    
    // MARK: - 辅助
    private func updateTotalSize() {
        let size = downloadManager.totalDownloadSize()
        totalSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
