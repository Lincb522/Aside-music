import Foundation

@MainActor
final class OnlineAccessManager: ObservableObject {
    static let shared = OnlineAccessManager()

    enum Mode: Equatable {
        case localOnly
        case online
    }

    private enum GatePhase: UInt8 {
        case shell = 0x17
        case remote = 0x4D

        init(hasToken: Bool) {
            self = hasToken ? .remote : .shell
        }

        init(hasToken: Bool, status: APIService.TokenStatus) {
            switch status {
            case .valid, .validationDisabled:
                self = .remote
            case .missing, .invalid, .deviceMismatch, .expired:
                self = .shell
            case .networkError:
                self = hasToken ? .remote : .shell
            }
        }

        var exposedMode: Mode {
            self == .remote ? .online : .localOnly
        }
    }

    @Published private(set) var mode: Mode
    @Published private(set) var isVerifying = false
    @Published private(set) var lastTokenStatus: APIService.TokenStatus?
    private var gatePhase: GatePhase

    private init() {
        let phase = GatePhase(hasToken: Self.hasStoredToken)
        gatePhase = phase
        mode = phase.exposedMode
    }

    static var hasStoredToken: Bool {
        guard let token = SecureConfig.apiToken else { return false }
        return !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasStoredToken: Bool {
        Self.hasStoredToken
    }

    var canUseOnlineFeatures: Bool {
        gatePhase == .remote
    }

    func refreshOnLaunch(showInvalidAlert: Bool = false) {
        guard hasStoredToken else {
            lastTokenStatus = .missing
            transition(to: .shell)
            return
        }

        Task {
            let status = await verifyCurrentToken(isRefresh: true)
            await MainActor.run {
                self.handle(status: status, showInvalidAlert: showInvalidAlert)
            }
        }
    }

    @discardableResult
    func submitToken(_ token: String) async -> APIService.TokenStatus {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            clearToken()
            return .missing
        }

        APIService.shared.applyToken(trimmed)
        let status = await verifyCurrentToken()

        await MainActor.run {
            self.handle(status: status, showInvalidAlert: false)
        }

        return status
    }

    func clearToken() {
        purgeCredential(with: .missing)
    }

    private func verifyCurrentToken(isRefresh: Bool = false) async -> APIService.TokenStatus {
        isVerifying = true
        defer { isVerifying = false }
        return await APIService.shared.verifyToken(isRefresh: isRefresh)
    }

    private func handle(status: APIService.TokenStatus, showInvalidAlert: Bool) {
        switch status {
        case .valid, .validationDisabled:
            lastTokenStatus = status
            transition(to: GatePhase(hasToken: hasStoredToken, status: status))
            LocalPlaylistCloudSyncManager.shared.handleAccessGranted()
            Task { @MainActor in
                await AIProviderConfigurationStore.shared.refreshRemoteConfigurationIfNeeded(force: true)
            }
            Task {
                _ = await SongContentConfigurationStore.shared.configuration(forceRefresh: true)
            }
        case .missing:
            lastTokenStatus = .missing
            transition(to: .shell)
            LocalPlaylistCloudSyncManager.shared.handleAccessRevoked()
        case .invalid:
            purgeCredential(with: .invalid)
            if showInvalidAlert {
                AlertManager.shared.show(
                    title: NSLocalizedString("access_expired_title", comment: ""),
                    message: NSLocalizedString("access_expired_message", comment: ""),
                    primaryButtonTitle: NSLocalizedString("common_ok", comment: ""),
                    primaryAction: {}
                )
            }
        case .expired:
            // Do NOT purge credential, so we can display '已过期' in settings
            lastTokenStatus = .expired
            transition(to: .shell)
            LocalPlaylistCloudSyncManager.shared.handleAccessRevoked()
            if showInvalidAlert {
                AlertManager.shared.show(
                    title: String(localized: "Token 已过期"),
                    message: String(localized: "当前授权的 Token 已过期，请重新获取"),
                    primaryButtonTitle: NSLocalizedString("common_ok", comment: ""),
                    primaryAction: {}
                )
            }
        case .deviceMismatch:
            purgeCredential(with: .deviceMismatch)
            if showInvalidAlert {
                AlertManager.shared.show(
                    title: String(localized: "设备验证失败"),
                    message: String(localized: "Token 已解绑，请重新绑定"),
                    primaryButtonTitle: NSLocalizedString("common_ok", comment: ""),
                    primaryAction: {}
                )
            }
        case .networkError:
            lastTokenStatus = .networkError
            transition(to: GatePhase(hasToken: hasStoredToken, status: status))
        }
    }

    private func purgeCredential(with status: APIService.TokenStatus) {
        APIService.shared.applyToken("")
        lastTokenStatus = status
        transition(to: .shell)
        LocalPlaylistCloudSyncManager.shared.handleAccessRevoked()
    }

    private func transition(to phase: GatePhase) {
        gatePhase = phase
        mode = phase.exposedMode
    }
}
