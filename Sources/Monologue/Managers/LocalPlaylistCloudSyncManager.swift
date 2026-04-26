import Foundation
import Combine
import UIKit

@MainActor
final class LocalPlaylistCloudSyncManager: ObservableObject {
    static let shared = LocalPlaylistCloudSyncManager()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastStatusMessage: String?
    @Published private(set) var lastSyncedAt: Date?

    private let playlistManager = LocalPlaylistManager.shared
    private let accessManager = OnlineAccessManager.shared
    private let settings = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var hasBootstrappedCurrentToken = false
    private var currentTokenFingerprint: String?
    private var isApplyingRemoteSnapshot = false
    private var lastObservedDigest: String
    private var lastRemoteRevision: String?
    private var pendingUploadDigest: String?
    private var uploadRetryTask: Task<Void, Never>?

    // MARK: - Upload Throttling
    //
    // 背景：线上监测到单设备每 1-2 秒发起一次 PUT 上报（单机 12k+ 次/30min），
    // 原因是 digest 不稳定（下载记录规范化、playlist.updatedAt 回灌等）反复
    // 触发 `enqueueLocalPlaylistChange → processPendingLocalUpload` 的 while 循环。
    //
    // 硬止血：连续两次上传之间至少间隔 `minUploadInterval` 秒；短时间内发生的
    // 重复变更会合并到一次后续上传。
    /// 连续两次上传的最小间隔
    private static let minUploadInterval: TimeInterval = 10
    /// 最近一次真正完成 uploadCloudPlaylistSnapshot 的时间戳
    private var lastUploadCompletedAt: Date?

