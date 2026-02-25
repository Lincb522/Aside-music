import SwiftUI

struct AsideAlertView: View {
    let title: String
    let message: String
    let primaryButtonTitle: String
    let secondaryButtonTitle: String?
    let primaryAction: () -> Void
    let secondaryAction: (() -> Void)?
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Dimmed Background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                }
            
            // Alert Content
            VStack(spacing: 24) {
                // Text
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text(message)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // Buttons
                HStack(spacing: 12) {
                    if let secondaryTitle = secondaryButtonTitle {
                        Button(action: {
                            withAnimation(.spring()) {
                                isPresented = false
                                secondaryAction?()
                            }
                        }) {
                            Text(secondaryTitle)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.asideTextPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                    }
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            isPresented = false
                            primaryAction()
                        }
                    }) {
                        Text(primaryButtonTitle)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.asideIconForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.asideIconBackground)
                            .cornerRadius(12)
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.asideGlassTint)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
            .scaleEffect(isPresented ? 1 : 0.8)
            .opacity(isPresented ? 1 : 0)
        }
        .zIndex(999)
        .transition(.opacity)
    }
}

extension View {
    func asideAlert(
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
                AsideAlertView(
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
