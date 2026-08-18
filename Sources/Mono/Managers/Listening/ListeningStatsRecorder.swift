import Combine
import Foundation
import UIKit

// MARK: - 真实听歌时长记录器

/// 统一记录 Mono PCM 管线与 Apple Music 受保护管线的真实可听时长。
///
/// Mono 使用渲染器已经送往音频设备的累计 PCM 时长；Apple Music 无法读取
/// PCM，因此使用单调时钟约束后的 MusicKit 播放位置增量。暂停、加载、seek、
/// 缓冲和单纯的进度跳变都不会增加时长。
@MainActor
final class ListeningStatsRecorder {
    static let shared = ListeningStatsRecorder()

    private var record: PlayHistory?
    private var song: Song?
    private var playbackSessionID: Int?
    private var songDurationSeconds: TimeInterval = 0
    private var accumulated: TimeInterval = 0
    private var lastPersistedLiveSeconds = -1
    private var didCommitEffectivePlayback = false
    private var sessionUsesAppleMusic = false

    private var lastAudibleOutputDuration: TimeInterval?
    private var lastAppleMusicPosition: TimeInterval?
    private var lastAppleMusicSampleUptime: TimeInterval?

    private var flushTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var observersInstalled = false

    private init() {}

    // MARK: - 会话

    func isTracking(playbackSessionID: Int) -> Bool {
        record != nil && self.playbackSessionID == playbackSessionID
    }

    func beginSession(record: PlayHistory, song: Song) {
        installObserversIfNeeded()
        let incomingSessionID = PlayerManager.shared.playbackSessionId
        if playbackSessionID == incomingSessionID, self.record != nil {
            return
        }
        finalizeSession()

        self.record = record
        self.song = song
        playbackSessionID = incomingSessionID
        songDurationSeconds = TimeInterval(max(0, (song.dt ?? 0) / 1_000))
        accumulated = 0
        lastPersistedLiveSeconds = -1
        didCommitEffectivePlayback = false
        sessionUsesAppleMusic = song.isAppleMusic
        resetSamplingBaselines()

        record.trackDuration = Int(songDurationSeconds.rounded(.down))
        record.effectivePlay = false
        record.completed = false
        record.qualificationVersion = ListeningPlaybackPolicy.qualificationVersion
        startFlushTimer()
    }

    func finalizeSession() {
        captureFinalAudibleSample()
        persistProgress(final: true)
        if let record, !ListeningPlaybackPolicy.isEffective(record) {
            HistoryRepository().deletePlayHistory(record)
        }
        record = nil
        song = nil
        playbackSessionID = nil
        songDurationSeconds = 0
        accumulated = 0
        lastPersistedLiveSeconds = -1
        didCommitEffectivePlayback = false
        sessionUsesAppleMusic = false
        resetSamplingBaselines()
        stopFlushTimer()
    }

    // MARK: - 心跳采样

    /// 由播放器唯一心跳调用，确保每个 tick 只上报一次，避免多个计时器重复累计。
    func samplePlayback(
        currentTime: TimeInterval,
        isPlaying: Bool,
        isSeeking: Bool,
        usesAppleMusic: Bool
    ) {
        guard record != nil else { return }
        updateDurationFromCurrentPlayerIfNeeded()

        guard isPlaying, !isSeeking else {
            resetSamplingBaselines()
            return
        }

        if usesAppleMusic {
            sampleAppleMusic(position: currentTime)
        } else {
            sampleMonoAudibleOutput()
        }
        updateRecordAndCommitIfNeeded()
    }

    /// Mono 的真实 PCM 计数只会在音频帧送出时增长。
    private func sampleMonoAudibleOutput() {
        let outputDuration = PlayerManager.shared.streamPlayer.totalAudiblePlaybackDuration
        guard outputDuration.isFinite, !outputDuration.isNaN, outputDuration >= 0 else {
            return
        }

        defer { lastAudibleOutputDuration = outputDuration }
        guard let last = lastAudibleOutputDuration else { return }

        let delta = outputDuration - last
        if delta > 0 {
            accumulated += delta
        }
    }

