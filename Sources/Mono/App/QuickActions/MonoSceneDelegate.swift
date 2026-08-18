// 接管主窗口 Scene 的生命周期，处理：
//  - Home Screen Quick Actions（长按 App 图标的快捷方式）
//  - 通用深链（预留）
// SwiftUI 场景默认走系统隐式 SceneDelegate；当需要 shortcutItem 回调时
// 必须声明一个显式的 UIWindowSceneDelegate 并由 AppDelegate 指派。

import UIKit
import SwiftUI

/// Quick Action 类型常量（对应 Info.plist 中 `UIApplicationShortcutItemType`，
/// 同时也是动态创建时使用的 type 字段）
enum MonoQuickActionType {
    static let toggleGameMode = "com.zijiu.Mono.quickaction.toggleGameMode"
    static let openPlayer = "com.zijiu.Mono.quickaction.openPlayer"
}

/// Scene 创建/恢复期间系统给主线程的时间窗口很短。小组件深链会在该窗口内
/// 唤醒 App；播放器心跳必须等 Scene 提交完成后再继续，避免任何系统媒体服务
/// 调用与 UIKit 的 scene-create 流程竞争主线程。
@MainActor
enum MonoSceneLifecycleGate {
    private static var connectingSceneIDs = Set<String>()
    private static var generations: [String: UInt] = [:]

    static var defersPlaybackHeartbeat: Bool {
        !connectingSceneIDs.isEmpty
    }

    static func beginConnecting(_ session: UISceneSession) {
        let id = session.persistentIdentifier
        generations[id, default: 0] &+= 1
        connectingSceneIDs.insert(id)
    }

    static func finishConnecting(_ session: UISceneSession) {
        let id = session.persistentIdentifier
        let generation = generations[id, default: 0]
        Task { @MainActor in
            // sceneDidBecomeActive 之后再留出两次常见刷新周期，让 SwiftUI
            // 根视图和小组件深链路由先完成首帧提交。
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard generations[id] == generation else { return }
            connectingSceneIDs.remove(id)
        }
    }

    static func disconnect(_ session: UISceneSession) {
        let id = session.persistentIdentifier
        generations[id, default: 0] &+= 1
        connectingSceneIDs.remove(id)
    }
}

final class MonoSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        MonoSceneLifecycleGate.beginConnecting(session)
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
        MonoSceneLifecycleGate.finishConnecting(scene.session)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Background audio must not keep a display-synchronization source alive.
        // The foreground policy is restored by sceneWillEnterForeground.
        AppFrameRate.unlock(scene)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        MonoSceneLifecycleGate.disconnect(scene.session)
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
        case MonoQuickActionType.toggleGameMode:
            GameModeManager.shared.toggle()
            // 同步更新图标上的 quick actions（下次长按会反映新状态）
            MonoQuickActionsManager.refreshAsync()
            return true

        case MonoQuickActionType.openPlayer:
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

enum MonoQuickActionsManager {
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
            type: MonoQuickActionType.toggleGameMode,
            localizedTitle: NSLocalizedString(
                isActive ? "quick_action_exit_game_mode" : "quick_action_enter_game_mode",
                comment: ""
            ),
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(type: .play),
            userInfo: nil
        )

        let openPlayerItem = UIApplicationShortcutItem(
            type: MonoQuickActionType.openPlayer,
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
