import Foundation
@preconcurrency import Combine

@MainActor
final class AIProviderConfigurationStore: ObservableObject {
    static let shared = AIProviderConfigurationStore()

    private enum Keys {
        static let wireProtocol = "ai.eq.provider.protocol"
        static let baseURL = "ai.eq.provider.base-url"
        static let model = "ai.eq.provider.model"
        static let modelDiscoveryURL = "ai.eq.provider.model-discovery-url"
        static let timeout = "ai.eq.provider.timeout"
        static let customHeaders = "ai.eq.provider.custom-headers"
        static let legacyAPIKey = "ai.eq.provider.api-key"
        static let dailyRequestLimit = "ai.eq.usage.daily-limit"
        static let hourlyRequestLimit = "ai.eq.usage.hourly-limit"
        static let minimumRequestInterval = "ai.eq.usage.minimum-interval"
    }

    @Published var wireProtocol: AIWireProtocol {
        didSet {
            saveIfReady()
            loadAPIKeyForSelectedProtocolIfReady()
        }
    }
    @Published var baseURL: String { didSet { saveIfReady() } }
    @Published var model: String { didSet { saveIfReady() } }
    @Published var modelDiscoveryURL: String { didSet { saveIfReady() } }
    @Published var timeout: Double { didSet { saveIfReady() } }
    @Published var customHeadersJSON: String { didSet { saveIfReady() } }
    @Published var apiKey: String { didSet { saveKeyIfReady() } }
    @Published var dailyRequestLimit: Int { didSet { saveIfReady() } }
    @Published var hourlyRequestLimit: Int { didSet { saveIfReady() } }
    @Published var minimumRequestInterval: Double { didSet { saveIfReady() } }

    private var isReady = false
    private var isLoadingAPIKey = false

    private init() {
        let defaults = UserDefaults.standard
        let builtInProtocol = Self.builtInProtocol
        let selectedProtocol = defaults.string(forKey: Keys.wireProtocol)
            .flatMap(AIWireProtocol.init(rawValue:)) ?? builtInProtocol
        let initialBaseURL = defaults.object(forKey: Keys.baseURL) as? String
            ?? Self.defaultBaseURL(for: selectedProtocol)
        let initialModel = defaults.object(forKey: Keys.model) as? String
            ?? Self.defaultModel(for: selectedProtocol)
        let initialModelDiscoveryURL = defaults.object(forKey: Keys.modelDiscoveryURL) as? String ?? ""
        let savedTimeout = defaults.double(forKey: Keys.timeout)
        let initialTimeout = savedTimeout > 0 ? savedTimeout : 45
        let initialCustomHeaders = defaults.object(forKey: Keys.customHeaders) as? String ?? ""
        let providerKey = KeychainHelper.loadString(key: Self.apiKeyStorageKey(for: selectedProtocol))
        let hasExplicitKeyOverride = defaults.bool(forKey: Self.apiKeyOverrideStorageKey(for: selectedProtocol))
        let initialKey = providerKey
            ?? KeychainHelper.loadString(key: Keys.legacyAPIKey)
            ?? (hasExplicitKeyOverride ? nil : Self.bundledAPIKey(for: selectedProtocol))
            ?? ""

        wireProtocol = selectedProtocol
        baseURL = initialBaseURL
        model = initialModel
        modelDiscoveryURL = initialModelDiscoveryURL
        timeout = initialTimeout
        customHeadersJSON = initialCustomHeaders
        apiKey = initialKey
        dailyRequestLimit = defaults.object(forKey: Keys.dailyRequestLimit) as? Int ?? 50
        hourlyRequestLimit = defaults.object(forKey: Keys.hourlyRequestLimit) as? Int ?? 20
        minimumRequestInterval = defaults.object(forKey: Keys.minimumRequestInterval) as? Double ?? 15
        isReady = true

        if providerKey == nil, !initialKey.isEmpty {
            KeychainHelper.save(key: Self.apiKeyStorageKey(for: selectedProtocol), value: initialKey)
        }
    }

    var configuration: AIProviderConfiguration {
        AIProviderConfiguration(
            wireProtocol: wireProtocol,
            baseURL: baseURL,
            model: model,
            modelDiscoveryURL: modelDiscoveryURL,
            timeout: min(120, max(10, timeout)),
            customHeadersJSON: customHeadersJSON
        )
    }

    var usageLimits: AIUsageLimits {
        AIUsageLimits(
            dailyRequestLimit: min(10_000, max(0, dailyRequestLimit)),
            hourlyRequestLimit: min(1_000, max(0, hourlyRequestLimit)),
            minimumRequestInterval: min(3_600, max(0, minimumRequestInterval))
        )
    }

    var displayModel: String { configuration.resolvedModel }

    func useProtocolDefaults() {
        baseURL = Self.defaultBaseURL(for: wireProtocol)
        model = Self.defaultModel(for: wireProtocol)
        modelDiscoveryURL = ""
        customHeadersJSON = ""
    }

