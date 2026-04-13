// OrientationManager.swift
// 设备方向管理器 — 用于 MV 全屏横屏播放

import UIKit
import SwiftUI

/// 全局方向管理器，控制 App 支持的设备方向
@MainActor
class OrientationManager: ObservableObject {
    static let shared = OrientationManager()

    /// 当前允许的方向，默认仅竖屏
    @Published var allowedOrientations: UIInterfaceOrientationMask = .portrait

    private init() {}

    @Published var isLandscapeLocked = false

    /// 进入横屏全屏模式（带重试）
    func enterLandscape() {
        isLandscapeLocked = true
        allowedOrientations = .landscape
        applyLandscape(retries: 3)
    }

    /// 退出横屏，回到竖屏
    func exitLandscape() {
        isLandscapeLocked = false
        allowedOrientations = .portrait
        rotateToPortrait()
    }

    /// 从后台恢复或冷启动时，如果之前锁定了横屏就重新应用
    func reapplyIfNeeded() {
        guard isLandscapeLocked else { return }
        allowedOrientations = .landscape
        applyLandscape(retries: 3)
    }

    private func applyLandscape(retries: Int) {
        guard retries > 0 else { return }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.applyLandscape(retries: retries - 1)
            }
            return
        }

        let currentOrientation = windowScene.interfaceOrientation
        if currentOrientation.isLandscape {
            return
        }

        let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscapeRight)
        windowScene.requestGeometryUpdate(prefs) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.applyLandscape(retries: retries - 1)
            }
        }
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    private func rotateToPortrait() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
        windowScene.requestGeometryUpdate(prefs) { error in
            AppLogger.error("竖屏旋转失败: \(error.localizedDescription)")
        }
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    private func setNeedsUpdateOfSupportedInterfaceOrientations() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        for window in windowScene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
