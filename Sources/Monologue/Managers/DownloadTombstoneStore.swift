import Foundation

/// 下载删除墓碑：记录用户明确删除过的下载条目。
///
/// 云端快照的应用（登录引导、下拉刷新、跨设备恢复）会把云端下载记录
/// 重新写回本地；没有墓碑时，刚删除、还没来得及上传的条目会被立刻复活，
/// 表现为「下载记录删除不了/删了又回来」。墓碑让本地删除在同步窗口内
/// 保持权威，云端恢复会跳过墓碑条目；重新下载时清除对应墓碑。
@MainActor
final class DownloadTombstoneStore {
    static let shared = DownloadTombstoneStore()

    private static let storageKey = "monologue_download_tombstones_v1"
    /// 墓碑保留时长（此后自动过期；届时删除早已随快照上传覆盖云端）
    private static let lifetime: TimeInterval = 90 * 24 * 3600
    private static let maxEntries = 1000

    /// uniqueKey -> 删除时间
    private var keyTombstones: [String: Date] = [:]
    /// songId -> 删除时间
    private var idTombstones: [Int: Date] = [:]

    private init() {
        load()
        pruneExpired()
    }

    // MARK: - 查询

    func isTombstoned(key: String) -> Bool {
        guard let date = keyTombstones[key] else { return false }
        return Date().timeIntervalSince(date) < Self.lifetime
    }

    func isTombstoned(songId: Int) -> Bool {
        guard let date = idTombstones[songId] else { return false }
        return Date().timeIntervalSince(date) < Self.lifetime
    }

    // MARK: - 写入

    func markDeleted(keys: Set<String>, songId: Int?) {
        let now = Date()
        for key in keys where !key.isEmpty {
            keyTombstones[key] = now
        }
        if let songId {
            idTombstones[songId] = now
        }
        pruneIfNeeded()
        save()
    }

    func markDeleted(records: [DownloadedSong]) {
        guard !records.isEmpty else { return }
        let now = Date()
        for record in records {
            keyTombstones[record.uniqueKey] = now
            idTombstones[record.id] = now
        }
        pruneIfNeeded()
        save()
    }

    /// 重新下载时清除这首歌的所有墓碑（含历史 key 变体）
    func clearTombstones(for song: Song) {
        var changed = false
        var candidates: Set<String> = [
            "ncm_\(song.id)",
            "qq_\(song.id)",
            "qsm_\(song.id)",
        ]
        if let trackId = song.qishuiTrackId {
            candidates.insert("qishui_\(trackId)")
        }
        for key in candidates where keyTombstones.removeValue(forKey: key) != nil {
            changed = true
        }
        if idTombstones.removeValue(forKey: song.id) != nil {
            changed = true
        }
        if changed { save() }
    }

    // MARK: - 持久化

    private struct Payload: Codable {
        var keys: [String: Date]
        var ids: [String: Date]
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return
        }
        keyTombstones = payload.keys
        idTombstones = payload.ids.reduce(into: [:]) { result, entry in
            if let id = Int(entry.key) {
                result[id] = entry.value
            }
        }
    }

    private func save() {
        let payload = Payload(
            keys: keyTombstones,
            ids: idTombstones.reduce(into: [:]) { $0[String($1.key)] = $1.value }
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func pruneExpired() {
        let cutoff = Date().addingTimeInterval(-Self.lifetime)
        let beforeKeys = keyTombstones.count
        let beforeIds = idTombstones.count
        keyTombstones = keyTombstones.filter { $0.value > cutoff }
        idTombstones = idTombstones.filter { $0.value > cutoff }
        if keyTombstones.count != beforeKeys || idTombstones.count != beforeIds {
            save()
        }
    }

    private func pruneIfNeeded() {
        if keyTombstones.count > Self.maxEntries {
            let sorted = keyTombstones.sorted { $0.value < $1.value }
            for entry in sorted.prefix(keyTombstones.count - Self.maxEntries) {
                keyTombstones.removeValue(forKey: entry.key)
            }
        }
        if idTombstones.count > Self.maxEntries {
            let sorted = idTombstones.sorted { $0.value < $1.value }
            for entry in sorted.prefix(idTombstones.count - Self.maxEntries) {
                idTombstones.removeValue(forKey: entry.key)
            }
        }
    }
}
