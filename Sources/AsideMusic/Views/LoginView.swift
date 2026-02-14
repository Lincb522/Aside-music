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
        .navigationBarHidden(true)
        .onChange(of: viewModel.isLoggedIn) { loggedIn in
            if loggedIn {
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
                        .background(Color.asideCardBackground)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
                Spacer()
            }
            
            VStack(spacing: 8) {
                Text("登录")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                
                Text("登录网易云音乐账号")
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
            tabButton(title: "扫码登录", icon: .qr, tab: .qr)
            tabButton(title: "手机登录", icon: .phone, tab: .phone)
        }
        .padding(4)
        .background(Color.asideCardBackground)
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
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.asideGlassOverlay)
                    )
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
                        Text("加载中...")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                }
                
                if viewModel.isQRExpired {
                    ZStack {
                        Color.asideCardBackground.opacity(0.9)
                        
                        VStack(spacing: 16) {
                            AsideIcon(icon: .refresh, size: 32, color: .asideTextPrimary)
                            Text("二维码已过期")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.asideTextPrimary)
                            
                            Button(action: { viewModel.refreshQR() }) {
                                Text("点击刷新")
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
                instructionRow(number: "1", text: "打开网易云音乐 App")
                instructionRow(number: "2", text: "点击左上角扫一扫")
                instructionRow(number: "3", text: "扫描上方二维码登录")
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
                Text("手机号")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
                
                HStack {
                    Text("+86")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                        .padding(.trailing, 8)
                    
                    Divider()
                        .frame(height: 20)
                    
                    TextField("请输入手机号", text: $viewModel.phoneNumber)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .keyboardType(.phonePad)
                        .padding(.leading, 8)
                }
                .padding(16)
                .background(Color.asideCardBackground)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("验证码")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
                
                HStack {
                    TextField("请输入验证码", text: $viewModel.captchaCode)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .keyboardType(.numberPad)
                    
                    Button(action: { viewModel.sendCaptcha() }) {
                        Text(viewModel.isCaptchaSent ? "重新发送" : "获取验证码")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(viewModel.phoneNumber.count == 11 ? .asideTextPrimary : .asideTextSecondary)
                    }
                    .disabled(viewModel.phoneNumber.count != 11)
                }
                .padding(16)
                .background(Color.asideCardBackground)
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
                    Text("登录")
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
            Text("登录即表示同意")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary)
            
            HStack(spacing: 4) {
                Text("《用户协议》")
                Text("和")
                    .foregroundColor(.asideTextSecondary)
                Text("《隐私政策》")
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(.asideTextPrimary)
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Actions
    
    private func handleLoginSuccess() {
        isAppLoggedIn = true
        
        // 触发全量数据刷新
        GlobalRefreshManager.shared.triggerLoginRefresh()
        
        // 关闭登录界面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

#Preview {
    LoginView()
}
