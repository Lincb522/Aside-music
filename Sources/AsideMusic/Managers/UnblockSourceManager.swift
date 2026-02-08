// UnblockSourceManager.swift
// 第三方音源管理器
// 管理用户导入的 JS 脚本音源和自定义 HTTP 音源，持久化存储

import Foundation
import NeteaseCloudMusicAPI

// MARK: - 持久化音源模型

/// 可持久化的音源配置
struct UnblockSourceConfig: Codable, Identifiable {
    let id: UUID
    /// 音源名称
    var name: String
    /// 音源类型
    var type: SourceType
    /// 是否启用
    var isEnabled: Bool
    /// 创建时间
    let createdAt: Date
    /// 排序优先级（越小越优先）
    var priority: Int

    enum SourceType: Codable {
        /// JS 脚本音源（存储脚本内容）
        case jsScript(content: String)
        /// 自定义 HTTP 地址音源
        case httpUrl(baseURL: String, urlTemplate: String?)
    }

    init(name: String, type: SourceType, priority: Int = 0) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.isEnabled = true
        self.createdAt = Date()
        self.priority = priority
    }
}

// MARK: - 音源管理器

@MainActor
final class UnblockSourceManager: ObservableObject {
    static let shared = UnblockSourceManager()

    /// 已保存的音源配置列表
    @Published var sources: [UnblockSourceConfig] = []

    /// 当前活跃的 UnblockManager 实例
    /// 使用 nonisolated 存储，允许非主线程安全读取（UnblockManager 本身是线程安全的）
    nonisolated(unsafe) private(set) var currentUnblockManager = UnblockManager()

    private let storageKey = "aside_unblock_sources"

    // MARK: - 默认源开关

    private let defaultSourcesKey = "aside_default_sources_enabled"

    /// 默认源总开关（一个开关控制三个默认源）
    @Published var defaultSourcesEnabled: Bool = true

    /// 读取默认源开关状态
    private func loadDefaultSourceStates() {
        if UserDefaults.standard.object(forKey: defaultSourcesKey) == nil {
            defaultSourcesEnabled = true
        } else {
            defaultSourcesEnabled = UserDefaults.standard.bool(forKey: defaultSourcesKey)
        }
    }

    /// 切换默认源开关
    func toggleDefaultSources() {
        defaultSourcesEnabled.toggle()
        UserDefaults.standard.set(defaultSourcesEnabled, forKey: defaultSourcesKey)
        rebuildUnblockManager()
    }

    // MARK: - 音源状态检测

    /// 单个音源的测试状态
    enum SourceTestStatus: Equatable {
        case unknown
        case checking
        case available(String)   // 成功，附带来源信息
        case unavailable(String) // 失败，附带错误信息
    }

    /// 所有音源的测试结果（key = 音源名称）
    @Published var sourceTestResults: [String: SourceTestStatus] = [:]

    /// 是否正在测试中
    @Published var isTesting = false

    /// 测试用歌曲 ID（晴天 - 周杰伦，经典曲目各平台基本都有）
    private let testSongId = 186016
    private let testSongTitle = "晴天"
    private let testSongArtist = "周杰伦"

