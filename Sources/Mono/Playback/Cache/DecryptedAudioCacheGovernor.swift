// QMC/汽水解密产物的磁盘治理（LRU）。
// 解密产物落在 tmp，单文件可达几十上百 MB；系统只在磁盘紧张时才回收 tmp，
// 长时间听无损会膨胀到 GB 级。这里按 LRU 控制总量：正在使用的输入显式保护，
// 近期触碰过的文件靠时间窗兜底。
// 同时集中管理两个缓存目录与 QMC 缓存文件的命名规则，供取址管线与无缝引擎共用。

import Foundation

@MainActor
final class DecryptedAudioCacheGovernor {

    unowned let player: PlayerManager

    init(player: PlayerManager) {
        self.player = player
    }

    /// QMC/汽水解密缓存的容量策略。
    private enum Policy {
        static let limitBytes: Int64 = 512 * 1024 * 1024
        static let targetBytes: Int64 = 384 * 1024 * 1024
        static let sweepInterval: TimeInterval = 10 * 60
        /// 近期触碰过的文件视为在用（当前曲目 / 预取中的下一曲），不参与清理。
        static let recentUseProtection: TimeInterval = 30 * 60
    }

    private var lastSweepAt: Date = .distantPast

    // MARK: - 缓存目录

    nonisolated static let qishuiCacheDir: URL = {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("qishui_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    nonisolated static let qmcCacheDir: URL = {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("qmc_decrypted", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - QMC 缓存文件命名与查找

    nonisolated static func qmcCacheBaseName(for song: Song) -> String {
        PlayerManager.playbackIdentityKey(for: song)
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "/", with: "_")
    }

    nonisolated static func qmcCacheURL(for song: Song, extension ext: String) -> URL {
        qmcCacheDir.appendingPathComponent("\(qmcCacheBaseName(for: song)).\(ext)")
    }

    nonisolated static func cachedQMCFileURL(for song: Song) -> URL? {
        for ext in ["flac", "ogg"] {
            let scopedURL = qmcCacheURL(for: song, extension: ext)
            if FileManager.default.fileExists(atPath: scopedURL.path) {
                touchCacheFile(at: scopedURL)
                return scopedURL
            }

            let legacyURL = qmcCacheDir.appendingPathComponent("\(song.id).\(ext)")
            if FileManager.default.fileExists(atPath: legacyURL.path) {
                if (try? FileManager.default.moveItem(at: legacyURL, to: scopedURL)) != nil {
                    touchCacheFile(at: scopedURL)
                    return scopedURL
                }
                touchCacheFile(at: legacyURL)
                return legacyURL
            }
        }
        return nil
    }

    /// 缓存命中时刷新触碰时间，让 LRU 排序反映真实使用顺序。
    nonisolated static func touchCacheFile(at url: URL) {
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: url.path
        )
    }

    // MARK: - LRU 清理

    func scheduleCleanup(force: Bool = false) {
        let now = Date()
        guard force
                || now.timeIntervalSince(lastSweepAt) >= Policy.sweepInterval else { return }
        lastSweepAt = now

        var protectedNames = Set<String>()
        let activeInputs = [
            player.currentPlayingURL,
            player.continuity.pendingGaplessPlaybackInput,
            player.pendingPlaybackPresentationInput
        ]
        for input in activeInputs {
            guard let input, !input.isEmpty else { continue }
            let name = (input as NSString).lastPathComponent
            if !name.isEmpty { protectedNames.insert(name) }
        }
        let directories = [Self.qishuiCacheDir, Self.qmcCacheDir]
        Task.detached(priority: .utility) {
            DecryptedAudioCacheGovernor.sweep(
                directories: directories,
                protectedFileNames: protectedNames
            )
        }
    }

    /// 后台线程执行：只做文件系统读取与删除，不触碰播放状态。
    nonisolated private static func sweep(
        directories: [URL],
        protectedFileNames: Set<String>
    ) {
        struct CacheEntry {
            let url: URL
            let size: Int64
            let lastUsedAt: Date
        }

        let fileManager = FileManager.default
        var entries: [CacheEntry] = []
        for directory in directories {
            guard let urls = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in urls {
                guard let values = try? url.resourceValues(
                    forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
                ), values.isRegularFile == true else { continue }
                entries.append(CacheEntry(
                    url: url,
                    size: Int64(values.fileSize ?? 0),
                    lastUsedAt: values.contentModificationDate ?? .distantPast
                ))
            }
        }

        let totalBytes = entries.reduce(Int64(0)) { $0 + $1.size }
        guard totalBytes > Policy.limitBytes else { return }

        let recentCutoff = Date().addingTimeInterval(-Policy.recentUseProtection)
        let deletable = entries
            .filter { $0.lastUsedAt < recentCutoff && !protectedFileNames.contains($0.url.lastPathComponent) }
            .sorted { $0.lastUsedAt < $1.lastUsedAt }

        var remainingBytes = totalBytes
        var removedBytes: Int64 = 0
        var removedCount = 0
        for entry in deletable {
            guard remainingBytes > Policy.targetBytes else { break }
            do {
                try fileManager.removeItem(at: entry.url)
            } catch {
                continue
            }
            remainingBytes -= entry.size
            removedBytes += entry.size
            removedCount += 1
        }
        if removedCount > 0 {
            AppLogger.info(
                "[PlaybackCache] 解密缓存 LRU 清理 removed=\(removedCount) freed=\(removedBytes / 1_048_576)MB before=\(totalBytes / 1_048_576)MB target=\(Policy.targetBytes / 1_048_576)MB",
                step: "playback.cache.sweep"
            )
        }
    }
}

// MARK: - PlayerManager facade（引擎调用点保持不变）

extension PlayerManager {

    func scheduleDecryptedAudioCacheCleanup(force: Bool = false) {
        cacheGovernor.scheduleCleanup(force: force)
    }
}
