import Foundation

/// Invalidates queued session mutations as well as work suspended on the main actor.
/// The lock only protects the flag; no system audio call holds it.
final class AudioSessionWorkToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    func checkCancellation() throws {
        if isCancelled { throw CancellationError() }
    }
}
