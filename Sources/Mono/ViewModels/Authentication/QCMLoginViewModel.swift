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
            return "QCM 登录二维码生成失败，请重试"
        case .missingCredentials:
            return "QCM 登录成功但未取得有效凭证，请刷新二维码重试"
        }
    }
}

@MainActor
class QQLoginViewModel: ObservableObject {

    // MARK: - QR 登录状态
    @Published var qrCodeImage: UIImage?
    @Published var qrStatusMessage: String = String(localized: "加载二维码中...")
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

    init() {
        syncFromUserSession()
    }

    private func syncFromUserSession() {
        isLoggedIn = userSession.isLoggedIn
        isVIP = userSession.isVIP
        qqMusicId = userSession.musicId
        if isLoggedIn {
            loginStatusText = isVIP ? String(localized: "已登录 · VIP") : String(localized: "settings_qq_logged_in")
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
        qrStatusMessage = String(localized: "加载二维码中...")

        let sessionID = UUID()
        let requestedType = qrLoginType
        loginSessionID = sessionID
        loginTask = Task { [weak self] in
            guard let self else { return }
            do {
                let qrCode = try await userSession.withUserSession { client in
                    try await client.createQRCode(type: requestedType)
                }
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
                qrCodeImage = image

                qrStatusMessage = requestedType == .qq
                    ? String(localized: "请使用 QQ 扫描二维码")
                    : String(localized: "请使用微信扫描二维码")
                await poll(qrId: qrCode.qrId, sessionID: sessionID)
            } catch is CancellationError {
                return
            } catch {
                guard isCurrentSession(sessionID) else { return }
                qrStatusMessage = L10n.format(
                    "qq_qr_create_failed_format",
                    error.localizedDescription
                )
                finishSession(sessionID)
            }
        }
    }

    private func poll(qrId: String, sessionID: UUID) async {
        AppLogger.info("[QQLogin] startPolling: qrId=\(qrId)")
        do {
            AppLogger.info("[QQLogin] pollTask started, calling pollQRCode...")
            let finalStatus = try await userSession.withUserSession { client in
                try await client.pollQRCode(
                    qrId: qrId,
                    interval: 3,
                    timeout: 300
                ) { [weak self] status in
                    Task { @MainActor [weak self] in
                        guard let self,
                              isCurrentSession(sessionID),
                              currentQRId == qrId else { return }
                        if status.isScan {
                            qrStatusMessage = String(localized: "等待扫码...")
                        } else if status.isConfirm {
                            qrStatusMessage = String(localized: "已扫码，请在手机上确认")
                        }
                    }
                }
            }

            try Task.checkCancellation()
            guard isCurrentSession(sessionID), currentQRId == qrId else { return }

            if finalStatus.isDone {
                AppLogger.info("[QQLogin] DONE! musicid=\(finalStatus.musicid ?? 0)")
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
                qrStatusMessage = String(localized: "登录成功")
                finishSession(sessionID)
            } else if finalStatus.isTimeout {
                qrStatusMessage = String(localized: "二维码已过期")
                isQRExpired = true
                finishSession(sessionID)
            } else if finalStatus.isRefused {
                qrStatusMessage = String(localized: "登录被拒绝")
                isQRExpired = true
                finishSession(sessionID)
            }
        } catch is CancellationError {
            return
        } catch {
            AppLogger.error("[QQLogin] pollTask error: \(error)")
            guard isCurrentSession(sessionID) else { return }
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
