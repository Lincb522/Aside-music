// MonoPlaybackEngine+Seek.swift
// Monologue
//
// 进度控制：seek、快进、快退

import Foundation

extension PlayerManager {
    
    // MARK: - Seek
    
    func seek(to time: Double) {
        guard time.isFinite else { return }
        let upperBound = duration.isFinite && duration > 0 ? duration : max(time, 0)
        let target = min(max(time, 0), upperBound)
        seekDebounceWorkItem?.cancel()
        seekDebounceWorkItem = nil

        isSeeking = true
        seekTargetTime = target
        seekStartedAt = Date()
        seekRetryCount = 0
        currentTime = target
        
        if needsPlaybackRestoration {
            pendingRestoreTime = target
            isSeeking = false
            seekTargetTime = nil
            seekStartedAt = nil
            updateNowPlayingTime()
            saveState()
            return
        }
        pendingRestoreTime = nil
        
        // 拖动型进度条会在同一手势中连续提交很多位置。短防抖只保留
        // 最后一个目标，避免解码器反复 flush；80ms 对单次点击无感。
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.streamPlayer.seek(to: target)
            self.updateNowPlayingTime()
            self.saveState()
        }
        seekDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }
    
    func seekForward(seconds: Double = 15) {
        seek(to: min(currentTime + seconds, duration))
    }
    
    func seekBackward(seconds: Double = 15) {
        seek(to: max(currentTime - seconds, 0))
    }
}
