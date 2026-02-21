// PlaybackTimePublisher.swift
// AsideMusic
//
// 轻量级播放进度发布器
// 将高频更新的 currentTime/duration 从 PlayerManager 中隔离出来
// 只有需要进度信息的视图订阅此对象，避免进度更新触发全局视图重渲染

import Foundation

@MainActor
class PlaybackTimePublisher: ObservableObject {
    static let shared = PlaybackTimePublisher()
    
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    
    /// 进度比例 0...1（安全计算，避免 NaN/Inf）
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }
    
    func update(currentTime: Double, duration: Double) {
        self.currentTime = currentTime
        self.duration = duration
    }
    
    func reset() {
        currentTime = 0
        duration = 0
    }
}
