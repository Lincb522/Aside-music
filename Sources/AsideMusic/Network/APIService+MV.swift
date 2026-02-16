// APIService+MV.swift
// MV 相关 API 接口

import Foundation
import Combine
import NeteaseCloudMusicAPI

extension APIService {

    // MARK: - MV 详情

    /// 获取 MV 详情
    func fetchMVDetail(id: Int) -> AnyPublisher<MVDetail, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.mvDetail(mvid: id)
            guard let dataDict = response.body["data"] as? [String: Any] else {
                throw NCMBridgeError.missingKey("data")
            }
            let data = try JSONSerialization.data(withJSONObject: dataDict)
            return try JSONDecoder().decode(MVDetail.self, from: data)
        }
    }

    // MARK: - MV 播放链接

    /// 获取 MV 播放 URL
    func fetchMVUrl(id: Int, resolution: Int = 1080) -> AnyPublisher<String, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.mvUrl(id: id, r: resolution)
            guard let dataDict = response.body["data"] as? [String: Any],
                  let url = dataDict["url"] as? String, !url.isEmpty else {
                AppLogger.warning("[MV] URL 为空: id=\(id), r=\(resolution), data=\(response.body["data"] ?? "nil")")
                throw PlaybackError.unavailable
            }
            // 确保使用 HTTPS
            let secureUrl = url.hasPrefix("http://") ? url.replacingOccurrences(of: "http://", with: "https://") : url
            return secureUrl
        }
    }

    // MARK: - MV 列表

    /// 获取全部 MV（支持筛选和分页）
    func fetchAllMVs(area: String = "全部", type: String = "全部", order: String = "上升最快", limit: Int = 12, offset: Int = 0) -> AnyPublisher<[MV], Error> {
        ncm.publisher { [ncm] in
            let areaEnum = MvArea(rawValue: area) ?? .all
            let typeEnum = MvType(rawValue: type) ?? .all
            let orderEnum = MvOrder(rawValue: order) ?? .hot
            let response = try await ncm.mvAll(
                area: areaEnum, type: typeEnum, order: orderEnum,
                limit: limit, offset: offset
            )
            guard let dataArray = response.body["data"] as? [[String: Any]] else {
                return [MV]()
            }
            let data = try JSONSerialization.data(withJSONObject: dataArray)
            return try JSONDecoder().decode([MV].self, from: data)
        }
    }

    /// 获取最新 MV
    func fetchLatestMVs(area: String = "全部", limit: Int = 12) -> AnyPublisher<[MV], Error> {
        ncm.publisher { [ncm] in
            let areaEnum = MvArea(rawValue: area) ?? .all
            let response = try await ncm.mvFirst(area: areaEnum, limit: limit)
            guard let dataArray = response.body["data"] as? [[String: Any]] else {
                return [MV]()
            }
            let data = try JSONSerialization.data(withJSONObject: dataArray)
            return try JSONDecoder().decode([MV].self, from: data)
        }
    }

    /// 获取网易出品 MV
    func fetchExclusiveMVs(limit: Int = 12, offset: Int = 0) -> AnyPublisher<[MV], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.mvExclusiveRcmd(limit: limit, offset: offset)
            guard let dataArray = response.body["data"] as? [[String: Any]] else {
                return [MV]()
            }
            let data = try JSONSerialization.data(withJSONObject: dataArray)
            return try JSONDecoder().decode([MV].self, from: data)
        }
    }

    /// 获取 MV 排行榜
    func fetchTopMVs(area: String = "", limit: Int = 20, offset: Int = 0) -> AnyPublisher<[MV], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.topMv(limit: limit, offset: offset, area: area)
            guard let dataArray = response.body["data"] as? [[String: Any]] else {
                return [MV]()
            }
            let data = try JSONSerialization.data(withJSONObject: dataArray)
            return try JSONDecoder().decode([MV].self, from: data)
        }
    }

    /// 获取歌手 MV
    func fetchArtistMVs(id: Int, limit: Int = 20, offset: Int = 0) -> AnyPublisher<[MV], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.artistMv(id: id, limit: limit, offset: offset)
            guard let mvsArray = response.body["mvs"] as? [[String: Any]] else {
                return [MV]()
            }
            let data = try JSONSerialization.data(withJSONObject: mvsArray)
            return try JSONDecoder().decode([MV].self, from: data)
        }
    }

    /// 获取相似 MV
    func fetchSimiMVs(id: Int) -> AnyPublisher<[MV], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.simiMv(mvid: id)
            guard let mvsArray = response.body["mvs"] as? [[String: Any]] else {
                return [MV]()
            }
            let data = try JSONSerialization.data(withJSONObject: mvsArray)
            return try JSONDecoder().decode([MV].self, from: data)
        }
    }

    /// 收藏/取消收藏 MV（直接调后端路由，绕过 NCM 库参数格式问题）
    func subscribeMV(id: Int, subscribe: Bool) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            guard let serverUrl = ncm.serverUrl else {
                // 直连模式回退到库方法
                let response = try await ncm.mvSub(mvid: id, action: subscribe ? .sub : .unsub)
                return SimpleResponse(
                    code: response.body["code"] as? Int ?? 200,
                    message: nil
                )
            }
            // 后端路由 /mv/sub 需要 t=1(收藏)/t=0(取消)，mvid 为 MV ID
            let params: [String: Any] = [
                "mvid": id,
                "t": subscribe ? 1 : 0
            ]
            let body = try await Self.postToBackend(serverUrl: serverUrl, route: "/mv/sub", params: params)
            let code = body["code"] as? Int ?? 200
            let msg = body["message"] as? String
            return SimpleResponse(code: code, message: msg)
        }
    }

    // MARK: - MV 互动数据

    /// 获取 MV 点赞/评论数等详细互动信息
    func fetchMVDetailInfo(id: Int) -> AnyPublisher<MVDetailInfo, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.mvDetailInfo(mvid: id)
            let data = try JSONSerialization.data(withJSONObject: response.body)
            return try JSONDecoder().decode(MVDetailInfo.self, from: data)
        }
    }

    // MARK: - 已收藏 MV 列表

    /// 获取用户已收藏的 MV 列表
    func fetchMVSublist(limit: Int = 25, offset: Int = 0) -> AnyPublisher<[MVSubItem], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.mvSublist(limit: limit, offset: offset)
            guard let dataArray = response.body["data"] as? [[String: Any]] else {
                return [MVSubItem]()
            }
            let data = try JSONSerialization.data(withJSONObject: dataArray)
            return try JSONDecoder().decode([MVSubItem].self, from: data)
        }
    }

    // MARK: - 相关视频

    /// 获取相关视频推荐（MV 或视频均可）
    func fetchRelatedVideos(id: String) -> AnyPublisher<[MV], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.relatedAllvideo(id: id)
            guard let dataArray = response.body["data"] as? [[String: Any]] else {
                return [MV]()
            }
            // 相关视频返回格式可能不同，尝试提取 MV 信息
            var mvs = [MV]()
            for item in dataArray {
                // 优先取 resources 里的 mlogBaseData 或直接的 MV 数据
                if let resources = item["resources"] as? [[String: Any]] {
                    for res in resources {
                        if let mlogBaseData = res["mlogBaseData"] as? [String: Any],
                           let mvId = mlogBaseData["id"] as? Int ?? (res["resourceId"] as? String).flatMap({ Int($0) }) {
                            // 构造简化 MV 数据
                            var mvDict: [String: Any] = ["id": mvId]
                            if let text = mlogBaseData["text"] as? String { mvDict["name"] = text }
                            if let coverUrl = mlogBaseData["coverUrl"] as? String { mvDict["cover"] = coverUrl }
                            if let duration = mlogBaseData["duration"] as? Int { mvDict["duration"] = duration }
                            if let d = try? JSONSerialization.data(withJSONObject: mvDict),
                               let mv = try? JSONDecoder().decode(MV.self, from: d) {
                                mvs.append(mv)
                            }
                        }
                    }
                }
            }
            return mvs
        }
    }
}
