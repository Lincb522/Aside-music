import Combine
import Foundation
import UIKit

// MARK: - 真实听歌时长记录器

/// 把「真实听了多少秒」持续写回当前播放日志行（PlayHistory）。
///
/// 计时不再用挂钟或界面播放状态（它们会把缓冲、断流、加载、
/// 蓝牙中断后的假播放状态算进去），直接跟随 Mono 引擎的 PCM 输出计数：
/// · 只有真实音频帧交给音频设备时才累计；
/// · 暂停、加载、缓冲、断流和补零阶段一秒都不计；
/// · seek、进度跳变和 App 前后台切换不会改变统计口径；
/// · 切歌 / 暂停 / 退后台 / 退出时立即结算，播放中每 60 秒兜底落盘；
/// · 听满 95% 记为完整播放。
@MainActor
final class ListeningStatsRecorder {
    static let shared = ListeningStatsRecorder()

    /// 当前跟踪的播放日志行（由 addToHistory 创建后交进来）
    private var record: PlayHistory?
    /// 歌曲总时长（秒，0 = 未知，落盘时再尝试从播放器补齐）
    private var songDurationSeconds = 0
    /// 已累计的真实可听输出秒数
    private var accumulated: TimeInterval = 0
    /// 上一次采样的引擎累计输出时长（nil = 基线未建立）
    private var lastAudibleOutputDuration: TimeInterval?

    private var flushTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var observersInstalled = false

    private init() {}

    // MARK: 会话

    /// 新歌开播：结算上一首，开始跟踪新行
    func beginSession(record: PlayHistory, song: Song) {
        installObserversIfNeeded()
        finalizeSession()

        self.record = record
        songDurationSeconds = (song.dt ?? 0) / 1000
        accumulated = 0
        lastAudibleOutputDuration = nil
        startFlushTimer()
    }

    /// 结算当前会话并停止跟踪
    func finalizeSession() {
        persistProgress(final: true)
        record = nil
        songDurationSeconds = 0
        accumulated = 0
        lastAudibleOutputDuration = nil
        stopFlushTimer()
    }

    // MARK: 可听输出采样

    /// 每次播放进度更新时取一次引擎计数。这里不信任 UI 的 isPlaying：
    /// 引擎没有送出真实 PCM 时计数本身不会动，送出了就代表用户确实听到了。
    private func sampleAudibleOutput() {
        guard record != nil else { return }
        let outputDuration = PlayerManager.shared.streamPlayer.totalAudiblePlaybackDuration
        guard outputDuration.isFinite, !outputDuration.isNaN, outputDuration >= 0 else { return }

        defer { lastAudibleOutputDuration = outputDuration }
        guard let last = lastAudibleOutputDuration else { return }

        let delta = outputDuration - last
        if delta > 0 {
            accumulated += delta
        }
    }

    private var liveSeconds: Int {
        let audibleSeconds = max(0, Int(accumulated.rounded(.down)))
        guard songDurationSeconds > 0 else { return audibleSeconds }
        return min(audibleSeconds, songDurationSeconds)
    }

    // MARK: 落盘

    private func persistProgress(final: Bool = false) {
        guard let record else { return }
        // 捕获距离上次 UI 进度回调之间已经真实输出的最后一小段音频。
        sampleAudibleOutput()

        // 开播时拿不到时长的来源（如部分 QQ 曲目），落盘时从播放器补一次
        // 只允许当前仍是同一首时补值；切歌结算上一首时，播放器时长已经
        // 可能属于下一首，不能拿来裁剪上一条记录。
        let currentSong = PlayerManager.shared.currentSong
        let isStillCurrentSong = currentSong?.id == record.songId
            && currentSong?.source?.rawValue == record.sourceRaw
        if songDurationSeconds <= 0, isStillCurrentSong {
            let playerDuration = PlaybackTimePublisher.shared.duration
            if playerDuration.isFinite, playerDuration > 0 {
                songDurationSeconds = Int(playerDuration)
            }
        }

        let seconds = liveSeconds
        guard seconds > 0 || final else { return }

        record.playDuration = seconds
        if songDurationSeconds > 0 {
            record.completed = Double(seconds) >= Double(songDurationSeconds) * 0.95
        }
        HistoryRepository().savePlayHistoryUpdates()
        LocalPlaylistCloudSyncManager.shared.scheduleSyncForLocalMutation()
    }

    // MARK: 播放状态与生命周期

    private func installObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true

        // UI 进度只作为采样节拍；实际累计值来自渲染器的 PCM 输出计数。
        PlaybackTimePublisher.shared.$currentTime
            .sink { [weak self] _ in
                self?.sampleAudibleOutput()
            }
            .store(in: &cancellables)

        // 暂停瞬间落盘一次。
        PlayerManager.shared.$isPlaying
            .removeDuplicates()
            .sink { [weak self] playing in
                guard let self else { return }
                if playing {
                    // 恢复后重建基线；暂停期间的引擎计数本应保持不动，
                    // 重建可额外隔离音频会话恢复时的边界状态。
                    self.lastAudibleOutputDuration = nil
                } else {
                    self.persistProgress()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: UIApplication.willResignActiveNotification
        )
        .sink { [weak self] _ in
            guard let self else { return }
            // 退后台不结束会话（后台播放继续算），只兜底落盘一次
            self.persistProgress()
        }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: UIApplication.willTerminateNotification
        )
        .sink { [weak self] _ in
            guard let self else { return }
            self.persistProgress(final: true)
        }
        .store(in: &cancellables)
    }

    private func startFlushTimer() {
        stopFlushTimer()
        flushTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                ListeningStatsRecorder.shared.persistProgress()
            }
        }
        flushTimer?.tolerance = 10
    }

    private func stopFlushTimer() {
        flushTimer?.invalidate()
        flushTimer = nil
    }
}
