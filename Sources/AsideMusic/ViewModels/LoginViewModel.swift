import SwiftUI
import Combine
import CoreImage.CIFilterBuiltins

@MainActor
class LoginViewModel: ObservableObject {
    @Published var qrCodeImage: UIImage?
    @Published var qrStatusMessage: String = NSLocalizedString("qr_loading", comment: "Loading QR Code")
    @Published var isQRExpired = false
    
    @Published var phoneNumber: String = ""
    @Published var captchaCode: String = ""
    @Published var isCaptchaSent = false
    @Published var loginErrorMessage: String?
    
    @Published var isLoggedIn = false
    
    private var qrKey: String?
    private var timer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    // MARK: - QR Login Flow
    
    func startQRLogin() {
        stopQRPolling()
        apiService.fetchQRKey()
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] response in
                self?.qrKey = response.data.unikey
                self?.generateQR()
            })
            .store(in: &cancellables)
    }
    
    private func generateQR() {
        guard let key = qrKey else { return }
        apiService.fetchQRCreate(key: key)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] response in
                let qrimg = response.data.qrimg
                let qrurl = response.data.qrurl
                if !qrimg.isEmpty {
                    // 后端返回了 base64 图片（兼容旧模式）
                    self?.decodeBase64Image(qrimg)
                } else if !qrurl.isEmpty {
                    // NCMClient 模式：用 URL 在客户端生成二维码
                    self?.generateQRImage(from: qrurl)
                }
                self?.startQRPolling()
            })
            .store(in: &cancellables)
    }
    
    /// 从 base64 字符串解码二维码图片（兼容旧模式）
    private func decodeBase64Image(_ base64String: String) {
        let cleanBase64 = base64String.components(separatedBy: ",").last ?? base64String
        if let data = Data(base64Encoded: cleanBase64), let image = UIImage(data: data) {
            self.qrCodeImage = image
            self.qrStatusMessage = NSLocalizedString("scan_instruction", comment: "Scan instruction")
        }
    }
    
    /// 使用 CoreImage 从 URL 字符串生成二维码图片
    private func generateQRImage(from urlString: String) {
        guard let data = urlString.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let ciImage = filter.outputImage else { return }
        // 放大二维码（原始尺寸很小）
        let scale = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: scale)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return }
        self.qrCodeImage = UIImage(cgImage: cgImage)
        self.qrStatusMessage = NSLocalizedString("scan_instruction", comment: "Scan instruction")
    }
    
    private func startQRPolling() {
        timer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.checkStatus()
                }
            }
    }
    
    private func stopQRPolling() {
        timer?.cancel()
        timer = nil
    }
    
    private func checkStatus() async {
        guard let key = qrKey else { return }
        do {
            let response = try await apiService.checkQRStatus(key: key).async()
            #if DEBUG
            print("[Login] QR 状态: code=\(response.code), message=\(response.message ?? "")")
            #endif
            switch response.code {
            case 800:
                self.qrStatusMessage = NSLocalizedString("qr_expired", comment: "QR Code Expired")
                self.isQRExpired = true
                self.stopQRPolling()
            case 801:
                self.qrStatusMessage = NSLocalizedString("qr_waiting", comment: "Waiting for scan...")
            case 802:
                self.qrStatusMessage = NSLocalizedString("qr_scanned", comment: "Scanned! Please confirm on phone.")
            case 803:
                self.qrStatusMessage = NSLocalizedString("login_success", comment: "Login Successful!")
                self.stopQRPolling()
                #if DEBUG
                print("[Login] 收到 803，cookie 长度: \(response.cookie?.count ?? 0)")
                #endif
                await self.handleQRLoginSuccess(cookie: response.cookie)
            default:
                break
            }
        } catch {
            #if DEBUG
            print("[Login] checkQRStatus 请求失败: \(error)")
            #endif
        }
    }
    
    /// 处理二维码登录成功
    private func handleQRLoginSuccess(cookie: String?) async {
        if let cookie = cookie {
            APIService.shared.currentCookie = cookie
            #if DEBUG
            print("[Login] cookie 已保存，开始获取登录状态...")
            #endif
        } else {
            #if DEBUG
            print("[Login] 803 但 cookie 为空，尝试用 SessionManager 已有 session")
            #endif
        }
        
        // 获取登录状态
        do {
            let status = try await APIService.shared.fetchLoginStatus().async()
            #if DEBUG
            print("[Login] fetchLoginStatus 成功，profile: \(status.data.profile?.nickname ?? "nil")")
            #endif
            if let profile = status.data.profile {
                APIService.shared.currentUserId = profile.userId
                // currentUserId 的 didSet 已经发送了 .didLogin 通知，无需重复发送
                LikeManager.shared.refreshLikes()
            }
        } catch {
            #if DEBUG
            print("[Login] fetchLoginStatus 失败: \(error)，但 cookie 已保存，继续登录")
            #endif
        }
        
        // 无论 fetchLoginStatus 是否成功，只要 803 就标记登录成功
        self.isLoggedIn = true
        UserDefaults.standard.set(true, forKey: AppConfig.StorageKeys.isLoggedIn)
        // 不再重复发送 .didLogin 通知（currentUserId didSet 已发送）
        GlobalRefreshManager.shared.triggerLoginRefresh()
    }
    
    func refreshQR() {
        isQRExpired = false
        qrStatusMessage = "Refreshing..."
        startQRLogin()
    }
    
    // MARK: - Phone Login Flow
    
    func sendCaptcha() {
        guard !phoneNumber.isEmpty else { return }
        apiService.sendCaptcha(phone: phoneNumber)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.loginErrorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] _ in
                self?.isCaptchaSent = true
                self?.loginErrorMessage = nil
            })
            .store(in: &cancellables)
    }
    
    func loginWithPhone() {
        guard !phoneNumber.isEmpty, !captchaCode.isEmpty else { return }
        apiService.loginCellphone(phone: phoneNumber, captcha: captchaCode)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.loginErrorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] response in
                if response.code == 200, let cookie = response.cookie {
                    APIService.shared.currentCookie = cookie
                    if let profile = response.profile {
                        APIService.shared.currentUserId = profile.userId
                        // currentUserId 的 didSet 已经发送了 .didLogin 通知
                        LikeManager.shared.refreshLikes()
                    }
                    self?.isLoggedIn = true
                    // 同步到 AppStorage，让 ContentView/ProfileView 感知登录状态
                    UserDefaults.standard.set(true, forKey: AppConfig.StorageKeys.isLoggedIn)
                    // 不再重复发送 .didLogin 通知
                    Task { @MainActor in
                        GlobalRefreshManager.shared.triggerLoginRefresh()
                    }
                } else {
                    self?.loginErrorMessage = String(format: NSLocalizedString("login_failed", comment: "Login Failed"), response.code)
                }
            })
            .store(in: &cancellables)
    }
    
    deinit {
        timer?.cancel()
        timer = nil
    }
}
