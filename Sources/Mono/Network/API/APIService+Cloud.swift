// 云盘相关 API 接口

import Foundation
import Combine
import NeteaseCloudMusicAPI

extension APIService {
    
    // MARK: - 获取云盘歌曲列表
    
    func fetchCloudSongs(limit: Int = 30, offset: Int = 0) -> AnyPublisher<CloudListResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.userCloud(limit: limit, offset: offset)
            
            let count = response.body["count"] as? Int ?? 0
            let hasMore = response.body["hasMore"] as? Bool ?? false
            let size = response.body["size"] as? String ?? "0"
            let maxSize = response.body["maxSize"] as? String ?? "0"
            
            var songs: [CloudSong] = []
            if let dataArray = response.body["data"] as? [[String: Any]] {
                for item in dataArray {
                    let songId = item["songId"] as? Int ?? 0
                    let songName = item["songName"] as? String ?? ""
                    let artist = item["artist"] as? String ?? ""
                    let album = item["album"] as? String ?? ""
                    let fileSize = item["fileSize"] as? Int ?? 0
                    let bitrate = item["bitrate"] as? Int ?? 0
                    let addTime = item["addTime"] as? Int
                    let fileName = item["fileName"] as? String
                    let cover = item["cover"] as? Int
                    
                    // 解析 simpleSong
                    var simpleSong: Song? = nil
                    if let simpleSongDict = item["simpleSong"] as? [String: Any] {
                        if let data = try? JSONSerialization.data(withJSONObject: simpleSongDict),
                           let decoded = try? JSONDecoder().decode(Song.self, from: data) {
                            simpleSong = decoded
                        }
                    }
                    
                    songs.append(CloudSong(
                        songId: songId,
                        songName: songName,
                        artist: artist,
                        album: album,
                        fileSize: fileSize,
                        bitrate: bitrate,
                        addTime: addTime,
                        fileName: fileName,
                        cover: cover,
                        simpleSong: simpleSong
                    ))
                }
            }

