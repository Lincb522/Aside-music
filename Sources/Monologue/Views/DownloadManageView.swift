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
            ThemedSettingsBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    SettingsScrollablePageHeader(
                        title: String(localized: "下载管理"),
                        eyebrow: "DOWNLOAD",
                        icon: .download
                    )

                    tabBar

                    if selectedTab == 0 {
                        downloadedList
                    } else {
                        downloadingList
                    }

                    FloatingBarBottomSpacer()
                }
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
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
        .padding(ThemedPageStyle.isActive ? 4 : 0)
        .themedOnlyPageSurface(cornerRadius: MangaStyle.isActive ? 18 : (NeumorphicStyle.isActive ? 20 : 14), elevated: false)
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        } label: {
            VStack(spacing: ThemedPageStyle.isActive ? 0 : 8) {
                Text(title)
                    .font(tabFont(isSelected: selectedTab == index))
                    .foregroundColor(tabTextColor(isSelected: selectedTab == index))
                
                if !ThemedPageStyle.isActive {
                    Rectangle()
                        .fill(selectedTab == index ? Color.monologueTextPrimary : Color.clear)
                        .frame(height: 2)
                        .frame(width: 40)
                }
            }
            .frame(height: ThemedPageStyle.isActive ? 38 : 44)
            .frame(maxWidth: .infinity)
            .background(tabBackground(isSelected: selectedTab == index))
            .clipShape(Capsule())
            .overlay {
                if MangaStyle.isActive && selectedTab == index {
                    Capsule()
                        .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }

    private func tabTextColor(isSelected: Bool) -> Color {
        if MangaStyle.isActive {
            return isSelected ? MangaStyle.ink : .monologueTextSecondary
        } else if MujiStyle.isActive {
            return isSelected ? MujiStyle.paper : .monologueTextSecondary
        } else if NeumorphicStyle.isActive {
            return isSelected ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft
        } else {
            return isSelected ? .monologueTextPrimary : .monologueTextSecondary
        }
    }

    private func tabFont(isSelected: Bool) -> Font {
        if MangaStyle.isActive { return MangaStyle.comicFont(14, weight: isSelected ? .bold : .medium) }
        if MujiStyle.isActive { return MujiStyle.labelFont(14, weight: isSelected ? .medium : .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(14, weight: isSelected ? .semibold : .medium) }
        return .system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded)
    }

    private func tabBackground(isSelected: Bool) -> Color {
        guard ThemedPageStyle.isActive, isSelected else { return .clear }
        if MangaStyle.isActive {
            return MangaStyle.labelYellow
        } else if MujiStyle.isActive {
            return MujiStyle.clay
        } else if NeumorphicStyle.isActive {
            return NeumorphicStyle.accent.opacity(0.14)
        } else {
            return .clear
        }
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
                                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : .system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueAccentBlue)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            Text("已选 \(selectedKeys.count) 首")
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .system(size: 13, design: .rounded))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                            
                            Spacer()
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { exitBatchMode() }
                            } label: {
                                Text("取消")
                                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("\(songs.count) 首歌曲")
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .system(size: 13, design: .rounded))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                            Spacer()
                            Text(totalSize)
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .system(size: 13, design: .rounded))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                        }
                    }
                    .padding(.horizontal, ThemedPageStyle.isActive ? 16 : DeviceLayout.viewHorizontalPadding)
                    .padding(.vertical, 12)
                    .themedOnlyPageSurface(cornerRadius: ThemedPageStyle.compactSurfaceCornerRadius, elevated: false)
                    .padding(.horizontal, ThemedPageStyle.horizontalInset)
                    
                    LazyVStack(spacing: ThemedPageStyle.listSpacing) {
                        ForEach(songs, id: \.id) { song in
                            downloadedRow(song: song)
                        }
                    }
                    .padding(.horizontal, ThemedPageStyle.horizontalInset)
                    .padding(.top, ThemedPageStyle.isActive ? 4 : 0)
                }
            }
        }
    }
    
    private func downloadedRow(song: DownloadedSong) -> some View {
        let isSelected = selectedKeys.contains(song.uniqueKey)
        
        return HStack(spacing: 12) {
            if isEditing {
                MonologueSymbolIcon(
                    name: isSelected ? "checkmark.circle.fill" : "circle",
                    size: 22,
                    color: isSelected ? .monologueAccentBlue : .monologueTextSecondary.opacity(0.4)
                )
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
            
            // 封面
            if let urlStr = song.coverUrl, let url = URL(string: urlStr) {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                        .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
                        .monologueGlass(cornerRadius: coverRadius)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                .overlay(coverStroke)
            } else {
                RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                    .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
                    .frame(width: 48, height: 48)
                    .monologueGlass(cornerRadius: coverRadius)
                    .overlay(MonologueIcon(icon: .musicNote, size: 20, color: NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueTextSecondary, lineWidth: 1.4))
                    .overlay(coverStroke)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.name)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .semibold) : .system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if let badge = song.quality.badgeText {
                        if NeumorphicStyle.isActive {
                            NeumorphicPill(text: badge, tint: MusicSource.netease.themedBadgeColor, compact: true)
                        } else {
                            Text(badge)
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(MangaStyle.isActive ? MusicSource.netease.themedBadgeColor : .monologueTextPrimary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: MangaStyle.isActive ? 6 : 2)
                                        .stroke(MangaStyle.isActive ? MusicSource.netease.themedBadgeColor : Color.monologueTextPrimary, lineWidth: 0.5)
                                )
                        }
                    }
                    Text("\(song.artistName) · \(song.fileSizeText)")
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .system(size: 12, design: .rounded))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, ThemedPageStyle.isActive ? 16 : DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, 8)
        .themedOnlyPageSurface(
            cornerRadius: ThemedPageStyle.compactSurfaceCornerRadius,
            elevated: isSelected,
            mangaTint: isSelected ? MangaStyle.labelYellow.opacity(0.88) : MangaStyle.bubbleWhite
        )
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
                LazyVStack(spacing: ThemedPageStyle.listSpacing) {
                    ForEach(tasks, id: \.id) { song in
                        downloadingRow(song: song)
                    }
                }
                .padding(.horizontal, ThemedPageStyle.horizontalInset)
                .padding(.top, ThemedPageStyle.isActive ? 8 : 0)
            }
        }
    }
    
    private func downloadingRow(song: DownloadedSong) -> some View {
        let progress = downloadManager.downloadingTasks[song.uniqueKey]?.progress ?? song.progress
        
        return HStack(spacing: 14) {
            // 封面
            if let urlStr = song.coverUrl, let url = URL(string: urlStr) {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                        .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
                        .monologueGlass(cornerRadius: coverRadius)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                .overlay(coverStroke)
            } else {
                RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                    .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
                    .frame(width: 48, height: 48)
                    .monologueGlass(cornerRadius: coverRadius)
                    .overlay(coverStroke)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(song.name)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .semibold) : .system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
                    .lineLimit(1)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueSeparator.opacity(0.3))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(NeumorphicStyle.isActive ? NeumorphicStyle.accent : Color.monologueAccentBlue)
                            .frame(width: geo.size.width * progress, height: 3)
                    }
                }
                .frame(height: 3)
                
                Text(song.status == .failed ? String(localized: "下载失败") : "\(Int(progress * 100))%")
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11, weight: .medium) : .system(size: 11, design: .rounded))
                    .foregroundColor(song.status == .failed ? (NeumorphicStyle.isActive ? NeumorphicStyle.red : .monologueAccentRed) : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary))
            }
            
            Spacer()
            
            Button {
                downloadManager.cancelDownload(songId: song.id, isQQ: song.isQQMusic)
            } label: {
                MonologueIcon(icon: .close, size: 14, color: .monologueTextSecondary, lineWidth: 1.4)
                    .frame(width: 32, height: 32)
                    .background(NeumorphicStyle.isActive ? NeumorphicStyle.surface : Color.monologueGlassTint)
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, ThemedPageStyle.isActive ? 16 : DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, 8)
        .themedOnlyPageSurface(cornerRadius: ThemedPageStyle.compactSurfaceCornerRadius, elevated: false)
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
