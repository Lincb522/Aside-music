import Foundation

enum KCMMembershipLevel: String, Codable, CaseIterable, Sendable {
    case none
    case trial
    case full

    var displayName: String {
        switch self {
        case .none: return "无会员"
        case .trial: return "体验会员"
        case .full: return "正式会员"
        }
    }
}

struct KCMStoredAccount: Codable, Identifiable, Sendable {
    let id: String
    let userId: String
    let nickname: String?
    let avatarUrl: String?
    let membershipLevel: KCMMembershipLevel
    let isActive: Bool
    let createdAt: String
    let updatedAt: String
    let lastUsedAt: String?
}

struct KCMAccountPoolState: Decodable, Sendable {
    let enabled: Bool
    let activeAccountId: String?
    let accounts: [KCMStoredAccount]
}

private struct KCMStoredAccountListResponse: Decodable {
    let accounts: [KCMStoredAccount]
    let activeAccountId: String?
}

private struct KCMStoredAccountSaveResponse: Decodable {
    let account: KCMStoredAccount
}

private struct KCMStoredAccountSessionResponse: Decodable {
    let account: KCMStoredAccount
    let cookie: String
}

private struct KCMStoredAccountSaveRequest: Encodable {
    struct Profile: Encodable {
        let nickname: String?
        let avatarUrl: String?
    }

    let cookie: String
    let membershipLevel: KCMMembershipLevel
    let profile: Profile
}

private struct KCMAccountPoolEnabledRequest: Encodable {
    let enabled: Bool
}

private struct KCMAccountPoolPlaybackRequest: Encodable {
    let hash: String
    let albumId: Int
    let albumAudioId: Int
    let qualities: [String]
    let excludeUserId: String?
    let preferredUserId: String?
}

private struct KCMAccountPoolPlaybackResponse: Decodable {
    let url: String
    let quality: String
    let account: KCMStoredAccount
}

struct KCMAccountPoolPlaybackResult: Sendable {
    let url: URL
    let qualityCode: String
}

extension APIService {
    private var kcmAccountVaultPath: String { "/_admin/api/account/kcm/accounts" }
    private var kcmAccountPoolPath: String { "/_admin/api/account/kcm/pool" }

