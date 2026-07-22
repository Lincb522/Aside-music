// WidgetPlaybackSync.swift
// Monologue
//
// 桌面小组件数据同步：App Group 键值、整首同步歌词文件（widget_lyrics.json）、
// BPM 节奏分析结果，以及带签名去重的 WidgetCenter 刷新，避免浪费系统刷新配额。
// 由 PlayerManager 强持有；`syncWidgetState()` 通过 PlayerManager facade 暴露。

import Foundation
import WidgetKit

@MainActor
final class WidgetPlaybackSync {

    unowned let player: PlayerManager

    init(player: PlayerManager) {
        self.player = player
    }

    // MARK: - App Group 键

    private static let widgetGroupID = "group.zijiu.Monologue.com"
    private static let widgetTempoBPMKey = "widget_tempo_bpm"
    private static let widgetTempoAnalyzingKey = "widget_tempo_analyzing"
    private static let widgetAlbumNameKey = "widget_album_name"
    private static let widgetSourceKey = "widget_source"
    private static let widgetQualityKey = "widget_quality"
    private static let widgetPlayModeKey = "widget_play_mode"
    private static let widgetQueueIndexKey = "widget_queue_index"
    private static let widgetQueueCountKey = "widget_queue_count"
    private static let widgetCurrentTimeKey = "widget_current_time"
    private static let widgetDurationKey = "widget_duration"
    private static let widgetProgressReferenceDateKey = "widget_progress_reference_date"

    // MARK: - 刷新去重状态

    private var lastWidgetSongName: String = ""
    private var lastWidgetPlaybackState: PlaybackSurfaceState = .idle
    private var lastWidgetMetadataSignature: String = ""
    private var lastWidgetLyricText: String = ""
    private var lastWidgetLyricsSignature: String = ""
    private var lastWidgetProgressAnchorTime: TimeInterval = 0
    private var lastWidgetProgressAnchorDate: Date?
    private var lastWidgetProgressDuration: TimeInterval = 0
    private var lastWidgetTempoSongID: Int?
    private var widgetTempoSyncTask: Task<Void, Never>?

    // MARK: - Widget 数据同步

