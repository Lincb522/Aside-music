// qcm用户登录 ViewModel
// 所有登录/登出操作通过用户凭证（musicId/musicKey）隔离

import SwiftUI
import Combine
import QQMusicKit

private enum QCMQRLoginError: LocalizedError {
    case invalidImage
    case missingCredentials

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return String(localized: "qr_error_invalid_image")
        case .missingCredentials:
            return String(localized: "qr_error_validation_failed")
        }
    }
}

@MainActor
class QQLoginViewModel: ObservableObject {

    // MARK: - QR 登录状态
    @Published var qrCodeImage: UIImage?
    @Published var qrStatusMessage: String = String(localized: "qr_loading")
    @Published var isQRExpired = false
    @Published var qrLoginType: QRLoginType = .qq

    // MARK: - 通用状态
    @Published var isLoggedIn = false
    @Published var isVIP = false
    @Published var loginStatusText: String?
    @Published var qqMusicId: Int?

    private var loginTask: Task<Void, Never>?
    private var loginSessionID: UUID?
    private var currentQRId: String?
    private var qrLoginStarted = false

    private var userSession: QQUserSession { QQUserSession.shared }

    private var qqClient: QQMusicClient {
        APIService.shared.qqClient
    }

    private func makeAnonymousLoginClient() -> QQMusicClient {
        let configuration = qqClient.configurationSnapshot
        return QQMusicClient(
            baseURL: configuration.baseURL,
            timeout: configuration.timeout,
            maxRetries: configuration.maxRetries,
            apiToken: configuration.apiToken
        )
    }

    init() {
        syncFromUserSession()
    }

    private func syncFromUserSession() {
        isLoggedIn = userSession.isLoggedIn
        isVIP = userSession.isVIP
        qqMusicId = userSession.musicId
        if isLoggedIn {
            loginStatusText = isVIP ? String(localized: "qq_logged_in_vip") : String(localized: "settings_qq_logged_in")
        }
    }

    // MARK: - 检查登录状态

    func checkLoginStatus() {
        Task {
            await userSession.refresh()
            syncFromUserSession()
        }
    }

    // MARK: - QR 码登录

    /// onAppear 调用：仅首次触发
    func startQRLoginIfNeeded() {
        guard !qrLoginStarted else { return }
        startQRLogin()
    }

    func startQRLogin() {
        qrLoginStarted = true
        stopPolling()
        isLoggedIn = false
        qrCodeImage = nil
        isQRExpired = false
        qrStatusMessage = String(localized: "qr_loading")

        let sessionID = UUID()
        let requestedType = qrLoginType
        let requestedUserSession = userSession.sessionSnapshot
        let loginClient = makeAnonymousLoginClient()
        loginSessionID = sessionID
        loginTask = Task { [weak self] in
            guard let self else { return }
            do {
                let qrCode = try await loginClient.createQRCode(type: requestedType)
                try Task.checkCancellation()
                guard isCurrentSession(sessionID) else { return }
                currentQRId = qrCode.qrId

                let image: UIImage?
                if let imageData = qrCode.imageData,
                   let decodedImage = UIImage(data: imageData) {
                    image = decodedImage
                } else {
                    let cleanBase64 = qrCode.image.components(separatedBy: ",").last ?? qrCode.image
                    if let data = Data(base64Encoded: cleanBase64),
                       let decodedImage = UIImage(data: data) {
                        image = decodedImage
                    } else {
                        image = nil
                    }
                }
                guard let image else { throw QCMQRLoginError.invalidImage }
                guard userSession.isCurrentSession(requestedUserSession) else {
                    finishSession(sessionID)
                    return
                }
                qrCodeImage = image

                qrStatusMessage = requestedType == .qq
                    ? String(localized: "qq_qr_scan_with_qq")
                    : String(localized: "qq_qr_scan_with_wechat")
                await poll(
                    qrId: qrCode.qrId,
                    sessionID: sessionID,
                    userSession: requestedUserSession,
                    client: loginClient
                )
            } catch is CancellationError {
                return
            } catch {
                guard isCurrentSession(sessionID),
                      userSession.isCurrentSession(requestedUserSession) else {
                    finishSession(sessionID)
                    return
                }
                qrStatusMessage = L10n.format(
                    "qq_qr_create_failed_format",
                    error.localizedDescription
                )
                finishSession(sessionID)
            }
        }
    }

