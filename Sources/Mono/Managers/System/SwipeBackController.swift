import UIKit
import SwiftUI

/// 全局侧滑返回控制器 - 拦截 UINavigationController 实现全屏返回手势
@MainActor
class SwipeBackController: NSObject, UIGestureRecognizerDelegate {
    
    static let shared = SwipeBackController()
    
    private var attachedNavControllers = NSHashTable<UINavigationController>.weakObjects()
    private var gestureMap = NSMapTable<UINavigationController, UIPanGestureRecognizer>.weakToStrongObjects()
    
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
        
        guard let interactivePopGestureRecognizer = navigationController.interactivePopGestureRecognizer,
              let gestureView = interactivePopGestureRecognizer.view else {
            return
        }
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleFullScreenPan(_:)))
        panGesture.delegate = self
        panGesture.maximumNumberOfTouches = 1
        panGesture.cancelsTouchesInView = false

        // 不再依赖 interactivePopGestureRecognizer 的私有 targets/KVC。
        // 系统版本变化时该私有目标可能为空，之前会导致整套全局侧滑完全没有安装。
        gestureView.addGestureRecognizer(panGesture)
        // 保留系统边缘返回。布局期关闭该手势会迫使 UINavigationController
        // 重新计算 bar 状态，和 SwiftUI 的 tab 切换重叠时可能触发 iOS 26
        // UINavigationBar.layoutSubviews 内部断言。全屏手势只负责边缘以外区域。
        interactivePopGestureRecognizer.isEnabled = true
        attachedNavControllers.add(navigationController)
        gestureMap.setObject(panGesture, forKey: navigationController)

        AppLogger.debug("SwipeBackController: Attached stable full-screen gesture (\(attachedNavControllers.count) total)")
    }
    
    /// 手势状态接收者 — 桥接到 EdgeSwipeGuard
    private let swipeGuardTarget = SwipeGuardTarget()
    
    private func findNavigationController(for gesture: UIGestureRecognizer) -> UINavigationController? {
        for nav in attachedNavControllers.allObjects {
            if gestureMap.object(forKey: nav) == gesture {
                return nav
            }
        }
        return nil
    }

    @objc private func handleFullScreenPan(_ pan: UIPanGestureRecognizer) {
        swipeGuardTarget.handleGestureState(pan)
        guard pan.state == .ended,
              let nav = findNavigationController(for: pan),
              nav.viewControllers.count > 1,
              nav.transitionCoordinator == nil else {
            return
        }

        let isRTL = nav.view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let direction: CGFloat = isRTL ? -1 : 1
        let translation = pan.translation(in: pan.view).x * direction
        let velocity = pan.velocity(in: pan.view).x * direction
        let projected = translation + velocity * 0.16
        guard max(translation, projected) >= 86 else { return }

        nav.popViewController(animated: true)
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
              let nav = findNavigationController(for: pan) else {
            return true
        }
        
        guard nav.viewControllers.count > 1 else {
            return false
        }
        
        if nav.transitionCoordinator != nil {
            return false
        }
        
        let velocity = pan.velocity(in: pan.view)
        let isRTL = nav.view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let directionalVelocity = isRTL ? -velocity.x : velocity.x
        guard directionalVelocity > 0 else { return false }

        let ratio = abs(velocity.y) / max(abs(velocity.x), 1)
        guard ratio < 0.82 else { return false }
        
        let location = pan.location(in: pan.view)
        let isInEdgeZone = isRTL
            ? location.x > (pan.view?.bounds.width ?? 0) - 50
            : location.x < 50

        // 边缘区域交还给系统的 interactivePopGestureRecognizer，避免同一次返回
        // 同时驱动系统交互转场和自定义 pop。
        guard !isInEdgeZone else { return false }
        
        if let hitView = pan.view?.hitTest(location, with: nil) {
            if hitView is UISlider { return false }
            
            var currentView: UIView? = hitView
            while let view = currentView {
                if let scrollView = view as? UIScrollView {
                    let isHorizontal = scrollView.contentSize.width > scrollView.bounds.width
                    let isAtStart = scrollView.contentOffset.x <= 0
                    
                    if isHorizontal && !isAtStart && !isInEdgeZone {
                        return false
                    }
                }
                
                if view == pan.view { break }
                currentView = view.superview
            }
        }
        
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let scrollView = otherGestureRecognizer.view as? UIScrollView {
            return scrollView.contentOffset.x <= 0
        }
        return false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
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
    private var pendingAttach: DispatchWorkItem?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        attachIfNeeded()
    }
    
    func attachIfNeeded() {
        guard let window = view.window else { return }
        // viewDidLayoutSubviews 在导航栏布局和 tab 转场中会连续触发。只保留一个
        // 延迟扫描，不能在每次布局时取消并重建任务，更不能同步修改导航手势。
        guard pendingAttach == nil else { return }
        let work = DispatchWorkItem { [weak self, weak window] in
            defer { self?.pendingAttach = nil }
            guard let window else { return }
            SwipeBackController.shared.enable(for: window)
        }
        pendingAttach = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // NavigationStack 和模态页面会延迟创建 UINavigationController；每次布局
        // 只做一次去重扫描，保证后创建的二、三级页面也能获得同一返回手势。
        attachIfNeeded()
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
