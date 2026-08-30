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
            guard let self else { return }
            self.rememberTextResponder(from: notification)
            self.pendingEndTask?.cancel()
            self.pendingEndTask = nil
            if !self.isEditing {
                self.isEditing = true
            }
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
    private static var activeSessions: [ObjectIdentifier: MonoTextInputCommitSession] = [:]

    static func commit(
        text: Binding<String>,
        responder preferredResponder: UIView? = nil,
        perform action: @escaping @MainActor (String) -> Void
    ) {
        guard let responder = preferredResponder
            ?? activeTextResponder
            ?? MonoTextInputActivity.shared.mostRecentTextResponder()
        else {
            action(text.wrappedValue)
            return
        }

        let responderID = ObjectIdentifier(responder)
        guard activeSessions[responderID] == nil else { return }

        let session = MonoTextInputCommitSession(
            responder: responder,
            text: text,
            perform: action
        ) {
            activeSessions[responderID] = nil
        }
        activeSessions[responderID] = session
        session.start()
    }

    fileprivate static func resolvedValue(
        settledResponderValue: String?,
        responderValueBeforeCommit: String?,
        bindingValueBeforeCommit: String,
        currentBindingValue: String
    ) -> String {
        // 组合词确认后可能比拼音或临时候选更短，最终文档值必须优先于字符数量。
        if let settledResponderValue, !settledResponderValue.isEmpty {
            return settledResponderValue
        }

        if !currentBindingValue.isEmpty {
            return currentBindingValue
        }

        if let responderValueBeforeCommit, !responderValueBeforeCommit.isEmpty {
            return responderValueBeforeCommit
        }

        if !bindingValueBeforeCommit.isEmpty {
            return bindingValueBeforeCommit
        }

        return settledResponderValue ?? responderValueBeforeCommit ?? ""
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

    fileprivate static func textValue(from responder: UIView?) -> String? {
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

@MainActor
private final class MonoTextInputCommitSession {
    private weak var responder: UIView?
    private let text: Binding<String>
    private let perform: @MainActor (String) -> Void
    private let didFinish: @MainActor () -> Void
    private let bindingValueBeforeCommit: String
    private let responderValueBeforeCommit: String?
    private var fallbackWorkItem: DispatchWorkItem?
    private var finishGeneration = 0
    private var isFinished = false

    init(
        responder: UIView,
        text: Binding<String>,
        perform: @escaping @MainActor (String) -> Void,
        didFinish: @escaping @MainActor () -> Void
    ) {
        self.responder = responder
        self.text = text
        self.perform = perform
        self.didFinish = didFinish
        bindingValueBeforeCommit = text.wrappedValue
        responderValueBeforeCommit = MonoTextInputCommitter.textValue(from: responder)
    }

    func start() {
        observeTextChanges()

        let hadMarkedText: Bool
        if let input = responder as? UITextInput, input.markedTextRange != nil {
            hadMarkedText = true
            input.unmarkText()
        } else {
            hadMarkedText = false
        }

        if hadMarkedText {
            // 第三方输入法可在 unmarkText 返回后才投递最终替换事件；通知负责
            // 提前完成，截止时间只处理未投递通知的键盘实现。
            let workItem = DispatchWorkItem { [weak self] in
                self?.finish()
            }
            fallbackWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
        } else {
            scheduleFinishAfterCurrentInputEvent()
        }
    }

    private func observeTextChanges() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UITextField.textDidChangeNotification,
            UITextField.textDidEndEditingNotification,
            UITextView.textDidChangeNotification,
            UITextView.textDidEndEditingNotification
        ]

        for name in names {
            center.addObserver(
                self,
                selector: #selector(handleTextChange(_:)),
                name: name,
                object: responder
            )
        }
    }

    @objc
    private func handleTextChange(_ notification: Notification) {
        scheduleFinishAfterCurrentInputEvent()
    }

    private func scheduleFinishAfterCurrentInputEvent() {
        finishGeneration += 1
        let generation = finishGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.finishGeneration == generation else { return }
            if let input = self.responder as? UITextInput,
               input.markedTextRange != nil {
                return
            }
            self.finish()
        }
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        fallbackWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)

        let value = MonoTextInputCommitter.resolvedValue(
            settledResponderValue: MonoTextInputCommitter.textValue(from: responder),
            responderValueBeforeCommit: responderValueBeforeCommit,
            bindingValueBeforeCommit: bindingValueBeforeCommit,
            currentBindingValue: text.wrappedValue
        )
        if text.wrappedValue != value {
            text.wrappedValue = value
        }
        perform(value)
        didFinish()
    }
}

