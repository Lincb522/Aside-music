// APIService+QQMusic.swift
// QQ 音乐 API 桥接层
// 将 QQMusicKit 的 async/await 接口适配到 AsideMusic 的 Song 模型和 Combine 体系

import Foundation
import Combine
import QQMusicKit

// MARK: - QQ 音乐配置

extension APIService {
    
    /// QQ 音乐客户端（使用默认配置）
    var qqClient: QQMusicClient {
        QQMusicClient.shared
    }
}

// MARK: - QQ 音乐搜索

extension APIService {
    
    /// 搜索 QQ 音乐歌曲
    func searchQQSongs(keyword: String, page: Int = 1, num: Int = 30) -> AnyPublisher<[Song], Error> {
        Future<[Song], Error> { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }
            Task {
                do {
                    let results = try await self.qqClient.search(
                        keyword: keyword,
                        type: .song,
                        num: num,
                        page: page,
                        highlight: false
                    )
                    let songs = results.compactMap { Self.convertQQSongToSong($0) }
                    promise(.success(songs))
                } catch {
                    AppLogger.error("[QQMusic] 搜索失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// 搜索 QQ 音乐歌手
    func searchQQArtists(keyword: String, page: Int = 1, num: Int = 30) -> AnyPublisher<[ArtistInfo], Error> {
        Future<[ArtistInfo], Error> { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }
            Task {
                do {
                    let results = try await self.qqClient.search(
                        keyword: keyword,
                        type: .singer,
                        num: num,
                        page: page,
                        highlight: false
                    )
                    let artists = results.compactMap { Self.convertQQArtistToArtistInfo($0) }
                    promise(.success(artists))
                } catch {
                    AppLogger.error("[QQMusic] 搜索歌手失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// 搜索 QQ 音乐歌单
    func searchQQPlaylists(keyword: String, page: Int = 1, num: Int = 30) -> AnyPublisher<[Playlist], Error> {
        Future<[Playlist], Error> { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }
            Task {
                do {
                    let results = try await self.qqClient.search(
                        keyword: keyword,
                        type: .songlist,
                        num: num,
                        page: page,
                        highlight: false
                    )
                    let playlists = results.compactMap { Self.convertQQPlaylistToPlaylist($0) }
                    promise(.success(playlists))
                } catch {
                    AppLogger.error("[QQMusic] 搜索歌单失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// 搜索 QQ 音乐专辑
    func searchQQAlbums(keyword: String, page: Int = 1, num: Int = 30) -> AnyPublisher<[SearchAlbum], Error> {
        Future<[SearchAlbum], Error> { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }
            Task {
                do {
                    let results = try await self.qqClient.search(
                        keyword: keyword,
                        type: .album,
                        num: num,
                        page: page,
                        highlight: false
                    )
                    let albums = results.compactMap { Self.convertQQAlbumToSearchAlbum($0) }
                    promise(.success(albums))
                } catch {
                    AppLogger.error("[QQMusic] 搜索专辑失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}

// MARK: - QQ 音乐播放 URL

extension APIService {
    
    /// 获取 QQ 音乐歌曲播放 URL
    func fetchQQSongUrl(mid: String, fileType: SongFileType = .mp3_128) -> AnyPublisher<SongUrlResult, Error> {
        Future<SongUrlResult, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(PlaybackError.unavailable))
                return
            }
            Task {
                // 先尝试用户指定的音质
                do {
                    if let url = try await self.qqClient.songURL(mid: mid, fileType: fileType),
                       !url.isEmpty {
                        promise(.success(SongUrlResult(url: url, isUnblocked: false)))
                        return
                    }
                } catch {
                    AppLogger.warning("[QQMusic] \(fileType.displayName) 请求失败，尝试降级: \(error.localizedDescription)")
                }
                
                // 降级尝试较低音质（catch 异常 + 空 URL 都走这里）
                if let fallbackUrl = await self.qqFallbackURL(mid: mid, excluding: fileType) {
                    promise(.success(SongUrlResult(url: fallbackUrl, isUnblocked: false)))
                } else {
                    AppLogger.error("[QQMusic] 所有音质均无法获取播放 URL: \(mid)")
                    promise(.failure(PlaybackError.unavailable))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// QQ 音乐音质降级策略（每个音质独立 catch，不会因单个失败中断）
    private func qqFallbackURL(mid: String, excluding: SongFileType? = nil) async -> String? {
        let fallbackTypes: [SongFileType] = [.mp3_320, .mp3_128, .aac96]
        for type in fallbackTypes {
            if type == excluding { continue }
            do {
                if let url = try await qqClient.songURL(mid: mid, fileType: type), !url.isEmpty {
                    AppLogger.info("[QQMusic] 降级到 \(type.displayName) 成功")
                    return url
                }
            } catch {
                AppLogger.warning("[QQMusic] 降级 \(type.displayName) 失败: \(error.localizedDescription)")
                continue
            }
        }
        return nil
    }
}

// MARK: - QQ 音乐歌词

extension APIService {
    
    /// 获取 QQ 音乐歌词
    func fetchQQLyric(mid: String) -> AnyPublisher<QQLyricResponse, Error> {
        Future<QQLyricResponse, Error> { [weak self] promise in
            guard let self = self else {
                promise(.success(QQLyricResponse(lyric: nil, trans: nil)))
                return
            }
            Task {
                do {
                    let result = try await self.qqClient.lyric(
                        value: mid,
                        qrc: false,
                        trans: true,
                        roma: false
                    )
                    promise(.success(QQLyricResponse(
                        lyric: result.lyric,
                        trans: result.trans
                    )))
                } catch {
                    AppLogger.error("[QQMusic] 获取歌词失败: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}

/// QQ 音乐歌词响应
struct QQLyricResponse {
    let lyric: String?
    let trans: String?
}

// MARK: - QQ 音乐热搜

extension APIService {
    
    /// 获取 QQ 音乐热搜词
    func fetchQQHotSearch() -> AnyPublisher<[HotSearchItem], Error> {
        Future<[HotSearchItem], Error> { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }
            Task {
                do {
                    let result = try await self.qqClient.hotkey()
                    let items = Self.convertQQHotkeys(result)
                    promise(.success(items))
                } catch {
                    AppLogger.error("[QQMusic] 获取热搜失败: \(error)")
                    promise(.success([]))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}
