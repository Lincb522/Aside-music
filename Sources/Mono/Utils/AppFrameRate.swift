import SwiftUI
import Combine

#if os(iOS)
import QuartzCore
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
    /// 全局帧率封顶（nil = 不封顶）。沉浸模式等重负载全屏场景把 ProMotion 从 120Hz 压回 60Hz，
    /// 整机渲染开销直接减半，是发热/耗电的第一杠杆。
    @MainActor
    private static var frameRateCeiling: Int?

    @MainActor
    private static var heavyWorkloadToken: UUID?

    @MainActor
    private static var adaptivePolicyCancellables: Set<AnyCancellable> = []

    @MainActor
    private static var adaptivePolicyInstalled = false

    /// 进入重负载场景时调用：把所有场景的锁定帧率压到 ceiling（如 60）
    @MainActor
    static func pushFrameRateCeiling(_ ceiling: Int, reason: String) {
        frameRateCeiling = ceiling
        if heavyWorkloadToken == nil {
            heavyWorkloadToken = MonoComputeEngine.shared.beginWorkload(.immersiveStage)
        }
        lockConnectedScenesToPreferredFrameRate(reason: "ceiling on: \(reason)")
    }

    /// 离开重负载场景时调用：恢复原始锁定帧率
    @MainActor
    static func popFrameRateCeiling(reason: String) {
        frameRateCeiling = nil
        if let heavyWorkloadToken {
            MonoComputeEngine.shared.endWorkload(heavyWorkloadToken)
            self.heavyWorkloadToken = nil
        }
        lockConnectedScenesToPreferredFrameRate(reason: "ceiling off: \(reason)")
    }

    @MainActor
    private static var activeDisplayLinks: [ObjectIdentifier: CADisplayLink] = [:]

    @MainActor
    private static var displayLinkTargets: [ObjectIdentifier: DisplayLinkTarget] = [:]

    @MainActor
    static func lockConnectedScenesToPreferredFrameRate(reason: String) {
        installAdaptivePolicyIfNeeded()
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeSceneIds = Set(windowScenes.map(ObjectIdentifier.init))

        for scene in windowScenes {
            lock(scene, reason: reason)
        }

        DisplayLinkStore.removeStaleLinks(activeSceneIds: activeSceneIds)
    }

    @MainActor
    static func lock(_ windowScene: UIWindowScene, reason: String) {
        installAdaptivePolicyIfNeeded()
        let sceneId = ObjectIdentifier(windowScene)

        // 常规界面始终交给 iOS / ProMotion 自适应。显示链接只用于沉浸模式
        // 主动设置的帧率上限，避免静止页面也持续唤醒渲染线程。
        guard shouldForceFrameRate else {
            DisplayLinkStore.unlock(sceneId: sceneId)
            AppLogger.debug("[FrameRate] system adaptive reason=\(reason)")
            return
        }

        let targetFPS = preferredFramesPerSecond(for: windowScene.screen)
        let frameRateRange = CAFrameRateRange(
            minimum: Float(targetFPS),
            maximum: Float(targetFPS),
            preferred: Float(targetFPS)
        )

        DisplayLinkStore.lock(sceneId: sceneId, frameRateRange: frameRateRange)

        AppLogger.info("[FrameRate] lock reason=\(reason) targetFPS=\(targetFPS) screenMaxFPS=\(windowScene.screen.maximumFramesPerSecond)")
    }

    @MainActor
    static func unlock(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let sceneId = ObjectIdentifier(windowScene)
        DisplayLinkStore.unlock(sceneId: sceneId)
    }

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

    @MainActor
    private static func preferredFramesPerSecond(for screen: UIScreen) -> Int {
        let base = min(max(screen.maximumFramesPerSecond, 60), preferredMaximumFramesPerSecond)
        let requested = frameRateCeiling.map { min(base, max($0, 30)) } ?? base
        return min(requested, systemPerformanceCeiling)
    }

    @MainActor
    private static var shouldForceFrameRate: Bool {
        frameRateCeiling != nil
    }

    /// Start reducing refresh work as soon as iOS reports heat pressure rather
    /// than waiting for the app to enter the immersive player. This affects
    /// cadence only; view content and animation equations stay unchanged.
    private static var systemPerformanceCeiling: Int {
        MonoComputeBudgetStore.shared.current.interactiveFramesPerSecond
    }

    @MainActor
    private static func installAdaptivePolicyIfNeeded() {
        guard !adaptivePolicyInstalled else { return }
        adaptivePolicyInstalled = true

        NotificationCenter.default.publisher(for: .monoComputeBudgetDidChange)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                Task { @MainActor in
                    lockConnectedScenesToPreferredFrameRate(reason: "compute budget changed")
                }
            }
            .store(in: &adaptivePolicyCancellables)
    }

    @MainActor
    private static func makeDisplayLink(for sceneId: ObjectIdentifier) -> CADisplayLink {
        let target = DisplayLinkTarget()
        let displayLink = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick(_:)))
        displayLink.add(to: .main, forMode: .common)
        displayLinkTargets[sceneId] = target
        return displayLink
    }

    private final class DisplayLinkTarget: NSObject {
        @objc func tick(_ displayLink: CADisplayLink) {}
    }

    @MainActor
    private enum DisplayLinkStore {
        static func lock(sceneId: ObjectIdentifier, frameRateRange: CAFrameRateRange) {
            let displayLink = activeDisplayLinks[sceneId] ?? makeDisplayLink(for: sceneId)
            displayLink.preferredFrameRateRange = frameRateRange
            activeDisplayLinks[sceneId] = displayLink
        }

        static func unlock(sceneId: ObjectIdentifier) {
            activeDisplayLinks.removeValue(forKey: sceneId)?.invalidate()
            displayLinkTargets.removeValue(forKey: sceneId)
        }

        static func removeStaleLinks(activeSceneIds: Set<ObjectIdentifier>) {
            let staleSceneIds = activeDisplayLinks.keys.filter { !activeSceneIds.contains($0) }
            for sceneId in staleSceneIds {
                unlock(sceneId: sceneId)
            }
        }
    }

    #endif
}