    func resetDeveloperOverride() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.wireProtocol)
        defaults.removeObject(forKey: Keys.baseURL)
        defaults.removeObject(forKey: Keys.model)
        defaults.removeObject(forKey: Keys.modelDiscoveryURL)
        defaults.removeObject(forKey: Keys.timeout)
        defaults.removeObject(forKey: Keys.customHeaders)
        defaults.removeObject(forKey: Keys.dailyRequestLimit)
        defaults.removeObject(forKey: Keys.hourlyRequestLimit)
        defaults.removeObject(forKey: Keys.minimumRequestInterval)
        for item in AIWireProtocol.allCases {
            KeychainHelper.delete(key: Self.apiKeyStorageKey(for: item))
            defaults.removeObject(forKey: Self.apiKeyOverrideStorageKey(for: item))
        }
        KeychainHelper.delete(key: Keys.legacyAPIKey)

        let builtInProtocol = Self.builtInProtocol
        wireProtocol = builtInProtocol
        baseURL = Self.defaultBaseURL(for: builtInProtocol)
        model = Self.defaultModel(for: builtInProtocol)
        modelDiscoveryURL = ""
        timeout = 45
        customHeadersJSON = ""
        isLoadingAPIKey = true
        apiKey = Self.bundledAPIKey(for: builtInProtocol) ?? ""
        isLoadingAPIKey = false
        if !apiKey.isEmpty {
            KeychainHelper.save(key: Self.apiKeyStorageKey(for: builtInProtocol), value: apiKey)
        }
        dailyRequestLimit = 50
        hourlyRequestLimit = 20
        minimumRequestInterval = 15
    }

    private func saveIfReady() {
        guard isReady else { return }
        let defaults = UserDefaults.standard
        defaults.set(wireProtocol.rawValue, forKey: Keys.wireProtocol)
        defaults.set(baseURL, forKey: Keys.baseURL)
        defaults.set(model, forKey: Keys.model)
        defaults.set(modelDiscoveryURL, forKey: Keys.modelDiscoveryURL)
        defaults.set(min(120, max(10, timeout)), forKey: Keys.timeout)
        defaults.set(customHeadersJSON, forKey: Keys.customHeaders)
        defaults.set(min(10_000, max(0, dailyRequestLimit)), forKey: Keys.dailyRequestLimit)
        defaults.set(min(1_000, max(0, hourlyRequestLimit)), forKey: Keys.hourlyRequestLimit)
        defaults.set(min(3_600, max(0, minimumRequestInterval)), forKey: Keys.minimumRequestInterval)
    }

    private func saveKeyIfReady() {
        guard isReady, !isLoadingAPIKey else { return }
        let normalized = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let storageKey = Self.apiKeyStorageKey(for: wireProtocol)
        UserDefaults.standard.set(true, forKey: Self.apiKeyOverrideStorageKey(for: wireProtocol))
        if normalized.isEmpty {
            KeychainHelper.delete(key: storageKey)
        } else {
            KeychainHelper.save(key: storageKey, value: normalized)
        }
    }

    private func loadAPIKeyForSelectedProtocolIfReady() {
        guard isReady else { return }
        let hasExplicitOverride = UserDefaults.standard.bool(
            forKey: Self.apiKeyOverrideStorageKey(for: wireProtocol)
        )
        isLoadingAPIKey = true
        apiKey = KeychainHelper.loadString(key: Self.apiKeyStorageKey(for: wireProtocol))
            ?? (hasExplicitOverride ? nil : Self.bundledAPIKey(for: wireProtocol))
            ?? ""
        isLoadingAPIKey = false
    }

    private static func apiKeyStorageKey(for wireProtocol: AIWireProtocol) -> String {
        "ai.eq.provider.api-key.\(wireProtocol.rawValue)"
    }

    private static func apiKeyOverrideStorageKey(for wireProtocol: AIWireProtocol) -> String {
        "ai.eq.provider.api-key-overridden.\(wireProtocol.rawValue)"
    }

    private static var builtInProtocol: AIWireProtocol {
        bundleString("AI_PROVIDER_PROTOCOL")
            .flatMap(AIWireProtocol.init(rawValue:)) ?? .appleIntelligence
    }

    private static func defaultBaseURL(for wireProtocol: AIWireProtocol) -> String {
        guard wireProtocol == builtInProtocol else { return wireProtocol.defaultBaseURL }
        return bundleString("AI_PROVIDER_BASE_URL") ?? wireProtocol.defaultBaseURL
    }

    private static func defaultModel(for wireProtocol: AIWireProtocol) -> String {
        guard wireProtocol == builtInProtocol else { return wireProtocol.defaultModel }
        return bundleString("AI_PROVIDER_MODEL") ?? ""
    }

    private static func bundledAPIKey(for wireProtocol: AIWireProtocol) -> String? {
        guard wireProtocol == builtInProtocol else { return nil }
        return bundleString("AI_PROVIDER_API_KEY")
    }

    private static func bundleString(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !normalized.hasPrefix("$(") else { return nil }
        return normalized
    }
}
