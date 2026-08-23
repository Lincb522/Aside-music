import Foundation
import Combine

/// Aria 沉浸模式的运行状态桥接器。视觉质量固定保持 high；系统压力由
/// MonoCompute 调整后台任务并发处理，不再动态减少粒子、光效或动画帧率。
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
        isScreenCaptured = MonoComputeEngine.shared.screenCaptured
        MonoComputeEngine.shared.$screenCaptured
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] captured in
                self?.isScreenCaptured = captured
            }
            .store(in: &cancellables)
    }
}
