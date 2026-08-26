import Foundation

enum AppAgentConfigurationServiceError: Error {
    case invalidURL
    case invalidResponse
}

extension APIService {
    func fetchAppAgentConfiguration() async throws -> AppAgentRemoteConfiguration {
        guard var components = URLComponents(string: SecureConfig.apiBaseURL) else {
            throw AppAgentConfigurationServiceError.invalidURL
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
        appendConfigurationTokenQueryItems(to: &queryItems)
        components.queryItems = queryItems

        guard let url = components.url else { throw AppAgentConfigurationServiceError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        // AppAgentConfigurationStore already owns the product-level TTL.
        // Once it decides to refresh, bypass URLCache so a newly published
        // Agent skill/tool policy becomes effective in the same request.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw AppAgentConfigurationServiceError.invalidResponse
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AppAgentRemoteConfiguration.self, from: data)
    }

    private func appendConfigurationTokenQueryItems(to queryItems: inout [URLQueryItem]) {
        guard let token = SecureConfig.apiToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else { return }
        queryItems.append(URLQueryItem(name: "token", value: token))
        queryItems.append(URLQueryItem(name: "deviceId", value: DeviceIdentifier.uuid))
    }
}
