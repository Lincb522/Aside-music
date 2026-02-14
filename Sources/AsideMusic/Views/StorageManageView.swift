import SwiftUI

/// 存储管理页面
struct StorageManageView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var downloadManager = DownloadManager.shared
    
    @State private var totalUsage: Int64 = 0
    @State private var songCacheSize: Int64 = 0
    @State private var databaseSize: Int64 = 0
    @State private var downloadSize: Int64 = 0
    @State private var imageCacheSize: Int64 = 0
    @State private var isLoading = true
    
    @State private var showClearCacheAlert = false
    @State private var showClearDatabaseAlert = false
    @State private var showClearDownloadAlert = false
    @State private var showClearImageAlert = false
    @State private var showClearAllAlert = false
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                    .padding(.top, DeviceLayout.headerTopPadding)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 总览环形图
                        overviewSection
                            .padding(.top, 20)
                        
                        // 分类详情
                        categorySection
                        
                        // 一键清理
                        clearAllSection
                        
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { calculateSizes() }
        .alert("清除歌曲缓存", isPresented: $showClearCacheAlert) {
            Button("清除", role: .destructive) { clearSongCache() }
            Button("取消", role: .cancel) {}
        } message: { Text("将清除所有歌曲和歌单的缓存数据") }
        .alert("清除用户数据", isPresented: $showClearDatabaseAlert) {
            Button("清除", role: .destructive) { clearDatabase() }
            Button("取消", role: .cancel) {}
        } message: { Text("将清除播放历史、搜索记录等用户数据") }
        .alert("清除下载", isPresented: $showClearDownloadAlert) {
            Button("删除全部", role: .destructive) { clearDownloads() }
            Button("取消", role: .cancel) {}
        } message: { Text("将删除所有已下载的歌曲文件") }
        .alert("清除图片缓存", isPresented: $showClearImageAlert) {
            Button("清除", role: .destructive) { clearImageCache() }
            Button("取消", role: .cancel) {}
        } message: { Text("将清除所有缓存的封面图片") }
        .alert("清除全部", isPresented: $showClearAllAlert) {
            Button("全部清除", role: .destructive) { clearAll() }
            Button("取消", role: .cancel) {}
        } message: { Text("将清除所有缓存、用户数据和下载文件，此操作不可撤销") }
    }
    
    // MARK: - 顶部栏
    private var headerSection: some View {
        HStack {
            AsideBackButton(style: .dismiss)
            Spacer()
            Text("存储管理")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
            Spacer()
            Circle().fill(Color.clear).frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 总览
    private var overviewSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // 环形背景
                Circle()
                    .stroke(Color.asideSeparator, lineWidth: 12)
                    .frame(width: 160, height: 160)
                
                // 各分类弧形
                storageRing
                    .frame(width: 160, height: 160)
                
                // 中心文字
                VStack(spacing: 4) {
                    Text(formatBytes(totalUsage))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    Text("总占用")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }
            }
            .padding(.vertical, 8)
            
            // 图例
            HStack(spacing: 20) {
                legendItem(color: .asideAccentBlue, label: "下载")
                legendItem(color: Color.orange, label: "缓存")
                legendItem(color: Color.purple, label: "数据")
                legendItem(color: Color.teal, label: "图片")
            }
        }
        .padding(24)
        .asideGlassCard(cornerRadius: 20)
    }
    
    private var storageRing: some View {
        let total = max(totalUsage, 1)
        let downloadFrac = Double(downloadSize) / Double(total)
        let cacheFrac = Double(songCacheSize) / Double(total)
        let dbFrac = Double(databaseSize) / Double(total)
        let imgFrac = Double(imageCacheSize) / Double(total)
        
        let segments: [(Double, Color)] = [
            (downloadFrac, .asideAccentBlue),
            (cacheFrac, .orange),
            (dbFrac, .purple),
            (imgFrac, .teal)
        ]
        
        return ZStack {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                let startAngle = segments.prefix(index).reduce(0.0) { $0 + $1.0 }
                Circle()
                    .trim(from: CGFloat(startAngle), to: CGFloat(startAngle + segment.0))
                    .stroke(segment.1, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6).delay(Double(index) * 0.1), value: totalUsage)
            }
        }
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary)
        }
    }

    // MARK: - 分类详情
    private var categorySection: some View {
        VStack(spacing: 0) {
            storageCategoryRow(
                icon: .download,
                iconColor: .asideAccentBlue,
                title: "下载歌曲",
                subtitle: "\(downloadManager.fetchAllDownloaded().count) 首",
                size: downloadSize,
                action: { showClearDownloadAlert = true }
            )
            
            Divider().padding(.leading, 56)
            
            storageCategoryRow(
                icon: .musicNote,
                iconColor: .orange,
                title: "歌曲缓存",
                subtitle: "歌曲、歌单、歌词等",
                size: songCacheSize,
                action: { showClearCacheAlert = true }
            )
            
            Divider().padding(.leading, 56)
            
            storageCategoryRow(
                icon: .profile,
                iconColor: .purple,
                title: "用户数据",
                subtitle: "播放历史、搜索记录等",
                size: databaseSize,
                action: { showClearDatabaseAlert = true }
            )
            
            Divider().padding(.leading, 56)
            
            storageCategoryRow(
                icon: .sparkle,
                iconColor: .teal,
                title: "图片缓存",
                subtitle: "封面、头像等图片",
                size: imageCacheSize,
                action: { showClearImageAlert = true }
            )
        }
        .asideGlassCard(cornerRadius: 16)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func storageCategoryRow(
        icon: AsideIcon.IconType,
        iconColor: Color,
        title: String,
        subtitle: String,
        size: Int64,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                AsideIcon(icon: icon, size: 16, color: iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }
            
            Spacer()
            
            Text(formatBytes(size))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary)
            
            // 清除按钮
            if size > 0 {
                Button(action: action) {
                    Text("清除")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.asideAccentBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.asideAccentBlue.opacity(0.1))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - 一键清理
    private var clearAllSection: some View {
        Button {
            showClearAllAlert = true
        } label: {
            HStack(spacing: 10) {
                AsideIcon(icon: .trash, size: 16, color: .asideAccentRed, lineWidth: 1.4)
                Text("清除全部数据")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.asideAccentRed)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .asideGlassCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 计算大小
    private func calculateSizes() {
        Task { @MainActor in
            // 下载大小
            downloadSize = downloadManager.totalDownloadSize()
            
            // 数据库大小
            databaseSize = calculateRawDatabaseSize()
            
            // 图片缓存（磁盘缓存中的图片部分）
            imageCacheSize = calculateImageCacheSize()
            
            // 歌曲缓存（磁盘缓存减去图片）
            let totalDiskCache = calculateDiskCacheSize()
            songCacheSize = max(totalDiskCache - imageCacheSize, 0)
            
            // 总计
            totalUsage = downloadSize + songCacheSize + databaseSize + imageCacheSize
            isLoading = false
        }
    }
    
    /// 计算数据库文件原始字节大小
    private func calculateRawDatabaseSize() -> Int64 {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return 0 }
        let dbPath = appSupport.appendingPathComponent("default.store")
        var total: Int64 = 0
        // 主文件 + WAL + SHM
        for ext in ["", ".wal", ".shm"] {
            let path = ext.isEmpty ? dbPath.path : dbPath.path + ext
            if let attrs = try? fm.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }
    
    /// 计算磁盘缓存总大小
    private func calculateDiskCacheSize() -> Int64 {
        let fm = FileManager.default
        let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AsideMusicCache")
        return directorySize(at: cacheDir)
    }
    
    /// 计算图片缓存大小
    private func calculateImageCacheSize() -> Int64 {
        let fm = FileManager.default
        let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        // 图片缓存可能在多个位置
        var total: Int64 = 0
        let imageDirs = ["ImageCache", "com.aside.images", "fsCachedData"]
        for dir in imageDirs {
            let path = cacheDir.appendingPathComponent(dir)
            total += directorySize(at: path)
        }
        // 如果没有独立图片目录，估算磁盘缓存的 60% 为图片
        if total == 0 {
            let diskTotal = calculateDiskCacheSize()
            total = Int64(Double(diskTotal) * 0.6)
        }
        return total
    }
    
    /// 计算目录大小
    private func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: .skipsHiddenFiles) else { return 0 }
        return files.reduce(0) { total, fileURL in
            let size = (try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0
            return total + Int64(size)
        }
    }
    
    // MARK: - 清理操作
    private func clearSongCache() {
        CacheManager.shared.clearAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            calculateSizes()
        }
    }
    
    private func clearDatabase() {
        DatabaseManager.shared.clearAllData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            calculateSizes()
        }
    }
    
    private func clearDownloads() {
        downloadManager.deleteAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            calculateSizes()
        }
    }
    
    private func clearImageCache() {
        // 清除图片内存缓存
        CachedAsyncImage<EmptyView>.clearMemoryCache()
        // 清除磁盘图片缓存
        let fm = FileManager.default
        let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        for dir in ["ImageCache", "com.aside.images", "fsCachedData"] {
            let path = cacheDir.appendingPathComponent(dir)
            try? fm.removeItem(at: path)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            calculateSizes()
        }
    }
    
    private func clearAll() {
        OptimizedCacheManager.shared.clearAll()
        downloadManager.deleteAll()
        clearImageCache()
    }
    
    // MARK: - 格式化
    private func formatBytes(_ bytes: Int64) -> String {
        if bytes == 0 { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
