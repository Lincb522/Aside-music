import Foundation

extension KCMMusicService {
    func request(
        path: String,
        method: String = "GET",
        query: [URLQueryItem] = []
    ) async throws -> [String: Any] {
        var lastError: Error = KCMMusicError.invalidResponse
        let endpoints = serviceEndpoints
        for (index, endpoint) in endpoints.enumerated() {
            guard var components = URLComponents(
                url: endpoint.url.appendingPathComponent(path),
                resolvingAgainstBaseURL: false
            ) else {
                continue
            }
            components.queryItems = query.isEmpty ? nil : query
            guard let url = components.url else { continue }
            do {
                return try await request(url: url, method: method)
            } catch {
                lastError = error
                guard Self.shouldTryNextServiceEndpoint(after: error),
                      index < endpoints.index(before: endpoints.endIndex) else {
                    throw error
                }
                AppLogger.warning(
                    "[KCM] \(endpoint.line.rawValue) endpoint unavailable, trying \(endpoints[index + 1].line.rawValue)"
                )
            }
        }
        throw lastError
    }

    func loginRequest(
        path: String,
        query: [URLQueryItem] = []
    ) async throws -> ([String: Any], URL) {
        var lastError: Error = KCMMusicError.invalidResponse
        let endpoints = serviceEndpoints
        for (index, endpoint) in endpoints.enumerated() {
            guard var components = URLComponents(
                url: endpoint.url.appendingPathComponent(path),
                resolvingAgainstBaseURL: false
            ) else {
                continue
            }
            var items = query
            items.append(URLQueryItem(name: "timestamp", value: String(Int(Date().timeIntervalSince1970 * 1_000))))
            components.queryItems = items
            guard let url = components.url else { continue }

            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("no-store, no-cache, max-age=0", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")
            applyApplicationAuthorization(to: &request)
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      !data.isEmpty,
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw KCMMusicError.invalidResponse
                }
                try Self.validate(json: json, statusCode: http.statusCode)
                return (json, url)
            } catch {
                lastError = error
                guard Self.shouldTryNextServiceEndpoint(after: error),
                      index < endpoints.index(before: endpoints.endIndex) else {
                    throw error
                }
                AppLogger.warning(
                    "[KCM] \(endpoint.line.rawValue) login endpoint unavailable, trying \(endpoints[index + 1].line.rawValue)"
                )
            }
        }
        throw lastError
    }

    static func shouldTryNextServiceEndpoint(after error: Error) -> Bool {
        if error is URLError { return true }
        guard let error = error as? KCMMusicError else { return false }
        switch error {
        case .invalidResponse:
            return true
        case .server(let code, _):
            return code >= 500
        case .authenticationRequired, .verificationRequired, .unavailable:
            return false
        }
    }

    func persistAuthenticatedSession(json: [String: Any], responseURL: URL) throws {
        let data = json["data"] as? [String: Any] ?? [:]
        var values: [String: String] = [:]
        for cookie in HTTPCookieStorage.shared.cookies(for: responseURL) ?? [] {
            values[cookie.name] = cookie.value
        }
        if let token = Self.string(data["token"]), !token.isEmpty {
            values["token"] = token
        }
        if let userID = Self.string(data["userid"]), !userID.isEmpty {
            values["userid"] = userID
        }
        var normalizedValues: [String: String] = [:]
        for (name, value) in values {
            normalizedValues[name.lowercased()] = value
        }
        guard let token = normalizedValues["token"], !token.isEmpty,
              let userID = normalizedValues["userid"], userID != "0", !userID.isEmpty else {
            throw KCMMusicError.authenticationRequired
        }
        let header = values
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "; ")
        KeychainHelper.save(key: cookieKey, value: header)
    }

    func request(
        url: URL,
        method: String = "GET",
        sendCookie: Bool = true,
        headers: [String: String] = [:]
    ) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyApplicationAuthorization(to: &request)
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        if sendCookie, let cookie = currentCookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw KCMMusicError.invalidResponse }
        if sendCookie { persistResponseCookies(for: url) }
        guard !data.isEmpty,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KCMMusicError.invalidResponse
        }
        try Self.validate(json: json, statusCode: http.statusCode)
        return json
    }

    func applyApplicationAuthorization(to request: inout URLRequest) {
        guard let token = SecureConfig.apiToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else { return }
        request.setValue(token, forHTTPHeaderField: "X-Api-Token")
        request.setValue(DeviceIdentifier.uuid, forHTTPHeaderField: "X-Device-ID")
    }

    func persistResponseCookies(for url: URL) {
        guard let cookies = HTTPCookieStorage.shared.cookies(for: url), !cookies.isEmpty else { return }
        let header = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"]
        guard let header, !header.isEmpty else { return }
        let values = Self.cookieValues(in: header)
        guard values["token"]?.isEmpty == false,
              let userID = values["userid"], userID != "0", !userID.isEmpty else { return }
        KeychainHelper.save(key: cookieKey, value: header)
    }

}
