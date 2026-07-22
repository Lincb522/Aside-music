// NowPlayingController.swift
// Monologue
//
// 锁屏/控制中心 Now Playing 信息：元数据构建与修复、封面下载/取色/缓存、
// MPRemoteCommandCenter 命令注册与按内容类型（音乐/播客）切换布局。
// 由 PlayerManager 强持有；常用入口通过 PlayerManager 上的同名 facade 暴露。

import Foundation
import MediaPlayer
import UIKit
import WidgetKit

@MainActor
final class NowPlayingController {

    unowned let player: PlayerManager

    init(player: PlayerManager) {
        self.player = player
    }

    let commandCenter = MPRemoteCommandCenter.shared()

    /// 上一次写入锁屏的歌词行号（-1 表示未写过），用于歌词换行去重
    var lastNowPlayingLyricIndex: Int = -1

    // MARK: - 锁屏封面缓存（避免重复下载 + 取色）
    /// 已完成封面管线的歌曲 ID / 封面 URL / 生成的锁屏 artwork
    private var cachedArtworkSongId: String?
    private var cachedArtworkCoverURL: URL?
    private var cachedArtworkImage: MPMediaItemArtwork?
    /// 生成缓存时的取色配置签名（颜色数|模式|随机种子），配置变了要重跑取色
    private var cachedArtworkPaletteSignature: String = ""
    /// 正在下载封面的歌曲 ID（同曲去重：loadAndPlay 与 startPlayback 会连续触发两次）
    private var artworkFetchInFlightSongId: String?
    /// 上次应用的锁屏命令布局（true = 播客 ±15s/倍速，false = 音乐 上/下一首）
    private var lastRemoteCommandProfileIsPodcast: Bool?

    private static let widgetGroupID = "group.zijiu.Monologue.com"

    // MARK: - Now Playing Info

