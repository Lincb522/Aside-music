// RealtimeLock.swift
// FFmpegSwiftSDK
//
// Bounded lock acquisition for real-time audio callbacks.

import Foundation

/// Attempts to take `lock` from the real-time render thread without risking
/// an unbounded wait.
///
/// The audio output stages (`AudioFilterGraph`, `EQFilter`, `AudioRepairEngine`)
/// previously used a single `lock.try()` and skipped the whole block on
/// contention. Skipping is *not* inaudible: with bass/spatial tuning or preamp
/// compensation active, one dry block is heard as a momentary "flattening"
/// followed by a bump when processing resumes — a tape-stutter artifact.
///
/// Writers only hold these locks for microsecond-scale parameter commits
/// (graph construction happens off-lock on the rebuild queue). Never call
/// `usleep`/`Thread.sleep` here: even a nominally tiny sleep can be rounded up by
/// the scheduler and wake after the hardware deadline under thermal or UI load.
/// A bounded immediate retry gives short commits a chance to finish without
/// voluntarily descheduling the realtime thread.
@inline(__always)
func acquireRealtimeAudioLock(_ lock: NSLock) -> Bool {
    if lock.try() { return true }
    for _ in 0..<48 {
        if lock.try() { return true }
    }
    return false
}
