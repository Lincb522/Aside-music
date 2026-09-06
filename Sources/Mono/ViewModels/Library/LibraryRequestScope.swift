import Combine

/// Owns one replaceable catalog request across filters, refreshes, and pagination.
@MainActor
final class LibraryRequestScope {
    private(set) var generation = 0
    private(set) var isRunning = false
    var cancellable: AnyCancellable?
    var task: Task<Void, Never>?

    func cancel() {
        generation += 1
        isRunning = false
        cancellable?.cancel()
        cancellable = nil
        task?.cancel()
        task = nil
    }

    func begin() -> Int {
        cancel()
        isRunning = true
        return generation
    }

    func isCurrent(_ request: Int) -> Bool { request == generation }

    func finish(_ request: Int) {
        if isCurrent(request) { isRunning = false }
    }

    deinit { task?.cancel() }
}
