import Foundation
import SwiftUI

enum AppAnnouncementCategory: String, Codable {
    case general, activity, maintenance, important, policy, update

    var title: String {
        switch self {
        case .general: return "通知"
        case .activity: return "活动"
        case .maintenance: return "维护"
        case .important: return "重要提醒"
        case .policy: return "协议政策"
        case .update: return "版本更新"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "bell"
        case .activity: return "sparkles"
        case .maintenance: return "wrench.and.screwdriver"
        case .important: return "exclamationmark.triangle"
        case .policy: return "doc.text"
        case .update: return "arrow.down.circle"
        }
    }
}

enum AppAnnouncementPriority: String, Codable {
    case normal, high, critical

    var rank: Int {
        switch self {
        case .normal: return 0
        case .high: return 1
        case .critical: return 2
        }
    }
}

struct AppAnnouncementManifestItem: Codable, Identifiable, Equatable {
    let id: String
    let displayRevision: Int
    let category: AppAnnouncementCategory
    let priority: AppAnnouncementPriority
    let title: String
    let summary: String?
    let publishedAt: String?
    let startsAt: String?
    let endsAt: String?
    let requiresAcknowledgement: Bool
}

struct AppAnnouncement: Codable, Identifiable, Equatable {
    let id: String
    let displayRevision: Int
    let category: AppAnnouncementCategory
    let priority: AppAnnouncementPriority
    let title: String
    let summary: String?
    let body: String
    let imageURL: String?
    let actionTitle: String?
    let actionURL: String?
    let publishedAt: String?
    let requiresAcknowledgement: Bool
}

struct AppAnnouncementManifestResponse: Decodable {
    let ok: Bool
    let revision: String
    let items: [AppAnnouncementManifestItem]
    let nextBoundaryAt: String?
    let recommendedCheckAfterSeconds: TimeInterval
}

struct AppAnnouncementDetailResponse: Decodable {
    let ok: Bool
    let announcement: AppAnnouncement
}

@MainActor
final class AnnouncementCenter: ObservableObject {
    static let shared = AnnouncementCenter()

    @Published private(set) var pendingAnnouncement: AppAnnouncement?

    private enum Keys {
        static let manifestETag = "announcement.manifest.etag"
        static let manifestItems = "announcement.manifest.items"
        static let cachedDetails = "announcement.details.cache"
        static let readRevisions = "announcement.read.revisions"
        static let nextCheckAt = "announcement.next.check.at"
        static let checkInterval = "announcement.check.interval"
    }

    private let defaults = UserDefaults.standard
    private let defaultCheckInterval: TimeInterval = 6 * 60 * 60
    private let minimumCheckInterval: TimeInterval = 15 * 60
    private let maximumCheckInterval: TimeInterval = 24 * 60 * 60
    private var manifestItems: [AppAnnouncementManifestItem] = []
    private var details: [String: AppAnnouncement] = [:]
    private var readRevisions: [String: Int] = [:]
    private var isChecking = false
    private var isLoadingDetail = false

    private init() {
        manifestItems = decode([AppAnnouncementManifestItem].self, forKey: Keys.manifestItems) ?? []
        details = decode([String: AppAnnouncement].self, forKey: Keys.cachedDetails) ?? [:]
        readRevisions = decode([String: Int].self, forKey: Keys.readRevisions) ?? [:]
    }

