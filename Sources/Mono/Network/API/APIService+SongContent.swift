import Foundation

enum SongContentServiceError: Error {
    case invalidURL
    case invalidResponse
    case unavailable
}

extension APIService {
    func fetchSongContentConfiguration() async throws -> SongContentFeatureConfiguration {
        guard var components = URLComponents(string: SecureConfig.apiBaseURL) else {
            throw SongContentServiceError.invalidURL
        }
        let route = "/api/public/song-content-config"
        components.path = components.path.hasSuffix("/")
            ? "\(components.path)\(route.dropFirst())"
            : "\(components.path)\(route)"

        var queryItems = [
            URLQueryItem(name: "app_version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String),
            URLQueryItem(name: "client_platform", value: "iOS"),
            URLQueryItem(name: "region", value: Locale.current.region?.identifier),
            URLQueryItem(name: "device_uuid", value: DeviceIdentifier.uuid),
        ]
        appendTokenQueryItems(to: &queryItems)
        components.queryItems = queryItems

        guard let url = components.url else { throw SongContentServiceError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        // SongContentConfigurationStore already owns the product-level TTL.
        // Once it decides to refresh, bypass URLCache so a newly published
        // Agent skill/tool policy becomes effective in the same request.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw SongContentServiceError.invalidResponse
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SongContentFeatureConfiguration.self, from: data)
    }

    func fetchSongContent(
        identity: SongContentRequestIdentity,
        locale: String = Locale.preferredLanguages.first ?? "zh-Hans"
    ) async throws -> SongContentDetailResponse {
        guard var components = URLComponents(string: SecureConfig.apiBaseURL) else {
            throw SongContentServiceError.invalidURL
        }

        let route = "/api/public/song-content"
        components.path = components.path.hasSuffix("/")
            ? "\(components.path)\(route.dropFirst())"
            : "\(components.path)\(route)"
        var queryItems = [
            URLQueryItem(name: "platform", value: identity.platform),
            URLQueryItem(name: "song_id", value: identity.platformSongID),
            URLQueryItem(name: "locale", value: locale),
        ]
        appendTokenQueryItems(to: &queryItems)
        components.queryItems = queryItems

        guard let url = components.url else {
            throw SongContentServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SongContentServiceError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 404 || http.statusCode == 501 || http.statusCode == 503 {
                throw SongContentServiceError.unavailable
            }
            throw SongContentServiceError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SongContentDetailResponse.self, from: data)
    }

    func ensureSongContent(
        song: Song,
        locale: String = Locale.preferredLanguages.first ?? "zh-Hans"
    ) async throws -> SongContentDetailResponse {
        let identity = song.contentRequestIdentity
        guard var components = URLComponents(string: SecureConfig.apiBaseURL) else {
            throw SongContentServiceError.invalidURL
        }

        let route = "/api/public/song-content/ensure"
        components.path = components.path.hasSuffix("/")
            ? "\(components.path)\(route.dropFirst())"
            : "\(components.path)\(route)"
        var queryItems: [URLQueryItem] = []
        appendTokenQueryItems(to: &queryItems)
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else { throw SongContentServiceError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.songContentEncoder.encode(
            SongContentEnsureRequest(
                platform: identity.platform,
                songId: identity.platformSongID,
                locale: locale,
                song: song.contentRequestSnapshot
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SongContentServiceError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 404 || http.statusCode == 501 || http.statusCode == 503 {
                throw SongContentServiceError.unavailable
            }
            throw SongContentServiceError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SongContentDetailResponse.self, from: data)
    }

    private func appendTokenQueryItems(to queryItems: inout [URLQueryItem]) {
        guard let token = SecureConfig.apiToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else { return }
        queryItems.append(URLQueryItem(name: "token", value: token))
        queryItems.append(URLQueryItem(name: "deviceId", value: DeviceIdentifier.uuid))
    }
}

private struct SongContentEnsureRequest: Encodable {
    let platform: String
    let songId: String
    let locale: String
    let song: SongContentRequestSnapshot
}

private extension JSONEncoder {
    static var songContentEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}
