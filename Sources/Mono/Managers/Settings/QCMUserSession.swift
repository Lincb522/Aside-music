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

    enum RefreshResult: Sendable, Equatable {
        case authenticated
        case unauthenticated
        case unavailable
    }

    struct SessionSnapshot: Sendable, Equatable {
        let revision: UInt64
        let musicID: Int?
        let isLoggedIn: Bool
    }

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
    @Published private(set) var sessionRevision: UInt64 = 0

    var sessionSnapshot: SessionSnapshot {
        SessionSnapshot(
            revision: sessionRevision,
            musicID: musicId,
            isLoggedIn: isLoggedIn
        )
    }

    func isCurrentSession(_ snapshot: SessionSnapshot) -> Bool {
        snapshot == sessionSnapshot
    }

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
    @discardableResult
    func refresh() async -> RefreshResult {
        let requestedSession = sessionSnapshot
        guard requestedSession.musicID != nil,
              let mkey = musicKey,
              !mkey.isEmpty else {
            AppLogger.info("[QQUserSession] 无有效凭证，标记为未登录")
            onLogout()
            return .unauthenticated
        }
        do {
            let status = try await withUserSession { client in
                try await client.authStatus()
            }
            guard isCurrentSession(requestedSession) else {
                if isLoggedIn { return .authenticated }
                return hasStoredCredentials ? .unavailable : .unauthenticated
            }

            let nextMusicKey = status.musickey?.isEmpty == false
                ? status.musickey
                : musicKey
            let nextEncryptUin = status.euin?.isEmpty == false
                ? status.euin
                : encryptUin
            let nextLoginType = status.loginType ?? loginType
            if isLoggedIn != status.loggedIn
                || musicId != status.musicid
                || musicKey != nextMusicKey
                || encryptUin != nextEncryptUin
                || loginType != nextLoginType {
                sessionRevision &+= 1
            }

            isLoggedIn = status.loggedIn
            musicId = status.musicid
            UserDefaults.standard.set(status.loggedIn, forKey: Self.loggedInKey)
            if let mid = status.musicid {
                KeychainHelper.save(key: Self.musicIdKey, intValue: mid)
            } else {
                KeychainHelper.delete(key: Self.musicIdKey)
            }
            if let nextMusicKey, !nextMusicKey.isEmpty {
                musicKey = nextMusicKey
                KeychainHelper.save(key: Self.musicKeyKey, value: nextMusicKey)
            } else {
                musicKey = nil
                KeychainHelper.delete(key: Self.musicKeyKey)
            }
            if let nextEncryptUin, !nextEncryptUin.isEmpty {
                encryptUin = nextEncryptUin
                KeychainHelper.save(key: Self.euinKey, value: nextEncryptUin)
            } else {
                encryptUin = nil
                KeychainHelper.delete(key: Self.euinKey)
            }
            if let nextLoginType {
                loginType = nextLoginType
                UserDefaults.standard.set(nextLoginType, forKey: Self.loginTypeKey)
            } else {
                loginType = nil
                UserDefaults.standard.removeObject(forKey: Self.loginTypeKey)
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
                    await refreshProfileFallback(
                        musicID: currentMusicID,
                        session: sessionSnapshot
                    )
                }
            } else {
                isVIP = false
                nickname = nil
                avatarURL = nil
                UserDefaults.standard.set(false, forKey: Self.isVIPKey)
            }
            return status.loggedIn ? .authenticated : .unauthenticated
        } catch {
            AppLogger.error("[QQUserSession] 刷新状态失败: \(error)")
            return .unavailable
        }
    }

    /// 查询 VIP 状态
    func refreshVIPStatus() async {
        let requestedSession = sessionSnapshot
        do {
            let status = try await withUserSession { client in
                try await client.authStatus()
            }
            guard isCurrentSession(requestedSession) else { return }
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
        sessionRevision &+= 1
        isLoggedIn = true
        isVIP = false
        nickname = nil
        avatarURL = nil
        self.musicId = musicId
        self.musicKey = musicKey
        UserDefaults.standard.set(true, forKey: Self.loggedInKey)
        UserDefaults.standard.set(false, forKey: Self.isVIPKey)
        if let mid = musicId {
            KeychainHelper.save(key: Self.musicIdKey, intValue: mid)
        } else {
            KeychainHelper.delete(key: Self.musicIdKey)
        }
        if let mkey = musicKey, !mkey.isEmpty {
            KeychainHelper.save(key: Self.musicKeyKey, value: mkey)
        } else {
            KeychainHelper.delete(key: Self.musicKeyKey)
        }
        if let euin = encryptUin, !euin.isEmpty {
            self.encryptUin = euin
            KeychainHelper.save(key: Self.euinKey, value: euin)
        } else {
            self.encryptUin = nil
            KeychainHelper.delete(key: Self.euinKey)
        }
        if let lt = loginType {
            self.loginType = lt
            UserDefaults.standard.set(lt, forKey: Self.loginTypeKey)
        } else {
            self.loginType = nil
            UserDefaults.standard.removeObject(forKey: Self.loginTypeKey)
        }
        Task { await refresh() }
    }

    /// 登出
    func onLogout() {
        sessionRevision &+= 1
        AppLogger.info("[QQUserSession] onLogout")
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
        AppLogger.info(
            "[QQUserSession] onLogout verify: musicId=\(checkMid == nil ? "nil" : "exists"), musicKey=\(checkMkey?.isEmpty == false ? "exists" : "nil"), euin=\(checkEuin?.isEmpty == false ? "exists" : "nil")"
        )
    }

    /// 使用当前用户凭证的独立客户端执行请求。
    func withUserSession<T>(_ block: (QQMusicClient) async throws -> T) async throws -> T {
        let configuration = qqClient.configurationSnapshot
        let client = QQMusicClient(
            baseURL: configuration.baseURL,
            timeout: configuration.timeout,
            maxRetries: configuration.maxRetries,
            apiToken: configuration.apiToken,
            musicId: musicId,
            musicKey: musicKey,
            encryptUin: encryptUin,
            loginType: loginType
        )
        return try await block(client)
    }

    private func refreshProfileFallback(
        musicID: Int,
        session: SessionSnapshot
    ) async {
        do {
            guard isCurrentSession(session) else { return }
            let euinResult = try await withUserSession { client in
                try await client.getEuin(musicid: musicID)
            }
            guard isCurrentSession(session) else { return }
            guard let euin = euinResult.stringValue, !euin.isEmpty else { return }
            let homepage = try await withUserSession { client in
                try await client.userHomepage(euin: euin)
            }
            guard isCurrentSession(session) else { return }
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
