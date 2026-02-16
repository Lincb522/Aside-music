// QQLoginViewModel.swift
// QQ 音乐登录 ViewModel
// 支持 QR 码登录（QQ/微信）和手机验证码登录

import SwiftUI
import Combine
import QQMusicKit

@MainActor
class QQLoginViewModel: ObservableObject {
    
    // MARK: - QR 登录状态
    @Published var qrCodeImage: UIImage?
    @Published var qrStatusMessage: String = "加载二维码中..."
    @Published var isQRExpired = false
    @Published var qrLoginType: QRLoginType = .qq
    
    // MARK: - 手机登录状态
    @Published var phoneNumber: String = ""
    @Published var captchaCode: String = ""
    @Published var isCaptchaSent = false
    @Published var phoneErrorMessage: String?
    @Published var needCaptchaVerify = false
    @Published var captchaVerifyURL: String?
    
    // MARK: - 通用状态
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var loginStatusText: String?
    @Published var qqMusicId: Int?
    
    private var pollTask: Task<Void, Never>?
    private var currentQRId: String?
    
    private var qqClient: QQMusicClient {
        APIService.shared.qqClient
    }
    
    // MARK: - 检查登录状态
    
    func checkLoginStatus() {
        Task {
            do {
                let status = try await qqClient.authStatus()
                isLoggedIn = status.loggedIn
                qqMusicId = status.musicid
                if status.loggedIn {
                    loginStatusText = "已登录 (ID: \(status.musicid ?? 0))"
                    UserDefaults.standard.set(true, forKey: AppConfig.StorageKeys.qqMusicLoggedIn)
                } else {
                    loginStatusText = nil
                    UserDefaults.standard.set(false, forKey: AppConfig.StorageKeys.qqMusicLoggedIn)
                }
            } catch {
                loginStatusText = "状态检查失败"
                isLoggedIn = false
            }
        }
    }
    
    // MARK: - QR 码登录
    
    func startQRLogin() {
        stopPolling()
        qrCodeImage = nil
        isQRExpired = false
        qrStatusMessage = "加载二维码中..."
        
        Task {
            do {
                let qrCode = try await qqClient.createQRCode(type: qrLoginType)
                currentQRId = qrCode.qrId
                
                // QQ 音乐 API 返回 base64 图片
                if let imageData = qrCode.imageData,
                   let image = UIImage(data: imageData) {
                    qrCodeImage = image
                } else {
                    // 尝试直接解码 base64
                    let cleanBase64 = qrCode.image.components(separatedBy: ",").last ?? qrCode.image
                    if let data = Data(base64Encoded: cleanBase64),
                       let image = UIImage(data: data) {
                        qrCodeImage = image
                    }
                }
                
                qrStatusMessage = qrLoginType == .qq ? "请使用 QQ 扫描二维码" : "请使用微信扫描二维码"
                startPolling(qrId: qrCode.qrId)
            } catch {
                qrStatusMessage = "获取二维码失败: \(error.localizedDescription)"
            }
        }
    }
    
    private func startPolling(qrId: String) {
        pollTask = Task {
            do {
                let finalStatus = try await qqClient.pollQRCode(
                    qrId: qrId,
                    interval: 3,
                    timeout: 300
                ) { [weak self] status in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        if status.isScan {
                            self.qrStatusMessage = "等待扫码..."
                        } else if status.isConfirm {
                            self.qrStatusMessage = "已扫码，请在手机上确认"
                        }
                    }
                }
                
                if finalStatus.isDone {
                    qrStatusMessage = "登录成功"
                    qqMusicId = finalStatus.musicid
                    isLoggedIn = true
                    UserDefaults.standard.set(true, forKey: AppConfig.StorageKeys.qqMusicLoggedIn)
                } else if finalStatus.isTimeout {
                    qrStatusMessage = "二维码已过期"
                    isQRExpired = true
                } else if finalStatus.isRefused {
                    qrStatusMessage = "登录被拒绝"
                    isQRExpired = true
                }
            } catch {
                if !Task.isCancelled {
                    qrStatusMessage = "轮询失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func refreshQR() {
        startQRLogin()
    }
    
    func switchQRType(_ type: QRLoginType) {
        qrLoginType = type
        startQRLogin()
    }
    
    // MARK: - 手机登录
    
    func sendPhoneCode() {
        guard let phone = Int(phoneNumber), phoneNumber.count == 11 else {
            phoneErrorMessage = "请输入正确的手机号"
            return
        }
        
        isLoading = true
        phoneErrorMessage = nil
        
        Task {
            do {
                let result = try await qqClient.sendPhoneCode(phone: phone)
                isLoading = false
                if result.isSent {
                    isCaptchaSent = true
                    phoneErrorMessage = nil
                } else if result.needCaptcha {
                    needCaptchaVerify = true
                    captchaVerifyURL = result.url
                    phoneErrorMessage = "需要滑块验证，请在浏览器中完成后重试"
                }
            } catch {
                isLoading = false
                phoneErrorMessage = "发送验证码失败: \(error.localizedDescription)"
            }
        }
    }
    
    func loginWithPhone() {
        guard let phone = Int(phoneNumber),
              let code = Int(captchaCode) else {
            phoneErrorMessage = "请输入正确的手机号和验证码"
            return
        }
        
        isLoading = true
        phoneErrorMessage = nil
        
        Task {
            do {
                let _ = try await qqClient.phoneLogin(phone: phone, code: code)
                // 验证登录状态
                let status = try await qqClient.authStatus()
                isLoading = false
                if status.loggedIn {
                    isLoggedIn = true
                    qqMusicId = status.musicid
                    UserDefaults.standard.set(true, forKey: AppConfig.StorageKeys.qqMusicLoggedIn)
                } else {
                    phoneErrorMessage = "登录失败，请重试"
                }
            } catch {
                isLoading = false
                phoneErrorMessage = "登录失败: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - 退出登录
    
    func logout() {
        Task {
            do {
                try await qqClient.logout()
            } catch {
                // 忽略退出错误
            }
            isLoggedIn = false
            qqMusicId = nil
            loginStatusText = nil
            UserDefaults.standard.set(false, forKey: AppConfig.StorageKeys.qqMusicLoggedIn)
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
