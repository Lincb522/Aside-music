// 播放器生命周期设置：前后台切换观察者、后台切歌保活、StreamPlayer 代理。
// 音频会话/中断/路由逻辑在 Playback/AudioSessionCoordinator.swift；
// 0.25s 心跳在 Playback/PlaybackHeartbeat.swift；
// 锁屏命令注册在 Playback/NowPlayingController.swift。

import Foundation
import AVFoundation
import UIKit
import FFmpegSwiftSDK

extension PlayerManager {

    // MARK: - 后台生命周期（节流 + 保活）

    /// 监听前后台切换：
    ///   - 进入后台：标记状态并立刻刷新一次锁屏时间锚点（锁屏进度靠 rate 自走）；
    ///   - 回到前台：清除节流状态并立刻补一次完整 UI 同步。
    func setupBackgroundStateObservers() {
        for observer in backgroundStateObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        backgroundStateObservers.removeAll()

        let didEnterBackground = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isAppInBackground = true
                self.heartbeat.backgroundTickSkipCounter = 0
                // 进入后台前把最新时间写入锁屏，之后由系统按 rate 自行推进
                if self.currentSong != nil {
                    self.updateNowPlayingTime()
                    self.syncWidgetState()
                    // 最终播放快照由 MonoApp 的统一后台持久化入口完成。
                    // 这里不能再异步排一次写盘，否则中央入口排空队列后，
                    // 此任务可能重新取得文件锁并触发 0xdead10cc。
                }
            }
        }
        backgroundStateObservers.append(didEnterBackground)

        let didBecomeActive = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isAppInBackground = false
                self.heartbeat.backgroundTickSkipCounter = 0
                self.endTransitionKeepAlive()
                self.reconcilePendingTrackTransitionWithEngine(reason: "didBecomeActive")
                // 回前台立即同步一次，避免 UI 显示后台期间的旧进度
                if self.currentSong != nil {
                    if let time = self.boundedEnginePlaybackTime(
                        self.streamPlayer.currentTime
                    ), !self.isSeeking {
                        self.currentTime = time
                    }
                    LyricViewModel.shared.updateCurrentTime(self.currentTime)
                    self.repairSystemPlaybackSurfacesIfNeeded(reason: "didBecomeActive")
                    self.updateNowPlayingTime()
                }
            }
        }
        backgroundStateObservers.append(didBecomeActive)
    }

    // MARK: - 后台切歌保活

    /// 歌曲在后台自然结束、需要网络请求下一首 URL 时，音频输出短暂停止，
    /// 系统可能在请求完成前挂起 App，导致「后台放完一首就停」。
    /// 这里申请一个短时后台任务（约 30s 窗口）保住切歌流程。
    func beginTransitionKeepAlive(reason: String) {
        let applicationState = UIApplication.shared.applicationState
        guard isAppInBackground || applicationState != .active else { return }
        if applicationState == .background {
            isAppInBackground = true
        }
        guard transitionKeepAliveTaskId == .invalid else { return }
        transitionKeepAliveTaskId = UIApplication.shared.beginBackgroundTask(withName: "Mono.TrackTransition") { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.mediaResolver.handleBackgroundExecutionExpiring() {
                    self.endTransitionKeepAlive()
                }
            }
        }
        if transitionKeepAliveTaskId != .invalid {
            AppLogger.debug("后台切歌保活开始: \(reason)")
        }
    }

    /// 播放真正恢复 / 出错 / 回前台时释放保活任务。
    func endTransitionKeepAlive() {
        guard transitionKeepAliveTaskId != .invalid else { return }
        UIApplication.shared.endBackgroundTask(transitionKeepAliveTaskId)
        transitionKeepAliveTaskId = .invalid
        AppLogger.debug("后台切歌保活结束")
    }

    /// 设置 StreamPlayer delegate（通过桥接适配器）
    func setupStreamPlayerDelegate() {
        let adapter = StreamPlayerDelegateAdapter(playerManager: self)
        self.delegateAdapter = adapter
        streamPlayer.delegate = adapter
    }
}
