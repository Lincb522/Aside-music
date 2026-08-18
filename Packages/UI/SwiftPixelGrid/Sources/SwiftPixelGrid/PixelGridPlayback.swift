import Foundation
import SwiftUI

/// 播放环境解析后的三种互斥状态。
enum PixelGridPlaybackState: Hashable, Sendable {
    case running
    case stopped
    case reducedMotion

    init(isAnimating: Bool, reduceMotion: Bool) {
        if reduceMotion {
            self = .reducedMotion
        } else if isAnimating {
            self = .running
        } else {
            self = .stopped
        }
    }

    var isPaused: Bool {
        self != .running
    }
}

/// 把连续延迟与 Pattern 两种 implementation 收进同一播放 interface。
enum PixelGridPlayback: Hashable, Sendable {
    case delay(PixelDelayEngine)
    case pattern(PixelPatternEngine)

    var minimumInterval: TimeInterval? {
        switch self {
        case .delay:
            // 连续亮度跟随当前显示器的刷新节奏，包括 ProMotion。
            nil
        case .pattern(let engine):
            // Pattern 仅在目标帧变化时更新。
            engine.frameDuration
        }
    }

    var transitionDuration: TimeInterval? {
        switch self {
        case .delay:
            nil
        case .pattern(let engine):
            engine.transitionDuration > 0
                ? engine.transitionDuration
                : nil
        }
    }

    func frame(
        at elapsedTime: TimeInterval,
        state: PixelGridPlaybackState
    ) -> PixelGridFrame {
        switch state {
        case .stopped:
            return .off
        case .reducedMotion:
            switch self {
            case .delay:
                return .on
            case .pattern(let engine):
                return engine.reducedMotionFrame
            }
        case .running:
            switch self {
            case .delay(let engine):
                return engine.frame(at: elapsedTime)
            case .pattern(let engine):
                return engine.frame(at: elapsedTime)
            }
        }
    }

    static func shouldRestart(
        from oldState: PixelGridPlaybackState,
        to newState: PixelGridPlaybackState
    ) -> Bool {
        oldState != .running && newState == .running
    }
}

struct PixelGridPlaybackSample: Hashable, Sendable {
    let frame: PixelGridFrame
    let state: PixelGridPlaybackState
    let transitionDuration: TimeInterval?

    var allowsMotion: Bool {
        state != .reducedMotion
    }
}

/// 两个 renderer adapter 共用的 SwiftUI 时间线与重启策略。
struct PixelGridPlaybackTimeline<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var epoch = Date.now

    let playback: PixelGridPlayback
    let isAnimating: Bool
    private let content: (PixelGridPlaybackSample) -> Content

    init(
        playback: PixelGridPlayback,
        isAnimating: Bool,
        @ViewBuilder content: @escaping (PixelGridPlaybackSample) -> Content
    ) {
        self.playback = playback
        self.isAnimating = isAnimating
        self.content = content
    }

    var body: some View {
        let state = PixelGridPlaybackState(
            isAnimating: isAnimating,
            reduceMotion: reduceMotion
        )

        TimelineView(
            .animation(
                minimumInterval: playback.minimumInterval,
                paused: state.isPaused
            )
        ) { context in
            let elapsedTime = context.date.timeIntervalSince(epoch)
            content(
                PixelGridPlaybackSample(
                    frame: playback.frame(
                        at: elapsedTime,
                        state: state
                    ),
                    state: state,
                    transitionDuration: playback.transitionDuration
                )
            )
        }
        .onChange(of: playback) { _ in
            epoch = .now
        }
        .onChange(of: state) { newState in
            // iOS 16 的 onChange 只提供新值。该回调仅在状态变化时触发，
            // 因而新状态进入 running 即等价于原先的 stopped/reduced → running。
            if newState == .running {
                epoch = .now
            }
        }
    }
}
