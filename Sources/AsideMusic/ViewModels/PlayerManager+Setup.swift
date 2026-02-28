// PlayerManager+Setup.swift
// AsideMusic
//
// 播放器初始化设置：音频会话、远程控制、StreamPlayer 代理、定时器

import Foundation
import AVFoundation
import MediaPlayer
import FFmpegSwiftSDK

extension PlayerManager {
    
    // MARK: - Setup
    
    func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            AppLogger.error("AVAudioSession 配置失败: \(error)")
        }
        
        // 监听音频中断（电话、其他 app 播放等）
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            // 在进入 @MainActor Task 前提取值，避免 Sendable 数据竞争
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                switch type {
                case .began:
                    // 中断开始：暂停播放，记录中断前的状态
                    AppLogger.info("音频中断开始，暂停播放")
                    if self.isPlaying {
                        self.wasPlayingBeforeInterruption = true
                        self.streamPlayer.pause()
                        self.isPlaying = false
                        self.updateNowPlayingTime()
                    }
                case .ended:
                    // 中断结束：根据选项决定是否恢复播放
                    AppLogger.info("音频中断结束")
                    if let optionsValue {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) && self.wasPlayingBeforeInterruption {
                            AppLogger.info("恢复播放")
                            // 重新激活音频会话
                            do {
                                try AVAudioSession.sharedInstance().setActive(true)
                            } catch {
                                AppLogger.error("重新激活音频会话失败: \(error)")
                            }
                            self.streamPlayer.resume()
                            self.isPlaying = true
                            self.updateNowPlayingTime()
                        }
                    }
                    self.wasPlayingBeforeInterruption = false
                @unknown default:
                    break
                }
            }
        }
        
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { _ in
            AppLogger.warning("媒体服务被重置，重建 audio session")
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [])
                try session.setActive(true)
            } catch {
                AppLogger.error("重建 audio session 失败: \(error)")
            }
            // 如果正在播放，重新触发当前歌曲播放（让库重新走 AudioRenderer.start 流程）
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let song = self.currentSong, self.isPlaying {
                    let time = self.currentTime
                    AppLogger.info("媒体服务重置后重新播放: \(song.name), 从 \(String(format: "%.1f", time))s 继续")
                    self.loadAndPlay(song: song, startTime: time)
                }
            }
        }
    }
    
    func setupRemoteCommands() {
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
            }
            return .success
        }
    }
    
    /// 设置 StreamPlayer delegate（通过桥接适配器）
    func setupStreamPlayerDelegate() {
        let adapter = StreamPlayerDelegateAdapter(playerManager: self)
        self.delegateAdapter = adapter
        streamPlayer.delegate = adapter
    }
    
    /// 定时器轮询 StreamPlayer 的 currentTime
    func startTimeUpdateTimer() {
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isPlaying, !self.isLoading else { return }
                
                // ── isSeeking 超时保护（3 秒） ──
                if self.isSeeking {
                    if let target = self.seekTargetTime {
                        let st = self.streamPlayer.currentTime
                        if st.isFinite && !st.isNaN && st >= target - 1.0 {
                            self.isSeeking = false
                            self.seekTargetTime = nil
                            self.seekStartedAt = nil
                            self.currentTime = st
                        } else if let started = self.seekStartedAt,
                                  Date().timeIntervalSince(started) > 3.0 {
                            AppLogger.warning("isSeeking 超时（3s），强制解除")
                            self.isSeeking = false
                            self.seekTargetTime = nil
                            self.seekStartedAt = nil
                            if st.isFinite && !st.isNaN {
                                self.currentTime = st
                            }
                        }
                    } else {
                        self.isSeeking = false
                        self.seekStartedAt = nil
                    }
                    return
                }
                
                // ── hasPendingTrackTransition：无缝切歌过渡 ──
                if self.hasPendingTrackTransition {
                    let time = self.streamPlayer.currentTime
                    if time.isFinite && !time.isNaN && time > 0.1 {
                        AppLogger.info("检测到下一首已开始播放 (\(String(format: "%.2f", time))s)，切换 UI")
                        self.pendingTransitionStartedAt = nil
                        self.applyPendingTrackTransition()
                        return
                    }
                    if let started = self.pendingTransitionStartedAt,
                       Date().timeIntervalSince(started) > 5.0 {
                        AppLogger.warning("hasPendingTrackTransition 超时（5s），强制重置")
                        self.hasPendingTrackTransition = false
                        self.pendingNextSong = nil
                        self.pendingTransitionStartedAt = nil
                        self.playerDidFinishPlaying()
                        return
                    }
                    // 旧音频仍在 AudioRenderer 缓冲区播放，继续推进进度条避免冻结
                    if self.duration > 0 && self.currentTime < self.duration {
                        self.currentTime = min(self.currentTime + 0.5, self.duration)
                        self.updateNowPlayingTime()
                    }
                    return
                }
                
                // ── 正常时间更新 ──
                let time = self.streamPlayer.currentTime
                if time.isFinite && !time.isNaN {
                    let jump = time - self.currentTime
                    if self.currentTime < 1.0 && jump > 2.0 {
                        // 刚开始播放，SDK 的时间不可信（解码缓冲超前），跳过
                    } else if self.currentTime > 10.0 && time < self.currentTime - 5.0 {
                        // 防止无缝切歌时进度条回跳
                    } else {
                        self.currentTime = time
                    }
                }
                self.updateNowPlayingTime()
                
                // 全局歌词同步
                LyricViewModel.shared.updateCurrentTime(self.currentTime)
            }
        }
    }
}
