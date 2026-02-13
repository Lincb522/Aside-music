// APIService+Cloud.swift
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
    
    // MARK: - 删除云盘歌曲
    
    func deleteCloudSong(ids: [Int]) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.userCloudDel(ids: ids)
            let code = response.body["code"] as? Int ?? 200
            return SimpleResponse(code: code, message: nil)
        }
    }
}
