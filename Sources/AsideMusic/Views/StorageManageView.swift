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
    
    @State private var showClearCacheAlert = false
    @State private var showClearDatabaseAlert = false
    @State private var showClearDownloadAlert = false
    @State private var showClearImageAlert = false
    @State private var showClearAllAlert = false
    
    // 清理动画
    @State private var isCleaning = false
    @State private var cleaningCategory: String?
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                    .padding(.top, DeviceLayout.headerTopPadding)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .asideTextSecondary))
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // 总览卡片
                            overviewCard
                                .padding(.top, 16)
                            
                            // 存储分类
                            storageCategoriesCard
                            
                            // 快速清理
                            quickCleanCard
                            
                            Color.clear.frame(height: 100)
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { calculateSizes() }
        .alert(String(localized: "storage_clear_cache"), isPresented: $showClearCacheAlert) {
            Button(String(localized: "storage_clear"), role: .destructive) { clearSongCache() }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: { Text(String(localized: "storage_clear_cache_desc")) }
        .alert(String(localized: "storage_clear_data"), isPresented: $showClearDatabaseAlert) {
            Button(String(localized: "storage_clear"), role: .destructive) { clearDatabase() }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: { Text(String(localized: "storage_clear_data_desc")) }
        .alert(String(localized: "storage_clear_download"), isPresented: $showClearDownloadAlert) {
            Button(String(localized: "storage_delete_all"), role: .destructive) { clearDownloads() }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: { Text(String(localized: "storage_clear_download_desc")) }
        .alert(String(localized: "storage_clear_image"), isPresented: $showClearImageAlert) {
            Button(String(localized: "storage_clear"), role: .destructive) { clearImageCache() }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: { Text(String(localized: "storage_clear_image_desc")) }
        .alert(String(localized: "storage_clear_all"), isPresented: $showClearAllAlert) {
            Button(String(localized: "storage_clear_all_confirm"), role: .destructive) { clearAll() }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: { Text(String(localized: "storage_clear_all_desc")) }
    }
    
    // MARK: - 顶部栏
    
    private var headerSection: some View {
        HStack {
            AsideBackButton()
            Spacer()
            Text(String(localized: "storage_title"))
                .font(.rounded(size: 18, weight: .bold))
                .foregroundColor(.asideTextPrimary)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    
    // MARK: - 总览卡片
    
    private var overviewCard: some View {
        VStack(spacing: 20) {
            // 圆环进度
            ZStack {
                // 背景环
                Circle()
                    .stroke(Color.asideSeparator.opacity(0.5), lineWidth: 16)
                    .frame(width: 140, height: 140)
                
                // 进度环
                storageRing
                    .frame(width: 140, height: 140)
                
                // 中心内容
                VStack(spacing: 2) {
                    Text(formatBytes(totalUsage))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    Text(String(localized: "storage_total"))
                        .font(.rounded(size: 12))
                        .foregroundColor(.asideTextSecondary)
                }
            }
            
            // 图例
            HStack(spacing: 16) {
                legendItem(color: .blue, label: String(localized: "storage_download"), size: downloadSize)
                legendItem(color: .orange, label: String(localized: "storage_cache"), size: songCacheSize)
                legendItem(color: .purple, label: String(localized: "storage_data"), size: databaseSize)
                legendItem(color: .teal, label: String(localized: "storage_image"), size: imageCacheSize)
            }
        }
        .padding(24)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
    
    private var storageRing: some View {
        let total = max(totalUsage, 1)
        let downloadFrac = Double(downloadSize) / Double(total)
        let cacheFrac = Double(songCacheSize) / Double(total)
        let dbFrac = Double(databaseSize) / Double(total)
        let imgFrac = Double(imageCacheSize) / Double(total)
        
        let segments: [(Double, Color)] = [
            (downloadFrac, .blue),
            (cacheFrac, .orange),
            (dbFrac, .purple),
            (imgFrac, .teal)
        ]
        
        return ZStack {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                let startAngle = segments.prefix(index).reduce(0.0) { $0 + $1.0 }
                Circle()
                    .trim(from: CGFloat(startAngle), to: CGFloat(startAngle + segment.0))
                    .stroke(segment.1, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.08), value: totalUsage)
            }
        }
    }
    
    private func legendItem(color: Color, label: String, size: Int64) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.asideTextSecondary)
        }
    }
    
    // MARK: - 存储分类卡片
    
    private var storageCategoriesCard: some View {
        VStack(spacing: 0) {
            categoryRow(
                icon: .download,
                color: .blue,
                title: String(localized: "storage_download_songs"),
                subtitle: String(format: String(localized: "storage_song_count"), downloadManager.fetchAllDownloaded().count),
                size: downloadSize,
                onClear: { showClearDownloadAlert = true }
            )
            
            categoryDivider
            
            categoryRow(
                icon: .musicNote,
                color: .orange,
                title: String(localized: "storage_song_cache"),
                subtitle: String(localized: "storage_song_cache_desc"),
                size: songCacheSize,
                onClear: { showClearCacheAlert = true }
            )
            
            categoryDivider
            
            categoryRow(
                icon: .profile,
                color: .purple,
                title: String(localized: "storage_user_data"),
                subtitle: String(localized: "storage_user_data_desc"),
                size: databaseSize,
                onClear: { showClearDatabaseAlert = true }
            )
            
            categoryDivider
            
            categoryRow(
                icon: .sparkle,
                color: .teal,
                title: String(localized: "storage_image_cache"),
                subtitle: String(localized: "storage_image_cache_desc"),
                size: imageCacheSize,
                onClear: { showClearImageAlert = true }
            )
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
    
    private var categoryDivider: some View {
        Rectangle()
            .fill(Color.asideSeparator.opacity(0.5))
            .frame(height: 0.5)
            .padding(.leading, 60)
    }
    
    private func categoryRow(
        icon: AsideIcon.IconType,
        color: Color,
        title: String,
        subtitle: String,
        size: Int64,
        onClear: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                AsideIcon(icon: icon, size: 18, color: color)
            }
            
            // 标题和副标题
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.rounded(size: 15, weight: .medium))
                    .foregroundColor(.asideTextPrimary)
                Text(subtitle)
                    .font(.rounded(size: 12))
                    .foregroundColor(.asideTextSecondary)
            }
            
            Spacer()
            
            // 大小
            Text(formatBytes(size))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
            
            // 清除按钮
            if size > 0 {
                Button(action: onClear) {
                    Text(String(localized: "storage_clear_btn"))
                        .font(.rounded(size: 12, weight: .medium))
                        .foregroundColor(color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(color.opacity(0.1))
                        )
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    // MARK: - 快速清理卡片
    
    private var quickCleanCard: some View {
        Button(action: { showClearAllAlert = true }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 44, height: 44)
                    AsideIcon(icon: .trash, size: 20, color: .red)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "storage_clear_all_title"))
                        .font(.rounded(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                    Text(String(localized: "storage_clear_all_subtitle"))
                        .font(.rounded(size: 12))
                        .foregroundColor(.asideTextSecondary)
                }
                
                Spacer()
                
                AsideIcon(icon: .chevronRight, size: 14, color: .asideTextSecondary.opacity(0.5))
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
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
        let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AsideMusicCache")
        return directorySize(at: cacheDir)
    }
    
    private func calculateImageCacheSize() -> Int64 {
        let fm = FileManager.default
        let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        var total: Int64 = 0
        let imageDirs = ["ImageCache", "com.aside.images", "fsCachedData"]
        for dir in imageDirs {
            let path = cacheDir.appendingPathComponent(dir)
            total += directorySize(at: path)
        }
        if total == 0 {
            let diskTotal = calculateDiskCacheSize()
            total = Int64(Double(diskTotal) * 0.6)
        }
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
        DatabaseManager.shared.clearAllData()
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
        // 清内存图片缓存
        CachedAsyncImage<EmptyView>.clearMemoryCache()
        // 清 URLSession 图片缓存
        URLCache.shared.removeAllCachedResponses()
        // 清磁盘图片目录
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
        HapticManager.shared.success()
        // 1. 清三级缓存（内存 + SwiftData + 磁盘文件）
        OptimizedCacheManager.shared.clearAll()
        // 2. 清下载
        downloadManager.deleteAll()
        // 3. 清图片（内存 + 磁盘目录）
        CachedAsyncImage<EmptyView>.clearMemoryCache()
        let fm = FileManager.default
        let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        for dir in ["ImageCache", "com.aside.images", "fsCachedData"] {
            let path = cacheDir.appendingPathComponent(dir)
            try? fm.removeItem(at: path)
        }
        // 4. 清 URLSession 网络缓存
        URLCache.shared.removeAllCachedResponses()
        // 5. 清 tmp 目录
        let tmpDir = fm.temporaryDirectory
        if let tmpFiles = try? fm.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil) {
            for file in tmpFiles {
                try? fm.removeItem(at: file)
            }
        }
        // 6. 清缓存时间戳
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
