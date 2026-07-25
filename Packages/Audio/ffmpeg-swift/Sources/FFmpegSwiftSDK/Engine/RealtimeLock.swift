// RealtimeLock.swift
// FFmpegSwiftSDK
//
// Bounded lock acquisition for real-time audio callbacks.

import Foundation

/// Attempts to take `lock` from the real-time render thread without risking
/// an unbounded wait.
///
/// The audio output stages (`AudioFilterGraph`, `EQFilter`, `AudioRepairEngine`)
/// share short configuration locks with UI/control code. A skipped DSP block can
/// sound slightly flatter, but a missed hardware callback sounds like tape drag,
/// coughs, or crackle. Under thermal pressure and app-switch bursts, protect the
/// render deadline first.
///
/// Never call `usleep`/`Thread.sleep` here: even a nominally tiny sleep can be
/// rounded up by the scheduler and wake after the hardware deadline. Keep the
/// spin budget intentionally tiny.
@inline(__always)
func acquireRealtimeAudioLock(_ lock: NSLock) -> Bool {
    if lock.try() { return true }
    for _ in 0..<8 {
        if lock.try() { return true }
    }
    return false
}