    /// MusicKit 不暴露 PCM 帧计数。这里要求“播放位置前进量”与单调时钟经过量
    /// 同时合理才累计；大幅跳变会被识别为 seek 而忽略。
    private func sampleAppleMusic(position: TimeInterval) {
        guard position.isFinite, !position.isNaN, position >= 0 else { return }
        let uptime = ProcessInfo.processInfo.systemUptime

        defer {
            lastAppleMusicPosition = position
            lastAppleMusicSampleUptime = uptime
        }
        guard let lastPosition = lastAppleMusicPosition,
              let lastUptime = lastAppleMusicSampleUptime else {
            return
        }

        let wallDelta = uptime - lastUptime
        let positionDelta = position - lastPosition
        guard wallDelta > 0, positionDelta > 0 else { return }

        // 允许后台 1 Hz 心跳、系统调度抖动和极小播放速率误差；
        // 超出该范围即视为拖动进度或 MusicKit 时钟重置。
        let maximumNaturalAdvance = max(0.6, wallDelta * 1.75 + 0.20)
        guard positionDelta <= maximumNaturalAdvance else { return }
        accumulated += min(positionDelta, wallDelta * 1.25 + 0.10)
    }

    private func captureFinalAudibleSample() {
        guard record != nil else { return }
        let player = PlayerManager.shared
        if sessionUsesAppleMusic {
            if let time = player.appleMusicPlayback.renderingPlaybackTime {
                sampleAppleMusic(position: time)
            }
        } else {
            sampleMonoAudibleOutput()
        }
    }

    private func resetSamplingBaselines() {
        lastAudibleOutputDuration = nil
        lastAppleMusicPosition = nil
        lastAppleMusicSampleUptime = nil
    }

    private var liveSeconds: Int {
        let seconds = max(0, Int(accumulated.rounded(.down)))
        guard songDurationSeconds > 0 else { return seconds }
        return min(seconds, Int(songDurationSeconds.rounded(.down)))
    }

    // MARK: - 判定与落盘

    private func updateRecordAndCommitIfNeeded() {
        guard let record else { return }
        let seconds = liveSeconds
        record.playDuration = seconds
        record.trackDuration = Int(songDurationSeconds.rounded(.down))
        record.qualificationVersion = ListeningPlaybackPolicy.qualificationVersion

        let effective = ListeningPlaybackPolicy.isEffective(
            actualPlayback: accumulated,
            trackDuration: songDurationSeconds
        )
        record.effectivePlay = effective
        record.completed = ListeningPlaybackPolicy.isCompleted(
            actualPlayback: accumulated,
            trackDuration: songDurationSeconds
        )

        if effective, !didCommitEffectivePlayback, let song {
            didCommitEffectivePlayback = true
            PlayerManager.shared.commitEffectivePlayback(song: song)
            persistProgress()
        }
    }

    private func persistProgress(final: Bool = false) {
        guard record != nil else { return }
        updateDurationFromCurrentPlayerIfNeeded()
        updateRecordAndCommitIfNeeded()

        let seconds = liveSeconds
        guard seconds > 0 || final else { return }
        guard final || seconds != lastPersistedLiveSeconds else { return }
        HistoryRepository().savePlayHistoryUpdates()
        lastPersistedLiveSeconds = seconds
    }

    private func updateDurationFromCurrentPlayerIfNeeded() {
        guard songDurationSeconds <= 0, let record else { return }
        let player = PlayerManager.shared
        let currentSong = player.currentSong
        let isSameSong = currentSong?.id == record.songId
            && currentSong?.source?.rawValue == record.sourceRaw
        guard isSameSong else { return }

        let duration = player.effectivePlaybackDuration
        if duration.isFinite, duration > 0 {
            songDurationSeconds = duration
        }
    }

    // MARK: - 播放状态与生命周期

    private func installObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true

        PlayerManager.shared.$isPlaying
            .removeDuplicates()
            .sink { [weak self] playing in
                guard let self else { return }
                if playing {
                    self.resetSamplingBaselines()
                } else {
                    self.captureFinalAudibleSample()
                    self.persistProgress()
                    self.resetSamplingBaselines()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.persistProgress()
            }
            .store(in: &cancellables)

        // iOS 终止回调只有极短窗口，不能在其中同步保存 SwiftData 或调度
        // 云端任务。willResignActive 已经先完成进度落盘，进程退出时不再做 I/O。
    }

    private func startFlushTimer() {
        stopFlushTimer()
        flushTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task { @MainActor in
                ListeningStatsRecorder.shared.persistProgress()
            }
        }
        flushTimer?.tolerance = 2
    }

    private func stopFlushTimer() {
        flushTimer?.invalidate()
        flushTimer = nil
    }
}