    private init() {
        lastObservedDigest = playlistManager.currentSyncDigest()
        lastStatusMessage = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.playlistSyncLastMessage)
        lastRemoteRevision = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.playlistSyncLastRemoteRevision)
        if let timestamp = UserDefaults.standard.object(forKey: AppConfig.StorageKeys.playlistSyncLastSyncedAt) as? Date {
            lastSyncedAt = timestamp
        }
        observePlaylistChanges()
        observeApplicationLifecycle()
    }

    func handleAccessGranted() {
        let fingerprint = Self.tokenFingerprint()
        resetRemoteStateIfNeeded(for: fingerprint)

        if currentTokenFingerprint != fingerprint {
            hasBootstrappedCurrentToken = false
            lastObservedDigest = playlistManager.currentSyncDigest()
            pendingUploadDigest = nil
        }
        currentTokenFingerprint = fingerprint

        Task {
            await bootstrapIfNeeded()
            await processPendingLocalUpload()
        }
    }

    func handleAccessRevoked() {
        currentTokenFingerprint = nil
        hasBootstrappedCurrentToken = false
        uploadRetryTask?.cancel()
        uploadRetryTask = nil
        pendingUploadDigest = nil
        _ = playlistManager.clearSyncablePlaylistsLocally()
        lastObservedDigest = playlistManager.currentSyncDigest()
    }

    func scheduleSyncForLocalMutation() {
        Task {
            await enqueueLocalPlaylistChange()
        }
    }

    func resumeAutomaticSync() {
        lastObservedDigest = ""
        pendingUploadDigest = playlistManager.currentSyncDigest()
        Task {
            await processPendingLocalUpload()
        }
    }

    @discardableResult
    func refreshAndSync() async throws -> Int {
        let restored = try await restoreFromCloud(showStatus: false)
        if playlistManager.currentSyncDigest() != lastObservedDigest {
            _ = try await syncToCloud(showStatus: false)
            persistStatus(NSLocalizedString("playlist_sync_auto_uploaded", comment: ""))
        }
        return restored
    }

    func clearCloudSnapshot(showStatus: Bool = true) async throws {
        guard accessManager.canUseOnlineFeatures else {
            throw URLError(.userAuthenticationRequired)
        }

        isSyncing = true
        defer { isSyncing = false }

        let response = try await APIService.shared.deleteCloudPlaylistSnapshot()
        persistRemoteRevision(nil)
        persistSyncState(date: response.updatedAt)

        if showStatus {
            persistStatus(NSLocalizedString("playlist_sync_cloud_empty", comment: ""))
        }
    }

    func syncToCloud(showStatus: Bool = true) async throws -> LocalPlaylistCloudUploadResponse {
        guard accessManager.canUseOnlineFeatures else {
            throw URLError(.userAuthenticationRequired)
        }

        isSyncing = true
        defer { isSyncing = false }

        let snapshot = playlistManager.makeCloudSnapshot(
            deviceId: Self.deviceId(),
            deviceName: UIDevice.current.name
        )
        let response = try await APIService.shared.uploadCloudPlaylistSnapshot(snapshot)
        lastUploadCompletedAt = Date()
        lastObservedDigest = playlistManager.currentSyncDigest()
        persistSyncState(date: response.updatedAt)
        persistRemoteRevision(response.revision)

        if showStatus {
            let message = String(
                format: NSLocalizedString("playlist_sync_upload_success", comment: ""),
                locale: Locale.current,
                response.playlistCount,
                response.songCount
            )
            persistStatus(message)
        }

        return response
    }

    @discardableResult
    func restoreFromCloud(showStatus: Bool = true) async throws -> Int {
        guard accessManager.canUseOnlineFeatures else {
            throw URLError(.userAuthenticationRequired)
        }

        isSyncing = true
        defer { isSyncing = false }

        guard let response = try await APIService.shared.fetchCloudPlaylistSnapshot() else {
            if showStatus {
                persistStatus(NSLocalizedString("playlist_sync_cloud_empty", comment: ""))
            }
            return 0
        }

        return applyRemoteResponse(response, showStatus: showStatus)
    }

    func refreshFromCloudIfNeeded(showStatus: Bool = false) async {
        do {
            _ = try await refreshRemoteSnapshotIfNeeded(showStatus: showStatus)
        } catch {
            if showStatus {
                persistStatus(
                    String(
                        format: NSLocalizedString("playlist_sync_failed_format", comment: ""),
                        locale: Locale.current,
                        error.localizedDescription
                    )
                )
            }
        }
    }

    private func bootstrapIfNeeded() async {
        guard accessManager.canUseOnlineFeatures else { return }
        guard let fingerprint = Self.tokenFingerprint() else { return }
        guard !hasBootstrappedCurrentToken else { return }

        currentTokenFingerprint = fingerprint
        defer { hasBootstrappedCurrentToken = true }

        do {
            guard let response = try await APIService.shared.fetchCloudPlaylistSnapshot() else {
                if playlistManager.hasSyncableContent && settings.playlistSyncAutoEnabled {
                    _ = try await syncToCloud(showStatus: false)
                    persistStatus(NSLocalizedString("playlist_sync_auto_uploaded", comment: ""))
                } else if lastStatusMessage == nil {
                    persistStatus(NSLocalizedString("playlist_sync_cloud_empty", comment: ""))
                }
                return
            }

            let remoteChanged = response.revision != lastRemoteRevision

            if response.hasSnapshot {
                if !playlistManager.hasSyncableContent || (lastRemoteRevision != nil && remoteChanged) {
                    _ = applyRemoteResponse(response, showStatus: false)
                } else if settings.playlistSyncAutoEnabled {
                    _ = try await syncToCloud(showStatus: false)
                    persistStatus(NSLocalizedString("playlist_sync_auto_uploaded", comment: ""))
                }
            } else if playlistManager.hasSyncableContent && settings.playlistSyncAutoEnabled {
                _ = try await syncToCloud(showStatus: false)
                persistStatus(NSLocalizedString("playlist_sync_auto_uploaded", comment: ""))
            } else {
                persistRemoteRevision(nil)
                if lastStatusMessage == nil {
                    persistStatus(NSLocalizedString("playlist_sync_cloud_empty", comment: ""))
                }
            }
        } catch {
            persistStatus(
                String(
                    format: NSLocalizedString("playlist_sync_failed_format", comment: ""),
                    locale: Locale.current,
                    error.localizedDescription
                )
            )
        }
    }

    private func observePlaylistChanges() {
        playlistManager.$playlists
            .dropFirst()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.enqueueLocalPlaylistChange() }
            }
            .store(in: &cancellables)

        // 监听下载记录变化（实时同步）
        DownloadManager.shared.$downloadedSongIds
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.enqueueLocalPlaylistChange() }
            }
            .store(in: &cancellables)

        // 监听播客本地订阅变化（实时同步）
        SubscriptionManager.shared.$localSubscribedRadios
            .dropFirst()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.enqueueLocalPlaylistChange() }
            }
            .store(in: &cancellables)
    }

    private func observeApplicationLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshFromCloudIfNeeded() }
            }
            .store(in: &cancellables)
    }

    private func enqueueLocalPlaylistChange() async {
        let digest = playlistManager.currentSyncDigest()
        guard settings.playlistSyncAutoEnabled else {
            lastObservedDigest = digest
            pendingUploadDigest = nil
            return
        }
        guard digest != lastObservedDigest else {
            if pendingUploadDigest == digest {
                pendingUploadDigest = nil
            }
            return
        }

        pendingUploadDigest = digest
        uploadRetryTask?.cancel()
        uploadRetryTask = nil

        await processPendingLocalUpload()
    }

    private func processPendingLocalUpload() async {
        guard accessManager.canUseOnlineFeatures else { return }
        guard hasBootstrappedCurrentToken else { return }
        guard !isApplyingRemoteSnapshot else { return }
        guard !isSyncing else { return }
        guard settings.playlistSyncAutoEnabled else { return }

        // 节流：距离上次上传不足 minUploadInterval 秒时，挂起一个延时任务
        // 等冷却完再进入 while 循环；避免 digest 抖动导致的死循环式上传。
        if let last = lastUploadCompletedAt {
            let elapsed = Date().timeIntervalSince(last)
            let remaining = Self.minUploadInterval - elapsed
            if remaining > 0 {
                uploadRetryTask?.cancel()
                uploadRetryTask = Task { [weak self] in
                    let nanos = UInt64(remaining * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: nanos)
                    guard let self, !Task.isCancelled else { return }
                    await self.processPendingLocalUpload()
                }
                return
            }
        }

        while let pendingUploadDigest, pendingUploadDigest != lastObservedDigest {
            do {
                if !playlistManager.hasSyncableContent {
                    lastObservedDigest = playlistManager.currentSyncDigest()

                    if settings.playlistSyncDeleteCloudSnapshot {
                        try await clearCloudSnapshot(showStatus: false)
                        persistStatus(NSLocalizedString("playlist_sync_cloud_empty", comment: ""))
                    } else {
                        persistStatus(NSLocalizedString("playlist_sync_cloud_retained", comment: ""))
                    }

                    self.pendingUploadDigest = nil
                    return
                }

                _ = try await syncToCloud(showStatus: false)

                let latestDigest = playlistManager.currentSyncDigest()
                if latestDigest == lastObservedDigest {
                    self.pendingUploadDigest = nil
                } else {
                    self.pendingUploadDigest = latestDigest
                }

                persistStatus(NSLocalizedString("playlist_sync_auto_uploaded", comment: ""))

                // 单次循环成功后立即跳出：剩余变更通过节流延时任务
                // 在 `minUploadInterval` 秒后统一处理。
                // 不再连续 upload，避免 digest 抖动引发的高频刷流量。
                if self.pendingUploadDigest != nil {
                    uploadRetryTask?.cancel()
                    uploadRetryTask = Task { [weak self] in
                        let nanos = UInt64(Self.minUploadInterval * 1_000_000_000)
                        try? await Task.sleep(nanoseconds: nanos)
                        guard let self, !Task.isCancelled else { return }
                        await self.processPendingLocalUpload()
                    }
                }
                return
            } catch {
                self.pendingUploadDigest = playlistManager.currentSyncDigest()
                scheduleUploadRetry()
                persistStatus(
                    String(
                        format: NSLocalizedString("playlist_sync_failed_format", comment: ""),
                        locale: Locale.current,
                        error.localizedDescription
                    )
                )
                return
            }
        }
    }

    private func scheduleUploadRetry() {
        guard pendingUploadDigest != nil else { return }

        uploadRetryTask?.cancel()
        uploadRetryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.processPendingLocalUpload()
        }
    }

    private func refreshRemoteSnapshotIfNeeded(showStatus: Bool) async throws -> Int? {
        guard accessManager.canUseOnlineFeatures else { return nil }
        guard hasBootstrappedCurrentToken else { return nil }
        guard !isApplyingRemoteSnapshot else { return nil }
        guard !isSyncing else { return nil }
        guard lastRemoteRevision != nil else { return nil }
        guard let response = try await APIService.shared.fetchCloudPlaylistSnapshot() else { return nil }

        let remoteChanged = response.revision != lastRemoteRevision
        let remoteCleared = !response.hasSnapshot && lastRemoteRevision != nil

        guard remoteChanged || remoteCleared else { return nil }
        return applyRemoteResponse(response, showStatus: showStatus)
    }

    @discardableResult
    private func applyRemoteResponse(_ response: LocalPlaylistCloudFetchResponse, showStatus: Bool) -> Int {
        if response.hasSnapshot {
            return applyRemotePlaylists(
                response.playlists,
                downloads: response.downloads,
                radioSubscriptions: response.localRadioSubscriptions,
                revision: response.revision,
                updatedAt: response.updatedAt,
                showStatus: showStatus
            )
        }

        return clearRemoteSnapshot(updatedAt: response.updatedAt, showStatus: showStatus)
    }

    @discardableResult
    private func applyRemotePlaylists(
        _ remotePlaylists: [LocalPlaylistCloudPlaylist],
        downloads: [CloudDownloadRecord]?,
        radioSubscriptions: [RadioStation]?,
        revision: String?,
        updatedAt: Date?,
        showStatus: Bool
    ) -> Int {
        isApplyingRemoteSnapshot = true
        defer { isApplyingRemoteSnapshot = false }

        let restoredCount = playlistManager.mergeSyncablePlaylists(
            with: remotePlaylists,
            preservingLocalChangesSince: lastSyncedAt
        )

        // 恢复播客本地订阅
        if let radios = radioSubscriptions, !radios.isEmpty {
            SubscriptionManager.shared.replaceLocalSubscriptions(with: radios)
        }

        // 恢复下载记录到下载歌单（仅元数据，显示用）
        if let downloads = downloads, !downloads.isEmpty {
            let songs = downloads.map { $0.toSong() }
            playlistManager.restoreDownloadPlaylistSongs(songs)
        }

        let localDigest = playlistManager.currentSyncDigest()

        // 上传后 digest 一致说明本地无更多变化
        lastObservedDigest = localDigest
        pendingUploadDigest = nil
        persistRemoteRevision(revision)
        persistSyncState(date: updatedAt ?? Date())

        if showStatus {
            let message = String(
                format: NSLocalizedString("playlist_sync_restore_success", comment: ""),
                locale: Locale.current,
                restoredCount
            )
            persistStatus(message)
        }

        return restoredCount
    }

    @discardableResult
    private func clearRemoteSnapshot(updatedAt: Date?, showStatus: Bool) -> Int {
        isApplyingRemoteSnapshot = true
        defer { isApplyingRemoteSnapshot = false }

        _ = playlistManager.mergeSyncablePlaylists(
            with: [],
            preservingLocalChangesSince: lastSyncedAt
        )
        let localDigest = playlistManager.currentSyncDigest()

        if localDigest.isEmpty {
            lastObservedDigest = localDigest
            pendingUploadDigest = nil
        } else {
            pendingUploadDigest = localDigest
            lastObservedDigest = ""
            Task { [weak self] in
                await self?.processPendingLocalUpload()
            }
        }
        persistRemoteRevision(nil)
        persistSyncState(date: updatedAt ?? Date())

        if showStatus {
            persistStatus(NSLocalizedString("playlist_sync_cloud_empty", comment: ""))
        }

        return 0
    }

    private func persistSyncState(date: Date) {
        lastSyncedAt = date
        UserDefaults.standard.set(date, forKey: AppConfig.StorageKeys.playlistSyncLastSyncedAt)
    }

    private func persistStatus(_ message: String) {
        lastStatusMessage = message
        UserDefaults.standard.set(message, forKey: AppConfig.StorageKeys.playlistSyncLastMessage)
    }

    private func persistRemoteRevision(_ revision: String?) {
        lastRemoteRevision = revision
        if let revision, !revision.isEmpty {
            UserDefaults.standard.set(revision, forKey: AppConfig.StorageKeys.playlistSyncLastRemoteRevision)
        } else {
            UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.playlistSyncLastRemoteRevision)
        }
    }

    private func resetRemoteStateIfNeeded(for fingerprint: String?) {
        let storedFingerprint = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.playlistSyncLastTokenFingerprint)
        guard storedFingerprint != fingerprint else { return }

        if let fingerprint, !fingerprint.isEmpty {
            UserDefaults.standard.set(fingerprint, forKey: AppConfig.StorageKeys.playlistSyncLastTokenFingerprint)
        } else {
            UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.playlistSyncLastTokenFingerprint)
        }

        persistRemoteRevision(nil)
    }

    private static func deviceId() -> String {
        return DeviceIdentifier.uuid
    }

    private static func tokenFingerprint() -> String? {
        guard let token = SecureConfig.apiToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return nil
        }
        return token
    }

    private static func digest(for snapshot: LocalPlaylistCloudSnapshot) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // 排除 updatedAt/deviceId/deviceName，只比较内容
        struct DigestContent: Encodable {
            let playlists: [LocalPlaylistCloudPlaylist]
            let downloads: [CloudDownloadRecord]?
            let localRadioSubscriptions: [RadioStation]?
        }
        let content = DigestContent(
            playlists: snapshot.playlists,
            downloads: snapshot.downloads,
            localRadioSubscriptions: snapshot.localRadioSubscriptions
        )
        guard let data = try? encoder.encode(content) else { return "" }
        return data.base64EncodedString()
    }
}
