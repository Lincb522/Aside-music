import Combine
import Darwin
import Foundation
import UIKit

/// CPU/GPU 统一运行预算。GPU 在 iOS 上没有适合生产环境持续轮询的全局利用率 API，
/// 因此 GPU 采用帧率、渲染分辨率、粒子密度和着色器准入预算治理；CPU 则额外采样
/// 本进程所有线程的实际利用率，并通过迟滞状态机避免质量档位频繁跳动。
struct MonoComputeBudget: Equatable, Sendable {
    enum Tier: Int, Comparable, Sendable {
        case maximum = 0
        case balanced = 1
        case reduced = 2
        case minimum = 3

        static func < (lhs: Tier, rhs: Tier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    let tier: Tier
    let interactiveFramesPerSecond: Int
    let continuousFramesPerSecond: Int
    let heavyVisualFramesPerSecond: Int
    let gpuRenderScale: Double
    let particleDensityScale: Double
    let backgroundComputeConcurrency: Int
    let allowsExpensiveShaders: Bool
    let allowsContinuousHaptics: Bool

    static func make(tier: Tier) -> MonoComputeBudget {
        switch tier {
        case .maximum:
            return .init(
                tier: tier,
                interactiveFramesPerSecond: 120,
                continuousFramesPerSecond: 60,
                heavyVisualFramesPerSecond: 60,
                gpuRenderScale: 1,
                particleDensityScale: 1,
                backgroundComputeConcurrency: 3,
                allowsExpensiveShaders: true,
                allowsContinuousHaptics: true
            )
        case .balanced:
            return .init(
                tier: tier,
                interactiveFramesPerSecond: 60,
                continuousFramesPerSecond: 60,
                heavyVisualFramesPerSecond: 60,
                gpuRenderScale: 1,
                particleDensityScale: 1,
                backgroundComputeConcurrency: 2,
                allowsExpensiveShaders: true,
                allowsContinuousHaptics: true
            )
        case .reduced:
            return .init(
                tier: tier,
                interactiveFramesPerSecond: 60,
                continuousFramesPerSecond: 60,
                heavyVisualFramesPerSecond: 60,
                gpuRenderScale: 1,
                particleDensityScale: 1,
                backgroundComputeConcurrency: 1,
                allowsExpensiveShaders: true,
                allowsContinuousHaptics: false
            )
        case .minimum:
            return .init(
                tier: tier,
                interactiveFramesPerSecond: 60,
                continuousFramesPerSecond: 60,
                heavyVisualFramesPerSecond: 60,
                gpuRenderScale: 1,
                particleDensityScale: 1,
                backgroundComputeConcurrency: 1,
                allowsExpensiveShaders: true,
                allowsContinuousHaptics: false
            )
        }
    }
}

/// 非 MainActor 的轻量预算镜像，供 TimelineView、解码任务和渲染辅助代码读取。
/// 写入仅由 MonoComputeEngine 负责。
final class MonoComputeBudgetStore: @unchecked Sendable {
    static let shared = MonoComputeBudgetStore()

    private let lock = NSLock()
    private var value: MonoComputeBudget

    private init() {
        let info = ProcessInfo.processInfo
        let initialTier: MonoComputeBudget.Tier
        if info.isLowPowerModeEnabled {
            initialTier = .reduced
        } else {
            switch info.thermalState {
            case .nominal: initialTier = .maximum
            case .fair: initialTier = .balanced
            case .serious: initialTier = .reduced
            case .critical: initialTier = .minimum
            @unknown default: initialTier = .balanced
            }
        }
        value = .make(tier: initialTier)
    }

    var current: MonoComputeBudget {
        lock.lock()
        let current = value
        lock.unlock()
        return current
    }

    func update(_ budget: MonoComputeBudget) {
        lock.lock()
        value = budget
        lock.unlock()
    }
}

extension Notification.Name {
    static let monoComputeBudgetDidChange = Notification.Name(
        "zijiu.Monologue.compute-budget-did-change"
    )
}

@MainActor
final class MonoComputeEngine: ObservableObject {
    static let shared = MonoComputeEngine()

    /// 只有持续刷新、能够真实反映界面帧稳定性的工作负载才需要登记。
    /// 网络请求、音频播放和一次性页面动画不应进入这里。
    enum WorkloadKind: String, Sendable {
        case immersiveStage = "immersive-stage"
        case fluidBackground = "fluid-background"
        case fluidFloatingBar = "fluid-floating-bar"
    }