@MainActor
private final class MonoTextFieldSubmitProbe: UIView {
    var onSubmit: (@MainActor (UITextField) -> Void)?

    private weak var attachedTextField: UITextField?
    private var isAttachmentScheduled = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBeginEditing(_:)),
            name: UITextField.textDidBeginEditingNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            detach()
        } else {
            scheduleAttachment()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scheduleAttachment()
    }

    func scheduleAttachment() {
        guard !isAttachmentScheduled else { return }
        isAttachmentScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isAttachmentScheduled = false
            self.attachToMatchingTextField()
        }
    }

    func detach() {
        attachedTextField?.removeTarget(
            self,
            action: #selector(handleReturn(_:)),
            for: .editingDidEndOnExit
        )
        attachedTextField = nil
    }

    private func attachToMatchingTextField() {
        guard let window else { return }
        if let attachedTextField,
           attachedTextField.window === window,
           matches(attachedTextField) {
            return
        }

        let candidate = window.monoDescendantTextFields
            .filter(matches)
            .max { matchScore(for: $0) < matchScore(for: $1) }
        if let candidate {
            attach(to: candidate)
        }
    }

    private func attach(to textField: UITextField) {
        guard attachedTextField !== textField else { return }
        detach()
        attachedTextField = textField
        textField.addTarget(
            self,
            action: #selector(handleReturn(_:)),
            for: .editingDidEndOnExit
        )
    }

    private func matches(_ textField: UITextField) -> Bool {
        guard let window,
              textField.window === window,
              !textField.isHidden,
              textField.alpha > 0.01 else { return false }

        let probeFrame = convert(bounds, to: window)
        let fieldFrame = textField.convert(textField.bounds, to: window)
        guard probeFrame.width > 0,
              probeFrame.height > 0,
              fieldFrame.width > 0,
              fieldFrame.height > 0 else { return false }

        let intersection = probeFrame.intersection(fieldFrame)
        guard !intersection.isNull else { return false }
        let fieldArea = fieldFrame.width * fieldFrame.height
        return intersection.width * intersection.height >= fieldArea * 0.6
    }

    private func matchScore(for textField: UITextField) -> CGFloat {
        guard let window else { return 0 }
        let probeFrame = convert(bounds, to: window)
        let fieldFrame = textField.convert(textField.bounds, to: window)
        let intersection = probeFrame.intersection(fieldFrame)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    @objc
    private func handleBeginEditing(_ notification: Notification) {
        guard let textField = notification.object as? UITextField,
              matches(textField) else { return }
        attach(to: textField)
    }

    @objc
    private func handleReturn(_ textField: UITextField) {
        onSubmit?(textField)
    }
}

private extension UIView {
    var monoDescendantTextFields: [UITextField] {
        var result: [UITextField] = []
        if let textField = self as? UITextField {
            result.append(textField)
        }
        for child in subviews {
            result.append(contentsOf: child.monoDescendantTextFields)
        }
        return result
    }
}

@MainActor
private struct MonoTextFieldSubmitBridge: UIViewRepresentable {
    let text: Binding<String>
    let perform: @MainActor (String) -> Void

    func makeUIView(context: Context) -> MonoTextFieldSubmitProbe {
        let probe = MonoTextFieldSubmitProbe()
        update(probe)
        return probe
    }

    func updateUIView(_ uiView: MonoTextFieldSubmitProbe, context: Context) {
        update(uiView)
        uiView.scheduleAttachment()
    }

    static func dismantleUIView(_ uiView: MonoTextFieldSubmitProbe, coordinator: ()) {
        uiView.detach()
    }

    private func update(_ probe: MonoTextFieldSubmitProbe) {
        probe.onSubmit = { textField in
            MonoTextInputCommitter.commit(
                text: text,
                responder: textField,
                perform: perform
            )
        }
    }
}

private struct MonoOnSubmitModifier: ViewModifier {
    let text: Binding<String>
    let perform: @MainActor (String) -> Void

    func body(content: Content) -> some View {
        content
            .onSubmit {
                MonoTextInputCommitter.commit(text: text, perform: perform)
            }
            .background {
                MonoTextFieldSubmitBridge(text: text, perform: perform)
                    .allowsHitTesting(false)
            }
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
        modifier(MonoOnSubmitModifier(text: text, perform: action))
    }
}
