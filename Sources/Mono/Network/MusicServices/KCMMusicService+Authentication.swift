import Foundation

extension KCMMusicService {
    func refreshAuthenticatedSession() async throws {
        guard isAuthenticated else { throw KCMMusicError.authenticationRequired }
        do {
            let (json, responseURL) = try await loginRequest(
                path: "/login/token",
                sendStoredCookie: true
            )
            try persistAuthenticatedSession(json: json, responseURL: responseURL)
        } catch {
            if Self.isAuthenticationFailure(error) {
                throw KCMMusicError.sessionExpired
            }
            throw error
        }
    }

    func createQRCode() async throws -> KCMQRCodeSession {
        let (keyResponse, _) = try await loginRequest(path: "/login/qr/key")
        let keyData = keyResponse["data"] as? [String: Any] ?? [:]
        guard let key = Self.string(keyData["qrcode"]), !key.isEmpty else {
            throw KCMMusicError.invalidResponse
        }

        if let encodedImage = Self.string(keyData["qrcode_img"]),
           let imageData = Self.decodeBase64Image(encodedImage) {
            return KCMQRCodeSession(key: key, imageData: imageData)
        }

        let (createResponse, _) = try await loginRequest(
            path: "/login/qr/create",
            query: [
                URLQueryItem(name: "key", value: key),
                URLQueryItem(name: "qrimg", value: "1"),
            ]
        )
        let createData = createResponse["data"] as? [String: Any] ?? [:]
        guard let encodedImage = Self.string(createData["base64"]),
              let imageData = Self.decodeBase64Image(encodedImage) else {
            throw KCMMusicError.invalidResponse
        }
        return KCMQRCodeSession(key: key, imageData: imageData)
    }

    func checkQRCode(key: String) async throws -> KCMQRCodeStatus {
        let (json, responseURL) = try await loginRequest(
            path: "/login/qr/check",
            query: [URLQueryItem(name: "key", value: key)]
        )
        let data = json["data"] as? [String: Any] ?? [:]
        guard let status = Self.int(data["status"]) else {
            throw KCMMusicError.invalidResponse
        }
        switch status {
        case 0:
            return .expired
        case 1:
            return .waiting
        case 2:
            return .scanned
        case 4:
            try persistAuthenticatedSession(json: json, responseURL: responseURL)
            Task { [weak self] in await self?.synchronizeCurrentAccount() }
            Task { @MainActor in KCMDailyMembershipEngine.shared.resumeAfterLogin() }
            return .confirmed
        default:
            return .waiting
        }
    }

    func fetchAccountProfile() async throws -> KCMAccountProfile? {
        guard isAuthenticated, let fallbackUserID = currentUserID else { return nil }
        let timestamp = Self.requestTimestamp
        let cacheBuster = [URLQueryItem(name: "timestamp", value: timestamp)]
        async let detailRequest = request(path: "/user/detail", query: cacheBuster)
        async let vipRequest = request(path: "/user/vip/detail", query: cacheBuster)
        let detail = try await detailRequest
        let vip = (try? await vipRequest) ?? [:]
        let userID = Self.firstInt(in: detail, keys: ["userid", "user_id", "id"]) ?? fallbackUserID
        let nickname = Self.firstString(in: detail, keys: ["nickname", "nick_name", "username", "user_name"])
        let avatarString = Self.firstString(
            in: detail,
            keys: ["pic", "k_pic", "avatar", "avatar_url", "headimg", "user_image"]
        )
        let membership = Self.membershipSummary(detail: detail, vip: vip)
        cacheMembershipLevel(membership.level, userID: userID)
        return KCMAccountProfile(
            userID: userID,
            nickname: nickname,
            avatarURL: avatarString.flatMap {
                URL(string: Self.secureURL($0.replacingOccurrences(of: "{size}", with: "240")))
            },
            membershipLevel: membership.level,
            membershipExpiration: membership.expiration,
            conceptProductType: membership.productType
        )
    }

    func synchronizeCurrentAccount(profile: KCMAccountProfile? = nil) async {
        guard let cookie = currentCookie else { return }
        do {
            let resolvedProfile: KCMAccountProfile?
            if let profile {
                resolvedProfile = profile
            } else {
                resolvedProfile = try await fetchAccountProfile()
            }
            guard let resolvedProfile else { return }
            _ = try await APIService.shared.saveKCMAccount(cookie: cookie, profile: resolvedProfile)
        } catch {
            AppLogger.warning("KCM 账号同步失败: \(error)")
        }
    }

}
