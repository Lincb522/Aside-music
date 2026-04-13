import SwiftUI
import Combine

@MainActor
class AlertManager: ObservableObject {
    static let shared = AlertManager()
    
    @Published var isPresented = false
    @Published var title = ""
    @Published var message = ""
    @Published var primaryButtonTitle = ""
    @Published var secondaryButtonTitle: String? = nil
    @Published var primaryAction: (() -> Void)?
    @Published var secondaryAction: (() -> Void)?
    
    @Published var inputMode = false
    @Published var inputText = ""
    @Published var inputPlaceholder = ""
    @Published var isSecureInput = false
    @Published var purchaseLink: String? = nil
    var inputAction: ((String) -> Void)?
    
    private init() {}
    
    func show(
        title: String,
        message: String,
        primaryButtonTitle: String,
        secondaryButtonTitle: String? = nil,
        primaryAction: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil
    ) {
        resetInput()
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryButtonTitle = secondaryButtonTitle
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        withAnimation(.spring()) {
            self.isPresented = true
        }
    }
    
    func showInput(
        title: String,
        message: String,
        placeholder: String = "",
        isSecure: Bool = false,
        primaryButtonTitle: String,
        secondaryButtonTitle: String? = nil,
        purchaseLink: String? = nil,
        onConfirm: @escaping (String) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryButtonTitle = secondaryButtonTitle
        self.inputMode = true
        self.inputText = ""
        self.inputPlaceholder = placeholder
        self.isSecureInput = isSecure
        self.purchaseLink = purchaseLink
        self.inputAction = onConfirm
        self.primaryAction = nil
        self.secondaryAction = onCancel
        withAnimation(.spring()) {
            self.isPresented = true
        }
    }
    
    func dismiss() {
        withAnimation(.spring()) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.resetInput()
        }
    }
    
    private func resetInput() {
        inputMode = false
        inputText = ""
        inputPlaceholder = ""
        isSecureInput = false
        purchaseLink = nil
        inputAction = nil
    }
}

// MARK: - Window-level Alert Overlay

@MainActor
class AlertWindow {
    static let shared = AlertWindow()
    private var window: PassthroughWindow?
    private var cancellable: AnyCancellable?
    
    private init() {}
    
    func setup() {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return }
        
        let win = PassthroughWindow(windowScene: scene)
        win.windowLevel = .alert + 2
        win.backgroundColor = .clear
        win.isHidden = false
        
        let hostingController = UIHostingController(rootView: AlertWindowContent())
        hostingController.view.backgroundColor = .clear
        win.rootViewController = hostingController
        
        self.window = win
        
        cancellable = AlertManager.shared.$isPresented
            .receive(on: RunLoop.main)
            .sink { [weak win] isPresented in
                win?.alertActive = isPresented
            }
        win.alertActive = AlertManager.shared.isPresented
    }
}

private class PassthroughWindow: UIWindow {
    var alertActive = false
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard alertActive else { return nil }
        return super.hitTest(point, with: event)
    }
}

private struct AlertWindowContent: View {
    @ObservedObject private var alertManager = AlertManager.shared
    
    var body: some View {
        ZStack {
            if alertManager.isPresented {
                MonologueAlertView(
                    title: alertManager.title,
                    message: alertManager.message,
                    primaryButtonTitle: alertManager.primaryButtonTitle,
                    secondaryButtonTitle: alertManager.secondaryButtonTitle,
                    primaryAction: { alertManager.primaryAction?() },
                    secondaryAction: {
                        alertManager.secondaryAction?()
                        alertManager.dismiss()
                    },
                    isPresented: $alertManager.isPresented,
                    inputMode: alertManager.inputMode,
                    inputText: $alertManager.inputText,
                    inputPlaceholder: alertManager.inputPlaceholder,
                    isSecureInput: alertManager.isSecureInput,
                    purchaseLink: alertManager.purchaseLink,
                    inputAction: { text in
                        alertManager.inputAction?(text)
                        alertManager.dismiss()
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
