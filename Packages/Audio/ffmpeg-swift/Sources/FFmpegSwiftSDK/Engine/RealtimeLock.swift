// RealtimeLock.swift
// FFmpegSwiftSDK
//
// Nonblocking configuration handoff to real-time audio callbacks.

import Foundation

/// Control code publishes whole configurations. Only the render thread consumes
/// them; contention delays a configuration change, never a block of audio.
final class RealtimeAudioConfiguration<Value: Equatable> {
    private let lock = NSLock()
    private var value: Value
    private var pending = false

    init(_ value: Value) { self.value = value }

    func read<Result>(_ body: (Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(value)
    }

    @discardableResult
    func update<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        let previous = value
        let result = body(&value)
        pending = pending || previous != value
        return result
    }

    /// Called by the single audio consumer at a block boundary.
    func takePending() -> Value? {
        guard lock.try() else { return nil }
        defer { lock.unlock() }
        guard pending else { return nil }
        pending = false
        return value
    }
}
