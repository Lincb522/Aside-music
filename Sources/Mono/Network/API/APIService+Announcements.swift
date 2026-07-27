import Foundation

enum AnnouncementManifestFetchResult {
    case notModified(etag: String?)
    case value(AppAnnouncementManifestResponse, etag: String?)
}

extension APIService {
    func fetchAnnouncementManifest(etag: String?) async throws -> AnnouncementManifestFetchResult {
        var components = try announcementURLComponents(path: "/api/public/announcements/manifest")
        appendAnnouncementContext(to: &components, includeVersion: true)
        guard let url = components.url else { throw AnnouncementServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let etag, !etag.isEmpty { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AnnouncementServiceError.invalidResponse }
        let responseETag = http.value(forHTTPHeaderField: "ETag")
        if http.statusCode == 304 { return .notModified(etag: responseETag ?? etag) }
        guard (200...299).contains(http.statusCode) else { throw AnnouncementServiceError.invalidResponse }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return .value(try decoder.decode(AppAnnouncementManifestResponse.self, from: data), etag: responseETag)
    }

    func fetchAnnouncementDetail(id: String, displayRevision: Int) async throws -> AppAnnouncement {
        let safeID = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        var components = try announcementURLComponents(path: "/api/public/announcements/\(safeID)")
        appendAnnouncementContext(to: &components, includeVersion: true)
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "revision", value: String(displayRevision)))
        components.queryItems = items
        guard let url = components.url else { throw AnnouncementServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw AnnouncementServiceError.unavailable
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AppAnnouncementDetailResponse.self, from: data).announcement
    }

    private func announcementURLComponents(path route: String) throws -> URLComponents {
        guard var components = URLComponents(string: SecureConfig.apiBaseURL) else {
            throw AnnouncementServiceError.invalidURL
        }
        components.path = components.path.hasSuffix("/")
            ? "\(components.path)\(route.dropFirst())"
            : "\(components.path)\(route)"
        return components
    }

    private func appendAnnouncementContext(to components: inout URLComponents, includeVersion: Bool) {
        var items = components.queryItems ?? []
        if includeVersion {
            items.append(URLQueryItem(
                name: "app_version",
                value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ))
            items.append(URLQueryItem(
                name: "app_build",
                value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            ))
        }
        items.append(URLQueryItem(name: "platform", value: "ios"))
        items.append(URLQueryItem(name: "locale", value: Locale.preferredLanguages.first ?? "zh-CN"))
        if let token = SecureConfig.apiToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            items.append(URLQueryItem(name: "token", value: token))
            items.append(URLQueryItem(name: "deviceId", value: DeviceIdentifier.uuid))
        }
        components.queryItems = items
    }
}

enum AnnouncementServiceError: Error {
    case invalidURL
    case invalidResponse
    case unavailable
}