    func clearNowPlayingInfo() {
        lastNowPlayingLyricIndex = -1
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// iOS may discard Now Playing metadata after a media-service reset, a long
    /// background transition, or an audio-session ownership change. Time-only
    /// updates cannot recover from a nil/incomplete dictionary, so rebuild the
    /// complete identity and artwork from the current PlayerManager state.
    func repairSystemPlaybackSurfacesIfNeeded(reason: String) {
        guard let song = player.currentSong else { return }
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        let reportedTitle = info?[MPMediaItemPropertyTitle] as? String
        let reportedIdentity = info?[MPNowPlayingInfoPropertyExternalContentIdentifier] as? String
        let hasUsableIdentity = reportedTitle == song.name
            && reportedIdentity == PlayerManager.playbackIdentityKey(for: song)
            && !(reportedTitle?.isEmpty ?? true)
        guard !hasUsableIdentity else { return }

        if GameModeManager.shared.isActive,
           SettingsManager.shared.gameModeSilentNowPlaying,
           !SettingsManager.shared.gameModeMinimalNowPlaying {
            return
        }

        AppLogger.warning(
            "Now Playing 内容缺失，重新发布 reason=\(reason) song=\(song.name)",
            step: "now-playing.repair"
        )
        updateNowPlayingInfo()
        updateNowPlayingArtwork(for: song)
    }

    func updateNowPlayingInfo() {
        lastNowPlayingLyricIndex = -1
        // 曲目/来源可能变化，按内容类型同步锁屏命令布局（音乐切歌 vs 播客±15s）
        updateRemoteCommandProfile()

        // 游戏模式 + 用户开启「隐藏锁屏/灵动岛信息」
        if GameModeManager.shared.isActive && SettingsManager.shared.gameModeSilentNowPlaying {
            if SettingsManager.shared.gameModeMinimalNowPlaying {
                // 最小化模式：保留歌名 + 极简播放状态，隐藏封面 / 歌手 / 时长
                var minimal = [String: Any]()
                minimal[MPMediaItemPropertyTitle] = player.currentSong?.name ?? ""
                if let currentSong = player.currentSong {
                    minimal[MPNowPlayingInfoPropertyExternalContentIdentifier] = PlayerManager.playbackIdentityKey(for: currentSong)
                }
                // 不填 Artist / Artwork / Duration，让锁屏只剩一行歌名
                minimal[MPNowPlayingInfoPropertyPlaybackRate] = player.isPlaying ? 1.0 : 0.0
                MPNowPlayingInfoCenter.default().nowPlayingInfo = minimal
            } else {
                // 完全隐藏
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            }
            player.syncWidgetState()
            return
        }

        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = player.currentSong?.name ?? ""
        info[MPMediaItemPropertyArtist] = player.currentSong?.artistName ?? ""
        info[MPMediaItemPropertyAlbumTitle] = player.currentSong?.album?.name ?? ""
        info[MPMediaItemPropertyPlaybackDuration] = player.duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
        // 声明媒体类型与非直播，帮助锁屏/CarPlay 渲染正确的控件样式
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        info[MPNowPlayingInfoPropertyIsLiveStream] = false
        if let currentSong = player.currentSong {
            info[MPNowPlayingInfoPropertyExternalContentIdentifier] = PlayerManager.playbackIdentityKey(for: currentSong)
        }
        if player.isPlayingPodcast, let radioName = player.currentSong?.album?.name, !radioName.isEmpty {
            info[MPMediaItemPropertyPodcastTitle] = radioName
        }
        // 锁屏进度按 rate 自行推进；倍速播放时必须上报真实速率，否则进度会漂移
        info[MPNowPlayingInfoPropertyPlaybackRate] = player.isPlaying ? Double(player.playbackSpeed) : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = Double(player.playbackSpeed)
        // 队列位置（CarPlay / 部分锁屏样式会显示「第 x 首，共 y 首」）
        let queueCount = player.currentContextList.count
        if queueCount > 0 {
            info[MPNowPlayingInfoPropertyPlaybackQueueCount] = queueCount
            info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = min(max(player.currentIndexInContext, 0), queueCount - 1)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        player.syncWidgetState()
    }

    func updateNowPlayingTime() {
        // 游戏模式静默：跳过（最小化模式也不更新 time，避免长出进度条）
        if GameModeManager.shared.isActive && SettingsManager.shared.gameModeSilentNowPlaying {
            // 最小化模式下只同步播放状态（是否在播）
            if SettingsManager.shared.gameModeMinimalNowPlaying,
               var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                info[MPNowPlayingInfoPropertyPlaybackRate] = player.isPlaying ? 1.0 : 0.0
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
            return
        }
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
            repairSystemPlaybackSurfacesIfNeeded(reason: "time update found empty metadata")
            return
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = player.isPlaying ? Double(player.playbackSpeed) : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = Double(player.playbackSpeed)
        if player.duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = player.duration
        }

        let lyricVM = LyricViewModel.shared
        if lyricVM.hasLyrics {
            let idx = lyricVM.currentLineIndex
            if idx != lastNowPlayingLyricIndex {
                lastNowPlayingLyricIndex = idx
                if let line = lyricVM.currentLineText, !line.isEmpty {
                    info[MPMediaItemPropertyArtist] = line
                } else {
                    info[MPMediaItemPropertyArtist] = player.currentSong?.artistName ?? ""
                }
                player.syncWidgetState()
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        player.syncWidgetState()
    }

    func updateNowPlayingArtwork(for song: Song?) {
        guard let song, let coverUrl = song.coverUrl else { return }
        let songId = song.id
        let identityKey = PlayerManager.playbackIdentityKey(for: song)

        let palettePreferences = CoverPalettePreferences.shared
        let paletteColorCount = palettePreferences.colorCount
        let paletteMode = palettePreferences.mode
        let paletteRandomSeed = palettePreferences.randomSeed
        let paletteSignature = "\(paletteColorCount)|\(paletteMode.rawValue)|\(paletteRandomSeed)"

        // 命中缓存：同一首歌 + 同一取色配置的封面已处理过（下载/缩略图/
        // 取色/小组件都已就绪），只需把缓存的 artwork 回填锁屏即可。
        // loadAndPlay → startPlayback 会连续触发两次，策略切换/中断恢复
        // 也会重进这里——全部走零开销路径，省掉重复下载与取色。
        if identityKey == cachedArtworkSongId,
           coverUrl == cachedArtworkCoverURL,
           paletteSignature == cachedArtworkPaletteSignature,
           let artwork = cachedArtworkImage {
            applyCachedNowPlayingArtwork(artwork)
            return
        }
        // 同曲下载仍在进行中，避免并发重复下载
        if artworkFetchInFlightSongId == identityKey { return }
        artworkFetchInFlightSongId = identityKey

        let groupID = Self.widgetGroupID

        Task.detached { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: coverUrl)
                guard let image = UIImage(data: data) else {
                    await MainActor.run { [weak self] in
                        guard let self, self.artworkFetchInFlightSongId == identityKey else { return }
                        self.artworkFetchInFlightSongId = nil
                    }
                    return
                }

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
                    sourceSeed: songId
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
                    guard let self else { return }
                    if self.artworkFetchInFlightSongId == identityKey {
                        self.artworkFetchInFlightSongId = nil
                    }
                    guard let current = self.player.currentSong,
                          PlayerManager.playbackIdentityKey(for: current) == identityKey else { return }
                    // 记入缓存：后续同曲重进（策略切换/中断恢复/二次调用）零开销回填
                    self.cachedArtworkSongId = identityKey
                    self.cachedArtworkCoverURL = coverUrl
                    self.cachedArtworkImage = artwork
                    self.cachedArtworkPaletteSignature = paletteSignature
                    self.applyCachedNowPlayingArtwork(artwork)
                    WidgetCenter.shared.reloadAllTimelines()
                }
            } catch {
                AppLogger.warning("封面图下载失败: \(error)")
                await MainActor.run { [weak self] in
                    guard let self, self.artworkFetchInFlightSongId == identityKey else { return }
                    self.artworkFetchInFlightSongId = nil
                }
            }
        }
    }

