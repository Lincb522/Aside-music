import SwiftUI

#if os(iOS)
import UIKit
#endif

enum AppFrameRate {
    static let preferredMaximumFramesPerSecond = 120
    /// Continuous decorative motion does not gain meaningful clarity above
    /// 60 fps, while driving every TimelineView at ProMotion cadence keeps the
    /// main thread and render server awake even on otherwise static screens.
    private static let continuousAnimationFramesPerSecond = 60

    static var screenMaximumFramesPerSecond: Int {
        #if os(iOS)
        return max(mainScreenMaximumFramesPerSecond, 60)
        #else
        return 60
        #endif
    }

    static var preferredFramesPerSecond: Int {
        #if os(iOS)
        let computeBudget = MonoComputeBudgetStore.shared.current
        return min(
            screenMaximumFramesPerSecond,
            preferredMaximumFramesPerSecond,
            computeBudget.interactiveFramesPerSecond
        )
        #else
        min(screenMaximumFramesPerSecond, preferredMaximumFramesPerSecond)
        #endif
    }

    static var supportsHighRefreshRate: Bool {
        preferredFramesPerSecond > 60
    }

    static var displaySyncedMinimumInterval: TimeInterval? {
        return 1.0 / Double(preferredFramesPerSecond)
    }

    static func animationTimeline(paused: Bool = false) -> AnimationTimelineSchedule {
        let computeBudget = MonoComputeBudgetStore.shared.current
        let fps = min(
            preferredFramesPerSecond,
            continuousAnimationFramesPerSecond,
            computeBudget.continuousFramesPerSecond
        )
        return .animation(minimumInterval: 1.0 / Double(fps), paused: paused)
    }

    static func animationTimeline(maximumFramesPerSecond fpsCap: Int, paused: Bool = false) -> AnimationTimelineSchedule {
        // `fpsCap` is a real cap. The previous 60 fps floor made every 20/24/30
        // fps visualizer render at 60 fps, doubling or tripling its intended
        // work without changing the animation itself.
        let fps = max(
            1,
            min(
                fpsCap,
                preferredFramesPerSecond,
                MonoComputeBudgetStore.shared.current.continuousFramesPerSecond
            )
        )
        return .animation(minimumInterval: 1.0 / Double(fps), paused: paused)
    }

    /// 低功耗 timeline：不受 60fps 下限保护，fpsCap 是真实上限。
    /// 供重负载全屏场景（沉浸模式的背景 Canvas / 歌词时间轴）使用，避免长时间高频重绘发热。
    static func throttledTimeline(maximumFramesPerSecond fpsCap: Int, paused: Bool = false) -> AnimationTimelineSchedule {
        let fps = max(
            1,
            min(
                fpsCap,
                preferredFramesPerSecond,
                MonoComputeBudgetStore.shared.current.heavyVisualFramesPerSecond
            )
        )
        return .animation(minimumInterval: 1.0 / Double(fps), paused: paused)
    }

    #if os(iOS)
    @MainActor
    private static var heavyWorkloadToken: UUID?

    /// 进入重负载场景时登记生命周期。视觉层自己的 TimelineView 已经明确
    /// 使用 60/30fps；这里不再创建空 CADisplayLink 试图“锁定全局帧率”。
    /// CADisplayLink 的 preferredFrameRateRange 只约束它自己的回调，不能约束
    /// 整个 UIWindowScene，旧实现因此只会额外持续唤醒主线程与 RenderServer。
    @MainActor
    static func pushFrameRateCeiling(_ ceiling: Int, reason: String) {
        if heavyWorkloadToken == nil {
            heavyWorkloadToken = MonoComputeEngine.shared.beginWorkload(.immersiveStage)
        }
        AppLogger.debug("[FrameRate] workload begin ceiling=\(ceiling) reason=\(reason)")
    }

    /// 离开重负载场景时调用：恢复原始锁定帧率
    @MainActor
    static func popFrameRateCeiling(reason: String) {
        if let heavyWorkloadToken {
            MonoComputeEngine.shared.endWorkload(heavyWorkloadToken)
            self.heavyWorkloadToken = nil
        }
        AppLogger.debug("[FrameRate] workload end reason=\(reason)")
    }

    @MainActor
    static func lockConnectedScenesToPreferredFrameRate(reason: String) {
        // 保留调用入口兼容现有场景生命周期。iOS 会自行调节 ProMotion；
        // 不创建无内容的显示链接，不增加任何常驻逐帧工作。
    }

    @MainActor
    static func lock(_ windowScene: UIWindowScene, reason: String) {
        // Compatibility no-op. A standalone CADisplayLink cannot set a scene-wide
        // refresh rate and keeping one alive caused permanent GPU/CPU wakeups.
    }

    @MainActor
    static func unlock(_ scene: UIScene) {}

    private static var mainScreenMaximumFramesPerSecond: Int {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                UIScreen.main.maximumFramesPerSecond
            }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                UIScreen.main.maximumFramesPerSecond
            }
        }
    }

    #endif
}
