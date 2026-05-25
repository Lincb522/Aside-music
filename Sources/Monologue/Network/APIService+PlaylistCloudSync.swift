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
            let baseURL = playlistCloudSyncURL(),
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "deviceId", value: playlistCloudSyncDeviceId)
        ]

        guard let url = components.url else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        return request
    }

    func fetchCloudPlaylistSnapshot() async throws -> LocalPlaylistCloudFetchResponse? {
        guard let request = playlistCloudRequest(method: "GET") else {
            return nil
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
