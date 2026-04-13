import Foundation
import NeteaseCloudMusicAPI
import Combine

/// 基于 qcm搜索的解灰音源（模糊匹配）
/// 当ncm歌曲无版权时，自动搜索 qcm匹配歌曲并获取播放 URL
class SearchUnblockSource: NCMUnblockSource {
    let name: String = String(localized: "QCM解灰")
    let sourceType: UnblockSourceType = .httpUrl
    
    init() {}
    
    func match(id: Int, title: String?, artist: String?, quality: String) async throws -> UnblockResult {
        let songName = (title ?? "").trimmingCharacters(in: .whitespaces)
        let artistName = (artist ?? "").trimmingCharacters(in: .whitespaces)
        
        #if DEBUG
        print("[QQUnblock] match: id=\(id), title=\(songName), artist=\(artistName), quality=\(quality)")
        #endif
        
        guard !songName.isEmpty else {
            return UnblockResult(url: "", quality: quality, platform: name)
        }
        
        let qqQuality = QQMusicQuality(rawValue: quality) ?? .mp3_320
        let searchQueries = buildSearchQueries(songName: songName, artistName: artistName)
        
        for query in searchQueries {
            if let result = try? await searchAndMatch(
                keywords: query, quality: qqQuality,
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
                        String(localized: "\\s*-\\s*(remix|live|cover|翻唱|伴奏|inst).*$")] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
            }
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - 搜索 & 匹配

    private func searchAndMatch(
        keywords: String, quality: QQMusicQuality,
        originalTitle: String, originalArtist: String
    ) async throws -> UnblockResult? {
        #if DEBUG
        print("[QQUnblock] 搜索: \(keywords)")
        #endif
        
        let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            var cancellable: AnyCancellable?
            cancellable = APIService.shared.searchQQSongs(keyword: keywords, page: 1, num: 10)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion, !resumed {
                        resumed = true
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                }, receiveValue: { songs in
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(returning: songs)
                    cancellable?.cancel()
                })
        }
        
        guard !songs.isEmpty else {
            #if DEBUG
            print("[QQUnblock] 搜索结果为空")
            #endif
            return nil
        }
        
        guard let best = fuzzyMatch(songs: songs, title: originalTitle, artist: originalArtist) else {
            return nil
        }
        
        guard let mid = best.qqMid else {
            #if DEBUG
            print("[QQUnblock] 匹配成功但无 qqMid")
            #endif
            return nil
        }
        
        let urlResult: APIService.SongUrlResult = try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            var cancellable: AnyCancellable?
            cancellable = APIService.shared.fetchQQSongUrl(mid: mid, quality: quality)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion, !resumed {
                        resumed = true
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                }, receiveValue: { result in
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(returning: result)
                    cancellable?.cancel()
                })
        }
        
        guard !urlResult.url.isEmpty else {
            #if DEBUG
            print("[QQUnblock] 匹配成功但无法获取播放 URL")
            #endif
            return nil
        }
        
        #if DEBUG
        print("[QQUnblock] ✅ 匹配: \(best.name) - \(best.artistName), URL: \(urlResult.url.prefix(80))...")
        #endif
        
        var extra: [String: Any] = ["qqMid": mid]
        if let ekey = urlResult.qmcEkey {
            extra["qmcEkey"] = ekey
        }
        return UnblockResult(url: urlResult.url, quality: quality.rawValue, platform: name, extra: extra)
    }
    
    // MARK: - 模糊匹配
    
    private func fuzzyMatch(songs: [Song], title: String, artist: String) -> Song? {
        let nTitle = normalize(title)
        let nArtist = normalize(artist)
        var bestMatch: Song?
        var bestScore: Double = 0
        
        for song in songs {
            let titleScore = similarity(nTitle, normalize(song.name))
            let artistScore = artist.isEmpty ? 1.0 : similarity(nArtist, normalize(song.artistName))
            let totalScore = titleScore * 0.7 + artistScore * 0.3
            
            #if DEBUG
            print("[QQUnblock] 匹配: \"\(song.name) - \(song.artistName)\" → \(String(format: "%.2f", totalScore))")
            #endif
            
            if totalScore > bestScore {
                bestScore = totalScore
                bestMatch = song
            }
        }
        
        guard bestScore >= 0.4 else {
            #if DEBUG
            print("[QQUnblock] 最佳分数 \(String(format: "%.2f", bestScore)) 低于阈值")
            #endif
            return nil
        }
        
        #if DEBUG
        if let m = bestMatch {
            print("[QQUnblock] ✅ 最佳: \"\(m.name) - \(m.artistName)\" 分数 \(String(format: "%.2f", bestScore))")
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
