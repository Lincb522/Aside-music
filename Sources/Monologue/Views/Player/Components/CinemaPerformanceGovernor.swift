import Foundation
import Combine

/// 影院沉浸模式的性能调节器 — 按设备热度与省电模式自动降档。
/// 封面粒子 Canvas 是 CPU 渲染（每帧数千次 fill），机身发热或低电量时
/// 主动降低粒子密度与帧率，避免掉帧和进一步发热。
@MainActor
final class CinemaPerformanceGovernor: ObservableObject {
    static let shared = CinemaPerformanceGovernor()

    enum Tier {
        case high    // 常态：满密度 60fps
        case medium  // 发热（serious）：降密度 45fps
        case low     // 低电量 / 过热（critical）：最低密度 30fps
    }

    @Published private(set) var tier: Tier = .high

    /// 封面粒子网格边长（粒子数 = grid²：4096 / 2916 / 1936）
    var coverGrid: Int {
        switch tier {
        case .high: return 64
        case .medium: return 54
        case .low: return 44
        }
    }

    /// 封面粒子 Canvas 帧率上限
    var coverFPS: Int {
        switch tier {
        case .high: return 60
        case .medium: return 45
        case .low: return 30
        }
    }

    /// 舞台镜头（漂移/视差/节拍冲击）帧率上限
    var stageFPS: Int {
        switch tier {
        case .high: return 60
        case .medium: return 45
        case .low: return 30
        }
    }

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        refresh()
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    private func refresh() {
        let info = ProcessInfo.processInfo
        let next: Tier
        if info.isLowPowerModeEnabled {
            next = .low
        } else {
            switch info.thermalState {
            case .nominal, .fair:
                next = .high
            case .serious:
                next = .medium
            case .critical:
                next = .low
            @unknown default:
                next = .medium
            }
        }
        if next != tier {
            tier = next
            AppLogger.debug("[CinemaPerf] 质量档位 -> \(next)")
        }
    }
}