    /// 把（缓存的）封面塞进锁屏 Now Playing。游戏模式静默时保持纯文字。
    private func applyCachedNowPlayingArtwork(_ artwork: MPMediaItemArtwork) {
        let silentMinimal = GameModeManager.shared.isActive
            && SettingsManager.shared.gameModeSilentNowPlaying
        guard !silentMinimal else { return }
        repairSystemPlaybackSurfacesIfNeeded(reason: "artwork apply found incomplete metadata")
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func refreshPlaybackSurfaceState() {
        if player.currentSong == nil {
            clearNowPlayingInfo()
        } else {
            repairSystemPlaybackSurfacesIfNeeded(reason: "playback surface refresh")
            updateNowPlayingTime()
        }

        player.syncWidgetState()

        #if canImport(ActivityKit) && os(iOS)
        Task { @MainActor [player] in
            if player.currentSong == nil {
                await LyricsLiveActivityManager.shared.endCurrentActivity()
            } else {
                await LyricsLiveActivityManager.shared.sync(with: player)
            }
        }
        #endif
    }

    // MARK: - 远程命令（锁屏 / 控制中心 / CarPlay）

    func setupRemoteCommands() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        // Media services can reset independently of the app process. Re-register
        // idempotently so a reset does not leave stale or duplicated handlers.
        let managedCommands: [MPRemoteCommand] = [
            commandCenter.playCommand,
            commandCenter.pauseCommand,
            commandCenter.togglePlayPauseCommand,
            commandCenter.nextTrackCommand,
            commandCenter.previousTrackCommand,
            commandCenter.skipForwardCommand,
            commandCenter.skipBackwardCommand,
            commandCenter.changePlaybackRateCommand,
            commandCenter.changePlaybackPositionCommand,
            commandCenter.changeRepeatModeCommand,
            commandCenter.changeShuffleModeCommand,
        ]
        managedCommands.forEach { $0.removeTarget(nil) }
        lastRemoteCommandProfileIsPodcast = nil

        commandCenter.playCommand.addTarget { [weak self] _ in
            (self?.player.playPlayback() ?? false) ? .success : .commandFailed
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            (self?.player.pausePlayback() ?? false) ? .success : .commandFailed
        }
        // 有线/蓝牙耳机的单击「播放暂停切换」走的是 toggle 命令，
        // 不注册的话部分耳机按键会没有反应。
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let player = self?.player else { return .commandFailed }
            let handled = player.isPlaying ? player.pausePlayback() : player.playPlayback()
            return handled ? .success : .commandFailed
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.player.next()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.player.previous()
            return .success
        }
        // 播客场景的锁屏 ±15s 快进快退（由 updateRemoteCommandProfile 按内容类型启停）
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let player = self?.player else { return .commandFailed }
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            player.seekForward(seconds: interval)
            return .success
        }
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let player = self?.player else { return .commandFailed }
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            player.seekBackward(seconds: interval)
            return .success
        }
        // 播客倍速（CarPlay / 锁屏长按等入口）
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates =
            [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0].map { NSNumber(value: $0) }
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let player = self?.player, let event = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            player.setPlaybackSpeed(event.playbackRate)
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.player.seek(to: event.positionTime)
            }
            return .success
        }
        // 锁屏 / CarPlay 的循环与随机模式切换
        commandCenter.changeRepeatModeCommand.isEnabled = true
        commandCenter.changeRepeatModeCommand.addTarget { [weak self] event in
            guard let self, let event = event as? MPChangeRepeatModeCommandEvent else { return .commandFailed }
            switch event.repeatType {
            case .one:
                self.applyRemotePlayMode(.loopSingle)
            case .all, .off:
                self.applyRemotePlayMode(self.player.mode == .shuffle ? .shuffle : .sequence)
            @unknown default:
                return .commandFailed
            }
            return .success
        }
        commandCenter.changeShuffleModeCommand.isEnabled = true
        commandCenter.changeShuffleModeCommand.addTarget { [weak self] event in
            guard let self, let event = event as? MPChangeShuffleModeCommandEvent else { return .commandFailed }
            switch event.shuffleType {
            case .off:
                self.applyRemotePlayMode(.sequence)
            case .items, .collections:
                self.applyRemotePlayMode(.shuffle)
            @unknown default:
                return .commandFailed
            }
            return .success
        }

        // 冷启动先按音乐布局收敛一次（系统默认所有命令都是 enabled，
        // 不收敛的话锁屏可能同时挂着切歌和 ±15s 两套按钮）
        updateRemoteCommandProfile()
    }

    /// 按内容类型切换锁屏/控制中心的命令布局：
    ///   - 音乐 / FM：上一首、下一首 + 循环/随机切换；
    ///   - 播客：±15s 快进快退 + 倍速（系统在禁用上/下一首时才会把
    ///     锁屏两侧按钮渲染成跳转间隔样式）。
    /// 由 updateNowPlayingInfo 在每次曲目/来源变化时调用，幂等且去重。
    func updateRemoteCommandProfile() {
        let podcast = player.isPlayingPodcast
        guard lastRemoteCommandProfileIsPodcast != podcast else { return }
        lastRemoteCommandProfileIsPodcast = podcast

        commandCenter.skipForwardCommand.isEnabled = podcast
        commandCenter.skipBackwardCommand.isEnabled = podcast
        commandCenter.changePlaybackRateCommand.isEnabled = podcast
        commandCenter.nextTrackCommand.isEnabled = !podcast
        commandCenter.previousTrackCommand.isEnabled = !podcast
        commandCenter.changeRepeatModeCommand.isEnabled = !podcast
        commandCenter.changeShuffleModeCommand.isEnabled = !podcast
    }

    /// 远程命令（锁屏 / CarPlay）触发的播放模式切换
    private func applyRemotePlayMode(_ newMode: PlayerManager.PlayMode) {
        let player = self.player
        guard newMode != player.mode else { return }
        player.mode = newMode
        if player.mode == .shuffle {
            player.generateShuffledContext()
        } else if let current = player.currentSong {
            player.contextIndex = player.context.firstIndex(where: { $0.id == current.id }) ?? 0
        }
        player.saveState()
        player.syncWidgetState()
    }
}

// MARK: - PlayerManager facade（外部与引擎扩展调用点保持不变）

extension PlayerManager {

    func clearNowPlayingInfo() {
        nowPlayingController.clearNowPlayingInfo()
    }

    func repairSystemPlaybackSurfacesIfNeeded(reason: String) {
        nowPlayingController.repairSystemPlaybackSurfacesIfNeeded(reason: reason)
    }

    func updateNowPlayingInfo() {
        nowPlayingController.updateNowPlayingInfo()
    }

    func updateNowPlayingTime() {
        nowPlayingController.updateNowPlayingTime()
    }

    func updateNowPlayingArtwork(for song: Song?) {
        nowPlayingController.updateNowPlayingArtwork(for: song)
    }

    func refreshPlaybackSurfaceState() {
        nowPlayingController.refreshPlaybackSurfaceState()
    }
}
