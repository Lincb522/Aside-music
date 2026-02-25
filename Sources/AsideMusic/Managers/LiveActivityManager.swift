// LiveActivityManager.swift
// 灵动岛 Live Activity 生命周期管理

import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    /// 当前活跃的 Live Activity
    private var currentActivity: Activity<MusicActivityAttributes>?
    
    /// 更新节流：避免过于频繁的更新（最小间隔 1 秒）
    private var lastUpdateTime: Date = .distantPast
    private let minUpdateInterval: TimeInterval = 1.0
    
    /// App Group UserDefaults（灵动岛按钮通信）
    private let groupDefaults = UserDefaults(suiteName: "group.zijiu.Aside.com")
    
    /// 命令轮询定时器
    private var commandTimer: Timer?
    /// 上次处理的命令
    private var lastProcessedCommand: String = ""
    
    private init() {
        startCommandListener()
    }
    
    // MARK: - 启动灵动岛
    
    /// 开始播放时启动灵动岛
    func startActivity(song: Song, isPlaying: Bool, currentTime: Double, duration: Double) {
        // 先结束旧的
        stopActivity()
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppLogger.warning("[LiveActivity] 用户未授权 Live Activity")
            return
        }
        
        let attributes = MusicActivityAttributes(
            songName: song.name,
            artistName: song.artistName,
            albumName: song.album?.name ?? "",
            coverUrlString: song.coverUrl?.absoluteString,
            duration: duration
        )
        
        let state = MusicActivityAttributes.ContentState(
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration,
            artistName: song.artistName
        )
        
        let content = ActivityContent(state: state, staleDate: nil)
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            AppLogger.info("[LiveActivity] 已启动: \(song.name)")
        } catch {
            AppLogger.error("[LiveActivity] 启动失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 更新状态
    
    /// 更新播放状态（播放/暂停、进度）
    func updateActivity(isPlaying: Bool, currentTime: Double, duration: Double, artistName: String) {
        guard let activity = currentActivity else { return }
        
        // 节流：播放中每秒最多更新一次，暂停时立即更新
        let now = Date()
        if isPlaying && now.timeIntervalSince(lastUpdateTime) < minUpdateInterval {
            return
        }
        lastUpdateTime = now
        
        let state = MusicActivityAttributes.ContentState(
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration,
            artistName: artistName
        )
        
        let content = ActivityContent(state: state, staleDate: nil)
        
        Task {
            await activity.update(content)
        }
    }
    
    // MARK: - 切歌时重建
    
    /// 切歌时重建 Activity（因为歌名等固定属性变了）
    func switchSong(song: Song, isPlaying: Bool, currentTime: Double, duration: Double) {
        startActivity(song: song, isPlaying: isPlaying, currentTime: currentTime, duration: duration)
    }
    
    // MARK: - 停止灵动岛
    
    /// 停止播放时结束灵动岛
    func stopActivity() {
        guard let activity = currentActivity else { return }
        
        let finalState = MusicActivityAttributes.ContentState(
            isPlaying: false,
            currentTime: 0,
            duration: 0,
            artistName: ""
        )
        
        let content = ActivityContent(state: finalState, staleDate: nil)
        
        Task {
            await activity.end(content, dismissalPolicy: .immediate)
        }
        
        currentActivity = nil
        AppLogger.info("[LiveActivity] 已停止")
    }
    
    // MARK: - 结束所有残留 Activity
    
    /// App 启动时清理可能残留的 Activity
    func cleanupStaleActivities() {
        Task {
            for activity in Activity<MusicActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    
    // MARK: - 灵动岛按钮命令监听
    
    /// 启动命令轮询（监听灵动岛按钮通过 App Group 发来的命令）
    private func startCommandListener() {
        commandTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForCommand()
            }
        }
    }
    
    private func checkForCommand() {
        guard let command = groupDefaults?.string(forKey: "liveActivityCommand"),
              !command.isEmpty,
              command != lastProcessedCommand else { return }
        
        lastProcessedCommand = command
        let player = PlayerManager.shared
        
        if command.hasPrefix("togglePlay") {
            player.togglePlayPause()
        } else if command.hasPrefix("next") {
            player.next()
        } else if command.hasPrefix("previous") {
            player.previous()
        }
    }
}
