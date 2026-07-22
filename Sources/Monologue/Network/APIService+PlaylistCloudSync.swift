import Foundation

extension APIService {
    private var playlistCloudSyncPath: String { "/_admin/api/account/playlists" }

    private var playlistCloudSyncDeviceId: String {
        if let stored = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.playlistSyncDeviceId)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !stored.isEmpty {
            return stored
        }

        let generated = DeviceIdentifier.uuid
        UserDefaults.standard.set(generated, forKey: AppConfig.StorageKeys.playlistSyncDeviceId)
        return generated
    }

    private func playlistCloudSyncURL() -> URL? {
        guard var components = URLComponents(string: SecureConfig.apiBaseURL) else {
            return nil
        }

        let currentPath = components.path
        components.path = currentPath.hasSuffix("/")
            ? "\(currentPath)\(playlistCloudSyncPath.dropFirst())"
            : "\(currentPath)\(playlistCloudSyncPath)"
        return components.url
    }

    private func playlistCloudRequest(method: String) -> URLRequest? {
        guard
            let token = SecureConfig.apiToken?.trimmingCharacters(in: .whitespacesAndNewlines),
            !token.isEmpty,
            let url = playlistCloudSyncURL()
        else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 45
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        // Keep credentials out of URLs and nginx access logs. The server still
        // accepts legacy query parameters for older app versions.
        request.setValue(token, forHTTPHeaderField: "X-Api-Token")
        request.setValue(playlistCloudSyncDeviceId, forHTTPHeaderField: "X-Device-ID")
        return request
    }

    func fetchCloudPlaylistSnapshot(
        ifChangedFrom knownRevision: String? = nil
    ) async throws -> LocalPlaylistCloudFetchResponse? {
        guard var request = playlistCloudRequest(method: "GET") else {
            return nil
        }
        if let knownRevision = knownRevision?.trimmingCharacters(in: .whitespacesAndNewlines),
           !knownRevision.isEmpty {
            request.setValue("\"\(knownRevision)\"", forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode == 304 {
            return nil
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        }
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LocalPlaylistCloudFetchResponse.self, from: data)
    }

    func uploadCloudPlaylistSnapshot(_ snapshot: LocalPlaylistCloudSnapshot) async throws -> LocalPlaylistCloudUploadResponse {
        guard var request = playlistCloudRequest(method: "PUT") else {
            throw URLError(.userAuthenticationRequired)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(snapshot)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        }
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LocalPlaylistCloudUploadResponse.self, from: data)
    }

    func deleteCloudPlaylistSnapshot() async throws -> LocalPlaylistCloudDeleteResponse {
        guard let request = playlistCloudRequest(method: "DELETE") else {
            throw URLError(.userAuthenticationRequired)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        }
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LocalPlaylistCloudDeleteResponse.self, from: data)
    }
}
