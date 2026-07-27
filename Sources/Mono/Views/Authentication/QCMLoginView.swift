// qcm登录界面
// 仅支持 QR 码（QQ/微信）扫码登录

import SwiftUI
import QQMusicKit

struct QQLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monoSheetDismiss) private var monoSheetDismiss
    @StateObject private var viewModel = QQLoginViewModel()
    @ObservedObject private var settings = SettingsManager.shared

    @State private var showSavedTip = false
    @State private var statusPulse = false

    private var isAside: Bool {
        GlobalThemeId.persistedOrDefault == .default
    }

    private var themeAccent: Color {
        if MangaStyle.isActive { return MangaStyle.labelYellow }
        if MujiStyle.isActive { return MujiStyle.clay }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        return Color.monoIconBackground
    }

    private var themeAccentText: Color {
        if MangaStyle.isActive { return ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.ink, dark: MangaStyle.onStrokeInk) }
        if MujiStyle.isActive { return MujiStyle.paper }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        if NeumorphicStyle.isActive { return Color(light: .white, dark: .black) }
        return Color.monoIconForeground
    }

    private var themeText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return Color.monoTextPrimary
    }

    private var themeSecondaryText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        return Color.monoTextSecondary
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            MonoSheetAwareBackground {
                ThemedPageBackground()
            }

            if isAside {
                asideBody
            } else {
                themedBody
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: viewModel.isLoggedIn) { _, loggedIn in
            if loggedIn {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss)
                }
            }
        }
        .onAppear {
            viewModel.startQRLoginIfNeeded()
        }
        .onDisappear {
            if viewModel.isLoggedIn {
                viewModel.stopPolling()
            }
        }
    }

    // MARK: - aside 版式

    private var asideBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss) } label: {
                    MonoIcon(icon: .xmark, size: 13, color: .monoTextSecondary)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.monoSeparator.opacity(0.9), lineWidth: 0.8))
                        .contentShape(Circle())
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            asideMasthead
                .padding(.horizontal, 28)
                .padding(.top, 20)

            asideChannelPicker
                .padding(.horizontal, 28)
                .padding(.top, 22)

            Spacer(minLength: 18)

            asideQRBlock
                .frame(maxWidth: .infinity)

            Spacer(minLength: 18)

            asideSteps
                .padding(.horizontal, 28)
                .padding(.bottom, 34)
        }
        .iPadContentWidth(520)
    }

    private var asideMasthead: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.monoAccent)
                    .frame(width: 18, height: 3)

                Text("SIGN IN")
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .tracking(2.4)
                    .foregroundColor(.monoTextSecondary.opacity(0.72))
                    .fixedSize()

                Rectangle()
                    .fill(Color.monoSeparator.opacity(0.5))
                    .frame(height: 0.5)
            }
            .padding(.bottom, 18)

            Text(LocalizedStringKey("qq_login_aside_title"))
                .font(.system(size: 29, weight: .heavy, design: .rounded))
                .foregroundColor(.monoTextPrimary)

            Text(LocalizedStringKey("qq_login_subtitle"))
                .font(.rounded(size: 13, weight: .medium))
                .foregroundColor(.monoTextSecondary.opacity(0.85))
                .padding(.top, 6)
        }
    }

    private var asideChannelPicker: some View {
        HStack(spacing: 24) {
            asideChannelButton(title: NSLocalizedString("qq_qr_qq", comment: ""), type: .qq)
            asideChannelButton(title: NSLocalizedString("qq_qr_wx", comment: ""), type: .wx)
            Spacer(minLength: 0)
        }
    }

    private func asideChannelButton(title: String, type: QRLoginType) -> some View {
        let selected = viewModel.qrLoginType == type
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                viewModel.switchQRType(type)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.rounded(size: 14, weight: selected ? .heavy : .medium))
                    .foregroundColor(selected ? .monoTextPrimary : .monoTextSecondary.opacity(0.75))

                Capsule()
                    .fill(Color.monoAccent)
                    .frame(width: 16, height: 2.5)
                    .opacity(selected ? 1 : 0)
            }
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
    }

    private var asideQRBlock: some View {
        VStack(spacing: 18) {
            ZStack {
                if let qrImage = viewModel.qrCodeImage {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 186, height: 186)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    VStack(spacing: 14) {
                        ProgressView()
                        Text(LocalizedStringKey("qq_qr_loading"))
                            .font(.rounded(size: 12.5, weight: .medium))
                            .foregroundColor(Color.black.opacity(0.45))
                    }
                    .frame(width: 186, height: 186)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.10), radius: 26, x: 0, y: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.monoTextPrimary.opacity(0.10), lineWidth: 0.8)
            )
            .overlay {
                if viewModel.isQRExpired {
                    asideExpiredOverlay
                }
            }

            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color.monoAccent)
                        .frame(width: 5, height: 5)
                        .opacity(statusPulse ? 1 : 0.25)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: statusPulse)

                    Text(viewModel.qrStatusMessage)
                        .font(.rounded(size: 12.5, weight: .semibold))
                        .foregroundColor(.monoTextSecondary)
                        .multilineTextAlignment(.center)
                }

                if viewModel.qrCodeImage != nil && !viewModel.isQRExpired {
                    Button(action: { saveQRToAlbum() }) {
                        Text(showSavedTip ? String(localized: "qq_qr_saved") : String(localized: "qq_qr_save"))
                            .font(.rounded(size: 11.5, weight: .semibold))
                            .tracking(0.4)
                            .foregroundColor(.monoTextPrimary.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .overlay(Capsule().stroke(Color.monoSeparator, lineWidth: 0.8))
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                }
            }
            .onAppear { statusPulse = true }
        }
    }

    private var asideExpiredOverlay: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                VStack(spacing: 12) {
                    MonoIcon(icon: .refresh, size: 24, color: .monoTextPrimary)

                    Text(LocalizedStringKey("qq_qr_expired"))
                        .font(.rounded(size: 13, weight: .semibold))
                        .foregroundColor(.monoTextPrimary)

                    Button(action: { viewModel.refreshQR() }) {
                        Text(LocalizedStringKey("qq_qr_refresh"))
                            .font(.rounded(size: 12.5, weight: .semibold))
                            .tracking(0.4)
                            .foregroundColor(.monoTextPrimary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .overlay(Capsule().stroke(Color.monoTextPrimary.opacity(0.35), lineWidth: 0.8))
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var asideSteps: some View {
        let appName = viewModel.qrLoginType == .qq ? "QCM" : "WeChat"
        return VStack(spacing: 0) {
            asideStepRow(index: "01", text: String(format: NSLocalizedString("qq_open_app", comment: ""), appName))
            asideStepDivider
            asideStepRow(index: "02", text: NSLocalizedString("qq_use_scan", comment: ""))
            asideStepDivider
            asideStepRow(index: "03", text: NSLocalizedString("qq_scan_qr", comment: ""))
        }
    }

    private var asideStepDivider: some View {
        Rectangle()
            .fill(Color.monoSeparator.opacity(0.45))
            .frame(height: 0.5)
    }

    private func asideStepRow(index: String, text: String) -> some View {
        HStack(spacing: 14) {
            Text(index)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .foregroundColor(.monoAccent)
                .frame(width: 24, alignment: .leading)

            Text(text)
                .font(.rounded(size: 13, weight: .medium))
                .foregroundColor(.monoTextPrimary.opacity(0.82))

            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }

    // MARK: - 其他主题版式

    private var themedBody: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss) } label: {
                    MonoIcon(icon: .xmark, size: 14, color: themeSecondaryText)
                        .frame(width: 32, height: 32)
                        .monoGlassCircle()
                }
                Spacer()
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 8)

            headerView
            Spacer()
            qrLoginContent
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .iPadContentWidth(500)
            Spacer()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(LocalizedStringKey("qq_login_subtitle"))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(themeSecondaryText)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
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
                            .foregroundColor(themeSecondaryText)
                    }
                }

                // 过期遮罩
                if viewModel.isQRExpired {
                    ZStack {
                        (SequoiaStyle.isActive ? SequoiaStyle.materialFloating : Color.monoGlassTint).opacity(0.9)

                        VStack(spacing: 16) {
                            MonoIcon(icon: .refresh, size: 32, color: themeText)
                            Text(LocalizedStringKey("qq_qr_expired"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(themeText)

                            Button(action: { viewModel.refreshQR() }) {
                                Text(LocalizedStringKey("qq_qr_refresh"))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(themeAccentText)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(themeAccent)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(MonoBouncingButtonStyle())
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
                    .foregroundColor(themeSecondaryText)
                    .multilineTextAlignment(.center)

                if viewModel.qrCodeImage != nil && !viewModel.isQRExpired {
                    Button(action: { saveQRToAlbum() }) {
                        HStack(spacing: 4) {
                            MonoIcon(icon: .download, size: 12, color: themeAccentText)
                            Text(LocalizedStringKey("qq_qr_save"))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(themeAccentText)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(themeAccent)
                        .cornerRadius(12)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
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
                .foregroundColor(viewModel.qrLoginType == type ? themeText : themeSecondaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(viewModel.qrLoginType == type ? loginSelectedFill : Color.clear)
                        .shadow(color: viewModel.qrLoginType == type ? Color.black.opacity(0.05) : .clear, radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(SequoiaStyle.isActive ? themeAccentText : themeSecondaryText)
                .frame(width: 20, height: 20)
                .background(SequoiaStyle.isActive ? themeAccent : Color.monoSeparator)
                .cornerRadius(10)

            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(themeSecondaryText)

            Spacer()
        }
    }

    private func saveQRToAlbum() {
        guard let image = viewModel.qrCodeImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        showSavedTip = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSavedTip = false
        }
    }

    private var loginSelectedFill: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.selectedWash }
        return NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monoGlassTint
    }
}
