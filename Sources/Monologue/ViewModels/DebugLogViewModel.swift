import Combine
import Foundation

@MainActor
final class DebugLogViewModel: ObservableObject {
    private struct PresentationState {
        var visibleEntries: [LogEntry] = []
        var totalCount = 0
        var droppedCount = 0
        var levelCounts: [LogEntry.LogLevel: Int] = [:]
    }

    @Published private var presentation = PresentationState()

    var visibleEntries: [LogEntry] { presentation.visibleEntries }
    var totalCount: Int { presentation.totalCount }
    var droppedCount: Int { presentation.droppedCount }

    func count(for level: LogEntry.LogLevel?) -> Int {
        guard let level else { return presentation.totalCount }
        return presentation.levelCounts[level, default: 0]
    }

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
    private var revision: UInt64 = .max
    private var changeCancellable: AnyCancellable?
    private var filterTask: Task<Void, Never>?

    init() {
        isCollecting = AppLogger.isCollectionEnabled
        changeCancellable = NotificationCenter.default.publisher(for: .appLoggerDidChange)
            .receive(on: RunLoop.main)
            .throttle(for: .milliseconds(220), scheduler: RunLoop.main, latest: true)
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

    func select(_ level: LogEntry.LogLevel?) {
        selectedLevel = selectedLevel == level ? nil : level
    }

    func refresh(force: Bool = false) {
        let snapshot = AppLogger.snapshot()
        guard force || snapshot.revision != revision else { return }

        revision = snapshot.revision
        allEntries = snapshot.entries
        let collectionState = AppLogger.isCollectionEnabled
        if isCollecting != collectionState {
            isCollecting = collectionState
        }

        presentation = PresentationState(
            visibleEntries: filteredEntries(),
            totalCount: snapshot.entries.count,
            droppedCount: snapshot.droppedCount,
            levelCounts: snapshot.counts
        )
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
        let result = filteredEntries()
        guard result != presentation.visibleEntries else { return }
        var updated = presentation
        updated.visibleEntries = result
        presentation = updated
    }

    private func filteredEntries() -> [LogEntry] {
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
        return result
    }
}
