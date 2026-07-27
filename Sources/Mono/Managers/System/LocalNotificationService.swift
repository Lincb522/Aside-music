import Foundation
import UserNotifications

/// 仅负责设备本地通知，不注册远程通知，也不会上传设备标识或访问远程通知服务。
@MainActor
final class LocalNotificationService: NSObject {
    static let shared = LocalNotificationService()

    private static let obsoleteRemoteNotificationKeys = [
        "apns_device_token",
        "apns_sandbox",
        "apns_last_upload_time",
        "certvault_auth_token",
    ]

    private override init() {
        super.init()
    }

    func setup() {
        Self.obsoleteRemoteNotificationKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        UNUserNotificationCenter.current().delegate = self
        Task { await requestPermissionIfNeeded() }
    }

    private func requestPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            AppLogger.warning("[LocalNotification] 通知权限请求失败: \(error.localizedDescription)")
        }
    }

    func send(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        badge: Int? = nil,
        delay: TimeInterval = 0.1,
        threadId: String? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let badge { content.badge = NSNumber(value: badge) }
        if let threadId { content.threadIdentifier = threadId }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 0.1), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                AppLogger.warning("[LocalNotification] 调度失败: \(error.localizedDescription)")
            }
        }
    }

    func sendCookieExpiredNotification() {
        send(
            id: "qq_cookie_expired",
            title: String(localized: "qq_session_expired_title"),
            body: String(localized: "qq_cookie_expired_body")
        )
    }

    func sendDownloadCompleteNotification(songName: String) {
        send(
            id: "download_\(songName.hashValue)",
            title: String(localized: "下载完成"),
            body: L10n.format("download_saved_local_notification_format", songName)
        )
    }

    func sendDownloadFailedNotification(songName: String) {
        send(
            id: "download_fail_\(songName.hashValue)",
            title: String(localized: "download_failed_title"),
            body: L10n.format("download_failed_notification_format", songName)
        )
    }

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}

extension LocalNotificationService: UNUserNotificationCenterDelegate {
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
