import Foundation
import UserNotifications
import UIKit

@MainActor
class PushService: NSObject, ObservableObject {
    static let shared = PushService()
    
    // MARK: - CertVault 远程推送配置
    
    private let certVaultBase = "https://p12.zijiu522.cn/api"
    private let certVaultUser = "zijiu522"
    private let certVaultPass = "yqq977522"
    
    @Published private(set) var pushEnabled: Bool = true
    
    private var authToken: String? {
        get { UserDefaults.standard.string(forKey: "certvault_auth_token") }
        set { UserDefaults.standard.set(newValue, forKey: "certvault_auth_token") }
    }
    
    private var deviceToken: String? {
        UserDefaults.standard.string(forKey: "apns_device_token")
    }
    
    private var isRemotePushAvailable: Bool {
        deviceToken != nil
    }
    
    private var isSandbox: Bool { false }
    
    private var deviceLabel: String {
        let systemName = UIDevice.current.name
        let generic = ["iPhone", "iPad", "iPod touch"]
        if generic.contains(systemName) {
            return deviceModel
        }
        return systemName
    }
    
    private var serverTimeOffset: TimeInterval = 0

    private override init() {
        super.init()
    }
    
    // MARK: - 初始化（App 启动时调用）
    
    func setup() {
        UNUserNotificationCenter.current().delegate = self
        Task {
            await calibrateTime()
            await loginCertVaultIfNeeded()
            await refreshPushStatus()
        }
    }

    private func calibrateTime() async {
        guard let url = URL(string: certVaultBase + "/push/status") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        do {
            let localBefore = Date()
            let (_, response) = try await URLSession.shared.data(for: request)
            let localAfter = Date()
            let localMid = localBefore.addingTimeInterval(localAfter.timeIntervalSince(localBefore) / 2)

            if let httpResp = response as? HTTPURLResponse,
               let dateStr = httpResp.value(forHTTPHeaderField: "Date") {
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US_POSIX")
                df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                if let serverDate = df.date(from: dateStr) {
                    serverTimeOffset = serverDate.timeIntervalSince(localMid)
                    if abs(serverTimeOffset) > 2 {
                        AppLogger.info("[Push] 时间校准：本地偏差 \(String(format: "%.1f", serverTimeOffset))s")
                    }
                }
            }
        } catch {
            AppLogger.warning("[Push] 时间校准失败，使用本地时间")
        }
    }

    private var calibratedNow: Date {
        Date().addingTimeInterval(serverTimeOffset)
    }

    private static let lastUploadKey = "apns_last_upload_time"
    private static let uploadThrottleInterval: TimeInterval = 30 * 60

    /// 注册 Device Token 并上报到 CertVault（防抖去重：token 不变且 30 分钟内不重复上报）
    func registerToken(_ token: String) {
        let env = isSandbox ? "sandbox" : "production"
        let previousToken = UserDefaults.standard.string(forKey: "apns_device_token")
        let isNewToken = token != previousToken

        UserDefaults.standard.set(token, forKey: "apns_device_token")
        UserDefaults.standard.set(isSandbox, forKey: "apns_sandbox")

        if !isNewToken {
            let lastUpload = UserDefaults.standard.double(forKey: Self.lastUploadKey)
            if lastUpload > 0, calibratedNow.timeIntervalSince1970 - lastUpload < Self.uploadThrottleInterval {
                AppLogger.info("[Push] Device Token 未变化且距上次上报不足 30 分钟，跳过 (\(env))")
                return
            }
        }

        AppLogger.info("[Push] Device Token \(isNewToken ? "已更新" : "定期上报") (\(env)): \(token.prefix(16))...")
        Task { await uploadDeviceToken(token) }
    }

