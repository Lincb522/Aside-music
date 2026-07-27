import Foundation

enum QCMMembershipLevel: String, Codable, CaseIterable, Sendable {
    case svip
    case vip
    case standard

    var displayName: String {
        switch self {
        case .svip: return "豪华绿钻"
        case .vip: return "绿钻"
        case .standard: return "普通凭证"
        }
    }
}

enum QCMLoginProvider: String, Codable, Sendable {
    case qq
    case wechat
    case unknown

    var displayName: String {
        switch self {
        case .qq: return "QQ"
        case .wechat: return "微信"
        case .unknown: return "未知方式"
        }
    }
}

struct QCMStoredCredential: Codable, Identifiable, Sendable {
    let id: String
    let musicId: String?
    let nickname: String?
    let avatarUrl: String?
    let loginType: Int
    let loginProvider: QCMLoginProvider
    let membershipLevel: QCMMembershipLevel
    let isActive: Bool

    var avatarURL: URL? {
        avatarUrl.flatMap(URL.init(string:))
    }
}

private struct QCMStoredCredentialListResponse: Decodable {
    let credentials: [QCMStoredCredential]
    let activeCredentialId: String?
}

extension APIService {
    private var qcmCredentialManagementPath: String { "/_admin/api/account/qcm/credentials" }

    private var qcmCredentialManagementDeviceID: String {
        if let stored = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.playlistSyncDeviceId),
           !stored.isEmpty {
            return stored
        }
        let generated = DeviceIdentifier.uuid
        UserDefaults.standard.set(generated, forKey: AppConfig.StorageKeys.playlistSyncDeviceId)
        return generated
    }

    private func qcmCredentialManagementRequest(pathSuffix: String = "", method: String) -> URLRequest? {
        guard let token = SecureConfig.apiToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty,
              var components = URLComponents(string: SecureConfig.apiBaseURL) else {
            return nil
        }
        let route = "\(qcmCredentialManagementPath)\(pathSuffix)"
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
        request.setValue(qcmCredentialManagementDeviceID, forHTTPHeaderField: "X-Device-ID")
        return request
    }

    func fetchQCMStoredCredentials() async throws -> [QCMStoredCredential] {
        guard let request = qcmCredentialManagementRequest(method: "GET") else { return [] }
        return try await performQCMCredentialManagementRequest(request)
    }

    func activateQCMStoredCredential(credentialID: String) async throws -> [QCMStoredCredential] {
        let encodedID = credentialID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? credentialID
        guard let request = qcmCredentialManagementRequest(
            pathSuffix: "/\(encodedID)/active",
            method: "POST"
        ) else { return [] }
        return try await performQCMCredentialManagementRequest(request)
    }

    func refreshQCMStoredCredential(credentialID: String) async throws -> [QCMStoredCredential] {
        let encodedID = credentialID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? credentialID
        guard let request = qcmCredentialManagementRequest(
            pathSuffix: "/\(encodedID)/refresh",
            method: "POST"
        ) else { return [] }
        return try await performQCMCredentialManagementRequest(request)
    }

    private func performQCMCredentialManagementRequest(
        _ request: URLRequest
    ) async throws -> [QCMStoredCredential] {
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validateQCMCredentialManagementResponse(response)
        return try JSONDecoder().decode(QCMStoredCredentialListResponse.self, from: data).credentials
    }

    private static func validateQCMCredentialManagementResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        }
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }
}
