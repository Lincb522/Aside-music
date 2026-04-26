// QQLoginView.swift
// qcm登录界面
// 支持 QR 码（QQ/微信）和手机验证码两种登录方式

import SwiftUI
import QQMusicKit

struct QQLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    @StateObject private var viewModel = QQLoginViewModel()
    
    @State private var selectedTab: LoginTab = .qr
    
    enum LoginTab {
        case qr
        case phone
    }

    private var themeAccent: Color {
        MangaStyle.isActive ? MangaStyle.labelYellow : (MujiStyle.isActive ? MujiStyle.clay : Color.monologueIconBackground)
    }

    private var themeAccentText: Color {
        MangaStyle.isActive ? MangaStyle.ink : (MujiStyle.isActive ? MujiStyle.paper : Color.monologueIconForeground)
    }
    
    var body: some View {
        ZStack {
            MonologueSheetAwareBackground {
                ThemedPageBackground()
            }
            
            VStack(spacing: 0) {
                HStack {
                    Button { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) } label: {
                        MonologueIcon(icon: .xmark, size: 14, color: .monologueTextSecondary)
                            .frame(width: 32, height: 32)
                            .monologueGlassCircle()
                    }
                    Spacer()
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 8)
                
                headerView
                Spacer()
                loginContent
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: viewModel.isLoggedIn) { _, loggedIn in
            if loggedIn {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
                }
            }
        }
        .onDisappear {
            if viewModel.isLoggedIn {
                viewModel.stopPolling()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(LocalizedStringKey("qq_login_subtitle"))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
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
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .iPadContentWidth(500)
    }
    
    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            tabButton(title: NSLocalizedString("qq_tab_qr", comment: ""), icon: .qr, tab: .qr)
            tabButton(title: NSLocalizedString("qq_tab_phone", comment: ""), icon: .phone, tab: .phone)
        }
        .padding(4)
        .themedPageSurface(cornerRadius: MangaStyle.isActive ? 18 : 16, elevated: false)
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
                MonologueIcon(icon: icon, size: 18, color: selectedTab == tab ? themeAccentText : .monologueTextSecondary)
                Text(title)
                    .font(MangaStyle.isActive ? MangaStyle.labelFont(13, weight: .black) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .medium) : .system(size: 14, weight: .semibold, design: .rounded)))
                    .foregroundColor(selectedTab == tab ? themeAccentText : .monologueTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selectedTab == tab ? themeAccent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: MangaStyle.isActive ? 14 : 12, style: .continuous))
            .overlay {
                if MangaStyle.isActive && selectedTab == tab {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                }
            }
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
    }
    
    // MARK: - QR Login
    
    private var qrLoginContent: some View {
        VStack(spacing: 24) {
            // QQ / 微信切换
            qrTypePicker
            
            // 二维码显示区域
            ZStack {
                if let qrImage = viewModel.qrCodeImage {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: DeviceLayout.isPad ? 220 : 180, height: DeviceLayout.isPad ? 220 : 180)
                        .cornerRadius(12)
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(LocalizedStringKey("qq_qr_loading"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                }
                
                // 过期遮罩
                if viewModel.isQRExpired {
                    ZStack {
                        Color.monologueGlassTint.opacity(0.9)
                        
                        VStack(spacing: 16) {
                            MonologueIcon(icon: .refresh, size: 32, color: .monologueTextPrimary)
                            Text(LocalizedStringKey("qq_qr_expired"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.monologueTextPrimary)
                            
                            Button(action: { viewModel.refreshQR() }) {
                                Text(LocalizedStringKey("qq_qr_refresh"))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(themeAccentText)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(themeAccent)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(MonologueBouncingButtonStyle())
                        }
                    }
                    .cornerRadius(24)
                }
            }
            .frame(width: DeviceLayout.isPad ? 300 : 240, height: DeviceLayout.isPad ? 300 : 240)
            .themedPageSurface(cornerRadius: MangaStyle.isActive ? 22 : 24, elevated: true, mangaTint: MangaStyle.bubbleWhite)
            
            HStack(spacing: 16) {
                Text(viewModel.qrStatusMessage)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
                    .multilineTextAlignment(.center)
                
                if viewModel.qrCodeImage != nil && !viewModel.isQRExpired {
                    Button(action: { saveQRToAlbum() }) {
                        HStack(spacing: 4) {
                            MonologueIcon(icon: .download, size: 12, color: themeAccentText)
                            Text("保存")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(themeAccentText)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(themeAccent)
                        .cornerRadius(12)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                }
            }
            
            // 操作说明
            VStack(spacing: 8) {
                let appName = viewModel.qrLoginType == .qq ? "QCM" : "WeChat"
                instructionRow(number: "1", text: String(format: NSLocalizedString("qq_open_app", comment: ""), appName))
                instructionRow(number: "2", text: NSLocalizedString("qq_use_scan", comment: ""))
                instructionRow(number: "3", text: NSLocalizedString("qq_scan_qr", comment: ""))
            }
            .padding(.top, 8)
        }
        .onAppear {
            viewModel.startQRLoginIfNeeded()
        }
    }
    
    private var qrTypePicker: some View {
        HStack(spacing: 12) {
            qrTypeButton(title: NSLocalizedString("qq_qr_qq", comment: ""), type: .qq)
            qrTypeButton(title: NSLocalizedString("qq_qr_wx", comment: ""), type: .wx)
        }
    }
    
    private func qrTypeButton(title: String, type: QRLoginType) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.switchQRType(type)
            }
        }) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(viewModel.qrLoginType == type ? .monologueTextPrimary : .monologueTextSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(viewModel.qrLoginType == type ? Color.monologueGlassTint : Color.clear)
                        .shadow(color: viewModel.qrLoginType == type ? Color.black.opacity(0.05) : .clear, radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
    }
    
    private func instructionRow(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
                .frame(width: 20, height: 20)
                .background(Color.monologueSeparator)
                .cornerRadius(10)
            
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
            
            Spacer()
        }
    }
    
    @State private var showSavedTip = false
    
    private func saveQRToAlbum() {
        guard let image = viewModel.qrCodeImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        showSavedTip = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSavedTip = false
        }
    }
    
    // MARK: - Phone Login
    
    private var phoneLoginContent: some View {
        VStack(spacing: 24) {
            // 手机号输入
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey("qq_phone_number"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
                
                HStack {
                    Text("+86")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)
                        .padding(.trailing, 8)
                    
                    Divider()
                        .frame(height: 20)
                    
                    TextField(NSLocalizedString("qq_phone_placeholder", comment: ""), text: $viewModel.phoneNumber)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .monologueTextInputBehavior()
                        .keyboardType(.phonePad)
                        .padding(.leading, 8)
                }
                .padding(16)
                .themedPageSurface(cornerRadius: 16, elevated: false)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
            
            // 验证码输入
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey("qq_captcha"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
                
                HStack {
                    TextField(NSLocalizedString("qq_captcha_placeholder", comment: ""), text: $viewModel.captchaCode)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .monologueTextInputBehavior()
                        .keyboardType(.numberPad)
                    
                    Button(action: { viewModel.sendPhoneCode() }) {
                        if viewModel.isLoading && !viewModel.isCaptchaSent {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text(viewModel.isCaptchaSent ? NSLocalizedString("qq_resend", comment: "") : NSLocalizedString("qq_get_captcha", comment: ""))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(viewModel.phoneNumber.count == 11 ? .monologueTextPrimary : .monologueTextSecondary)
                        }
                    }
                    .disabled(viewModel.phoneNumber.count != 11 || (viewModel.isLoading && !viewModel.isCaptchaSent))
                }
                .padding(16)
                .themedPageSurface(cornerRadius: 16, elevated: false)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
            
            // 错误信息
            if let error = viewModel.phoneErrorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.red)
            }
            
            // 登录按钮
            Button(action: { viewModel.loginWithPhone() }) {
                HStack {
                    if viewModel.isLoading && viewModel.isCaptchaSent {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(LocalizedStringKey("qq_login_btn"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(themeAccentText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    (viewModel.phoneNumber.count == 11 && viewModel.captchaCode.count >= 4)
                    ? themeAccent
                    : Color.monologueSeparator
                )
                .cornerRadius(16)
            }
            .disabled(viewModel.phoneNumber.count != 11 || viewModel.captchaCode.count < 4 || viewModel.isLoading)
            .buttonStyle(MonologueBouncingButtonStyle())
            .padding(.top, 8)
        }
    }
}
