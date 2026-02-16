import Foundation
import Combine
import NeteaseCloudMusicAPI

// MARK: - 播客/电台接口

extension APIService {

    func fetchDJPersonalizeRecommend(limit: Int = 6) -> AnyPublisher<[RadioStation], Error> {
        ncm.fetch([RadioStation].self, keyPath: "data") { [ncm] in
            try await ncm.djPersonalizeRecommend(limit: limit)
        }
    }

    func fetchDJCategories() -> AnyPublisher<[RadioCategory], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.djCatelist()
            guard let catsArray = response.body["categories"] as? [[String: Any]] else {
                return [RadioCategory]()
            }
            let data = try JSONSerialization.data(withJSONObject: catsArray)
            let cats = try JSONDecoder().decode([RadioCategory].self, from: data)
            AppLogger.debug("电台分类数量: \(cats.count)")
            return cats
        }
    }

    func fetchDJRecommend() -> AnyPublisher<[RadioStation], Error> {
        ncm.fetch([RadioStation].self, keyPath: "djRadios") { [ncm] in
            try await ncm.djRecommend()
        }
    }

    func fetchDJDetail(id: Int) -> AnyPublisher<RadioStation, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.djDetail(rid: id)
            guard let dataDict = response.body["data"] as? [String: Any] ??
                  response.body["djRadio"] as? [String: Any] else {
                throw URLError(.badServerResponse)
            }
            let data = try JSONSerialization.data(withJSONObject: dataDict)
            return try JSONDecoder().decode(RadioStation.self, from: data)
        }
    }

    func fetchDJPrograms(radioId: Int, limit: Int = 30, offset: Int = 0) -> AnyPublisher<[RadioProgram], Error> {
        ncm.fetch([RadioProgram].self, keyPath: "programs") { [ncm] in
            try await ncm.djProgram(rid: radioId, limit: limit, offset: offset)
        }
    }

    func fetchDJCategoryHot(cateId: Int, limit: Int = 30, offset: Int = 0) -> AnyPublisher<(radios: [RadioStation], hasMore: Bool), Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.djRadioHot(cateId: cateId, limit: limit, offset: offset)
            let radiosArray = response.body["djRadios"] as? [[String: Any]] ?? []
            let hasMore = response.body["hasMore"] as? Bool ?? (radiosArray.count >= limit)
            let data = try JSONSerialization.data(withJSONObject: radiosArray)
            let radios = try JSONDecoder().decode([RadioStation].self, from: data)
            AppLogger.debug("分类热门电台: cateId=\(cateId), offset=\(offset), 返回\(radios.count)条, hasMore=\(hasMore)")
            return (radios: radios, hasMore: hasMore)
        }
    }

    /// 热门电台榜（支持分页）
    func fetchDJToplist(type: String = "hot", limit: Int = 30, offset: Int = 0) -> AnyPublisher<[RadioStation], Error> {
        ncm.fetch([RadioStation].self, keyPath: "toplist") { [ncm] in
            try await ncm.djToplist(limit: limit, offset: offset)
        }
    }

    /// 热门电台（支持分页）
    func fetchDJHot(limit: Int = 30, offset: Int = 0) -> AnyPublisher<[RadioStation], Error> {
        ncm.fetch([RadioStation].self, keyPath: "djRadios") { [ncm] in
            try await ncm.djHot(limit: limit, offset: offset)
        }
    }

    /// 搜索电台（cloudsearch type=1009）
    func searchDJRadio(keywords: String, limit: Int = 30, offset: Int = 0) -> AnyPublisher<[RadioStation], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.cloudsearch(
                keywords: keywords,
                type: .dj,
                limit: limit,
                offset: offset
            )
            guard let result = response.body["result"] as? [String: Any],
                  let radiosArray = result["djRadios"] as? [[String: Any]] else {
                return [RadioStation]()
            }
            let data = try JSONSerialization.data(withJSONObject: radiosArray)
            return try JSONDecoder().decode([RadioStation].self, from: data)
        }
    }

    // MARK: - 广播电台接口（地区 FM 广播）

    /// 获取广播电台频道列表
    func fetchBroadcastChannels(categoryId: String = "0", regionId: String = "0", limit: Int = 20, offset: Int = 0) -> AnyPublisher<[BroadcastChannel], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.broadcastChannelList(
                categoryId: categoryId, regionId: regionId,
                limit: limit, offset: offset
            )
            AppLogger.debug("广播频道列表响应 keys: \(response.body.keys)")
            
            // 尝试多种数据路径
            let listArray: [[String: Any]]
            if let dataDict = response.body["data"] as? [String: Any],
               let list = dataDict["list"] as? [[String: Any]] {
                listArray = list
            } else if let list = response.body["list"] as? [[String: Any]] {
                listArray = list
            } else if let dataArray = response.body["data"] as? [[String: Any]] {
                listArray = dataArray
            } else {
                AppLogger.debug("广播频道列表: 无法解析数据, body: \(response.body)")
                return [BroadcastChannel]()
            }
            
            AppLogger.debug("广播频道列表: 获取到 \(listArray.count) 个频道")
            if let first = listArray.first {
                AppLogger.debug("广播频道示例 keys: \(first.keys)")
            }
            
            let data = try JSONSerialization.data(withJSONObject: listArray)
            return try JSONDecoder().decode([BroadcastChannel].self, from: data)
        }
    }

    /// 获取广播电台地区和分类信息
    func fetchBroadcastCategoryRegion() -> AnyPublisher<(categories: [BroadcastCategory], regions: [BroadcastRegion]), Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.broadcastCategoryRegionGet()
            let dataDict = response.body["data"] as? [String: Any] ?? response.body

            var categories: [BroadcastCategory] = []
            var regions: [BroadcastRegion] = []

            if let catsArray = dataDict["categoryList"] as? [[String: Any]] ?? dataDict["categories"] as? [[String: Any]] {
                let data = try JSONSerialization.data(withJSONObject: catsArray)
                categories = try JSONDecoder().decode([BroadcastCategory].self, from: data)
            }
            if let regionsArray = dataDict["regionList"] as? [[String: Any]] ?? dataDict["regions"] as? [[String: Any]] {
                let data = try JSONSerialization.data(withJSONObject: regionsArray)
                regions = try JSONDecoder().decode([BroadcastRegion].self, from: data)
            }
            return (categories: categories, regions: regions)
        }
    }

    /// 获取广播频道当前播放信息（含流地址）
    func fetchBroadcastChannelInfo(id: String) -> AnyPublisher<[String: Any], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.broadcastChannelCurrentinfo(id: id)
            AppLogger.debug("广播频道信息响应 keys: \(response.body.keys)")
            AppLogger.debug("广播频道信息响应 body: \(response.body)")
            return response.body["data"] as? [String: Any] ?? response.body
        }
    }

    // MARK: - 收藏/订阅接口

    /// 获取用户订阅的播客列表
    func fetchDJSublist(limit: Int = 30, offset: Int = 0) -> AnyPublisher<[RadioStation], Error> {
        ncm.fetch([RadioStation].self, keyPath: "djRadios") { [ncm] in
            try await ncm.djSublist(limit: limit, offset: offset)
        }
    }

    /// 订阅/取消订阅播客
    func subscribeDJ(rid: Int, subscribe: Bool) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.djSub(
                rid: rid,
                action: subscribe ? .sub : .unsub
            )
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: nil
            )
        }
    }

    /// 收藏/取消收藏歌单
    /// 直接调用后端 /playlist/subscribe，传 t=1（收藏）或 t=2（取消收藏）
    /// 绕过 SDK 的 playlistSubscribe（SDK 未传 t 参数导致后端始终走 unsubscribe）
    func subscribePlaylist(id: Int, subscribe: Bool) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            guard let serverUrl = ncm.serverUrl else {
                // 无后端地址时回退到 SDK 方法
                let response = try await ncm.playlistSubscribe(
                    id: id,
                    action: subscribe ? .sub : .unsub
                )
                return SimpleResponse(
                    code: response.body["code"] as? Int ?? 200,
                    message: nil
                )
            }
            let params: [String: Any] = [
                "id": id,
                "t": subscribe ? 1 : 2,
            ]
            let body = try await Self.postToBackend(
                serverUrl: serverUrl,
                route: "/playlist/subscribe",
                params: params
            )
            return SimpleResponse(
                code: body["code"] as? Int ?? 200,
                message: body["message"] as? String
            )
        }
    }

    /// 删除用户创建的歌单
    func deletePlaylist(id: Int) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.playlistDelete(ids: [id])
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: nil
            )
        }
    }
}
