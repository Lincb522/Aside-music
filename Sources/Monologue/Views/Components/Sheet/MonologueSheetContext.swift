import SwiftUI

/// 单例稳定引用，避免每次 `body` 重建 `Environment` 里的 struct 闭包导致子树（尤其液态玻璃）反复挂载产生闪烁。
@MainActor
final class MonologueSheetDragCoordinator: ObservableObject {
    @Published private(set) var translation: CGFloat = 0
    @Published private(set) var dismissalBaseline: CGFloat = 0

    private(set) var isTopmost = false
    private(set) var isVisible = false
    private(set) var allowsDragToDismiss = false
    private(set) var requestDismiss: () -> Void = {}

    func sync(
        isTopmost: Bool,
        isVisible: Bool,
        allowsDragToDismiss: Bool,
        requestDismiss: @escaping () -> Void
    ) {
        self.isTopmost = isTopmost
        self.isVisible = isVisible
        self.allowsDragToDismiss = allowsDragToDismiss
        self.requestDismiss = requestDismiss

        if isVisible, dismissalBaseline != 0 {
            dismissalBaseline = 0
        }

        if !isTopmost || !isVisible || !allowsDragToDismiss {
            resetTranslationWithoutAnimation()
        }
    }

    func applyDragTranslation(fromGestureHeight height: CGFloat) {
        guard isTopmost, isVisible, allowsDragToDismiss else { return }
        let next = Self.resolvedDragTranslation(for: height)
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            translation = next
        }
    }

    func endDrag(_ value: DragGesture.Value) {
        guard isTopmost, isVisible, allowsDragToDismiss else {
            resetTranslationWithoutAnimation()
            return
        }

        let predictedHeight = max(value.predictedEndTranslation.height, value.translation.height)
        let shouldDismiss = value.translation.height > 140 || predictedHeight > 220

        if shouldDismiss {
            requestDismiss()
        } else {
            dismissalBaseline = 0
            withAnimation(MonologueSheetAnimation.dismiss) {
                translation = 0
            }
        }
    }

    private func resetTranslationWithoutAnimation() {
        guard translation != 0 else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            translation = 0
        }
    }

    /// Sheet 进入收起动画时调用，记录手势结束时的位置作为 dismiss 动画起点，
    /// 避免先清空 drag offset 再叠加 visibility offset 导致抖动重影。
    func clearTranslationForVisibilityHide() {
        dismissalBaseline = max(dismissalBaseline, max(0, translation))
        resetTranslationWithoutAnimation()
    }

    private static func resolvedDragTranslation(for translation: CGFloat) -> CGFloat {
        guard translation < 0 else { return translation }

        let upwardMagnitude = min(-translation, 260)
        return -(upwardMagnitude * 0.72)
    }
}

struct MonologueSheetContext {
    let preset: MonologueSheetPreset
}

struct MonologueSheetDismissAction: Sendable {
    private let handler: (@MainActor @Sendable () -> Void)?

    init(handler: (@MainActor @Sendable () -> Void)? = nil) {
        self.handler = handler
    }

    var isAvailable: Bool {
        handler != nil
    }

    @MainActor
    func callAsFunction() {
        handler?()
    }
}

private struct MonologueSheetContextKey: EnvironmentKey {
    static let defaultValue: MonologueSheetContext? = nil
}

private struct MonologueSheetDismissActionKey: EnvironmentKey {
    static let defaultValue = MonologueSheetDismissAction()
}

private struct MonologueSheetStretchAmountKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct MonologueSheetDragCoordinatorKey: EnvironmentKey {
    static let defaultValue: MonologueSheetDragCoordinator? = nil
}

extension EnvironmentValues {
    var monologueSheetContext: MonologueSheetContext? {
        get { self[MonologueSheetContextKey.self] }
        set { self[MonologueSheetContextKey.self] = newValue }
    }

    var monologueSheetDismiss: MonologueSheetDismissAction {
        get { self[MonologueSheetDismissActionKey.self] }
        set { self[MonologueSheetDismissActionKey.self] = newValue }
    }

    var monologueSheetStretchAmount: CGFloat {
        get { self[MonologueSheetStretchAmountKey.self] }
        set { self[MonologueSheetStretchAmountKey.self] = newValue }
    }

    var monologueSheetDragCoordinator: MonologueSheetDragCoordinator? {
        get { self[MonologueSheetDragCoordinatorKey.self] }
        set { self[MonologueSheetDragCoordinatorKey.self] = newValue }
    }
}

struct MonologueSheetAwareBackground<Content: View>: View {
    let content: Content

    @Environment(\.monologueSheetContext) private var monologueSheetContext

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Group {
            if monologueSheetContext == nil {
                content
            } else {
                Color.clear
            }
        }
    }
}

@MainActor
func dismissCurrentPresentation(
    systemDismiss: DismissAction,
    monologueSheetDismiss: MonologueSheetDismissAction
) {
    if monologueSheetDismiss.isAvailable {
        monologueSheetDismiss()
    } else {
        systemDismiss()
    }
}
