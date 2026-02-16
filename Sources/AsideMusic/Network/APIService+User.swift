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
            try await ncm.lyric(id: id)
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
}
