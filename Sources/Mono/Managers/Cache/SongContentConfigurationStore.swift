import Foundation

actor SongContentConfigurationStore {
    static let shared = SongContentConfigurationStore()

    private enum Keys {
        static let payload = "songContent.remoteConfiguration"
        static let fetchedAt = "songContent.remoteConfiguration.fetchedAt"
    }

    private let defaults: UserDefaults
    private var cached: SongContentFeatureConfiguration
    private var fetchedAt: Date?
    private var refreshTask: Task<SongContentFeatureConfiguration, Error>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.payload),
           let configuration = try? JSONDecoder().decode(SongContentFeatureConfiguration.self, from: data) {
            cached = configuration
        } else {
            cached = .bundledDefault
        }
        fetchedAt = defaults.object(forKey: Keys.fetchedAt) as? Date
    }

    func configuration(forceRefresh: Bool = false) async -> SongContentFeatureConfiguration {
        if !forceRefresh, isFresh { return cached }
        if let refreshTask {
            return (try? await refreshTask.value) ?? cached
        }

        let fallback = cached
        let task = Task<SongContentFeatureConfiguration, Error> {
            try await APIService.shared.fetchSongContentConfiguration()
        }
        refreshTask = task
        do {
            let configuration = try await task.value
            refreshTask = nil
            cached = configuration
            fetchedAt = Date()
            persist(configuration)
            return configuration
        } catch {
            refreshTask = nil
            AppLogger.debug("Song content configuration unavailable: \(error)")
            return fallback
        }
    }

    func agentConfiguration(
        _ identifier: AppAgentIdentifier,
        forceRefresh: Bool = false
    ) async -> AppAgentConfiguration? {
        let configuration = await configuration(forceRefresh: forceRefresh)
        guard configuration.agentManagementEnabled == true else { return nil }
        return configuration.agents?[identifier]
    }

    static func cachedAgentConfiguration(_ identifier: AppAgentIdentifier) -> AppAgentConfiguration? {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Keys.payload),
              let configuration = try? JSONDecoder().decode(SongContentFeatureConfiguration.self, from: data),
              configuration.agentManagementEnabled == true else { return nil }
        return configuration.agents?[identifier]
    }

    private var isFresh: Bool {
        guard let fetchedAt else { return false }
        return Date().timeIntervalSince(fetchedAt) < TimeInterval(max(30, cached.cacheMaxAgeSeconds))
    }

    private func persist(_ configuration: SongContentFeatureConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: Keys.payload)
        defaults.set(fetchedAt, forKey: Keys.fetchedAt)
    }
}