    func checkIfNeeded(force: Bool = false) {
        guard OnlineAccessManager.shared.hasStoredToken else { return }
        let nextCheck = defaults.object(forKey: Keys.nextCheckAt) as? Date ?? .distantPast
        let shouldRefreshManifest = force || Date() >= nextCheck
        if !shouldRefreshManifest {
            if pendingAnnouncement == nil { presentCachedAnnouncementIfAvailable() }
            return
        }
        guard !isChecking else { return }

        isChecking = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.isChecking = false }
            do {
                let result = try await APIService.shared.fetchAnnouncementManifest(
                    etag: self.defaults.string(forKey: Keys.manifestETag)
                )
                switch result {
                case .notModified(let etag):
                    if let etag { self.defaults.set(etag, forKey: Keys.manifestETag) }
                    self.scheduleNextCheck(interval: self.persistedCheckInterval, boundary: nil)
                case .value(let payload, let etag):
                    guard payload.ok else { throw AnnouncementServiceError.invalidResponse }
                    self.manifestItems = payload.items
                    self.persist(payload.items, forKey: Keys.manifestItems)
                    self.trimAndPersistDetails()
                    self.defaults.set(etag ?? payload.revision, forKey: Keys.manifestETag)
                    let interval = min(max(payload.recommendedCheckAfterSeconds, self.minimumCheckInterval), self.maximumCheckInterval)
                    self.defaults.set(interval, forKey: Keys.checkInterval)
                    self.scheduleNextCheck(interval: interval, boundary: payload.nextBoundaryAt)
                }
                await self.loadNextAnnouncementIfNeeded()
            } catch {
                self.defaults.set(Date().addingTimeInterval(self.minimumCheckInterval), forKey: Keys.nextCheckAt)
                AppLogger.warning("[Announcement] 公告清单读取失败: \(error.localizedDescription)")
            }
        }
    }

    func dismissPendingAnnouncement() {
        guard let announcement = pendingAnnouncement else { return }
        readRevisions[announcement.id] = max(readRevisions[announcement.id] ?? 0, announcement.displayRevision)
        persist(readRevisions, forKey: Keys.readRevisions)
        withAnimation(.easeOut(duration: 0.2)) { pendingAnnouncement = nil }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            await self?.loadNextAnnouncementIfNeeded()
        }
    }

    private var persistedCheckInterval: TimeInterval {
        let value = defaults.double(forKey: Keys.checkInterval)
        return value > 0 ? min(max(value, minimumCheckInterval), maximumCheckInterval) : defaultCheckInterval
    }

    @discardableResult
    private func presentCachedAnnouncementIfAvailable() -> Bool {
        guard let item = nextUnreadItem(), let detail = details[cacheKey(item.id, item.displayRevision)] else { return false }
        withAnimation(.easeOut(duration: 0.22)) { pendingAnnouncement = detail }
        return true
    }

    private func loadNextAnnouncementIfNeeded() async {
        guard pendingAnnouncement == nil, !isLoadingDetail, let item = nextUnreadItem() else { return }
        if presentCachedAnnouncementIfAvailable() { return }

        isLoadingDetail = true
        defer { isLoadingDetail = false }
        do {
            let detail = try await APIService.shared.fetchAnnouncementDetail(
                id: item.id,
                displayRevision: item.displayRevision
            )
            guard detail.id == item.id, detail.displayRevision == item.displayRevision else { return }
            details[cacheKey(detail.id, detail.displayRevision)] = detail
            trimAndPersistDetails()
            withAnimation(.easeOut(duration: 0.22)) { pendingAnnouncement = detail }
        } catch {
            defaults.removeObject(forKey: Keys.manifestETag)
            defaults.set(Date().addingTimeInterval(minimumCheckInterval), forKey: Keys.nextCheckAt)
            AppLogger.warning("[Announcement] 公告详情读取失败: \(error.localizedDescription)")
        }
    }

    private func nextUnreadItem() -> AppAnnouncementManifestItem? {
        manifestItems
            .filter { item in
                guard (readRevisions[item.id] ?? 0) < item.displayRevision else { return false }
                let now = Date()
                if let startsAt = item.startsAt, let starts = parseServerDate(startsAt), starts > now { return false }
                if let endsAt = item.endsAt, let ends = parseServerDate(endsAt), ends <= now { return false }
                return true
            }
            .sorted {
                if $0.priority.rank != $1.priority.rank { return $0.priority.rank > $1.priority.rank }
                return ($0.publishedAt ?? "") > ($1.publishedAt ?? "")
            }
            .first
    }

    private func scheduleNextCheck(interval: TimeInterval, boundary: String?) {
        var date = Date().addingTimeInterval(interval)
        if let boundary,
           let boundaryDate = parseServerDate(boundary),
           boundaryDate > Date() {
            date = min(date, boundaryDate)
        }
        defaults.set(date, forKey: Keys.nextCheckAt)
    }

    private func trimAndPersistDetails() {
        let validKeys = Set(manifestItems.map { cacheKey($0.id, $0.displayRevision) })
        details = details.filter { validKeys.contains($0.key) }
        if details.count > 30 {
            let retainedDetails = details
                .sorted { $0.key > $1.key }
                .prefix(30)
                .map { ($0.key, $0.value) }
            details = Dictionary(uniqueKeysWithValues: retainedDetails)
        }
        persist(details, forKey: Keys.cachedDetails)
    }

    private func cacheKey(_ id: String, _ revision: Int) -> String { "\(id):\(revision)" }

    private func parseServerDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func persist<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
