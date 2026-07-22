import Foundation
import Combine
import UIKit

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
        NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    private var anyScreenCaptured: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen }
            .contains(where: \.isCaptured)
    }

    private func refresh() {
        let info = ProcessInfo.processInfo
        let captured = anyScreenCaptured
        let next: Tier
        // 录屏时系统对每帧额外抓取+编码，与舞台渲染叠加是掉帧/发热主源，
        // 不等 thermalState 升级，直接压到最低档。
        if captured || info.isLowPowerModeEnabled {
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
        if captured != isScreenCaptured {
            isScreenCaptured = captured
        }
        if next != tier {
            tier = next
            AppLogger.debug("[AriaPerf] 质量档位 -> \(next) captured=\(captured)")
        }
    }
}
