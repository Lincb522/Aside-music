import Foundation

actor AppAgentConfigurationStore {
    static let shared = AppAgentConfigurationStore()

    private enum Keys {
        // 保留旧键以无损复用已经下发的 Agent 配置缓存。
        static let payload = "songContent.remoteConfiguration"
        static let fetchedAt = "songContent.remoteConfiguration.fetchedAt"
    }

    private let defaults: UserDefaults
    private var cached: AppAgentRemoteConfiguration
    private var fetchedAt: Date?
    private var refreshTask: Task<AppAgentRemoteConfiguration, Error>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.payload),
           let configuration = try? JSONDecoder().decode(AppAgentRemoteConfiguration.self, from: data) {
            cached = configuration
        } else {
            cached = .bundledDefault
        }
        fetchedAt = defaults.object(forKey: Keys.fetchedAt) as? Date
    }

    func configuration(forceRefresh: Bool = false) async -> AppAgentRemoteConfiguration {
        if !forceRefresh, isFresh {
            await synchronizeAudioAgentSkills(from: cached, source: .cached)
            return cached
        }
        if let refreshTask {
            if let configuration = try? await refreshTask.value {
                await synchronizeAudioAgentSkills(from: configuration, source: .server)
                return configuration
            }
            await synchronizeAudioAgentSkills(from: cached, source: .cached)
            return cached
        }

        let fallback = cached
        let task = Task<AppAgentRemoteConfiguration, Error> {
            try await APIService.shared.fetchAppAgentConfiguration()
        }
        refreshTask = task
        do {
            let configuration = try await task.value
            refreshTask = nil
            cached = configuration
            fetchedAt = Date()
            persist(configuration)
            await synchronizeAudioAgentSkills(from: configuration, source: .server)
            return configuration
        } catch {
            refreshTask = nil
            AppLogger.debug("App Agent configuration unavailable: \(error)")
            await synchronizeAudioAgentSkills(from: fallback, source: .cached)
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
              let configuration = try? JSONDecoder().decode(AppAgentRemoteConfiguration.self, from: data),
              configuration.agentManagementEnabled == true else { return nil }
        return configuration.agents?[identifier]
    }

    private var isFresh: Bool {
        guard let fetchedAt else { return false }
        return Date().timeIntervalSince(fetchedAt) < TimeInterval(max(30, cached.cacheMaxAgeSeconds))
    }

    private func persist(_ configuration: AppAgentRemoteConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: Keys.payload)
        defaults.set(fetchedAt, forKey: Keys.fetchedAt)
    }

    private func synchronizeAudioAgentSkills(
        from configuration: AppAgentRemoteConfiguration,
        source: MonoAudioAgentSkillConfigurationSource
    ) async {
        let equalizer = configuration.agentManagementEnabled == true
            ? configuration.agents?[.equalizer]
            : nil
        await MainActor.run {
            MonoAudioAgentSkillStore.shared.applyRemoteAgentConfiguration(
                equalizer,
                source: source
            )
        }
    }
}