    private func poll(
        qrId: String,
        sessionID: UUID,
        userSession requestedUserSession: QQUserSession.SessionSnapshot,
        client loginClient: QQMusicClient
    ) async {
        AppLogger.info("[QQLogin] startPolling")
        do {
            AppLogger.info("[QQLogin] pollTask started, calling pollQRCode...")
            let finalStatus = try await loginClient.pollQRCode(
                qrId: qrId,
                interval: 3,
                timeout: 300
            ) { [weak self] status in
                Task { @MainActor [weak self] in
                    guard let self,
                          isCurrentSession(sessionID),
                          userSession.isCurrentSession(requestedUserSession),
                          currentQRId == qrId else { return }
                    if status.isScan {
                        qrStatusMessage = String(localized: "qr_waiting")
                    } else if status.isConfirm {
                        qrStatusMessage = String(localized: "qr_scanned")
                    }
                }
            }

            try Task.checkCancellation()
            guard isCurrentSession(sessionID),
                  currentQRId == qrId,
                  userSession.isCurrentSession(requestedUserSession) else {
                finishSession(sessionID)
                return
            }

            if finalStatus.isDone {
                AppLogger.info("[QQLogin] DONE")
                guard let musicID = finalStatus.musicid,
                      musicID > 0,
                      let musicKey = finalStatus.musickey,
                      !musicKey.isEmpty else {
                    throw QCMQRLoginError.missingCredentials
                }
                userSession.onLoginSuccess(
                    musicId: musicID,
                    musicKey: musicKey,
                    encryptUin: finalStatus.euin,
                    loginType: finalStatus.loginType
                )
                syncFromUserSession()
                qrStatusMessage = String(localized: "login_success")
                finishSession(sessionID)
            } else if finalStatus.isTimeout {
                qrStatusMessage = String(localized: "qr_expired")
                isQRExpired = true
                finishSession(sessionID)
            } else if finalStatus.isRefused {
                qrStatusMessage = String(localized: "qq_qr_refused")
                isQRExpired = true
                finishSession(sessionID)
            }
        } catch is CancellationError {
            return
        } catch {
            AppLogger.error("[QQLogin] pollTask error: \(error)")
            guard isCurrentSession(sessionID),
                  userSession.isCurrentSession(requestedUserSession) else {
                finishSession(sessionID)
                return
            }
            qrStatusMessage = L10n.format(
                "qq_qr_poll_failed_format",
                error.localizedDescription
            )
            finishSession(sessionID)
        }
    }

    private func isCurrentSession(_ sessionID: UUID) -> Bool {
        loginSessionID == sessionID && !Task.isCancelled
    }

    private func finishSession(_ sessionID: UUID) {
        guard loginSessionID == sessionID else { return }
        loginTask = nil
        loginSessionID = nil
        currentQRId = nil
    }

    func refreshQR() {
        qrLoginStarted = false
        startQRLogin()
    }

    func switchQRType(_ type: QRLoginType) {
        qrLoginType = type
        qrLoginStarted = false
        startQRLogin()
    }

    // MARK: - 退出登录

    func logout() {
        Task {
            userSession.onLogout()
            syncFromUserSession()
            loginStatusText = nil
        }
    }

    // MARK: - 清理

    func stopPolling() {
        loginTask?.cancel()
        loginTask = nil
        loginSessionID = nil
        currentQRId = nil
    }

    deinit {
        loginTask?.cancel()
    }
}
