import SwiftUI

/// 存储管理页面 - 重构版
struct StorageManageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var downloadManager = DownloadManager.shared
    
    @State private var totalUsage: Int64 = 0
    @State private var songCacheSize: Int64 = 0
    @State private var databaseSize: Int64 = 0
    @State private var downloadSize: Int64 = 0
    @State private var imageCacheSize: Int64 = 0
    @State private var isLoading = true
    
    
    
    // 清理动画
    @State private var isCleaning = false
    @State private var cleaningCategory: String?
    
    var body: some View {
        ZStack {
            ThemedSettingsBackground()
            
            VStack(spacing: 0) {
                if isLoading {
                    ScrollView {
                        VStack(spacing: 28) {
                            SettingsScrollablePageHeader(
                                title: String(localized: "storage_title"),
                                eyebrow: "STORAGE",
                                icon: .storage
                            )

                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .monologueTextSecondary))
                                .padding(.top, 80)
                        }
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            SettingsScrollablePageHeader(
                                title: String(localized: "storage_title"),
                                eyebrow: "STORAGE",
                                icon: .storage
                            )

                            VStack(spacing: 20) {
                                // 总览卡片
                                overviewCard

                                // 存储分类
                                storageCategoriesCard

                                // 快速清理
                                quickCleanCard

                                FloatingBarBottomSpacer()
                            }
                            .padding(.horizontal, DeviceLayout.settingsSectionHorizontalPadding)
                        }
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    MonologueIcon(icon: .back, size: 16)
                }
            }
        }
        .onAppear { calculateSizes() }
        
    }
    
    // MARK: - 甜甜圈总览卡片（Figma: Storage Details）
    
    private var overviewCard: some View {
        VStack(spacing: 16) {
            donutChart
                .frame(width: 160, height: 160)
            
            VStack(spacing: 4) {
                Text(String(localized: "storage_available"))
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .rounded(size: 13))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                Text(formatBytes(availableSpace))
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(28, weight: .semibold) : .system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
                Text(String(format: String(localized: "storage_total_format"), formatBytes(totalDiskSpace)))
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .rounded(size: 13))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .themedPageSurface(cornerRadius: MangaStyle.isActive ? 24 : 20, elevated: true, mangaTint: MangaStyle.bubbleWhite)
    }
    
    private var totalDiskSpace: Int64 {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey])
        return Int64(values?.volumeTotalCapacity ?? 0)
    }
    
    private var availableSpace: Int64 {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }
    
    private var donutChart: some View {
        let total = max(totalUsage, 1)
        let segments: [(Double, Color)] = [
            (Double(downloadSize) / Double(total), .blue),
            (Double(songCacheSize) / Double(total), .orange),
            (Double(databaseSize) / Double(total), .purple),
            (Double(imageCacheSize) / Double(total), .teal),
        ]
        let gap: Double = 0.008
        
        return ZStack {
            Circle()
                .stroke(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueSeparator.opacity(0.3), lineWidth: 22)
            
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                let startAngle = segments.prefix(index).reduce(0.0) { $0 + $1.0 + gap }
                let endAngle = startAngle + max(segment.0 - gap, 0)
                Circle()
                    .trim(from: CGFloat(startAngle), to: CGFloat(endAngle))
                    .stroke(segment.1, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.08), value: totalUsage)
            }
        }
    }
    
    // MARK: - 存储分类列表（带进度条）
    
    private var storageCategoriesCard: some View {
        VStack(spacing: 0) {
            storageCategoryRow(
                color: .blue,
                title: String(localized: "storage_download_songs"),
                size: downloadSize,
                onTap: { showConfirm(title: String(localized: "storage_clear_download"), message: String(localized: "storage_clear_download_desc"), confirm: String(localized: "storage_delete_all")) { clearDownloads() } }
            )
            storageCategoryRow(
                color: .orange,
                title: String(localized: "storage_song_cache"),
                size: songCacheSize,
                onTap: { showConfirm(title: String(localized: "storage_clear_cache"), message: String(localized: "storage_clear_cache_desc"), confirm: String(localized: "storage_clear")) { clearSongCache() } }
            )
            storageCategoryRow(
                color: .purple,
                title: String(localized: "storage_user_data"),
                size: databaseSize,
                onTap: { showConfirm(title: String(localized: "storage_clear_data"), message: String(localized: "storage_clear_data_desc"), confirm: String(localized: "storage_clear")) { clearDatabase() } }
            )
            storageCategoryRow(
                color: .teal,
                title: String(localized: "storage_image_cache"),
                size: imageCacheSize,
                onTap: { showConfirm(title: String(localized: "storage_clear_image"), message: String(localized: "storage_clear_image_desc"), confirm: String(localized: "storage_clear")) { clearImageCache() } }
            )
        }
        .padding(.vertical, 4)
        .themedPageSurface(cornerRadius: MangaStyle.isActive ? 20 : 16, elevated: true, mangaTint: MangaStyle.bubbleWhite)
    }
    
    private func storageCategoryRow(
        color: Color,
        title: String,
        size: Int64,
        onTap: @escaping () -> Void
    ) -> some View {
        let fraction = totalUsage > 0 ? CGFloat(size) / CGFloat(totalUsage) : 0
        
        return Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(title)
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .medium) : .rounded(size: 15, weight: .medium))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
                        Spacer()
                        Text(formatBytes(size))
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueSeparator.opacity(0.3))
                                .frame(height: 4)
                            Capsule()
                                .fill(color)
                                .frame(width: max(geo.size.width * fraction, fraction > 0 ? 4 : 0), height: 4)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: size)
                        }
                    }
                    .frame(height: 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 快速清理
    
    private var quickCleanCard: some View {
        Button(action: { showConfirm(title: String(localized: "storage_clear_all"), message: String(localized: "storage_clear_all_desc"), confirm: String(localized: "storage_clear_all_confirm")) { clearAll() } }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 44, height: 44)
                    MonologueIcon(icon: .trash, size: 20, color: .red)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "storage_clear_all_title"))
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(16, weight: .semibold) : .rounded(size: 16, weight: .semibold))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.red : .red)
                    Text(String(localized: "storage_clear_all_subtitle"))
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .rounded(size: 12))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                }
                
                Spacer()
                
                MonologueIcon(icon: .chevronRight, size: 14, color: NeumorphicStyle.isActive ? NeumorphicStyle.red.opacity(0.8) : .monologueTextSecondary.opacity(0.5))
            }
            .padding(16)
            .themedPageSurface(cornerRadius: MangaStyle.isActive ? 20 : 16, elevated: true, mangaTint: MangaStyle.bubblePink.opacity(0.92))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
    }

    
    // MARK: - 计算大小
    
    private func calculateSizes() {
        Task { @MainActor in
            isLoading = true
            
            // 下载大小
            downloadSize = downloadManager.totalDownloadSize()
            
            // 数据库大小
            databaseSize = calculateRawDatabaseSize()
            
            // 图片缓存
            imageCacheSize = calculateImageCacheSize()
            
            // 歌曲缓存
            let totalDiskCache = calculateDiskCacheSize()
            songCacheSize = max(totalDiskCache - imageCacheSize, 0)
            
            // 总计
            totalUsage = downloadSize + songCacheSize + databaseSize + imageCacheSize
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isLoading = false
            }
        }
    }
    
    private func calculateRawDatabaseSize() -> Int64 {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return 0 }
        let dbPath = appSupport.appendingPathComponent("default.store")
        var total: Int64 = 0
        for ext in ["", ".wal", ".shm"] {
            let path = ext.isEmpty ? dbPath.path : dbPath.path + ext
            if let attrs = try? fm.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }
    
    private func calculateDiskCacheSize() -> Int64 {
        let fm = FileManager.default
        guard let cacheBase = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return 0 }
        let cacheDir = cacheBase.appendingPathComponent("MonologueCache")
        return directorySize(at: cacheDir)
    }
    
    private func calculateImageCacheSize() -> Int64 {
        let fm = FileManager.default
        guard let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return 0 }
        var total: Int64 = 0
        let imageDirs = ["ImageCache", "zijiu.Monologue.com.images", "com.monologue.images", "fsCachedData", "MonologueCache"]
        for dir in imageDirs {
            let path = cacheDir.appendingPathComponent(dir)
            total += directorySize(at: path)
        }
        total += Int64(URLCache.shared.currentDiskUsage)
        return total
    }
    
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
        HapticManager.shared.success()
        // 清内存 + 磁盘文件缓存
        CacheManager.shared.clearAll()
        // 同步清 OptimizedCacheManager 的内存层
        OptimizedCacheManager.shared.clearAll()
        // 清 URLSession 缓存（网络请求缓存）
        URLCache.shared.removeAllCachedResponses()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            calculateSizes()
        }
    }
    
    private func clearDatabase() {
        HapticManager.shared.success()
        DatabaseManager.shared.clearCacheData()
        // 清除数据库相关的时间戳
        UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.dailyCacheTimestamp)
        UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.lastSyncTimestamp)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            calculateSizes()
        }
    }
    
    private func clearDownloads() {
        HapticManager.shared.success()
        downloadManager.deleteAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            calculateSizes()
        }
    }
    
    private func clearImageCache() {
        HapticManager.shared.success()
        CachedAsyncImage<EmptyView>.clearMemoryCache()
        URLCache.shared.removeAllCachedResponses()
        CacheManager.shared.clearAll()
        let fm = FileManager.default
        guard let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        for dir in ["ImageCache", "zijiu.Monologue.com.images", "com.monologue.images", "fsCachedData"] {
            let path = cacheDir.appendingPathComponent(dir)
            try? fm.removeItem(at: path)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            calculateSizes()
        }
    }
    
    private func showConfirm(title: String, message: String, confirm: String, action: @escaping () -> Void) {
        AlertManager.shared.show(
            title: title,
            message: message,
            primaryButtonTitle: confirm,
            secondaryButtonTitle: String(localized: "cancel"),
            primaryAction: action
        )
    }
    
    private func clearAll() {
        HapticManager.shared.success()
        OptimizedCacheManager.shared.clearAll()
        CacheManager.shared.clearAll()
        CachedAsyncImage<EmptyView>.clearMemoryCache()
        URLCache.shared.removeAllCachedResponses()
        
        let fm = FileManager.default
        if let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            for dir in ["ImageCache", "zijiu.Monologue.com.images", "com.monologue.images", "fsCachedData"] {
                let path = cacheDir.appendingPathComponent(dir)
                try? fm.removeItem(at: path)
            }
        }
        
        let tmpDir = fm.temporaryDirectory
        if let tmpFiles = try? fm.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil) {
            for file in tmpFiles {
                try? fm.removeItem(at: file)
            }
        }
        
        UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.dailyCacheTimestamp)
        UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.lastSyncTimestamp)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.calculateSizes()
        }
    }
    
    // MARK: - 格式化
    
    private func formatBytes(_ bytes: Int64) -> String {
        if bytes == 0 { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
