import UIKit
import SwiftUI

/// Global Swipe Back Controller
/// Intercepts UINavigationController to enable full-screen pop gesture
/// Improved to handle multiple NavigationStacks and TabView conflicts
class SwipeBackController: NSObject, UIGestureRecognizerDelegate {
    
    static let shared = SwipeBackController()
    
    // Track all attached navigation controllers (for multi-NavigationStack support)
    private var attachedNavControllers = NSHashTable<UINavigationController>.weakObjects()
    
    // Map of nav controllers to their pan gestures
    private var gestureMap = NSMapTable<UINavigationController, UIPanGestureRecognizer>.weakToStrongObjects()
    
    private override init() {
        super.init()
    }
    
    /// Enable the gesture for a specific window
    func enable(for window: UIWindow?) {
        guard let rootVC = window?.rootViewController else { return }
        findAndAttachAll(to: rootVC)
    }
    
    /// Recursively find and attach to ALL UINavigationControllers in the hierarchy
    private func findAndAttachAll(to viewController: UIViewController) {
        // Check if this is a navigation controller
        if let nav = viewController as? UINavigationController {
            attach(to: nav)
        }
        
        // Check presented view controller
        if let presented = viewController.presentedViewController {
            findAndAttachAll(to: presented)
        }
        
        // Check all children
        for child in viewController.children {
            findAndAttachAll(to: child)
        }
    }
    
    private func attach(to navigationController: UINavigationController) {
        // Skip if already attached
        guard !attachedNavControllers.contains(navigationController) else { return }
        
        guard let interactivePopGestureRecognizer = navigationController.interactivePopGestureRecognizer,
              let gestureView = interactivePopGestureRecognizer.view else {
            return
        }
        
        // Create custom pan gesture
        let panGesture = UIPanGestureRecognizer()
        panGesture.delegate = self
        panGesture.maximumNumberOfTouches = 1
        
        // Copy targets from system gesture (using private API - fallback gracefully if fails)
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
    
    /// Find the navigation controller for a given gesture
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
        
        // 1. Must have controllers to pop
        guard nav.viewControllers.count > 1 else {
            return false
        }
        
        // 2. No transition in progress
        if nav.transitionCoordinator != nil {
            return false
        }
        
        // 3. Direction check (left to right)
        let velocity = pan.velocity(in: pan.view)
        guard velocity.x > 0 else { return false }
        
        // Must be horizontal movement (allow some vertical tolerance)
        let ratio = abs(velocity.y) / abs(velocity.x)
        guard ratio < 1.5 else { return false }
        
        // 4. Edge detection for first 50pt (left edge priority zone)
        let location = pan.location(in: pan.view)
        let isInEdgeZone = location.x < 50
        
        // 5. Hit test for conflicts
        if let hitView = pan.view?.hitTest(location, with: nil) {
            // Never conflict with sliders
            if hitView is UISlider { return false }
            
            // Check for horizontal scroll views
            var currentView: UIView? = hitView
            while let view = currentView {
                if let scrollView = view as? UIScrollView {
                    let isHorizontal = scrollView.contentSize.width > scrollView.bounds.width
                    let isAtStart = scrollView.contentOffset.x <= 0
                    
                    // If at start of horizontal scroll view, allow swipe back
                    // If not at start, only allow in edge zone
                    if isHorizontal && !isAtStart && !isInEdgeZone {
                        return false
                    }
                }
                
                // Stop traversal at navigation view
                if view == pan.view { break }
                currentView = view.superview
            }
        }
        
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow simultaneous recognition only with scroll views at their start position
        if let scrollView = otherGestureRecognizer.view as? UIScrollView {
            return scrollView.contentOffset.x <= 0
        }
        return false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Our gesture should have priority over scroll views
        return otherGestureRecognizer.view is UIScrollView
    }
}

// MARK: - SwiftUI Integration

/// Injects SwipeBackController into the SwiftUI lifecycle
struct SwipeBackInjector: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SwipeBackViewController {
        return SwipeBackViewController()
    }
    
    func updateUIViewController(_ uiViewController: SwipeBackViewController, context: Context) {
        uiViewController.attachIfNeeded()
    }
}

/// Helper view controller that attaches SwipeBackController when in hierarchy
class SwipeBackViewController: UIViewController {
    private var hasAttached = false
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        attachIfNeeded()
    }
    
    func attachIfNeeded() {
        guard !hasAttached, let window = view.window else { return }
        
        // Delay slightly to ensure SwiftUI navigation hierarchy is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            SwipeBackController.shared.enable(for: window)
            self?.hasAttached = true
        }
    }
}
