import Foundation
import Combine
@preconcurrency import QQMusicKit

/// qcm用户会话管理
///
/// 管理用户独立的 session_id、登录状态和 VIP 信息。
/// session_id 是设备唯一 UUID，首次生成后永久存储在 Keychain 中。
/// 所有用户状态数据由服务端维护，客户端仅保留 session_id 和缓存。
@MainActor
final class QQUserSession: ObservableObject {

    static let shared = QQUserSession()

    private static let isVIPKey = "qq_user_is_vip"
    private static let musicIdKey = "qq_user_music_id"
    private static let musicKeyKey = "qq_user_music_key"
    private static let loggedInKey = "qq_user_logged_in"
    private static let euinKey = "qq_user_euin"
    private static let loginTypeKey = "qq_user_login_type"

    @Published private(set) var isLoggedIn: Bool = false
    @Published private(set) var isVIP: Bool = false
    @Published private(set) var musicId: Int?
    @Published private(set) var musicKey: String?
    @Published private(set) var encryptUin: String?
    @Published private(set) var loginType: Int?
    @Published private(set) var nickname: String?
    @Published private(set) var avatarURL: URL?

    var hasStoredCredentials: Bool {
        musicId != nil && !(musicKey?.isEmpty ?? true)
    }

    private var qqClient: QQMusicClient { APIService.shared.qqClient }

    private init() {
        let savedMusicId = KeychainHelper.loadInt(key: Self.musicIdKey)
        let savedMusicKey = KeychainHelper.loadString(key: Self.musicKeyKey)
        self.musicId = savedMusicId
        self.musicKey = savedMusicKey
        self.encryptUin = KeychainHelper.loadString(key: Self.euinKey)
        self.loginType = UserDefaults.standard.object(forKey: Self.loginTypeKey) as? Int

        let hasValidCredentials = savedMusicId != nil && savedMusicKey != nil && !(savedMusicKey?.isEmpty ?? true)
        self.isLoggedIn = hasValidCredentials && UserDefaults.standard.bool(forKey: Self.loggedInKey)
        self.isVIP = hasValidCredentials && UserDefaults.standard.bool(forKey: Self.isVIPKey)
    }

    /// 刷新登录状态和 VIP 信息（调用服务器）
    func refresh() async {
        guard musicId != nil, let mkey = musicKey, !mkey.isEmpty else {
            AppLogger.info("[QQUserSession] 无有效凭证，标记为未登录")
            onLogout()
            return
        }
        do {
            let status = try await withUserSession { client in
                try await client.authStatus()
            }
            isLoggedIn = status.loggedIn
            musicId = status.musicid
            UserDefaults.standard.set(status.loggedIn, forKey: Self.loggedInKey)
            if let mid = status.musicid {
                KeychainHelper.save(key: Self.musicIdKey, intValue: mid)
            }
            if let mkey = status.musickey, !mkey.isEmpty {
                musicKey = mkey
                KeychainHelper.save(key: Self.musicKeyKey, value: mkey)
            }
            if let euin = status.euin, !euin.isEmpty {
                encryptUin = euin
                KeychainHelper.save(key: Self.euinKey, value: euin)
            }
            if let lt = status.loginType {
                loginType = lt
                UserDefaults.standard.set(lt, forKey: Self.loginTypeKey)
            }

            if status.loggedIn {
                let isSvip = (status.isSvip ?? 0) == 1
                let isRegularVip = (status.isVip ?? 0) == 1
                isVIP = isSvip || isRegularVip
                nickname = status.nickname
                avatarURL = Self.normalizedAvatarURL(status.avatar)
                UserDefaults.standard.set(isVIP, forKey: Self.isVIPKey)
                if nickname?.isEmpty != false || avatarURL == nil,
                   let currentMusicID = musicId {
                    await refreshProfileFallback(musicID: currentMusicID)
                }
            } else {
                isVIP = false
                nickname = nil
                avatarURL = nil
                UserDefaults.standard.set(false, forKey: Self.isVIPKey)
            }
        } catch {
            AppLogger.error("[QQUserSession] 刷新状态失败: \(error)")
        }
    }

    /// 查询 VIP 状态
    func refreshVIPStatus() async {
        do {
            let status = try await withUserSession { client in
                try await client.authStatus()
            }
            let isSvip = (status.isSvip ?? 0) == 1
            let isRegularVip = (status.isVip ?? 0) == 1
            isVIP = status.loggedIn && (isSvip || isRegularVip)
            nickname = status.loggedIn ? status.nickname : nil
            avatarURL = status.loggedIn ? Self.normalizedAvatarURL(status.avatar) : nil
            UserDefaults.standard.set(isVIP, forKey: Self.isVIPKey)
            AppLogger.info("[QQUserSession] VIP 状态: \(isVIP)")
        } catch {
            AppLogger.error("[QQUserSession] 查询 VIP 失败: \(error)")
        }
    }

