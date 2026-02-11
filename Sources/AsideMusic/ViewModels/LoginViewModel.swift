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
                self?.checkStatus()
            }
    }
    
    private func stopQRPolling() {
        timer?.cancel()
        timer = nil
    }
    
    private func checkStatus() {
        guard let key = qrKey else { return }
        apiService.checkQRStatus(key: key)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] response in
                guard let self = self else { return }
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
                    if let cookie = response.cookie {
                        APIService.shared.currentCookie = cookie
                        APIService.shared.fetchLoginStatus()
                            .sink(receiveCompletion: { _ in }, receiveValue: { status in
                                if let profile = status.data.profile {
                                    APIService.shared.currentUserId = profile.userId
                                    LikeManager.shared.refreshLikes()
                                    self.isLoggedIn = true
                                    // 同步到 AppStorage，让 ContentView/ProfileView 感知登录状态
                                    UserDefaults.standard.set(true, forKey: "isLoggedIn")
                                    self.stopQRPolling()
                                    NotificationCenter.default.post(name: .didLogin, object: nil)
                                    Task { @MainActor in
                                        GlobalRefreshManager.shared.triggerLoginRefresh()
                                    }
                                }
                            })
                            .store(in: &self.cancellables)
                    }
                default:
                    break
                }
            })
            .store(in: &cancellables)
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
                        LikeManager.shared.refreshLikes()
                    }
                    self?.isLoggedIn = true
                    // 同步到 AppStorage，让 ContentView/ProfileView 感知登录状态
                    UserDefaults.standard.set(true, forKey: "isLoggedIn")
                    NotificationCenter.default.post(name: .didLogin, object: nil)
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
