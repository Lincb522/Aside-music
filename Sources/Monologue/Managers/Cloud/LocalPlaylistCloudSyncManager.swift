import Foundation
import Combine
import UIKit
import CryptoKit

struct CloudSyncContentSummary: Equatable {
    var playlists = 0
    var playlistSongs = 0
    var downloads = 0
    var podcastSubscriptions = 0
    var colorConfigurations = 0
    var listeningRecords = 0
    var playbackRecords = 0
    var aiTuningPlans = 0
    var customEQPresets = 0

    var hasContent: Bool {
        playlists > 0
            || downloads > 0
            || podcastSubscriptions > 0
            || colorConfigurations > 0
            || playbackRecords > 0
            || aiTuningPlans > 0
            || customEQPresets > 0
    }
}

@MainActor
final class LocalPlaylistCloudSyncManager: ObservableObject {
    static let shared = LocalPlaylistCloudSyncManager()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastStatusMessage: String?
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var localContentSummary = CloudSyncContentSummary()

    private let playlistManager = LocalPlaylistManager.shared
    private let accessManager = OnlineAccessManager.shared
    private let settings = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var hasBootstrappedCurrentToken = false
    private var isBootstrappingCurrentToken = false
    private var currentTokenFingerprint: String?
    private var isApplyingRemoteSnapshot = false
    private var lastObservedDigest: String
    private var lastRemoteRevision: String?
    private var pendingUploadDigest: String?
    private var automaticUploadTask: Task<Void, Never>?
    private var scheduledAutomaticUploadAt: Date?
    private var isCheckingRemoteSnapshot = false
    private var automaticUploadInFlight = false

    // MARK: - 自动同步时段

    /// 按本地时区划分 00:00、08:00、16:00 三个时段；同一时段的变化
    /// 只合并上传一次，手动同步不受此限制。
    private struct AutomaticSyncSlot {
        let key: String
        let nextBoundary: Date
    }

