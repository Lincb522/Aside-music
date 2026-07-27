import Combine
import Foundation

/// 调试日志面板的数据源：订阅 `AppLogger` 变更通知（节流 220ms），
/// 提供按级别/分类/关键词的筛选、排序、导出与采集开关能力。
@MainActor
final class DebugLogViewModel: ObservableObject {
    /// 聚合的展示状态，整体替换以减少 @Published 发布次数。
    private struct PresentationState {
        var visibleEntries: [LogEntry] = []
        var totalCount = 0
        var droppedCount = 0
        var coalescedCount = 0
        var levelCounts: [LogEntry.LogLevel: Int] = [:]
        var categoryCounts: [LogEntry.Category: Int] = [:]
    }

    @Published private var presentation = PresentationState()

    var visibleEntries: [LogEntry] { presentation.visibleEntries }
    var totalCount: Int { presentation.totalCount }
    var droppedCount: Int { presentation.droppedCount }
    var coalescedCount: Int { presentation.coalescedCount }

    func count(for level: LogEntry.LogLevel?) -> Int {
        guard let level else { return presentation.totalCount }
        return presentation.levelCounts[level, default: 0]
    }

    func count(for category: LogEntry.Category?) -> Int {
        guard let category else { return presentation.totalCount }
        return presentation.categoryCounts[category, default: 0]
    }

    // MARK: - 筛选条件

    /// 搜索词变更频繁，走 90ms 防抖；其余条件变更直接应用筛选。
    @Published var searchText = "" {
        didSet { scheduleFilter() }
    }

    @Published var selectedLevel: LogEntry.LogLevel? {
        didSet { applyFilter() }
    }

    @Published var selectedCategory: LogEntry.Category? {
        didSet { applyFilter() }
    }

    @Published var newestFirst = true {
        didSet { applyFilter() }
    }

    /// 列表是否自动滚动到最新条目。
    @Published var followsLatest = true

    /// 日志采集开关，与 `AppLogger` 双向同步。
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
        selectedLevel != nil
            || selectedCategory != nil
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var latestVisibleEntryID: UUID? {
        newestFirst ? visibleEntries.first?.id : visibleEntries.last?.id
    }

    var allEntriesForExport: [LogEntry] {
        newestFirst ? allEntries.reversed() : allEntries
    }

    // MARK: - 操作

    /// 重复点击同一级别时取消筛选。
    func select(_ level: LogEntry.LogLevel?) {
        selectedLevel = selectedLevel == level ? nil : level
    }

    func select(category: LogEntry.Category?) {
        selectedCategory = selectedCategory == category ? nil : category
    }

    /// 从 AppLogger 取快照刷新；revision 未变时跳过，避免无效重建。
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
            coalescedCount: snapshot.coalescedCount,
            levelCounts: snapshot.counts,
            categoryCounts: snapshot.categoryCounts
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

    // MARK: - 筛选实现

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
        let category = selectedCategory

        var result: [LogEntry]
        if level == nil && category == nil && query.isEmpty {
            result = allEntries
        } else {
            result = allEntries.filter { entry in
                (level == nil || entry.level == level)
                    && (category == nil || entry.category == category)
                    && entry.matches(query)
            }
        }
        if newestFirst {
            result.reverse()
        }
        return result
    }
}