    /// 登录成功后调用
    func onLoginSuccess(musicId: Int?, musicKey: String? = nil, encryptUin: String? = nil, loginType: Int? = nil) {
        isLoggedIn = true
        self.musicId = musicId
        self.musicKey = musicKey
        UserDefaults.standard.set(true, forKey: Self.loggedInKey)
        if let mid = musicId {
            KeychainHelper.save(key: Self.musicIdKey, intValue: mid)
        }
        if let mkey = musicKey, !mkey.isEmpty {
            KeychainHelper.save(key: Self.musicKeyKey, value: mkey)
        }
        if let euin = encryptUin, !euin.isEmpty {
            self.encryptUin = euin
            KeychainHelper.save(key: Self.euinKey, value: euin)
        }
        if let lt = loginType {
            self.loginType = lt
            UserDefaults.standard.set(lt, forKey: Self.loginTypeKey)
        }
        Task { await refresh() }
    }

    /// 登出
    func onLogout() {
        AppLogger.info("[QQUserSession] onLogout: clearing musicId=\(musicId ?? 0), euin=\(encryptUin ?? "nil")")
        isLoggedIn = false
        isVIP = false
        musicId = nil
        musicKey = nil
        encryptUin = nil
        loginType = nil
        nickname = nil
        avatarURL = nil
        UserDefaults.standard.set(false, forKey: Self.loggedInKey)
        UserDefaults.standard.set(false, forKey: Self.isVIPKey)
        UserDefaults.standard.removeObject(forKey: Self.loginTypeKey)
        KeychainHelper.delete(key: Self.musicIdKey)
        KeychainHelper.delete(key: Self.musicKeyKey)
        KeychainHelper.delete(key: Self.euinKey)

        let checkMid = KeychainHelper.loadInt(key: Self.musicIdKey)
        let checkMkey = KeychainHelper.loadString(key: Self.musicKeyKey)
        let checkEuin = KeychainHelper.loadString(key: Self.euinKey)
        AppLogger.info("[QQUserSession] onLogout verify: musicId=\(checkMid ?? 0), musicKey=\(checkMkey?.isEmpty == false ? "exists" : "nil"), euin=\(checkEuin ?? "nil")")
    }

    /// 使用用户凭证执行请求（临时设置 musicId/musicKey，完成后恢复）
    func withUserSession<T>(_ block: (QQMusicClient) async throws -> T) async throws -> T {
        let client = qqClient
        let orig = (client.musicId, client.musicKey, client.encryptUin, client.loginType)
        client.musicId = musicId
        client.musicKey = musicKey
        client.encryptUin = encryptUin
        client.loginType = loginType
        defer {
            (client.musicId, client.musicKey, client.encryptUin, client.loginType) = orig
        }
        return try await block(client)
    }

    nonisolated func withUserSessionSync<T>(_ block: (QQMusicClient) throws -> T) rethrows -> T {
        let client = QQMusicClient.shared
        let orig = (client.musicId, client.musicKey, client.encryptUin, client.loginType)
        client.musicId = MainActor.assumeIsolated { musicId }
        client.musicKey = MainActor.assumeIsolated { musicKey }
        client.encryptUin = MainActor.assumeIsolated { encryptUin }
        client.loginType = MainActor.assumeIsolated { loginType }
        defer {
            (client.musicId, client.musicKey, client.encryptUin, client.loginType) = orig
        }
        return try block(client)
    }

    private func refreshProfileFallback(musicID: Int) async {
        do {
            let euinResult = try await withUserSession { client in
                try await client.getEuin(musicid: musicID)
            }
            guard let euin = euinResult.stringValue, !euin.isEmpty else { return }
            let homepage = try await withUserSession { client in
                try await client.userHomepage(euin: euin)
            }
            guard let baseInfo = homepage["base_info"] ?? homepage["Info"]?["BaseInfo"] else {
                return
            }
            if nickname?.isEmpty != false {
                nickname = baseInfo["name"]?.stringValue ?? baseInfo["Name"]?.stringValue
            }
            if avatarURL == nil {
                avatarURL = Self.normalizedAvatarURL(
                    baseInfo["avatar"]?.stringValue
                        ?? baseInfo["BigAvatar"]?.stringValue
                        ?? baseInfo["Avatar"]?.stringValue
                )
            }
        } catch {
            AppLogger.warning("[QQUserSession] 用户资料兜底获取失败: \(error)")
        }
    }

    private static func normalizedAvatarURL(_ rawValue: String?) -> URL? {
        guard var value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        if value.hasPrefix("//") {
            value = "https:\(value)"
        } else if value.hasPrefix("http://") {
            value = "https://\(value.dropFirst("http://".count))"
        }
        return URL(string: value)
    }
}
