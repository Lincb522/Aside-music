import Foundation
import Combine

/// Aria 沉浸模式的性能调节器 — 按设备热度、省电模式与屏幕捕获自动降档。
/// 封面粒子 Canvas 是 CPU 渲染（每帧数千次 fill），机身发热或低电量时
/// 主动降低粒子密度与帧率，避免掉帧和进一步发热。
/// 系统录屏/投屏时每帧还要额外走一遍抓取+缩放+编码，必须提前降档而不是等过热。
@MainActor
final class AriaPerformanceGovernor: ObservableObject {
    static let shared = AriaPerformanceGovernor()

    enum Tier {
        case high    // 常态：满密度 60fps
        case medium  // 发热（serious）：降密度 45fps
        case low     // 低电量 / 过热（critical）/ 录屏投屏：最低密度 30fps
    }

    @Published private(set) var tier: Tier = .high
    /// 屏幕正在被系统录屏 / AirPlay 镜像 / 投屏捕获
    @Published private(set) var isScreenCaptured = false

    /// 封面粒子网格边长（粒子数 = grid²：4096 / 2916 / 1936）
    var coverGrid: Int {
        let density = MonoComputeBudgetStore.shared.current.particleDensityScale
        return max(36, min(64, Int((64 * density.squareRoot()).rounded())))
    }

    /// 封面粒子 Canvas 帧率上限
    var coverFPS: Int {
        min(60, MonoComputeBudgetStore.shared.current.heavyVisualFramesPerSecond)
    }

    /// 舞台镜头（漂移/视差/节拍冲击）帧率上限
    var stageFPS: Int {
        min(60, MonoComputeBudgetStore.shared.current.heavyVisualFramesPerSecond)
    }

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        refresh(
            budget: MonoComputeEngine.shared.budget,
            captured: MonoComputeEngine.shared.screenCaptured
        )
        MonoComputeEngine.shared.$budget
            .combineLatest(MonoComputeEngine.shared.$screenCaptured)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] budget, captured in
                self?.refresh(budget: budget, captured: captured)
            }
            .store(in: &cancellables)
    }

    private func refresh(budget: MonoComputeBudget, captured: Bool) {
        let next: Tier
        switch budget.tier {
        case .maximum:
            next = .high
        case .balanced, .reduced:
            next = .medium
        case .minimum:
            next = .low
        }
        if captured != isScreenCaptured {
            isScreenCaptured = captured
        }
        if next != tier {
            tier = next
            AppLogger.debug("[AriaPerf] 质量档位 -> \(next) captured=\(captured)")
        }
    }
}
