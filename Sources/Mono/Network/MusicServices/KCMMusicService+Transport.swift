import Foundation

extension KCMMusicService {
    func request(
        path: String,
        method: String = "GET",
        query: [URLQueryItem] = []
    ) async throws -> [String: Any] {
        try await request(
            path: path,
            method: method,
            query: query,
            expectedSession: nil,
            allowsAuthenticationRefresh: true
        )
    }

    func request(
        path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        ifCurrentSession expectedSession: SessionSnapshot
    ) async throws -> [String: Any] {
        try await request(
            path: path,
            method: method,
            query: query,
            expectedSession: expectedSession,
            allowsAuthenticationRefresh: true
        )
    }

    private func request(
        path: String,
        method: String,
        query: [URLQueryItem],
        expectedSession: SessionSnapshot?,
        allowsAuthenticationRefresh: Bool
    ) async throws -> [String: Any] {
        guard let context = sessionRequestContext(ifCurrent: expectedSession) else {
            throw CancellationError()
        }

        var lastError: Error = KCMMusicError.invalidResponse
        let endpoints = serviceEndpoints
        for (index, endpoint) in endpoints.enumerated() {
            guard isCurrentRequestContext(context) else { throw CancellationError() }
            guard var components = URLComponents(
                url: endpoint.url.appendingPathComponent(path),
                resolvingAgainstBaseURL: false
            ) else {
                continue
            }
            components.queryItems = query.isEmpty ? nil : query
            guard let url = components.url else { continue }
            do {
                return try await request(url: url, method: method, context: context)
            } catch {
                if allowsAuthenticationRefresh,
                   context.snapshot.isAuthenticated,
                   Self.isAuthenticationFailure(error) {
                    do {
                        try await authenticationRefreshCoordinator.run(
                            for: context.credentialContext
                        ) { [self] in
                            guard isCurrentRequestContext(context) else {
                                throw CancellationError()
                            }
                            _ = try await refreshAuthenticatedSession(
                                ifCurrentRequestContext: context
                            )
                        }
                        guard isCurrentSession(context.snapshot) else {
                            throw CancellationError()
                        }
                        return try await request(
                            path: path,
                            method: method,
                            query: query,
                            expectedSession: context.snapshot,
                            allowsAuthenticationRefresh: false
                        )
                    } catch let refreshError {
                        if let kcmError = refreshError as? KCMMusicError,
                           case .sessionExpired(let failureContext) = kcmError,
                           failureContext != nil {
                            throw kcmError
                        }
                        if Self.isAuthenticationFailure(refreshError) {
                            guard isCurrentRequestContext(context) else {
                                throw CancellationError()
                            }
                            throw KCMMusicError.sessionExpired(context.credentialContext)
                        }
                        throw refreshError
                    }
                }
                if context.snapshot.isAuthenticated,
                   Self.isAuthenticationFailure(error) {
                    if let kcmError = error as? KCMMusicError,
                       case .sessionExpired(let failureContext) = kcmError,
                       failureContext != nil {
                        throw kcmError
                    }
                    guard isCurrentRequestContext(context) else {
                        throw CancellationError()
                    }
                    throw KCMMusicError.sessionExpired(context.credentialContext)
                }
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
        query: [URLQueryItem] = [],
        sendStoredCookie: Bool = false,
        ifCurrentRequestContext expectedContext: SessionRequestContext? = nil
    ) async throws -> ([String: Any], HTTPURLResponse, SessionRequestContext?) {
        let context: SessionRequestContext?
        if sendStoredCookie {
            let requestContext: SessionRequestContext
            if let expectedContext {
                guard isCurrentRequestContext(expectedContext) else {
                    throw CancellationError()
                }
                requestContext = expectedContext
            } else {
                guard let currentContext = sessionRequestContext() else {
                    throw KCMMusicError.authenticationRequired
                }
                requestContext = currentContext
            }
            guard requestContext.snapshot.isAuthenticated,
                  requestContext.cookieHeader != nil else {
                throw KCMMusicError.authenticationRequired
            }
            context = requestContext
        } else {
            context = nil
        }

        var lastError: Error = KCMMusicError.invalidResponse
        let endpoints = serviceEndpoints
        for (index, endpoint) in endpoints.enumerated() {
            if let context, !isCurrentRequestContext(context) {
                throw CancellationError()
            }
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
            if let cookie = context?.cookieHeader {
                request.setValue(cookie, forHTTPHeaderField: "Cookie")
            }
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      !data.isEmpty,
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw KCMMusicError.invalidResponse
                }
                try Self.validate(json: json, statusCode: http.statusCode)
                if let context, !isCurrentRequestContext(context) {
                    throw CancellationError()
                }
                return (json, http, context)
            } catch {
                if let context {
                    guard isCurrentRequestContext(context) else {
                        throw CancellationError()
                    }
                    if Self.isAuthenticationFailure(error) {
                        throw KCMMusicError.sessionExpired(context.credentialContext)
                    }
                }
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
            return (500...599).contains(code)
        case .authenticationRequired, .sessionExpired, .verificationRequired, .unavailable:
            return false
        }
    }

    static func isAuthenticationFailure(_ error: Error) -> Bool {
        guard let error = error as? KCMMusicError else { return false }
        switch error {
        case .authenticationRequired, .sessionExpired:
            return true
        case .server(let code, _):
            return code == 20017 || code == 20018
        case .verificationRequired, .invalidResponse, .unavailable:
            return false
        }
    }

    func requestPublicJSON(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:]
    ) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              !data.isEmpty,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KCMMusicError.invalidResponse
        }
        try Self.validate(json: json, statusCode: http.statusCode)
        return json
    }

    @discardableResult
    func persistAuthenticatedSession(
        json: [String: Any],
        response: HTTPURLResponse,
        ifCurrentRequestContext context: SessionRequestContext
    ) throws -> SessionSnapshot {
        let header = try authenticatedCookieHeader(
            json: json,
            response: response,
            requestCookieHeader: context.cookieHeader
        )
        guard let updatedSession = updateCookie(
            header,
            ifCurrentRequestContext: context
        ) else {
            throw CancellationError()
        }
        return updatedSession
    }

    @discardableResult
    func persistAuthenticatedSession(
        json: [String: Any],
        response: HTTPURLResponse,
        forLoginAttempt attempt: LoginAttempt
    ) throws -> SessionSnapshot {
        let header = try authenticatedCookieHeader(
            json: json,
            response: response,
            requestCookieHeader: nil
        )
        guard let acceptedSession = applyCookie(header, forLoginAttempt: attempt) else {
            throw CancellationError()
        }
        return acceptedSession
    }

    private func authenticatedCookieHeader(
        json: [String: Any],
        response: HTTPURLResponse,
        requestCookieHeader: String?
    ) throws -> String {
        var values = requestCookieHeader.map(Self.cookieValues(in:)) ?? [:]
        for (name, value) in responseCookieValues(from: response) {
            values[name] = value
        }

        let data = json["data"] as? [String: Any] ?? [:]
        if let token = Self.string(data["token"]), !token.isEmpty {
            values["token"] = token
        }
        if let userID = Self.string(data["userid"]), !userID.isEmpty {
            values["userid"] = userID
        }
        guard values["token"]?.isEmpty == false,
              let userID = values["userid"], userID != "0", !userID.isEmpty else {
            throw KCMMusicError.authenticationRequired
        }
        return Self.cookieHeader(from: values)
    }

    private func request(
        url: URL,
        method: String,
        context: SessionRequestContext
    ) async throws -> [String: Any] {
        guard isCurrentRequestContext(context) else { throw CancellationError() }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyApplicationAuthorization(to: &request)
        if let cookie = context.cookieHeader {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw KCMMusicError.invalidResponse
        }
        guard !data.isEmpty,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KCMMusicError.invalidResponse
        }
        do {
            try Self.validate(json: json, statusCode: http.statusCode)
        } catch {
            guard isCurrentRequestContext(context) else {
                throw CancellationError()
            }
            if context.snapshot.isAuthenticated,
               Self.isAuthenticationFailure(error) {
                throw KCMMusicError.sessionExpired(context.credentialContext)
            }
            throw error
        }

        let responseValues = responseCookieValues(from: http)
        if context.snapshot.isAuthenticated, !responseValues.isEmpty {
            guard isCurrentRequestContext(context) else { throw CancellationError() }
            var values = context.cookieHeader.map(Self.cookieValues(in:)) ?? [:]
            for (name, value) in responseValues {
                values[name] = value
            }
            guard values["token"]?.isEmpty == false,
                  let userID = values["userid"], userID != "0", !userID.isEmpty else {
                throw KCMMusicError.sessionExpired(context.credentialContext)
            }
            guard updateCookie(
                Self.cookieHeader(from: values),
                ifCurrentRequestContext: context
            ) != nil else {
                throw CancellationError()
            }
        } else if !isCurrentRequestContext(context) {
            throw CancellationError()
        }

        guard isCurrentSession(context.snapshot) else { throw CancellationError() }
        return json
    }

    func applyApplicationAuthorization(to request: inout URLRequest) {
        guard let token = SecureConfig.apiToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else { return }
        request.setValue(token, forHTTPHeaderField: "X-Api-Token")
        request.setValue(DeviceIdentifier.uuid, forHTTPHeaderField: "X-Device-ID")
    }

    private func responseCookieValues(from response: HTTPURLResponse) -> [String: String] {
        var fields: [String: String] = [:]
        for (name, value) in response.allHeaderFields {
            guard let name = name as? String else { continue }
            fields[name] = String(describing: value)
        }
        let responseURL = response.url ?? baseURL
        var values: [String: String] = [:]
        for cookie in HTTPCookie.cookies(withResponseHeaderFields: fields, for: responseURL) {
            values[cookie.name.lowercased()] = cookie.value
        }
        return values
    }

    private static func cookieHeader(from values: [String: String]) -> String {
        values
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "; ")
    }
}
