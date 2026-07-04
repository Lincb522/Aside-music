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
        guard retries > 0, isLandscapeLocked else { return }
        guard let windowScene = activeWindowScene else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.applyLandscape(retries: retries - 1)
            }
            return
        }

        if windowScene.interfaceOrientation.isLandscape {
            return
        }

        // 先通知系统支持方向已变，再请求旋转，避免请求被旧的方向掩码拒绝
        setNeedsUpdateOfSupportedInterfaceOrientations()
        let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscapeRight)
        windowScene.requestGeometryUpdate(prefs) { error in
            AppLogger.error("横屏旋转失败: \(error.localizedDescription)")
        }

        // 无论成功与否，稍后校验一次；仍是竖屏则重试（修复进入后显示竖屏布局的问题）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self, self.isLandscapeLocked else { return }
            if !(self.activeWindowScene?.interfaceOrientation.isLandscape ?? false) {
                self.applyLandscape(retries: retries - 1)
            }
        }
    }

    /// 前台活跃的 windowScene（连接场景中的第一个可能是后台场景）
    private var activeWindowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }

    private func rotateToPortrait() {
        guard let windowScene = activeWindowScene else { return }
        let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
        windowScene.requestGeometryUpdate(prefs) { error in
            AppLogger.error("竖屏旋转失败: \(error.localizedDescription)")
        }
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    private func setNeedsUpdateOfSupportedInterfaceOrientations() {
        guard let windowScene = activeWindowScene else { return }
        for window in windowScene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
