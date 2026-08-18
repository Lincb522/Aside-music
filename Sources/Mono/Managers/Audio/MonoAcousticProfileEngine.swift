import Foundation
import FFmpegSwiftSDK

struct MonoAcousticFilter: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case peak = "peak_dip"
        case lowShelf = "low_shelf"
        case highShelf = "high_shelf"
        case lowPass = "low_pass"
        case highPass = "high_pass"
        case bandPass = "band_pass"
        case notch = "band_stop"
    }

    let kind: Kind
    let frequency: Float
    let gainDB: Float
    let q: Float
    let slope: Float?
}

struct MonoAcousticProfile: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let productID: String
    let vendor: String
    let product: String
    let subtype: String
    let author: String
    let details: String
    let sourceURL: String?
    let artworkPath: String?
    let preampDB: Float
    let filters: [MonoAcousticFilter]

    var displayName: String {
        vendor.isEmpty ? product : "\(vendor) \(product)"
    }

    var searchIndex: String {
        "\(vendor) \(product) \(author) \(details)".folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
    }

    var attributionURL: URL? {
        URL(string: sourceURL ?? "https://github.com/opra-project/OPRA")
    }

    func graphicGains(mode: GraphicEQMode) -> [Float] {
        mode.centerFrequencies.map { frequency in
            filters.reduce(Float(0)) { partial, filter in
                partial + Self.response(of: filter, at: frequency)
            }
        }
        .map { min(6, max(-6, $0)) }
    }

    private static func response(of filter: MonoAcousticFilter, at frequency: Float) -> Float {
        let center = max(20, filter.frequency)
        let octaveDistance = log2f(max(frequency, 20) / center)
        let q = min(12, max(0.1, filter.q))

        switch filter.kind {
        case .peak:
            let width = max(0.08, 0.72 / q)
            return filter.gainDB * expf(-0.5 * powf(octaveDistance / width, 2))
        case .lowShelf:
            let transition = 1 / (1 + expf(octaveDistance * max(1.8, q * 2.4)))
            return filter.gainDB * transition
        case .highShelf:
            let transition = 1 / (1 + expf(-octaveDistance * max(1.8, q * 2.4)))
            return filter.gainDB * transition
        case .lowPass:
            guard frequency > center else { return 0 }
            return -min(18, abs(octaveDistance) * max(6, filter.slope ?? 12))
        case .highPass:
            guard frequency < center else { return 0 }
            return -min(18, abs(octaveDistance) * max(6, filter.slope ?? 12))
        case .bandPass:
            let width = max(0.1, 0.75 / q)
            return -min(18, abs(octaveDistance) / width * 6)
        case .notch:
            let width = max(0.04, 0.35 / q)
            return -12 * expf(-0.5 * powf(octaveDistance / width, 2))
        }
    }
}

private struct OPRAProduct: Sendable {
    let id: String
    let vendorID: String
    let name: String
    let subtype: String
    let artworkPath: String?
}

private struct OPRAPendingEQ: Sendable {
    let id: String
    let productID: String
    let author: String
    let details: String
    let sourceURL: String?
    let preampDB: Float
    let filters: [MonoAcousticFilter]
}

@MainActor
final class MonoAcousticProfileEngine: ObservableObject {
    static let shared = MonoAcousticProfileEngine()

    @Published private(set) var profiles: [MonoAcousticProfile] = [] {
        didSet { scheduleSearch() }
    }
    @Published private(set) var filteredProfiles: [MonoAcousticProfile] = []
    @Published private(set) var favoriteIDs: Set<String>
    @Published private(set) var recentIDs: [String]
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var errorMessage: String?
    @Published var query = "" {
        didSet { scheduleSearch() }
    }

    private let databaseURL = URL(string: "https://opra.roonlabs.net/database_v1.jsonl")!
    private let cacheURL: URL
    private let defaults = UserDefaults.standard
    private let lastUpdatedKey = "mono.acoustic.opra.last-updated"
    private let etagKey = "mono.acoustic.opra.etag"
    private let modifiedKey = "mono.acoustic.opra.last-modified"
    private let favoritesKey = "mono.acoustic.opra.favorites"
    private let recentsKey = "mono.acoustic.opra.recents"
    private var refreshTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    var catalogCount: Int { profiles.count }