    struct Snapshot: Sendable {
        let budget: MonoComputeBudget
        let processCPUPercent: Double
        let smoothedCPUPercent: Double
        let thermalStateRawValue: Int
        let isLowPowerModeEnabled: Bool
        let isApplicationActive: Bool
        let isScreenCaptured: Bool
        let frameDropRatio: Double
        let longestFrameDurationMilliseconds: Double
        let renderPressureTier: MonoComputeBudget.Tier
        let activeWorkloads: [String]
        let sampledAt: Date
    }

    @Published private(set) var budget: MonoComputeBudget
    @Published private(set) var screenCaptured = false
    private(set) var snapshot: Snapshot

    private var observerTokens: [NSObjectProtocol] = []
    private var monitorTask: Task<Void, Never>?
    private var activeWorkloads: [UUID: WorkloadKind] = [:]
    private var isStarted = false
    private var isApplicationActive = true
    private var isScreenCaptured = false
    private var smoothedCPUPercent = 0.0
    private var cpuTier: MonoComputeBudget.Tier = .maximum
    private var pendingCPUTier: MonoComputeBudget.Tier?
    private var pendingCPUStreak = 0
    private var recoveryStreak = 0
    /// GPU 没有可用于生产环境持续轮询的全局占用率 API。旧实现另外创建
    /// CADisplayLink 作为“帧探针”，它本身会持续唤醒主线程和渲染服务，
    /// 在流体与沉浸页面反而成为长期发热源。渲染质量现固定保持完整，
    /// 引擎只把系统压力转移到后台计算并发，不再主动制造额外帧循环。
    private let renderPressureTier: MonoComputeBudget.Tier = .maximum
    private let lastFrameDropRatio = 0.0
    private let lastLongestFrameDuration = 0.0
    private var transientPressureUntil: Date?

    private init() {
        let initial = MonoComputeBudgetStore.shared.current
        budget = initial
        snapshot = Snapshot(
            budget: initial,
            processCPUPercent: 0,
            smoothedCPUPercent: 0,
            thermalStateRawValue: ProcessInfo.processInfo.thermalState.rawValue,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            isApplicationActive: true,
            isScreenCaptured: false,
            frameDropRatio: 0,
            longestFrameDurationMilliseconds: 0,
            renderPressureTier: .maximum,
            activeWorkloads: [],
            sampledAt: Date()
        )
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        isApplicationActive = UIApplication.shared.applicationState == .active
        isScreenCaptured = Self.anyScreenCaptured()
        screenCaptured = isScreenCaptured
        installObservers()
        refreshBudget(reason: "startup")
        startMonitor()
        AppLogger.info(
            "MonoCompute Engine 已启动 tier=\(budget.tier.rawValue) fps=\(budget.interactiveFramesPerSecond)/\(budget.continuousFramesPerSecond)/\(budget.heavyVisualFramesPerSecond)",
            category: .interface,
            event: "compute.engine.start"
        )
    }

    func diagnosticSnapshot() -> Snapshot {
        snapshot
    }

    /// 登记持续重视觉工作，用来让 CPU 采样采用较快节奏；不再创建额外
    /// CADisplayLink，避免性能引擎与真实动画争抢每帧主线程预算。
    @discardableResult
    func beginWorkload(_ kind: WorkloadKind) -> UUID {
        let token = UUID()
        activeWorkloads[token] = kind
        refreshBudget(reason: "workload begin")
        return token
    }

    func endWorkload(_ token: UUID) {
        guard activeWorkloads.removeValue(forKey: token) != nil else { return }
        refreshBudget(reason: "workload end")
    }

    func diagnosticReport() -> String {
        let current = snapshot
        return [
            "MonoCompute Engine",
            "tier=\(current.budget.tier.rawValue) cpu=\(String(format: "%.1f%%", current.processCPUPercent)) smoothed=\(String(format: "%.1f%%", current.smoothedCPUPercent))",
            "fps interactive=\(current.budget.interactiveFramesPerSecond) continuous=\(current.budget.continuousFramesPerSecond) heavy=\(current.budget.heavyVisualFramesPerSecond)",
            "gpuScale=\(String(format: "%.2f", current.budget.gpuRenderScale)) particles=\(String(format: "%.2f", current.budget.particleDensityScale)) shaders=\(current.budget.allowsExpensiveShaders)",
            "frameProbe=disabled renderQuality=full renderTier=\(current.renderPressureTier.rawValue)",
            "thermal=\(current.thermalStateRawValue) lowPower=\(current.isLowPowerModeEnabled) active=\(current.isApplicationActive) captured=\(current.isScreenCaptured)",
            "workloads=\(current.activeWorkloads.joined(separator: ","))"
        ].joined(separator: "\n")
    }

