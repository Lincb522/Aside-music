import SwiftUI

#if os(iOS)
import UIKit
#endif

enum AppFrameRate {
    static let preferredMaximumFramesPerSecond = 120

    static var screenMaximumFramesPerSecond: Int {
        #if os(iOS)
        return max(UIScreen.main.maximumFramesPerSecond, 60)
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
        guard supportsHighRefreshRate else { return nil }
        return 1.0 / Double(preferredFramesPerSecond)
    }

    static func animationTimeline(paused: Bool = false) -> AnimationTimelineSchedule {
        .animation(minimumInterval: displaySyncedMinimumInterval, paused: paused)
    }

    static func animationTimeline(maximumFramesPerSecond fpsCap: Int, paused: Bool = false) -> AnimationTimelineSchedule {
        let fps = max(1, min(fpsCap, preferredFramesPerSecond))
        return .animation(minimumInterval: 1.0 / Double(fps), paused: paused)
    }
}
