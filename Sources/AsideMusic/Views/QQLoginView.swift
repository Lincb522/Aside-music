// QQLoginView.swift
// QQ 音乐登录界面
// 支持 QR 码（QQ/微信）和手机验证码两种登录方式

import SwiftUI
import QQMusicKit

struct QQLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = QQLoginViewModel()
    
    @State private var selectedTab: LoginTab = .qr
    
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
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: viewModel.isLoggedIn) { _, loggedIn in
            if loggedIn {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
        }
        .onDisappear {
            viewModel.stopPolling()
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
                .buttonStyle(AsideBouncingButtonStyle())
                Spacer()
            }
            
            VStack(spacing: 8) {
                Text(LocalizedStringKey("qq_login_title"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                
                Text(LocalizedStringKey("qq_login_subtitle"))
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
            tabButton(title: NSLocalizedString("qq_tab_qr", comment: ""), icon: .qr, tab: .qr)
            tabButton(title: NSLocalizedString("qq_tab_phone", comment: ""), icon: .phone, tab: .phone)
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
                AsideIcon(icon: icon, size: 18, color: selectedTab == tab ? .asideIconForeground : .asideTextSecondary)
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(selectedTab == tab ? .asideIconForeground : .asideTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selectedTab == tab ? Color.asideIconBackground : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
    }
    
    // MARK: - QR Login
    
    private var qrLoginContent: some View {
        VStack(spacing: 24) {
            // QQ / 微信切换
            qrTypePicker
            
            // 二维码显示区域
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
                        Text(LocalizedStringKey("qq_qr_loading"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                }
                
                // 过期遮罩
                if viewModel.isQRExpired {
                    ZStack {
                        Color.asideGlassTint.opacity(0.9)
                        
                        VStack(spacing: 16) {
                            AsideIcon(icon: .refresh, size: 32, color: .asideTextPrimary)
                            Text(LocalizedStringKey("qq_qr_expired"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.asideTextPrimary)
                            
                            Button(action: { viewModel.refreshQR() }) {
                                Text(LocalizedStringKey("qq_qr_refresh"))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.asideIconForeground)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(Color.asideIconBackground)
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
            
            // 操作说明
            VStack(spacing: 8) {
                let appName = viewModel.qrLoginType == .qq ? "QQ" : "WeChat"
                instructionRow(number: "1", text: String(format: NSLocalizedString("qq_open_app", comment: ""), appName))
                instructionRow(number: "2", text: NSLocalizedString("qq_use_scan", comment: ""))
                instructionRow(number: "3", text: NSLocalizedString("qq_scan_qr", comment: ""))
            }
            .padding(.top, 8)
        }
        .onAppear {
            viewModel.startQRLogin()
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
                .foregroundColor(viewModel.qrLoginType == type ? .asideTextPrimary : .asideTextSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(viewModel.qrLoginType == type ? Color.asideGlassTint : Color.clear)
                        .shadow(color: viewModel.qrLoginType == type ? Color.black.opacity(0.05) : .clear, radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
    }
    
    private func instructionRow(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextSecondary)
                .frame(width: 20, height: 20)
                .background(Color.asideSeparator)
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
            // 手机号输入
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey("qq_phone_number"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
                
                HStack {
                    Text("+86")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                        .padding(.trailing, 8)
                    
                    Divider()
                        .frame(height: 20)
                    
                    TextField(NSLocalizedString("qq_phone_placeholder", comment: ""), text: $viewModel.phoneNumber)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .keyboardType(.phonePad)
                        .padding(.leading, 8)
                }
                .padding(16)
                .background(Color.asideGlassTint)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
            
            // 验证码输入
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey("qq_captcha"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
                
                HStack {
                    TextField(NSLocalizedString("qq_captcha_placeholder", comment: ""), text: $viewModel.captchaCode)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .keyboardType(.numberPad)
                    
                    Button(action: { viewModel.sendPhoneCode() }) {
                        if viewModel.isLoading && !viewModel.isCaptchaSent {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text(viewModel.isCaptchaSent ? NSLocalizedString("qq_resend", comment: "") : NSLocalizedString("qq_get_captcha", comment: ""))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(viewModel.phoneNumber.count == 11 ? .asideTextPrimary : .asideTextSecondary)
                        }
                    }
                    .disabled(viewModel.phoneNumber.count != 11 || (viewModel.isLoading && !viewModel.isCaptchaSent))
                }
                .padding(16)
                .background(Color.asideGlassTint)
                .cornerRadius(16)
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
                .foregroundColor(.asideIconForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    (viewModel.phoneNumber.count == 11 && viewModel.captchaCode.count >= 4)
                    ? Color.asideIconBackground
                    : Color.asideSeparator
                )
                .cornerRadius(16)
            }
            .disabled(viewModel.phoneNumber.count != 11 || viewModel.captchaCode.count < 4 || viewModel.isLoading)
            .buttonStyle(AsideBouncingButtonStyle())
            .padding(.top, 8)
        }
    }
}
