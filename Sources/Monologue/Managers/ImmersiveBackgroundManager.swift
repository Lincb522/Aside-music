import Foundation
import Combine

/// 一段导入的沉浸背景视频（本地文件）
struct ImmersiveVideo: Identifiable, Codable, Equatable {
    let id: String            // UUID
    var displayName: String
    let filename: String      // 存储在 ImmersiveBackgrounds 目录下的文件名
    let importedAt: Date
}

/// 沉浸视频背景管理：导入的视频库 + 按歌曲/歌单的绑定关系 + 解析当前应显示的视频。
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

    private let fm = FileManager.default
    private let defaults = UserDefaults.standard
    private let libraryKey = "immersiveBg.library.v1"
    private let songKey = "immersiveBg.songBindings.v1"
    private let contextKey = "immersiveBg.contextBindings.v1"

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

    // MARK: - 绑定 key

    static func songBindingKey(_ songId: Int) -> String { "song:\(songId)" }

    static func contextBindingKey(_ context: PlayerManager.PlayContext) -> String? {
        guard let id = context.id else { return nil }
        return "\(context.type.rawValue):\(id)"
    }

    // MARK: - 解析当前视频（歌曲绑定优先，其次歌单/上下文绑定）

    func resolvedVideo(for song: Song?, context: PlayerManager.PlayContext?) -> ImmersiveVideo? {
        if let song, let v = video(withId: songBindings[Self.songBindingKey(song.id)]) {
            return v
        }
        if let context, let key = Self.contextBindingKey(context), let v = video(withId: contextBindings[key]) {
            return v
        }
        return nil
    }

    func resolvedVideoURL(for song: Song?, context: PlayerManager.PlayContext?) -> URL? {
        guard let v = resolvedVideo(for: song, context: context) else { return nil }
        let url = fileURL(for: v)
        return fm.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - 导入 / 删除 / 重命名

    @discardableResult
    func importVideo(from sourceURL: URL, displayName: String? = nil) -> ImmersiveVideo? {
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
            importedAt: Date()
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
        save()
    }

    // MARK: - 绑定操作

    func bindSong(_ songId: Int, to videoId: String?) {
        let key = Self.songBindingKey(songId)
        if let videoId { songBindings[key] = videoId } else { songBindings.removeValue(forKey: key) }
        save()
    }

    func bindContext(_ context: PlayerManager.PlayContext, to videoId: String?) {
        guard let key = Self.contextBindingKey(context) else { return }
        if let videoId { contextBindings[key] = videoId } else { contextBindings.removeValue(forKey: key) }
        save()
    }

    func boundVideoId(forSong songId: Int) -> String? {
        songBindings[Self.songBindingKey(songId)]
    }

    func boundVideoId(forContext context: PlayerManager.PlayContext) -> String? {
        guard let key = Self.contextBindingKey(context) else { return nil }
        return contextBindings[key]
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
        pruneMissingFiles()
    }

    /// 清理文件已不存在的库项与其绑定
    private func pruneMissingFiles() {
        let missing = library.filter { !fm.fileExists(atPath: fileURL(for: $0).path) }
        guard !missing.isEmpty else { return }
        let missingIds = Set(missing.map { $0.id })
        library.removeAll { missingIds.contains($0.id) }
        songBindings = songBindings.filter { !missingIds.contains($0.value) }
        contextBindings = contextBindings.filter { !missingIds.contains($0.value) }
        save()
    }

    private func save() {
        let enc = JSONEncoder()
        if let d = try? enc.encode(library) { defaults.set(d, forKey: libraryKey) }
        if let d = try? enc.encode(songBindings) { defaults.set(d, forKey: songKey) }
        if let d = try? enc.encode(contextBindings) { defaults.set(d, forKey: contextKey) }
    }
}
