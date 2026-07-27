import SwiftUI

/// 单例稳定引用，避免每次 `body` 重建 `Environment` 里的 struct 闭包导致子树（尤其液态玻璃）反复挂载产生闪烁。
@MainActor
final class MonoSheetDragCoordinator: ObservableObject {
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
            withAnimation(MonoSheetAnimation.dismiss) {
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

struct MonoSheetContext {
    let preset: MonoSheetPreset
}

struct MonoSheetDismissAction: Sendable {
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

private struct MonoSheetContextKey: EnvironmentKey {
    static let defaultValue: MonoSheetContext? = nil
}

private struct MonoSheetDismissActionKey: EnvironmentKey {
    static let defaultValue = MonoSheetDismissAction()
}

private struct MonoSheetStretchAmountKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct MonoSheetDragCoordinatorKey: EnvironmentKey {
    static let defaultValue: MonoSheetDragCoordinator? = nil
}

extension EnvironmentValues {
    var monoSheetContext: MonoSheetContext? {
        get { self[MonoSheetContextKey.self] }
        set { self[MonoSheetContextKey.self] = newValue }
    }

    var monoSheetDismiss: MonoSheetDismissAction {
        get { self[MonoSheetDismissActionKey.self] }
        set { self[MonoSheetDismissActionKey.self] = newValue }
    }

    var monoSheetStretchAmount: CGFloat {
        get { self[MonoSheetStretchAmountKey.self] }
        set { self[MonoSheetStretchAmountKey.self] = newValue }
    }

    var monoSheetDragCoordinator: MonoSheetDragCoordinator? {
        get { self[MonoSheetDragCoordinatorKey.self] }
        set { self[MonoSheetDragCoordinatorKey.self] = newValue }
    }
}

struct MonoSheetAwareBackground<Content: View>: View {
    let content: Content

    @Environment(\.monoSheetContext) private var monoSheetContext

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Group {
            if monoSheetContext == nil {
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
    monoSheetDismiss: MonoSheetDismissAction
) {
    if monoSheetDismiss.isAvailable {
        monoSheetDismiss()
    } else {
        systemDismiss()
    }
}
