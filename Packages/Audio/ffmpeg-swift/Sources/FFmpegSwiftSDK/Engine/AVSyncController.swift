// AVSyncController.swift
// FFmpegSwiftSDK
//
// Implements PTS-based audio-video synchronization using audio clock as the master clock.
// When A/V drift exceeds 40ms, video frames are dropped or repeated to compensate.

import Foundation

/// Describes the action the renderer should take for a video frame based on A/V sync analysis.
enum AVSyncAction: Equatable {
    /// Display the frame normally after waiting the specified delay (in seconds).
    case display(delay: TimeInterval)
    /// Drop the frame because video is too far behind audio.
    case drop
    /// Repeat (hold) the previous frame because video is too far ahead of audio.
    case repeatPrevious(delay: TimeInterval)
}

/// Controls audio-video synchronization using the audio clock as the master clock.
///
/// The sync strategy is:
/// - Audio clock is the **master clock**; video adjusts its presentation timing to match.
/// - `updateAudioClock(_:)` is called whenever an audio frame is rendered, advancing the master clock.
/// - `calculateVideoDelay(for:)` computes how long to wait before displaying a video frame,
///   or whether to drop/repeat it.
/// - When the absolute drift between video PTS and audio clock exceeds `maxDrift` (40ms):
///   - If video is **behind** audio → drop the frame.
///   - If video is **ahead** of audio → repeat the previous frame (wait longer).
///
/// Thread safety is guaranteed via `NSLock` for concurrent access to clock values.
final class AVSyncController {

    // MARK: - Properties

    /// Lock protecting clock value reads and writes.
    private let lock = NSLock()

    /// The current audio clock position in seconds (master clock).
    private var audioClock: TimeInterval = 0

    /// The current video clock position in seconds.
    private var videoClock: TimeInterval = 0

    /// Maximum allowed drift between audio and video clocks (40ms).
    /// When drift exceeds this threshold, compensatory action is taken.
    let maxDrift: TimeInterval = 0.040

    // MARK: - Initialization

    /// Creates a new `AVSyncController` with both clocks at zero.
    init() {}

    // MARK: - Audio Clock

    /// Updates the audio master clock to the given PTS.
    ///
    /// This should be called each time an audio frame is rendered to keep
    /// the master clock current.
    ///
    /// - Parameter pts: The presentation timestamp of the most recently rendered audio frame, in seconds.
    func updateAudioClock(_ pts: TimeInterval) {
        lock.lock()
        audioClock = pts
        lock.unlock()
    }

    /// Returns the current audio clock value.
    ///
    /// Thread-safe.
    func currentAudioClock() -> TimeInterval {
        lock.lock()
        let value = audioClock
        lock.unlock()
        return value
    }

    // MARK: - Video Clock

    /// Updates the video clock to the given PTS.
    ///
    /// This should be called each time a video frame is actually displayed.
    ///
    /// - Parameter pts: The presentation timestamp of the displayed video frame, in seconds.
    func updateVideoClock(_ pts: TimeInterval) {
        lock.lock()
        videoClock = pts
        lock.unlock()
    }

    /// Returns the current video clock value.
    ///
    /// Thread-safe.
    func currentVideoClock() -> TimeInterval {
        lock.lock()
        let value = videoClock
        lock.unlock()
        return value
    }

    // MARK: - Sync Calculation

    /// Calculates the delay (in seconds) before a video frame should be displayed,
    /// based on the current audio master clock.
    ///
    /// The returned value indicates:
    /// - **Positive**: Video is ahead of audio; wait this many seconds before displaying.
    /// - **Zero**: Video and audio are in sync; display immediately.
    /// - **Negative**: Video is behind audio; display immediately (caller may choose to drop).
    ///
    /// - Parameter pts: The presentation timestamp of the video frame to be displayed.
    /// - Returns: The delay in seconds. Negative means the frame is late.
    func calculateVideoDelay(for pts: TimeInterval) -> TimeInterval {
        lock.lock()
        let currentAudio = audioClock
        lock.unlock()

        // drift = video PTS - audio clock
        // Positive drift means video is ahead of audio (need to wait)
        // Negative drift means video is behind audio (need to catch up)
        let drift = pts - currentAudio
        return drift
    }

    /// Determines the sync action for a video frame based on its PTS and the current audio clock.
    ///
    /// This method combines delay calculation with drift compensation logic:
    /// - If drift is within `±maxDrift`, display normally with the computed delay.
    /// - If video is behind audio by more than `maxDrift`, drop the frame.
    /// - If video is ahead of audio by more than `maxDrift`, repeat the previous frame.
    ///
    /// - Parameter pts: The presentation timestamp of the video frame.
    /// - Returns: An `AVSyncAction` indicating what the renderer should do.
    func syncAction(for pts: TimeInterval) -> AVSyncAction {
        let delay = calculateVideoDelay(for: pts)

        if delay < -maxDrift {
            // Video is significantly behind audio → drop frame to catch up
            return .drop
        } else if delay > maxDrift {
            // Video is significantly ahead of audio → repeat previous frame / wait
            return .repeatPrevious(delay: delay)
        } else {
            // Within acceptable drift range → display with appropriate delay
            return .display(delay: max(0, delay))
        }
    }

    /// Checks whether a video frame should be dropped based on its PTS.
    ///
    /// A frame should be dropped when video is behind audio by more than `maxDrift`.
    ///
    /// - Parameter pts: The presentation timestamp of the video frame.
    /// - Returns: `true` if the frame should be dropped, `false` otherwise.
    func shouldDropFrame(for pts: TimeInterval) -> Bool {
        let delay = calculateVideoDelay(for: pts)
        return delay < -maxDrift
    }

    // MARK: - Reset

    /// Resets both clocks to zero.
    ///
    /// Call this when starting a new playback session or after a seek.
    func reset() {
        lock.lock()
        audioClock = 0
        videoClock = 0
        lock.unlock()
    }
}