    private var kcmAccountVaultDeviceID: String {
        if let stored = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.playlistSyncDeviceId),
           !stored.isEmpty {
            return stored
        }
        let generated = DeviceIdentifier.uuid
        UserDefaults.standard.set(generated, forKey: AppConfig.StorageKeys.playlistSyncDeviceId)
        return generated
    }

    private func kcmAccountVaultRequest(
        basePath: String? = nil,
        pathSuffix: String = "",
        method: String
    ) -> URLRequest? {
        guard let token = SecureConfig.apiToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty,
              var components = URLComponents(string: SecureConfig.apiBaseURL) else {
            return nil
        }
        let route = "\(basePath ?? kcmAccountVaultPath)\(pathSuffix)"
        components.path = components.path.hasSuffix("/")
            ? "\(components.path)\(route.dropFirst())"
            : "\(components.path)\(route)"
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Api-Token")
        request.setValue(kcmAccountVaultDeviceID, forHTTPHeaderField: "X-Device-ID")
        return request
    }

    func saveKCMAccount(cookie: String, profile: KCMAccountProfile) async throws -> KCMStoredAccount? {
        guard var request = kcmAccountVaultRequest(method: "PUT") else { return nil }
        request.httpBody = try JSONEncoder().encode(
            KCMStoredAccountSaveRequest(
                cookie: cookie,
                membershipLevel: profile.membershipLevel,
                profile: .init(
                    nickname: profile.nickname,
                    avatarUrl: profile.avatarURL?.absoluteString
                )
            )
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validateKCMAccountVaultResponse(response)
        return try JSONDecoder().decode(KCMStoredAccountSaveResponse.self, from: data).account
    }

    func fetchStoredKCMAccounts() async throws -> [KCMStoredAccount] {
        guard let request = kcmAccountVaultRequest(method: "GET") else { return [] }
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validateKCMAccountVaultResponse(response)
        return try JSONDecoder().decode(KCMStoredAccountListResponse.self, from: data).accounts
    }

    func fetchStoredKCMSession(accountID: String) async throws -> String? {
        let suffix = "/\(accountID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? accountID)/session"
        guard let request = kcmAccountVaultRequest(pathSuffix: suffix, method: "GET") else { return nil }
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validateKCMAccountVaultResponse(response)
        return try JSONDecoder().decode(KCMStoredAccountSessionResponse.self, from: data).cookie
    }

    func activateStoredKCMAccount(accountID: String) async throws -> KCMStoredAccount? {
        let suffix = "/\(accountID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? accountID)/active"
        guard let request = kcmAccountVaultRequest(pathSuffix: suffix, method: "PATCH") else { return nil }
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validateKCMAccountVaultResponse(response)
        return try JSONDecoder().decode(KCMStoredAccountSaveResponse.self, from: data).account
    }

    func deleteStoredKCMAccount(accountID: String) async throws {
        let suffix = "/\(accountID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? accountID)"
        guard let request = kcmAccountVaultRequest(pathSuffix: suffix, method: "DELETE") else { return }
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validateKCMAccountVaultResponse(response)
    }

    func fetchKCMAccountPoolState() async throws -> KCMAccountPoolState? {
        guard let request = kcmAccountVaultRequest(basePath: kcmAccountPoolPath, method: "GET") else {
            return nil
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validateKCMAccountVaultResponse(response)
        return try JSONDecoder().decode(KCMAccountPoolState.self, from: data)
    }

    func setKCMAccountPoolEnabled(_ enabled: Bool) async throws -> KCMAccountPoolState? {
        guard var request = kcmAccountVaultRequest(basePath: kcmAccountPoolPath, method: "PATCH") else {
            return nil
        }
        request.httpBody = try JSONEncoder().encode(KCMAccountPoolEnabledRequest(enabled: enabled))
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validateKCMAccountVaultResponse(response)
        return try JSONDecoder().decode(KCMAccountPoolState.self, from: data)
    }

    func activateKCMAccountPoolAccount(accountID: String) async throws -> KCMAccountPoolState? {
        let encodedID = accountID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? accountID
        guard let request = kcmAccountVaultRequest(
            basePath: kcmAccountPoolPath,
            pathSuffix: "/accounts/\(encodedID)/active",
            method: "PATCH"
        ) else { return nil }
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validateKCMAccountVaultResponse(response)
        return try JSONDecoder().decode(KCMAccountPoolState.self, from: data)
    }

    func fetchKCMAccountPoolSongURL(
        song: Song,
        qualityCodes: [String],
        excludeUserID: Int?,
        preferredUserID: Int?
    ) async throws -> KCMAccountPoolPlaybackResult? {
        guard let hash = song.kugouHash, !hash.isEmpty,
              var request = kcmAccountVaultRequest(
                basePath: kcmAccountPoolPath,
                pathSuffix: "/song-url",
                method: "POST"
              ) else { return nil }
        request.httpBody = try JSONEncoder().encode(
            KCMAccountPoolPlaybackRequest(
                hash: hash,
                albumId: song.kugouAlbumID ?? 0,
                albumAudioId: song.kugouAlbumAudioID ?? 0,
                qualities: qualityCodes,
                excludeUserId: excludeUserID.map(String.init),
                preferredUserId: preferredUserID.map(String.init)
            )
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validateKCMAccountVaultResponse(response)
        let payload = try JSONDecoder().decode(KCMAccountPoolPlaybackResponse.self, from: data)
        guard let url = URL(string: payload.url) else { return nil }
        return KCMAccountPoolPlaybackResult(url: url, qualityCode: payload.quality)
    }

    private static func validateKCMAccountVaultResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        }
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }
}
