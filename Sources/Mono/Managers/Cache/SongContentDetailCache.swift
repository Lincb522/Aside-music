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
    private let maximumEntries = 100

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = Self.decode([String: Entry].self, from: defaults.data(forKey: Keys.entries)) ?? [:]
        identityIndex = Self.decode([String: String].self, from: defaults.data(forKey: Keys.identityIndex)) ?? [:]
    }

    func response(for identity: SongContentRequestIdentity) -> SongContentDetailResponse? {
        guard let canonicalID = identityIndex[identity.cacheKey],
              let entry = entries[canonicalID],
              entry.response.content?.hasPublishedCopy == true else {
            return nil
        }
        return entry.response
    }

    func storePublished(_ response: SongContentDetailResponse, for identity: SongContentRequestIdentity) {
        guard let canonicalID = response.song?.id,
              response.content?.hasPublishedCopy == true else { return }
        entries[canonicalID] = Entry(canonicalSongID: canonicalID, response: response, storedAt: Date())
        identityIndex[identity.cacheKey] = canonicalID
        evictIfNeeded()
        persist()
    }

    func remove(for identity: SongContentRequestIdentity) {
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

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
