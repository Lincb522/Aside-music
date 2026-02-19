// PlayerManager+Controls.swift
// AsideMusic
//
// 播放控制：暂停/恢复、上/下一首、切换模式、停止、切换音质

import Foundation
import Combine

extension PlayerManager {
    
    // MARK: - Playback Controls
    
    func togglePlayPause() {
        if isPlaying {
            streamPlayer.pause()
            isPlaying = false
        } else {
            streamPlayer.resume()
            isPlaying = true
        }
        updateNowPlayingTime()
    }
    
    func next() {
        consecutiveFailures = 0
        retryDelay = 1.0
        
        if let nextSong = userQueue.first {
            userQueue.removeFirst()
            // 如果歌曲在 context 中，更新索引；否则保持当前索引不变
            // 这样下次从 context 继续时，会从正确的位置接着播
            if let index = currentContextList.firstIndex(where: { $0.id == nextSong.id }) {
                contextIndex = index
            }
            loadAndPlay(song: nextSong)
            return
        }
        
        let list = currentContextList
        guard !list.isEmpty else { return }
        
        var nextIndex = contextIndex + 1
        if nextIndex >= list.count {
            nextIndex = 0
        }
        
        contextIndex = nextIndex
        loadAndPlay(song: list[nextIndex])
    }
    
    func previous() {
        consecutiveFailures = 0
        retryDelay = 1.0
        
        let list = currentContextList
        guard !list.isEmpty else { return }
        
        var prevIndex = contextIndex - 1
        if prevIndex < 0 {
            prevIndex = list.count - 1
        }
        
        contextIndex = prevIndex
        loadAndPlay(song: list[prevIndex])
    }
    
    func switchMode() {
        mode = mode.next
        
        if mode == .shuffle {
            generateShuffledContext()
        } else {
            if let current = currentSong {
                contextIndex = context.firstIndex(where: { $0.id == current.id }) ?? 0
            }
        }
        
        saveState()
    }
    
    func stopAndClear() {
        isUserStopping = true
        streamPlayer.stop()
        isPlaying = false
        currentSong = nil
        streamInfo = nil
        isUserStopping = false
        saveState()
    }
    
    func switchQuality(_ quality: SoundQuality) {
        guard soundQuality != quality else { return }
        
        if let current = currentSong {
            let time = currentTime
            
            Task { @MainActor in
                APIService.shared.fetchSongUrl(
                    id: current.id,
                    level: quality.rawValue,
                    kugouQuality: self.kugouQuality.rawValue
                )
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            AppLogger.error("切换音质失败: \(error)")
                            AlertManager.shared.show(
                                title: "切换失败",
                                message: "无法获取该音质的音频，请稍后重试",
                                primaryButtonTitle: "确定",
                                primaryAction: {}
                            )
                        }
                    }, receiveValue: { [weak self] result in
                        guard let self = self, let url = URL(string: result.url) else { return }
                        self.soundQuality = quality
                        self.isCurrentSongUnblocked = result.isUnblocked
                        self.streamInfo = nil
                        // 记录这是音质切换（不是切歌），seek 位置
                        self.pendingQualitySwitchSeek = time
                        // 用 prepareNext 预加载新音质的 URL
                        self.streamPlayer.prepareNext(url: url.absoluteString)
                        // prepareNext 完成后，用 switchToNext 触发切换
                        self.pollAndSwitch(seekTo: time, attempts: 0)
                    })
                    .store(in: &self.cancellables)
            }
        } else {
            soundQuality = quality
        }
    }
    
    /// 切换酷狗音质（解灰歌曲专用）
    func switchKugouQuality(_ quality: KugouQuality) {
        guard kugouQuality != quality else { return }
        
        if let current = currentSong, isCurrentSongUnblocked {
            let time = currentTime
            
            #if DEBUG
            print("[PlayerManager] switchKugouQuality: \(kugouQuality.rawValue) → \(quality.rawValue)")
            #endif
            
            Task { @MainActor in
                // 已解灰歌曲直接走酷狗解灰源，不尝试网易云
                APIService.shared.fetchUnblockedSongUrl(
                    id: current.id,
                    kugouQuality: quality.rawValue
                )
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            AppLogger.error("切换酷狗音质失败: \(error)")
                            AlertManager.shared.show(
                                title: "切换失败",
                                message: "无法获取该音质的音频，请稍后重试",
                                primaryButtonTitle: "确定",
                                primaryAction: {}
                            )
                        }
                    }, receiveValue: { [weak self] result in
                        guard let self = self, let url = URL(string: result.url) else { return }
                        self.kugouQuality = quality
                        self.streamInfo = nil
                        self.pendingQualitySwitchSeek = time
                        self.streamPlayer.prepareNext(url: url.absoluteString)
                        self.pollAndSwitch(seekTo: time, attempts: 0)
                    })
                    .store(in: &self.cancellables)
            }
        } else {
            kugouQuality = quality
        }
    }
    
    /// 切换 QQ 音乐音质
    func switchQQMusicQuality(_ quality: QQMusicQuality) {
        guard qqMusicQuality != quality else { return }
        
        if let current = currentSong, current.isQQMusic, let mid = current.qqMid {
            let time = currentTime
            
            Task { @MainActor in
                APIService.shared.fetchQQSongUrl(mid: mid, quality: quality)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            AppLogger.error("[QQMusic] 切换音质失败: \(error)")
                            AlertManager.shared.show(
                                title: "切换失败",
                                message: "无法获取该音质的音频，请稍后重试",
                                primaryButtonTitle: "确定",
                                primaryAction: {}
                            )
                        }
                    }, receiveValue: { [weak self] result in
                        guard let self = self, let url = URL(string: result.url) else { return }
                        self.qqMusicQuality = quality
                        self.streamInfo = nil
                        self.pendingQualitySwitchSeek = time
                        self.streamPlayer.prepareNext(url: url.absoluteString)
                        self.pollAndSwitch(seekTo: time, attempts: 0)
                    })
                    .store(in: &self.cancellables)
            }
        } else {
            qqMusicQuality = quality
        }
    }
    
    /// 轮询预加载状态，就绪后触发切换
    func pollAndSwitch(seekTo time: Double, attempts: Int) {
        guard attempts < 200 else {
            // 超时降级（200 * 0.05s = 10s）
            AppLogger.warning("音质切换预加载超时，降级为重新播放")
            pendingQualitySwitchSeek = nil
            streamPlayer.cancelNextPreparation()
            if let song = currentSong {
                loadAndPlay(song: song, startTime: time)
            }
            return
        }
        
        // 每次只尝试触发 switchToNext，如果预加载还没就绪会直接返回
        streamPlayer.switchToNext(seekTo: time)
        
        // 短暂延迟后检查是否已切换
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            if self.pendingQualitySwitchSeek == nil {
                // 已在 delegate 回调中清除，说明切换成功
                return
            }
            self.pollAndSwitch(seekTo: time, attempts: attempts + 1)
        }
    }
}
