// QQLoginViewModel.swift
// qcm用户登录 ViewModel
// 所有登录/登出操作通过用户凭证（musicId/musicKey）隔离

import SwiftUI
import Combine
import QQMusicKit

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

    private var pollTask: Task<Void, Never>?
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
            loginStatusText = isVIP ? String(localized: "已登录 · VIP") : String(localized: "已登录")
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
        qrCodeImage = nil
        isQRExpired = false
        qrStatusMessage = String(localized: "加载二维码中...")

        Task {
            do {
                let qrCode = try await userSession.withUserSession { client in
                    try await client.createQRCode(type: qrLoginType)
                }
                currentQRId = qrCode.qrId

                if let imageData = qrCode.imageData,
                   let image = UIImage(data: imageData) {
                    qrCodeImage = image
                } else {
                    let cleanBase64 = qrCode.image.components(separatedBy: ",").last ?? qrCode.image
                    if let data = Data(base64Encoded: cleanBase64),
                       let image = UIImage(data: data) {
                        qrCodeImage = image
                    }
                }

                qrStatusMessage = qrLoginType == .qq ? String(localized: "请使用 QQ 扫描二维码") : String(localized: "请使用微信扫描二维码")
                startPolling(qrId: qrCode.qrId)
            } catch {
                qrStatusMessage = String(localized: "获取二维码失败: \(error.localizedDescription)")
            }
        }
    }

    private func startPolling(qrId: String) {
        AppLogger.info("[QQLogin] startPolling: qrId=\(qrId)")
        pollTask = Task {
            do {
                AppLogger.info("[QQLogin] pollTask started, calling pollQRCode...")
                let finalStatus = try await userSession.withUserSession { client in
                    try await client.pollQRCode(
                        qrId: qrId,
                        interval: 3,
                        timeout: 300
                    ) { [weak self] status in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            if status.isScan {
                                qrStatusMessage = String(localized: "等待扫码...")
                            } else if status.isConfirm {
                                qrStatusMessage = String(localized: "已扫码，请在手机上确认")
                            }
                        }
                    }
                }

                if finalStatus.isDone {
                    AppLogger.info("[QQLogin] DONE! musicid=\(finalStatus.musicid ?? 0)")
                    stopPolling()
                    qrStatusMessage = String(localized: "登录成功")
                    userSession.onLoginSuccess(
                        musicId: finalStatus.musicid,
                        musicKey: finalStatus.musickey,
                        encryptUin: finalStatus.euin,
                        loginType: finalStatus.loginType
                    )
                    syncFromUserSession()
                } else if finalStatus.isTimeout {
                    qrStatusMessage = String(localized: "二维码已过期")
                    isQRExpired = true
                } else if finalStatus.isRefused {
                    qrStatusMessage = String(localized: "登录被拒绝")
                    isQRExpired = true
                }
            } catch {
                AppLogger.error("[QQLogin] pollTask error: \(error)")
                if !Task.isCancelled {
                    qrStatusMessage = String(localized: "轮询失败: \(error.localizedDescription)")
                }
            }
        }
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
        pollTask?.cancel()
        pollTask = nil
    }

    deinit {
        pollTask?.cancel()
    }
}
