import Foundation

/// MonoCompute Engine 的 CPU admission controller。
///
/// 它不改变任务的 QoS，也不抢占已经运行的工作；只限制可延后的 CPU 密集型
/// 工作同时进入执行区的数量。预算降低时，正在执行的任务自然结束，后续任务
/// 按优先级和到达顺序继续，避免取消图片处理或音频分析造成半成品状态。
actor MonoComputeScheduler {
    static let shared = MonoComputeScheduler()

    enum WorkClass: Int, Sendable {
        /// 用户正在等待结果的短任务，例如当前封面取色。
        case userInitiated = 0
        /// 可延后但仍服务于当前功能的分析任务。
        case analysis = 1
        /// 缓存整理、批处理等维护任务。
        case maintenance = 2
    }

    struct Snapshot: Sendable {
        let activeTaskCount: Int
        let waitingTaskCount: Int
        let waitingByClass: [Int: Int]
        let currentConcurrencyBudget: Int
        let completedTaskCount: Int
    }

    private struct Waiter {
        let id: UUID
        let workClass: WorkClass
        let sequence: UInt64
        let continuation: CheckedContinuation<Bool, Never>
    }

    private var activeTaskIDs: Set<UUID> = []
    private var waiters: [Waiter] = []
    private var cancelledBeforeEnqueue: Set<UUID> = []
    private var nextSequence: UInt64 = 0
    private var completedTaskCount = 0

    private init() {}

    func withPermit<T: Sendable>(
        _ workClass: WorkClass,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let id = UUID()
        let acquired = await withTaskCancellationHandler {
            await acquire(id: id, workClass: workClass)
        } onCancel: {
            Task { await self.cancelWaiting(id: id) }
        }
        guard acquired else { throw CancellationError() }

        do {
            try Task.checkCancellation()
            let value = try await operation()
            release(id: id)
            return value
        } catch {
            release(id: id)
            throw error
        }
    }

    func diagnosticSnapshot() -> Snapshot {
        Snapshot(
            activeTaskCount: activeTaskIDs.count,
            waitingTaskCount: waiters.count,
            waitingByClass: Dictionary(grouping: waiters, by: { $0.workClass.rawValue })
                .mapValues(\.count),
            currentConcurrencyBudget: MonoComputeBudgetStore.shared.current
                .backgroundComputeConcurrency,
            completedTaskCount: completedTaskCount
        )
    }

    private func acquire(id: UUID, workClass: WorkClass) async -> Bool {
        guard !Task.isCancelled,
              cancelledBeforeEnqueue.remove(id) == nil else { return false }
        if waiters.isEmpty, canStart(workClass) {
            activeTaskIDs.insert(id)
            return true
        }

        let sequence = nextSequence
        nextSequence &+= 1
        return await withCheckedContinuation { continuation in
            waiters.append(
                Waiter(
                    id: id,
                    workClass: workClass,
                    sequence: sequence,
                    continuation: continuation
                )
            )
            drainWaiters()
        }
    }

    private func release(id: UUID) {
        guard activeTaskIDs.remove(id) != nil else { return }
        completedTaskCount &+= 1
        drainWaiters()
    }

    private func cancelWaiting(id: UUID) {
        if let index = waiters.firstIndex(where: { $0.id == id }) {
            let waiter = waiters.remove(at: index)
            waiter.continuation.resume(returning: false)
        } else if !activeTaskIDs.contains(id) {
            // 取消可能先于 acquire 进入 actor；留下标记让随后到达的
            // acquire 立即退出，避免 continuation 永久留在等待队列。
            cancelledBeforeEnqueue.insert(id)
        }
    }

    private func drainWaiters() {
        while let index = nextEligibleWaiterIndex() {
            let waiter = waiters.remove(at: index)
            activeTaskIDs.insert(waiter.id)
            waiter.continuation.resume(returning: true)
        }
    }

    private func nextEligibleWaiterIndex() -> Int? {
        waiters.indices
            .filter { canStart(waiters[$0].workClass) }
            .min { lhs, rhs in
                let left = waiters[lhs]
                let right = waiters[rhs]
                if left.workClass.rawValue == right.workClass.rawValue {
                    return left.sequence < right.sequence
                }
                return left.workClass.rawValue < right.workClass.rawValue
            }
    }

    private func canStart(_ workClass: WorkClass) -> Bool {
        let base = MonoComputeBudgetStore.shared.current.backgroundComputeConcurrency
        let limit: Int
        switch workClass {
        case .userInitiated:
            limit = min(4, max(2, base + 1))
        case .analysis:
            limit = max(1, base)
        case .maintenance:
            limit = max(1, base - 1)
        }
        return activeTaskIDs.count < limit
    }
}
