import Foundation

// Synthetic AVAudioSession: exposes the queue ordering of the production executor
// without opening a device route. Mutable observations share one lock.
final class AVAudioSession: @unchecked Sendable {
    enum Category { case playback, record }
    enum Mode { case `default` }
    struct CategoryOptions: OptionSet, Sendable { let rawValue: UInt }
    struct SetActiveOptions: OptionSet, Sendable { let rawValue: UInt }
    static let shared = AVAudioSession()
    static func sharedInstance() -> AVAudioSession { shared }
    var category: Category { .playback }
    var mode: Mode { .default }
    var categoryOptions: CategoryOptions { [] }
    let releaseCategory = DispatchSemaphore(value: 0)
    let categoryEntered = AsyncStream<Void>.makeStream()
    private let lock = NSLock()
    private var categoryCalls = 0
    private var activationCalls = 0
    var counts: (Int, Int) {
        lock.lock()
        defer { lock.unlock() }
        return (categoryCalls, activationCalls)
    }
    func setCategory(_ category: Category, mode: Mode, options: CategoryOptions = []) throws {
        lock.lock()
        categoryCalls += 1
        lock.unlock()
        categoryEntered.continuation.yield(())
        precondition(releaseCategory.wait(timeout: .now() + 10) == .success)
    }
    func setActive(_ active: Bool, options: SetActiveOptions = []) throws {
        lock.lock()
        if active { activationCalls += 1 }
        lock.unlock()
    }
}

// EXECUTOR

@main struct AudioSessionExecutorRegressions {
    static func main() async throws {
        let session = AVAudioSession.sharedInstance()
        let executor = AudioSessionMutationExecutor.shared
        let firstToken = AudioSessionWorkToken()
        let secondToken = AudioSessionWorkToken()
        let first = Task {
            try await executor.configurePlayback(optionsRawValue: 1, activate: true, authorization: firstToken)
        }
        var events = session.categoryEntered.stream.makeAsyncIterator()
        _ = await events.next()
        // The first request is inside category configuration; the second has not
        // reached the serial queue's mutation boundary. Invalidate both.
        let second = Task {
            try await executor.configurePlayback(optionsRawValue: 2, activate: true, authorization: secondToken)
        }
        firstToken.cancel()
        secondToken.cancel()
        session.releaseCategory.signal()
        do { try await first.value; preconditionFailure("cancelled activation ran") }
        catch is CancellationError {}
        do { try await second.value; preconditionFailure("cancelled queued request ran") }
        catch is CancellationError {}
        precondition(session.counts.0 == 1 && session.counts.1 == 0)
        let valid = AudioSessionWorkToken()
        try await executor.configurePlayback(optionsRawValue: 0, activate: true, authorization: valid)
        precondition(session.counts.1 == 1)
        print("PASS: production serial executor cancels requests before category/activation; a new valid request succeeds")
    }
}
