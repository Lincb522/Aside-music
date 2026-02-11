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
    
    private init() {}
    
    func show(
        title: String,
        message: String,
        primaryButtonTitle: String,
        secondaryButtonTitle: String? = nil,
        primaryAction: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil
    ) {
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
    
    func dismiss() {
        withAnimation(.spring()) {
            isPresented = false
        }
    }
}
