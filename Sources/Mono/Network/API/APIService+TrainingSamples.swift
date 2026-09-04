import Foundation

struct CloudTrainingSampleUploadResponse: Decodable, Sendable {
    struct Accepted: Decodable, Sendable {
        var id: String
        var state: String
    }

    struct Rejected: Decodable, Sendable {
        var id: String?
        var reason: String
    }

    var ok: Bool
    var accepted: [Accepted]
    var rejected: [Rejected]
    var stored: Int
    var updated: Int
    var accountSampleCount: Int
    var accountByteCount: Int
}

extension APIService {
    private var trainingSamplePath: String { "/_admin/api/account/training-samples" }

    private func trainingSampleRequest(method: String) -> URLRequest? {
        guard let token = SecureConfig.apiToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty,
              var components = URLComponents(string: SecureConfig.apiBaseURL(for: .primary)) else {
            return nil
        }
        let currentPath = components.path
        components.path = currentPath.hasSuffix("/")
            ? "\(currentPath)\(trainingSamplePath.dropFirst())"
            : "\(currentPath)\(trainingSamplePath)"
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Api-Token")
        let deviceID = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.playlistSyncDeviceId)
            ?? DeviceIdentifier.uuid
        request.setValue(deviceID, forHTTPHeaderField: "X-Device-ID")
        return request
    }

    /// Uploads a small batch of complete tuning samples to the dedicated intake.
    /// The server caps batches at 16 samples and 64 KB per sample.
    func uploadTrainingSamples(
        _ samples: [CloudAIEqualizerTrainingSample]
    ) async throws -> CloudTrainingSampleUploadResponse {
        guard var request = trainingSampleRequest(method: "PUT") else {
            throw URLError(.userAuthenticationRequired)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(["samples": samples])

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
        return try JSONDecoder().decode(CloudTrainingSampleUploadResponse.self, from: data)
    }

    func deleteTrainingSamples() async throws {
        guard let request = trainingSampleRequest(method: "DELETE") else {
            throw URLError(.userAuthenticationRequired)
        }
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        }
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
