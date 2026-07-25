// 接管主窗口 Scene 的生命周期，处理：
//  - Home Screen Quick Actions（长按 App 图标的快捷方式）
//  - 通用深链（预留）
// SwiftUI 场景默认走系统隐式 SceneDelegate；当需要 shortcutItem 回调时
// 必须声明一个显式的 UIWindowSceneDelegate 并由 AppDelegate 指派。

import UIKit
import SwiftUI

/// Quick Action 类型常量（对应 Info.plist 中 `UIApplicationShortcutItemType`，
/// 同时也是动态创建时使用的 type 字段）
enum MonologueQuickActionType {
    static let toggleGameMode = "com.zijiu.Monologue.quickaction.toggleGameMode"
    static let openPlayer = "com.zijiu.Monologue.quickaction.openPlayer"
}

final class MonologueSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let windowScene = scene as? UIWindowScene {
            AppFrameRate.lock(windowScene, reason: "scene will connect")
        }

        // 启动时如果是从 shortcut 冷启动，立刻处理
        if let shortcutItem = connectionOptions.shortcutItem {
            Task { @MainActor in
                _ = await Self.handle(shortcutItem: shortcutItem)
            }
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        if let windowScene = scene as? UIWindowScene {
            AppFrameRate.lock(windowScene, reason: "scene will enter foreground")
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        if let windowScene = scene as? UIWindowScene {
            AppFrameRate.lock(windowScene, reason: "scene did become active")
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Background audio must not keep a display-synchronization source alive.
        // The foreground policy is restored by sceneWillEnterForeground.
        AppFrameRate.unlock(scene)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        AppFrameRate.unlock(scene)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            let handled = await Self.handle(shortcutItem: shortcutItem)
            completionHandler(handled)
        }
    }

    // MARK: - 分发

    @MainActor
    static func handle(shortcutItem: UIApplicationShortcutItem) async -> Bool {
        switch shortcutItem.type {
        case MonologueQuickActionType.toggleGameMode:
            GameModeManager.shared.toggle()
            // 同步更新图标上的 quick actions（下次长按会反映新状态）
            MonologueQuickActionsManager.refreshAsync()
            return true

        case MonologueQuickActionType.openPlayer:
            // 触发打开全屏播放器：ContentView 已监听此通知
            NotificationCenter.default.post(
                name: .init("OpenNormalPlayer"),
                object: nil
            )
            return true

        default:
            return false
        }
    }
}

// MARK: - 动态维护 shortcut items

enum MonologueQuickActionsManager {
    /// 刷新 App 图标长按菜单。
    /// 传入当前 GameMode 状态，显示"开启/关闭"两种标题。
    ///
    /// ⚠️ 必须通过参数传入 isActive，而不是内部读 `GameModeManager.shared.isActive`。
    /// 因为 refresh 可能在 `GameModeManager.init()` 内被调用
    /// （来自 `syncToAppGroup`），此时 `shared` 仍在初始化，
    /// 再次访问会造成循环初始化崩溃（EXC_BREAKPOINT）。
    @MainActor
    static func refresh(isActive: Bool) {
        let toggleGameModeItem = UIApplicationShortcutItem(
            type: MonologueQuickActionType.toggleGameMode,
            localizedTitle: NSLocalizedString(
                isActive ? "quick_action_exit_game_mode" : "quick_action_enter_game_mode",
                comment: ""
            ),
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(type: .play),
            userInfo: nil
        )

        let openPlayerItem = UIApplicationShortcutItem(
            type: MonologueQuickActionType.openPlayer,
            localizedTitle: NSLocalizedString("quick_action_open_player", comment: ""),
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(type: .play),
            userInfo: nil
        )

        UIApplication.shared.shortcutItems = [toggleGameModeItem, openPlayerItem]
    }

    /// 便捷方法：异步读取当前 GameMode 状态后刷新。
    /// 用异步调度避免在 `GameModeManager.init()` 正在执行时重入访问 `shared`。
    @MainActor
    static func refreshAsync() {
        DispatchQueue.main.async {
            refresh(isActive: GameModeManager.shared.isActive)
        }
    }
}
