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
            return String(localized: "qr_error_invalid_key")
        case .invalidQRCode:
            return String(localized: "qr_error_invalid_image")
        case .loginValidationFailed:
            return String(localized: "qr_error_validation_failed")
        case .timedOut:
            return String(localized: "qr_error_timed_out")
        }
    }
}

enum PhoneLoginFeedback: Equatable {
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .success(let message), .failure(let message):
            return message
        }
    }
}

@MainActor
class LoginViewModel: ObservableObject {
    @Published var qrCodeImage: UIImage?
    @Published var qrStatusMessage: String = NSLocalizedString("qr_loading", comment: "Loading QR Code")
    @Published var isQRExpired = false

    @Published var countryCode = "86" {
        didSet {
            let previous = Self.asciiDigits(in: oldValue)
            let sanitized = String(Self.asciiDigits(in: countryCode).prefix(4))
            if countryCode != sanitized { countryCode = sanitized }
            if previous != sanitized {
                phoneLoginAttempt = nil
                phoneCaptcha = ""
                phoneFeedback = nil
            }
        }
    }
    @Published var phoneNumber = "" {
        didSet {
            let previous = Self.asciiDigits(in: oldValue)
            let sanitized = String(Self.asciiDigits(in: phoneNumber).prefix(15))
            if phoneNumber != sanitized { phoneNumber = sanitized }
            if previous != sanitized {
                phoneLoginAttempt = nil
                phoneCaptcha = ""
                phoneFeedback = nil
            }
        }
    }
    @Published var phoneCaptcha = "" {
        didSet {
            let sanitized = String(Self.asciiDigits(in: phoneCaptcha).prefix(8))
            if phoneCaptcha != sanitized { phoneCaptcha = sanitized }
        }
    }
    @Published private(set) var phoneFeedback: PhoneLoginFeedback?
    @Published private(set) var isSendingCaptcha = false
    @Published private(set) var isPhoneLoggingIn = false
    @Published private(set) var captchaCooldownRemaining = 0

    @Published var isLoggedIn = false

    private var qrKey: String?
    private var loginTask: Task<Void, Never>?
    private var loginSessionID: UUID?
    private var captchaRequestTask: Task<Void, Never>?
    private var captchaRequestID: UUID?
    private var phoneLoginTask: Task<Void, Never>?
    private var phoneLoginRequestID: UUID?
    private var phoneLoginAttempt: NCMLoginAttempt?
    private var captchaCooldownTask: Task<Void, Never>?
    private var captchaCooldownDeadline: Date?
    private var loginCompletionID: UUID?
    private let apiService = APIService.shared

    var canSendCaptcha: Bool {
        isValidPhoneInput
            && !isSendingCaptcha
            && !isPhoneLoggingIn
            && captchaCooldownRemaining == 0
    }

    var canLoginWithPhone: Bool {
        isValidPhoneInput
            && (4...8).contains(normalizedCaptcha.count)
            && !isSendingCaptcha
            && !isPhoneLoggingIn
    }
    
    // MARK: - QR Login Flow
    
