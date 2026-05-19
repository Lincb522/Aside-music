// MetadataReader.swift
// FFmpegSwiftSDK
//
// 读取音频文件的元数据（ID3 标签、Vorbis Comment 等）。
// 提取标题、艺术家、专辑、年份、专辑封面等信息。
// 支持本地文件和流媒体 URL。

import Foundation
import CFFmpeg

/// 音频文件元数据。
public struct AudioMetadata {
    /// 歌曲标题
    public let title: String?
    /// 艺术家
    public let artist: String?
    /// 专辑名
    public let album: String?
    /// 专辑艺术家
    public let albumArtist: String?
    /// 年份
    public let year: String?
    /// 曲目编号
    public let trackNumber: String?
    /// 流派
    public let genre: String?
    /// 作曲家
    public let composer: String?
    /// 专辑封面图片数据（JPEG/PNG）
    public let artworkData: Data?
    /// 专辑封面 MIME 类型（如 "image/jpeg"）
    public let artworkMimeType: String?
    /// 所有原始标签键值对
    public let rawTags: [String: String]
    /// 流媒体标题（ICY 元数据）
    public let streamTitle: String?
    /// 流媒体名称
    public let streamName: String?
    /// 流媒体 URL
    public let streamURL: String?
}

/// 音频元数据读取器。
///
/// 使用 FFmpeg 的 AVFormatContext 读取各种格式的元数据标签，
/// 支持 ID3v1/v2（MP3）、Vorbis Comment（FLAC/OGG）、
/// iTunes Metadata（M4A/AAC）、ICY 元数据（网络流）等。
///
/// ```swift
/// let reader = MetadataReader()
/// let metadata = try reader.read(url: "https://stream.example.com/radio.mp3")
/// print(metadata.title)       // 歌曲标题
/// print(metadata.streamTitle) // 流媒体当前播放的歌曲
/// ```
public final class MetadataReader {

    public init() {}

    /// 读取音频文件或流媒体的元数据。
    ///
    /// - Parameter url: 文件路径或流媒体 URL
    /// - Returns: AudioMetadata
    /// - Throws: FFmpegError
    public func read(url: String) throws -> AudioMetadata {
        // 检测是否为流媒体 URL
        let isStreamURL = url.lowercased().hasPrefix("http://") ||
                          url.lowercased().hasPrefix("https://") ||
                          url.lowercased().hasPrefix("rtmp://") ||
                          url.lowercased().hasPrefix("rtsp://") ||
                          url.lowercased().hasPrefix("mms://") ||
                          url.lowercased().hasPrefix("icy://")
        
        // 设置网络选项
        var options: OpaquePointer?
        if isStreamURL {
            av_dict_set(&options, "timeout", "5000000", 0)  // 5 秒超时
            av_dict_set(&options, "icy", "1", 0)  // 启用 ICY 元数据
            av_dict_set(&options, "reconnect", "1", 0)
        }
        defer { av_dict_free(&options) }
        
        var fmtCtx: UnsafeMutablePointer<AVFormatContext>?
        let ret = avformat_open_input(&fmtCtx, url, nil, &options)
        guard ret >= 0, let ctx = fmtCtx else {
            throw FFmpegError.connectionFailed(code: ret, message: "无法打开: \(url)")
        }
        defer { avformat_close_input(&fmtCtx) }

        avformat_find_stream_info(ctx, nil)

        // 读取容器级别的标签
        var rawTags = [String: String]()
        if let metadata = ctx.pointee.metadata {
            rawTags = extractTags(from: metadata)
        }

        // 也检查各个流的标签（有些格式把标签放在流上）
        for i in 0..<Int(ctx.pointee.nb_streams) {
            if let stream = ctx.pointee.streams[i], let metadata = stream.pointee.metadata {
                let streamTags = extractTags(from: metadata)
                for (key, value) in streamTags where rawTags[key] == nil {
                    rawTags[key] = value
                }
            }
        }

        // 提取专辑封面
        var artworkData: Data?
        var artworkMimeType: String?
        for i in 0..<Int(ctx.pointee.nb_streams) {
            guard let stream = ctx.pointee.streams[i] else { continue }
            let codecpar = stream.pointee.codecpar
            // 封面通常是 MJPEG 或 PNG 编码的视频流，disposition 标记为 attached_pic
            if stream.pointee.disposition & AV_DISPOSITION_ATTACHED_PIC != 0 {
                let pkt = stream.pointee.attached_pic
                if pkt.size > 0, let data = pkt.data {
                    artworkData = Data(bytes: data, count: Int(pkt.size))
                    // 判断 MIME 类型
                    if let cp = codecpar {
                        let codecID = cp.pointee.codec_id
                        if codecID == AV_CODEC_ID_MJPEG || codecID == AV_CODEC_ID_JPEG2000 {
                            artworkMimeType = "image/jpeg"
                        } else if codecID == AV_CODEC_ID_PNG {
                            artworkMimeType = "image/png"
                        } else if codecID == AV_CODEC_ID_BMP {
                            artworkMimeType = "image/bmp"
                        } else {
                            artworkMimeType = "image/jpeg" // 默认
                        }
                    }
                }
                break
            }
        }
        
        // 提取流媒体特有的元数据
        let streamTitle = rawTags["icy-title"] ?? rawTags["StreamTitle"]
        let streamName = rawTags["icy-name"] ?? rawTags["icy_name"]
        let streamURL = rawTags["icy-url"] ?? rawTags["icy_url"]

        return AudioMetadata(
            title: rawTags["title"] ?? rawTags["TITLE"] ?? streamTitle,
            artist: rawTags["artist"] ?? rawTags["ARTIST"],
            album: rawTags["album"] ?? rawTags["ALBUM"],
            albumArtist: rawTags["album_artist"] ?? rawTags["ALBUMARTIST"],
            year: rawTags["date"] ?? rawTags["DATE"] ?? rawTags["year"] ?? rawTags["YEAR"],
            trackNumber: rawTags["track"] ?? rawTags["TRACKNUMBER"],
            genre: rawTags["genre"] ?? rawTags["GENRE"],
            composer: rawTags["composer"] ?? rawTags["COMPOSER"],
            artworkData: artworkData,
            artworkMimeType: artworkMimeType,
            rawTags: rawTags,
            streamTitle: streamTitle,
            streamName: streamName,
            streamURL: streamURL
        )
    }
    
    /// 异步读取元数据（适用于流媒体）
    public func readAsync(url: String) async throws -> AudioMetadata {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.read(url: url)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 从 AVDictionary 提取所有键值对。
    /// AVDictionary 在 Swift 中是不透明类型，需要用 OpaquePointer 传递。
    private func extractTags(from dict: OpaquePointer) -> [String: String] {
        var tags = [String: String]()
        var entry: UnsafeMutablePointer<AVDictionaryEntry>?
        while true {
            entry = av_dict_get(dict, "", entry, AV_DICT_IGNORE_SUFFIX)
            guard let e = entry else { break }
            let key = String(cString: e.pointee.key)
            let value = String(cString: e.pointee.value)
            tags[key] = value
        }
        return tags
    }
}
