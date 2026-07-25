import Foundation
import Combine

/// 一段导入的沉浸背景视频（本地文件）
struct ImmersiveVideo: Identifiable, Codable, Equatable {
    let id: String            // UUID
    var displayName: String
    let filename: String      // 存储在 ImmersiveBackgrounds 目录下的文件名
    let importedAt: Date
    var sourceIdentifier: String? = nil
    var sourceName: String? = nil
}

/// 沉浸视频背景管理：导入的视频库 + 歌曲/全局绑定 + 旧上下文兼容回退。
/// 视频文件存放在 Documents/ImmersiveBackgrounds/，元数据与绑定关系存 UserDefaults。
@MainActor
final class ImmersiveBackgroundManager: ObservableObject {
    static let shared = ImmersiveBackgroundManager()

    /// 已导入的视频库（最新在前）
    @Published private(set) var library: [ImmersiveVideo] = []
    /// 歌曲绑定： "song:<id>" -> videoId
    @Published private(set) var songBindings: [String: String] = [:]
    /// 歌单/专辑等上下文绑定： "<contextType>:<id>" -> videoId
    @Published private(set) var contextBindings: [String: String] = [:]
    /// 未被歌曲或旧版上下文覆盖时使用的全局沉浸背景
    @Published private(set) var globalVideoID: String?
    /// 视频背景总开关：关闭只是暂停使用，绑定关系全部保留
    @Published var videoBackgroundEnabled: Bool = true {
        didSet {
            guard videoBackgroundEnabled != oldValue else { return }
            defaults.set(videoBackgroundEnabled, forKey: enabledKey)
        }
    }

    private let fm = FileManager.default
    private let defaults = UserDefaults.standard
    private let libraryKey = "immersiveBg.library.v1"
    private let songKey = "immersiveBg.songBindings.v1"
    private let contextKey = "immersiveBg.contextBindings.v1"
    private let globalKey = "immersiveBg.globalVideo.v1"
    private let enabledKey = "immersiveBg.enabled.v1"

    private init() { load() }

    // MARK: - 存储目录

