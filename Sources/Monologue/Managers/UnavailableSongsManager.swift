// UnavailableSongsManager.swift
// Monologue
//
// 运行时记录播放失败（通常是数字专辑未购/无版权）的歌曲。
// UI 层据此显示灰色禁用状态，播放层据此避免在列表播放时反复尝试。
//
// 只在本次运行生命周期内保留，App 重启后清空，给后端兜底账号池一个重新尝试的机会。

import Foundation
import Combine

@MainActor
final class UnavailableSongsManager: ObservableObject {
    static let shared = UnavailableSongsManager()

    /// 失败原因分类
    enum Reason: Equatable {
        /// 无版权/数字专辑未购（服务器兜底全失败）
        case unavailable
        /// 网络暂时错误（可重试）
        case transient
    }

    /// key = 组合 ID，避免 ncm/qcm id 冲突
    private struct SongKey: Hashable {
        let id: Int
        let source: String  // "ncm" / "qq" / "qsm" / "local"
    }

    /// 失败歌曲标记
    @Published private var failures: [SongKey: Reason] = [:]

    private init() {}

    // MARK: - Mark

    /// 标记一首歌无版权
    func markUnavailable(song: Song) {
        let key = makeKey(song: song)
        failures[key] = .unavailable
        AppLogger.info("[Unavailable] 标记无版权: \(song.name) (\(key.source)/\(song.id))")
    }

    /// 标记一首歌遭遇短暂性错误（不永久标记，后续可再试）
    func markTransient(song: Song) {
        let key = makeKey(song: song)
        // 仅在还没被标记为无版权时才打临时标签
        if failures[key] == nil {
            failures[key] = .transient
        }
    }

    /// 清除某首歌的失败标记（比如用户手动重试成功）
    func clear(song: Song) {
        failures.removeValue(forKey: makeKey(song: song))
    }

    /// 一键清空所有失败标记
    func clearAll() {
        failures.removeAll()
    }

    // MARK: - Query

    /// 是否被标记为不可播放
    func isUnavailable(song: Song) -> Bool {
        failures[makeKey(song: song)] == .unavailable
    }

    /// 是否被标记（不可播放或短暂错误）
    func isFlagged(song: Song) -> Bool {
        failures[makeKey(song: song)] != nil
    }

    // MARK: - Helpers

    private func makeKey(song: Song) -> SongKey {
        let source: String
        switch song.musicSource {
        case .netease: source = "ncm"
        case .qqmusic: source = "qq"
        case .qishui: source = "qsm"
        case .local: source = "local"
        }
        return SongKey(id: song.id, source: source)
    }
}
