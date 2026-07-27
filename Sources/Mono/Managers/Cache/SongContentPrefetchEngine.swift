import Combine
import Foundation

/// 在歌曲真正开始播放后，后台预热歌曲幕后内容。
///
/// 这个引擎只负责触发服务端的幂等 ensure 请求：已有持久化内容时服务端直接返回，
/// 没有内容时由服务端创建唯一生成任务。它不把生成结果塞进播放器状态，也不会阻塞播放。
@MainActor
final class SongContentPrefetchEngine {
    private weak var player: PlayerManager?
    private var playbackObservation: AnyCancellable?
    private var requestTasks: [SongContentRequestIdentity: Task<Void, Never>] = [:]
    private var startedIdentities = Set<SongContentRequestIdentity>()
    private let maximumRememberedIdentities = 256

    init(player: PlayerManager) {
        self.player = player
    }

    func start() {
        guard playbackObservation == nil else { return }
        guard let player else { return }

        playbackObservation = player.$currentSong
            .combineLatest(player.$isPlaying)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] song, isPlaying in
                guard isPlaying, let song else { return }
                self?.prefetch(song: song)
            }
    }

    func stop() {
        playbackObservation?.cancel()
        playbackObservation = nil
        requestTasks.values.forEach { $0.cancel() }
        requestTasks.removeAll()
    }

    private func prefetch(song: Song) {
        let identity = song.contentRequestIdentity
        guard startedIdentities.insert(identity).inserted else { return }

        if startedIdentities.count > maximumRememberedIdentities {
            // 按播放会话限制集合大小；服务端/本地缓存仍然是最终去重层。
            startedIdentities.removeAll(keepingCapacity: true)
            startedIdentities.insert(identity)
        }

        requestTasks[identity] = Task { [weak self] in
            guard let self else { return }
            defer { self.requestTasks[identity] = nil }
            do {
                if await SongContentDetailCache.shared.response(for: identity) != nil {
                    return
                }

                let configuration = await SongContentConfigurationStore.shared.configuration()
                guard configuration.enabled, !Task.isCancelled else { return }

                let response = try await APIService.shared.ensureSongContent(song: song)
                if response.content?.hasPublishedCopy == true {
                    await SongContentDetailCache.shared.storePublished(response, for: identity)
                }
                AppLogger.debug("Song content prefetch scheduled: \(identity.cacheKey)")
            } catch is CancellationError {
                return
            } catch {
                // 预取是增强能力，网络或身份未确认时不影响当前歌曲播放。
                self.startedIdentities.remove(identity)
                AppLogger.debug("Song content prefetch unavailable for \(identity.cacheKey): \(error)")
            }
        }
    }
}