    private var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? "Unknown"
            }
        }
    }

    private var deviceModel: String {
        let id = deviceModelIdentifier
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return Self.modelMap[sim] ?? sim
        }
        return Self.modelMap[id] ?? id
    }

    private static let modelMap: [String: String] = [
        // MARK: - iPhone
        "iPhone8,1": "iPhone 6s", "iPhone8,2": "iPhone 6s Plus",
        "iPhone8,4": "iPhone SE (1st)",
        "iPhone9,1": "iPhone 7", "iPhone9,3": "iPhone 7",
        "iPhone9,2": "iPhone 7 Plus", "iPhone9,4": "iPhone 7 Plus",
        "iPhone10,1": "iPhone 8", "iPhone10,4": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus", "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X", "iPhone10,6": "iPhone X",
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max", "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e",
        "iPhone18,1": "iPhone 17 Pro",
        "iPhone18,2": "iPhone 17 Pro Max",
        "iPhone18,3": "iPhone 17",
        "iPhone18,4": "iPhone Air",
        "iPhone18,5": "iPhone 17e",

        // MARK: - iPad
        "iPad11,1": "iPad mini (5th)", "iPad11,2": "iPad mini (5th)",
        "iPad11,3": "iPad Air (3rd)", "iPad11,4": "iPad Air (3rd)",
        "iPad11,6": "iPad (8th)", "iPad11,7": "iPad (8th)",
        "iPad12,1": "iPad (9th)", "iPad12,2": "iPad (9th)",
        "iPad13,1": "iPad Air (4th)", "iPad13,2": "iPad Air (4th)",
        "iPad13,4": "iPad Pro 11-inch (3rd)", "iPad13,5": "iPad Pro 11-inch (3rd)",
        "iPad13,6": "iPad Pro 11-inch (3rd)", "iPad13,7": "iPad Pro 11-inch (3rd)",
        "iPad13,8": "iPad Pro 12.9-inch (5th)", "iPad13,9": "iPad Pro 12.9-inch (5th)",
        "iPad13,10": "iPad Pro 12.9-inch (5th)", "iPad13,11": "iPad Pro 12.9-inch (5th)",
        "iPad13,16": "iPad Air (5th)", "iPad13,17": "iPad Air (5th)",
        "iPad13,18": "iPad (10th)", "iPad13,19": "iPad (10th)",
        "iPad14,1": "iPad mini (6th)", "iPad14,2": "iPad mini (6th)",
        "iPad14,3": "iPad Pro 11-inch (4th)", "iPad14,4": "iPad Pro 11-inch (4th)",
        "iPad14,5": "iPad Pro 12.9-inch (6th)", "iPad14,6": "iPad Pro 12.9-inch (6th)",
        "iPad14,8": "iPad Air 11-inch (M2)", "iPad14,9": "iPad Air 11-inch (M2)",
        "iPad14,10": "iPad Air 13-inch (M2)", "iPad14,11": "iPad Air 13-inch (M2)",
        "iPad15,7": "iPad (11th)", "iPad15,8": "iPad (11th)",
        "iPad16,1": "iPad mini (A17 Pro)", "iPad16,2": "iPad mini (A17 Pro)",
        "iPad16,3": "iPad Pro 11-inch (M4)", "iPad16,4": "iPad Pro 11-inch (M4)",
        "iPad16,5": "iPad Pro 13-inch (M4)", "iPad16,6": "iPad Pro 13-inch (M4)",
        "iPad16,8": "iPad Air 11-inch (M4)", "iPad16,9": "iPad Air 11-inch (M4)",
        "iPad16,10": "iPad Air 13-inch (M4)", "iPad16,11": "iPad Air 13-inch (M4)",

        // MARK: - iPod
        "iPod9,1": "iPod touch (7th)",
    ]
    
    private var appVersion: String {
        let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(ver) (\(build))"
    }
    
    private func uploadDeviceToken(_ token: String) async {
        do {
            let auth = try await ensureAuth()
            guard let url = URL(string: "\(certVaultBase)/push/register-device") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(auth)", forHTTPHeaderField: "Authorization")
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            let reportTime = formatter.string(from: calibratedNow)

            var payload: [String: Any] = [
                "device_token": token,
                "platform": "ios",
                "sandbox": isSandbox,
                "device_name": deviceLabel,
                "model": deviceModel,
                "os_version": "iOS \(UIDevice.current.systemVersion)",
                "app_version": appVersion,
                "reported_at": reportTime,
                "label": "\(deviceLabel) | \(deviceModel) (\(deviceModelIdentifier)) | iOS \(UIDevice.current.systemVersion) | v\(appVersion)",
                "device_uuid": DeviceIdentifier.uuid  // 添加设备唯一标识
            ]
            if let tokenKey = SecureConfig.apiToken, !tokenKey.isEmpty {
                payload["token_key"] = tokenKey
            }
            // 添加 Vendor ID（可选）
            if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
                payload["vendor_id"] = vendorId
            }
            
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success {
                UserDefaults.standard.set(calibratedNow.timeIntervalSince1970, forKey: Self.lastUploadKey)
                AppLogger.info("[Push] Device Token 上报成功 (\(deviceLabel), \(deviceModel), iOS \(UIDevice.current.systemVersion))")
            } else {
                AppLogger.warning("[Push] Device Token 上报失败: \(String(data: data, encoding: .utf8) ?? "")")
            }
        } catch {
            AppLogger.warning("[Push] Device Token 上报异常: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 推送服务状态
    
    func refreshPushStatus() async {
        do {
            let auth = try await ensureAuth()
            guard let url = URL(string: "\(certVaultBase)/push/status") else { return }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(auth)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataObj = json["data"] as? [String: Any],
               let enabled = dataObj["push_enabled"] as? Bool {
                pushEnabled = enabled
            }
        } catch {
            AppLogger.warning("[Push] 获取推送状态失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 通知权限
    
    private func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            AppLogger.info("[Push] 通知权限: \(granted ? "已授权" : "未授权")")
        } catch {
            AppLogger.error("[Push] 请求通知权限失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CertVault 自动登录
    
    private func loginCertVaultIfNeeded() async {
        if let token = authToken, !token.isEmpty {
            AppLogger.info("[Push] CertVault 已有缓存 Token")
            return
        }
        do {
            try await loginCertVault()
        } catch {
            AppLogger.warning("[Push] CertVault 自动登录失败: \(error.localizedDescription)")
        }
    }
    
    private func loginCertVault() async throws {
        guard let url = URL(string: "\(certVaultBase)/auth/login") else {
            throw PushError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["username": certVaultUser, "password": certVaultPass]
        )
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool, success,
              let dataObj = json["data"] as? [String: Any],
              let token = dataObj["token"] as? String else {
            throw PushError.loginFailed
        }
        
        self.authToken = token
        AppLogger.info("[Push] CertVault 登录成功")
    }
    
    // MARK: - 统一发送（本地 + 远程）
    
    /// 发送通知：本地通知立即展示，远程推送作为补充（后台唤醒等场景）
    func send(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        badge: Int? = nil,
        delay: TimeInterval = 0.1,
        remoteOnly: Bool = false,
        threadId: String? = nil,
        collapseId: String? = nil,
        interruptionLevel: String? = nil
    ) {
        if !remoteOnly {
            sendLocal(id: id, title: title, body: body, badge: badge, delay: delay, threadId: threadId)
        }
        
        if isRemotePushAvailable && pushEnabled {
            sendRemote(title: title, body: body, badge: badge,
                       threadId: threadId, collapseId: collapseId,
                       interruptionLevel: interruptionLevel)
        }
    }
    
    // MARK: - 本地通知
    
    private func sendLocal(id: String, title: String, body: String, badge: Int?, delay: TimeInterval, threadId: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let badge = badge {
            content.badge = NSNumber(value: badge)
        }
        if let threadId = threadId {
            content.threadIdentifier = threadId
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 0.1), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                AppLogger.error("[Push] 本地通知发送失败: \(error.localizedDescription)")
            } else {
                AppLogger.info("[Push] 本地通知已调度: \(title)")
            }
        }
    }
    
    // MARK: - 远程推送
    
    private func sendRemote(title: String, body: String, badge: Int?,
                            threadId: String? = nil, collapseId: String? = nil,
                            interruptionLevel: String? = nil) {
        guard let token = deviceToken, !token.isEmpty else { return }
        
        Task {
            do {
                let auth = try await ensureAuth()
                try await sendAPNs(
                    authToken: auth, deviceToken: token,
                    title: title, body: body, badge: badge,
                    threadId: threadId, collapseId: collapseId,
                    interruptionLevel: interruptionLevel
                )
                AppLogger.info("[Push] 远程推送已发送: \(title)")
            } catch PushError.pushDisabled {
                pushEnabled = false
                AppLogger.info("[Push] 推送服务已关闭，跳过远程推送")
            } catch {
                AppLogger.warning("[Push] 远程推送失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func ensureAuth() async throws -> String {
        if let token = authToken, !token.isEmpty {
            return token
        }
        try await loginCertVault()
        guard let token = authToken else {
            throw PushError.notAuthenticated
        }
        return token
    }
    
    private func sendAPNs(authToken: String, deviceToken: String,
                          title: String, body: String, badge: Int?,
                          threadId: String? = nil, collapseId: String? = nil,
                          interruptionLevel: String? = nil) async throws {
        guard let url = URL(string: "\(certVaultBase)/push/send") else {
            throw PushError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        var payload: [String: Any] = [
            "device_token": deviceToken,
            "title": title,
            "body": body,
            "sound": "default",
            "sandbox": isSandbox
        ]
        if let badge = badge { payload["badge"] = badge }
        if let threadId = threadId { payload["thread_id"] = threadId }
        if let collapseId = collapseId { payload["collapse_id"] = collapseId }
        if let interruptionLevel = interruptionLevel { payload["interruption_level"] = interruptionLevel }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 503 {
                throw PushError.pushDisabled
            }
            if httpResponse.statusCode == 401 {
                self.authToken = nil
                let newAuth = try await ensureAuth()
                request.setValue("Bearer \(newAuth)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResp) = try await URLSession.shared.data(for: request)
                if let retryHttp = retryResp as? HTTPURLResponse, retryHttp.statusCode == 503 {
                    throw PushError.pushDisabled
                }
                guard let json = try JSONSerialization.jsonObject(with: retryData) as? [String: Any],
                      let success = json["success"] as? Bool, success else {
                    let msg = (try? JSONSerialization.jsonObject(with: retryData) as? [String: Any])?["message"] as? String ?? String(localized: "common_unknown_error")
                    throw PushError.sendFailed(msg)
                }
                return
            }
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool, success else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String ?? String(localized: "common_unknown_error")
            throw PushError.sendFailed(msg)
        }
    }
    
    // MARK: - 业务通知快捷方法
    
    /// qcm Cookie 过期
    func sendCookieExpiredNotification() {
        send(
            id: "qq_cookie_expired",
            title: String(localized: "qq_session_expired_title"),
            body: String(localized: "qq_cookie_expired_body")
        )
    }
    
    /// 下载完成
    func sendDownloadCompleteNotification(songName: String) {
        send(
            id: "download_\(songName.hashValue)",
            title: String(localized: "下载完成"),
            body: L10n.format("download_saved_local_notification_format", songName)
        )
    }
    
    /// 下载失败
    func sendDownloadFailedNotification(songName: String) {
        send(
            id: "download_fail_\(songName.hashValue)",
            title: String(localized: "download_failed_title"),
            body: L10n.format("download_failed_notification_format", songName)
        )
    }
    
    // MARK: - 清除角标
    
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    
    // MARK: - Errors
    
    enum PushError: LocalizedError {
        case notAuthenticated
        case invalidURL
        case loginFailed
        case sendFailed(String)
        case pushDisabled
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return String(localized: "CertVault 未登录")
            case .invalidURL: return String(localized: "推送服务地址无效")
            case .loginFailed: return String(localized: "CertVault 登录失败")
            case .sendFailed(let msg): return L10n.format("push_send_failed_format", msg)
            case .pushDisabled: return String(localized: "推送服务已关闭")
            }
        }
    }
}

// MARK: - 前台通知展示

extension PushService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