            return CloudListResponse(
                data: songs,
                count: count,
                hasMore: hasMore,
                size: size,
                maxSize: maxSize
            )
        }
    }

    func enrichCloudSongsMetadata(_ songs: [CloudSong], forceQQMetadata: Bool = false) async -> [CloudSong] {
        guard !songs.isEmpty else { return songs }
        return await enrichCloudSongsIfNeeded(songs, forceQQMetadata: forceQQMetadata)
    }

    private func enrichCloudSongsIfNeeded(_ songs: [CloudSong], forceQQMetadata: Bool) async -> [CloudSong] {
        let missingDetailIDs = songs
            .filter { $0.simpleSong == nil || $0.simpleSong?.coverUrl == nil }
            .map(\.songId)

        var enrichedSongs = songs

        if !missingDetailIDs.isEmpty {
            do {
                let detailedSongs = try await fetchSongDetails(ids: missingDetailIDs).async()
                let detailMap = Dictionary(uniqueKeysWithValues: detailedSongs.map { ($0.id, $0) })

                enrichedSongs = songs.map { song in
                    let resolvedSong = detailMap[song.songId] ?? song.simpleSong
                    return CloudSong(
                        songId: song.songId,
                        songName: song.songName,
                        artist: song.artist,
                        album: song.album,
                        fileSize: song.fileSize,
                        bitrate: song.bitrate,
                        addTime: song.addTime,
                        fileName: song.fileName,
                        cover: song.cover,
                        simpleSong: resolvedSong
                    )
                }
            } catch {
                AppLogger.warning("云盘歌曲详情富化失败: \(error.localizedDescription)")
            }
        }

        return await enrichCloudSongsWithQQMetadata(enrichedSongs, forceQQMetadata: forceQQMetadata)
    }

    private func enrichCloudSongsWithQQMetadata(_ songs: [CloudSong], forceQQMetadata: Bool) async -> [CloudSong] {
        var enrichedSongs = songs

        for index in enrichedSongs.indices {
            let cloudSong = enrichedSongs[index]
            let baseSong = cloudSong.toSong()
            let needsQQMetadata = forceQQMetadata || cloudSong.simpleSong == nil || baseSong.coverUrl == nil

            guard needsQQMetadata else { continue }
            let ncmSong = await searchNCMMatchForCloudSong(name: cloudSong.songName, artist: cloudSong.artist)
            let qqSong = await searchQQMatchForCloudSong(name: cloudSong.songName, artist: cloudSong.artist)

            guard ncmSong != nil || qqSong != nil else {
                AppLogger.info("云盘歌曲未匹配到补全元数据: \(cloudSong.songName) - \(cloudSong.artist)")
                continue
            }

            let mergedSong = mergeCloudSong(baseSong: baseSong, ncmSong: ncmSong, qqSong: qqSong)
            enrichedSongs[index] = CloudSong(
                songId: cloudSong.songId,
                songName: cloudSong.songName,
                artist: cloudSong.artist,
                album: cloudSong.album,
                fileSize: cloudSong.fileSize,
                bitrate: cloudSong.bitrate,
                addTime: cloudSong.addTime,
                fileName: cloudSong.fileName,
                cover: cloudSong.cover,
                simpleSong: mergedSong
            )
            AppLogger.info("云盘歌曲已补全元数据: \(cloudSong.songName) - \(cloudSong.artist)")
        }

        return enrichedSongs
    }

    private func searchNCMMatchForCloudSong(name: String, artist: String) async -> Song? {
        let queries = buildSearchQueries(songName: name, artistName: artist)

        for query in queries {
            do {
                let songs = try await searchSongs(keyword: query, offset: 0).async()
                if let match = bestPlatformMatch(from: songs, title: name, artist: artist) {
                    return match
                }
            } catch {
                AppLogger.warning("云盘歌曲 NCM 匹配失败: \(query) - \(error.localizedDescription)")
            }
        }

        return nil
    }

    private func searchQQMatchForCloudSong(name: String, artist: String) async -> Song? {
        let queries = buildSearchQueries(songName: name, artistName: artist)

        for query in queries {
            do {
                let songs = try await searchQQSongs(keyword: query, page: 1, num: 10).async()
                if let match = bestPlatformMatch(from: songs, title: name, artist: artist) {
                    return match
                }
            } catch {
                AppLogger.warning("云盘歌曲 QCM 匹配失败: \(query) - \(error.localizedDescription)")
            }
        }

        return nil
    }

    private func buildSearchQueries(songName: String, artistName: String) -> [String] {
        var queries: [String] = []

        let trimmedSong = songName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedArtist = artistName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedArtist.isEmpty {
            let firstArtist = trimmedArtist
                .components(separatedBy: CharacterSet(charactersIn: "/、,，&"))
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmedArtist
            queries.append("\(trimmedSong) \(firstArtist)")
            queries.append("\(firstArtist) \(trimmedSong)")
        }

        queries.append(trimmedSong)

        let cleaned = cleanSongName(trimmedSong)
        if !cleaned.isEmpty, cleaned != trimmedSong {
            queries.append(cleaned)
        }

        return Array(NSOrderedSet(array: queries)) as? [String] ?? queries
    }

    private func cleanSongName(_ name: String) -> String {
        var cleaned = name
        for pattern in [
            "\\s*[\\(（].*?[\\)）]",
            "\\s*[\\[【].*?[\\]】]",
            String(localized: "\\s*-\\s*(remix|live|cover|翻唱|伴奏|inst).*$")
        ] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: ""
                )
            }
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func bestPlatformMatch(from songs: [Song], title: String, artist: String) -> Song? {
        let normalizedTitle = normalizeMatchText(title)
        let normalizedArtist = normalizeMatchText(artist)

        var bestMatch: Song?
        var bestScore = 0.0

        for song in songs {
            let titleScore = similarityScore(normalizedTitle, normalizeMatchText(song.name))
            let artistScore = artist.isEmpty ? 1.0 : similarityScore(normalizedArtist, normalizeMatchText(song.artistName))
            let totalScore = titleScore * 0.72 + artistScore * 0.28

            if totalScore > bestScore {
                bestScore = totalScore
                bestMatch = song
            }
        }

        return bestScore >= 0.4 ? bestMatch : nil
    }

    private func normalizeMatchText(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: "\u{4E00}"..."\u{9FFF}")).inverted)
            .joined()
    }

    private func similarityScore(_ lhs: String, _ rhs: String) -> Double {
        guard !lhs.isEmpty && !rhs.isEmpty else { return lhs == rhs ? 1.0 : 0.0 }
        if lhs.contains(rhs) || rhs.contains(lhs) {
            return max(Double(min(lhs.count, rhs.count)) / Double(max(lhs.count, rhs.count)), 0.8)
        }

        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        let m = lhsChars.count
        let n = rhsChars.count

        if Double(min(m, n)) / Double(max(m, n)) < 0.3 {
            return 0.2
        }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                dp[i][j] = lhsChars[i - 1] == rhsChars[j - 1]
                    ? dp[i - 1][j - 1] + 1
                    : max(dp[i - 1][j], dp[i][j - 1])
            }
        }

        return Double(dp[m][n] * 2) / Double(m + n)
    }

    private func mergeCloudSong(baseSong: Song, ncmSong: Song?, qqSong: Song?) -> Song {
        let baseAlbum = baseSong.al
        let ncmAlbum = ncmSong?.al
        let qqAlbum = qqSong?.al
        let coverURL = baseAlbum?.picUrl
            ?? ncmSong?.coverUrl?.absoluteString
            ?? qqSong?.coverUrl?.absoluteString
        let mergedAlbum: Album? =
            if baseAlbum != nil || ncmAlbum != nil || qqAlbum != nil || coverURL != nil {
                Album(
                    id: baseAlbum?.id ?? ncmAlbum?.id ?? qqAlbum?.id ?? 0,
                    name: (baseAlbum?.name.isEmpty == false ? baseAlbum?.name : (ncmAlbum?.name.isEmpty == false ? ncmAlbum?.name : qqAlbum?.name)) ?? "",
                    picUrl: coverURL
                )
            } else {
                nil
            }

        var mergedSong = Song(
            id: baseSong.id,
            name: baseSong.name,
            ar: baseSong.ar ?? ncmSong?.ar ?? qqSong?.ar,
            al: mergedAlbum,
            dt: baseSong.dt ?? ncmSong?.dt ?? qqSong?.dt,
            fee: baseSong.fee,
            mv: baseSong.mv ?? ncmSong?.mv ?? qqSong?.mv,
            h: baseSong.h,
            m: baseSong.m,
            l: baseSong.l,
            sq: baseSong.sq,
            hr: baseSong.hr,
            alia: baseSong.alia
        )

        mergedSong.privilege = baseSong.privilege
        mergedSong.podcastCoverUrl = baseSong.podcastCoverUrl
        mergedSong.source = baseSong.source ?? .netease
        mergedSong.qqMid = baseSong.qqMid ?? qqSong?.qqMid
        mergedSong.qqAlbumMid = baseSong.qqAlbumMid ?? qqSong?.qqAlbumMid
        mergedSong.qqArtistMid = baseSong.qqArtistMid ?? qqSong?.qqArtistMid
        mergedSong.qqMaxQuality = baseSong.qqMaxQuality ?? qqSong?.qqMaxQuality
        mergedSong.localRelativePath = baseSong.localRelativePath
        mergedSong.localImportedAt = baseSong.localImportedAt
        return mergedSong
    }
    
    // MARK: - 删除云盘歌曲
    
    func deleteCloudSong(ids: [Int]) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.userCloudDel(ids: ids)
            let code = response.body["code"] as? Int ?? 200
            return SimpleResponse(code: code, message: nil)
        }
    }
}