    private init() {
        lastObservedDigest = ""
        lastStatusMessage = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.playlistSyncLastMessage)
        lastRemoteRevision = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.playlistSyncLastRemoteRevision)
        if let timestamp = UserDefaults.standard.object(forKey: AppConfig.StorageKeys.playlistSyncLastSyncedAt) as? Date {
            lastSyncedAt = timestamp
        }
        observePlaylistChanges()
        observeApplicationLifecycle()
        let initialSnapshot = makeLocalSnapshot()
        localContentSummary = Self.contentSummary(for: initialSnapshot)
        lastObservedDigest = Self.digest(for: initialSnapshot)
    }

    func handleAccessGranted() {
        let fingerprint = Self.tokenFingerprint()
        resetRemoteStateIfNeeded(for: fingerprint)

        if currentTokenFingerprint != fingerprint {
            hasBootstrappedCurrentToken = false
            lastObservedDigest = currentLocalDigest()
            pendingUploadDigest = nil
            automaticUploadTask?.cancel()
            automaticUploadTask = nil
            scheduledAutomaticUploadAt = nil
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
        isBootstrappingCurrentToken = false
        automaticUploadTask?.cancel()
        automaticUploadTask = nil
        scheduledAutomaticUploadAt = nil
        pendingUploadDigest = nil
        isCheckingRemoteSnapshot = false
        _ = playlistManager.clearSyncablePlaylistsLocally()
        refreshLocalContentSummary()
        lastObservedDigest = currentLocalDigest()
    }

    func scheduleSyncForLocalMutation() {
        Task {
            await enqueueLocalPlaylistChange()
        }
    }

    func resumeAutomaticSync() {
        Task {
            await bootstrapIfNeeded()
            await refreshFromCloudIfNeeded()
            await processPendingLocalUpload()
        }
    }

    @discardableResult
    func refreshAndSync() async throws -> Int {
        guard accessManager.canUseOnlineFeatures else {
            throw URLError(.userAuthenticationRequired)
        }

        refreshLocalContentSummary()
        let response = try await APIService.shared.fetchCloudPlaylistSnapshot()

        // 云端没有快照时绝不动本地内容（清空动作只允许由
        // refreshRemoteSnapshotIfNeeded 的跨设备清空流程触发）
        var restored = 0
        if let response, response.hasSnapshot {
            restored = applyRemoteResponse(response, showStatus: false)
        }

        // 合并后本地内容与云端不一致（本地有离线新增）才补一次上传
        let needsUpload: Bool
        if let response, response.hasSnapshot {
            needsUpload = localContentDiffers(from: response)
        } else {
            needsUpload = hasCloudSyncableContent
        }

        if needsUpload {
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
        defer {
            isSyncing = false
            if pendingUploadDigest != nil {
                Task { [weak self] in
                    await self?.processPendingLocalUpload()
                }
            }
        }

        let snapshot = makeLocalSnapshot()
        localContentSummary = Self.contentSummary(for: snapshot)
        let response = try await APIService.shared.uploadCloudPlaylistSnapshot(snapshot)
        // 只把本次实际上传的内容记为同步基线。网络请求期间若本地又有
        // 变化，后续比较仍能发现差异并补传，不会误判为已经上云。
        lastObservedDigest = Self.digest(for: snapshot)
        persistSyncState(date: response.updatedAt)
        persistRemoteRevision(response.revision)

        if showStatus {
            persistStatus(NSLocalizedString("playlist_sync_upload_success", comment: ""))
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

        let response = try await APIService.shared.fetchCloudPlaylistSnapshot()

        // 云端为空时「恢复」只提示，不把本地内容清掉
        guard let response, response.hasSnapshot else {
            if showStatus {
                persistStatus(NSLocalizedString("playlist_sync_cloud_empty", comment: ""))
            }
            return 0
        }

        return applyRemoteResponse(response, showStatus: showStatus)
    }

    func refreshFromCloudIfNeeded(showStatus: Bool = false) async {
        guard accessManager.canUseOnlineFeatures else { return }
        guard hasBootstrappedCurrentToken else { return }
        guard !isBootstrappingCurrentToken else { return }
        guard !isCheckingRemoteSnapshot else { return }
        let slot = Self.automaticSyncSlot()
        if !showStatus,
           UserDefaults.standard.string(
            forKey: AppConfig.StorageKeys.playlistSyncLastAutomaticRefreshSlot
           ) == slot.key {
            return
        }

        isCheckingRemoteSnapshot = true
        defer { isCheckingRemoteSnapshot = false }

        if !showStatus {
            // 自动检查按时段记账，不因网络失败或页面反复出现而高频重试。
            UserDefaults.standard.set(
                slot.key,
                forKey: AppConfig.StorageKeys.playlistSyncLastAutomaticRefreshSlot
            )
        }

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
        guard !isBootstrappingCurrentToken else { return }

        isBootstrappingCurrentToken = true
        currentTokenFingerprint = fingerprint
        defer {
            isBootstrappingCurrentToken = false
            hasBootstrappedCurrentToken = true
        }

        let slot = Self.automaticSyncSlot()
        let refreshedSlot = UserDefaults.standard.string(
            forKey: AppConfig.StorageKeys.playlistSyncLastAutomaticRefreshSlot
        )
        if refreshedSlot == slot.key {
            if settings.playlistSyncAutoEnabled, hasCloudSyncableContent {
                pendingUploadDigest = currentLocalDigest()
            }
            return
        }

        do {
            // 启动恢复也属于当前自动同步时段，先记账以避免失败后反复启动刷接口。
            UserDefaults.standard.set(
                slot.key,
                forKey: AppConfig.StorageKeys.playlistSyncLastAutomaticRefreshSlot
            )
            let response = try await APIService.shared.fetchCloudPlaylistSnapshot()
            guard let response else {
                if hasCloudSyncableContent && settings.playlistSyncAutoEnabled {
                    pendingUploadDigest = currentLocalDigest()
                } else if lastStatusMessage == nil {
                    persistStatus(NSLocalizedString("playlist_sync_cloud_empty", comment: ""))
                }
                return
            }

            if response.hasSnapshot {
                // ⚠️ 云端有快照时一律「先并入云端内容，再按差异补传」。
                //
                // 历史事故：这里曾按「本地有内容且云端 revision 没变 → 直接上传」
                // 决策。退出登录会清空本地可同步歌单，但下载记录/播客订阅还在，
                // 于是重新登录后被判成「本地有内容」，把清空后的状态整包传上去，
                // 云端歌单被一次性抹掉，之后点「恢复」自然什么都拉不回来。
                //
                // merge 会保留比上次同步更新的本地改动，云端内容不会丢；
                // 代价是离线删除的歌单可能被云端补回（可再手动删，删除会即时上云）。
                _ = applyRemoteResponse(response, showStatus: false)

                // 并入后本地仍比云端多内容（离线新增）→ 补一次上传
                if settings.playlistSyncAutoEnabled, localContentDiffers(from: response) {
                    pendingUploadDigest = currentLocalDigest()
                }
            } else if hasCloudSyncableContent && settings.playlistSyncAutoEnabled {
                pendingUploadDigest = currentLocalDigest()
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

        // 下载记录变化纳入当前自动同步批次。
        DownloadManager.shared.$downloadedSongIds
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.enqueueLocalPlaylistChange() }
            }
            .store(in: &cancellables)

        // 播客本地订阅变化纳入当前自动同步批次。
        SubscriptionManager.shared.$localSubscribedRadios
            .dropFirst()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.enqueueLocalPlaylistChange() }
            }
            .store(in: &cancellables)

        settings.$globalThemeRevision
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in self.scheduleSyncForLocalMutation() }
            }
            .store(in: &cancellables)

        EQManager.shared.$customPresets
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in self.scheduleSyncForLocalMutation() }
            }
            .store(in: &cancellables)

        AIEqualizerAgent.shared.$savedProposals
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in self.scheduleSyncForLocalMutation() }
            }
            .store(in: &cancellables)
    }

    private func observeApplicationLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.refreshFromCloudIfNeeded()
                    await self.processPendingLocalUpload()
                }
            }
            .store(in: &cancellables)
    }

    private func enqueueLocalPlaylistChange() async {
        let snapshot = makeLocalSnapshot()
        localContentSummary = Self.contentSummary(for: snapshot)
        let digest = Self.digest(for: snapshot)
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

        await processPendingLocalUpload()
    }

    private func processPendingLocalUpload() async {
        guard accessManager.canUseOnlineFeatures else { return }
        guard hasBootstrappedCurrentToken else { return }
        guard !isApplyingRemoteSnapshot else { return }
        guard !isSyncing else { return }
        guard !automaticUploadInFlight else { return }
        guard settings.playlistSyncAutoEnabled else { return }
        guard let pendingUploadDigest,
              pendingUploadDigest != lastObservedDigest else {
            self.pendingUploadDigest = nil
            return
        }

        let slot = Self.automaticSyncSlot()
        let completedSlot = UserDefaults.standard.string(
            forKey: AppConfig.StorageKeys.playlistSyncLastAutomaticUploadSlot
        )
        guard completedSlot != slot.key else {
            scheduleAutomaticUpload(at: slot.nextBoundary)
            return
        }

        automaticUploadInFlight = true
        defer { automaticUploadInFlight = false }
        // 每个时段最多进行一次自动写入尝试；失败内容留到下一时段。
        persistAutomaticUploadSlot(slot.key)

        do {
            if !hasCloudSyncableContent {
                lastObservedDigest = currentLocalDigest()

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

            let latestDigest = currentLocalDigest()
            if latestDigest == lastObservedDigest {
                self.pendingUploadDigest = nil
            } else {
                self.pendingUploadDigest = latestDigest
                scheduleAutomaticUpload(at: slot.nextBoundary)
            }

            persistStatus(NSLocalizedString("playlist_sync_auto_uploaded", comment: ""))
        } catch {
            self.pendingUploadDigest = currentLocalDigest()
            scheduleAutomaticUpload(at: slot.nextBoundary)
            persistStatus(
                String(
                    format: NSLocalizedString("playlist_sync_failed_format", comment: ""),
                    locale: Locale.current,
                    error.localizedDescription
                )
            )
        }
    }

    private func scheduleAutomaticUpload(at date: Date) {
        if let scheduledAutomaticUploadAt,
           abs(scheduledAutomaticUploadAt.timeIntervalSince(date)) < 1,
           automaticUploadTask != nil {
            return
        }

        automaticUploadTask?.cancel()
        scheduledAutomaticUploadAt = date
        automaticUploadTask = Task { [weak self] in
            let delay = max(1, date.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.automaticUploadTask = nil
            self.scheduledAutomaticUploadAt = nil
            await self.processPendingLocalUpload()
        }
    }

    private func refreshRemoteSnapshotIfNeeded(showStatus: Bool) async throws -> Int? {
        guard accessManager.canUseOnlineFeatures else { return nil }
        guard hasBootstrappedCurrentToken else { return nil }
        guard !isBootstrappingCurrentToken else { return nil }
        guard !isApplyingRemoteSnapshot else { return nil }
        guard !isSyncing else { return nil }
        let knownRevision = lastRemoteRevision
        guard let response = try await APIService.shared.fetchCloudPlaylistSnapshot(
            ifChangedFrom: knownRevision
        ) else { return nil }

        let remoteChanged = response.revision != knownRevision
        let remoteCleared = !response.hasSnapshot && knownRevision != nil

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
                themeCustomization: response.themeCustomization,
                playbackHistory: response.playbackHistory,
                aiEqualizer: response.aiEqualizer,
                customEQPresets: response.customEQPresets,
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
        themeCustomization: CloudThemeCustomizationSnapshot?,
        playbackHistory: CloudPlaybackHistorySnapshot?,
        aiEqualizer: CloudAIEqualizerSnapshot?,
        customEQPresets: [EQPreset]?,
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
        if AppConfig.Features.restrictedDownloadEnabled,
           let downloads = downloads,
           !downloads.isEmpty {
            DownloadManager.shared.restoreCloudDownloadRecords(downloads)
            let songs = downloads.map { $0.toSong() }
            playlistManager.restoreDownloadPlaylistSongs(songs)
        }

        if let themeCustomization {
            ThemeColorCustomization.restoreCloudSnapshot(
                themeCustomization,
                replacingLocal: showStatus
            )
        }

        if let playbackHistory {
            _ = HistoryRepository().mergeCloudPlaybackHistory(playbackHistory)
            PlayerManager.shared.fetchHistory()
        }

        if let aiEqualizer {
            AIEqualizerAgent.shared.restoreCloudSnapshot(aiEqualizer)
        }

        if let customEQPresets, !customEQPresets.isEmpty {
            EQManager.shared.restoreCloudCustomPresets(customEQPresets)
        }

        let localSnapshot = makeLocalSnapshot()
        let localDigest = Self.digest(for: localSnapshot)

        // 上传后 digest 一致说明本地无更多变化
        lastObservedDigest = localDigest
        pendingUploadDigest = nil
        persistRemoteRevision(revision)
        persistSyncState(date: updatedAt ?? Date())
        localContentSummary = Self.contentSummary(for: localSnapshot)

        if showStatus {
            persistStatus(NSLocalizedString("playlist_sync_restore_success", comment: ""))
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
        let localDigest = currentLocalDigest()

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

    /// 本地内容与云端快照内容是否不同（忽略 updatedAt / 设备信息）。
    /// 用于 merge 之后判断是否还需要补一次上传。
    private func localContentDiffers(from response: LocalPlaylistCloudFetchResponse) -> Bool {
        let localSnapshot = makeLocalSnapshot()
        let remoteSnapshot = LocalPlaylistCloudSnapshot(
            updatedAt: Date(),
            deviceId: "",
            deviceName: "",
            playlists: response.playlists,
            downloads: (response.downloads?.isEmpty == false) ? response.downloads : nil,
            localRadioSubscriptions: (response.localRadioSubscriptions?.isEmpty == false) ? response.localRadioSubscriptions : nil,
            themeCustomization: response.themeCustomization,
            playbackHistory: response.playbackHistory,
            aiEqualizer: response.aiEqualizer,
            customEQPresets: (response.customEQPresets?.isEmpty == false) ? response.customEQPresets : nil
        )
        return Self.digest(for: localSnapshot) != Self.digest(for: remoteSnapshot)
    }

    private static func automaticSyncSlot(for date: Date = Date()) -> AutomaticSyncSlot {
        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        let hour = components.hour ?? 0
        let slotIndex = min(2, max(0, hour / 8))
        let key = String(
            format: "%04d-%02d-%02d-%d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            slotIndex
        )

        let nextBoundary: Date
        if slotIndex < 2 {
            nextBoundary = calendar.date(
                bySettingHour: (slotIndex + 1) * 8,
                minute: 0,
                second: 0,
                of: date
            ) ?? date.addingTimeInterval(8 * 60 * 60)
        } else {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(8 * 60 * 60)
            nextBoundary = calendar.startOfDay(for: tomorrow)
        }

        return AutomaticSyncSlot(key: key, nextBoundary: nextBoundary)
    }

    private func persistAutomaticUploadSlot(_ key: String) {
        UserDefaults.standard.set(
            key,
            forKey: AppConfig.StorageKeys.playlistSyncLastAutomaticUploadSlot
        )
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
        UserDefaults.standard.removeObject(
            forKey: AppConfig.StorageKeys.playlistSyncLastAutomaticUploadSlot
        )
        UserDefaults.standard.removeObject(
            forKey: AppConfig.StorageKeys.playlistSyncLastAutomaticRefreshSlot
        )
        // 换账号后旧的同步基线不再可信：留着会让 merge 把旧账号时期的
        // 本地歌单误判为「没改过」而被新账号的云端快照覆盖/删除。
        lastSyncedAt = nil
        UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.playlistSyncLastSyncedAt)
    }

    private static func deviceId() -> String {
        let id = DeviceIdentifier.uuid
        UserDefaults.standard.set(id, forKey: AppConfig.StorageKeys.playlistSyncDeviceId)
        return id
    }

    private static func tokenFingerprint() -> String? {
        guard let token = SecureConfig.apiToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return nil
        }
        return token
    }

    private var hasCloudSyncableContent: Bool {
        localContentSummary.hasContent
    }

    private func makeLocalSnapshot() -> LocalPlaylistCloudSnapshot {
        var snapshot = playlistManager.makeCloudSnapshot(
            deviceId: Self.deviceId(),
            deviceName: UIDevice.current.name
        )
        snapshot.themeCustomization = ThemeColorCustomization.makeCloudSnapshot()
        snapshot.playbackHistory = HistoryRepository().makeCloudPlaybackHistorySnapshot()
        if var aiEqualizer = AIEqualizerAgent.shared.makeCloudSnapshot() {
            let proposalMetadata = makeAIEqualizerSongMetadata(
                from: snapshot.playlists,
                matching: aiEqualizer
            )
            aiEqualizer.proposalMetadata = proposalMetadata.isEmpty ? nil : proposalMetadata
            snapshot.aiEqualizer = aiEqualizer
        } else {
            snapshot.aiEqualizer = nil
        }
        snapshot.customEQPresets = EQManager.shared.makeCloudCustomPresets()
        return snapshot
    }

    private func makeAIEqualizerSongMetadata(
        from playlists: [LocalPlaylistCloudPlaylist],
        matching aiEqualizer: CloudAIEqualizerSnapshot
    ) -> [String: CloudAIEqualizerSongMetadata] {
        var requestedKeys = Set(aiEqualizer.cachedProposals.keys)
        var requestedSongIds = Set(aiEqualizer.cachedProposals.values.map(\.songID))

        for (songIdentifier, entries) in aiEqualizer.savedProposals {
            requestedKeys.insert(songIdentifier)
            entries.forEach { entry in
                requestedSongIds.insert(entry.proposal.songID)
            }
        }

        var metadata: [String: CloudAIEqualizerSongMetadata] = [:]

        for playlist in playlists {
            for song in playlist.songs {
                let item = CloudAIEqualizerSongMetadata(song: song)
                let source = item.sourceRaw
                let songId = String(item.songId)
                var keys = [
                    item.songIdentifier,
                    songId,
                    "\(source):\(songId)"
                ]

                if source == MusicSource.netease.rawValue {
                    keys.append("netease|\(songId)")
                }

                if let qqMid = song.qqMid?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !qqMid.isEmpty {
                    keys.append(qqMid)
                    keys.append("qqmusic:\(qqMid)")
                }

                if let qishuiTrackId = song.qishuiTrackId {
                    let trackId = String(qishuiTrackId)
                    keys.append(trackId)
                    keys.append("qishui:\(trackId)")
                }

                guard requestedSongIds.contains(song.id) || keys.contains(where: requestedKeys.contains) else {
                    continue
                }

                for key in keys {
                    metadata[key] = item
                }
            }
        }

        return metadata
    }

    private func currentLocalDigest() -> String {
        Self.digest(for: makeLocalSnapshot())
    }

    private func refreshLocalContentSummary() {
        localContentSummary = Self.contentSummary(for: makeLocalSnapshot())
    }

    private static func contentSummary(
        for snapshot: LocalPlaylistCloudSnapshot
    ) -> CloudSyncContentSummary {
        let themeCount = snapshot.themeCustomization?.entries.reduce(into: 0) { count, entry in
            count += entry.savedLight.count + entry.savedDark.count
            if entry.currentLight != nil { count += 1 }
            if entry.currentDark != nil { count += 1 }
        } ?? 0
        let playbackRecords = snapshot.playbackHistory?.records ?? []
        let cachedAIPlanIDs = Set(snapshot.aiEqualizer?.cachedProposals.values.map(\.id) ?? [])
        let savedAIPlanIDs = Set(
            snapshot.aiEqualizer?.savedProposals.values
                .flatMap { $0 }
                .map { $0.proposal.id } ?? []
        )
        let aiPlans = cachedAIPlanIDs.union(savedAIPlanIDs).count

        return CloudSyncContentSummary(
            playlists: snapshot.playlists.count,
            playlistSongs: snapshot.playlists.reduce(0) { $0 + $1.songs.count },
            downloads: snapshot.downloads?.count ?? 0,
            podcastSubscriptions: snapshot.localRadioSubscriptions?.count ?? 0,
            colorConfigurations: themeCount,
            listeningRecords: playbackRecords.filter { $0.playDuration > 0 }.count,
            playbackRecords: playbackRecords.count,
            aiTuningPlans: aiPlans,
            customEQPresets: snapshot.customEQPresets?.count ?? 0
        )
    }

    private static func digest(for snapshot: LocalPlaylistCloudSnapshot) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        // 排除 updatedAt/deviceId/deviceName，只比较内容
        struct DigestContent: Encodable {
            let playlists: [LocalPlaylistCloudPlaylist]
            let downloads: [CloudDownloadRecord]?
            let localRadioSubscriptions: [RadioStation]?
            let themeCustomization: CloudThemeCustomizationSnapshot?
            let playbackHistory: CloudPlaybackHistorySnapshot?
            let aiEqualizer: CloudAIEqualizerSnapshot?
            let customEQPresets: [EQPreset]?
        }
        let content = DigestContent(
            playlists: snapshot.playlists,
            downloads: snapshot.downloads,
            localRadioSubscriptions: snapshot.localRadioSubscriptions,
            themeCustomization: snapshot.themeCustomization,
            playbackHistory: snapshot.playbackHistory,
            aiEqualizer: snapshot.aiEqualizer,
            customEQPresets: snapshot.customEQPresets
        )
        guard let data = try? encoder.encode(content) else { return "" }
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
