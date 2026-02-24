import SwiftUI

struct QRLoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    
    var body: some View {
        VStack(spacing: 10) {
            if let image = viewModel.qrCodeImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 120, height: 120)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.asideMilk)
                            .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    )
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                    .overlay(
                        Group {
                            if viewModel.isQRExpired {
                                ZStack {
                                    Color.black.opacity(0.7).cornerRadius(14)
                                    Button(action: {
                                        viewModel.refreshQR()
                                    }) {
                                        AsideIcon(icon: .refresh, size: 28, color: .white)
                                    }
                                }
                            }
                        }
                    )
            } else {
                AsideLoadingView(text: "LOADING")
                    .frame(width: 120, height: 120)
            }
            
            Text(viewModel.qrStatusMessage)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary.opacity(0.8))
        }
        .onAppear {
            viewModel.startQRLogin()
        }
    }
}

struct PhoneLoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                AsideIcon(icon: .profile, size: 16, color: .gray.opacity(0.6))
                TextField(LocalizedStringKey("phone_number"), text: $viewModel.phoneNumber)
                    .font(.system(size: 14))
                    .keyboardType(.phonePad)
                    .foregroundColor(.asideTextPrimary)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(Color.asideMilk)
                    .glassEffect(.regular, in: .rect(cornerRadius: 25))
            )
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
            
            HStack(spacing: 12) {
                AsideIcon(icon: .lock, size: 16, color: .gray.opacity(0.6))
                TextField(LocalizedStringKey("captcha"), text: $viewModel.captchaCode)
                    .font(.system(size: 14))
                    .keyboardType(.numberPad)
                    .foregroundColor(.asideTextPrimary)
                
                Button(action: {
                    withAnimation {
                        viewModel.sendCaptcha()
                    }
                }) {
                    if viewModel.isCaptchaSent {
                        Text(LocalizedStringKey("sent"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    } else {
                        AsideIcon(icon: .send, size: 20, color: .asideTextPrimary.opacity(0.8))
                            .padding(8)
                            .background(Color.asideSeparator)
                            .clipShape(Circle())
                    }
                }
                .disabled(viewModel.isCaptchaSent)
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(Color.asideMilk)
                    .glassEffect(.regular, in: .rect(cornerRadius: 25))
            )
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
            
            if let error = viewModel.loginErrorMessage {
                Text(error)
                    .foregroundColor(.red.opacity(0.8))
                    .font(.system(size: 11, weight: .medium))
                    .padding(.top, -4)
            }
            
            Button(action: {
                viewModel.loginWithPhone()
            }) {
                Text(LocalizedStringKey("login"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary.opacity(0.8))
                    .frame(minWidth: 100)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .stroke(Color.asideSeparator, lineWidth: 1)
                            .background(Capsule().fill(Color.asideMilk).glassEffect(.regular, in: .capsule))
                    )
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 40)
    }
}
