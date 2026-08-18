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

    private init() {
        let center = NotificationCenter.default
        Publishers.Merge(
            center.publisher(for: UITextField.textDidBeginEditingNotification),
            center.publisher(for: UITextView.textDidBeginEditingNotification)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
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
        .sink { [weak self] _ in
            self?.scheduleEditingStateRefresh()
        }
        .store(in: &cancellables)
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
        let value = committedText(fallback: text.wrappedValue)
        if text.wrappedValue != value {
            text.wrappedValue = value
        }

        Task { @MainActor in
            // 给 SwiftUI 一次机会消费 UIKit 在 unmarkText 后发出的 editingChanged，
            // 但提交动作始终使用上面直接读取的完整文本，不依赖事件到达顺序。
            await Task.yield()
            action(value)
        }
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

    private static func committedText(fallback: String) -> String {
        guard let responder = activeTextResponder else { return fallback }

        if let input = responder as? UITextInput,
           input.markedTextRange != nil {
            input.unmarkText()
        }

        if let textField = responder as? UITextField {
            return textField.text ?? fallback
        }
        if let textView = responder as? UITextView {
            return textView.text
        }
        return fallback
    }

    private static var activeTextResponder: UIView? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
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