    private init() {
        favoriteIDs = Set(defaults.stringArray(forKey: favoritesKey) ?? [])
        recentIDs = defaults.stringArray(forKey: recentsKey) ?? []
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = support.appendingPathComponent("MonoAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        cacheURL = directory.appendingPathComponent("opra-database-v1.jsonl")
        lastUpdatedAt = defaults.object(forKey: lastUpdatedKey) as? Date
        loadCachedCatalog()
    }

    func refreshIfNeeded() {
        guard !isRefreshing else { return }
        if profiles.isEmpty || lastUpdatedAt.map({ Date().timeIntervalSince($0) > 7 * 86_400 }) != false {
            refresh()
        }
    }

    func refresh() {
        refreshTask?.cancel()
        isRefreshing = true
        errorMessage = nil
        refreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                var request = URLRequest(url: databaseURL)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.timeoutInterval = 45
                if let etag = defaults.string(forKey: etagKey), !etag.isEmpty {
                    request.setValue(etag, forHTTPHeaderField: "If-None-Match")
                }
                if let modified = defaults.string(forKey: modifiedKey), !modified.isEmpty {
                    request.setValue(modified, forHTTPHeaderField: "If-Modified-Since")
                }
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                if http.statusCode == 304 {
                    lastUpdatedAt = Date()
                    defaults.set(lastUpdatedAt, forKey: lastUpdatedKey)
                    isRefreshing = false
                    return
                }
                guard (200..<300).contains(http.statusCode), !data.isEmpty else {
                    throw URLError(.badServerResponse)
                }
                let decoded = try await Task.detached(priority: .utility) {
                    try Self.decodeDatabase(data)
                }.value
                try data.write(to: cacheURL, options: .atomic)
                profiles = decoded
                lastUpdatedAt = Date()
                defaults.set(lastUpdatedAt, forKey: lastUpdatedKey)
                if let etag = http.value(forHTTPHeaderField: "ETag") {
                    defaults.set(etag, forKey: etagKey)
                }
                if let modified = http.value(forHTTPHeaderField: "Last-Modified") {
                    defaults.set(modified, forKey: modifiedKey)
                }
                errorMessage = nil
            } catch is CancellationError {
                // A new refresh superseded this request.
            } catch {
                errorMessage = error.localizedDescription
            }
            isRefreshing = false
        }
    }

    func apply(_ profile: MonoAcousticProfile) {
        recordUsage(profile.id)
        EQManager.shared.installAcousticProfile(profile)
    }

    func isFavorite(_ profile: MonoAcousticProfile) -> Bool {
        favoriteIDs.contains(profile.id)
    }

    func toggleFavorite(_ profile: MonoAcousticProfile) {
        if favoriteIDs.contains(profile.id) {
            favoriteIDs.remove(profile.id)
        } else {
            favoriteIDs.insert(profile.id)
        }
        defaults.set(Array(favoriteIDs).sorted(), forKey: favoritesKey)
        scheduleSearch(immediate: true)
    }

    func bestRouteMatch(for routeName: String) -> MonoAcousticProfile? {
        let normalized = routeName.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        guard normalized.count >= 3 else { return nil }
        return profiles.first { profile in
            normalized.contains(profile.product.folding(options: .caseInsensitive, locale: .current))
                && (profile.vendor.isEmpty || normalized.contains(profile.vendor.folding(options: .caseInsensitive, locale: .current)))
        }
    }

    private func loadCachedCatalog() {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }
        let url = cacheURL
        Task { [weak self] in
            do {
                let data = try await Task.detached(priority: .utility) { try Data(contentsOf: url) }.value
                let decoded = try await Task.detached(priority: .utility) { try Self.decodeDatabase(data) }.value
                self?.profiles = decoded
            } catch {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    private func recordUsage(_ id: String) {
        recentIDs.removeAll { $0 == id }
        recentIDs.insert(id, at: 0)
        if recentIDs.count > 24 {
            recentIDs.removeLast(recentIDs.count - 24)
        }
        defaults.set(recentIDs, forKey: recentsKey)
        scheduleSearch(immediate: true)
    }

    private func scheduleSearch(immediate: Bool = false) {
        searchTask?.cancel()
        let snapshot = profiles
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        let favorites = favoriteIDs
        let recents = recentIDs
        searchTask = Task { [weak self] in
            if !immediate {
                try? await Task.sleep(for: .milliseconds(120))
            }
            guard !Task.isCancelled else { return }
            let result = await Task.detached(priority: .userInitiated) {
                Self.search(
                    profiles: snapshot,
                    needle: needle,
                    favorites: favorites,
                    recents: recents
                )
            }.value
            guard !Task.isCancelled else { return }
            self?.filteredProfiles = result
        }
    }

    nonisolated private static func search(
        profiles: [MonoAcousticProfile],
        needle: String,
        favorites: Set<String>,
        recents: [String]
    ) -> [MonoAcousticProfile] {
        if !needle.isEmpty {
            return profiles.lazy
                .filter { $0.searchIndex.contains(needle) }
                .prefix(160)
                .map { $0 }
        }

        let byID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        var result: [MonoAcousticProfile] = []
        var used = Set<String>()
        result.reserveCapacity(160)
        for id in favorites.sorted() + recents {
            guard used.insert(id).inserted, let profile = byID[id] else { continue }
            result.append(profile)
        }
        for profile in profiles where result.count < 160 {
            guard used.insert(profile.id).inserted else { continue }
            result.append(profile)
        }
        return result
    }

    nonisolated private static func decodeDatabase(_ data: Data) throws -> [MonoAcousticProfile] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        var vendors: [String: String] = [:]
        var products: [String: OPRAProduct] = [:]
        var equalizers: [OPRAPendingEQ] = []
        vendors.reserveCapacity(400)
        products.reserveCapacity(6_000)
        equalizers.reserveCapacity(14_000)

        for line in text.split(separator: "\n") where !line.isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let object = try JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = object["type"] as? String,
                  let id = object["id"] as? String,
                  let payload = object["data"] as? [String: Any] else { continue }

            switch type {
            case "vendor":
                if let name = payload["name"] as? String { vendors[id] = name }
            case "product":
                guard let name = payload["name"] as? String else { continue }
                products[id] = OPRAProduct(
                    id: id,
                    vendorID: payload["vendor_id"] as? String ?? "",
                    name: name,
                    subtype: payload["subtype"] as? String ?? "",
                    artworkPath: payload["line_art_96x64_png"] as? String
                )
            case "eq":
                guard let productID = payload["product_id"] as? String,
                      let parameters = payload["parameters"] as? [String: Any],
                      let rawBands = parameters["bands"] as? [[String: Any]] else { continue }
                let filters = rawBands.compactMap { raw -> MonoAcousticFilter? in
                    guard let rawType = raw["type"] as? String,
                          let kind = MonoAcousticFilter.Kind(rawValue: rawType),
                          let frequency = number(raw["frequency"]) else { return nil }
                    return MonoAcousticFilter(
                        kind: kind,
                        frequency: frequency,
                        gainDB: number(raw["gain_db"]) ?? 0,
                        q: number(raw["q"]) ?? 0.707,
                        slope: number(raw["slope"])
                    )
                }
                guard !filters.isEmpty else { continue }
                equalizers.append(
                    OPRAPendingEQ(
                        id: id,
                        productID: productID,
                        author: payload["author"] as? String ?? "OPRA",
                        details: payload["details"] as? String ?? "",
                        sourceURL: payload["link"] as? String,
                        preampDB: number(parameters["gain_db"]) ?? 0,
                        filters: filters
                    )
                )
            default:
                break
            }
        }

        return equalizers.compactMap { equalizer in
            guard let product = products[equalizer.productID] else { return nil }
            return MonoAcousticProfile(
                id: equalizer.id,
                productID: equalizer.productID,
                vendor: vendors[product.vendorID] ?? product.vendorID.replacingOccurrences(of: "_", with: " ").capitalized,
                product: product.name,
                subtype: product.subtype,
                author: equalizer.author,
                details: equalizer.details,
                sourceURL: equalizer.sourceURL,
                artworkPath: product.artworkPath,
                preampDB: min(0, max(-18, equalizer.preampDB)),
                filters: Array(equalizer.filters.prefix(12))
            )
        }
        .sorted {
            if $0.displayName != $1.displayName { return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            return $0.author.localizedStandardCompare($1.author) == .orderedAscending
        }
    }

    nonisolated private static func number(_ value: Any?) -> Float? {
        if let value = value as? NSNumber { return value.floatValue }
        if let value = value as? String { return Float(value) }
        return nil
    }
}