    /// 后端服务地址
    var serverUrl: String {
        if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"] {
            return envURL
        } else if let plistURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String {
            return plistURL
        }
        return "http://114.66.31.109:3000"
    }

    /// 测试所有已注册音源的可用性
    func checkAllSources() {
        guard !isTesting else { return }
        isTesting = true

        let manager = currentUnblockManager
        let sources = manager.sources

        // 先全部标记为 checking
        var results: [String: SourceTestStatus] = [:]
        for source in sources {
            results[source.name] = .checking
        }
        sourceTestResults = results

        Task {
            // 逐个测试每个音源
            for source in sources {
                let status: SourceTestStatus
                do {
                    let result = try await source.match(
                        id: testSongId,
                        title: testSongTitle,
                        artist: testSongArtist,
                        quality: "320"
                    )
                    if !result.url.isEmpty {
                        let info = result.platform.isEmpty ? "可用" : result.platform
                        status = .available(info)
                    } else {
                        status = .unavailable("未匹配到结果")
                    }
                } catch {
                    status = .unavailable(error.localizedDescription)
                }
                // 逐个更新，UI 实时刷新
                await MainActor.run {
                    sourceTestResults[source.name] = status
                }
            }
            await MainActor.run {
                isTesting = false
            }
        }
    }

    /// 测试单个音源（按名称匹配，用于用户自定义源的独立测试）
    func checkSingleSource(name: String) {
        // 从 currentUnblockManager 中找到对应音源
        guard let source = currentUnblockManager.sources.first(where: { $0.name == name }) else { return }
        sourceTestResults[name] = .checking

        Task {
            let status: SourceTestStatus
            do {
                let result = try await source.match(
                    id: testSongId,
                    title: testSongTitle,
                    artist: testSongArtist,
                    quality: "320"
                )
                if !result.url.isEmpty {
                    let info = result.platform.isEmpty ? "可用" : result.platform
                    status = .available(info)
                } else {
                    status = .unavailable("未匹配到结果")
                }
            } catch {
                status = .unavailable(error.localizedDescription)
            }
            await MainActor.run {
                sourceTestResults[name] = status
            }
        }
    }

    /// 可用音源数量
    var availableSourceCount: Int {
        sourceTestResults.values.filter {
            if case .available = $0 { return true }
            return false
        }.count
    }

    /// 总测试音源数量
    var totalTestedSourceCount: Int {
        sourceTestResults.count
    }

    private init() {
        loadSources()
        loadDefaultSourceStates()
        rebuildUnblockManager()
        // 启动时自动测试所有音源
        checkAllSources()
    }

    /// 是否有用户自定义音源
    var hasCustomSources: Bool {
        !sources.isEmpty
    }

    // MARK: - 增删改

    /// 添加音源
    func addSource(_ config: UnblockSourceConfig) {
        var newConfig = config
        newConfig.priority = sources.count
        sources.append(newConfig)
        save()
        rebuildUnblockManager()
    }

    /// 删除音源
    func removeSource(at offsets: IndexSet) {
        sources.remove(atOffsets: offsets)
        reindexPriorities()
        save()
        rebuildUnblockManager()
    }

    /// 删除指定音源
    func removeSource(id: UUID) {
        sources.removeAll { $0.id == id }
        reindexPriorities()
        save()
        rebuildUnblockManager()
    }

    /// 切换启用状态
    func toggleSource(id: UUID) {
        if let idx = sources.firstIndex(where: { $0.id == id }) {
            sources[idx].isEnabled.toggle()
            save()
            rebuildUnblockManager()
        }
    }

    /// 移动排序
    func moveSource(from: IndexSet, to: Int) {
        sources.move(fromOffsets: from, toOffset: to)
        reindexPriorities()
        save()
        rebuildUnblockManager()
    }

    /// 更新音源名称
    func updateName(id: UUID, name: String) {
        if let idx = sources.firstIndex(where: { $0.id == id }) {
            sources[idx].name = name
            save()
            rebuildUnblockManager()
        }
    }

    // MARK: - 导入 JS 脚本

    /// 从文件 URL 导入 JS 脚本
    func importJSScript(from fileURL: URL) throws -> UnblockSourceConfig {
        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { fileURL.stopAccessingSecurityScopedResource() }
        }

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let fileName = fileURL.deletingPathExtension().lastPathComponent

        // 尝试从脚本中提取名称
        let source = JSScriptSource(name: fileName, script: content)
        let name = source.name

        let config = UnblockSourceConfig(
            name: name,
            type: .jsScript(content: content)
        )
        return config
    }

    // MARK: - 持久化

    private func save() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadSources() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([UnblockSourceConfig].self, from: data) else {
            return
        }
        sources = saved.sorted { $0.priority < $1.priority }
    }

    private func reindexPriorities() {
        for i in 0..<sources.count {
            sources[i].priority = i
        }
    }

    // MARK: - 构建 UnblockManager

    /// 根据当前启用的音源重建 UnblockManager
    /// 没有用户自定义源时，注册默认的后端解灰源（match → ncmget → GD 直连）
    func rebuildUnblockManager() {
        let manager = UnblockManager()

        let enabledSources = sources.filter(\.isEnabled)

        if enabledSources.isEmpty {
            // 无用户自定义源：使用默认后端解灰源
            registerDefaultSources(to: manager)
        } else {
            // 有用户自定义源：按优先级注册
            for config in enabledSources {
                switch config.type {
                case .jsScript(let content):
                    let source = JSScriptSource(name: config.name, script: content)
                    manager.register(source)
                case .httpUrl(let baseURL, let urlTemplate):
                    let source = CustomURLSource(name: config.name, baseURL: baseURL, urlTemplate: urlTemplate)
                    manager.register(source)
                }
            }
            // 用户自定义源之后，追加默认源作为兜底
            registerDefaultSources(to: manager)
        }

        currentUnblockManager = manager

        // 同步到 NCMClient，确保库内置的 autoUnblock 使用最新音源
        syncToNCMClient(manager: manager)
    }

    /// 标记 APIService 已初始化完成，可以安全访问
    nonisolated(unsafe) private var _apiServiceReady = false
    func markAPIServiceReady() {
        _apiServiceReady = true
        // 首次同步
        syncToNCMClient(manager: currentUnblockManager)
    }

    /// 同步 UnblockManager 到 NCMClient
    private func syncToNCMClient(manager: UnblockManager) {
        guard _apiServiceReady else { return }
        let enabled = UserDefaults.standard.bool(forKey: "unblockEnabled")
        // unblockEnabled 默认值为 true，但 UserDefaults 未设置时返回 false
        // 使用 object(forKey:) 检测是否曾设置过
        let isEnabled = UserDefaults.standard.object(forKey: "unblockEnabled") == nil ? true : enabled
        if isEnabled {
            APIService.shared.ncm.unblockManager = manager
            APIService.shared.ncm.autoUnblock = true
        }
    }

    /// 注册默认的后端解灰源（根据总开关状态）
    /// 优先级：后端 match → 后端 ncmget → GD 音乐台直连
    private func registerDefaultSources(to manager: UnblockManager) {
        guard defaultSourcesEnabled else { return }

        let serverUrl: String
        if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"] {
            serverUrl = envURL
        } else if let plistURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String {
            serverUrl = plistURL
        } else {
            serverUrl = "http://114.66.31.109:3000"
        }

        if !serverUrl.isEmpty {
            manager.register(ServerUnblockSource(serverUrl: serverUrl, mode: .match))
            manager.register(ServerUnblockSource(serverUrl: serverUrl, mode: .ncmget))
        }
        manager.register(ServerUnblockSource.gd())
    }

    /// 启用的音源数量
    var enabledCount: Int {
        sources.filter(\.isEnabled).count
    }
}
