import Foundation
import Combine
import SwiftData
import QQMusicKit

/// 音乐下载管理器
@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    
    // MARK: - 发布属性
    @Published var downloadingTasks: [String: DownloadTask] = [:]  // uniqueKey -> task
    @Published var downloadedSongIds: Set<String> = []  // uniqueKey 集合
    
    /// 最大并发下载数
    private let maxConcurrent = 3
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
    }
    
    // MARK: - URLSession
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 600 // 10分钟超时
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    /// taskIdentifier -> uniqueKey 映射（用于 delegate 回调）
    private var taskToKey: [Int: String] = [:]
    
    private override init() {
        super.init()
        // 启动时加载已下载歌曲 ID
        Task { loadDownloadedIds() }
    }

    /// 生成 uniqueKey
    private static func makeKey(songId: Int, isQQ: Bool) -> String {
        isQQ ? "qq_\(songId)" : "ncm_\(songId)"
    }
    
    // MARK: - 公开方法
    
    /// 下载歌曲
    func download(song: Song, quality: SoundQuality? = nil) {
        let key = Self.makeKey(songId: song.id, isQQ: song.isQQMusic)
        
        // 已下载或正在下载则跳过
        guard !downloadedSongIds.contains(key),
              downloadingTasks[key] == nil,
              !waitingQueue.contains(key) else {
            AppLogger.debug("歌曲 \(key) 已下载或正在下载中")
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
        waitingQueue.append(key)
        AppLogger.info("歌曲加入下载队列: \(song.name)")
        
        // 尝试启动下载
        processQueue()
    }
    
    /// 下载 QQ 音乐歌曲（指定 QQ 音质）
    func downloadQQ(song: Song, quality: QQMusicQuality) {
        let key = Self.makeKey(songId: song.id, isQQ: true)
        
        guard !downloadedSongIds.contains(key),
              downloadingTasks[key] == nil,
              !waitingQueue.contains(key) else {
            AppLogger.debug("歌曲 \(key) 已下载或正在下载中")
            return
        }
        
        let context = DatabaseManager.shared.context
        let downloaded = DownloadedSong(from: song, qqQuality: quality)
        context.insert(downloaded)
        try? context.save()
        
        waitingQueue.append(key)
        AppLogger.info("[QQMusic] 歌曲加入下载队列: \(song.name)")
        processQueue()
    }
    
    /// 取消下载
    func cancelDownload(songId: Int, isQQ: Bool = false) {
        let key = Self.makeKey(songId: songId, isQQ: isQQ)
        
        // 取消活跃任务
        if let task = downloadingTasks[key] {
            task.urlSessionTask?.cancel()
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
        let key = Self.makeKey(songId: songId, isQQ: isQQ)
        
        // 删除本地文件
        if let url = localFileURL(songId: songId, isQQ: isQQ) {
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
    }
    
    /// 删除所有下载
    func deleteAll() {
        // 取消所有进行中的任务
        for (_, task) in downloadingTasks {
            task.urlSessionTask?.cancel()
        }
        downloadingTasks.removeAll()
        waitingQueue.removeAll()
        
        // 删除下载目录（包含所有音频文件）
        let dir = DownloadedSong.downloadsDirectory
        let fm = FileManager.default
        
        // 先逐个删除文件（确保即使目录删除失败，文件也被清理）
        if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for file in files {
                do {
                    try fm.removeItem(at: file)
                } catch {
                    AppLogger.error("删除下载文件失败: \(file.lastPathComponent), error=\(error)")
                }
            }
        }
        
        // 再删除整个目录并重建
        do {
            if fm.fileExists(atPath: dir.path) {
                try fm.removeItem(at: dir)
            }
        } catch {
            AppLogger.error("删除下载目录失败: \(error)")
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        
        // 清空数据库中的下载记录
        let context = DatabaseManager.shared.context
        do {
            try context.delete(model: DownloadedSong.self)
            try context.save()
        } catch {
            AppLogger.error("清空下载数据库失败: \(error)")
        }
        
        downloadedSongIds.removeAll()
        
        // 验证清理结果
        #if DEBUG
        let remaining = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?.count ?? 0
        print("[DownloadManager] 清理完成，下载目录剩余文件: \(remaining)")
        #endif
        
        AppLogger.info("已清除所有下载")
    }
    
    /// 检查是否已下载（兼容旧调用，同时检查 ncm 和 qq 两个 key）
    func isDownloaded(songId: Int) -> Bool {
        downloadedSongIds.contains("ncm_\(songId)") || downloadedSongIds.contains("qq_\(songId)")
    }
    
    /// 获取本地文件 URL
    func localFileURL(songId: Int, isQQ: Bool = false) -> URL? {
        let key = Self.makeKey(songId: songId, isQQ: isQQ)
        let context = DatabaseManager.shared.context
        let completed = "completed"
        var descriptor = FetchDescriptor<DownloadedSong>(
            predicate: #Predicate { $0.uniqueKey == key && $0.statusRaw == completed }
        )
        descriptor.fetchLimit = 1
        guard let record = try? context.fetch(descriptor).first,
              let url = record.localFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            // 回退：按 songId 查找（兼容旧数据）
            var fallback = FetchDescriptor<DownloadedSong>(
                predicate: #Predicate { $0.id == songId && $0.statusRaw == completed }
            )
            fallback.fetchLimit = 1
            guard let record = try? context.fetch(fallback).first,
                  let url = record.localFileURL,
                  FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            return url
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
        try? DatabaseManager.shared.context.save()
        
        if record.isQQMusic, let mid = record.qqMid {
            startQQDownload(key: key, songId: songId, mid: mid, record: record)
        } else {
            startNeteaseDownload(key: key, songId: songId)
        }
    }
    
    /// 开始网易云歌曲下载
    private func startNeteaseDownload(key: String, songId: Int) {
        let quality = getQuality(key: key)
        apiService.fetchSongUrl(id: songId, level: quality.rawValue)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("获取歌曲URL失败: \(error)")
                    self?.handleDownloadFailed(key: key)
                }
            }, receiveValue: { [weak self] result in
                guard let self = self, let url = URL(string: result.url) else {
                    self?.handleDownloadFailed(key: key)
                    return
                }
                self.downloadFile(key: key, from: url)
            })
            .store(in: &cancellables)
    }
    
    /// 开始 QQ 音乐歌曲下载
    private func startQQDownload(key: String, songId: Int, mid: String, record: DownloadedSong?) {
        let quality = record?.qqQuality ?? .mp3_320
        apiService.fetchQQSongUrl(mid: mid, quality: quality)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("[QQMusic] 获取下载URL失败: \(error)")
                    self?.handleDownloadFailed(key: key)
                }
            }, receiveValue: { [weak self] result in
                guard let self = self, let url = URL(string: result.url) else {
                    self?.handleDownloadFailed(key: key)
                    return
                }
                self.downloadFile(key: key, from: url)
            })
            .store(in: &cancellables)
    }
    
    /// 下载文件
    private func downloadFile(key: String, from url: URL) {
        let task = urlSession.downloadTask(with: url)
        taskToKey[task.taskIdentifier] = key
        downloadingTasks[key]?.urlSessionTask = task
        task.resume()
        AppLogger.info("开始下载文件: \(key)")
    }
    
    /// 下载失败处理
    private func handleDownloadFailed(key: String) {
        downloadingTasks.removeValue(forKey: key)
        if let record = getDownloadRecord(key: key) {
            record.status = .failed
            try? DatabaseManager.shared.context.save()
        }
        processQueue()
    }
    
    /// 根据音质推断文件扩展名
    private func inferFileExtension(key: String) -> String {
        guard let record = getDownloadRecord(key: key) else { return "mp3" }
        if record.isQQMusic {
            switch record.qqQuality {
            case .flac:                         return "flac"
            case .ogg640, .ogg320, .ogg192, .ogg96: return "ogg"
            case .aac192, .aac96, .aac48:       return "m4a"
            case .master, .atmos2, .atmos51:    return "flac"
            default:                            return "mp3"
            }
        } else {
            switch record.quality {
            case .lossless, .hires, .jymaster:  return "flac"
            case .sky, .jyeffect:               return "flac"
            default:                            return "mp3"
            }
        }
    }
    
    /// 下载完成处理
    private func handleDownloadCompleted(key: String, tempURL: URL) {
        guard let record = getDownloadRecord(key: key) else {
            try? FileManager.default.removeItem(at: tempURL)
            processQueue()
            return
        }
        let ext = inferFileExtension(key: key)
        // 文件名用 uniqueKey 避免冲突
        let fileName = "\(key).\(ext)"
        let destURL = DownloadedSong.downloadsDirectory.appendingPathComponent(fileName)
        
        do {
            // 如果已存在则先删除
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: destURL)
            
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int64) ?? 0
            
            // 更新数据库
            record.status = .completed
            record.progress = 1.0
            record.localPath = fileName
            record.fileSize = fileSize
            record.downloadedAt = Date()
            try? DatabaseManager.shared.context.save()
            
            downloadedSongIds.insert(key)
            downloadingTasks.removeValue(forKey: key)
            AppLogger.success("下载完成: \(key), 大小=\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
            
        } catch {
            AppLogger.error("保存下载文件失败: \(error)")
            handleDownloadFailed(key: key)
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
            downloadedSongIds = Set(records.map { $0.uniqueKey })
        }
    }
    
    private func getQuality(key: String) -> SoundQuality {
        getDownloadRecord(key: key)?.quality ?? .exhigh
    }
    
    private func getDownloadRecord(key: String) -> DownloadedSong? {
        let context = DatabaseManager.shared.context
        var descriptor = FetchDescriptor<DownloadedSong>(
            predicate: #Predicate { $0.uniqueKey == key }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
    
    private func deleteFromDB(key: String) {
        let context = DatabaseManager.shared.context
        var descriptor = FetchDescriptor<DownloadedSong>(
            predicate: #Predicate { $0.uniqueKey == key }
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
            guard let self = self, let key = self.taskToKey[taskId] else { return }
            self.taskToKey.removeValue(forKey: taskId)
            self.handleDownloadCompleted(key: key, tempURL: tempFile)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let taskId = downloadTask.taskIdentifier
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        
        Task { @MainActor [weak self] in
            guard let self = self, let key = self.taskToKey[taskId] else { return }
            self.downloadingTasks[key]?.progress = progress
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        let taskId = task.taskIdentifier
        
        Task { @MainActor [weak self] in
            guard let self = self, let key = self.taskToKey[taskId] else { return }
            self.taskToKey.removeValue(forKey: taskId)
            AppLogger.error("下载失败: \(key), error=\(error.localizedDescription)")
            self.handleDownloadFailed(key: key)
        }
    }
}
