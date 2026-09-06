import Foundation
@preconcurrency import Combine

struct AIPersonalProviderSettings: Codable, Equatable, Sendable {
    var isEnabled = false
    var configuration = AIProviderConfiguration(
        wireProtocol: .openAICompatible,
        baseURL: "",
        model: "",
        modelDiscoveryURL: "",
        timeout: 45,
        customHeadersJSON: ""
    )
    var apiKey = ""

    func validated() throws -> Self {
        var value = self
        value.configuration.baseURL = configuration.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        value.configuration.model = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)
        value.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEnabled else { return value }
        guard value.configuration.wireProtocol.supportsCustomEndpoint,
              let url = URLComponents(string: value.configuration.resolvedBaseURL),
              let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.fragment == nil,
              url.url != nil else {
            throw AIPersonalProviderError.invalidEndpoint
        }
        guard !value.configuration.model.isEmpty else {
            throw AIPersonalProviderError.missingModel
        }
        if value.configuration.wireProtocol.requiresAPIKey, value.apiKey.isEmpty {
            throw AIEqualizerError.missingAPIKey
        }
        return value
    }
}

enum AIPersonalProviderError: LocalizedError {
    case invalidEndpoint
    case missingModel
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: return String(localized: "ai_config_invalid_endpoint")
        case .missingModel: return String(localized: "ai_config_missing_model")
        case .saveFailed: return String(localized: "ai_config_save_failed")
        }
    }
}

/// Keep the endpoint and its credentials together across discovery, sampling and retries.
struct AIProviderRequestContext: Sendable {
    var configuration: AIProviderConfiguration
    let apiKey: String
    let usageLimits: AIUsageLimits?
    let persistsDiscoveredModel: Bool

    static func resolve(
        personal: AIPersonalProviderSettings,
        defaultContext: () -> Self
    ) throws -> Self {
        guard personal.isEnabled else { return defaultContext() }
        let settings = try personal.validated()
        return Self(
            configuration: settings.configuration,
            apiKey: settings.apiKey,
            usageLimits: nil,
            persistsDiscoveredModel: false
        )
    }
}

@MainActor
final class AIPersonalProviderStore: ObservableObject {
    static let shared = AIPersonalProviderStore()
    @Published private(set) var settings: AIPersonalProviderSettings
    private let persist: (Data) -> Bool

    init(
        load: () -> Data? = { KeychainHelper.loadData(key: "ai.personal.provider.settings") },
        persist: @escaping (Data) -> Bool = { data in
            KeychainHelper.save(key: "ai.personal.provider.settings", data: data)
            return KeychainHelper.loadData(key: "ai.personal.provider.settings") == data
        }
    ) {
        settings = load().flatMap { try? JSONDecoder().decode(AIPersonalProviderSettings.self, from: $0) }
            ?? AIPersonalProviderSettings()
        self.persist = persist
    }

    func save(_ draft: AIPersonalProviderSettings) throws {
        let value = try draft.validated()
        let data = try JSONEncoder().encode(value)
        guard persist(data) else { throw AIPersonalProviderError.saveFailed }
        settings = value
    }
}
