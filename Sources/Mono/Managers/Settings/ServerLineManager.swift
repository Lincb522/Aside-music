// 多线路管理：主线路（宁波直连）+ 多条备用线路（独立分流）
// 自动模式决策规则（不区分地区，只看健康与繁忙程度）：
// 1. 主线路探测失败（超时/5xx）→ 切到备用线路
// 2. 主线路繁忙 → 分流到备用线路。繁忙 = 响应慢于 busyLatencyThreshold 且备用明显更快，
//    或 nginx 活跃连接数达到 busyConnectionsThreshold（请求量大）
// 3. 已在备用线路时，主线路延迟与负载都回落、连续两次探测健康且驻留时间足够 → 回切主线路（滞后防抖）

import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 线路定义

enum ServerLine: String, CaseIterable {
    case primary
    case backup
    case backup2

    var displayName: String {
        switch self {
        case .primary: return String(localized: "server_line_primary")
        case .backup: return String(localized: "server_line_backup")
        case .backup2: return String(localized: "server_line_backup_2")
        }
    }
}

enum ServerLinePreference: String, CaseIterable {
    /// 自动：健康探测 + 繁忙分流
    case auto
    /// 强制主线路
    case primary
    /// 强制备用线路
    case backup
    /// 强制备用线路 2
    case backup2
}

// MARK: - 线路管理器

final class ServerLineManager: ObservableObject, @unchecked Sendable {

    static let shared = ServerLineManager()

    // MARK: - 常量

    private enum Tuning {
        /// 探测超时
        static let probeTimeout: TimeInterval = 5
        /// 主线路响应超过该值视为「繁忙」（带宽打满时静态探测 RTT 会显著抬升）
        static let busyLatencyThreshold: TimeInterval = 2.0
        /// 繁忙分流要求备用线路延迟低于主线路的该比例（避免两边都慢时无意义切换）
        static let busyAdvantageRatio: Double = 0.6
        /// 主线路 nginx 活跃连接数达到该值视为「请求量大」，分流到备用线路
        static let busyConnectionsThreshold = 80
        /// 回切主线路要求活跃连接数回落到该值以下（滞后区间，防抖）
        static let recoverConnectionsThreshold = 48
        /// 主线路恢复判定延迟上限
        static let recoverLatencyThreshold: TimeInterval = 1.2
        /// 回切主线路需要的连续健康探测次数
        static let recoverStreakRequired = 2
        /// 切换后最短驻留时间，防止来回抖动
        static let minDwellInterval: TimeInterval = 120
        /// 周期探测间隔
        static let periodicInterval: TimeInterval = 180
        /// 被动失败计数窗口与阈值：窗口内连续失败即触发即时探测
        static let failureWindow: TimeInterval = 60
        static let failureThreshold = 3
    }

    private enum StorageKeys {
        static let preference = "server_line_preference"
        static let activeLine = "server_line_active"
    }

    enum RefreshTrigger: String {
        case launch
        case foreground
        case periodic
        case failure
        case manual
    }

    // MARK: - 跨线程快照（SecureConfig 在任意线程读取）

    private static let snapshotLock = NSLock()
    nonisolated(unsafe) private static var activeSnapshot: ServerLine = ServerLineManager.loadPersistedLine()

    /// 当前生效线路（线程安全，供 SecureConfig 解析 URL 用）
    static var currentLine: ServerLine {
        snapshotLock.lock()
        defer { snapshotLock.unlock() }
        return activeSnapshot
    }

    private static func storeSnapshot(_ line: ServerLine) {
        snapshotLock.lock()
        activeSnapshot = line
        snapshotLock.unlock()
    }

    private static func loadPersistedLine() -> ServerLine {
        // 强制偏好优先；auto 时沿用上次生效线路，冷启动即用上次的健康线路
        let rawPreference = UserDefaults.standard.string(forKey: StorageKeys.preference)
        if let rawPreference, let forced = forcedLine(for: rawPreference) {
            return forced
        }
        if let rawActive = UserDefaults.standard.string(forKey: StorageKeys.activeLine),
           let line = ServerLine(rawValue: rawActive),
           isConfiguredLine(line) {
            return line
        }
        return .primary
    }

