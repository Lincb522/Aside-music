//
//  MediaIntentHandler.swift
//  Monologue
//
//  Siri 语音搜索播放 — 基于 App Intents (iOS 17+)
//

import AppIntents
import Combine

// MARK: - 歌曲搜索实体（用于 Siri 短语参数）

struct SongQuery: AppEntity {
    var id: String

    static let defaultQuery = SongStringQuery()
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "歌曲名称")

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

struct SongStringQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SongQuery] {
        identifiers.map { SongQuery(id: $0) }
    }

    func entities(matching string: String) async throws -> [SongQuery] {
        [SongQuery(id: string)]
    }

    @MainActor
    func suggestedEntities() async throws -> [SongQuery] {
        PlayerManager.shared.history.prefix(10).map { SongQuery(id: $0.name) }
    }
}

// MARK: - App Intent

struct PlaySongIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "播放歌曲"
    static let description = IntentDescription("在独白音乐中搜索并播放歌曲")

    @Parameter(title: "歌曲名称")
    var song: SongQuery

    @MainActor
    func perform() async throws -> some IntentResult {
        let keyword = song.id
        AppLogger.info("[Siri] PlaySongIntent: \(keyword)")

        let songs = try await SiriSearchHelper.searchAllSources(keyword: keyword)
        guard let first = songs.first else {
            throw SiriPlaybackError.noResults
        }
        PlayerManager.shared.playReplacingContext(song: first, in: songs)
        return .result()
    }

    enum SiriPlaybackError: Error, CustomLocalizedStringResourceConvertible {
        case noResults
        var localizedStringResource: LocalizedStringResource { "未找到匹配歌曲" }
    }
}

// MARK: - Siri Shortcuts 注册

struct MonologueShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlaySongIntent(),
            phrases: [
                "用\(.applicationName)播放\(\.$song)",
                "在\(.applicationName)播放\(\.$song)",
                "\(.applicationName)播放\(\.$song)",
            ],
            shortTitle: "播放歌曲",
            systemImageName: "play.fill"
        )

        AppShortcut(
            intent: OpenGameModeIntent(),
            phrases: [
                "打开\(.applicationName)游戏模式",
                "开启\(.applicationName)游戏模式",
                "启动\(.applicationName)游戏模式",
                "\(.applicationName)开始游戏模式",
            ],
            shortTitle: "开启游戏模式",
            systemImageName: "gamecontroller.fill"
        )

        AppShortcut(
            intent: ExitGameModeIntent(),
            phrases: [
                "关闭\(.applicationName)游戏模式",
                "退出\(.applicationName)游戏模式",
                "\(.applicationName)结束游戏模式",
            ],
            shortTitle: "关闭游戏模式",
            systemImageName: "gamecontroller"
        )

        AppShortcut(
            intent: ToggleGameModeIntent(),
            phrases: [
                "切换\(.applicationName)游戏模式",
            ],
            shortTitle: "切换游戏模式",
            systemImageName: "gamecontroller"
        )
    }
}

// MARK: - 搜索工具（NCM + QQ 并发）

enum SiriSearchHelper {

    static func searchAllSources(keyword: String) async throws -> [Song] {
        async let ncmTask = searchNCM(keyword: keyword)
        async let qqTask = searchQQ(keyword: keyword)

        let ncmSongs = (try? await ncmTask) ?? []
        let qqSongs = (try? await qqTask) ?? []

        var merged = ncmSongs
        let existingIDs = Set(ncmSongs.map(\.id))
        for song in qqSongs where !existingIDs.contains(song.id) {
            merged.append(song)
        }

        guard !merged.isEmpty else {
            throw PlaySongIntent.SiriPlaybackError.noResults
        }
        return merged
    }

    private static func searchNCM(keyword: String) async throws -> [Song] {
        try await withCheckedThrowingContinuation { continuation in
            var finished = false
            var cancellable: AnyCancellable?
            cancellable = APIService.shared.searchSongs(keyword: keyword, offset: 0)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        guard !finished else { return }
                        finished = true
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                        withExtendedLifetime(cancellable) {}
                    },
                    receiveValue: { songs in
                        guard !finished else { return }
                        finished = true
                        continuation.resume(returning: songs)
                    }
                )
        }
    }

    private static func searchQQ(keyword: String) async throws -> [Song] {
        try await withCheckedThrowingContinuation { continuation in
            var finished = false
            var cancellable: AnyCancellable?
            cancellable = APIService.shared.searchQQSongs(keyword: keyword, page: 1, num: 15)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        guard !finished else { return }
                        finished = true
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                        withExtendedLifetime(cancellable) {}
                    },
                    receiveValue: { songs in
                        guard !finished else { return }
                        finished = true
                        continuation.resume(returning: songs)
                    }
                )
        }
    }
}
