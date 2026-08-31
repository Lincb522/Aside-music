import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

@MainActor
struct NCMVIPAccountSwitchingView: View {
    @State private var accounts: [NCMVIPPoolAccount] = []
    @State private var isLoading = false
    @State private var processingID: String?
    @State private var qrSession: NCMVIPQRSession?
    @State private var qrImage: UIImage?
    @State private var qrStateText: String?
    @State private var errorMessage: String?
    @State private var isShowingError = false

    var body: some View {
        ZStack {
            DeveloperDiagnosticBackdrop()

            ScrollView {
                VStack(spacing: SettingsPageLayout.deepSectionSpacing) {
                    DeveloperDiagnosticHeader(
                        title: String(localized: "ncm_vip_pool_title"),
                        status: String.localizedStringWithFormat(
                            String(localized: "ncm_vip_pool_account_count"),
                            accounts.count
                        ),
                        icon: .personCircle,
                        tint: .red
                    )

                    qrSection
                    accountSections

                    FloatingBarBottomSpacer()
                }
                .padding(.horizontal, DeviceLayout.settingsSectionHorizontalPadding)
                .padding(.bottom, 44)
                .iPadContentWidth(SettingsPageLayout.contentWidth)
            }
            .scrollIndicators(.hidden)
            .refreshable { await load() }
        }
        .developerDiagnosticPageChrome()
        .task { await load() }
        .task(id: qrSession?.sessionId) {
            guard let sessionID = qrSession?.sessionId else { return }
            await pollQRSession(sessionID)
        }
        .alert(String(localized: "ncm_vip_pool_operation_failed"), isPresented: $isShowingError) {
            Button(String(localized: "common_ok"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var qrSection: some View {
        SettingsSection(title: String(localized: "ncm_vip_pool_add_section")) {
            if let qrImage {
                VStack(spacing: 14) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .accessibilityLabel(String(localized: "ncm_vip_pool_qr_accessibility"))

                    Text(qrStateText ?? String(localized: "ncm_vip_pool_qr_waiting"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            } else {
                Button(action: startQRLogin) {
                    HStack(spacing: 12) {
                        MonoIcon(icon: .qr, size: 17, color: .red)
                            .frame(width: 34, height: 34)
                            .background(Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                        Text(String(localized: "ncm_vip_pool_add_account"))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Spacer()

                        if processingID == "qr" {
                            ProgressView()
                                .tint(.white)
                        } else {
                            MonoIcon(icon: .chevronRight, size: 12, color: .white.opacity(0.35))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(processingID != nil)
            }
        }
    }

    @ViewBuilder
    private var accountSections: some View {
        if isLoading && accounts.isEmpty {
            DeveloperSwitchingStateSection(
                title: String(localized: "ncm_vip_pool_accounts_section"),
                text: String(localized: "ncm_vip_pool_loading")
            )
        } else if accounts.isEmpty {
            DeveloperSwitchingStateSection(
                title: String(localized: "ncm_vip_pool_accounts_section"),
                text: String(localized: "ncm_vip_pool_empty")
            )
        } else {
            SettingsSection(title: String(localized: "ncm_vip_pool_accounts_section")) {
                ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                    DeveloperSwitchingAccountRow(
                        source: .netease,
                        avatarURL: account.avatarUrl.flatMap(URL.init(string:)),
                        title: account.nickname ?? "NCM",
                        subtitle: "\(account.membershipLevel.displayName) · \(account.health.displayName)",
                        isActive: account.isActive,
                        isProcessing: processingID == account.id,
                        onActivate: { activate(account) }
                    )
                    .contextMenu {
                        Button(String(localized: "ncm_vip_pool_refresh")) { refresh(account) }
                    }

                    if index < accounts.count - 1 {
                        DeveloperSwitchingDivider()
                    }
                }
            }
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if let state = try await APIService.shared.fetchNCMVIPAccountPoolState() {
                apply(state)
            }
        } catch {
            showError(error)
        }
    }

    private func startQRLogin() {
        guard processingID == nil else { return }
        processingID = "qr"
        Task { @MainActor in
            defer { processingID = nil }
            do {
                guard let session = try await APIService.shared.startNCMVIPQRLogin(),
                      let image = NCMVIPQRCodeRenderer.image(from: session.qrURL) else {
                    throw URLError(.badServerResponse)
                }
                qrSession = session
                qrImage = image
                qrStateText = String(localized: "ncm_vip_pool_qr_waiting")
            } catch {
                showError(error)
            }
        }
    }

    private func pollQRSession(_ sessionID: String) async {
        while !Task.isCancelled, qrSession?.sessionId == sessionID {
            do {
                guard let status = try await APIService.shared.fetchNCMVIPQRStatus(sessionID: sessionID) else {
                    throw URLError(.badServerResponse)
                }
                switch status.state {
                case .waiting:
                    qrStateText = String(localized: "ncm_vip_pool_qr_waiting")
                case .authorizing:
                    qrStateText = String(localized: "ncm_vip_pool_qr_authorizing")
                case .completed:
                    if let accounts = status.accounts {
                        self.accounts = accounts
                    }
                    clearQRSession()
                    HapticManager.shared.success()
                    return
                case .expired, .rejected:
                    clearQRSession()
                    showError(NCMVIPQRDisplayError(
                        message: status.message ?? String(localized: "ncm_vip_pool_qr_expired")
                    ))
                    return
                }
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch is CancellationError {
                return
            } catch {
                clearQRSession()
                showError(error)
                return
            }
        }
    }

    private func activate(_ account: NCMVIPPoolAccount) {
        perform(account) {
            try await APIService.shared.activateNCMVIPPoolAccount(accountID: account.id)
        }
    }

    private func refresh(_ account: NCMVIPPoolAccount) {
        perform(account) {
            try await APIService.shared.refreshNCMVIPPoolAccount(accountID: account.id)
        }
    }

    private func perform(
        _ account: NCMVIPPoolAccount,
        operation: @escaping () async throws -> NCMVIPAccountPoolState?
    ) {
        guard processingID == nil else { return }
        processingID = account.id
        Task { @MainActor in
            defer { processingID = nil }
            do {
                if let state = try await operation() {
                    apply(state)
                }
                HapticManager.shared.success()
            } catch {
                showError(error)
            }
        }
    }

    private func apply(_ state: NCMVIPAccountPoolState) {
        accounts = state.accounts
    }

    private func clearQRSession() {
        qrSession = nil
        qrImage = nil
        qrStateText = nil
    }

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        isShowingError = true
    }
}

private struct NCMVIPQRDisplayError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
private enum NCMVIPQRCodeRenderer {
    private static let context = CIContext()

    static func image(from value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(
            by: CGAffineTransform(scaleX: 12, y: 12)
        ), let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
