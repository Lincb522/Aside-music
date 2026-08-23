import Combine
import SwiftUI
import UIKit

/// 全局文本输入状态。直接监听 UIKit 编辑通知，因此 SwiftUI 的 TextField、
/// SecureField、TextEditor 以及 UIKit 包装输入框都会自动纳入，不要求页面逐个上报。
@MainActor
final class MonoTextInputActivity: ObservableObject {
    static let shared = MonoTextInputActivity()

    @Published private(set) var isEditing = false

    private var cancellables = Set<AnyCancellable>()
    private var pendingEndTask: Task<Void, Never>?
    private weak var recentTextResponder: UIView?
    private var recentTextResponderDate = Date.distantPast

    private init() {
        let center = NotificationCenter.default
        Publishers.Merge3(
            center.publisher(for: UITextField.textDidBeginEditingNotification),
            center.publisher(for: UITextView.textDidBeginEditingNotification),
            Publishers.Merge(
                center.publisher(for: UITextField.textDidChangeNotification),
                center.publisher(for: UITextView.textDidChangeNotification)
            )
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            self?.rememberTextResponder(from: notification)
            self?.pendingEndTask?.cancel()
            self?.pendingEndTask = nil
            self?.isEditing = true
        }
        .store(in: &cancellables)

        Publishers.Merge(
            center.publisher(for: UITextField.textDidEndEditingNotification),
            center.publisher(for: UITextView.textDidEndEditingNotification)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            self?.rememberTextResponder(from: notification)
            self?.scheduleEditingStateRefresh()
        }
        .store(in: &cancellables)
    }

    private func rememberTextResponder(from notification: Notification) {
        guard let responder = notification.object as? UIView else { return }
        recentTextResponder = responder
        recentTextResponderDate = Date()
    }

    /// Return 提交时 SwiftUI 可能已经让输入框失去第一响应者。短时间保留最近
    /// 编辑的 UIKit 输入控件，确保仍可读取输入法刚刚确认的完整组合文本。
    fileprivate func mostRecentTextResponder(maxAge: TimeInterval = 1.5) -> UIView? {
        guard Date().timeIntervalSince(recentTextResponderDate) <= maxAge else { return nil }
        return recentTextResponder
    }

    private func scheduleEditingStateRefresh() {
        pendingEndTask?.cancel()
        pendingEndTask = Task { @MainActor [weak self] in
            // 输入焦点从一个字段切到另一个字段时，UIKit 会先发 end 再发 begin。
            // 留出一个很短的事件周期，避免悬浮播放器在两次通知之间闪现。
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }
            self?.isEditing = Self.hasActiveTextInput
        }
    }

    private static var hasActiveTextInput: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .contains { window in
                guard let responder = window.monoFirstResponder else { return false }
                return responder is UITextField || responder is UITextView
            }
    }
}

private extension UIView {
    var monoFirstResponder: UIView? {
        if isFirstResponder { return self }
        for child in subviews {
            if let responder = child.monoFirstResponder {
                return responder
            }
        }
        return nil
    }
}

/// SwiftUI 的 Binding 会在输入法组合文本确认后才更新。中文、日文等输入法下，
/// Return 或发送按钮可能先于这次更新执行，因此提交前需要直接向 UIKit 输入控件
/// 确认 marked text，并把最终文本同步回 Binding。
@MainActor
enum MonoTextInputCommitter {
    static func commit(
        text: Binding<String>,
        perform action: @escaping @MainActor (String) -> Void
    ) {
        let responder = activeTextResponder
            ?? MonoTextInputActivity.shared.mostRecentTextResponder()
        // 先保留 Binding 中已经可见的内容。部分输入法在 Return 事件到达时，
        // UITextField 会短暂回报空字符串；此时不能用这个瞬时空值覆盖用户
        // 已经输入并显示在 SwiftUI TextField 中的关键词。
        let bindingValueBeforeCommit = text.wrappedValue
        let responderValueBeforeCommit = textValue(from: responder)
        let hadMarkedText: Bool

        if let input = responder as? UITextInput,
           input.markedTextRange != nil {
            hadMarkedText = true
            input.unmarkText()
        } else {
            hadMarkedText = false
        }

        Task { @MainActor in
            // unmarkText 的 editingChanged 与 SwiftUI Binding 更新并不同步。
            // 跨过当前键盘事件周期，再从同一个 UIKit 控件读取最终值。
            await Task.yield()
            try? await Task.sleep(nanoseconds: 12_000_000)

            let valueAfterCommit = textValue(from: responder)
            let value = resolvedValue(
                valueAfterCommit: valueAfterCommit,
                responderValueBeforeCommit: responderValueBeforeCommit,
                bindingValueBeforeCommit: bindingValueBeforeCommit,
                currentBindingValue: text.wrappedValue,
                hadMarkedText: hadMarkedText
            )

            if text.wrappedValue != value {
                text.wrappedValue = value
            }
            action(value)
        }
    }

