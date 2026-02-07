import UIKit
import SwiftUI

/// 全局侧滑返回控制器 - 拦截 UINavigationController 实现全屏返回手势
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
        
        guard let interactivePopGestureRecognizer = navigationController.interactivePopGestureRecognizer,
              let gestureView = interactivePopGestureRecognizer.view else {
            return
        }
        
        let panGesture = UIPanGestureRecognizer()
        panGesture.delegate = self
        panGesture.maximumNumberOfTouches = 1
        
        if let internalTargets = interactivePopGestureRecognizer.value(forKey: "targets") as? [NSObject],
           let internalTarget = internalTargets.first,
           let target = internalTarget.value(forKey: "target") {
            let action = Selector(("handleNavigationTransition:"))
            panGesture.addTarget(target, action: action)
            
            gestureView.addGestureRecognizer(panGesture)
            attachedNavControllers.add(navigationController)
            gestureMap.setObject(panGesture, forKey: navigationController)
            
            #if DEBUG
            print("SwipeBackController: Attached to NavigationController (\(attachedNavControllers.count) total)")
            #endif
        }
    }
    
    private func findNavigationController(for gesture: UIGestureRecognizer) -> UINavigationController? {
        for nav in attachedNavControllers.allObjects {
            if gestureMap.object(forKey: nav) == gesture {
                return nav
            }
        }
        return nil
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
        guard velocity.x > 0 else { return false }
        
        let ratio = abs(velocity.y) / abs(velocity.x)
        guard ratio < 1.5 else { return false }
        
        let location = pan.location(in: pan.view)
        let isInEdgeZone = location.x < 50
        
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
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return otherGestureRecognizer.view is UIScrollView
    }
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            SwipeBackController.shared.enable(for: window)
            self?.hasAttached = true
        }
    }
}
