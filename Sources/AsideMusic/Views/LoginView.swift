import SwiftUI
import Combine

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LoginViewModel()
    @AppStorage("isLoggedIn") private var isAppLoggedIn = false
    
    @State private var selectedTab: LoginTab = .qr
    @State private var isLoading = false
    
    enum LoginTab {
        case qr
        case phone
    }
    
    var body: some View {
        ZStack {
            AsideBackground()
            
            VStack(spacing: 0) {
                headerView
                
                Spacer()
                
                loginContent
                
                Spacer()
                
                footerView
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: viewModel.isLoggedIn) { _, loggedIn in
            if loggedIn {
                handleLoginSuccess()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didLogin)) { _ in
            // 双保险：如果 onChange 没触发，通过通知兜底
            if !isAppLoggedIn {
                handleLoginSuccess()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: { dismiss() }) {
                    AsideIcon(icon: .back, size: 20, color: .asideTextPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.asideGlassTint)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
                Spacer()
            }
            
            VStack(spacing: 8) {
                Text(LocalizedStringKey("login"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                
                Text(LocalizedStringKey("login_subtitle"))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }
            .padding(.top, 20)
        }
        .padding(.horizontal, 24)
        .padding(.top, DeviceLayout.headerTopPadding)
    }
    
    // MARK: - Login Content
    
    private var loginContent: some View {
        VStack(spacing: 32) {
            tabSwitcher
            
            if selectedTab == .qr {
                qrLoginContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                phoneLoginContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            tabButton(title: String(localized: "scan_qr"), icon: .qr, tab: .qr)
            tabButton(title: String(localized: "phone_login"), icon: .phone, tab: .phone)
        }
        .padding(4)
        .background(Color.asideGlassTint)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    private func tabButton(title: String, icon: AsideIcon.IconType, tab: LoginTab) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
                if tab == .qr {
                    viewModel.startQRLogin()
                }
            }
        }) {
            HStack(spacing: 8) {
                AsideIcon(icon: icon, size: 18, color: selectedTab == tab ? .white : .asideTextSecondary)
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(selectedTab == tab ? .white : .asideTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selectedTab == tab ? Color.black : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
    }
    
    // MARK: - QR Login
    
    private var qrLoginContent: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.asideGlassTint)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
                
                if let qrImage = viewModel.qrCodeImage {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .cornerRadius(12)
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(LocalizedStringKey("login_loading"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                }
                
                if viewModel.isQRExpired {
                    ZStack {
                        Color.asideGlassTint.opacity(0.9)
                        
                        VStack(spacing: 16) {
                            AsideIcon(icon: .refresh, size: 32, color: .asideTextPrimary)
                            Text(LocalizedStringKey("qr_expired"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.asideTextPrimary)
                            
                            Button(action: { viewModel.refreshQR() }) {
                                Text(LocalizedStringKey("login_tap_refresh"))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(Color.black)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(AsideBouncingButtonStyle())
                        }
                    }
                    .cornerRadius(24)
                }
            }
            .frame(width: 240, height: 240)
            
            Text(viewModel.qrStatusMessage)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 8) {
                instructionRow(number: "1", text: String(localized: "login_instruction_1"))
                instructionRow(number: "2", text: String(localized: "login_instruction_2"))
                instructionRow(number: "3", text: String(localized: "login_instruction_3"))
            }
            .padding(.top, 8)
        }
        .onAppear {
            viewModel.startQRLogin()
        }
    }
    
    private func instructionRow(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.black.opacity(0.2))
                .cornerRadius(10)
            
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary)
            
            Spacer()
        }
    }
    
    // MARK: - Phone Login
    
    private var phoneLoginContent: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey("phone_number"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
                
                HStack {
                    Text("+86")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                        .padding(.trailing, 8)
                    
                    Divider()
                        .frame(height: 20)
                    
                    TextField(String(localized: "login_phone_placeholder"), text: $viewModel.phoneNumber)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .keyboardType(.phonePad)
                        .padding(.leading, 8)
                }
                .padding(16)
                .background(Color.asideGlassTint)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey("captcha"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
                
                HStack {
                    TextField(String(localized: "login_captcha_placeholder"), text: $viewModel.captchaCode)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .keyboardType(.numberPad)
                    
                    Button(action: { viewModel.sendCaptcha() }) {
                        Text(viewModel.isCaptchaSent ? String(localized: "login_resend") : String(localized: "get_captcha"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(viewModel.phoneNumber.count == 11 ? .asideTextPrimary : .asideTextSecondary)
                    }
                    .disabled(viewModel.phoneNumber.count != 11)
                }
                .padding(16)
                .background(Color.asideGlassTint)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
            
            if let error = viewModel.loginErrorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.red)
            }
            
            Button(action: { viewModel.loginWithPhone() }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(LocalizedStringKey("login"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    (viewModel.phoneNumber.count == 11 && viewModel.captchaCode.count >= 4)
                    ? Color.black
                    : Color.gray.opacity(0.3)
                )
                .cornerRadius(16)
            }
            .disabled(viewModel.phoneNumber.count != 11 || viewModel.captchaCode.count < 4)
            .buttonStyle(AsideBouncingButtonStyle())
            .padding(.top, 8)
        }
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        VStack(spacing: 8) {
            Text(LocalizedStringKey("login_agreement_prefix"))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary)
            
            HStack(spacing: 4) {
                Text(LocalizedStringKey("login_user_agreement"))
                Text(LocalizedStringKey("login_and"))
                    .foregroundColor(.asideTextSecondary)
                Text(LocalizedStringKey("login_privacy_policy"))
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(.asideTextPrimary)
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Actions
    
    private func handleLoginSuccess() {
        guard !isAppLoggedIn else { return }
        isAppLoggedIn = true
        
        // 触发全量数据刷新
        GlobalRefreshManager.shared.triggerLoginRefresh()
        
        // 关闭登录界面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dismiss()
        }
    }
}

#Preview {
    LoginView()
}
