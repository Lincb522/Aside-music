import Foundation
import NeteaseCloudMusicAPI

/// 基于酷狗搜索的解灰音源（模糊匹配）
/// API: /music/search_with_url?keywords=歌名+歌手&quality=normal|high|sq|res
/// 返回结果直接包含 proxy_play_url，无需二次请求
class SearchUnblockSource: NCMUnblockSource {
    let name: String = "搜索解灰"
    let sourceType: UnblockSourceType = .httpUrl
    
    private let serverUrl: String
    private let session: URLSession
    
    init(serverUrl: String) {
        self.serverUrl = serverUrl.hasSuffix("/") ? String(serverUrl.dropLast()) : serverUrl
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }
    
    func match(id: Int, title: String?, artist: String?, quality: String) async throws -> UnblockResult {
        let songName = (title ?? "").trimmingCharacters(in: .whitespaces)
        let artistName = (artist ?? "").trimmingCharacters(in: .whitespaces)
        
        #if DEBUG
        print("[SearchUnblock] match 调用: id=\(id), title=\(songName), artist=\(artistName), quality=\(quality)")
        #endif
        
        guard !songName.isEmpty else {
            return UnblockResult(url: "", quality: quality, platform: name)
        }
        
        // quality 直接就是酷狗音质（normal/high/sq/res/viper_* 等），不做映射
        let searchQueries = buildSearchQueries(songName: songName, artistName: artistName)
        
        for query in searchQueries {
            if let result = try? await searchAndMatch(
                keywords: query, quality: quality,
                originalTitle: songName, originalArtist: artistName
            ), !result.url.isEmpty {
                return result
            }
        }
        
        return UnblockResult(url: "", quality: quality, platform: name)
    }
    
    // MARK: - 搜索策略
    
    private func buildSearchQueries(songName: String, artistName: String) -> [String] {
        var queries: [String] = []
        if !artistName.isEmpty {
            let firstArtist = artistName.components(separatedBy: CharacterSet(charactersIn: "/、,，&")).first?
                .trimmingCharacters(in: .whitespaces) ?? artistName
            queries.append("\(songName) \(firstArtist)")
        }
        queries.append(songName)
        let cleaned = cleanSongName(songName)
        if cleaned != songName && !cleaned.isEmpty {
            queries.append(cleaned)
        }
        return queries
    }
    
    private func cleanSongName(_ name: String) -> String {
        var cleaned = name
        for pattern in ["\\s*[\\(（].*?[\\)）]", "\\s*[\\[【].*?[\\]】]",
                        "\\s*-\\s*(remix|live|cover|翻唱|伴奏|inst).*$"] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
            }
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - 搜索 & 匹配
    
    private func searchAndMatch(
        keywords: String, quality: String,
        originalTitle: String, originalArtist: String
    ) async throws -> UnblockResult? {
        var components = URLComponents(string: "\(serverUrl)/music/search_with_url")!
        components.queryItems = [
            URLQueryItem(name: "keywords", value: keywords),
            URLQueryItem(name: "quality", value: quality)
        ]
        guard let url = components.url else { return nil }
        
        #if DEBUG
        print("[SearchUnblock] 搜索: \(keywords) quality=\(quality)")
        #endif
        
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        
        #if DEBUG
        if let s = String(data: data, encoding: .utf8) { print("[SearchUnblock] 响应: \(String(s.prefix(300)))") }
        #endif
        
        let lists = extractLists(from: json)
        guard !lists.isEmpty else {
            #if DEBUG
            print("[SearchUnblock] 搜索结果为空")
            #endif
            return nil
        }
        
        guard let best = fuzzyMatch(results: lists, title: originalTitle, artist: originalArtist) else {
            return nil
        }
        
        // search_with_url 直接返回播放地址
        let playUrl = best["proxy_play_url"] as? String
            ?? best["play_url"] as? String
            ?? ""
        
        guard !playUrl.isEmpty else {
            #if DEBUG
            print("[SearchUnblock] 匹配成功但无播放地址")
            #endif
            return nil
        }
        
        #if DEBUG
        print("[SearchUnblock] ✅ 播放地址: \(playUrl)")
        #endif
        
        return UnblockResult(url: playUrl, quality: quality, platform: name, extra: best)
    }
    
    // MARK: - 数据解析
    
    /// 响应结构: { code:200, data: { lists: [...] } } 或 { code:200, data: { data: { lists: [...] } } }
    private func extractLists(from json: [String: Any]) -> [[String: Any]] {
        if let d1 = json["data"] as? [String: Any] {
            if let lists = d1["lists"] as? [[String: Any]], !lists.isEmpty { return lists }
            if let d2 = d1["data"] as? [String: Any],
               let lists = d2["lists"] as? [[String: Any]], !lists.isEmpty { return lists }
        }
        return []
    }
    
    // MARK: - 模糊匹配
    
    private func fuzzyMatch(results: [[String: Any]], title: String, artist: String) -> [String: Any]? {
        let nTitle = normalize(title)
        let nArtist = normalize(artist)
        var bestMatch: [String: Any]?
        var bestScore: Double = 0
        
        for item in results {
            let fileName = item["FileName"] as? String ?? ""
            let singerName = item["SingerName"] as? String ?? ""
            let itemTitle: String
            if let r = fileName.range(of: " - ") {
                itemTitle = String(fileName[r.upperBound...])
            } else {
                itemTitle = fileName
            }
            
            let titleScore = similarity(nTitle, normalize(itemTitle))
            let artistScore = artist.isEmpty ? 1.0 : similarity(nArtist, normalize(singerName))
            let totalScore = titleScore * 0.7 + artistScore * 0.3
            
            #if DEBUG
            print("[SearchUnblock] 匹配: \"\(fileName)\" → \(String(format: "%.2f", totalScore))")
            #endif
            
            if totalScore > bestScore {
                bestScore = totalScore
                bestMatch = item
            }
        }
        
        guard bestScore >= 0.4 else {
            #if DEBUG
            print("[SearchUnblock] 最佳分数 \(String(format: "%.2f", bestScore)) 低于阈值")
            #endif
            return nil
        }
        
        #if DEBUG
        if let m = bestMatch {
            print("[SearchUnblock] ✅ 最佳: \"\(m["FileName"] ?? "")\" 分数 \(String(format: "%.2f", bestScore))")
        }
        #endif
        return bestMatch
    }
    
    // MARK: - 字符串相似度
    
    private func normalize(_ str: String) -> String {
        str.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: "\u{4E00}"..."\u{9FFF}")).inverted)
            .joined()
    }
    
    private func similarity(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty && !b.isEmpty else { return a == b ? 1.0 : 0.0 }
        if a.contains(b) || b.contains(a) {
            return max(Double(min(a.count, b.count)) / Double(max(a.count, b.count)), 0.8)
        }
        let ac = Array(a), bc = Array(b)
        let m = ac.count, n = bc.count
        if Double(min(m, n)) / Double(max(m, n)) < 0.3 { return 0.2 }
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m { for j in 1...n {
            dp[i][j] = ac[i-1] == bc[j-1] ? dp[i-1][j-1] + 1 : max(dp[i-1][j], dp[i][j-1])
        }}
        return Double(dp[m][n] * 2) / Double(m + n)
    }
}
