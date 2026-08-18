import SwiftUI
import Combine
import CoreImage.CIFilterBuiltins

private enum NCMQRLoginError: LocalizedError {
    case invalidKey
    case invalidQRCode
    case loginValidationFailed
    case timedOut

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "未能获取有效的登录二维码，请重试"
        case .invalidQRCode:
            return "登录二维码生成失败，请重试"
        case .loginValidationFailed:
            return "登录凭证验证失败，请刷新二维码重试"
        case .timedOut:
            return "二维码已过期，请刷新后重试"
        }
    }
}

@MainActor
class LoginViewModel: ObservableObject {
    @Published var qrCodeImage: UIImage?
    @Published var qrStatusMessage: String = NSLocalizedString("qr_loading", comment: "Loading QR Code")
    @Published var isQRExpired = false
    
    @Published var isLoggedIn = false
    
    private var qrKey: String?
    private var loginTask: Task<Void, Never>?
    private var loginSessionID: UUID?
    private let apiService = APIService.shared
    
    // MARK: - QR Login Flow
    
    func startQRLogin() {
        stopQRPolling()
        qrCodeImage = nil
        isQRExpired = false
        isLoggedIn = false
        qrStatusMessage = NSLocalizedString("qr_loading", comment: "Loading QR Code")

        let sessionID = UUID()
        loginSessionID = sessionID
        loginTask = Task { [weak self] in
            guard let self else { return }
            do {
                let keyResponse = try await apiService.fetchQRKey().async()
                try Task.checkCancellation()
                guard isCurrentSession(sessionID) else { return }

                let key = keyResponse.data.unikey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { throw NCMQRLoginError.invalidKey }
                qrKey = key

                let createResponse = try await apiService.fetchQRCreate(key: key).async()
                try Task.checkCancellation()
                guard isCurrentSession(sessionID), qrKey == key else { return }

                guard let image = qrImage(from: createResponse.data) else {
                    throw NCMQRLoginError.invalidQRCode
                }
                qrCodeImage = image
                qrStatusMessage = NSLocalizedString("scan_instruction", comment: "Scan instruction")

                try await pollQRStatus(key: key, sessionID: sessionID)
            } catch is CancellationError {
                return
            } catch {
                guard isCurrentSession(sessionID) else { return }
                qrStatusMessage = error.localizedDescription
                finishSession(sessionID)
            }
        }
    }
    
    /// 从 base64 字符串解码二维码图片（兼容旧模式）
    private func decodeBase64Image(_ base64String: String) -> UIImage? {
        let cleanBase64 = base64String.components(separatedBy: ",").last ?? base64String
        guard let data = Data(base64Encoded: cleanBase64) else { return nil }
        return UIImage(data: data)
    }
    
    /// 使用 CoreImage 从 URL 字符串生成二维码图片
    private func generateQRImage(from urlString: String) -> UIImage? {
        guard let data = urlString.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let ciImage = filter.outputImage else { return nil }
        // 放大二维码（原始尺寸很小）
        let scale = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: scale)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func qrImage(from data: QRCreateData) -> UIImage? {
        if !data.qrimg.isEmpty, let image = decodeBase64Image(data.qrimg) {
            return image
        }
        if !data.qrurl.isEmpty {
            return generateQRImage(from: data.qrurl)
        }
        return nil
    }
    
    func stopQRPolling() {
        loginTask?.cancel()
        loginTask = nil
        loginSessionID = nil
        qrKey = nil
    }
    