    private func installObservers() {
        let center = NotificationCenter.default
        observerTokens.append(center.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshBudget(reason: "thermal") }
        })
        observerTokens.append(center.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshBudget(reason: "power") }
        })
        observerTokens.append(center.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isScreenCaptured = Self.anyScreenCaptured()
                self.screenCaptured = self.isScreenCaptured
                self.refreshBudget(reason: "screen capture")
            }
        })
        observerTokens.append(center.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                // 内存告警通常伴随图片解码、纹理上传或系统整体压力。
                // 仅临时降低可重建视觉/后台任务，不触碰音频播放。
                self.transientPressureUntil = Date().addingTimeInterval(90)
                self.refreshBudget(reason: "memory pressure")
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
                self.isScreenCaptured = Self.anyScreenCaptured()
                self.screenCaptured = self.isScreenCaptured
                self.refreshBudget(reason: "foreground")
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
                // 后台直接由环境档位接管，不再保留/消费前台瞬时 CPU 峰值；
                // 否则重新回前台时会被旧样本继续压在低画质档。
                self.smoothedCPUPercent = 0
                self.cpuTier = .maximum
                self.pendingCPUTier = nil
                self.pendingCPUStreak = 0
                self.recoveryStreak = 0
                self.refreshBudget(reason: "background", sampledCPU: 0)
            }
        })
    }

    private func startMonitor() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                // 线程级 CPU 采样会遍历进程中的每条线程。旧版每 2 秒常驻
                // 扫描，在播放和复杂动画期间会与主业务叠加。重视觉期间 8 秒、
                // 普通前台 20 秒、后台 60 秒已经足够判断持续压力，并允许系统
                // 合并唤醒，避免监控器自身造成发热。
                let interval: Duration
                if !self.isApplicationActive {
                    interval = .seconds(60)
                } else if !self.activeWorkloads.isEmpty {
                    interval = .seconds(8)
                } else {
                    interval = .seconds(20)
                }
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                let cpu = await Task.detached(priority: .utility) {
                    Self.processCPUUsagePercent()
                }.value
                guard self.isApplicationActive else { continue }
                self.consumeCPUSample(cpu)
            }
        }
    }

    private func consumeCPUSample(_ cpuPercent: Double) {
        guard isApplicationActive else { return }
        let normalized = max(0, cpuPercent.isFinite ? cpuPercent : 0)
        smoothedCPUPercent = smoothedCPUPercent == 0
            ? normalized
            : smoothedCPUPercent * 0.82 + normalized * 0.18

        // processCPUUsagePercent 是所有线程之和，100% 仅代表占满一个核心。
        // 阈值随设备核心数增长，避免一次封面解码或 SwiftUI 布局峰值就降档。
        let processorCount = Double(max(ProcessInfo.processInfo.activeProcessorCount, 1))
        let balancedThreshold = max(150, processorCount * 28)
        let reducedThreshold = max(240, processorCount * 42)
        let minimumThreshold = max(340, processorCount * 58)

        let candidate: MonoComputeBudget.Tier
        if smoothedCPUPercent >= minimumThreshold {
            candidate = .minimum
        } else if smoothedCPUPercent >= reducedThreshold {
            candidate = .reduced
        } else if smoothedCPUPercent >= balancedThreshold {
            candidate = .balanced
        } else {
            candidate = .maximum
        }

        if candidate > cpuTier {
            if pendingCPUTier == candidate {
                pendingCPUStreak += 1
            } else {
                pendingCPUTier = candidate
                pendingCPUStreak = 1
            }
            recoveryStreak = 0
            let requiredStreak = candidate == .minimum ? 7 : 5
            if pendingCPUStreak >= requiredStreak {
                cpuTier = MonoComputeBudget.Tier(
                    rawValue: min(candidate.rawValue, cpuTier.rawValue + 1)
                ) ?? candidate
                pendingCPUTier = nil
                pendingCPUStreak = 0
            }
        } else if candidate < cpuTier,
                  smoothedCPUPercent < balancedThreshold * 0.72 {
            recoveryStreak += 1
            pendingCPUTier = nil
            pendingCPUStreak = 0
            if recoveryStreak >= 4 {
                cpuTier = MonoComputeBudget.Tier(
                    rawValue: max(candidate.rawValue, cpuTier.rawValue - 1)
                ) ?? candidate
                recoveryStreak = 0
            }
        } else {
            pendingCPUTier = nil
            pendingCPUStreak = 0
            recoveryStreak = 0
        }

        refreshBudget(reason: "cpu", sampledCPU: normalized)
    }

    private func refreshBudget(reason: String, sampledCPU: Double? = nil) {
        let info = ProcessInfo.processInfo
        var environmentTier: MonoComputeBudget.Tier = .maximum

        if !isApplicationActive {
            environmentTier = .minimum
        } else if info.isLowPowerModeEnabled {
            environmentTier = .reduced
        }

        if isScreenCaptured {
            environmentTier = max(environmentTier, .reduced)
        }

        if let transientPressureUntil {
            if transientPressureUntil > Date() {
                environmentTier = max(environmentTier, .reduced)
            } else {
                self.transientPressureUntil = nil
            }
        }

        let thermalTier: MonoComputeBudget.Tier
        switch info.thermalState {
        case .nominal: thermalTier = .maximum
        // fair 只是系统轻微升温提示，不足以牺牲正在显示的视觉连续性。
        case .fair: thermalTier = .maximum
        case .serious: thermalTier = .reduced
        case .critical: thermalTier = .minimum
        @unknown default: thermalTier = .balanced
        }

        let resolvedTier = max(
            environmentTier,
            thermalTier,
            cpuTier,
            renderPressureTier
        )
        let nextBudget = MonoComputeBudget.make(tier: resolvedTier)
        let cpu = sampledCPU ?? snapshot.processCPUPercent
        snapshot = Snapshot(
            budget: nextBudget,
            processCPUPercent: cpu,
            smoothedCPUPercent: smoothedCPUPercent,
            thermalStateRawValue: info.thermalState.rawValue,
            isLowPowerModeEnabled: info.isLowPowerModeEnabled,
            isApplicationActive: isApplicationActive,
            isScreenCaptured: isScreenCaptured,
            frameDropRatio: lastFrameDropRatio,
            longestFrameDurationMilliseconds: lastLongestFrameDuration * 1_000,
            renderPressureTier: renderPressureTier,
            activeWorkloads: activeWorkloads.values
                .map(\.rawValue)
                .sorted(),
            sampledAt: Date()
        )

        guard nextBudget != budget else { return }
        budget = nextBudget
        MonoComputeBudgetStore.shared.update(nextBudget)
        Task { await MonoComputeScheduler.shared.budgetDidChange() }
        NotificationCenter.default.post(name: .monoComputeBudgetDidChange, object: nil)
        AppLogger.info(
            "MonoCompute Engine 调整 tier=\(resolvedTier.rawValue) reason=\(reason) cpu=\(String(format: "%.1f", cpu)) fps=\(nextBudget.interactiveFramesPerSecond)/\(nextBudget.continuousFramesPerSecond)/\(nextBudget.heavyVisualFramesPerSecond) gpuScale=\(String(format: "%.2f", nextBudget.gpuRenderScale))",
            category: .interface,
            event: "compute.engine.policy"
        )
    }

    private static func anyScreenCaptured() -> Bool {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen }
            .contains(where: \.isCaptured)
    }

    nonisolated static func processCPUUsagePercent() -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        guard result == KERN_SUCCESS, let threadList else { return 0 }

        defer {
            let size = vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: threadList)),
                size
            )
        }

        var total = 0.0
        for index in 0..<Int(threadCount) {
            var info = thread_basic_info_data_t()
            var count = mach_msg_type_number_t(THREAD_INFO_MAX)
            let status = withUnsafeMutablePointer(to: &info) { pointer in
                pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                    thread_info(
                        threadList[index],
                        thread_flavor_t(THREAD_BASIC_INFO),
                        rebound,
                        &count
                    )
                }
            }
            guard status == KERN_SUCCESS, info.flags & TH_FLAGS_IDLE == 0 else { continue }
            total += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100
        }
        return total
    }
}
