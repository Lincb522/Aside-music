import SwiftUI
import QQMusicKit

enum PlatformLoginSource: String, CaseIterable, Identifiable {
    case ncm
    case qcm
    case kcm

    var id: String { rawValue }

    var title: String { rawValue.uppercased() }

    var musicSource: MusicSource {
        switch self {
        case .ncm: return .netease
        case .qcm: return .qqmusic
        case .kcm: return .kugou
        }
    }
}

struct PlatformLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = SettingsManager.shared
    @StateObject private var ncmViewModel = LoginViewModel()
    @StateObject private var qcmViewModel = QQLoginViewModel()
    @StateObject private var kcmViewModel = KCMLoginViewModel()

    @State private var selectedPlatform: PlatformLoginSource
    @State private var didFinishLogin = false

    init(initialPlatform: PlatformLoginSource = .ncm) {
        _selectedPlatform = State(initialValue: initialPlatform)
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedPageBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    if SignalStyle.isActive {
                        SignalNestedPageHeader(
                            title: String(localized: "扫码登录"),
                            eyebrow: "AUTH TERMINAL",
                            icon: .personCircle,
                            module: .accounts
                        )
                    }

                    platformPicker
                    if selectedPlatform == .qcm {
                        qcmLoginModePicker
                    }
                    qrCodePanel
                    statusRow
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 28)
                .padding(.bottom, 48)
                .iPadContentWidth(520)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(SignalStyle.isActive ? "" : "扫码登录")
        .navigationBarTitleDisplayMode(.inline)
        .monoNavigationBackButton()
        .onAppear(perform: startSelectedLogin)
        .onDisappear(perform: stopAllPolling)
        .onChange(of: selectedPlatform) { _, _ in
            didFinishLogin = false
            stopAllPolling()
            startSelectedLogin()
        }
        .onChange(of: ncmViewModel.isLoggedIn) { _, loggedIn in
            if loggedIn { finishLogin(for: .ncm) }
        }
        .onChange(of: qcmViewModel.isLoggedIn) { _, loggedIn in
            if loggedIn { finishLogin(for: .qcm) }
        }
        .onChange(of: kcmViewModel.isLoggedIn) { _, loggedIn in
            if loggedIn { finishLogin(for: .kcm) }
        }
    }

    private var platformPicker: some View {
        HStack(spacing: 8) {
            ForEach(PlatformLoginSource.allCases) { platform in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedPlatform = platform
                    }
                } label: {
                    HStack(spacing: 7) {
                        PlatformBadgeLabel(
                            text: platform.musicSource.shortName,
                            source: platform.musicSource,
                            fontSize: 9
                        )

                        Text(platform.title)
                            .font(SignalStyle.isActive ? SignalStyle.labelFont(10, weight: selectedPlatform == platform ? .bold : .medium) : .system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(
                        SignalStyle.isActive
                            ? (selectedPlatform == platform ? SignalStyle.onAccent : SignalStyle.inkSoft)
                            : (selectedPlatform == platform ? Color.monoTextPrimary : Color.monoTextSecondary)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                SignalStyle.isActive
                                    ? (selectedPlatform == platform ? SignalStyle.accent : SignalStyle.control)
                                    : (selectedPlatform == platform ? platform.musicSource.themedBadgeColor.opacity(0.14) : Color.clear)
                            )
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                .accessibilityLabel("切换到 \(platform.title) 登录")
            }
        }
        .padding(4)
        .themedPageSurface(cornerRadius: 16, elevated: false, mangaTint: MangaStyle.bubbleWhite)
    }

    private var qcmLoginModePicker: some View {
        HStack(spacing: 8) {
            qcmLoginModeButton(
                title: String(localized: "qcm_login_mode_qq"),
                type: .qq
            )
            qcmLoginModeButton(
                title: String(localized: "qcm_login_mode_wechat"),
                type: .wx
            )
        }
        .padding(4)
        .themedPageSurface(cornerRadius: 14, elevated: false, mangaTint: MangaStyle.bubbleWhite)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "qcm_login_mode"))
    }

    private func qcmLoginModeButton(title: String, type: QRLoginType) -> some View {
        let selected = qcmViewModel.qrLoginType == type
        return Button {
            guard !selected else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                qcmViewModel.switchQRType(type)
            }
        } label: {
            Text(title)
                .font(SignalStyle.isActive ? SignalStyle.labelFont(10, weight: selected ? .bold : .medium) : .system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(SignalStyle.isActive ? (selected ? SignalStyle.onAccent : SignalStyle.inkSoft) : (selected ? Color.monoTextPrimary : Color.monoTextSecondary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            SignalStyle.isActive
                                ? (selected ? SignalStyle.accent : SignalStyle.control)
                                : (selected ? MusicSource.qqmusic.themedBadgeColor.opacity(0.14) : Color.clear)
                        )
                }
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var qrCodePanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: SignalStyle.isActive ? 9 : 20, style: .continuous)
                .fill(Color.white)

            if let image = qrCodeImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(22)
            } else {
                ProgressView()
                    .tint(selectedPlatform.musicSource.themedBadgeColor)
            }

            if isQRExpired {
                RoundedRectangle(cornerRadius: SignalStyle.isActive ? 9 : 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Button(action: refreshQRCode) {
                            VStack(spacing: 10) {
                                MonoIcon(icon: .refresh, size: 24, color: .monoTextPrimary)
                                Text("刷新二维码")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.monoTextPrimary)
                            }
                            .padding(20)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
                    }
            }
        }
        .frame(width: 244, height: 244)
        .overlay {
            RoundedRectangle(cornerRadius: SignalStyle.isActive ? 9 : 20, style: .continuous)
                .stroke(SignalStyle.isActive ? SignalStyle.separator.opacity(0.78) : Color.monoSeparator.opacity(0.75), lineWidth: 0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(qrCodeAccessibilityLabel)
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            MonoStatusBeacon(
                kind: qrStatusKind,
                tint: selectedPlatform.musicSource.themedBadgeColor,
                size: 7
            )

            Text(qrStatusMessage)
                .font(SignalStyle.isActive ? SignalStyle.bodyFont(12, weight: .medium) : .system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(SignalStyle.isActive ? SignalStyle.inkSoft : Color.monoTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var qrCodeImage: UIImage? {
        switch selectedPlatform {
        case .ncm: return ncmViewModel.qrCodeImage
        case .qcm: return qcmViewModel.qrCodeImage
        case .kcm: return kcmViewModel.qrCodeImage
        }
    }

    private var qrStatusMessage: String {
        switch selectedPlatform {
        case .ncm: return ncmViewModel.qrStatusMessage
        case .qcm: return qcmViewModel.qrStatusMessage
        case .kcm: return kcmViewModel.qrStatusMessage
        }
    }

    private var isQRExpired: Bool {
        switch selectedPlatform {
        case .ncm: return ncmViewModel.isQRExpired
        case .qcm: return qcmViewModel.isQRExpired
        case .kcm: return kcmViewModel.isQRExpired
        }
    }

    private var qrStatusKind: MonoStatusKind {
        if isQRExpired { return .failed }

        let status = qrStatusMessage.lowercased()
        if status.contains("成功") || status.contains("success") {
            return .success
        }
        if status.contains("已扫码") || status.contains("scanned") || status.contains("确认") {
            return .scanned
        }
        if status.contains("拒绝") || status.contains("失败") || status.contains("异常") || status.contains("error") {
            return .failed
        }
        if qrCodeImage != nil || status.contains("加载") || status.contains("等待") || status.contains("重试") {
            return .active
        }
        return .idle
    }

    private var qrCodeAccessibilityLabel: String {
        if selectedPlatform == .qcm {
            let mode = qcmViewModel.qrLoginType == .qq
                ? String(localized: "qcm_login_mode_qq")
                : String(localized: "qcm_login_mode_wechat")
            return "\(mode)二维码"
        }
        return "\(selectedPlatform.title) 登录二维码"
    }

    private func startSelectedLogin() {
        switch selectedPlatform {
        case .ncm: ncmViewModel.startQRLogin()
        case .qcm: qcmViewModel.startQRLogin()
        case .kcm: kcmViewModel.startQRLogin()
        }
    }

    private func refreshQRCode() {
        switch selectedPlatform {
        case .ncm: ncmViewModel.refreshQR()
        case .qcm: qcmViewModel.refreshQR()
        case .kcm: kcmViewModel.refreshQR()
        }
    }

    private func stopAllPolling() {
        ncmViewModel.stopQRPolling()
        qcmViewModel.stopPolling()
        kcmViewModel.stopPolling()
    }

    private func finishLogin(for platform: PlatformLoginSource) {
        guard selectedPlatform == platform, !didFinishLogin else { return }
        didFinishLogin = true
        stopAllPolling()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        PlatformLoginView(initialPlatform: .kcm)
    }
}
