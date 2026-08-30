import Foundation

extension KCMMusicService {
    @discardableResult
    func refreshAuthenticatedSession(
        ifCurrentRequestContext expectedContext: SessionRequestContext
    ) async throws -> SessionSnapshot {
        guard expectedContext.snapshot.isAuthenticated,
              isCurrentRequestContext(expectedContext) else {
            throw CancellationError()
        }
        let (json, response, requestContext) = try await loginRequest(
            path: "/login/token",
            sendStoredCookie: true,
            ifCurrentRequestContext: expectedContext
        )
        guard let requestContext else { throw KCMMusicError.invalidResponse }
        do {
            return try persistAuthenticatedSession(
                json: json,
                response: response,
                ifCurrentRequestContext: requestContext
            )
        } catch {
            if let kcmError = error as? KCMMusicError,
               case .sessionExpired(let failureContext) = kcmError,
               failureContext != nil {
                throw kcmError
            }
            if Self.isAuthenticationFailure(error) {
                guard isCurrentRequestContext(requestContext) else {
                    throw CancellationError()
                }
                throw KCMMusicError.sessionExpired(requestContext.credentialContext)
            }
            throw error
        }
    }

    func createQRCode(for attempt: LoginAttempt) async throws -> KCMQRCodeSession {
        guard isCurrentLoginAttempt(attempt) else { throw CancellationError() }
        let (keyResponse, _, _) = try await loginRequest(path: "/login/qr/key")
        guard isCurrentLoginAttempt(attempt) else { throw CancellationError() }
        let keyData = keyResponse["data"] as? [String: Any] ?? [:]
        guard let key = Self.string(keyData["qrcode"]), !key.isEmpty else {
            throw KCMMusicError.invalidResponse
        }

        if let encodedImage = Self.string(keyData["qrcode_img"]),
           let imageData = Self.decodeBase64Image(encodedImage) {
            return KCMQRCodeSession(key: key, imageData: imageData)
        }

        let (createResponse, _, _) = try await loginRequest(
            path: "/login/qr/create",
            query: [
                URLQueryItem(name: "key", value: key),
                URLQueryItem(name: "qrimg", value: "1"),
            ]
        )
        guard isCurrentLoginAttempt(attempt) else { throw CancellationError() }
        let createData = createResponse["data"] as? [String: Any] ?? [:]
        guard let encodedImage = Self.string(createData["base64"]),
              let imageData = Self.decodeBase64Image(encodedImage) else {
            throw KCMMusicError.invalidResponse
        }
        return KCMQRCodeSession(key: key, imageData: imageData)
    }

    func checkQRCode(
        key: String,
        for attempt: LoginAttempt
    ) async throws -> KCMQRCodeStatus {
        guard isCurrentLoginAttempt(attempt) else { throw CancellationError() }
        let (json, response, _) = try await loginRequest(
            path: "/login/qr/check",
            query: [URLQueryItem(name: "key", value: key)]
        )
        guard isCurrentLoginAttempt(attempt) else { throw CancellationError() }
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
            let acceptedSession = try persistAuthenticatedSession(
                json: json,
                response: response,
                forLoginAttempt: attempt
            )
            Task { [weak self] in
                await self?.synchronizeCurrentAccount(
                    ifCurrentSession: acceptedSession
                )
            }
            Task { @MainActor [weak self] in
                guard self?.isCurrentSession(acceptedSession) == true else { return }
                KCMDailyMembershipEngine.shared.resumeAfterLogin()
            }
            return .confirmed
        default:
            return .waiting
        }
    }

    func fetchAccountProfile(
        ifCurrentSession expectedSession: SessionSnapshot? = nil
    ) async throws -> KCMAccountProfile? {
        let requestedSession = expectedSession ?? sessionSnapshot
        guard requestedSession.isAuthenticated,
              let requestedUserID = requestedSession.userID,
              isCurrentSession(requestedSession) else { return nil }

        let timestamp = Self.requestTimestamp
        let cacheBuster = [URLQueryItem(name: "timestamp", value: timestamp)]
        async let detailRequest = request(
            path: "/user/detail",
            query: cacheBuster,
            ifCurrentSession: requestedSession
        )
        async let vipRequest = request(
            path: "/user/vip/detail",
            query: cacheBuster,
            ifCurrentSession: requestedSession
        )
        let detail = try await detailRequest
        let vip = (try? await vipRequest) ?? [:]
        guard isCurrentSession(requestedSession) else { throw CancellationError() }

        let userID = Self.firstInt(in: detail, keys: ["userid", "user_id", "id"]) ?? requestedUserID
        guard userID == requestedUserID else { throw KCMMusicError.invalidResponse }
        let nickname = Self.firstString(in: detail, keys: ["nickname", "nick_name", "username", "user_name"])
        let avatarString = Self.firstString(
            in: detail,
            keys: ["pic", "k_pic", "avatar", "avatar_url", "headimg", "user_image"]
        )
        let membership = Self.membershipSummary(detail: detail, vip: vip)
        guard cacheMembershipLevel(
            membership.level,
            userID: userID,
            ifCurrentSession: requestedSession
        ) else {
            throw CancellationError()
        }
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

    func synchronizeCurrentAccount(
        profile: KCMAccountProfile? = nil,
        ifCurrentSession expectedSession: SessionSnapshot? = nil
    ) async {
        let requestedSession = expectedSession ?? sessionSnapshot
        guard requestedSession.isAuthenticated,
              let requestedUserID = requestedSession.userID,
              isCurrentSession(requestedSession) else { return }
        var remainingCredentialRotationRetries = 1
        while true {
            do {
                let resolvedProfile: KCMAccountProfile?
                if let profile {
                    resolvedProfile = profile
                } else {
                    resolvedProfile = try await fetchAccountProfile(
                        ifCurrentSession: requestedSession
                    )
                }
                guard let resolvedProfile,
                      resolvedProfile.userID == requestedUserID,
                      let requestContext = sessionRequestContext(ifCurrent: requestedSession),
                      let cookie = requestContext.cookieHeader else { return }

                let outcome = await KCMAccountVaultSaveCoordinator.shared.enqueue(
                    while: { [weak self] in
                        self?.isCurrentRequestContext(requestContext) == true
                    },
                    operation: {
                        do {
                            _ = try await APIService.shared.saveKCMAccount(
                                cookie: cookie,
                                profile: resolvedProfile
                            )
                            return .succeeded
                        } catch {
                            AppLogger.warning("KCM 账号同步失败: \(error.localizedDescription)")
                            return .failed
                        }
                    }
                )
                if outcome.requiresCurrentAccountCompensation
                    || !isCurrentRequestContext(requestContext) {
                    guard sessionSnapshot.isAuthenticated else { return }
                    await synchronizeCurrentAccount()
                }
                return
            } catch is CancellationError {
                guard remainingCredentialRotationRetries > 0,
                      !Task.isCancelled,
                      isCurrentSession(requestedSession) else { return }
                remainingCredentialRotationRetries -= 1
            } catch {
                AppLogger.warning("KCM 账号同步失败: \(error.localizedDescription)")
                return
            }
        }
    }
}
