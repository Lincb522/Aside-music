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
