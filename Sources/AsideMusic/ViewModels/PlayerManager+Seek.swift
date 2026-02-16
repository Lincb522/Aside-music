// PlayerManager+Seek.swift
// AsideMusic
//
// 进度控制：seek、快进、快退

import Foundation

extension PlayerManager {
    
    // MARK: - Seek
    
    func seek(to time: Double) {
        isSeeking = true
        seekTargetTime = time
        currentTime = time
        updateNowPlayingTime()
        
        // Debounce：快速拖动时只执行最后一次 seek
        seekDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.streamPlayer.seek(to: time)
        }
        seekDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }
    
    func seekForward(seconds: Double = 15) {
        seek(to: min(currentTime + seconds, duration))
    }
    
    func seekBackward(seconds: Double = 15) {
        seek(to: max(currentTime - seconds, 0))
    }
}
