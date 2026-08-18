import Foundation

actor SongContentDetailCache {
    static let shared = SongContentDetailCache()

    private struct Entry: Codable {
        let canonicalSongID: String
        let response: SongContentDetailResponse
        let storedAt: Date
    }

    private enum Keys {
        static let entries = "songContent.publishedDetail.entries"
        static let identityIndex = "songContent.publishedDetail.identityIndex"
    }

    private let defaults: UserDefaults
    private var entries: [String: Entry]
    private var identityIndex: [String: String]
    private var hasDiscardedMemoryEntries = false
    private let maximumEntries = 100

    @MainActor
    static func installMemoryManagement() {
        MonoMemoryEngine.shared.registerResource(
            id: "cache.song-content",
            priority: .retained,
            budgetWeight: 0.03,
            minimumBudgetBytes: 2 * 1_024 * 1_024,
            applyBudget: { _ in },
            trim: { context in
                await SongContentDetailCache.shared.trimMemory(context)
            }
        )
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = Self.decode([String: Entry].self, from: defaults.data(forKey: Keys.entries)) ?? [:]
        identityIndex = Self.decode([String: String].self, from: defaults.data(forKey: Keys.identityIndex)) ?? [:]
    }

    func response(for identity: SongContentRequestIdentity) -> SongContentDetailResponse? {
        if let canonicalID = identityIndex[identity.cacheKey],
           let entry = entries[canonicalID],
           entry.response.content?.hasPublishedCopy == true {
            return entry.response
        }
        guard hasDiscardedMemoryEntries else { return nil }
        restorePersistedEntriesIfNeeded()
        guard let canonicalID = identityIndex[identity.cacheKey],
              let entry = entries[canonicalID],
              entry.response.content?.hasPublishedCopy == true else { return nil }
        return entry.response
    }

    func storePublished(_ response: SongContentDetailResponse, for identity: SongContentRequestIdentity) {
        restorePersistedEntriesIfNeeded()
        guard let canonicalID = response.song?.id,
              response.content?.hasPublishedCopy == true else { return }
        entries[canonicalID] = Entry(canonicalSongID: canonicalID, response: response, storedAt: Date())
        identityIndex[identity.cacheKey] = canonicalID
        evictIfNeeded()
        persist()
    }

    func remove(for identity: SongContentRequestIdentity) {
        restorePersistedEntriesIfNeeded()
        guard let canonicalID = identityIndex.removeValue(forKey: identity.cacheKey) else { return }
        let stillReferenced = identityIndex.values.contains(canonicalID)
        if !stillReferenced { entries.removeValue(forKey: canonicalID) }
        persist()
    }

    private func evictIfNeeded() {
        guard entries.count > maximumEntries else { return }
        let removedIDs = entries.values
            .sorted { $0.storedAt < $1.storedAt }
            .prefix(entries.count - maximumEntries)
            .map(\.canonicalSongID)
        for id in removedIDs { entries.removeValue(forKey: id) }
        identityIndex = identityIndex.filter { entries[$0.value] != nil }
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(entries), forKey: Keys.entries)
        defaults.set(try? JSONEncoder().encode(identityIndex), forKey: Keys.identityIndex)
    }

    private func trimMemory(_ context: MonoMemoryEngine.TrimContext) -> MonoMemoryEngine.TrimResult {
        let target: Int
        switch context.level {
        case .routine: target = maximumEntries
        case .background: target = 20
        case .warning: target = 6
        case .critical: target = 0
        }
        guard entries.count > target else { return .none }

        let retainedIDs = Set(
            entries.values
                .sorted { $0.storedAt > $1.storedAt }
                .prefix(target)
                .map(\.canonicalSongID)
        )
        let beforeCount = entries.count
        entries = entries.filter { retainedIDs.contains($0.key) }
        identityIndex = identityIndex.filter { retainedIDs.contains($0.value) }
        hasDiscardedMemoryEntries = true
        let releasedCount = max(0, beforeCount - entries.count)
        return .init(
            releasedItemCount: releasedCount,
            // 内存压力路径不能为了统计释放量再次 JSON 编码整份内容；
            // 使用保守估算，避免回收动作本身制造新的峰值。
            estimatedReleasedBytes: releasedCount * 12 * 1_024,
            preservedItemCount: entries.count
        )
    }

    private func restorePersistedEntriesIfNeeded() {
        guard hasDiscardedMemoryEntries else { return }
        let persistedEntries = Self.decode([String: Entry].self, from: defaults.data(forKey: Keys.entries)) ?? [:]
        let persistedIndex = Self.decode([String: String].self, from: defaults.data(forKey: Keys.identityIndex)) ?? [:]
        entries = persistedEntries.merging(entries) { _, current in current }
        identityIndex = persistedIndex.merging(identityIndex) { _, current in current }
        hasDiscardedMemoryEntries = false
        evictIfNeeded()
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
