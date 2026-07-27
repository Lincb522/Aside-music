import SwiftUI
import Combine

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monoSheetDismiss) private var monoSheetDismiss
    @StateObject private var viewModel = LoginViewModel()
    @ObservedObject private var settings = SettingsManager.shared
    @AppStorage("isLoggedIn") private var isAppLoggedIn = false

    @State private var didHandleLoginSuccess = false
    @State private var statusPulse = false

    private var isAside: Bool {
        GlobalThemeId.persistedOrDefault == .default
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedPageBackground()

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
                handleLoginSuccess()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didLogin)) { _ in
            // 双保险：如果 onChange 没触发，通过通知兜底。
            handleLoginSuccess()
        }
        .onAppear {
            viewModel.startQRLogin()
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

            Spacer(minLength: 20)

            asideQRBlock
                .frame(maxWidth: .infinity)

            Spacer(minLength: 20)

            asideSteps
                .padding(.horizontal, 28)

            asideFooter
                .padding(.top, 22)
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

            Text(LocalizedStringKey("login_ncm_title"))
                .font(.system(size: 29, weight: .heavy, design: .rounded))
                .foregroundColor(.monoTextPrimary)

            Text(LocalizedStringKey("login_qr_only_hint"))
                .font(.rounded(size: 13, weight: .medium))
                .foregroundColor(.monoTextSecondary.opacity(0.85))
                .padding(.top, 6)
        }
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
                        Text(LocalizedStringKey("login_loading"))
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
            .onAppear { statusPulse = true }
        }
    }

    private var asideExpiredOverlay: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                VStack(spacing: 12) {
                    MonoIcon(icon: .refresh, size: 24, color: .monoTextPrimary)

                    Text(LocalizedStringKey("qr_expired"))
                        .font(.rounded(size: 13, weight: .semibold))
                        .foregroundColor(.monoTextPrimary)

                    Button(action: { viewModel.refreshQR() }) {
                        Text(LocalizedStringKey("login_tap_refresh"))
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
        VStack(spacing: 0) {
            asideStepRow(index: "01", text: String(localized: "login_instruction_1"))
            asideStepDivider
            asideStepRow(index: "02", text: String(localized: "login_instruction_2"))
            asideStepDivider
            asideStepRow(index: "03", text: String(localized: "login_instruction_3"))
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

    private var asideFooter: some View {
        VStack(spacing: 5) {
            Text(LocalizedStringKey("login_agreement_prefix"))
                .font(.rounded(size: 11, weight: .medium))
                .foregroundColor(.monoTextSecondary.opacity(0.7))

            HStack(spacing: 4) {
                Text(LocalizedStringKey("login_user_agreement"))
                Text(LocalizedStringKey("login_and"))
                    .foregroundColor(.monoTextSecondary.opacity(0.7))
                Text(LocalizedStringKey("login_privacy_policy"))
            }
            .font(.rounded(size: 11, weight: .semibold))
            .foregroundColor(.monoTextPrimary.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 其他主题版式

    private var themedBody: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss) } label: {
                    MonoIcon(icon: .xmark, size: 14, color: loginSecondaryText)
                        .frame(width: 32, height: 32)
                        .monoGlassCircle()
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            headerView

            Spacer()

            qrLoginContent
                .padding(.horizontal, 24)

            Spacer()

            footerView
        }
        .iPadContentWidth(500)
    }

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

    private var qrLoginContent: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(SequoiaStyle.isActive ? SequoiaStyle.materialList.opacity(0.62) : (NeumorphicStyle.isActive ? Color.clear : Color.monoGlassTint))
                    .monoGlass(cornerRadius: 24)
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
                        (SequoiaStyle.isActive ? SequoiaStyle.materialFloating : Color.monoGlassTint).opacity(0.9)

                        VStack(spacing: 16) {
                            MonoIcon(icon: .refresh, size: 32, color: loginText)
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
                            .buttonStyle(MonoBouncingButtonStyle())
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
        guard !didHandleLoginSuccess else { return }
        didHandleLoginSuccess = true
        if !isAppLoggedIn {
            isAppLoggedIn = true
        }

        // 触发全量数据刷新
        GlobalRefreshManager.shared.triggerLoginRefresh()

        // 关闭登录界面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss)
        }
    }

    private var loginAccent: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        return Color.monoIconBackground
    }

    private var loginAccentText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        if NeumorphicStyle.isActive { return Color(light: .white, dark: .black) }
        return Color.monoIconForeground
    }

    private var loginText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return Color.monoTextPrimary
    }

    private var loginSecondaryText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        return Color.monoTextSecondary
    }
}

#Preview {
    LoginView()
}
