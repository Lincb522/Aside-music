// APIService+Search.swift
// 搜索相关接口 - 基于 NCMClient 实现

import Foundation
import Combine
import NeteaseCloudMusicAPI

extension APIService {
    func searchSongs(keyword: String, offset: Int = 0) -> AnyPublisher<[Song], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.cloudsearch(
                keywords: keyword,
                type: .single,
                limit: 30,
                offset: offset
            )
            guard let result = response.body["result"] as? [String: Any],
                  let songsArray = result["songs"] as? [[String: Any]], !songsArray.isEmpty else {
                return [Song]()
            }
            
            // 直接从 cloudsearch 结果解析歌曲，不再额外调用 songDetail
            let songsData = try JSONSerialization.data(withJSONObject: songsArray)
            var songs = try JSONDecoder().decode([Song].self, from: songsData)
            
            // privilege 也在 cloudsearch 的 result 里（如果有的话）
            if let privArray = result["privileges"] as? [[String: Any]] {
                let privData = try JSONSerialization.data(withJSONObject: privArray)
                let privileges = try JSONDecoder().decode([Privilege].self, from: privData)
                let privDict = Dictionary(uniqueKeysWithValues: privileges.compactMap {
                    $0.id != nil ? ($0.id!, $0) : nil
                })
                for i in 0..<songs.count {
                    if let p = privDict[songs[i].id] {
                        songs[i].privilege = p
                    }
                }
            }
            return songs
        }
    }

    func fetchSearchSuggestions(keyword: String) -> AnyPublisher<[String], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.searchSuggest(keywords: keyword, type: .mobile)
            guard let result = response.body["result"] as? [String: Any],
                  let allMatch = result["allMatch"] as? [[String: Any]] else {
                return [String]()
            }
            return allMatch.compactMap { $0["keyword"] as? String }
        }
    }

    // MARK: - 搜索歌单
    
    func searchPlaylists(keyword: String, limit: Int = 30, offset: Int = 0) -> AnyPublisher<[Playlist], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.cloudsearch(
                keywords: keyword,
                type: .playlist,
                limit: limit,
                offset: offset
            )
            guard let result = response.body["result"] as? [String: Any],
                  let playlistsArray = result["playlists"] as? [[String: Any]] else {
                return [Playlist]()
            }
            let data = try JSONSerialization.data(withJSONObject: playlistsArray)
            return try JSONDecoder().decode([Playlist].self, from: data)
        }
    }
    
    // MARK: - 搜索专辑
    
    func searchAlbums(keyword: String, limit: Int = 30, offset: Int = 0) -> AnyPublisher<[SearchAlbum], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.cloudsearch(
                keywords: keyword,
                type: .album,
                limit: limit,
                offset: offset
            )
            guard let result = response.body["result"] as? [String: Any],
                  let albumsArray = result["albums"] as? [[String: Any]] else {
                return [SearchAlbum]()
            }
            let data = try JSONSerialization.data(withJSONObject: albumsArray)
            return try JSONDecoder().decode([SearchAlbum].self, from: data)
        }
    }
    
    // MARK: - 搜索 MV
    
    func searchMVs(keyword: String, limit: Int = 30, offset: Int = 0) -> AnyPublisher<[MV], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.cloudsearch(
                keywords: keyword,
                type: .mv,
                limit: limit,
                offset: offset
            )
            guard let result = response.body["result"] as? [String: Any],
                  let mvsArray = result["mvs"] as? [[String: Any]] else {
                return [MV]()
            }
            let data = try JSONSerialization.data(withJSONObject: mvsArray)
            return try JSONDecoder().decode([MV].self, from: data)
        }
    }
}

// MARK: - 搜索专辑模型

struct SearchAlbum: Identifiable, Codable {
    let id: Int
    let name: String
    let picUrl: String?
    let artist: Artist?
    let artists: [Artist]?
    let size: Int?          // 歌曲数量
    let publishTime: Int?
    
    var coverUrl: URL? {
        if let url = picUrl { return URL(string: url) }
        return nil
    }
    
    var artistName: String {
        if let artists = artists, !artists.isEmpty {
            return artists.map { $0.name }.joined(separator: " / ")
        }
        return artist?.name ?? ""
    }
}

// MARK: - 搜索响应模型（保持兼容）

struct SearchResponse: Codable {
    let result: SearchResult?
}
struct SearchResult: Codable {
    let songs: [Song]?
    let privileges: [Privilege]?
}

struct SearchSuggestResponse: Codable {
    let result: SearchSuggestResult?
}
struct SearchSuggestResult: Codable {
    let allMatch: [SearchSuggestionItem]?
}
struct SearchSuggestionItem: Codable {
    let keyword: String
}
