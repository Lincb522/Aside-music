import Foundation
import Combine
import QQMusicKit

/// 音乐下载管理器
@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    
    // MARK: - 发布属性
    @Published var downloadingTasks: [String: DownloadTask] = [:]  // uniqueKey -> task
    @Published var downloadedSongIds: Set<String> = []  // uniqueKey 集合
    @Published var lastError: DownloadError? = nil
    
    struct DownloadError: Identifiable {
        let id = UUID()
        let songName: String
        let message: String
    }
    
    /// 最大并发下载数
    private var maxConcurrent: Int {
        min(3, MonoComputeBudgetStore.shared.current.backgroundComputeConcurrency)
    }
    /// 等待队列
    private var waitingQueue: [String] = []  // uniqueKey 队列
    /// 活跃下载数
    private var activeCount: Int { downloadingTasks.values.filter { $0.isActive }.count }
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// 下载任务包装
    struct DownloadTask {
        let uniqueKey: String
        let songId: Int
        var urlSessionTask: URLSessionDownloadTask?
        var progress: Double = 0
        var isActive: Bool = false
        /// QMC 加密文件的 ekey（下载完成后需解密）
        var qmcEkey: String?
    }

    func task(for song: Song) -> DownloadTask? {
        downloadingTasks[Self.makeKey(for: song)]
    }

    func isDownloading(_ song: Song) -> Bool {
        let key = Self.makeKey(for: song)
        return downloadingTasks[key] != nil || waitingQueue.contains(key)
    }

    func cancelDownload(for song: Song) {
        cancelDownload(key: Self.makeKey(for: song))
    }
    
    // MARK: - URLSession
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 600 // 10分钟超时
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    /// taskIdentifier -> uniqueKey 映射（用于 delegate 回调）
    private var taskToKey: [Int: String] = [:]
    nonisolated private let progressGate = DownloadProgressGate()
    
    private override init() {
        super.init()
        MonoComputeEngine.shared.$budget
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.processQueue() }
            .store(in: &cancellables)
        // 启动时加载已下载歌曲 ID
        Task { loadDownloadedIds() }
    }

    /// 生成 uniqueKey
    private static func makeKey(songId: Int, isQQ: Bool) -> String {
        isQQ ? "qq_\(songId)" : "ncm_\(songId)"
    }

    static func makeQishuiKey(trackId: Int) -> String {
        "qishui_\(trackId)"
    }

    static func makeKey(for song: Song) -> String {
        switch song.musicSource {
        case .netease: return makeKey(songId: song.id, isQQ: false)
        case .qqmusic: return makeKey(songId: song.id, isQQ: true)
        case .qishui: return makeQishuiKey(trackId: song.qishuiTrackId ?? song.id)
        case .kugou, .appleMusic, .local: return "\(song.musicSource.rawValue)_\(song.id)"
        }
    }

    private static func makeKey(for record: CloudDownloadRecord) -> String {
        if record.source == MusicSource.qishui.rawValue, let trackId = record.qishuiTrackId {
            return makeQishuiKey(trackId: trackId)
        }
        return makeKey(songId: record.songId, isQQ: record.source == MusicSource.qqmusic.rawValue)
    }
    
    // MARK: - 默认下载音质

    /// qcm默认下载音质：QMC 解密开启时用最高，否则用 SQ (FLAC)
    static var defaultQQDownloadQuality: QQMusicQuality {
        SettingsManager.shared.qmcDecryptEnabled ? .master : .flac
    }

    /// ncm默认下载音质：始终使用最高
    static var defaultNeteaseDownloadQuality: SoundQuality {
        .jymaster
    }

    // MARK: - 公开方法
    
    /// 下载歌曲
    func download(song: Song, quality: SoundQuality? = nil) {
        guard AppConfig.Features.restrictedDownloadEnabled else {
            AppLogger.info("[DownloadManager] 下载功能已关闭，忽略下载请求: \(song.id)")
            return
        }
        // 汽水歌曲走专用下载通道（key 形态不同，走通用通道会产生错配记录）
        if song.isQishui {
            downloadQishui(song: song, quality: SettingsManager.shared.defaultQishuiPlaybackQuality)
            return
        }

        guard song.musicSource == .netease || song.musicSource == .qqmusic else {
            handleDownloadFailed(key: Self.makeKey(for: song), songName: song.name,
                                 reason: String(localized: "download_source_unsupported"))
            return
        }
        let key = Self.makeKey(for: song)
        DownloadTombstoneStore.shared.clearTombstones(for: song)
        
        // 已下载或正在下载则跳过
        guard !downloadedSongIds.contains(key),
              downloadingTasks[key] == nil,
              !waitingQueue.contains(key) else {
            AppLogger.debug("歌曲 \(key) 已下载或正在下载中")
            return
        }
        
        // 保存到数据库（区分 qcm和ncm）
        let store = DatabaseManager.shared.store
        if song.isQQMusic {
            let downloaded = DownloadedSong(from: song, qqQuality: Self.defaultQQDownloadQuality)
            store.insert(downloaded)
        } else {
            let targetQuality = quality ?? Self.defaultNeteaseDownloadQuality
            let downloaded = DownloadedSong(from: song, quality: targetQuality)
            store.insert(downloaded)
        }
        store.save()
        
        // 加入队列
        waitingQueue.append(key)
        AppLogger.info("歌曲加入下载队列: \(song.name)")
        
        // 尝试启动下载
        processQueue()
    }
    
    /// 下载 qcm歌曲（指定 QQ 音质）
    func downloadQQ(song: Song, quality: QQMusicQuality) {
        guard AppConfig.Features.restrictedDownloadEnabled else {
            AppLogger.info("[DownloadManager] 下载功能已关闭，忽略 QQ 下载请求: \(song.id)")
            return
        }
        let key = Self.makeKey(songId: song.id, isQQ: true)
        DownloadTombstoneStore.shared.clearTombstones(for: song)
        
        guard !downloadedSongIds.contains(key),
              downloadingTasks[key] == nil,
              !waitingQueue.contains(key) else {
            AppLogger.debug("歌曲 \(key) 已下载或正在下载中")
            return
        }
        
        let store = DatabaseManager.shared.store
        let downloaded = DownloadedSong(from: song, qqQuality: quality)
        store.insert(downloaded)
        store.save()
        
        waitingQueue.append(key)
        AppLogger.info("[QQMusic] 歌曲加入下载队列: \(song.name)")
        processQueue()
    }
    
    /// 下载汽水音乐歌曲（通过服务端代理）
    func downloadQishui(song: Song, quality: String = "highest") {
        guard AppConfig.Features.restrictedDownloadEnabled else {
            AppLogger.info("[DownloadManager] 下载功能已关闭，忽略汽水下载请求: \(song.id)")
            return
        }
        guard let trackId = song.qishuiTrackId else { return }
        let key = Self.makeQishuiKey(trackId: trackId)
        DownloadTombstoneStore.shared.clearTombstones(for: song)

        guard !downloadedSongIds.contains(key),
              downloadingTasks[key] == nil,
              !waitingQueue.contains(key) else {
            AppLogger.debug("歌曲 \(key) 已下载或正在下载中")
            return
        }

        let store = DatabaseManager.shared.store
        let downloaded = DownloadedSong(
            id: song.id,
            name: song.name,
            artistName: song.artistName,
            albumName: song.al?.name,
            coverUrl: song.coverUrl?.absoluteString,
            duration: song.dt,
            quality: .exhigh,
            isQishui: true,
            qishuiTrackId: trackId,
            qishuiQualityRaw: quality
        )
        downloaded.uniqueKey = key
        store.insert(downloaded)
        store.save()

        waitingQueue.append(key)
        AppLogger.info("[Qishui] 歌曲加入下载队列: \(song.name) (\(quality))")
        processQueue()
    }

    /// 取消下载
    func cancelDownload(songId: Int, isQQ: Bool = false) {
        cancelDownload(key: Self.makeKey(songId: songId, isQQ: isQQ))
    }

    private func cancelDownload(key: String) {
        // 取消活跃任务
        if let task = downloadingTasks[key] {
            if let sessionTask = task.urlSessionTask {
                taskToKey.removeValue(forKey: sessionTask.taskIdentifier)
                progressGate.remove(taskID: sessionTask.taskIdentifier)
                sessionTask.cancel()
            }
            downloadingTasks.removeValue(forKey: key)
        }
        
        // 从等待队列移除
        waitingQueue.removeAll { $0 == key }
        
        // 从数据库删除
        deleteFromDB(key: key)
        
        AppLogger.info("取消下载: \(key)")
        processQueue()
    }
    
    /// 删除已下载歌曲
    func deleteDownload(songId: Int, isQQ: Bool = false) {
        deleteDownload(key: Self.makeKey(songId: songId, isQQ: isQQ))
    }

    /// 删除已下载歌曲（按歌曲来源解析 key，兼容汽水下载）
    func deleteDownload(for song: Song) {
        deleteDownload(key: Self.makeKey(for: song))
    }

    /// 删除与这首歌相关的**所有**下载记录与文件。
    /// Includes legacy key variants belonging to the same platform track.
    func deleteAllDownloadRecords(for song: Song) {
        var keys: Set<String> = [Self.makeKey(for: song)]
        let store = DatabaseManager.shared.store
        for record in store.fetch(DownloadedSong.self, where: { $0.toSong() == song }) {
            keys.insert(record.uniqueKey)
        }
        DownloadTombstoneStore.shared.markDeleted(keys: keys, song: song)

        for key in keys {
            removeDownload(key: key, notifyCloud: false)
        }
        LocalPlaylistCloudSyncManager.shared.scheduleSyncForLocalMutation()
    }

    /// 删除已下载歌曲（按 uniqueKey）
    func deleteDownload(key: String) {
        if let record = getDownloadRecord(key: key) {
            DownloadTombstoneStore.shared.markDeleted(keys: [key], song: record.toSong())
        } else {
            DownloadTombstoneStore.shared.markDeleted(keys: [key], song: nil)
        }
        removeDownload(key: key, notifyCloud: true)
    }

    private func removeDownload(key: String, notifyCloud: Bool) {
        // 删除本地文件
        if let url = localFileURL(forKey: key) {
            do {
                try FileManager.default.removeItem(at: url)
                #if DEBUG
                print("[DownloadManager] ✅ 已删除文件: \(url.lastPathComponent)")
                #endif
            } catch {
                AppLogger.error("删除下载文件失败: \(url.lastPathComponent), error=\(error)")
            }
        } else {
            // localFileURL 找不到记录时，尝试按 key 直接扫描文件
            let dir = DownloadedSong.downloadsDirectory
            let fm = FileManager.default
            if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for file in files where file.lastPathComponent.hasPrefix(key) {
                    try? fm.removeItem(at: file)
                    #if DEBUG
                    print("[DownloadManager] ✅ 按 key 前缀删除文件: \(file.lastPathComponent)")
                    #endif
                }
            }
        }
        
        // 从数据库删除
        deleteFromDB(key: key)
        downloadedSongIds.remove(key)
        
        AppLogger.info("删除下载: \(key)")
        if notifyCloud {
            LocalPlaylistCloudSyncManager.shared.scheduleSyncForLocalMutation()
        }
    }
    
    /// 删除所有下载
    func deleteAll() {
        // 先为所有记录打删除墓碑，避免云端快照把清空的记录恢复回来
        let allRecords = DatabaseManager.shared.store.fetchAll(DownloadedSong.self)
        DownloadTombstoneStore.shared.markDeleted(records: allRecords)

        // 取消所有进行中的任务
        for (_, task) in downloadingTasks {
            if let sessionTask = task.urlSessionTask {
                taskToKey.removeValue(forKey: sessionTask.taskIdentifier)
                progressGate.remove(taskID: sessionTask.taskIdentifier)
                sessionTask.cancel()
            }
        }
        downloadingTasks.removeAll()
        waitingQueue.removeAll()
        
        // 只删除音频记录对应文件；歌词使用 Downloads/Lyrics 独立保存，不能一并清掉。
        let dir = DownloadedSong.downloadsDirectory
        let fm = FileManager.default

        for record in allRecords {
            guard let url = record.localFileURL, fm.fileExists(atPath: url.path) else { continue }
            do {
                try fm.removeItem(at: url)
            } catch {
                AppLogger.error("删除下载文件失败: \(url.lastPathComponent), error=\(error)")
            }
        }

        // 兼容没有数据库记录的旧音频文件，只清理目录第一层文件，保留 Lyrics 子目录。
        if let files = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for file in files {
                let isDirectory = (try? file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                guard !isDirectory else { continue }
                try? fm.removeItem(at: file)
            }
        }
        
        // 清空数据库中的下载记录
        let store = DatabaseManager.shared.store
        store.deleteAll(DownloadedSong.self)
        store.save()
        
        downloadedSongIds.removeAll()
        
        // 验证清理结果
        #if DEBUG
        let remaining = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?.count ?? 0
        print("[DownloadManager] 清理完成，下载目录剩余文件: \(remaining)")
        #endif
        
        AppLogger.info("已清除所有下载")
    }
    
    func isDownloaded(song: Song) -> Bool {
        downloadedSongIds.contains(Self.makeKey(for: song))
    }

    /// 获取本地文件 URL
    func localFileURL(for song: Song) -> URL? {
        localFileURL(forKey: Self.makeKey(for: song))
    }

    /// 获取本地文件 URL
    func localFileURL(songId: Int, isQQ: Bool = false) -> URL? {
        let key = Self.makeKey(songId: songId, isQQ: isQQ)
        let store = DatabaseManager.shared.store
        let completed = "completed"
        guard let record = store.first(DownloadedSong.self, where: { $0.uniqueKey == key && $0.statusRaw == completed }),
              let url = normalizeCompletedFileNameIfNeeded(for: record) ?? record.localFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            // 回退：按 songId 查找（兼容旧数据）
            guard let record = store.first(DownloadedSong.self, where: {
                      $0.id == songId && $0.isQQMusic == isQQ && $0.statusRaw == completed
                  }),
                  let url = normalizeCompletedFileNameIfNeeded(for: record) ?? record.localFileURL,
                  FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            return url
        }
        return url
    }
    
    /// 获取所有已下载歌曲
    func fetchAllDownloaded() -> [DownloadedSong] {
        let records = DatabaseManager.shared.store.fetch(
            DownloadedSong.self,
            where: { $0.statusRaw == "completed" },
            sortBy: { ($0.downloadedAt ?? .distantPast) > ($1.downloadedAt ?? .distantPast) }
        )
        for record in records {
            _ = normalizeCompletedFileNameIfNeeded(for: record)
        }
        return records
    }

    func fetchCloudSyncedDownloads() -> [DownloadedSong] {
        fetchDownloadRecords(includingRestored: true)
    }

    func fetchDownloadPlaylistSongs() -> [Song] {
        fetchDownloadRecords(includingRestored: true).map { $0.toSong() }
    }

    func restoreCloudDownloadRecords(_ records: [CloudDownloadRecord]) {
        guard AppConfig.Features.restrictedDownloadEnabled, !records.isEmpty else { return }

        let store = DatabaseManager.shared.store
        let tombstones = DownloadTombstoneStore.shared
        for cloudRecord in records {
            let key = Self.makeKey(for: cloudRecord)

            // 本地明确删除过的条目：云端快照（可能还没同步到删除）不允许复活
            if tombstones.isTombstoned(key: key) || tombstones.isTombstoned(song: cloudRecord.toSong()) {
                continue
            }

            let existing = getDownloadRecord(key: key)

            if existing?.status == .completed, localFileURL(forKey: key) != nil {
                continue
            }

            let target = existing ?? DownloadedSong(
                id: cloudRecord.songId,
                name: cloudRecord.name,
                artistName: cloudRecord.artistName,
                albumName: cloudRecord.albumName,
                coverUrl: cloudRecord.coverUrl,
                duration: cloudRecord.duration,
                quality: cloudRecord.qualityRaw.flatMap(SoundQuality.init(rawValue:)) ?? .exhigh,
                qqMid: cloudRecord.qqMid,
                isQQMusic: cloudRecord.source == MusicSource.qqmusic.rawValue,
                qqQuality: cloudRecord.qqQualityRaw.flatMap(QQMusicQuality.init(rawValue:)),
                isQishui: cloudRecord.source == MusicSource.qishui.rawValue,
                qishuiTrackId: cloudRecord.qishuiTrackId,
                qishuiQualityRaw: cloudRecord.qishuiQualityRaw
            )

            target.uniqueKey = key
            target.name = cloudRecord.name
            target.artistName = cloudRecord.artistName
            target.albumName = cloudRecord.albumName
            target.coverUrl = cloudRecord.coverUrl
            target.duration = cloudRecord.duration
            target.qualityRaw = cloudRecord.qualityRaw ?? target.qualityRaw
            target.qqQualityRaw = cloudRecord.qqQualityRaw
            target.qqMid = cloudRecord.qqMid
            target.isQQMusic = cloudRecord.source == MusicSource.qqmusic.rawValue
            target.isQishui = cloudRecord.source == MusicSource.qishui.rawValue
            target.qishuiTrackId = cloudRecord.qishuiTrackId
            target.qishuiQualityRaw = cloudRecord.qishuiQualityRaw
            target.localPath = nil
            target.fileSize = 0
            target.progress = 0
            target.status = .restored
            target.downloadedAt = cloudRecord.downloadedAt

            if existing == nil {
                store.insert(target)
            }
        }

        store.save()
    }

    func enqueueRestoredDownloadIfNeeded(for song: Song) {
        guard AppConfig.Features.restrictedDownloadEnabled else { return }
        let key = Self.makeKey(for: song)
        guard localFileURL(forKey: key) == nil,
              downloadingTasks[key] == nil,
              !waitingQueue.contains(key),
              let record = getDownloadRecord(key: key),
              record.status == .restored || record.status == .failed else {
            return
        }

        record.status = .waiting
        record.progress = 0
        record.localPath = nil
        record.fileSize = 0
        DatabaseManager.shared.save()
        waitingQueue.append(key)
        AppLogger.info("[DownloadRestore] 本地文件缺失，按原音质重新加入下载队列: \(record.name)")
        processQueue()
    }
    
    /// 获取下载中的歌曲
    func fetchDownloading() -> [DownloadedSong] {
        let completed = DownloadedSong.Status.completed.rawValue
        let restored = DownloadedSong.Status.restored.rawValue
        return DatabaseManager.shared.store.fetch(
            DownloadedSong.self,
            where: { $0.statusRaw != completed && $0.statusRaw != restored },
            sortBy: { $0.createdAt < $1.createdAt }
        )
    }
    
    /// 计算已下载总大小
    func totalDownloadSize() -> Int64 {
        let all = fetchAllDownloaded()
        return all.reduce(0) { $0 + $1.fileSize }
    }

    // MARK: - 内部方法
    
    /// 处理下载队列
    private func processQueue() {
        guard AppConfig.Features.restrictedDownloadEnabled else { return }
        while activeCount < maxConcurrent, let key = waitingQueue.first {
            waitingQueue.removeFirst()
            startDownload(key: key)
        }
    }
    
    /// 开始下载单首歌曲
    private func startDownload(key: String) {
        guard let record = getDownloadRecord(key: key) else { return }
        let songId = record.id
        
        downloadingTasks[key] = DownloadTask(uniqueKey: key, songId: songId, isActive: true)
        
        // 更新数据库状态
        record.status = .downloading
        DatabaseManager.shared.save()
        
        if key.hasPrefix("qishui_") {
            let trackIdStr = key.replacingOccurrences(of: "qishui_", with: "")
            if let trackId = Int(trackIdStr) {
                startQishuiDownload(key: key, trackId: trackId, record: record)
            } else {
                handleDownloadFailed(key: key, reason: "无效的汽水音乐 track ID")
            }
        } else if record.isQQMusic, let mid = record.qqMid {
            startQQDownload(key: key, songId: songId, mid: mid, record: record)
        } else {
            startNeteaseDownload(key: key, songId: songId)
        }
    }
    
    /// 开始ncm歌曲下载
    private func startNeteaseDownload(key: String, songId: Int) {
        let quality = getQuality(key: key)
        apiService.fetchSongUrl(id: songId, level: quality.rawValue, isDownload: true)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self, self.downloadingTasks[key] != nil else { return }
                if case .failure(let error) = completion {
                    AppLogger.error("获取歌曲URL失败: \(error)")
                    self.handleDownloadFailed(
                        key: key,
                        reason: L10n.format(
                            "download_url_failed_format",
                            error.localizedDescription
                        )
                    )
                }
            }, receiveValue: { [weak self] result in
                guard let self = self, self.downloadingTasks[key] != nil else { return }
                guard !result.url.isEmpty, let url = URL(string: result.url) else {
                    self.handleDownloadFailed(key: key, reason: String(localized: "该歌曲暂无此音质的下载链接，请尝试其他音质"))
                    return
                }
                self.downloadFile(key: key, from: url)
            })
            .store(in: &cancellables)
    }
    
    /// 开始 qcm歌曲下载
    private func startQQDownload(key: String, songId: Int, mid: String, record: DownloadedSong?) {
        let quality = record?.qqQuality ?? .mp3_320
        let useDownloadAPI = SettingsManager.shared.qmcDecryptEnabled
        let publisher: AnyPublisher<APIService.SongUrlResult, Error> = useDownloadAPI
            ? apiService.fetchQQDownloadUrl(mid: mid, quality: quality)
            : apiService.fetchQQSongUrl(mid: mid, quality: quality)
        publisher
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self, self.downloadingTasks[key] != nil else { return }
                if case .failure(let error) = completion {
                    AppLogger.error("[QQMusic] 获取下载URL失败: \(error)")
                    self.handleDownloadFailed(key: key, reason: String(localized: "获取下载链接失败，该歌曲可能需要 VIP 或无版权"))
                }
            }, receiveValue: { [weak self] result in
                guard let self = self, self.downloadingTasks[key] != nil else { return }
                guard !result.url.isEmpty, let url = URL(string: result.url) else {
                    self.handleDownloadFailed(key: key, reason: String(localized: "该歌曲暂无此音质的下载链接，请尝试其他音质"))
                    return
                }
                if let ekey = result.qmcEkey {
                    self.downloadingTasks[key]?.qmcEkey = ekey
                }
                self.downloadFile(key: key, from: url)
            })
            .store(in: &cancellables)
    }
    
    /// 开始汽水音乐下载（通过服务端代理，返回已解密的音频）
    private func startQishuiDownload(key: String, trackId: Int, record: DownloadedSong?) {
        let quality = record?.qishuiQualityRaw ?? SettingsManager.shared.defaultQishuiPlaybackQuality
        var proxyURL = APIService.qishuiProxyPlayURL(trackId: trackId, quality: quality)
        let separator = proxyURL.contains("?") ? "&" : "?"
        proxyURL += separator + "_download=1"
        guard let url = URL(string: proxyURL) else {
            handleDownloadFailed(key: key, reason: "无法构建汽水音乐下载 URL")
            return
        }
        AppLogger.info("[Qishui] 开始下载: trackId=\(trackId), quality=\(quality)")
        downloadFile(key: key, from: url)
    }

    /// 下载文件
    private func downloadFile(key: String, from url: URL) {
        guard downloadingTasks[key] != nil else {
            AppLogger.info("下载已取消，跳过: \(key)")
            return
        }
        let task = urlSession.downloadTask(with: url)
        taskToKey[task.taskIdentifier] = key
        progressGate.register(taskID: task.taskIdentifier)
        downloadingTasks[key]?.urlSessionTask = task
        task.resume()
        AppLogger.info("开始下载文件: \(key)")
    }
    
    /// 下载失败处理
    private func handleDownloadFailed(key: String, songName: String? = nil, reason: String? = nil) {
        let songName = songName ?? getDownloadRecord(key: key)?.name ?? key
        downloadingTasks.removeValue(forKey: key)
        if let record = getDownloadRecord(key: key) {
            record.status = .failed
            DatabaseManager.shared.save()
        }
        LocalNotificationService.shared.sendDownloadFailedNotification(songName: songName)
        let msg = reason ?? String(localized: "下载出错，可能是该音质无版权或需要会员")
        lastError = DownloadError(songName: songName, message: msg)
        AlertManager.shared.show(
            title: String(localized: "download_failed_title"),
            message: "\(songName)\n\(msg)",
            primaryButtonTitle: String(localized: "好的"),
            primaryAction: { AlertManager.shared.dismiss() }
        )
        processQueue()
    }
    
    /// 根据音质推断文件扩展名
    private func inferFileExtension(key: String) -> String {
        guard let record = getDownloadRecord(key: key) else { return "mp3" }
        return inferFileExtension(for: record)
    }

    private func inferFileExtension(for record: DownloadedSong) -> String {
        if record.isQQMusic {
            switch record.qqQuality {
            case .flac:                         return "flac"
            case .ogg640, .ogg320, .ogg192, .ogg96: return "ogg"
            case .aac192, .aac96, .aac48:       return "m4a"
            case .master, .dtsx, .atmos71, .atmos2, .atmos51, .nac, .vinyl: return "flac"
            default:                            return "mp3"
            }
        } else {
            switch record.quality {
            case .lossless, .hires, .jymaster:  return "flac"
            case .sky, .jyeffect:               return "flac"
            case .vivid:                        return "mp3"
            default:                            return "mp3"
            }
        }
    }

    private func sanitizedFileNameComponent(_ text: String, fallback: String? = String(localized: "未知歌曲")) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
            .union(.newlines)
            .union(.controlCharacters)
            .union(.illegalCharacters)
        let cleaned = text
            .components(separatedBy: invalidCharacters)
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ."))

        if !cleaned.isEmpty {
            return cleaned
        }
        return fallback ?? ""
    }

    private func preferredBaseFileName(for record: DownloadedSong) -> String {
        let songName = sanitizedFileNameComponent(record.name)
        let artistName = sanitizedFileNameComponent(record.artistName, fallback: nil)

        guard !artistName.isEmpty, artistName != songName else {
            return songName
        }
        return "\(songName) - \(artistName)"
    }

    private func availableDestinationURL(
        for record: DownloadedSong,
        fileExtension: String,
        excluding currentURL: URL? = nil
    ) -> URL {
        let directory = DownloadedSong.downloadsDirectory
        let baseName = preferredBaseFileName(for: record)
        var candidate = directory
            .appendingPathComponent(baseName)
            .appendingPathExtension(fileExtension)

        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path),
              candidate.path != currentURL?.path {
            candidate = directory
                .appendingPathComponent("\(baseName) (\(index))")
                .appendingPathExtension(fileExtension)
            index += 1
        }

        return candidate
    }

    @discardableResult
    private func normalizeCompletedFileNameIfNeeded(for record: DownloadedSong) -> URL? {
        guard record.status == .completed,
              let currentURL = record.localFileURL,
              FileManager.default.fileExists(atPath: currentURL.path) else {
            return nil
        }

        let fileExtension = currentURL.pathExtension.isEmpty ? inferFileExtension(for: record) : currentURL.pathExtension
        let targetURL = availableDestinationURL(for: record, fileExtension: fileExtension, excluding: currentURL)

        guard targetURL.path != currentURL.path else {
            return currentURL
        }

        do {
            try FileManager.default.moveItem(at: currentURL, to: targetURL)
            record.localPath = targetURL.lastPathComponent
            DatabaseManager.shared.save()
            AppLogger.info("已规范下载文件名: \(targetURL.lastPathComponent)")
            return targetURL
        } catch {
            AppLogger.error("规范下载文件名失败: \(error)")
            return currentURL
        }
    }

    /// 下载完成处理
    private func handleDownloadCompleted(key: String, tempURL: URL) {
        guard let record = getDownloadRecord(key: key) else {
            let url = tempURL
            Task.detached(priority: .background) { try? FileManager.default.removeItem(at: url) }
            processQueue()
            return
        }
        
        let ekey = downloadingTasks[key]?.qmcEkey
        var ext = inferFileExtension(key: key)
        if ekey != nil {
            if ext == "mflac" { ext = "flac" }
            else if ext.hasPrefix("mgg") { ext = "ogg" }
        }
        let destURL = availableDestinationURL(for: record, fileExtension: ext)
        
        Task.detached(priority: .userInitiated) { [weak self] in
            var sourceURL = tempURL
            defer { try? FileManager.default.removeItem(at: sourceURL) }
            do {
                let handle = try FileHandle(forReadingFrom: tempURL)
                var prefix = try handle.read(upToCount: 4_096) ?? Data()
                try handle.close()
                if let ekey {
                    let decryptor = try QMCDecryptor.create(ekey: ekey)
                    decryptor.decrypt(&prefix, offset: 0)
                }
                try DownloadResponseValidator.validateMediaPrefix(prefix)
                let decryptEnabled = await MainActor.run { SettingsManager.shared.qmcDecryptEnabled }
                
                if let ekey = ekey, decryptEnabled {
                    AppLogger.info("[QMC] 下载完成，开始解密: \(key)")
                    let decryptor = try QMCDecryptor.create(ekey: ekey)
                    var data = try Data(contentsOf: tempURL)
                    decryptor.decrypt(&data, offset: 0)
                    let decryptedURL = tempURL.deletingPathExtension().appendingPathExtension("dec")
                    try data.write(to: decryptedURL)
                    try? FileManager.default.removeItem(at: tempURL)
                    sourceURL = decryptedURL
                    AppLogger.success("[QMC] 解密完成: \(key)")
                }
                
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: sourceURL, to: destURL)
                
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int64) ?? 0
                
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    if let record = self.getDownloadRecord(key: key) {
                        record.status = .completed
                        record.progress = 1.0
                        record.localPath = destURL.lastPathComponent
                        record.fileSize = fileSize
                        record.downloadedAt = Date()
                        DatabaseManager.shared.save()
                        
                        let songName = record.name
                        LocalNotificationService.shared.sendDownloadCompleteNotification(songName: songName)
                    }
                    
                    self.downloadedSongIds.insert(key)
                    self.downloadingTasks.removeValue(forKey: key)
                    AppLogger.success("下载完成: \(key), 大小=\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
                    
                    self.processQueue()
                    
                    // 触发云端同步（下载记录变更）
                    LocalPlaylistCloudSyncManager.shared.scheduleSyncForLocalMutation()
                }
            } catch {
                AppLogger.error("保存下载文件失败: \(error)")
                await MainActor.run { [weak self] in
                    self?.handleDownloadFailed(key: key, reason: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - 数据库辅助
    
    private func loadDownloadedIds() {
        let records = DatabaseManager.shared.store.fetch(DownloadedSong.self, where: { $0.statusRaw == "completed" })
        downloadedSongIds = Set(
            records.compactMap { record in
                localFileURL(for: record) == nil ? nil : record.uniqueKey
            }
        )
    }

    private func fetchDownloadRecords(includingRestored: Bool) -> [DownloadedSong] {
        let sorted = DatabaseManager.shared.store.fetch(
            DownloadedSong.self,
            sortBy: {
                let lhs = ($0.downloadedAt ?? .distantPast, $0.createdAt)
                let rhs = ($1.downloadedAt ?? .distantPast, $1.createdAt)
                return lhs > rhs
            }
        )
        let allowedStatuses: Set<DownloadedSong.Status> = includingRestored && AppConfig.Features.restrictedDownloadEnabled
            ? [.completed, .restored, .waiting, .downloading]
            : [.completed]
        let records = sorted.filter { record in
            guard allowedStatuses.contains(record.status) else { return false }
            guard record.status == .completed else { return true }
            return localFileURL(for: record) != nil
        }
        for record in records where record.status == .completed {
            _ = normalizeCompletedFileNameIfNeeded(for: record)
        }
        return records
    }
    
    private func getQuality(key: String) -> SoundQuality {
        getDownloadRecord(key: key)?.quality ?? .exhigh
    }
    
    private func getDownloadRecord(key: String) -> DownloadedSong? {
        DatabaseManager.shared.store.first(DownloadedSong.self, where: { $0.uniqueKey == key })
    }

    private func localFileURL(forKey key: String) -> URL? {
        guard let record = getDownloadRecord(key: key) else { return nil }
        return localFileURL(for: record)
    }

    private func localFileURL(for record: DownloadedSong) -> URL? {
        guard let url = normalizeCompletedFileNameIfNeeded(for: record) ?? record.localFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }
    
    private func deleteFromDB(key: String) {
        let store = DatabaseManager.shared.store
        if let record = store.first(DownloadedSong.self, where: { $0.uniqueKey == key }) {
            store.delete(record)
            store.save()
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let taskId = downloadTask.taskIdentifier
        progressGate.remove(taskID: taskId)
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try DownloadResponseValidator.validate(response: downloadTask.response)
            try FileManager.default.copyItem(at: location, to: tempFile)
        } catch {
            let reason = error.localizedDescription
            try? FileManager.default.removeItem(at: tempFile)
            Task { @MainActor [weak self] in
                guard let self, let key = self.taskToKey.removeValue(forKey: taskId) else { return }
                self.handleDownloadFailed(key: key, reason: reason)
            }
            return
        }
        Task { @MainActor [weak self] in
            guard let self, let key = self.taskToKey.removeValue(forKey: taskId) else {
                try? FileManager.default.removeItem(at: tempFile)
                return
            }
            self.handleDownloadCompleted(key: key, tempURL: tempFile)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let taskId = downloadTask.taskIdentifier
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        
        // Filter on the delegate queue before scheduling any UI work.
        guard let rounded = progressGate.accept(progress, taskID: taskId) else { return }
        Task { @MainActor [weak self] in
            guard let self = self, let key = self.taskToKey[taskId] else { return }
            let current = self.downloadingTasks[key]?.progress ?? 0
            guard abs(rounded - current) >= 0.02 || progress >= 1.0 else { return }
            self.downloadingTasks[key]?.progress = rounded
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        progressGate.remove(taskID: task.taskIdentifier)
        guard let error = error else { return }
        let taskId = task.taskIdentifier
        let errorDesc = error.localizedDescription
        
        Task { @MainActor [weak self] in
            guard let self = self, let key = self.taskToKey[taskId] else { return }
            self.taskToKey.removeValue(forKey: taskId)
            AppLogger.error("下载失败: \(key), error=\(errorDesc)")
            let isCancelled = (error as NSError).code == NSURLErrorCancelled
            if !isCancelled {
                self.handleDownloadFailed(
                    key: key,
                    reason: L10n.format("download_network_failed_format", errorDesc)
                )
            } else {
                self.downloadingTasks.removeValue(forKey: key)
                self.processQueue()
            }
        }
    }
}

/// Shared by URLSession's delegate queue and main-actor cancellation.
private final class DownloadProgressGate: @unchecked Sendable {
    private let lock = NSLock()
    private var lastProgress: [Int: Double] = [:]

    func register(taskID: Int) {
        lock.lock()
        defer { lock.unlock() }
        lastProgress[taskID] = 0
    }

    func remove(taskID: Int) {
        lock.lock()
        defer { lock.unlock() }
        lastProgress.removeValue(forKey: taskID)
    }

    func accept(_ progress: Double, taskID: Int) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        guard let previous = lastProgress[taskID] else { return nil }
        let rounded = (progress * 50).rounded() / 50
        guard rounded != previous,
              abs(rounded - previous) >= 0.02 || progress >= 1.0 else { return nil }
        lastProgress[taskID] = rounded
        return rounded
    }
}

// MARK: - 歌词下载

struct DownloadedLyric: Codable, Identifiable, Equatable {
    let id: String
    let songKey: String
    let songId: Int
    let songName: String
    let artistName: String
    let coverURLString: String?
    let source: LyricSource
    let primaryFileName: String
    let translatedFileName: String?
    let fileSize: Int64
    let downloadedAt: Date

    var primaryFileURL: URL {
        LyricDownloadManager.downloadsDirectory.appendingPathComponent(primaryFileName)
    }

    var translatedFileURL: URL? {
        guard let translatedFileName else { return nil }
        return LyricDownloadManager.downloadsDirectory.appendingPathComponent(translatedFileName)
    }

    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

@MainActor
final class LyricDownloadManager: ObservableObject {
    struct ActiveTask: Identifiable, Equatable {
        let id: String
        let songName: String
        let artistName: String
        let coverURLString: String?
        let source: LyricSource
    }

    static let shared = LyricDownloadManager()

    @Published private(set) var records: [DownloadedLyric] = []
    @Published private(set) var activeRecordIDs: Set<String> = []
    @Published private(set) var activeTasks: [String: ActiveTask] = [:]
    @Published var lastError: String?

    nonisolated static var downloadsDirectory: URL {
        let directory = DownloadedSong.downloadsDirectory.appendingPathComponent("Lyrics", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    nonisolated private static var indexURL: URL {
        downloadsDirectory.appendingPathComponent("lyrics-index.json")
    }

    private let lyricViewModel = LyricViewModel.shared

    private init() {
        loadRecords()
    }

    static func offlineLyrics(
        for song: Song,
        source: LyricSource
    ) -> (lyrics: String, translated: String?)? {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([DownloadedLyric].self, from: data),
              let record = decoded.first(where: { $0.id == recordID(for: song, source: source) }),
              let lyrics = try? String(contentsOf: record.primaryFileURL, encoding: .utf8) else {
            return nil
        }
        let translated = record.translatedFileURL.flatMap {
            try? String(contentsOf: $0, encoding: .utf8)
        }
        return (lyrics, translated)
    }

    func record(for song: Song, source: LyricSource? = nil) -> DownloadedLyric? {
        let resolvedSource = source ?? lyricViewModel.selectedSource(for: song)
        let recordID = Self.recordID(for: song, source: resolvedSource)
        return records.first { $0.id == recordID }
    }

    func isDownloading(_ song: Song, source: LyricSource? = nil) -> Bool {
        let resolvedSource = source ?? lyricViewModel.selectedSource(for: song)
        return activeRecordIDs.contains(Self.recordID(for: song, source: resolvedSource))
    }

    func downloadLyrics(for song: Song) async {
        guard AppConfig.Features.restrictedDownloadEnabled else {
            lastError = String(localized: "当前账号不支持下载")
            return
        }

        let source = lyricViewModel.selectedSource(for: song)
        let recordID = Self.recordID(for: song, source: source)
        guard !activeRecordIDs.contains(recordID) else { return }

        if let existing = records.first(where: { $0.id == recordID }),
           FileManager.default.fileExists(atPath: existing.primaryFileURL.path) {
            return
        }

        activeRecordIDs.insert(recordID)
        activeTasks[recordID] = ActiveTask(
            id: recordID,
            songName: song.name,
            artistName: song.artistName,
            coverURLString: song.coverUrl?.absoluteString,
            source: source
        )
        lastError = nil
        defer {
            activeRecordIDs.remove(recordID)
            activeTasks.removeValue(forKey: recordID)
        }

        if lyricViewModel.currentSongId != song.id
            || lyricViewModel.activeSource != source
            || !lyricViewModel.hasLyrics {
            lyricViewModel.fetchLyrics(for: song)
        }

        for _ in 0..<180 {
            if lyricViewModel.currentSongId == song.id,
               lyricViewModel.activeSource == source,
               lyricViewModel.hasLyrics,
               !lyricViewModel.lyrics.isEmpty {
                break
            }
            if !lyricViewModel.isLoading, lyricViewModel.currentSongId == nil {
                break
            }
            try? await Task.sleep(for: .milliseconds(100))
        }

        guard lyricViewModel.currentSongId == song.id,
              lyricViewModel.activeSource == source,
              lyricViewModel.hasLyrics,
              !lyricViewModel.lyrics.isEmpty else {
            lastError = String(localized: "未获取到可下载歌词")
            return
        }

        do {
            try save(
                song: song,
                source: source,
                lines: lyricViewModel.lyrics
            )
            HapticManager.shared.success()
        } catch {
            lastError = String(localized: "歌词保存失败")
            AppLogger.error("[LyricDownload] 保存失败: \(error.localizedDescription)")
        }
    }

    func delete(_ record: DownloadedLyric) {
        try? FileManager.default.removeItem(at: record.primaryFileURL)
        if let translatedFileURL = record.translatedFileURL {
            try? FileManager.default.removeItem(at: translatedFileURL)
        }
        records.removeAll { $0.id == record.id }
        persistRecords()
    }

    func deleteAll() {
        for record in records {
            try? FileManager.default.removeItem(at: record.primaryFileURL)
            if let translatedFileURL = record.translatedFileURL {
                try? FileManager.default.removeItem(at: translatedFileURL)
            }
        }
        records.removeAll()
        persistRecords()
    }

    func totalDownloadSize() -> Int64 {
        records.reduce(0) { $0 + $1.fileSize }
    }

    private func save(song: Song, source: LyricSource, lines: [LyricLine]) throws {
        let recordID = Self.recordID(for: song, source: source)
        let safeName = Self.safeFileComponent("\(song.name)-\(song.artistName)")
        let fileStem = "\(Self.songKey(for: song))-\(source.rawValue)-\(safeName)"
        let primaryFileName = "\(fileStem).qrc"
        let translatedFileName = lines.contains(where: { !($0.translation ?? "").isEmpty })
            ? "\(fileStem)-translation.lrc"
            : nil

        let primaryText = Self.makeTimedLyrics(from: lines)
        let primaryData = Data(primaryText.utf8)
        let primaryURL = Self.downloadsDirectory.appendingPathComponent(primaryFileName)
        try primaryData.write(to: primaryURL, options: .atomic)

        var fileSize = Int64(primaryData.count)
        if let translatedFileName {
            let translatedText = Self.makeTranslations(from: lines)
            let translatedData = Data(translatedText.utf8)
            try translatedData.write(
                to: Self.downloadsDirectory.appendingPathComponent(translatedFileName),
                options: .atomic
            )
            fileSize += Int64(translatedData.count)
        }

        OptimizedCacheManager.shared.cacheLyrics(
            songId: song.id,
            source: song.musicSource,
            lyrics: primaryText,
            translated: translatedFileName == nil ? nil : Self.makeTranslations(from: lines)
        )

        let record = DownloadedLyric(
            id: recordID,
            songKey: Self.songKey(for: song),
            songId: song.id,
            songName: song.name,
            artistName: song.artistName,
            coverURLString: song.coverUrl?.absoluteString,
            source: source,
            primaryFileName: primaryFileName,
            translatedFileName: translatedFileName,
            fileSize: fileSize,
            downloadedAt: Date()
        )

        records.removeAll { $0.id == record.id }
        records.insert(record, at: 0)
        persistRecords()
        AppLogger.info("[LyricDownload] 已保存歌词: \(song.name) source=\(source.rawValue)")
    }

    private func loadRecords() {
        guard let data = try? Data(contentsOf: Self.indexURL),
              let decoded = try? JSONDecoder().decode([DownloadedLyric].self, from: data) else {
            records = []
            return
        }
        records = decoded
            .filter { FileManager.default.fileExists(atPath: $0.primaryFileURL.path) }
            .sorted { $0.downloadedAt > $1.downloadedAt }
        persistRecords()
    }

    private func persistRecords() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: Self.indexURL, options: .atomic)
    }

    private static func songKey(for song: Song) -> String {
        if song.isQishui, let trackId = song.qishuiTrackId {
            return "qishui_\(trackId)"
        }
        return "\(song.musicSource.rawValue)_\(song.id)"
    }

    private static func recordID(for song: Song, source: LyricSource) -> String {
        "\(songKey(for: song))_\(source.rawValue)"
    }

    private static func safeFileComponent(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        let sanitized = value.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(sanitized.prefix(80)).isEmpty ? "lyrics" : String(sanitized.prefix(80))
    }

    private static func makeTimedLyrics(from lines: [LyricLine]) -> String {
        lines.enumerated().map { index, line in
            let start = max(0, Int((line.time * 1000).rounded()))
            let words = line.words.filter { !$0.text.isEmpty && $0.duration > 0 }
            let nextLineDuration = lines.indices.contains(index + 1)
                ? max(0, lines[index + 1].time - line.time)
                : 5
            let wordDuration = words.last.map { max(0, $0.startTime + $0.duration - line.time) } ?? 0
            let resolvedDuration = line.duration > 0.05
                ? line.duration
                : max(nextLineDuration, wordDuration, 0.5)
            let duration = max(1, Int((resolvedDuration * 1000).rounded()))
            if words.isEmpty {
                return "[\(start),\(duration)]\(qrcSafeText(line.text))(\(start),\(duration))"
            }
            let content = words.map { word in
                let wordStart = max(0, Int((word.startTime * 1000).rounded()))
                let wordDuration = max(1, Int((word.duration * 1000).rounded()))
                return "\(qrcSafeText(word.text))(\(wordStart),\(wordDuration))"
            }.joined()
            return "[\(start),\(duration)]\(content)"
        }.joined(separator: "\n")
    }

    private static func qrcSafeText(_ text: String) -> String {
        text.replacingOccurrences(of: "(", with: "（")
            .replacingOccurrences(of: ")", with: "）")
    }

    private static func makeTranslations(from lines: [LyricLine]) -> String {
        lines.compactMap { line in
            guard let translation = line.translation?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !translation.isEmpty else { return nil }
            let minutes = Int(line.time) / 60
            let seconds = line.time - Double(minutes * 60)
            return String(format: "[%02d:%05.2f]%@", minutes, seconds, translation)
        }.joined(separator: "\n")
    }
}