    private static func forcedLine(for rawPreference: String) -> ServerLine? {
        switch ServerLinePreference(rawValue: rawPreference) {
        case .primary: return .primary
        case .backup: return SecureConfig.hasFirstBackupLine ? .backup : nil
        case .backup2: return SecureConfig.hasSecondBackupLine ? .backup2 : nil
        default: return nil
        }
    }

    private static func isConfiguredLine(_ line: ServerLine) -> Bool {
        switch line {
        case .primary:
            return true
        case .backup:
            return SecureConfig.hasFirstBackupLine
        case .backup2:
            return SecureConfig.hasSecondBackupLine
        }
    }

    /// 是否配置了备用线路（未配置时整个功能保持惰性）
    static var isBackupConfigured: Bool {
        SecureConfig.hasBackupLine
    }

    static var isFirstBackupConfigured: Bool {
        SecureConfig.hasFirstBackupLine
    }

    static var isSecondBackupConfigured: Bool {
        SecureConfig.hasSecondBackupLine
    }

    // MARK: - UI 状态

    struct ProbeResult {
        /// nil 表示探测失败（超时或 5xx）
        let latency: TimeInterval?
        /// 主服务器 nginx 活跃连接数（探测端点返回 stub_status 时才有），衡量请求量
        let activeConnections: Int?
        let date: Date

        var isAlive: Bool { latency != nil }

        static func failure() -> ProbeResult {
            ProbeResult(latency: nil, activeConnections: nil, date: Date())
        }
    }

    @Published private(set) var activeLine: ServerLine
    @Published private(set) var preference: ServerLinePreference
    @Published private(set) var probeResults: [ServerLine: ProbeResult] = [:]
    @Published private(set) var isProbing = false

    // MARK: - 内部状态

    private let stateLock = NSLock()
    private var recoverStreak = 0
    private var lastSwitchDate = Date.distantPast
    private var recentFailureDates: [Date] = []
    private var refreshTask: Task<Bool, Never>?
    private var periodicTimer: Timer?
    private var started = false

    private let probeSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = Tuning.probeTimeout
        config.timeoutIntervalForResource = Tuning.probeTimeout
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private init() {
        let rawPreference = UserDefaults.standard.string(forKey: StorageKeys.preference) ?? ""
        preference = ServerLinePreference(rawValue: rawPreference) ?? .auto
        activeLine = Self.currentLine
    }

    // MARK: - 生命周期

