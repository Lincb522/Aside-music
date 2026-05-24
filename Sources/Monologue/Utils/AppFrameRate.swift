import SwiftUI

#if os(iOS)
import QuartzCore
import UIKit
#endif

enum AppFrameRate {
    static let preferredMaximumFramesPerSecond = 120
    static let minimumLockedFramesPerSecond = 60

    static var screenMaximumFramesPerSecond: Int {
        #if os(iOS)
        return max(mainScreenMaximumFramesPerSecond, 60)
        #else
        return 60
        #endif
    }

    static var preferredFramesPerSecond: Int {
        min(screenMaximumFramesPerSecond, preferredMaximumFramesPerSecond)
    }

    static var supportsHighRefreshRate: Bool {
        preferredFramesPerSecond > 60
    }

    static var displaySyncedMinimumInterval: TimeInterval? {
        return 1.0 / Double(preferredFramesPerSecond)
    }

    static func animationTimeline(paused: Bool = false) -> AnimationTimelineSchedule {
        .animation(minimumInterval: displaySyncedMinimumInterval, paused: paused)
    }

    static func animationTimeline(maximumFramesPerSecond fpsCap: Int, paused: Bool = false) -> AnimationTimelineSchedule {
        let fps = max(minimumLockedFramesPerSecond, min(fpsCap, preferredFramesPerSecond))
        return .animation(minimumInterval: 1.0 / Double(fps), paused: paused)
    }

    #if os(iOS)
    @MainActor
    private static var activeDisplayLinks: [ObjectIdentifier: CADisplayLink] = [:]

    @MainActor
    private static var displayLinkTargets: [ObjectIdentifier: DisplayLinkTarget] = [:]

    @MainActor
    static func lockConnectedScenesToPreferredFrameRate(reason: String) {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeSceneIds = Set(windowScenes.map(ObjectIdentifier.init))

        for scene in windowScenes {
            lock(scene, reason: reason)
        }

        DisplayLinkStore.removeStaleLinks(activeSceneIds: activeSceneIds)
        if #available(iOS 18.0, *) {
            UpdateLinkStore.removeStaleLinks(activeSceneIds: activeSceneIds)
        }
    }

    @MainActor
    static func lock(_ windowScene: UIWindowScene, reason: String) {
        let targetFPS = preferredFramesPerSecond(for: windowScene.screen)
        let frameRateRange = CAFrameRateRange(
            minimum: Float(targetFPS),
            maximum: Float(targetFPS),
            preferred: Float(targetFPS)
        )

        let sceneId = ObjectIdentifier(windowScene)
        if #available(iOS 18.0, *) {
            DisplayLinkStore.unlock(sceneId: sceneId)
            UpdateLinkStore.lock(sceneId: sceneId, windowScene: windowScene, frameRateRange: frameRateRange)
        } else {
            DisplayLinkStore.lock(sceneId: sceneId, frameRateRange: frameRateRange)
        }

        AppLogger.info("[FrameRate] lock reason=\(reason) targetFPS=\(targetFPS) screenMaxFPS=\(windowScene.screen.maximumFramesPerSecond)")
    }

    @MainActor
    static func unlock(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let sceneId = ObjectIdentifier(windowScene)
        DisplayLinkStore.unlock(sceneId: sceneId)
        if #available(iOS 18.0, *) {
            UpdateLinkStore.unlock(sceneId: sceneId)
        }
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
        min(max(screen.maximumFramesPerSecond, 60), preferredMaximumFramesPerSecond)
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

    @available(iOS 18.0, *)
    @MainActor
    private enum UpdateLinkStore {
        private static var activeUpdateLinks: [ObjectIdentifier: UIUpdateLink] = [:]

        static func lock(
            sceneId: ObjectIdentifier,
            windowScene: UIWindowScene,
            frameRateRange: CAFrameRateRange
        ) {
            let updateLink = activeUpdateLinks[sceneId] ?? UIUpdateLink(windowScene: windowScene)
            updateLink.preferredFrameRateRange = frameRateRange
            updateLink.isEnabled = true
            activeUpdateLinks[sceneId] = updateLink
        }

        static func unlock(sceneId: ObjectIdentifier) {
            guard let updateLink = activeUpdateLinks.removeValue(forKey: sceneId) else { return }
            updateLink.isEnabled = false
            updateLink.preferredFrameRateRange = .default
        }

        static func removeStaleLinks(activeSceneIds: Set<ObjectIdentifier>) {
            let staleSceneIds = activeUpdateLinks.keys.filter { !activeSceneIds.contains($0) }
            for sceneId in staleSceneIds {
                unlock(sceneId: sceneId)
            }
        }
    }
    #endif
}
