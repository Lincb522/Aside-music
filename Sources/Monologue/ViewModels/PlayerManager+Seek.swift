// PlayerManager+Seek.swift
// Monologue
//
// 进度控制：seek、快进、快退

import Foundation

extension PlayerManager {
    
    // MARK: - Seek
    
    func seek(to time: Double) {
        isSeeking = true
        seekTargetTime = time
        seekStartedAt = Date()
        currentTime = time
        pendingRestoreTime = time
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
            self?.streamPlayer.seek(to: time)
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
