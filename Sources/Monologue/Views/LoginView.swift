import SwiftUI
import Combine

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LoginViewModel()
    @ObservedObject private var settings = SettingsManager.shared
    @AppStorage("isLoggedIn") private var isAppLoggedIn = false
    
    @State private var selectedTab: LoginTab = .qr
    @State private var isLoading = false
    
    enum LoginTab {
        case qr
        case phone
    }
    
    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedPageBackground()
            
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        MonologueIcon(icon: .xmark, size: 14, color: loginSecondaryText)
                            .frame(width: 32, height: 32)
                            .monologueGlassCircle()
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                headerView
                
                Spacer()
                
                loginContent
                
                Spacer()
                
                footerView
            }
            .iPadContentWidth(500)
        }
        .navigationBarBackButtonHidden(true)
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
            VStack(spacing: 8) {
                Text(LocalizedStringKey("login_subtitle"))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(loginSecondaryText)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Login Content
    
    private var loginContent: some View {
        VStack(spacing: 32) {
            qrLoginContent
        }
        .padding(.horizontal, 24)
    }
    
    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            tabButton(title: String(localized: "scan_qr"), icon: .qr, tab: .qr)
            tabButton(title: String(localized: "phone_login"), icon: .phone, tab: .phone)
        }
        .padding(4)
        .themedPageSurface(cornerRadius: 16, elevated: false)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    private func tabButton(title: String, icon: MonologueIcon.IconType, tab: LoginTab) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
                if tab == .qr {
                    viewModel.startQRLogin()
                }
            }
        }) {
            HStack(spacing: 8) {
                MonologueIcon(icon: icon, size: 18, color: selectedTab == tab ? loginAccentText : loginSecondaryText)
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(selectedTab == tab ? loginAccentText : loginSecondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selectedTab == tab ? loginAccent : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
    }
    
    // MARK: - QR Login
    
    private var qrLoginContent: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(SequoiaStyle.isActive ? SequoiaStyle.materialList.opacity(0.62) : (NeumorphicStyle.isActive ? Color.clear : Color.monologueGlassTint))
                    .monologueGlass(cornerRadius: 24)
                    .shadow(color: Color.black.opacity(SequoiaStyle.isActive ? 0.05 : 0.08), radius: SequoiaStyle.isActive ? 14 : 20, x: 0, y: 8)
                
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
                            .foregroundColor(loginSecondaryText)
                    }
                }
                
                if viewModel.isQRExpired {
                    ZStack {
                        (SequoiaStyle.isActive ? SequoiaStyle.materialFloating : Color.monologueGlassTint).opacity(0.9)
                        
                        VStack(spacing: 16) {
                            MonologueIcon(icon: .refresh, size: 32, color: loginText)
                            Text(LocalizedStringKey("qr_expired"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(loginText)
                            
                            Button(action: { viewModel.refreshQR() }) {
                                Text(LocalizedStringKey("login_tap_refresh"))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(loginAccentText)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(loginAccent)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(MonologueBouncingButtonStyle())
                        }
                    }
                    .cornerRadius(24)
                }
            }
            .frame(width: 240, height: 240)
            .themedOnlyPageSurface(cornerRadius: 24, elevated: true, mangaTint: MangaStyle.bubbleWhite)
            
            Text(viewModel.qrStatusMessage)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(loginSecondaryText)
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
                .foregroundColor(loginAccentText)
                .frame(width: 20, height: 20)
                .background(loginAccent.opacity(SequoiaStyle.isActive ? 0.92 : 0.2))
                .cornerRadius(10)
            
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(loginSecondaryText)
            
            Spacer()
        }
    }
    
    // MARK: - Phone Login
    
    private var phoneLoginContent: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey("phone_number"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(loginSecondaryText)
                
                HStack {
                    Text("+86")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(loginText)
                        .padding(.trailing, 8)
                    
                    Divider()
                        .frame(height: 20)
                    
                    TextField(String(localized: "login_phone_placeholder"), text: $viewModel.phoneNumber)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .monologueTextInputBehavior()
                        .keyboardType(.phonePad)
                        .padding(.leading, 8)
                }
                .padding(16)
                .themedPageSurface(cornerRadius: 16, elevated: false)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey("captcha"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(loginSecondaryText)
                
                HStack {
                    TextField(String(localized: "login_captcha_placeholder"), text: $viewModel.captchaCode)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .monologueTextInputBehavior()
                        .keyboardType(.numberPad)
                    
                    Button(action: { viewModel.sendCaptcha() }) {
                        Group {
                            if viewModel.captchaCooldown > 0 {
                                Text("\(viewModel.captchaCooldown)s")
                            } else {
                                Text(viewModel.isCaptchaSent ? String(localized: "login_resend") : String(localized: "get_captcha"))
                            }
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(viewModel.phoneNumber.count == 11 && viewModel.captchaCooldown == 0 ? loginText : loginSecondaryText)
                    }
                    .disabled(viewModel.phoneNumber.count != 11 || viewModel.captchaCooldown > 0)
                }
                .padding(16)
                .themedPageSurface(cornerRadius: 16, elevated: false)
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
                .foregroundColor(loginAccentText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    (viewModel.phoneNumber.count == 11 && viewModel.captchaCode.count >= 4)
                    ? loginAccent
                    : (SequoiaStyle.isActive ? SequoiaStyle.materialPressed : Color.gray.opacity(0.3))
                )
                .cornerRadius(16)
            }
            .disabled(viewModel.phoneNumber.count != 11 || viewModel.captchaCode.count < 4)
            .buttonStyle(MonologueBouncingButtonStyle())
            .padding(.top, 8)
        }
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        VStack(spacing: 8) {
            Text(LocalizedStringKey("login_agreement_prefix"))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(loginSecondaryText)
            
            HStack(spacing: 4) {
                Text(LocalizedStringKey("login_user_agreement"))
                Text(LocalizedStringKey("login_and"))
                    .foregroundColor(loginSecondaryText)
                Text(LocalizedStringKey("login_privacy_policy"))
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(loginText)
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

    private var loginAccent: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        return Color.monologueIconBackground
    }

    private var loginAccentText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        if NeumorphicStyle.isActive { return Color(light: .white, dark: .black) }
        return Color.monologueIconForeground
    }

    private var loginText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return Color.monologueTextPrimary
    }

    private var loginSecondaryText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        return Color.monologueTextSecondary
    }
}

#Preview {
    LoginView()
}
