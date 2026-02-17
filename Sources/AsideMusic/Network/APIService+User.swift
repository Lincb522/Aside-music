import Foundation
import Combine
import NeteaseCloudMusicAPI

// MARK: - 用户接口

extension APIService {

    struct UserDetailResponse: Codable {
        let profile: UserProfile
        let level: Int?
        let listenSongs: Int?
        let createTime: Int?
        let createDays: Int?
    }

    func fetchUserDetail(uid: Int) -> AnyPublisher<UserDetailResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.userDetail(uid: uid)
            guard let profileDict = response.body["profile"] as? [String: Any] else {
                throw NCMBridgeError.missingKey("profile")
            }
            let profileData = try JSONSerialization.data(withJSONObject: profileDict)
            let profile = try JSONDecoder().decode(UserProfile.self, from: profileData)
            return UserDetailResponse(
                profile: profile,
                level: response.body["level"] as? Int,
                listenSongs: response.body["listenSongs"] as? Int,
                createTime: response.body["createTime"] as? Int,
                createDays: response.body["createDays"] as? Int
            )
        }
    }

    struct UserUpdateResponse: Codable {
        let code: Int
    }

    func updateSignature(signature: String) -> AnyPublisher<UserUpdateResponse, Error> {
        ncm.publisher { [ncm] in
            var nickname = ""
            var gender = 0
            var birthday = 0
            var province = 0
            var city = 0
            
            let statusResp = try await ncm.loginStatus()
            let profileSource: [String: Any]?
            if let dataDict = statusResp.body["data"] as? [String: Any] {
                profileSource = dataDict["profile"] as? [String: Any]
            } else {
                profileSource = statusResp.body["profile"] as? [String: Any]
            }
            if let profile = profileSource {
                nickname = profile["nickname"] as? String ?? ""
                gender = profile["gender"] as? Int ?? 0
                birthday = profile["birthday"] as? Int ?? 0
                province = profile["province"] as? Int ?? 0
                city = profile["city"] as? Int ?? 0
            }
            
            let response = try await ncm.userUpdate(
                nickname: nickname,
                signature: signature,
                gender: gender,
                birthday: birthday,
                province: province,
                city: city
            )
            let code = response.body["code"] as? Int ?? 200
            return UserUpdateResponse(code: code)
        }
    }

    func fetchLyric(id: Int) -> AnyPublisher<LyricResponse, Error> {
        ncm.fetch(LyricResponse.self) { [ncm] in
            try await ncm.lyricNew(id: id)
        }
    }

    func likeSong(id: Int, like: Bool) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.like(id: id, like: like)
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: nil
            )
        }
    }

    struct LikedSongListResponse: Codable {
        let ids: [Int]
        let code: Int
    }

    func fetchLikedSongs(uid: Int) -> AnyPublisher<[Int], Error> {
        ncm.fetch([Int].self, keyPath: "ids") { [ncm] in
            try await ncm.likelist(uid: uid)
        }
    }

    // MARK: - 历史 & 风格

    struct HistoryDateResponse: Codable {
        let code: Int?
        let data: HistoryData?
        struct HistoryData: Codable {
            let dates: [String]?
        }
    }

    func fetchHistoryRecommendDates() -> AnyPublisher<[String], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.historyRecommendSongs()
            let dataDict = response.body["data"] as? [String: Any]
            let dates = dataDict?["dates"] as? [String] ?? []
            AppLogger.debug("History API 响应 - code: \(response.body["code"] ?? -1), dates: \(dates.count)")
            return dates
        }
    }

    struct HistorySongsResponse: Codable {
        let code: Int?
        let data: HistorySongsData?

        struct HistorySongsData: Codable {
            let songs: [Song]?
        }
    }

    func fetchHistoryRecommendSongs(date: String) -> AnyPublisher<[Song], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.historyRecommendSongsDetail(date: date)
            guard let dataDict = response.body["data"] as? [String: Any],
                  let songsArray = dataDict["songs"] as? [[String: Any]] else {
                AppLogger.debug("History Songs API 响应 - 无歌曲")
                return [Song]()
            }
            let songsData = try JSONSerialization.data(withJSONObject: songsArray)
            let songs = try JSONDecoder().decode([Song].self, from: songsData)
            AppLogger.debug("History Songs API 响应 - 歌曲数: \(songs.count)")
            return songs
        }
    }

    struct StyleListResponse: Codable {
        let code: Int
        let data: [StyleTag]?
    }

    struct StylePreferenceResponse: Codable {
        let code: Int
        let data: StylePreferenceData?

        struct StylePreferenceData: Codable {
             let tagPreference: [StyleTag]?
        }
    }

    struct StyleTag: Codable, Identifiable, Hashable {
        let tagId: Int?
        let tagName: String?
        let colorString: String?
        let rawId: Int?
        let rawName: String?

        enum CodingKeys: String, CodingKey {
            case tagId, tagName, colorString
            case rawId = "id"
            case rawName = "name"
        }

        var finalId: Int { tagId ?? rawId ?? 0 }
        var finalName: String { tagName ?? rawName ?? "Unknown" }

        var id: Int { finalId }

        init(id: String, name: String, type: Int = 0) {
            self.tagId = id.hashValue
            self.tagName = name
            self.rawId = id.hashValue
            self.rawName = name
            self.colorString = nil
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            tagId = try container.decodeIfPresent(Int.self, forKey: .tagId)
            tagName = try container.decodeIfPresent(String.self, forKey: .tagName)
            colorString = try container.decodeIfPresent(String.self, forKey: .colorString)
            rawId = try container.decodeIfPresent(Int.self, forKey: .rawId)
            rawName = try container.decodeIfPresent(String.self, forKey: .rawName)
        }
    }

    func fetchStyleList() -> AnyPublisher<[StyleTag], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.styleList()
            guard let dataArray = response.body["data"] as? [[String: Any]] else {
                return [StyleTag]()
            }
            let data = try JSONSerialization.data(withJSONObject: dataArray)
            return try JSONDecoder().decode([StyleTag].self, from: data)
        }
    }

    func fetchStylePreference() -> AnyPublisher<[StyleTag], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.stylePreference()
            guard let dataDict = response.body["data"] as? [String: Any],
                  let tagArray = dataDict["tagPreference"] as? [[String: Any]] else {
                return [StyleTag]()
            }
            let data = try JSONSerialization.data(withJSONObject: tagArray)
            return try JSONDecoder().decode([StyleTag].self, from: data)
        }
    }

    struct StyleSongResponse: Codable {
        let data: StyleSongData?
        struct StyleSongData: Codable {
            let songs: [Song]?
        }
    }

    func fetchStyleSongs(tagId: Int) -> AnyPublisher<[Song], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.styleSong(tagId: tagId)
            guard let dataDict = response.body["data"] as? [String: Any],
                  let songsArray = dataDict["songs"] as? [[String: Any]] else {
                return [Song]()
            }
            let songsData = try JSONSerialization.data(withJSONObject: songsArray)
            return try JSONDecoder().decode([Song].self, from: songsData)
        }
    }

    // MARK: - 搜索默认词

    func fetchSearchDefault() -> AnyPublisher<SearchDefaultResult, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.searchDefault()
            guard let dataDict = response.body["data"] as? [String: Any] else {
                return SearchDefaultResult(showKeyword: "", realkeyword: "")
            }
            let showKeyword = dataDict["showKeyword"] as? String ?? ""
            let realkeyword = dataDict["realkeyword"] as? String ?? ""
            return SearchDefaultResult(showKeyword: showKeyword, realkeyword: realkeyword)
        }
    }

    // MARK: - 搜索多类型匹配

    func fetchSearchMultimatch(keywords: String) -> AnyPublisher<SearchMultimatchResult, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.searchMultimatch(keywords: keywords)
            guard let result = response.body["result"] as? [String: Any] else {
                return SearchMultimatchResult(artist: nil, album: nil, playlist: nil)
            }
            var artist: ArtistInfo?
            var album: SearchAlbum?
            var playlist: Playlist?
            if let arr = result["artist"] as? [[String: Any]], let first = arr.first {
                let data = try JSONSerialization.data(withJSONObject: first)
                artist = try? JSONDecoder().decode(ArtistInfo.self, from: data)
            }
            if let arr = result["album"] as? [[String: Any]], let first = arr.first {
                let data = try JSONSerialization.data(withJSONObject: first)
                album = try? JSONDecoder().decode(SearchAlbum.self, from: data)
            }
            if let arr = result["playlist"] as? [[String: Any]], let first = arr.first {
                let data = try JSONSerialization.data(withJSONObject: first)
                playlist = try? JSONDecoder().decode(Playlist.self, from: data)
            }
            return SearchMultimatchResult(artist: artist, album: album, playlist: playlist)
        }
    }

    // MARK: - 专辑收藏

    func albumSub(id: Int, subscribe: Bool) -> AnyPublisher<Bool, Error> {
        ncm.publisher { [ncm] in
            let action: SubAction = subscribe ? .sub : .unsub
            let response = try await ncm.albumSub(id: id, action: action)
            return response.body["code"] as? Int == 200
        }
    }

    func fetchAlbumSublist(limit: Int = 25, offset: Int = 0) -> AnyPublisher<[AlbumInfo], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.albumSublist(limit: limit, offset: offset)
            guard let dataArray = response.body["data"] as? [[String: Any]] else {
                return [AlbumInfo]()
            }
            let data = try JSONSerialization.data(withJSONObject: dataArray)
            return try JSONDecoder().decode([AlbumInfo].self, from: data)
        }
    }

    // MARK: - 歌曲副歌时间

    func fetchSongChorus(id: Int) -> AnyPublisher<SongChorusResult, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.songChorus(id: id)
            guard let dataArray = response.body["data"] as? [[String: Any]],
                  let first = dataArray.first else {
                return SongChorusResult(startTime: nil, endTime: nil)
            }
            let startTime = first["startTime"] as? Double
            let endTime = first["endTime"] as? Double
            return SongChorusResult(
                startTime: startTime.map { $0 / 1000.0 },
                endTime: endTime.map { $0 / 1000.0 }
            )
        }
    }

    // MARK: - 歌曲动态封面

    func fetchSongDynamicCover(id: Int) -> AnyPublisher<String?, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.songDynamicCover(id: id)
            if let dataDict = response.body["data"] as? [String: Any],
               let url = dataDict["url"] as? String, !url.isEmpty {
                return url
            }
            return nil
        }
    }

    // MARK: - 音乐百科

    func fetchSongWiki(id: Int) -> AnyPublisher<[SongWikiBlock], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.songWikiSummary(id: id)
            guard let dataDict = response.body["data"] as? [String: Any],
                  let blocks = dataDict["blocks"] as? [[String: Any]] else {
                return [SongWikiBlock]()
            }
            var result: [SongWikiBlock] = []
            for block in blocks {
                let blockType = block["type"] as? String ?? ""
                if let creatives = block["creatives"] as? [[String: Any]] {
                    for creative in creatives {
                        let title = creative["title"] as? String ?? ""
                        let desc = creative["description"] as? String ?? ""
                        if !title.isEmpty || !desc.isEmpty {
                            result.append(SongWikiBlock(type: blockType, title: title, description: desc))
                        }
                    }
                }
            }
            return result
        }
    }

    // MARK: - 相关歌单

    func fetchRelatedPlaylists(id: Int) -> AnyPublisher<[RelatedPlaylist], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.relatedPlaylist(id: id)
            guard let arr = response.body["playlists"] as? [[String: Any]] else {
                return [RelatedPlaylist]()
            }
            var result: [RelatedPlaylist] = []
            for item in arr {
                let plId = (item["id"] as? String).flatMap { Int($0) } ?? item["id"] as? Int ?? 0
                let name = item["name"] as? String ?? ""
                let coverImgUrl = item["coverImgUrl"] as? String
                var creatorName = ""
                if let creator = item["creator"] as? [String: Any] {
                    creatorName = creator["nickname"] as? String ?? ""
                }
                result.append(RelatedPlaylist(id: plId, name: name, coverImgUrl: coverImgUrl, creatorName: creatorName))
            }
            return result
        }
    }

    // MARK: - 相似推荐

    /// 获取相似歌曲
    func fetchSimiSongs(id: Int) -> AnyPublisher<[Song], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.simiSong(id: id)
            guard let songsArray = response.body["songs"] as? [[String: Any]] else {
                return [Song]()
            }
            // simiSong 返回 artists/album 而非 ar/al，需要映射
            let mapped: [[String: Any]] = songsArray.map { item in
                var song = item
                // artists → ar
                if song["ar"] == nil, let artists = song["artists"] as? [[String: Any]] {
                    song["ar"] = artists
                }
                // album → al
                if song["al"] == nil, let album = song["album"] as? [String: Any] {
                    song["al"] = album
                }
                // duration → dt
                if song["dt"] == nil, let duration = song["duration"] as? Int {
                    song["dt"] = duration
                }
                return song
            }
            let data = try JSONSerialization.data(withJSONObject: mapped)
            return try JSONDecoder().decode([Song].self, from: data)
        }
    }

    /// 获取相似歌手
    func fetchSimiArtists(id: Int) -> AnyPublisher<[ArtistInfo], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.simiArtist(id: id)
            guard let artistsArray = response.body["artists"] as? [[String: Any]] else {
                return [ArtistInfo]()
            }
            let data = try JSONSerialization.data(withJSONObject: artistsArray)
            return try JSONDecoder().decode([ArtistInfo].self, from: data)
        }
    }

    /// 获取相似歌单
    func fetchSimiPlaylists(id: Int) -> AnyPublisher<[Playlist], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.simiPlaylist(id: id)
            guard let playlistsArray = response.body["playlists"] as? [[String: Any]] else {
                return [Playlist]()
            }
            let data = try JSONSerialization.data(withJSONObject: playlistsArray)
            return try JSONDecoder().decode([Playlist].self, from: data)
        }
    }

    // MARK: - 私人FM模式

    /// 切换私人FM模式
    func setPersonalFmMode(mode: String) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.personalFmMode(mode: mode)
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: nil
            )
        }
    }

    // MARK: - 歌单管理

    /// 创建歌单
    func createPlaylist(name: String, privacy: Int = 0) -> AnyPublisher<Playlist?, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.playlistCreate(name: name, privacy: privacy)
            guard let playlistDict = response.body["playlist"] as? [String: Any] else {
                return nil
            }
            let data = try JSONSerialization.data(withJSONObject: playlistDict)
            return try JSONDecoder().decode(Playlist.self, from: data)
        }
    }

    /// 添加/删除歌单歌曲
    func modifyPlaylistTracks(op: String, pid: Int, trackIds: [Int]) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.playlistTracks(op: op, pid: pid, trackIds: trackIds)
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: response.body["message"] as? String
            )
        }
    }

    // MARK: - 新歌速递

    /// 获取新歌速递
    func fetchTopSongs(type: Int = 0) -> AnyPublisher<[Song], Error> {
        ncm.publisher { [ncm] in
            let songType = TopSongType(rawValue: type) ?? .all
            let response = try await ncm.topSong(type: songType)
            guard let songsArray = response.body["data"] as? [[String: Any]] else {
                return [Song]()
            }
            // topSong 返回的字段是 album/artists/duration 而非 al/ar/dt
            // 需要手动映射为 Song 模型兼容的格式
            var songs: [Song] = []
            for item in songsArray {
                let id = item["id"] as? Int ?? 0
                let name = item["name"] as? String ?? ""
                let duration = item["duration"] as? Int
                let fee = item["fee"] as? Int
                let mvid = item["mvid"] as? Int ?? item["mv"] as? Int
                
                // 解析歌手：优先 artists，备用 ar
                var artists: [Artist] = []
                let arSource = item["artists"] as? [[String: Any]] ?? item["ar"] as? [[String: Any]] ?? []
                for ar in arSource {
                    let arId = ar["id"] as? Int ?? 0
                    let arName = ar["name"] as? String ?? ""
                    artists.append(Artist(id: arId, name: arName))
                }
                
                // 解析专辑：优先 album，备用 al
                var album: Album? = nil
                if let alDict = item["album"] as? [String: Any] ?? item["al"] as? [String: Any] {
                    let alId = alDict["id"] as? Int ?? 0
                    let alName = alDict["name"] as? String ?? ""
                    let picUrl = alDict["picUrl"] as? String ?? alDict["blurPicUrl"] as? String
                    album = Album(id: alId, name: alName, picUrl: picUrl)
                }
                
                // 解析音质
                func parseQuality(_ key: String) -> SongQuality? {
                    guard let q = item[key] as? [String: Any], let br = q["br"] as? Int else { return nil }
                    return SongQuality(br: br, fid: q["fid"] as? Int, size: q["size"] as? Int, vd: q["vd"] as? Double, sr: q["sr"] as? Int)
                }
                
                // 解析 privilege
                var privilege: Privilege? = nil
                if let privDict = item["privilege"] as? [String: Any] {
                    let privData = try JSONSerialization.data(withJSONObject: privDict)
                    privilege = try? JSONDecoder().decode(Privilege.self, from: privData)
                }
                
                songs.append(Song(
                    id: id, name: name, ar: artists, al: album,
                    dt: duration, fee: fee, mv: mvid,
                    h: parseQuality("h") ?? parseQuality("hMusic"),
                    m: parseQuality("m") ?? parseQuality("mMusic"),
                    l: parseQuality("l") ?? parseQuality("lMusic"),
                    sq: parseQuality("sq") ?? parseQuality("sqMusic"),
                    hr: parseQuality("hr") ?? parseQuality("hrMusic"),
                    alia: item["alias"] as? [String],
                    privilege: privilege
                ))
            }
            return songs
        }
    }

    // MARK: - 用户动态

    /// 获取用户动态
    func fetchUserEvents(uid: Int, lasttime: Int = -1, limit: Int = 30) -> AnyPublisher<UserEventResult, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.userEvent(uid: uid, lasttime: lasttime, limit: limit)
            let events = response.body["events"] as? [[String: Any]] ?? []
            let lasttime = response.body["lasttime"] as? Int ?? -1
            let more = response.body["more"] as? Bool ?? false
            var result: [UserEvent] = []
            for eventDict in events {
                let id = eventDict["id"] as? Int ?? 0
                let eventTime = eventDict["eventTime"] as? Int ?? 0
                let actName = eventDict["actName"] as? String ?? ""
                // 解析 json 字段（动态内容）
                var content = ""
                var songInfo: Song? = nil
                if let jsonStr = eventDict["json"] as? String,
                   let jsonData = jsonStr.data(using: .utf8),
                   let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    content = jsonDict["msg"] as? String ?? ""
                    if let songDict = jsonDict["song"] as? [String: Any] {
                        let songData = try JSONSerialization.data(withJSONObject: songDict)
                        songInfo = try? JSONDecoder().decode(Song.self, from: songData)
                    }
                }
                // 用户信息
                var userName = ""
                var userAvatar: String? = nil
                if let userDict = eventDict["user"] as? [String: Any] {
                    userName = userDict["nickname"] as? String ?? ""
                    userAvatar = userDict["avatarUrl"] as? String
                }
                result.append(UserEvent(
                    id: id, eventTime: eventTime, actName: actName,
                    content: content, song: songInfo,
                    userName: userName, userAvatarUrl: userAvatar
                ))
            }
            return UserEventResult(events: result, lasttime: lasttime, more: more)
        }
    }
}
