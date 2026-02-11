// OrientationManager.swift
// 设备方向管理器 — 用于 MV 全屏横屏播放

import UIKit
import SwiftUI

/// 全局方向管理器，控制 App 支持的设备方向
class OrientationManager: ObservableObject {
    static let shared = OrientationManager()

    /// 当前允许的方向，默认仅竖屏
    @Published var allowedOrientations: UIInterfaceOrientationMask = .portrait

    private init() {}

    /// 进入横屏全屏模式
    func enterLandscape() {
        allowedOrientations = .landscape
        rotateToLandscape()
    }

    /// 退出横屏，回到竖屏
    func exitLandscape() {
        allowedOrientations = .portrait
        rotateToPortrait()
    }

    private func rotateToLandscape() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscapeRight)
        windowScene.requestGeometryUpdate(geometryPreferences) { error in
            AppLogger.error("横屏旋转失败: \(error.localizedDescription)")
        }
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    private func rotateToPortrait() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
        windowScene.requestGeometryUpdate(geometryPreferences) { error in
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
