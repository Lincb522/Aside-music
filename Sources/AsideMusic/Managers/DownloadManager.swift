import Foundation
import Combine
import SwiftData
import QQMusicKit

/// 音乐下载管理器
@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    
    // MARK: - 发布属性
    @Published var downloadingTasks: [Int: DownloadTask] = [:]  // songId -> task
    @Published var downloadedSongIds: Set<Int> = []
    
    /// 最大并发下载数
    private let maxConcurrent = 3
    /// 等待队列
    private var waitingQueue: [Int] = []
    /// 活跃下载数
    private var activeCount: Int { downloadingTasks.values.filter { $0.isActive }.count }
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// 下载任务包装
    struct DownloadTask {
        let songId: Int
        var urlSessionTask: URLSessionDownloadTask?
        var progress: Double = 0
        var isActive: Bool = false
    }
    
    // MARK: - URLSession
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 600 // 10分钟超时
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    /// songId -> URLSessionDownloadTask 映射（用于 delegate 回调）
    private var taskToSongId: [Int: Int] = [:] // taskIdentifier -> songId
    
    private override init() {
        super.init()
        // 启动时加载已下载歌曲 ID
        Task { await loadDownloadedIds() }
    }

    // MARK: - 公开方法
    
    /// 下载歌曲
    func download(song: Song, quality: SoundQuality? = nil) {
        let songId = song.id
        
        // 已下载或正在下载则跳过
        guard !downloadedSongIds.contains(songId),
              downloadingTasks[songId] == nil,
              !waitingQueue.contains(songId) else {
            AppLogger.debug("歌曲 \(songId) 已下载或正在下载中")
            return
        }
        
        // 保存到数据库（区分 QQ 音乐和网易云）
        let context = DatabaseManager.shared.context
        if song.isQQMusic {
            let qqQuality = PlayerManager.shared.qqMusicQuality
            let downloaded = DownloadedSong(from: song, qqQuality: qqQuality)
            context.insert(downloaded)
        } else {
            let targetQuality = quality ?? SoundQuality(rawValue: SettingsManager.shared.defaultDownloadQuality) ?? .standard
            let downloaded = DownloadedSong(from: song, quality: targetQuality)
            context.insert(downloaded)
        }
        try? context.save()
        
        // 加入队列
        waitingQueue.append(songId)
        AppLogger.info("歌曲加入下载队列: \(song.name)")
        
        // 尝试启动下载
        processQueue()
    }
    
    /// 下载 QQ 音乐歌曲（指定 QQ 音质）
    func downloadQQ(song: Song, quality: QQMusicQuality) {
        let songId = song.id
        
        guard !downloadedSongIds.contains(songId),
              downloadingTasks[songId] == nil,
              !waitingQueue.contains(songId) else {
            AppLogger.debug("歌曲 \(songId) 已下载或正在下载中")
            return
        }
        
        let context = DatabaseManager.shared.context
        let downloaded = DownloadedSong(from: song, qqQuality: quality)
        context.insert(downloaded)
        try? context.save()
        
        waitingQueue.append(songId)
        AppLogger.info("[QQMusic] 歌曲加入下载队列: \(song.name)")
        processQueue()
    }
    
    /// 取消下载
    func cancelDownload(songId: Int) {
        // 取消活跃任务
        if let task = downloadingTasks[songId] {
            task.urlSessionTask?.cancel()
            downloadingTasks.removeValue(forKey: songId)
        }
        
        // 从等待队列移除
        waitingQueue.removeAll { $0 == songId }
        
        // 从数据库删除
        deleteFromDB(songId: songId)
        
        AppLogger.info("取消下载: \(songId)")
        processQueue()
    }
    
    /// 删除已下载歌曲
    func deleteDownload(songId: Int) {
        // 删除本地文件
        if let url = localFileURL(songId: songId) {
            try? FileManager.default.removeItem(at: url)
        }
        
        // 从数据库删除
        deleteFromDB(songId: songId)
        downloadedSongIds.remove(songId)
        
        AppLogger.info("删除下载: \(songId)")
    }
    
    /// 删除所有下载
    func deleteAll() {
        // 取消所有进行中的任务
        for (_, task) in downloadingTasks {
            task.urlSessionTask?.cancel()
        }
        downloadingTasks.removeAll()
        waitingQueue.removeAll()
        
        // 删除下载目录
        let dir = DownloadedSong.downloadsDirectory
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        // 清空数据库
        let context = DatabaseManager.shared.context
        let descriptor = FetchDescriptor<DownloadedSong>()
        if let all = try? context.fetch(descriptor) {
            for item in all { context.delete(item) }
            try? context.save()
        }
        
        downloadedSongIds.removeAll()
        AppLogger.info("已清除所有下载")
    }
    
    /// 检查是否已下载
    func isDownloaded(songId: Int) -> Bool {
        downloadedSongIds.contains(songId)
    }
    
    /// 获取本地文件 URL
    func localFileURL(songId: Int) -> URL? {
        let context = DatabaseManager.shared.context
        var descriptor = FetchDescriptor<DownloadedSong>(
            predicate: #Predicate { $0.id == songId && $0.statusRaw == "completed" }
        )
        descriptor.fetchLimit = 1
        guard let record = try? context.fetch(descriptor).first,
              let url = record.localFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }
    
    /// 获取所有已下载歌曲
    func fetchAllDownloaded() -> [DownloadedSong] {
        let context = DatabaseManager.shared.context
        let descriptor = FetchDescriptor<DownloadedSong>(
            predicate: #Predicate { $0.statusRaw == "completed" },
            sortBy: [SortDescriptor(\.downloadedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// 获取下载中的歌曲
    func fetchDownloading() -> [DownloadedSong] {
        let context = DatabaseManager.shared.context
        let descriptor = FetchDescriptor<DownloadedSong>(
            predicate: #Predicate { $0.statusRaw != "completed" },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// 计算已下载总大小
    func totalDownloadSize() -> Int64 {
        let all = fetchAllDownloaded()
        return all.reduce(0) { $0 + $1.fileSize }
    }

    // MARK: - 内部方法
    
    /// 处理下载队列
    private func processQueue() {
        while activeCount < maxConcurrent, let songId = waitingQueue.first {
            waitingQueue.removeFirst()
            startDownload(songId: songId)
        }
    }
    
    /// 开始下载单首歌曲
    private func startDownload(songId: Int) {
        downloadingTasks[songId] = DownloadTask(songId: songId, isActive: true)
        
        // 更新数据库状态
        updateDBStatus(songId: songId, status: .downloading)
        
        // 查询数据库获取歌曲信息
        let record = getDownloadRecord(songId: songId)
        
        if record?.isQQMusic == true, let mid = record?.qqMid {
            // QQ 音乐歌曲：使用 QQ 音乐 API 获取 URL
            startQQDownload(songId: songId, mid: mid, record: record)
        } else {
            // 网易云歌曲：使用网易云 API 获取 URL
            startNeteaseDownload(songId: songId)
        }
    }
    
    /// 开始网易云歌曲下载
    private func startNeteaseDownload(songId: Int) {
        let quality = getQuality(songId: songId)
        apiService.fetchSongUrl(id: songId, level: quality.rawValue)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("获取歌曲URL失败: \(error)")
                    self?.handleDownloadFailed(songId: songId)
                }
            }, receiveValue: { [weak self] result in
                guard let self = self, let url = URL(string: result.url) else {
                    self?.handleDownloadFailed(songId: songId)
                    return
                }
                self.downloadFile(songId: songId, from: url)
            })
            .store(in: &cancellables)
    }
    
    /// 开始 QQ 音乐歌曲下载
    private func startQQDownload(songId: Int, mid: String, record: DownloadedSong?) {
        let quality = record?.qqQuality ?? .mp3_320
        apiService.fetchQQSongUrl(mid: mid, quality: quality)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("[QQMusic] 获取下载URL失败: \(error)")
                    self?.handleDownloadFailed(songId: songId)
                }
            }, receiveValue: { [weak self] result in
                guard let self = self, let url = URL(string: result.url) else {
                    self?.handleDownloadFailed(songId: songId)
                    return
                }
                self.downloadFile(songId: songId, from: url)
            })
            .store(in: &cancellables)
    }
    
    /// 下载文件
    private func downloadFile(songId: Int, from url: URL) {
        let task = urlSession.downloadTask(with: url)
        taskToSongId[task.taskIdentifier] = songId
        downloadingTasks[songId]?.urlSessionTask = task
        task.resume()
        AppLogger.info("开始下载文件: songId=\(songId)")
    }
    
    /// 下载失败处理
    private func handleDownloadFailed(songId: Int) {
        downloadingTasks.removeValue(forKey: songId)
        updateDBStatus(songId: songId, status: .failed)
        processQueue()
    }
    
    /// 下载完成处理
    private func handleDownloadCompleted(songId: Int, tempURL: URL) {
        let fileName = "\(songId).mp3"
        let destURL = DownloadedSong.downloadsDirectory.appendingPathComponent(fileName)
        
        do {
            // 如果已存在则先删除
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: destURL)
            
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int64) ?? 0
            
            // 更新数据库
            let context = DatabaseManager.shared.context
            var descriptor = FetchDescriptor<DownloadedSong>(
                predicate: #Predicate { $0.id == songId }
            )
            descriptor.fetchLimit = 1
            if let record = try? context.fetch(descriptor).first {
                record.status = .completed
                record.progress = 1.0
                record.localPath = fileName
                record.fileSize = fileSize
                record.downloadedAt = Date()
                try? context.save()
            }
            
            downloadedSongIds.insert(songId)
            downloadingTasks.removeValue(forKey: songId)
            AppLogger.success("下载完成: songId=\(songId), 大小=\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
            
        } catch {
            AppLogger.error("保存下载文件失败: \(error)")
            handleDownloadFailed(songId: songId)
        }
        
        processQueue()
    }
    
    // MARK: - 数据库辅助
    
    private func loadDownloadedIds() {
        let context = DatabaseManager.shared.context
        let descriptor = FetchDescriptor<DownloadedSong>(
            predicate: #Predicate { $0.statusRaw == "completed" }
        )
        if let records = try? context.fetch(descriptor) {
            downloadedSongIds = Set(records.map { $0.id })
        }
    }
    
    private func updateDBStatus(songId: Int, status: DownloadedSong.Status) {
        let context = DatabaseManager.shared.context
        var descriptor = FetchDescriptor<DownloadedSong>(
            predicate: #Predicate { $0.id == songId }
        )
        descriptor.fetchLimit = 1
        if let record = try? context.fetch(descriptor).first {
            record.status = status
            try? context.save()
        }
    }
    
    private func updateDBProgress(songId: Int, progress: Double) {
        let context = DatabaseManager.shared.context
        var descriptor = FetchDescriptor<DownloadedSong>(
            predicate: #Predicate { $0.id == songId }
        )
        descriptor.fetchLimit = 1
        if let record = try? context.fetch(descriptor).first {
            record.progress = progress
            try? context.save()
        }
    }
    
    private func getQuality(songId: Int) -> SoundQuality {
        let context = DatabaseManager.shared.context
        var descriptor = FetchDescriptor<DownloadedSong>(
            predicate: #Predicate { $0.id == songId }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor).first)?.quality ?? .exhigh
    }
    
    private func getDownloadRecord(songId: Int) -> DownloadedSong? {
        let context = DatabaseManager.shared.context
        var descriptor = FetchDescriptor<DownloadedSong>(
            predicate: #Predicate { $0.id == songId }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
    
    private func deleteFromDB(songId: Int) {
        let context = DatabaseManager.shared.context
        var descriptor = FetchDescriptor<DownloadedSong>(
            predicate: #Predicate { $0.id == songId }
        )
        descriptor.fetchLimit = 1
        if let record = try? context.fetch(descriptor).first {
            context.delete(record)
            try? context.save()
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let taskId = downloadTask.taskIdentifier
        // 复制临时文件到安全位置（临时文件会被系统删除）
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".tmp")
        try? FileManager.default.copyItem(at: location, to: tempFile)
        
        Task { @MainActor [weak self] in
            guard let self = self, let songId = self.taskToSongId[taskId] else { return }
            self.taskToSongId.removeValue(forKey: taskId)
            self.handleDownloadCompleted(songId: songId, tempURL: tempFile)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let taskId = downloadTask.taskIdentifier
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        
        Task { @MainActor [weak self] in
            guard let self = self, let songId = self.taskToSongId[taskId] else { return }
            self.downloadingTasks[songId]?.progress = progress
            // 每 5% 更新一次数据库，避免频繁写入
            if Int(progress * 100) % 5 == 0 {
                self.updateDBProgress(songId: songId, progress: progress)
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        let taskId = task.taskIdentifier
        
        Task { @MainActor [weak self] in
            guard let self = self, let songId = self.taskToSongId[taskId] else { return }
            self.taskToSongId.removeValue(forKey: taskId)
            AppLogger.error("下载失败: songId=\(songId), error=\(error.localizedDescription)")
            self.handleDownloadFailed(songId: songId)
        }
    }
}
