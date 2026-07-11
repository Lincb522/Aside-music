// PlayerManager+Seek.swift
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

        isSeeking = true
        seekTargetTime = target
        seekStartedAt = Date()
        currentTime = target
        pendingRestoreTime = target
        updateNowPlayingTime()
        saveState()
        
        if needsPlaybackRestoration {
            isSeeking = false
            seekTargetTime = nil
            seekStartedAt = nil
            return
        }
        
        // 保留“仅执行最后一次 seek”的语义，但不再额外等待 50ms。
        seekDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.streamPlayer.seek(to: target)
        }
        seekDebounceWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }
    
    func seekForward(seconds: Double = 15) {
        seek(to: min(currentTime + seconds, duration))
    }
    
    func seekBackward(seconds: Double = 15) {
        seek(to: max(currentTime - seconds, 0))
    }
}
