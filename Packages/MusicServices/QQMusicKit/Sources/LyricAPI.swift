import Foundation

// MARK: - 歌词相关 API

public extension QQMusicClient {

    /// 获取歌词
    ///
    /// ```swift
    /// let lyric = try await client.lyric(value: "001yS0N31jFfpK", trans: true)
    /// print(lyric.lyric ?? "无歌词")
    /// ```
    ///
    /// - Parameters:
    ///   - value: 歌曲 id 或 mid
    ///   - songType: 歌曲类型
    ///   - qrc: 是否返回逐字歌词（QRC 格式）
    ///   - trans: 是否返回翻译歌词
    ///   - roma: 是否返回罗马音歌词
    ///   - singingAnnotations: 是否返回助唱标注歌词
    func lyric(
        value: String,
        songType: Int = 1,
        qrc: Bool = false,
        trans: Bool = false,
        roma: Bool = false,
        singingAnnotations: Bool = false
    ) async throws -> LyricResult {
        try await requestWrapped("/lyric/get_lyric", params: [
            "value": value,
            "song_type": String(songType),
            "qrc": String(qrc),
            "trans": String(trans),
            "roma": String(roma),
            "singing_annotations": String(singingAnnotations),
        ])
    }

    func singingAnnotationsInfo(songId: Int) async throws -> JSON {
        try await module("lyric", function: "get_singing_annotations_info", parameters: ["songid": songId])
    }

    func multiStyleTranslatedLyric(songId: Int) async throws -> JSON {
        try await module("lyric", function: "get_multi_style_trans_lyric", parameters: ["songid": songId])
    }

    func hasAILyricDictionary(songId: Int) async throws -> JSON {
        try await module("lyric", function: "is_ai_dict_exists", parameters: ["songid": songId])
    }

    func aiLyricDictionary(songId: Int) async throws -> JSON {
        try await module("lyric", function: "get_ai_dict", parameters: ["songid": songId])
    }
}
