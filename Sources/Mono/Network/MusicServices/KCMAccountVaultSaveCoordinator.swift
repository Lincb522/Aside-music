import Foundation

actor KCMAccountVaultSaveCoordinator {
    static let shared = KCMAccountVaultSaveCoordinator()

    enum OperationResult: Sendable {
        case succeeded
        case failed
    }

    enum Outcome: Sendable, Equatable {
        case skippedStale
        case completedCurrent
        case completedStale
        case failedCurrent
        case failedStale

        var requiresCurrentAccountCompensation: Bool {
            switch self {
            case .skippedStale, .completedStale, .failedStale:
                return true
            case .completedCurrent, .failedCurrent:
                return false
            }
        }
    }

    private var tail: Task<Void, Never>?
    private var tailID: UUID?

    func enqueue(
        while isCurrent: @escaping @Sendable () -> Bool,
        operation: @escaping @Sendable () async -> OperationResult
    ) async -> Outcome {
        let predecessor = tail
        let operationTask = Task { () -> Outcome in
            await predecessor?.value
            guard isCurrent() else { return .skippedStale }

            let result = await operation()
            switch (result, isCurrent()) {
            case (.succeeded, true):
                return .completedCurrent
            case (.succeeded, false):
                return .completedStale
            case (.failed, true):
                return .failedCurrent
            case (.failed, false):
                return .failedStale
            }
        }
        let operationID = UUID()
        let completionTask = Task<Void, Never> { _ = await operationTask.value }
        tail = completionTask
        tailID = operationID

        let outcome = await operationTask.value
        if tailID == operationID {
            tail = nil
            tailID = nil
        }
        return outcome
    }
}
