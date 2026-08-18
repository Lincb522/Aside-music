import Combine
import Darwin
import Foundation
import UIKit

/// Mono 全局内存治理引擎。
///
/// 统一负责：
/// - 根据设备内存、低电量模式、热状态和前后台状态分配缓存预算；
/// - 将系统内存警告转换为可预测的分级回收，而不是让各模块重复监听；
/// - 定期约束没有自然上限的目录、图片和派生数据缓存；
/// - 保留持久化数据及当前播放所需状态，回收后允许按需重新加载。
@MainActor
final class MonoMemoryEngine: ObservableObject {
    static let shared = MonoMemoryEngine()

    enum PressureLevel: Int, Comparable, Sendable {
        case routine = 0
        case background = 1
        case warning = 2
        case critical = 3

        static func < (lhs: PressureLevel, rhs: PressureLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    enum TrimReason: String, Sendable {
        case periodicMaintenance
        case enteredBackground
        case systemMemoryWarning
        case footprintSoftLimit
        case footprintHardLimit
        case thermalPressure
        case manual
    }

    enum ResourcePriority: Int, Sendable {
        /// 随时可以从网络、磁盘或数据库重新生成。
        case recreatable = 0
        /// 重新生成有成本，但不会影响当前播放连续性。
        case retained = 1
        /// 当前播放和关键模型；资源自身必须保留正在使用的部分。
        case essential = 2
    }

    struct TrimContext: Sendable {
        let level: PressureLevel
        let reason: TrimReason
        let processFootprintBytes: UInt64
        let cacheBudgetBytes: Int
        let isApplicationActive: Bool
    }

    struct TrimResult: Sendable {
        let releasedItemCount: Int
        let estimatedReleasedBytes: Int
        let preservedItemCount: Int

        static let none = TrimResult(
            releasedItemCount: 0,
            estimatedReleasedBytes: 0,
            preservedItemCount: 0
        )
    }

    struct ResourceUsage: Sendable {
        let itemCount: Int
        let estimatedBytes: Int

        static let unknown = ResourceUsage(itemCount: 0, estimatedBytes: 0)
    }

    struct ResourceSnapshot: Sendable {
        let id: String
        let priority: ResourcePriority
        let allocatedBudgetBytes: Int
        let itemCount: Int
        let estimatedBytes: Int
        let lastReleasedItemCount: Int
        let lastEstimatedReleasedBytes: Int
        let lastTrimDurationMilliseconds: Double
    }

    struct Snapshot: Sendable {
        let processFootprintBytes: UInt64
        let physicalMemoryBytes: UInt64
        let cacheBudgetBytes: Int
        let registeredResourceCount: Int
        let lastTrimLevel: PressureLevel?
        let lastTrimReason: TrimReason?
        let lastTrimAt: Date?
        let totalTrimCount: Int
        let resources: [ResourceSnapshot]
    }

    typealias BudgetHandler = @MainActor (_ bytes: Int) -> Void
    typealias TrimHandler = @MainActor (_ context: TrimContext) async -> TrimResult
    typealias UsageHandler = @MainActor () -> ResourceUsage

    private struct Resource {
        let id: String
        let priority: ResourcePriority
        let budgetWeight: Double
        let minimumBudgetBytes: Int
        let applyBudget: BudgetHandler
        let trim: TrimHandler
        let measureUsage: UsageHandler
    }

    private struct ResourceTrimMetric {
        let result: TrimResult
        let durationMilliseconds: Double
    }

    @Published private(set) var snapshot: Snapshot

    private var resources: [String: Resource] = [:]
    private var allocatedBudgets: [String: Int] = [:]
    private var trimMetrics: [String: ResourceTrimMetric] = [:]
    private var observerTokens: [NSObjectProtocol] = []
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var monitorTask: Task<Void, Never>?
    private var isStarted = false
    private var isApplicationActive = true
    private var isTrimming = false
    private var activeTrimLevel: PressureLevel?
    private var pendingTrim: (level: PressureLevel, reason: TrimReason)?
    private var lastAutomaticTrimAt: Date?
    private var pressureBudgetUntil: Date?
    private var pressureBudgetFactor = 1.0
    private var totalTrimCount = 0

    private static let megabyte = 1_024 * 1_024
    private static let automaticTrimCooldown: TimeInterval = 20

    private init() {
        let physical = ProcessInfo.processInfo.physicalMemory
        snapshot = Snapshot(
            processFootprintBytes: Self.processFootprintBytes(),
            physicalMemoryBytes: physical,
            cacheBudgetBytes: Self.baseCacheBudgetBytes(for: physical),
            registeredResourceCount: 0,
            lastTrimLevel: nil,
            lastTrimReason: nil,
            lastTrimAt: nil,
            totalTrimCount: 0,
            resources: []
        )
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        isApplicationActive = UIApplication.shared.applicationState == .active
        installObservers()
        installMemoryPressureSource()
        installSystemURLCacheResource()
        rebalanceBudgets()
        startPeriodicMonitor()
        publishSnapshot()
        AppLogger.info(
            "MonoMemory Engine 已启动，统一缓存预算 \(Self.byteString(currentCacheBudgetBytes()))",
            category: .database,
            event: "memory.engine.start"
        )
    }

    func registerResource(
        id: String,
        priority: ResourcePriority,
        budgetWeight: Double,
        minimumBudgetBytes: Int = 0,
        applyBudget: @escaping BudgetHandler,
        trim: @escaping TrimHandler,
        measureUsage: @escaping UsageHandler = { .unknown }
    ) {
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty else { return }
        resources[normalizedID] = Resource(
            id: normalizedID,
            priority: priority,
            budgetWeight: max(0.01, budgetWeight),
            minimumBudgetBytes: max(0, minimumBudgetBytes),
            applyBudget: applyBudget,
            trim: trim,
            measureUsage: measureUsage
        )
        rebalanceBudgets()
        publishSnapshot()
    }

    func unregisterResource(id: String) {
        resources.removeValue(forKey: id)
        allocatedBudgets.removeValue(forKey: id)
        trimMetrics.removeValue(forKey: id)
        rebalanceBudgets()
        publishSnapshot()
    }

    /// 手动清理仅作用于可重建的内存资源，不删除数据库、下载或磁盘持久化缓存。
    func trim(level: PressureLevel = .warning, reason: TrimReason = .manual) {
        requestTrim(level: level, reason: reason, bypassCooldown: reason == .manual)
    }

    func diagnosticSnapshot() -> Snapshot {
        publishSnapshot()
        return snapshot
    }

    func diagnosticReport() -> String {
        let current = diagnosticSnapshot()
        var lines = [
            "MonoMemory Engine",
            "footprint=\(Self.byteString(Int(current.processFootprintBytes))) physical=\(Self.byteString(Int(current.physicalMemoryBytes))) budget=\(Self.byteString(current.cacheBudgetBytes))",
            "resources=\(current.registeredResourceCount) trims=\(current.totalTrimCount) last=\(current.lastTrimReason?.rawValue ?? "none")"
        ]
        lines.append(contentsOf: current.resources.map { resource in
            "\(resource.id) priority=\(resource.priority.rawValue) budget=\(Self.byteString(resource.allocatedBudgetBytes)) usage=\(Self.byteString(resource.estimatedBytes)) items=\(resource.itemCount) released=\(Self.byteString(resource.lastEstimatedReleasedBytes)) duration=\(String(format: "%.2fms", resource.lastTrimDurationMilliseconds))"
        })
        return lines.joined(separator: "\n")
    }

    private func installObservers() {
        let center = NotificationCenter.default
        observerTokens.append(center.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.requestTrim(
                    level: .critical,
                    reason: .systemMemoryWarning,
                    bypassCooldown: true
                )
            }
        })
        observerTokens.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isApplicationActive = false
                self.rebalanceBudgets()
                self.requestTrim(
                    level: .background,
                    reason: .enteredBackground,
                    bypassCooldown: true
                )
            }
        })
        observerTokens.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isApplicationActive = true
                self.rebalanceBudgets()
                self.evaluateFootprint()
            }
        })
        observerTokens.append(center.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.rebalanceBudgets()
                if ProcessInfo.processInfo.thermalState == .serious
                    || ProcessInfo.processInfo.thermalState == .critical {
                    self.requestTrim(level: .warning, reason: .thermalPressure)
                }
            }
        })
        observerTokens.append(center.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebalanceBudgets()
            }
        })
    }

    private func installMemoryPressureSource() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        source.setEventHandler { [weak self, weak source] in
            guard let self, let event = source?.data else { return }
            Task { @MainActor in
                if event.contains(.critical) {
                    self.requestTrim(
                        level: .critical,
                        reason: .systemMemoryWarning,
                        bypassCooldown: true
                    )
                } else if event.contains(.warning) {
                    self.requestTrim(
                        level: .warning,
                        reason: .systemMemoryWarning,
                        bypassCooldown: true
                    )
                }
            }
        }
        source.resume()
        memoryPressureSource = source
    }

    private func installSystemURLCacheResource() {
        registerResource(
            id: "cache.url-session",
            priority: .recreatable,
            budgetWeight: 0.03,
            minimumBudgetBytes: 2 * Self.megabyte,
            applyBudget: { bytes in
                URLCache.shared.memoryCapacity = max(0, min(16 * Self.megabyte, bytes))
            },
            trim: { context in
                guard context.level >= .background else { return .none }
                let before = URLCache.shared.currentMemoryUsage
                // memoryCapacity 置零会立即释放内存响应；diskCapacity 不变，
                // 因而不会把内存治理误变成清除用户磁盘缓存。
                URLCache.shared.memoryCapacity = 0
                return .init(
                    releasedItemCount: before > 0 ? 1 : 0,
                    estimatedReleasedBytes: before,
                    preservedItemCount: 0
                )
            },
            measureUsage: {
                .init(
                    itemCount: URLCache.shared.currentMemoryUsage > 0 ? 1 : 0,
                    estimatedBytes: URLCache.shared.currentMemoryUsage
                )
            }
        )
    }

    private func startPeriodicMonitor() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self else { return }
                // 同时负责恢复已经到期的临时压力预算，并重新向所有资源下发额度。
                self.rebalanceBudgets()
                self.evaluateFootprint()
            }
        }
    }

    private func evaluateFootprint() {
        let footprint = Self.processFootprintBytes()
        let limits = Self.footprintLimits(
            physicalMemory: ProcessInfo.processInfo.physicalMemory
        )

        if footprint >= limits.hard {
            requestTrim(level: .critical, reason: .footprintHardLimit)
        } else if footprint >= limits.soft {
            requestTrim(level: .warning, reason: .footprintSoftLimit)
        } else {
            requestTrim(level: .routine, reason: .periodicMaintenance)
        }
        publishSnapshot(processFootprint: footprint)
    }

    private func requestTrim(
        level: PressureLevel,
        reason: TrimReason,
        bypassCooldown: Bool = false
    ) {
        if isTrimming {
            let queuedLevel = pendingTrim?.level ?? activeTrimLevel ?? .routine
            if level > queuedLevel {
                pendingTrim = (level, reason)
            }
            return
        }

        if !bypassCooldown,
           level < .critical,
           let lastAutomaticTrimAt,
           Date().timeIntervalSince(lastAutomaticTrimAt) < Self.automaticTrimCooldown {
            return
        }

        if reason != .manual { lastAutomaticTrimAt = Date() }
        if level >= .warning { enterPressureBudget(level: level) }
        isTrimming = true
        activeTrimLevel = level
        Task { [weak self] in
            await self?.performTrim(level: level, reason: reason)
        }
    }

    private func performTrim(level: PressureLevel, reason: TrimReason) async {
        let footprintBefore = Self.processFootprintBytes()
        let context = TrimContext(
            level: level,
            reason: reason,
            processFootprintBytes: footprintBefore,
            cacheBudgetBytes: currentCacheBudgetBytes(),
            isApplicationActive: isApplicationActive
        )
        let ordered = resources.values.sorted {
            if $0.priority == $1.priority { return $0.id < $1.id }
            return $0.priority.rawValue < $1.priority.rawValue
        }

        var releasedItems = 0
        var releasedBytes = 0
        var preservedItems = 0
        for resource in ordered {
            let startedAt = CFAbsoluteTimeGetCurrent()
            let result = await resource.trim(context)
            let duration = (CFAbsoluteTimeGetCurrent() - startedAt) * 1_000
            trimMetrics[resource.id] = ResourceTrimMetric(
                result: result,
                durationMilliseconds: max(0, duration)
            )
            releasedItems += max(0, result.releasedItemCount)
            releasedBytes += max(0, result.estimatedReleasedBytes)
            preservedItems += max(0, result.preservedItemCount)
        }

        totalTrimCount += 1
        let footprintAfter = Self.processFootprintBytes()
        snapshot = Snapshot(
            processFootprintBytes: footprintAfter,
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            cacheBudgetBytes: currentCacheBudgetBytes(),
            registeredResourceCount: resources.count,
            lastTrimLevel: level,
            lastTrimReason: reason,
            lastTrimAt: Date(),
            totalTrimCount: totalTrimCount,
            resources: makeResourceSnapshots()
        )
        let largestResources = snapshot.resources
            .filter { $0.estimatedBytes > 0 }
            .prefix(4)
            .map { "\($0.id)=\(Self.byteString($0.estimatedBytes))" }
            .joined(separator: ",")
        AppLogger.info(
            "MonoMemory Engine 回收完成 level=\(level.rawValue) reason=\(reason.rawValue) items=\(releasedItems) estimated=\(Self.byteString(releasedBytes)) footprint=\(Self.byteString(Int(footprintBefore)))→\(Self.byteString(Int(footprintAfter))) preserved=\(preservedItems) largest=[\(largestResources)]",
            category: .database,
            event: "memory.engine.trim"
        )

        isTrimming = false
        activeTrimLevel = nil
        let limits = Self.footprintLimits(
            physicalMemory: ProcessInfo.processInfo.physicalMemory
        )
        if footprintAfter >= limits.hard, level < .critical {
            pendingTrim = (.critical, .footprintHardLimit)
        } else if footprintAfter >= limits.soft, level < .warning {
            pendingTrim = (.warning, .footprintSoftLimit)
        }
        if let pendingTrim {
            self.pendingTrim = nil
            requestTrim(
                level: pendingTrim.level,
                reason: pendingTrim.reason,
                bypassCooldown: true
            )
        }
    }

    private func rebalanceBudgets() {
        let total = currentCacheBudgetBytes()
        let orderedResources = resources.values.sorted { $0.id < $1.id }
        let totalWeight = orderedResources.reduce(0.0) { $0 + $1.budgetWeight }
        guard totalWeight > 0, !orderedResources.isEmpty else {
            allocatedBudgets.removeAll(keepingCapacity: false)
            publishSnapshot()
            return
        }

        let minimumTotal = orderedResources.reduce(0) { $0 + $1.minimumBudgetBytes }
        let remaining = max(0, total - minimumTotal)
        let minimumScale = minimumTotal > total
            ? Double(total) / Double(max(1, minimumTotal))
            : 1.0

        var newBudgets: [String: Int] = [:]
        var assigned = 0
        for (index, resource) in orderedResources.enumerated() {
            let budget: Int
            if index == orderedResources.count - 1 {
                budget = max(0, total - assigned)
            } else if minimumTotal > total {
                budget = Int(Double(resource.minimumBudgetBytes) * minimumScale)
            } else {
                let weighted = Int(Double(remaining) * resource.budgetWeight / totalWeight)
                budget = resource.minimumBudgetBytes + weighted
            }
            newBudgets[resource.id] = budget
            assigned += budget
            resource.applyBudget(budget)
        }
        allocatedBudgets = newBudgets
        assert(
            newBudgets.values.reduce(0, +) == total,
            "MonoMemory Engine resource budgets must equal the global budget"
        )
        publishSnapshot()
    }

    private func enterPressureBudget(level: PressureLevel) {
        let factor: Double = level >= .critical ? 0.52 : 0.72
        pressureBudgetFactor = min(pressureBudgetFactor, factor)
        let proposedUntil = Date().addingTimeInterval(level >= .critical ? 180 : 120)
        pressureBudgetUntil = max(pressureBudgetUntil ?? .distantPast, proposedUntil)
        rebalanceBudgets()
    }

    private func currentCacheBudgetBytes() -> Int {
        var budget = Self.baseCacheBudgetBytes(for: ProcessInfo.processInfo.physicalMemory)
        if !isApplicationActive { budget = Int(Double(budget) * 0.58) }
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            budget = Int(Double(budget) * 0.82)
        }
        switch ProcessInfo.processInfo.thermalState {
        case .serious:
            budget = Int(Double(budget) * 0.78)
        case .critical:
            budget = Int(Double(budget) * 0.62)
        default:
            break
        }
        if let pressureBudgetUntil {
            if pressureBudgetUntil > Date() {
                budget = Int(Double(budget) * pressureBudgetFactor)
            } else {
                self.pressureBudgetUntil = nil
                pressureBudgetFactor = 1.0
            }
        }
        return max(72 * Self.megabyte, budget)
    }

    private func publishSnapshot(processFootprint: UInt64? = nil) {
        snapshot = Snapshot(
            processFootprintBytes: processFootprint ?? Self.processFootprintBytes(),
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            cacheBudgetBytes: currentCacheBudgetBytes(),
            registeredResourceCount: resources.count,
            lastTrimLevel: snapshot.lastTrimLevel,
            lastTrimReason: snapshot.lastTrimReason,
            lastTrimAt: snapshot.lastTrimAt,
            totalTrimCount: totalTrimCount,
            resources: makeResourceSnapshots()
        )
    }

    private func makeResourceSnapshots() -> [ResourceSnapshot] {
        resources.values
            .map { resource in
                let usage = resource.measureUsage()
                let metric = trimMetrics[resource.id]
                return ResourceSnapshot(
                    id: resource.id,
                    priority: resource.priority,
                    allocatedBudgetBytes: allocatedBudgets[resource.id] ?? 0,
                    itemCount: max(0, usage.itemCount),
                    estimatedBytes: max(0, usage.estimatedBytes),
                    lastReleasedItemCount: max(0, metric?.result.releasedItemCount ?? 0),
                    lastEstimatedReleasedBytes: max(0, metric?.result.estimatedReleasedBytes ?? 0),
                    lastTrimDurationMilliseconds: max(0, metric?.durationMilliseconds ?? 0)
                )
            }
            .sorted {
                if $0.estimatedBytes == $1.estimatedBytes { return $0.id < $1.id }
                return $0.estimatedBytes > $1.estimatedBytes
            }
    }

    private static func baseCacheBudgetBytes(for physicalMemory: UInt64) -> Int {
        let gigabyte = UInt64(1_024 * 1_024 * 1_024)
        if physicalMemory <= 3 * gigabyte { return 128 * megabyte }
        if physicalMemory <= 4 * gigabyte { return 176 * megabyte }
        if physicalMemory <= 6 * gigabyte { return 240 * megabyte }
        return 320 * megabyte
    }

    nonisolated private static func footprintLimits(
        physicalMemory: UInt64
    ) -> (soft: UInt64, hard: UInt64) {
        let physical = max(physicalMemory, 1)
        let megabyte = 1_024 * 1_024
        return (
            soft: min(
                UInt64(640 * megabyte),
                max(UInt64(320 * megabyte), physical / 10)
            ),
            hard: min(
                UInt64(880 * megabyte),
                max(UInt64(520 * megabyte), physical / 7)
            )
        )
    }

    nonisolated static func processFootprintBytes() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    rebound,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.phys_footprint)
    }

    nonisolated private static func byteString(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(max(0, bytes)), countStyle: .memory)
    }
}
