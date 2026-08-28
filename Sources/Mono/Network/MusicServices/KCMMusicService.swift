import Foundation

final class KCMMusicService: @unchecked Sendable {
    static let shared = KCMMusicService()

    let session: URLSession
    let cookieKey = "mono_kugou_cookie"
    let membershipLevelKey = "mono_kcm_membership_level"
    let membershipUserIDKey = "mono_kcm_membership_user_id"

    init(session: URLSession = .shared) {
        self.session = session
    }

    var baseURL: URL {
        URL(string: AppConfig.API.kugouBaseURL)!
    }

    var serviceEndpoints: [(line: ServerLine, url: URL)] {
        var lines = [ServerLineManager.currentLine]
        if !lines.contains(.primary) {
            lines.append(.primary)
        }
        if ServerLineManager.isFirstBackupConfigured, !lines.contains(.backup) {
            lines.append(.backup)
        }
        if ServerLineManager.isSecondBackupConfigured, !lines.contains(.backup2) {
            lines.append(.backup2)
        }
        return lines.compactMap { line in
            URL(string: SecureConfig.kugouBaseURL(for: line)).map { (line, $0) }
        }
    }

    var currentCookie: String? {
        let value = KeychainHelper.loadString(key: cookieKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    var isAuthenticated: Bool {
        guard let cookie = currentCookie else { return false }
        let values = Self.cookieValues(in: cookie)
        guard let token = values["token"], !token.isEmpty,
              let userID = values["userid"], userID != "0", !userID.isEmpty else {
            return false
        }
        return true
    }

    var currentUserID: Int? {
        guard let cookie = currentCookie else { return nil }
        return Self.cookieValues(in: cookie)["userid"].flatMap(Int.init)
    }

    var currentMembershipLevel: KCMMembershipLevel? {
        guard let userID = currentUserID,
              UserDefaults.standard.integer(forKey: membershipUserIDKey) == userID,
              let rawValue = UserDefaults.standard.string(forKey: membershipLevelKey) else {
            return nil
        }
        return KCMMembershipLevel(rawValue: rawValue)
    }

    func applyCookie(_ cookie: String) {
        let previousUserID = currentUserID
        let ignoredAttributes = Set(["path", "domain", "expires", "max-age", "samesite", "secure", "httponly"])
        let normalized = cookie
            .replacingOccurrences(of: "Set-Cookie:", with: "", options: .caseInsensitive)
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { component in
                guard !component.isEmpty else { return false }
                let name = component.split(separator: "=", maxSplits: 1).first?.lowercased() ?? ""
                return !ignoredAttributes.contains(name)
            }
            .joined(separator: "; ")
        guard !normalized.isEmpty else {
            logout()
            return
        }
        let nextUserID = Self.cookieValues(in: normalized)["userid"].flatMap(Int.init)
        if previousUserID != nextUserID {
            clearMembershipCache()
        }
        KeychainHelper.save(key: cookieKey, value: normalized)
    }

    func logout() {
        KeychainHelper.delete(key: cookieKey)
        clearMembershipCache()
        HTTPCookieStorage.shared.cookies(for: baseURL)?.forEach {
            HTTPCookieStorage.shared.deleteCookie($0)
        }
    }


    static let kcmQualityOrder: [SoundQuality] = [
        .multitrack, .jymaster, .sky, .jyeffect,
        .hires, .lossless, .exhigh, .standard,
    ]
}