    /// App 启动时调用：应用初始线路并启动周期探测
    func start() {
        guard Self.isBackupConfigured else { return }
        stateLock.lock()
        let alreadyStarted = started
        started = true
        stateLock.unlock()
        guard !alreadyStarted else { return }

        kickRefresh(trigger: .launch)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let timer = Timer.scheduledTimer(withTimeInterval: Tuning.periodicInterval, repeats: true) { [weak self] _ in
                self?.handlePeriodicTick()
            }
            timer.tolerance = Tuning.periodicInterval * 0.2
            self.periodicTimer = timer
        }
    }

    private func handlePeriodicTick() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            #if canImport(UIKit)
            guard UIApplication.shared.applicationState == .active else { return }
            #endif
            guard self.preference == .auto else { return }
            self.kickRefresh(trigger: .periodic)
        }
    }

    // MARK: - 偏好设置

    func setPreference(_ newPreference: ServerLinePreference) {
        UserDefaults.standard.set(newPreference.rawValue, forKey: StorageKeys.preference)
        DispatchQueue.main.async { [weak self] in
            self?.preference = newPreference
        }

        switch newPreference {
        case .primary:
            activate(.primary, reason: "手动强制主线路")
        case .backup:
            activate(.backup, reason: "手动强制备用线路")
        case .backup2:
            activate(.backup2, reason: "手动强制备用线路 2")
        case .auto:
            kickRefresh(trigger: .manual)
        }
    }

    // MARK: - 被动失败上报

    /// 网络层请求失败（超时/连接断开/5xx）时调用；窗口内失败达到阈值触发即时探测
    func noteNetworkFailure() {
        guard Self.isBackupConfigured, preference == .auto else { return }

        let now = Date()
        stateLock.lock()
        recentFailureDates = recentFailureDates.filter { now.timeIntervalSince($0) < Tuning.failureWindow }
        recentFailureDates.append(now)
        let shouldRefresh = recentFailureDates.count >= Tuning.failureThreshold
        if shouldRefresh {
            recentFailureDates.removeAll()
        }
        stateLock.unlock()

        if shouldRefresh {
            AppLogger.warning("[ServerLine] 窗口内连续请求失败，触发线路探测")
            kickRefresh(trigger: .failure)
        }
    }

    /// 请求成功时调用，清空失败计数
    func noteNetworkSuccess() {
        stateLock.lock()
        recentFailureDates.removeAll()
        stateLock.unlock()
    }

    // MARK: - 探测与切换

    /// 触发一次探测刷新（合并并发调用）
    func kickRefresh(trigger: RefreshTrigger) {
        Task { _ = await self.refresh(trigger: trigger) }
    }

    /// 探测并按需切换；返回本次刷新是否发生了线路切换。
    /// 并发调用会复用进行中的刷新任务。
    @discardableResult
    func refresh(trigger: RefreshTrigger) async -> Bool {
        guard Self.isBackupConfigured else { return false }

        let (task, isOwner) = dedupedRefreshTask(trigger: trigger)
        let switched = await task.value
        if isOwner {
            clearRefreshTask()
        }
        return switched
    }

    /// 同步的任务去重：已有进行中的刷新则复用，否则创建（NSLock 不能在 async 上下文直接使用）
    private func dedupedRefreshTask(trigger: RefreshTrigger) -> (task: Task<Bool, Never>, isOwner: Bool) {
        stateLock.lock()
        defer { stateLock.unlock() }

        if let running = refreshTask {
            return (running, false)
        }
        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }
            return await self.performRefresh(trigger: trigger)
        }
        refreshTask = task
        return (task, true)
    }

    private func clearRefreshTask() {
        stateLock.lock()
        refreshTask = nil
        stateLock.unlock()
    }

    private func performRefresh(trigger: RefreshTrigger) async -> Bool {
        await MainActor.run { self.isProbing = true }
        defer { Task { @MainActor in self.isProbing = false } }

        async let primaryProbe = probe(line: .primary)
        async let backupProbe = probeIfConfigured(line: .backup)
        async let backup2Probe = probeIfConfigured(line: .backup2)
        let (primary, backup, backup2) = await (primaryProbe, backupProbe, backup2Probe)

        await MainActor.run {
            self.probeResults[.primary] = primary
            self.updateProbeResult(backup, for: .backup, isConfigured: Self.isFirstBackupConfigured)
            self.updateProbeResult(backup2, for: .backup2, isConfigured: Self.isSecondBackupConfigured)
        }

        let latencyText: (ProbeResult) -> String = { result in
            guard let latency = result.latency else { return "失败" }
            var text = String(format: "%.0fms", latency * 1000)
            if let connections = result.activeConnections {
                text += "/\(connections)conn"
            }
            return text
        }
        AppLogger.info("[ServerLine] 探测(\(trigger.rawValue)) 主=\(latencyText(primary)) 备1=\(latencyText(backup)) 备2=\(latencyText(backup2)) 当前=\(activeLineRawValue())")

        guard preference == .auto else { return false }

        let decision = decideAutoLine(primary: primary, backup: backup, backup2: backup2)
        guard decision != Self.currentLine else { return false }

        let reason: String
        switch decision {
        case .backup, .backup2:
            let selected = decision == .backup ? backup : backup2
            reason = primary.isAlive
                ? "主线路繁忙(\(latencyText(primary)))，分流到\(decision.displayName)(\(latencyText(selected)))"
                : "主线路不可用，切换到\(decision.displayName)"
        case .primary:
            reason = "主线路已恢复(\(latencyText(primary)))，回切主线路"
        }
        activate(decision, reason: reason)
        return true
    }

    private func activeLineRawValue() -> String {
        Self.currentLine.rawValue
    }

    private func probeIfConfigured(line: ServerLine) async -> ProbeResult {
        switch line {
        case .primary:
            return await probe(line: line)
        case .backup:
            guard Self.isFirstBackupConfigured else { return .failure() }
            return await probe(line: line)
        case .backup2:
            guard Self.isSecondBackupConfigured else { return .failure() }
            return await probe(line: line)
        }
    }

    @MainActor
    private func updateProbeResult(_ result: ProbeResult, for line: ServerLine, isConfigured: Bool) {
        if isConfigured {
            probeResults[line] = result
        } else {
            probeResults.removeValue(forKey: line)
        }
    }

    private func isConfiguredFallback(_ line: ServerLine) -> Bool {
        switch line {
        case .primary:
            return true
        case .backup:
            return Self.isFirstBackupConfigured
        case .backup2:
            return Self.isSecondBackupConfigured
        }
    }

    /// 自动模式决策
    private func decideAutoLine(primary: ProbeResult, backup: ProbeResult, backup2: ProbeResult) -> ServerLine {
        let current = Self.currentLine
        let now = Date()

        stateLock.lock()
        let dwell = now.timeIntervalSince(lastSwitchDate)
        stateLock.unlock()

        let fallbackCandidates: [(line: ServerLine, result: ProbeResult)] = [
            (.backup, backup),
            (.backup2, backup2),
        ].filter { candidate in
            candidate.result.isAlive && isConfiguredFallback(candidate.line)
        }

        let bestFallback = fallbackCandidates.min { lhs, rhs in
            (lhs.result.latency ?? .greatestFiniteMagnitude) < (rhs.result.latency ?? .greatestFiniteMagnitude)
        }

        // 备用线路都不可用：只能用主线路
        guard let bestFallback else {
            resetRecoverStreak()
            return .primary
        }

        // 主线路不可用：切最快可用备用
        guard let primaryLatency = primary.latency else {
            resetRecoverStreak()
            return bestFallback.line
        }

        switch current {
        case .primary:
            resetRecoverStreak()
            guard dwell >= Tuning.minDwellInterval else { return .primary }

            // 请求量分流：主服务器活跃连接数过高
            if let connections = primary.activeConnections,
               connections >= Tuning.busyConnectionsThreshold {
                return bestFallback.line
            }
            // 延迟分流：主线路明显变慢且备用线路有实质优势
            if primaryLatency > Tuning.busyLatencyThreshold,
               let fallbackLatency = bestFallback.result.latency,
               fallbackLatency < primaryLatency * Tuning.busyAdvantageRatio {
                return bestFallback.line
            }
            return .primary

        case .backup, .backup2:
            // 回切：主线路延迟与负载都回落，连续多次健康且驻留够久
            let loadRecovered = (primary.activeConnections ?? 0) < Tuning.recoverConnectionsThreshold
            if primaryLatency <= Tuning.recoverLatencyThreshold, loadRecovered {
                stateLock.lock()
                recoverStreak += 1
                let streak = recoverStreak
                stateLock.unlock()
                if streak >= Tuning.recoverStreakRequired, dwell >= Tuning.minDwellInterval {
                    return .primary
                }
            } else {
                resetRecoverStreak()
            }

            let currentProbe = current == .backup ? backup : backup2
            if currentProbe.isAlive {
                return current
            }
            return bestFallback.line
        }
    }

    private func resetRecoverStreak() {
        stateLock.lock()
        recoverStreak = 0
        stateLock.unlock()
    }

    /// 应用线路切换：更新快照、持久化、重绑各网络客户端
    private func activate(_ line: ServerLine, reason: String) {
        let previous = Self.currentLine
        guard line != previous else { return }

        Self.storeSnapshot(line)
        UserDefaults.standard.set(line.rawValue, forKey: StorageKeys.activeLine)

        stateLock.lock()
        lastSwitchDate = Date()
        recoverStreak = 0
        recentFailureDates.removeAll()
        stateLock.unlock()

        AppLogger.warning("[ServerLine] \(previous.rawValue) → \(line.rawValue)：\(reason)")

        DispatchQueue.main.async { [weak self] in
            self?.activeLine = line
            APIService.shared.rebindServerLine()
        }
    }

    // MARK: - 探测实现

    /// 对指定线路的 NCM / QCM / 汽水 / KCM 域名发起轻量探测。
    /// 任何 < 500 的 HTTP 响应都视为线路可达（404 属正常：探测路径不存在于业务路由）；
    /// 备用线路是独立分流节点，5xx 意味着当前节点或本机业务服务异常。
    private func probe(line: ServerLine) async -> ProbeResult {
        async let ncmProbe = probeEndpoint(
            base: SecureConfig.apiBaseURL(for: line),
            line: line,
            service: "NCM",
            collectActiveConnections: true
        )
        async let qcmProbe = probeEndpoint(
            base: SecureConfig.qqMusicBaseURL(for: line),
            line: line,
            service: "QCM",
            collectActiveConnections: false
        )
        async let qishuiProbe = probeEndpoint(
            base: SecureConfig.qishuiBaseURL(for: line),
            line: line,
            service: "Qishui",
            collectActiveConnections: false
        )
        async let kcmProbe = probeEndpoint(
            base: SecureConfig.kugouBaseURL(for: line),
            line: line,
            service: "KCM",
            collectActiveConnections: false,
            requiresSuccessfulStatus: true,
            requiresOKBody: true
        )
        let (ncm, qcm, qishui, kcm) = await (ncmProbe, qcmProbe, qishuiProbe, kcmProbe)

        let probes = [ncm, qcm, qishui, kcm]
        guard probes.allSatisfy(\.isAlive) else {
            return .failure()
        }

        return ProbeResult(
            latency: probes.compactMap(\.latency).max(),
            activeConnections: ncm.activeConnections,
            date: Date()
        )
    }

    private func probeEndpoint(
        base: String,
        line: ServerLine,
        service: String,
        collectActiveConnections: Bool,
        requiresSuccessfulStatus: Bool = false,
        requiresOKBody: Bool = false
    ) async -> ProbeResult {
        guard var components = URLComponents(string: base) else {
            AppLogger.warning("[ServerLine] endpoint failure line=\(line.rawValue) service=\(service) reason=invalid_url")
            return .failure()
        }
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = basePath + "/__line_ok"

        guard let url = components.url else {
            AppLogger.warning("[ServerLine] endpoint failure line=\(line.rawValue) service=\(service) reason=invalid_url")
            return .failure()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = Tuning.probeTimeout

        let start = CFAbsoluteTimeGetCurrent()
        do {
            let (data, response) = try await probeSession.data(for: request)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            guard let http = response as? HTTPURLResponse else {
                AppLogger.warning("[ServerLine] endpoint failure line=\(line.rawValue) service=\(service) reason=non_http")
                return .failure()
            }
            let accepted = requiresSuccessfulStatus
                ? (200..<300).contains(http.statusCode)
                : http.statusCode < 500
            guard accepted else {
                AppLogger.warning("[ServerLine] endpoint failure line=\(line.rawValue) service=\(service) status=\(http.statusCode)")
                return .failure()
            }
            if requiresOKBody {
                let body = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                guard body == "ok" else {
                    AppLogger.warning("[ServerLine] endpoint failure line=\(line.rawValue) service=\(service) reason=unexpected_health_body")
                    return .failure()
                }
            }
            return ProbeResult(
                latency: elapsed,
                activeConnections: collectActiveConnections ? Self.parseActiveConnections(from: data) : nil,
                date: Date()
            )
        } catch let error as URLError {
            AppLogger.warning("[ServerLine] endpoint failure line=\(line.rawValue) service=\(service) url_error=\(error.code.rawValue)")
            return .failure()
        } catch {
            AppLogger.warning("[ServerLine] endpoint failure line=\(line.rawValue) service=\(service) reason=request_error")
            return .failure()
        }
    }

    /// 解析 nginx stub_status 的 "Active connections: N"
    private static func parseActiveConnections(from data: Data) -> Int? {
        guard data.count <= 4096,
              let text = String(data: data, encoding: .utf8),
              let range = text.range(of: "Active connections:") else {
            return nil
        }
        let tail = text[range.upperBound...].drop { $0 == " " }
        let digits = tail.prefix { $0.isNumber }
        return Int(digits)
    }
}
