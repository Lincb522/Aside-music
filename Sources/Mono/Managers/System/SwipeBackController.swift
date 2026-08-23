import UIKit
import SwiftUI

/// 旧版 UIKit 返回手势兼容器。
///
/// SwiftUI NavigationStack 的返回必须由 path / dismiss 驱动，不能直接调用
/// UINavigationController.popViewController。这里只观察系统原生边缘返回状态，
/// 不再安装全屏 UIPanGestureRecognizer，也不再修改 UIKit 导航栈。
@MainActor
class SwipeBackController: NSObject {
    
    static let shared = SwipeBackController()

    private var attachedNavControllers = NSHashTable<UINavigationController>.weakObjects()
    
    private override init() {
        super.init()
    }
    
    func enable(for window: UIWindow?) {
        guard let rootVC = window?.rootViewController else { return }
        findAndAttachAll(to: rootVC)
    }
    
    private func findAndAttachAll(to viewController: UIViewController) {
        if let nav = viewController as? UINavigationController {
            attach(to: nav)
        }
        
        if let presented = viewController.presentedViewController {
            findAndAttachAll(to: presented)
        }
        
        for child in viewController.children {
            findAndAttachAll(to: child)
        }
    }
    
    private func attach(to navigationController: UINavigationController) {
        guard !attachedNavControllers.contains(navigationController) else { return }
        guard navigationController.transitionCoordinator == nil else { return }

        guard let interactivePopGestureRecognizer = navigationController.interactivePopGestureRecognizer else {
            return
        }

        // 只旁听系统手势以维持 EdgeSwipeGuard 状态。系统是否启用该手势由
        // UINavigationController 自己决定，禁止在布局期间强行切换 isEnabled。
        interactivePopGestureRecognizer.addTarget(
            swipeGuardTarget,
            action: #selector(SwipeGuardTarget.handleGestureState(_:))
        )
        attachedNavControllers.add(navigationController)

        AppLogger.debug("SwipeBackController: Observing native edge gesture (\(attachedNavControllers.count) total)")
    }
    
    /// 手势状态接收者 — 桥接到 EdgeSwipeGuard
    private let swipeGuardTarget = SwipeGuardTarget()
    
}

// MARK: - SwiftUI Integration

struct SwipeBackInjector: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SwipeBackViewController {
        return SwipeBackViewController()
    }
    
    func updateUIViewController(_ uiViewController: SwipeBackViewController, context: Context) {
        uiViewController.attachIfNeeded()
    }
}

class SwipeBackViewController: UIViewController {
    private var hasAttached = false
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        attachIfNeeded()
    }
    
    func attachIfNeeded() {
        guard !hasAttached, let window = view.window else { return }
        hasAttached = true
        // 即使旧调用点仍保留，也只在页面出现后扫描一次，绝不在
        // viewDidLayoutSubviews / UINavigationBar 布局期间反复遍历和修改手势。
        DispatchQueue.main.async { [weak window] in
            guard let window else { return }
            SwipeBackController.shared.enable(for: window)
        }
    }
}

// MARK: - 防误触手势状态桥接

/// 接收 UIPanGestureRecognizer 状态变化，通知 EdgeSwipeGuard
final class SwipeGuardTarget: NSObject {
    @MainActor @objc func handleGestureState(_ gesture: UIGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            EdgeSwipeGuard.shared.beginSwipe()
        case .ended, .cancelled, .failed:
            EdgeSwipeGuard.shared.endSwipe()
        default:
            break
        }
    }
}
