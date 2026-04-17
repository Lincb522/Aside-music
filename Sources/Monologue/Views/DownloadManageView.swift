import SwiftUI

/// 下载管理页面
struct DownloadManageView: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0  // 0=已下载, 1=下载中
    @State private var totalSize: String = String(localized: "计算中...")
    
    private enum BatchMode: Equatable { case none, sharing, deleting }
    @State private var batchMode: BatchMode = .none
    @State private var selectedKeys: Set<String> = []
    
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    
    private var isEditing: Bool { batchMode != .none }
    
    var body: some View {
        ZStack {
            MonologueBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                tabBar
                    .padding(.top, 16)
                
                if selectedTab == 0 {
                    downloadedList
                } else {
                    downloadingList
                }
            }
        }
        .navigationTitle(String(localized: "下载管理"))
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if selectedTab == 0 {
                    HStack(spacing: 14) {
                        toolbarIcon(
                            icon: .share,
                            activeMode: .sharing,
                            action: handleShareTap
                        )
                        
                        toolbarIcon(
                            icon: .trash,
                            activeMode: .deleting,
                            destructive: true,
                            action: handleDeleteTap
                        )
                    }
                }
            }
        }
        .onAppear { updateTotalSize() }
        .onChange(of: selectedTab) { _, _ in
            exitBatchMode()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }
    
    // MARK: - Toolbar Icon
    
    @ViewBuilder
    private func toolbarIcon(
        icon: MonologueIcon.IconType,
        activeMode: BatchMode,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let isActive = batchMode == activeMode
        let activeColor: Color = destructive ? .monologueAccentRed : .monologueAccentBlue
        
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                MonologueIcon(
                    icon: icon,
                    size: 18,
                    color: isActive ? activeColor : .monologueTextSecondary,
                    lineWidth: 1.4
                )
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                
                if isActive && !selectedKeys.isEmpty {
                    Text("\(selectedKeys.count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(activeColor, in: Capsule())
                        .offset(x: 6, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 标签栏
    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: String(localized: "已下载"), index: 0)
            tabButton(title: String(localized: "下载中"), index: 1)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: selectedTab == index ? .bold : .medium, design: .rounded))
                    .foregroundColor(selectedTab == index ? .monologueTextPrimary : .monologueTextSecondary)
                
                Rectangle()
                    .fill(selectedTab == index ? Color.monologueTextPrimary : Color.clear)
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
                    MonologueIcon(icon: .download, size: 40, color: .monologueTextSecondary.opacity(0.3), lineWidth: 1.4)
                    Text("暂无下载")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                }
                Spacer()
            } else {
                VStack(spacing: 0) {
                    HStack {
                        if isEditing {
                            Button {
                                if selectedKeys.count == songs.count {
                                    selectedKeys.removeAll()
                                } else {
                                    selectedKeys = Set(songs.map { $0.uniqueKey })
                                }
                            } label: {
                                Text(selectedKeys.count == songs.count ? String(localized: "取消全选") : String(localized: "全选"))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.monologueAccentBlue)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            Text("已选 \(selectedKeys.count) 首")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.monologueTextSecondary)
                            
                            Spacer()
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { exitBatchMode() }
                            } label: {
                                Text("取消")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.monologueTextSecondary)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("\(songs.count) 首歌曲")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.monologueTextSecondary)
                            Spacer()
                            Text(totalSize)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.monologueTextSecondary)
                        }
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.vertical, 12)
                    
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(songs, id: \.id) { song in
                                downloadedRow(song: song)
                            }
                        }
                        .padding(.bottom, 120)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }
    
    private func downloadedRow(song: DownloadedSong) -> some View {
        let isSelected = selectedKeys.contains(song.uniqueKey)
        
        return HStack(spacing: 12) {
            if isEditing {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .monologueAccentBlue : .monologueTextSecondary.opacity(0.4))
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
            
            // 封面
            if let urlStr = song.coverUrl, let url = URL(string: urlStr) {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 10).fill(Color.monologueGlassTint).monologueGlass(cornerRadius: 10)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.monologueGlassTint)
                    .frame(width: 48, height: 48)
                    .monologueGlass(cornerRadius: 10)
                    .overlay(MonologueIcon(icon: .musicNote, size: 20, color: .monologueTextSecondary, lineWidth: 1.4))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if let badge = song.quality.badgeText {
                        Text(badge)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.monologueTextPrimary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.monologueTextPrimary, lineWidth: 0.5)
                            )
                    }
                    Text("\(song.artistName) · \(song.fileSizeText)")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapWithHaptic {
            if isEditing {
                toggleSelection(key: song.uniqueKey)
            } else {
                let s = song.toSong()
                PlayerManager.shared.play(song: s, in: downloadManager.fetchAllDownloaded().map { $0.toSong() })
            }
        }
        .contextMenu {
            if !isEditing {
                Button {
                    shareSong(song)
                } label: {
                    Label(String(localized: "分享"), systemImage: "square.and.arrow.up")
                }
                
                Button(role: .destructive) {
                    downloadManager.deleteDownload(songId: song.id, isQQ: song.isQQMusic)
                    updateTotalSize()
                } label: {
                    Label(String(localized: "删除"), systemImage: "trash")
                }
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
                    MonologueIcon(icon: .download, size: 40, color: .monologueTextSecondary.opacity(0.3), lineWidth: 1.4)
                    Text("没有正在下载的任务")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
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
                .scrollIndicators(.hidden)
            }
        }
    }
    
    private func downloadingRow(song: DownloadedSong) -> some View {
        let progress = downloadManager.downloadingTasks[song.uniqueKey]?.progress ?? song.progress
        
        return HStack(spacing: 14) {
            // 封面
            if let urlStr = song.coverUrl, let url = URL(string: urlStr) {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 10).fill(Color.monologueGlassTint).monologueGlass(cornerRadius: 10)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.monologueGlassTint)
                    .frame(width: 48, height: 48)
                    .monologueGlass(cornerRadius: 10)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(song.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(1)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.monologueSeparator.opacity(0.3))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.monologueAccentBlue)
                            .frame(width: geo.size.width * progress, height: 3)
                    }
                }
                .frame(height: 3)
                
                Text(song.status == .failed ? String(localized: "下载失败") : "\(Int(progress * 100))%")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(song.status == .failed ? .monologueAccentRed : .monologueTextSecondary)
            }
            
            Spacer()
            
            Button {
                downloadManager.cancelDownload(songId: song.id, isQQ: song.isQQMusic)
            } label: {
                MonologueIcon(icon: .close, size: 14, color: .monologueTextSecondary, lineWidth: 1.4)
                    .frame(width: 32, height: 32)
                    .background(Color.monologueGlassTint)
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, 8)
    }
    
    // MARK: - Actions
    
    private func exitBatchMode() {
        batchMode = .none
        selectedKeys.removeAll()
    }
    
    private func toggleSelection(key: String) {
        if selectedKeys.contains(key) {
            selectedKeys.remove(key)
        } else {
            selectedKeys.insert(key)
        }
    }
    
    private func handleShareTap() {
        switch batchMode {
        case .sharing:
            guard !selectedKeys.isEmpty else {
                withAnimation(.easeInOut(duration: 0.2)) { exitBatchMode() }
                return
            }
            let songs = downloadManager.fetchAllDownloaded()
            let urls = songs
                .filter { selectedKeys.contains($0.uniqueKey) }
                .compactMap { $0.localFileURL }
            guard !urls.isEmpty else { return }
            shareItems = urls
            showShareSheet = true
            withAnimation(.easeInOut(duration: 0.2)) { exitBatchMode() }
        default:
            withAnimation(.easeInOut(duration: 0.2)) {
                batchMode = .sharing
                selectedKeys.removeAll()
            }
        }
    }
    
    private func handleDeleteTap() {
        switch batchMode {
        case .deleting:
            guard !selectedKeys.isEmpty else {
                withAnimation(.easeInOut(duration: 0.2)) { exitBatchMode() }
                return
            }
            let count = selectedKeys.count
            AlertManager.shared.show(
                title: String(localized: "确认删除"),
                message: String(localized: "将删除选中的 \(count) 首歌曲，此操作不可撤销"),
                primaryButtonTitle: String(localized: "删除 \(count) 首"),
                secondaryButtonTitle: String(localized: "取消"),
                primaryAction: { [selectedKeys] in
                    let songs = downloadManager.fetchAllDownloaded()
                    for song in songs where selectedKeys.contains(song.uniqueKey) {
                        downloadManager.deleteDownload(songId: song.id, isQQ: song.isQQMusic)
                    }
                    self.selectedKeys.removeAll()
                    self.batchMode = .none
                    updateTotalSize()
                }
            )
        default:
            withAnimation(.easeInOut(duration: 0.2)) {
                batchMode = .deleting
                selectedKeys.removeAll()
            }
        }
    }
    
    private func shareSong(_ song: DownloadedSong) {
        guard let url = song.localFileURL else { return }
        shareItems = [url]
        showShareSheet = true
    }
    
    private func updateTotalSize() {
        let size = downloadManager.totalDownloadSize()
        totalSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - UIKit ShareSheet Bridge

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
