import Foundation

enum NCMVIPMembershipLevel: String, Codable, Sendable {
    case none
    case vip

    var displayName: String {
        switch self {
        case .none: return String(localized: "ncm_vip_pool_membership_none")
        case .vip: return String(localized: "ncm_vip_pool_membership_vip")
        }
    }
}

enum NCMVIPAccountHealth: String, Codable, Sendable {
    case available
    case expired
    case unavailable
    case unknown

    var displayName: String {
        switch self {
        case .available: return String(localized: "ncm_vip_pool_health_available")
        case .expired: return String(localized: "ncm_vip_pool_health_expired")
        case .unavailable: return String(localized: "ncm_vip_pool_health_unavailable")
        case .unknown: return String(localized: "ncm_vip_pool_health_unknown")
        }
    }
}

struct NCMVIPPoolAccount: Codable, Identifiable, Sendable {
    let id: String
    let userId: String
    let nickname: String?
    let avatarUrl: String?
    let membershipLevel: NCMVIPMembershipLevel
    let vipType: Int
    let redVipLevel: Int
    let expiresAt: String?
    let health: NCMVIPAccountHealth
    let isActive: Bool
    let createdAt: String
    let updatedAt: String
    let lastCheckedAt: String?
    let lastUsedAt: String?
}

struct NCMVIPAccountPoolState: Decodable, Sendable {
    let available: Bool
    let activeAccountId: String?
    let accounts: [NCMVIPPoolAccount]
}

struct NCMVIPQRSession: Decodable, Sendable {
    let sessionId: String
    let qrURL: String
    let expiresAt: String
}

enum NCMVIPQRState: String, Decodable, Sendable {
    case waiting
    case authorizing
    case completed
    case expired
    case rejected
}

struct NCMVIPQRStatus: Decodable, Sendable {
    let state: NCMVIPQRState
    let message: String?
    let available: Bool?
    let activeAccountId: String?
    let accounts: [NCMVIPPoolAccount]?
}

private struct NCMVIPPoolServerError: Decodable {
    let error: String?
    let message: String?
}

private struct NCMVIPPoolRequestError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

extension APIService {
    private var ncmVIPPoolPath: String { "/_admin/api/account/ncm/pool" }

    private var ncmVIPPoolDeviceID: String {
        if let stored = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.playlistSyncDeviceId),
           !stored.isEmpty {
            return stored
        }
        let generated = DeviceIdentifier.uuid
        UserDefaults.standard.set(generated, forKey: AppConfig.StorageKeys.playlistSyncDeviceId)
        return generated
    }

    private func ncmVIPPoolRequest(pathSuffix: String = "", method: String) -> URLRequest? {
        guard let token = SecureConfig.apiToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty,
              var components = URLComponents(string: SecureConfig.apiBaseURL(for: .primary)) else {
            return nil
        }
        let route = "\(ncmVIPPoolPath)\(pathSuffix)"
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
        request.setValue(ncmVIPPoolDeviceID, forHTTPHeaderField: "X-Device-ID")
        return request
    }

    func fetchNCMVIPAccountPoolState() async throws -> NCMVIPAccountPoolState? {
        guard let request = ncmVIPPoolRequest(method: "GET") else { return nil }
        let data = try await performNCMVIPPoolRequest(request)
        return try JSONDecoder().decode(NCMVIPAccountPoolState.self, from: data)
    }

    func activateNCMVIPPoolAccount(accountID: String) async throws -> NCMVIPAccountPoolState? {
        let encodedID = accountID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? accountID
        guard let request = ncmVIPPoolRequest(
            pathSuffix: "/accounts/\(encodedID)/active",
            method: "PATCH"
        ) else { return nil }
        let data = try await performNCMVIPPoolRequest(request)
        return try JSONDecoder().decode(NCMVIPAccountPoolState.self, from: data)
    }

    func refreshNCMVIPPoolAccount(accountID: String) async throws -> NCMVIPAccountPoolState? {
        let encodedID = accountID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? accountID
        guard let request = ncmVIPPoolRequest(
            pathSuffix: "/accounts/\(encodedID)/refresh",
            method: "POST"
        ) else { return nil }
        let data = try await performNCMVIPPoolRequest(request)
        return try JSONDecoder().decode(NCMVIPAccountPoolState.self, from: data)
    }

    func startNCMVIPQRLogin() async throws -> NCMVIPQRSession? {
        guard let request = ncmVIPPoolRequest(pathSuffix: "/qr", method: "POST") else { return nil }
        let data = try await performNCMVIPPoolRequest(request)
        return try JSONDecoder().decode(NCMVIPQRSession.self, from: data)
    }

    func fetchNCMVIPQRStatus(sessionID: String) async throws -> NCMVIPQRStatus? {
        let encodedID = sessionID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? sessionID
        guard let request = ncmVIPPoolRequest(pathSuffix: "/qr/\(encodedID)", method: "GET") else {
            return nil
        }
        let data = try await performNCMVIPPoolRequest(request)
        return try JSONDecoder().decode(NCMVIPQRStatus.self, from: data)
    }

    private func performNCMVIPPoolRequest(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? JSONDecoder().decode(NCMVIPPoolServerError.self, from: data)
            let message = payload?.error ?? payload?.message ?? String(localized: "ncm_vip_pool_error_generic")
            throw NCMVIPPoolRequestError(message: message)
        }
        return data
    }
}