    func startQRLogin() {
        stopQRPolling()
        qrCodeImage = nil
        isQRExpired = false
        isLoggedIn = false
        qrStatusMessage = NSLocalizedString("qr_loading", comment: "Loading QR Code")

        let sessionID = UUID()
        let attempt = apiService.makeLoginAttempt()
        let ncmSession = apiService.ncmSessionSnapshot
        loginSessionID = sessionID
        loginTask = Task { [weak self] in
            guard let self else { return }
            do {
                let keyResponse = try await apiService.fetchQRKey(using: attempt).async()
                try Task.checkCancellation()
                guard isCurrentSession(sessionID) else { return }

                let key = keyResponse.data.unikey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { throw NCMQRLoginError.invalidKey }
                qrKey = key

                let createResponse = try await apiService.fetchQRCreate(
                    key: key,
                    using: attempt
                ).async()
                try Task.checkCancellation()
                guard isCurrentSession(sessionID), qrKey == key else { return }

                guard let image = qrImage(from: createResponse.data) else {
                    throw NCMQRLoginError.invalidQRCode
                }
                qrCodeImage = image
                qrStatusMessage = NSLocalizedString("scan_instruction", comment: "Scan instruction")

                try await pollQRStatus(
                    key: key,
                    sessionID: sessionID,
                    attempt: attempt,
                    ncmSession: ncmSession
                )
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
        invalidateLoginCompletion()
    }
    
    private func pollQRStatus(
        key: String,
        sessionID: UUID,
        attempt: NCMLoginAttempt,
        ncmSession: APIService.NCMSessionSnapshot
    ) async throws {
        let deadline = Date().addingTimeInterval(180)
        var consecutiveFailures = 0

        while Date() < deadline {
            try Task.checkCancellation()
            guard isCurrentSession(sessionID), qrKey == key else { return }

            do {
                let response = try await apiService.checkQRStatus(
                    key: key,
                    using: attempt
                ).async()
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
                    let completionID = beginLoginCompletion()
                    guard await completeLogin(
                        cookie: response.cookie,
                        completionID: completionID,
                        ncmSession: ncmSession
                    ) else {
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
                        qrStatusMessage = String(localized: "qr_status_unexpected")
                    }
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                guard isCurrentSession(sessionID), qrKey == key else {
                    throw CancellationError()
                }
                consecutiveFailures += 1
                guard consecutiveFailures < 3 else { throw error }
                qrStatusMessage = String(localized: "qr_status_retrying")
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

    // MARK: - Phone Login Flow

    func sendPhoneCaptcha() {
        guard !isSendingCaptcha,
              !isPhoneLoggingIn,
              captchaCooldownRemaining == 0 else { return }
        guard isValidPhoneInput else {
            phoneFeedback = .failure(String(localized: "login_phone_invalid"))
            return
        }

        let countryCode = normalizedCountryCode
        let phone = normalizedPhoneNumber
        let attempt = apiService.makeLoginAttempt()
        let requestID = UUID()
        phoneLoginAttempt = attempt
        captchaRequestID = requestID
        isSendingCaptcha = true
        phoneCaptcha = ""
        phoneFeedback = nil

        captchaRequestTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await apiService.sendCaptcha(
                    phone: phone,
                    countryCode: countryCode,
                    using: attempt
                ).async()
                try Task.checkCancellation()
                guard captchaRequestID == requestID else { return }

                guard response.code == 200 else {
                    phoneFeedback = .failure(
                        response.message ?? String(localized: "login_captcha_send_failed")
                    )
                    finishCaptchaRequest(requestID)
                    return
                }

                phoneFeedback = .success(String(localized: "login_captcha_sent"))
                startCaptchaCooldown()
                finishCaptchaRequest(requestID)
            } catch is CancellationError {
                finishCaptchaRequest(requestID)
            } catch {
                guard captchaRequestID == requestID else { return }
                phoneFeedback = .failure(error.localizedDescription)
                finishCaptchaRequest(requestID)
            }
        }
    }

    func loginWithPhone() {
        guard !isSendingCaptcha, !isPhoneLoggingIn else { return }
        guard isValidPhoneInput else {
            phoneFeedback = .failure(String(localized: "login_phone_invalid"))
            return
        }
        guard (4...8).contains(normalizedCaptcha.count) else {
            phoneFeedback = .failure(String(localized: "login_captcha_invalid"))
            return
        }

        stopQRPolling()
        let countryCode = normalizedCountryCode
        let phone = normalizedPhoneNumber
        let captcha = normalizedCaptcha
        let ncmSession = apiService.ncmSessionSnapshot
        let attempt = apiService.makeLoginAttempt(
            preservingCookiesFrom: phoneLoginAttempt
        )
        let requestID = UUID()
        phoneLoginAttempt = attempt
        phoneLoginRequestID = requestID
        isPhoneLoggingIn = true
        phoneFeedback = nil

        phoneLoginTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await apiService.loginCellphone(
                    phone: phone,
                    countryCode: countryCode,
                    captcha: captcha,
                    using: attempt
                ).async()
                try Task.checkCancellation()
                guard phoneLoginRequestID == requestID else { return }

                guard response.code == 200 else {
                    phoneFeedback = .failure(
                        response.message ?? String(localized: "login_phone_failed")
                    )
                    finishPhoneLogin(requestID)
                    return
                }

                let completionID = beginLoginCompletion()
                guard await completeLogin(
                    cookie: response.cookie,
                    completionID: completionID,
                    ncmSession: ncmSession
                ) else {
                    guard phoneLoginRequestID == requestID, !Task.isCancelled else { return }
                    phoneFeedback = .failure(String(localized: "login_phone_validation_failed"))
                    finishPhoneLogin(requestID)
                    return
                }

                guard phoneLoginRequestID == requestID else { return }
                phoneFeedback = .success(String(localized: "login_success"))
                finishPhoneLogin(requestID)
            } catch is CancellationError {
                finishPhoneLogin(requestID)
            } catch {
                guard phoneLoginRequestID == requestID else { return }
                phoneFeedback = .failure(error.localizedDescription)
                finishPhoneLogin(requestID)
            }
        }
    }

    func cancelPhoneRequests() {
        let hadActiveRequest = captchaRequestID != nil || phoneLoginRequestID != nil
        captchaRequestTask?.cancel()
        captchaRequestTask = nil
        captchaRequestID = nil
        phoneLoginTask?.cancel()
        phoneLoginTask = nil
        phoneLoginRequestID = nil
        isSendingCaptcha = false
        isPhoneLoggingIn = false
        phoneFeedback = nil
        if hadActiveRequest {
            phoneLoginAttempt = nil
            phoneCaptcha = ""
        }
        invalidateLoginCompletion()
    }

    func suspendLoginWork() {
        stopQRPolling()
        cancelPhoneRequests()
    }

    func stopLoginWork() {
        suspendLoginWork()
        phoneLoginAttempt = nil
        captchaCooldownTask?.cancel()
        captchaCooldownTask = nil
        captchaCooldownDeadline = nil
        captchaCooldownRemaining = 0
        phoneCaptcha = ""
    }

    private var normalizedCountryCode: String {
        Self.asciiDigits(in: countryCode)
    }

    private var normalizedPhoneNumber: String {
        Self.asciiDigits(in: phoneNumber)
    }

    private var normalizedCaptcha: String {
        Self.asciiDigits(in: phoneCaptcha)
    }

    private var isValidPhoneInput: Bool {
        (1...4).contains(normalizedCountryCode.count)
            && (5...15).contains(normalizedPhoneNumber.count)
    }

    private static func asciiDigits(in value: String) -> String {
        value.filter { character in
            character.unicodeScalars.allSatisfy { (48...57).contains($0.value) }
        }
    }

    private func finishCaptchaRequest(_ requestID: UUID) {
        guard captchaRequestID == requestID else { return }
        captchaRequestTask = nil
        captchaRequestID = nil
        isSendingCaptcha = false
    }

    private func finishPhoneLogin(_ requestID: UUID) {
        guard phoneLoginRequestID == requestID else { return }
        phoneLoginTask = nil
        phoneLoginRequestID = nil
        isPhoneLoggingIn = false
    }

    private func startCaptchaCooldown(seconds: Int = 60) {
        captchaCooldownTask?.cancel()
        let deadline = Date().addingTimeInterval(TimeInterval(seconds))
        captchaCooldownDeadline = deadline
        captchaCooldownRemaining = seconds
        captchaCooldownTask = Task { [weak self] in
            guard let self else { return }
            while let captchaCooldownDeadline {
                captchaCooldownRemaining = max(
                    0,
                    Int(ceil(captchaCooldownDeadline.timeIntervalSinceNow))
                )
                guard captchaCooldownRemaining > 0 else { break }
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
            }
            captchaCooldownRemaining = 0
            captchaCooldownDeadline = nil
            captchaCooldownTask = nil
        }
    }

    // MARK: - Shared Login Completion

    private func beginLoginCompletion() -> UUID {
        invalidateLoginCompletion()
        let completionID = UUID()
        loginCompletionID = completionID
        return completionID
    }

    private func invalidateLoginCompletion() {
        loginCompletionID = nil
    }

    private func isActiveLoginCompletion(_ completionID: UUID) -> Bool {
        loginCompletionID == completionID && !Task.isCancelled
    }

    private func failLoginCompletion(_ completionID: UUID) {
        guard loginCompletionID == completionID else { return }
        invalidateLoginCompletion()
    }

    private func completeLogin(
        cookie: String?,
        completionID: UUID,
        ncmSession: APIService.NCMSessionSnapshot
    ) async -> Bool {
        guard isActiveLoginCompletion(completionID) else { return false }
        guard let cookie = cookie?.trimmingCharacters(in: .whitespacesAndNewlines),
              !cookie.isEmpty else {
            #if DEBUG
            print("[Login] 803 但 cookie 为空，拒绝写入无效登录态")
            #endif
            failLoginCompletion(completionID)
            return false
        }

        #if DEBUG
        print("[Login] 开始验证登录状态...")
        #endif
        
        // 获取登录状态
        do {
            let status = try await apiService.validateLoginStatus(cookie: cookie).async()
            guard isActiveLoginCompletion(completionID) else { return false }
            #if DEBUG
            print("[Login] fetchLoginStatus 成功，profile: \(status.data.profile?.nickname ?? "nil")")
            #endif
            guard let profile = status.data.profile else {
                failLoginCompletion(completionID)
                return false
            }
            guard apiService.commitValidatedLogin(
                cookie: cookie,
                userID: profile.userId,
                ifCurrentSession: ncmSession
            ) else {
                failLoginCompletion(completionID)
                return false
            }
            loginCompletionID = nil
            // currentUserId 的 didSet 已经发送了 .didLogin 通知，无需重复发送
            LikeManager.shared.refreshLikes()
        } catch {
            #if DEBUG
            print("[Login] fetchLoginStatus 失败: \(error)")
            #endif
            failLoginCompletion(completionID)
            return false
        }
        
        self.isLoggedIn = true
        UserDefaults.standard.set(true, forKey: AppConfig.StorageKeys.isLoggedIn)
        // 不再重复发送 .didLogin 通知（currentUserId didSet 已发送）
        GlobalRefreshManager.shared.triggerLoginRefresh()
        
        // 检测 VIP 状态，决定内容请求使用哪个 Cookie
        apiService.checkUserVIPStatus()
        return true
    }
    
    func refreshQR() {
        isQRExpired = false
        qrStatusMessage = String(localized: "qr_refreshing")
        startQRLogin()
    }
    
    deinit {
        MainActor.assumeIsolated {
            invalidateLoginCompletion()
            loginTask?.cancel()
            loginTask = nil
            captchaRequestTask?.cancel()
            captchaRequestTask = nil
            phoneLoginTask?.cancel()
            phoneLoginTask = nil
            captchaCooldownTask?.cancel()
            captchaCooldownTask = nil
            captchaCooldownDeadline = nil
        }
    }
}