    func syncWidgetState() {
        guard let defaults = UserDefaults(suiteName: Self.widgetGroupID) else { return }
        let player = self.player
        let songName = player.currentSong?.name ?? ""
        let artistName = player.currentSong?.artistName ?? ""
        let albumName = player.currentSong?.album?.name ?? ""
        let sourceName = player.currentSong?.musicSource.widgetDisplayName ?? ""
        let qualityText = player.currentSong == nil ? "" : (player.qualityInfoText ?? player.qualityButtonText)
        let playModeText = widgetPlayModeText
        let queueCount = player.currentSong == nil ? 0 : max(player.currentContextList.count, 1)
        let queueIndex = player.currentSong == nil ? 0 : min(max(player.currentIndexInContext + 1, 1), queueCount)
        let playbackState = player.playbackSurfaceState
        let progressReferenceDate = Date()
        let safeCurrentTime = player.currentSong == nil ? 0 : max(player.currentTime, 0)
        let safeDuration = player.currentSong == nil
            ? 0
            : max(player.effectivePlaybackDuration, 0)
        defaults.set(songName, forKey: "widget_songName")
        defaults.set(artistName, forKey: "widget_artistName")
        defaults.set(player.currentSong?.id ?? 0, forKey: "widget_song_id")
        defaults.set(playbackState.rawValue, forKey: "widget_playbackState")
        defaults.set(playbackState.isPlaying, forKey: "widget_isPlaying")
        defaults.set(albumName, forKey: Self.widgetAlbumNameKey)
        defaults.set(sourceName, forKey: Self.widgetSourceKey)
        defaults.set(qualityText, forKey: Self.widgetQualityKey)
        defaults.set(playModeText, forKey: Self.widgetPlayModeKey)
        defaults.set(queueIndex, forKey: Self.widgetQueueIndexKey)
        defaults.set(queueCount, forKey: Self.widgetQueueCountKey)
        defaults.set(safeCurrentTime, forKey: Self.widgetCurrentTimeKey)
        defaults.set(safeDuration, forKey: Self.widgetDurationKey)
        defaults.set(progressReferenceDate, forKey: Self.widgetProgressReferenceDateKey)
        let lyricVM = LyricViewModel.shared
        let lyricText: String = {
            guard let song = player.currentSong,
                  lyricVM.currentSongId == song.id,
                  lyricVM.hasLyrics,
                  let text = lyricVM.currentLineText else { return "" }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }()
        defaults.set(lyricText, forKey: "widget_lyricText")
        let lyricsSignature = syncWidgetLyricsFile(lyricVM: lyricVM)
        syncWidgetTempo(for: player.currentSong, playbackState: playbackState, defaults: defaults)
        let metadataSignature = [
            songName,
            artistName,
            albumName,
            sourceName,
            qualityText,
            playModeText,
            "\(queueIndex)",
            "\(queueCount)"
        ].joined(separator: "|")
        let expectedWidgetProgressTime: TimeInterval = {
            guard let anchorDate = lastWidgetProgressAnchorDate else {
                return lastWidgetProgressAnchorTime
            }
            let elapsed = lastWidgetPlaybackState.isPlaying ? max(0, progressReferenceDate.timeIntervalSince(anchorDate)) : 0
            guard lastWidgetProgressDuration > 0 else {
                return lastWidgetProgressAnchorTime + elapsed
            }
            return min(lastWidgetProgressAnchorTime + elapsed, lastWidgetProgressDuration)
        }()
        let progressNeedsReload =
            player.currentSong != nil &&
            (abs(safeCurrentTime - expectedWidgetProgressTime) > 2.5 ||
             abs(safeDuration - lastWidgetProgressDuration) > 0.5)
        // 有整首同步歌词时，逐句换行由 Widget 侧预生成的时间线自动推进，
        // 不再为每句歌词触发 reload（节省系统刷新配额）；无同步歌词时保留逐句兜底。
        let hasSyncedLyrics = !lyricsSignature.isEmpty
        let lyricNeedsReload = hasSyncedLyrics
            ? lyricsSignature != lastWidgetLyricsSignature
            : lyricText != lastWidgetLyricText
        if songName != lastWidgetSongName
            || playbackState != lastWidgetPlaybackState
            || metadataSignature != lastWidgetMetadataSignature
            || lyricNeedsReload
            || progressNeedsReload {
            lastWidgetSongName = songName
            lastWidgetPlaybackState = playbackState
            lastWidgetMetadataSignature = metadataSignature
            lastWidgetLyricText = lyricText
            lastWidgetLyricsSignature = lyricsSignature
            lastWidgetProgressAnchorTime = safeCurrentTime
            lastWidgetProgressAnchorDate = progressReferenceDate
            lastWidgetProgressDuration = safeDuration
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// 把整首歌的逐行同步歌词写入 App Group，供 Widget 预生成未来时间线。
    /// 返回本次歌词内容的签名；无同步歌词时清空文件并返回空字符串。
    private func syncWidgetLyricsFile(lyricVM: LyricViewModel) -> String {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.widgetGroupID) else { return "" }
        let fileURL = containerURL.appendingPathComponent("widget_lyrics.json")

        guard let song = player.currentSong,
              lyricVM.currentSongId == song.id,
              lyricVM.hasLyrics,
              !lyricVM.lyrics.isEmpty else {
            if lastWidgetLyricsSignature != "" || FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }
            return ""
        }

        let signature = "\(song.id)|\(lyricVM.lyrics.count)"
        guard signature != lastWidgetLyricsSignature else { return signature }

        var lines: [[String: Any]] = []
        lines.reserveCapacity(lyricVM.lyrics.count)
        for line in lyricVM.lyrics {
            guard line.time.isFinite else { continue }
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            var item: [String: Any] = ["t": line.time, "x": text]
            if let translation = line.translation?.trimmingCharacters(in: .whitespacesAndNewlines),
               !translation.isEmpty {
                item["tr"] = translation
            }
            lines.append(item)
        }
        let payload: [String: Any] = ["songId": song.id, "lines": lines]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return "" }
        do {
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            AppLogger.warning("小组件歌词文件写入失败: \(error)")
            return ""
        }
        return signature
    }

    // MARK: - BPM 节奏同步

    private func syncWidgetTempo(
        for song: Song?,
        playbackState: PlaybackSurfaceState,
        defaults: UserDefaults
    ) {
        let songID = song?.id
        let hasTempoValue = (defaults.object(forKey: Self.widgetTempoBPMKey) as? Int).map { $0 > 0 } ?? false
        let shouldRetrySameSong = lastWidgetTempoSongID == songID
            && !hasTempoValue
            && widgetTempoSyncTask == nil
            && playbackState.isPlaying

        guard lastWidgetTempoSongID != songID || shouldRetrySameSong else { return }

        if lastWidgetTempoSongID != songID {
            lastWidgetTempoSongID = songID
            widgetTempoSyncTask?.cancel()
            widgetTempoSyncTask = nil
        }

        guard let song else {
            clearWidgetTempo(in: defaults, reload: true)
            return
        }

        if let cachedAnalysis = cachedWidgetTempoAnalysis(for: song.id) {
            writeWidgetTempo(from: cachedAnalysis, songID: song.id, defaults: defaults)
            return
        }

        guard playbackState.isPlaying else {
            defaults.removeObject(forKey: Self.widgetTempoBPMKey)
            defaults.set(false, forKey: Self.widgetTempoAnalyzingKey)
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        defaults.removeObject(forKey: Self.widgetTempoBPMKey)
        defaults.set(true, forKey: Self.widgetTempoAnalyzingKey)
        WidgetCenter.shared.reloadAllTimelines()

        let requestedSongID = song.id
        let requestedSong = song
        widgetTempoSyncTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.widgetTempoSyncTask = nil }

            var resolvedAnalysis: AudioAnalysisResult?
            for attempt in 0..<2 {
                guard !Task.isCancelled else { return }

                if let analysis = await AudioLabManager.shared.estimateTempoFromCurrentPlayback(for: requestedSong) {
                    resolvedAnalysis = analysis
                    break
                }

                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 900_000_000)
                }
            }

            guard !Task.isCancelled,
                  self.player.currentSong?.id == requestedSongID,
                  let defaults = UserDefaults(suiteName: Self.widgetGroupID) else {
                return
            }

            if let analysis = resolvedAnalysis ?? self.cachedWidgetTempoAnalysis(for: requestedSongID) {
                self.writeWidgetTempo(from: analysis, songID: requestedSongID, defaults: defaults)
            } else {
                self.clearWidgetTempo(in: defaults, reload: true)
            }
        }
    }

    private func cachedWidgetTempoAnalysis(for songID: Int) -> AudioAnalysisResult? {
        AudioLabManager.shared.cachedAnalysis(for: songID)
    }

    private func writeWidgetTempo(from analysis: AudioAnalysisResult, songID: Int, defaults: UserDefaults) {
        guard player.currentSong?.id == songID else { return }

        let bpmValue = Int(analysis.bpm.rounded())
        guard bpmValue > 0 else {
            clearWidgetTempo(in: defaults, reload: true)
            return
        }

        defaults.set(bpmValue, forKey: Self.widgetTempoBPMKey)
        defaults.set(false, forKey: Self.widgetTempoAnalyzingKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func clearWidgetTempo(in defaults: UserDefaults, reload: Bool) {
        defaults.removeObject(forKey: Self.widgetTempoBPMKey)
        defaults.set(false, forKey: Self.widgetTempoAnalyzingKey)

        if reload {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private var widgetPlayModeText: String {
        switch player.mode {
        case .sequence:
            return "顺序"
        case .loopSingle:
            return "单曲循环"
        case .shuffle:
            return "随机"
        }
    }

    /// deinit 清理
    func cancelPendingWork() {
        widgetTempoSyncTask?.cancel()
        widgetTempoSyncTask = nil
    }
}

// MARK: - PlayerManager facade

extension PlayerManager {

    func syncWidgetState() {
        widgetSync.syncWidgetState()
    }
}
