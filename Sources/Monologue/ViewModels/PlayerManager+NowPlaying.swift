// PlayerManager+NowPlaying.swift
// Monologue
//
// 锁屏/控制中心 Now Playing 信息更新 + 桌面小组件数据同步

import Foundation
import MediaPlayer
import UIKit
import WidgetKit

extension PlayerManager {
    
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
    
    // MARK: - Now Playing Info

    func clearNowPlayingInfo() {
        lastNowPlayingLyricIndex = -1
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func updateNowPlayingInfo() {
        lastNowPlayingLyricIndex = -1

        // 游戏模式 + 用户开启「隐藏锁屏/灵动岛信息」
        if GameModeManager.shared.isActive && SettingsManager.shared.gameModeSilentNowPlaying {
            if SettingsManager.shared.gameModeMinimalNowPlaying {
                // 最小化模式：保留歌名 + 极简播放状态，隐藏封面 / 歌手 / 时长
                var minimal = [String: Any]()
                minimal[MPMediaItemPropertyTitle] = currentSong?.name ?? ""
                // 不填 Artist / Artwork / Duration，让锁屏只剩一行歌名
                minimal[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
                MPNowPlayingInfoCenter.default().nowPlayingInfo = minimal
            } else {
                // 完全隐藏
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            }
            syncWidgetState()
            return
        }

        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = currentSong?.name ?? ""
        info[MPMediaItemPropertyArtist] = currentSong?.artistName ?? ""
        info[MPMediaItemPropertyAlbumTitle] = currentSong?.album?.name ?? ""
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        syncWidgetState()
    }
    
    func updateNowPlayingTime() {
        // 游戏模式静默：跳过（最小化模式也不更新 time，避免长出进度条）
        if GameModeManager.shared.isActive && SettingsManager.shared.gameModeSilentNowPlaying {
            // 最小化模式下只同步播放状态（是否在播）
            if SettingsManager.shared.gameModeMinimalNowPlaying,
               var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
            return
        }
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        
        let lyricVM = LyricViewModel.shared
        if lyricVM.hasLyrics {
            let idx = lyricVM.currentLineIndex
            if idx != lastNowPlayingLyricIndex {
                lastNowPlayingLyricIndex = idx
                if let line = lyricVM.currentLineText, !line.isEmpty {
                    info[MPMediaItemPropertyArtist] = line
                } else {
                    info[MPMediaItemPropertyArtist] = currentSong?.artistName ?? ""
                }
                syncWidgetState()
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        syncWidgetState()
    }
    
    func updateNowPlayingArtwork(for song: Song?) {
        guard let coverUrl = song?.coverUrl else { return }
        let songId = song?.id
        let groupID = Self.widgetGroupID
        let palettePreferences = CoverPalettePreferences.shared
        let paletteColorCount = palettePreferences.colorCount
        let paletteMode = palettePreferences.mode
        let paletteRandomSeed = palettePreferences.randomSeed
        
        Task.detached { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: coverUrl)
                guard let image = UIImage(data: data) else { return }
                
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                
                let thumbSize = CGSize(width: 220, height: 220)
                let renderer = UIGraphicsImageRenderer(size: thumbSize)
                let thumbnail = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: thumbSize))
                }
                
                let colors = image.extractColors(
                    count: paletteColorCount,
                    mode: paletteMode,
                    randomSeed: paletteRandomSeed,
                    sourceSeed: songId ?? 0
                )
                var dominantRGB: [CGFloat] = [0.15, 0.12, 0.25]
                var secondaryRGB: [CGFloat] = [0.10, 0.10, 0.18]
                var paletteRGB: [[CGFloat]] = []
                var coverIsDark = true
                if let dComps = UIColor(colors.dominant).cgColor.components, dComps.count >= 3 {
                    dominantRGB = [dComps[0], dComps[1], dComps[2]]
                }
                if let sComps = UIColor(colors.secondary).cgColor.components, sComps.count >= 3 {
                    secondaryRGB = [sComps[0], sComps[1], sComps[2]]
                }
                paletteRGB = colors.palette.compactMap { color in
                    let components = UIColor(color).cgColor.components ?? []
                    guard components.count >= 3 else { return nil }
                    return [components[0], components[1], components[2]]
                }
                coverIsDark = colors.isDark
                
                if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
                    if let jpegData = thumbnail.jpegData(compressionQuality: 0.72) {
                        let fileURL = containerURL.appendingPathComponent("widget_cover.jpg")
                        try? jpegData.write(to: fileURL, options: .atomic)
                    }
                    let defaults = UserDefaults(suiteName: groupID)
                    defaults?.set(dominantRGB, forKey: "widget_dominantRGB")
                    defaults?.set(secondaryRGB, forKey: "widget_secondaryRGB")
                    defaults?.set(paletteRGB, forKey: "widget_paletteRGB")
                    defaults?.set(coverIsDark, forKey: "widget_coverIsDark")
                }
                
                await MainActor.run { [weak self] in
                    guard let self = self, self.currentSong?.id == songId else { return }
                    // 游戏模式静默 + 最小化：不回塞封面，保持锁屏纯文字
                    let silentMinimal = GameModeManager.shared.isActive
                        && SettingsManager.shared.gameModeSilentNowPlaying
                    if !silentMinimal {
                        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        info[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                    }
                    WidgetCenter.shared.reloadAllTimelines()
                }
            } catch {
                AppLogger.warning("封面图下载失败: \(error)")
            }
        }
    }

    func refreshPlaybackSurfaceState() {
        if currentSong == nil {
            clearNowPlayingInfo()
        } else if MPNowPlayingInfoCenter.default().nowPlayingInfo == nil {
            updateNowPlayingInfo()
        } else {
            updateNowPlayingTime()
        }

        syncWidgetState()

        #if canImport(ActivityKit) && os(iOS)
        Task { @MainActor in
            if currentSong == nil {
                await LyricsLiveActivityManager.shared.endCurrentActivity()
            } else {
                await LyricsLiveActivityManager.shared.sync(with: self)
            }
        }
        #endif
    }
    
    // MARK: - Widget 数据同步
    
    func syncWidgetState() {
        guard let defaults = UserDefaults(suiteName: Self.widgetGroupID) else { return }
        let songName = currentSong?.name ?? ""
        let artistName = currentSong?.artistName ?? ""
        let albumName = currentSong?.album?.name ?? ""
        let sourceName = currentSong?.musicSource.widgetDisplayName ?? ""
        let qualityText = currentSong == nil ? "" : (qualityInfoText ?? qualityButtonText)
        let playModeText = widgetPlayModeText
        let queueCount = currentSong == nil ? 0 : max(currentContextList.count, 1)
        let queueIndex = currentSong == nil ? 0 : min(max(currentIndexInContext + 1, 1), queueCount)
        let playbackState = playbackSurfaceState
        let progressReferenceDate = Date()
        let safeCurrentTime = currentSong == nil ? 0 : max(currentTime, 0)
        let safeDuration = currentSong == nil ? 0 : max(duration, currentSong?.dt.map { Double($0) / 1000.0 } ?? 0)
        defaults.set(songName, forKey: "widget_songName")
        defaults.set(artistName, forKey: "widget_artistName")
        defaults.set(currentSong?.id ?? 0, forKey: "widget_song_id")
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
            guard let song = currentSong,
                  lyricVM.currentSongId == song.id,
                  lyricVM.hasLyrics,
                  let text = lyricVM.currentLineText else { return "" }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }()
        defaults.set(lyricText, forKey: "widget_lyricText")
        let lyricsSignature = syncWidgetLyricsFile(lyricVM: lyricVM)
        syncWidgetTempo(for: currentSong, playbackState: playbackState, defaults: defaults)
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
            currentSong != nil &&
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

        guard let song = currentSong,
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
                  self.currentSong?.id == requestedSongID,
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
        guard currentSong?.id == songID else { return }

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
        switch mode {
        case .sequence:
            return "顺序"
        case .loopSingle:
            return "单曲循环"
        case .shuffle:
            return "随机"
        }
    }
}