    private func pollQRStatus(key: String, sessionID: UUID) async throws {
        let deadline = Date().addingTimeInterval(180)
        var consecutiveFailures = 0

        while Date() < deadline {
            try Task.checkCancellation()
            guard isCurrentSession(sessionID), qrKey == key else { return }

            do {
                let response = try await apiService.checkQRStatus(key: key).async()
                try Task.checkCancellation()
                guard isCurrentSession(sessionID), qrKey == key else { return }
                consecutiveFailures = 0

            #if DEBUG
            print("[Login] QR 状态: code=\(response.code), message=\(response.message ?? "")")
            #endif
                switch response.code {
                case 800:
                    qrStatusMessage = NSLocalizedString("qr_expired", comment: "QR Code Expired")
                    isQRExpired = true
                    finishSession(sessionID)
                    return
                case 801:
                    qrStatusMessage = NSLocalizedString("qr_waiting", comment: "Waiting for scan...")
                case 802:
                    qrStatusMessage = NSLocalizedString("qr_scanned", comment: "Scanned! Please confirm on phone.")
                case 803:
                    #if DEBUG
                    print("[Login] 收到 803，cookie 长度: \(response.cookie?.count ?? 0)")
                    #endif
                    guard await handleQRLoginSuccess(cookie: response.cookie) else {
                        throw NCMQRLoginError.loginValidationFailed
                    }
                    guard isCurrentSession(sessionID) else { return }
                    qrStatusMessage = NSLocalizedString("login_success", comment: "Login Successful!")
                    finishSession(sessionID)
                    return
                default:
                    if let message = response.message, !message.isEmpty {
                        qrStatusMessage = message
                    } else {
                        qrStatusMessage = "登录状态异常，请刷新二维码重试"
                    }
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                consecutiveFailures += 1
                guard consecutiveFailures < 3 else { throw error }
                qrStatusMessage = "网络连接不稳定，正在重试"
            }

            try await Task.sleep(nanoseconds: 2_000_000_000)
        }

        throw NCMQRLoginError.timedOut
    }

    private func isCurrentSession(_ sessionID: UUID) -> Bool {
        loginSessionID == sessionID && !Task.isCancelled
    }

    private func finishSession(_ sessionID: UUID) {
        guard loginSessionID == sessionID else { return }
        loginTask = nil
        loginSessionID = nil
        qrKey = nil
    }
    
    /// 处理二维码登录成功
    private func handleQRLoginSuccess(cookie: String?) async -> Bool {
        guard let cookie = cookie?.trimmingCharacters(in: .whitespacesAndNewlines),
              !cookie.isEmpty else {
            #if DEBUG
            print("[Login] 803 但 cookie 为空，拒绝写入无效登录态")
            #endif
            return false
        }

        APIService.shared.currentCookie = cookie
        #if DEBUG
        print("[Login] cookie 已保存，开始获取登录状态...")
        #endif
        
        // 获取登录状态
        do {
            let status = try await APIService.shared.fetchLoginStatus().async()
            #if DEBUG
            print("[Login] fetchLoginStatus 成功，profile: \(status.data.profile?.nickname ?? "nil")")
            #endif
            guard let profile = status.data.profile else {
                APIService.shared.currentCookie = nil
                APIService.shared.currentUserId = nil
                return false
            }
            APIService.shared.currentUserId = profile.userId
            // currentUserId 的 didSet 已经发送了 .didLogin 通知，无需重复发送
            LikeManager.shared.refreshLikes()
        } catch {
            #if DEBUG
            print("[Login] fetchLoginStatus 失败: \(error)")
            #endif
            APIService.shared.currentCookie = nil
            APIService.shared.currentUserId = nil
            return false
        }
        
        self.isLoggedIn = true
        UserDefaults.standard.set(true, forKey: AppConfig.StorageKeys.isLoggedIn)
        // 不再重复发送 .didLogin 通知（currentUserId didSet 已发送）
        GlobalRefreshManager.shared.triggerLoginRefresh()
        
        // 检测 VIP 状态，决定内容请求使用哪个 Cookie
        APIService.shared.checkUserVIPStatus()
        return true
    }
    
    func refreshQR() {
        isQRExpired = false
        qrStatusMessage = "刷新二维码中..."
        startQRLogin()
    }
    
    deinit {
        MainActor.assumeIsolated {
            loginTask?.cancel()
            loginTask = nil
        }
    }
}
