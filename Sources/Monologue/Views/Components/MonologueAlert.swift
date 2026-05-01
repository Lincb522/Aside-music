import SwiftUI
#if os(iOS)
import UIKit
#endif

struct MonologueAlertView: View {
    let title: String
    let message: String
    let primaryButtonTitle: String
    let secondaryButtonTitle: String?
    let primaryAction: () -> Void
    let secondaryAction: (() -> Void)?
    @Binding var isPresented: Bool
    
    var inputMode: Bool = false
    @Binding var inputText: String
    var inputPlaceholder: String = ""
    var isSecureInput: Bool = false
    var purchaseLink: String? = nil
    var inputAction: ((String) -> Void)?
    
    @ObservedObject private var settings = SettingsManager.shared
    @FocusState private var isInputFocused: Bool
    
    init(
        title: String,
        message: String,
        primaryButtonTitle: String,
        secondaryButtonTitle: String? = nil,
        primaryAction: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil,
        isPresented: Binding<Bool>,
        inputMode: Bool = false,
        inputText: Binding<String> = .constant(""),
        inputPlaceholder: String = "",
        isSecureInput: Bool = false,
        purchaseLink: String? = nil,
        inputAction: ((String) -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryButtonTitle = secondaryButtonTitle
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self._isPresented = isPresented
        self.inputMode = inputMode
        self._inputText = inputText
        self.inputPlaceholder = inputPlaceholder
        self.isSecureInput = isSecureInput
        self.purchaseLink = purchaseLink
        self.inputAction = inputAction
    }
    
    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isInputFocused = false
                }
            
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)
                        .multilineTextAlignment(.center)
                    
                    if !message.isEmpty {
                        Text(message)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                if inputMode {
                    Group {
                        if isSecureInput {
                            SecureField(inputPlaceholder, text: $inputText)
                        } else {
                            TextField(inputPlaceholder, text: $inputText)
                        }
                    }
                    .font(.system(size: 15, design: .rounded))
                    .monologueTextInputBehavior()
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.monologueAccent.opacity(isInputFocused ? 0.5 : 0.15), lineWidth: 1)
                    )
                    .focused($isInputFocused)
                    .onSubmit { handlePrimary() }
                    
                    if let link = purchaseLink, let url = URL(string: link) {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                MonologueIcon(icon: .download, size: 13, color: .monologueAccent, lineWidth: 1.4)
                                Text(NSLocalizedString("access_token_get", comment: ""))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(.monologueAccent)
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    if let secondaryTitle = secondaryButtonTitle {
                        Button(action: handleSecondary) {
                            Text(secondaryTitle)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.monologueTextPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                    }
                    
                    Button(action: handlePrimary) {
                        Text(inputMode && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSLocalizedString("common_submit", comment: "") : primaryButtonTitle)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.monologueIconForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.monologueIconBackground)
                            .cornerRadius(12)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.monologueGlassTint)
                    .monologueGlass(cornerRadius: 20)
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
            .scaleEffect(isPresented ? 1 : 0.8)
            .opacity(isPresented ? 1 : 0)
        }
        .zIndex(999)
        .transition(.opacity)
        .onAppear {
            isInputFocused = false
        }
        .onChange(of: isPresented) { _, presented in
            if !presented {
                releaseTextInputSession()
            }
        }
    }
    
    private func handlePrimary() {
        let submittedText = inputText
        releaseTextInputSession()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring()) {
                isPresented = false
            }

            if inputMode {
                inputAction?(submittedText)
            } else {
                primaryAction()
            }
        }
    }
    
    private func handleSecondary() {
        releaseTextInputSession()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring()) {
                isPresented = false
            }
            secondaryAction?()
        }
    }

    private func releaseTextInputSession() {
        isInputFocused = false
#if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }
}

extension View {
    func monologueAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        primaryButtonTitle: String,
        secondaryButtonTitle: String? = nil,
        primaryAction: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        ZStack {
            self
            
            if isPresented.wrappedValue {
                MonologueAlertView(
                    title: title,
                    message: message,
                    primaryButtonTitle: primaryButtonTitle,
                    secondaryButtonTitle: secondaryButtonTitle,
                    primaryAction: primaryAction,
                    secondaryAction: secondaryAction,
                    isPresented: isPresented
                )
            }
        }
    }
}