    var storageDirectory: URL {
        let base = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("ImmersiveBackgrounds", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func fileURL(for video: ImmersiveVideo) -> URL {
        storageDirectory.appendingPathComponent(video.filename)
    }

    func video(withId id: String?) -> ImmersiveVideo? {
        guard let id else { return nil }
        return library.first { $0.id == id }
    }

    func video(sourceIdentifier: String, sourceName: String) -> ImmersiveVideo? {
        library.first {
            $0.sourceIdentifier == sourceIdentifier && $0.sourceName == sourceName
        }
    }

    // MARK: - 绑定 key

    static func songBindingKey(_ songId: Int) -> String { "song:\(songId)" }

    static func contextBindingKey(_ context: PlayerManager.PlayContext) -> String? {
        guard let id = context.id else { return nil }
        return "\(context.type.rawValue):\(id)"
    }

    // MARK: - 解析当前视频（歌曲优先，其次全局背景，旧版上下文仅作兼容回退）

    /// 无视总开关的绑定解析：舞台开关按钮据此判断「有无提前设定」
    func boundVideo(for song: Song?, context: PlayerManager.PlayContext?) -> ImmersiveVideo? {
        if let song, let v = video(withId: songBindings[Self.songBindingKey(song.id)]) {
            return v
        }
        if let v = video(withId: globalVideoID) {
            return v
        }
        if let context, let key = Self.contextBindingKey(context), let v = video(withId: contextBindings[key]) {
            return v
        }
        return nil
    }

    func resolvedVideo(for song: Song?, context: PlayerManager.PlayContext?) -> ImmersiveVideo? {
        guard videoBackgroundEnabled else { return nil }
        return boundVideo(for: song, context: context)
    }

    func resolvedVideoURL(for song: Song?, context: PlayerManager.PlayContext?) -> URL? {
        guard let v = resolvedVideo(for: song, context: context) else { return nil }
        let url = fileURL(for: v)
        return fm.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - 导入 / 删除 / 重命名

    @discardableResult
    func importVideo(
        from sourceURL: URL,
        displayName: String? = nil,
        sourceIdentifier: String? = nil,
        sourceName: String? = nil
    ) -> ImmersiveVideo? {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }

        let ext = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension
        let id = UUID().uuidString
        let filename = "\(id).\(ext)"
        let dest = storageDirectory.appendingPathComponent(filename)

        do {
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
            try fm.copyItem(at: sourceURL, to: dest)
        } catch {
            AppLogger.error("[ImmersiveBg] 导入视频失败: \(error.localizedDescription)")
            return nil
        }

        let rawName = displayName ?? sourceURL.deletingPathExtension().lastPathComponent
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let video = ImmersiveVideo(
            id: id,
            displayName: name.isEmpty ? "Video" : name,
            filename: filename,
            importedAt: Date(),
            sourceIdentifier: sourceIdentifier,
            sourceName: sourceName
        )
        library.insert(video, at: 0)
        save()
        return video
    }

    func rename(_ video: ImmersiveVideo, to newName: String) {
        guard let idx = library.firstIndex(where: { $0.id == video.id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        library[idx].displayName = trimmed.isEmpty ? library[idx].displayName : trimmed
        save()
    }

    func delete(_ video: ImmersiveVideo) {
        try? fm.removeItem(at: fileURL(for: video))
        library.removeAll { $0.id == video.id }
        songBindings = songBindings.filter { $0.value != video.id }
        contextBindings = contextBindings.filter { $0.value != video.id }
        if globalVideoID == video.id {
            globalVideoID = nil
        }
        save()
    }

    // MARK: - 绑定操作

    func bindSong(_ songId: Int, to videoId: String?) {
        let key = Self.songBindingKey(songId)
        if let videoId { songBindings[key] = videoId } else { songBindings.removeValue(forKey: key) }
        if videoId != nil { videoBackgroundEnabled = true }
        save()
    }

    func bindContext(_ context: PlayerManager.PlayContext, to videoId: String?) {
        guard let key = Self.contextBindingKey(context) else { return }
        if let videoId { contextBindings[key] = videoId } else { contextBindings.removeValue(forKey: key) }
        if videoId != nil { videoBackgroundEnabled = true }
        save()
    }

    func bindGlobal(to videoId: String?) {
        globalVideoID = videoId
        if videoId != nil { videoBackgroundEnabled = true }
        save()
    }

    func boundVideoId(forSong songId: Int) -> String? {
        songBindings[Self.songBindingKey(songId)]
    }

    func boundVideoId(forContext context: PlayerManager.PlayContext) -> String? {
        guard let key = Self.contextBindingKey(context) else { return nil }
        return contextBindings[key]
    }

    func boundGlobalVideoId() -> String? {
        globalVideoID
    }

    // MARK: - 持久化

    private func load() {
        let dec = JSONDecoder()
        if let d = defaults.data(forKey: libraryKey), let v = try? dec.decode([ImmersiveVideo].self, from: d) {
            library = v
        }
        if let d = defaults.data(forKey: songKey), let v = try? dec.decode([String: String].self, from: d) {
            songBindings = v
        }
        if let d = defaults.data(forKey: contextKey), let v = try? dec.decode([String: String].self, from: d) {
            contextBindings = v
        }
        globalVideoID = defaults.string(forKey: globalKey)
        videoBackgroundEnabled = defaults.object(forKey: enabledKey) as? Bool ?? true
        pruneMissingFiles()
        if globalVideoID != nil, video(withId: globalVideoID) == nil {
            globalVideoID = nil
            save()
        }
    }

    /// 清理文件已不存在的库项与其绑定
    private func pruneMissingFiles() {
        let missing = library.filter { !fm.fileExists(atPath: fileURL(for: $0).path) }
        guard !missing.isEmpty else { return }
        let missingIds = Set(missing.map { $0.id })
        library.removeAll { missingIds.contains($0.id) }
        songBindings = songBindings.filter { !missingIds.contains($0.value) }
        contextBindings = contextBindings.filter { !missingIds.contains($0.value) }
        if let globalVideoID, missingIds.contains(globalVideoID) {
            self.globalVideoID = nil
        }
        save()
    }

    private func save() {
        let enc = JSONEncoder()
        if let d = try? enc.encode(library) { defaults.set(d, forKey: libraryKey) }
        if let d = try? enc.encode(songBindings) { defaults.set(d, forKey: songKey) }
        if let d = try? enc.encode(contextBindings) { defaults.set(d, forKey: contextKey) }
        if let globalVideoID {
            defaults.set(globalVideoID, forKey: globalKey)
        } else {
            defaults.removeObject(forKey: globalKey)
        }
    }
}