    /// 优先采用输入控件完成组合后的内容；若 UIKit 在 Return 周期短暂返回空值，
    /// 则回退到提交前后非空的 Binding，而不是把真正输入清空。
    private static func resolvedValue(
        valueAfterCommit: String?,
        responderValueBeforeCommit: String?,
        bindingValueBeforeCommit: String,
        currentBindingValue: String,
        hadMarkedText: Bool
    ) -> String {
        // 中文输入法按 Return 时，SwiftUI Binding 往往还是“周杰”，而完整
        // UITextInput 文档已经是“周杰伦”。如果 unmark 后系统短暂回退成旧值，
        // 保留提交前完整文档中包含的组合文字，不能把最后一个字截掉。
        if hadMarkedText {
            let responderCandidates = [
                valueAfterCommit,
                responderValueBeforeCommit
            ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

            if let completeResponderValue = responderCandidates.max(by: {
                $0.count < $1.count
            }) {
                return completeResponderValue
            }
        }

        if let valueAfterCommit, !valueAfterCommit.isEmpty {
            return valueAfterCommit
        }

        if let responderValueBeforeCommit,
           !responderValueBeforeCommit.isEmpty {
            return responderValueBeforeCommit
        }

        if !currentBindingValue.isEmpty {
            return currentBindingValue
        }

        if !bindingValueBeforeCommit.isEmpty {
            return bindingValueBeforeCommit
        }

        return responderValueBeforeCommit ?? valueAfterCommit ?? ""
    }

    /// 只结束真实存在且仍属于前台场景的输入会话。避免在弹窗已经关闭、
    /// 键盘从未出现或场景正在销毁时再次广播键盘隐藏事件。
    @discardableResult
    static func resignActiveTextInputIfPresent() -> Bool {
        guard UIApplication.shared.applicationState == .active,
              let responder = activeTextResponder,
              let scene = responder.window?.windowScene,
              scene.activationState == .foregroundActive else {
            return false
        }
        return responder.resignFirstResponder()
    }

    private static func textValue(from responder: UIView?) -> String? {
        // `UITextField.text` 在中文/日文组合输入期间可能尚未包含 marked text。
        // UITextInput 的完整 document range 才是屏幕上当前显示的完整字符串。
        if let input = responder as? UITextInput,
           let documentRange = input.textRange(
               from: input.beginningOfDocument,
               to: input.endOfDocument
           ),
           let documentText = input.text(in: documentRange) {
            return documentText
        }

        if let textField = responder as? UITextField {
            return textField.text
        }
        if let textView = responder as? UITextView {
            return textView.text
        }
        return nil
    }

    private static var activeTextResponder: UIView? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .sorted { lhs, rhs in
                if lhs.isKeyWindow != rhs.isKeyWindow {
                    return lhs.isKeyWindow
                }
                return lhs.windowLevel.rawValue > rhs.windowLevel.rawValue
            }
            .compactMap(\.monoFirstResponder)
            .first
    }
}

extension View {
    /// 统一的文本输入行为：关闭自动大写与自动纠错（用于搜索词、Key、URL 等字段）。
    func monoTextInputBehavior() -> some View {
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }

    /// 在输入法完成组合文本后再执行 Return 提交，避免空搜索或丢失最后一个字。
    func monoOnSubmit(
        text: Binding<String>,
        perform action: @escaping @MainActor (String) -> Void
    ) -> some View {
        onSubmit {
            MonoTextInputCommitter.commit(text: text, perform: action)
        }
    }
}
