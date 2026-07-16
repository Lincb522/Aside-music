import Combine
import Foundation

@MainActor
final class DebugLogViewModel: ObservableObject {
    @Published private(set) var visibleEntries: [LogEntry] = []
    @Published private(set) var totalCount = 0
    @Published private(set) var droppedCount = 0
    @Published private(set) var lastUpdatedAt: Date?

    @Published var searchText = "" {
        didSet { scheduleFilter() }
    }

    @Published var selectedLevel: LogEntry.LogLevel? {
        didSet { applyFilter() }
    }

    @Published var newestFirst = true {
        didSet { applyFilter() }
    }

    @Published var followsLatest = true

    @Published var isCollecting: Bool {
        didSet {
            guard isCollecting != AppLogger.isCollectionEnabled else { return }
            AppLogger.setCollectionEnabled(isCollecting)
        }
    }

    private var allEntries: [LogEntry] = []
    private var counts: [LogEntry.LogLevel: Int] = [:]
    private var revision: UInt64 = .max
    private var changeCancellable: AnyCancellable?
    private var filterTask: Task<Void, Never>?

    init() {
        isCollecting = AppLogger.isCollectionEnabled
        changeCancellable = NotificationCenter.default.publisher(for: .appLoggerDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
        refresh(force: true)
    }

    deinit {
        filterTask?.cancel()
    }

    var isFiltering: Bool {
        selectedLevel != nil || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var latestVisibleEntryID: UUID? {
        newestFirst ? visibleEntries.first?.id : visibleEntries.last?.id
    }

    var allEntriesForExport: [LogEntry] {
        newestFirst ? allEntries.reversed() : allEntries
    }

    func count(for level: LogEntry.LogLevel) -> Int {
        counts[level, default: 0]
    }

    func select(_ level: LogEntry.LogLevel?) {
        selectedLevel = selectedLevel == level ? nil : level
    }

    func refresh(force: Bool = false) {
        let snapshot = AppLogger.snapshot()
        guard force || snapshot.revision != revision else { return }

        revision = snapshot.revision
        allEntries = snapshot.entries
        counts = snapshot.counts
        totalCount = snapshot.entries.count
        droppedCount = snapshot.droppedCount
        let collectionState = AppLogger.isCollectionEnabled
        if isCollecting != collectionState {
            isCollecting = collectionState
        }
        lastUpdatedAt = Date()
        applyFilter()
    }

    func clear() {
        AppLogger.clearLogs()
        refresh(force: true)
    }

    func textExport(filtered: Bool) -> String {
        AppLogger.textExport(entries: filtered ? visibleEntries : allEntriesForExport)
    }

    func jsonExport() -> String {
        AppLogger.jsonExport(entries: allEntriesForExport)
            ?? AppLogger.textExport(entries: allEntriesForExport)
    }

    private func scheduleFilter() {
        filterTask?.cancel()
        filterTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 90_000_000)
            guard !Task.isCancelled else { return }
            self?.applyFilter()
        }
    }

    private func applyFilter() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let level = selectedLevel

        var result: [LogEntry]
        if level == nil && query.isEmpty {
            result = allEntries
        } else {
            result = allEntries.filter { entry in
                (level == nil || entry.level == level) && entry.matches(query)
            }
        }
        if newestFirst {
            result.reverse()
        }
        visibleEntries = result
    }
}
