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
    ///   - qrc: 是否返回逐字歌词（QRC 格式）
    ///   - trans: 是否返回翻译歌词
    ///   - roma: 是否返回罗马音歌词
    func lyric(
        value: String,
        qrc: Bool = false,
        trans: Bool = false,
        roma: Bool = false
    ) async throws -> LyricResult {
        try await requestWrapped("/lyric/get_lyric", params: [
            "value": value,
            "qrc": String(qrc),
            "trans": String(trans),
            "roma": String(roma),
        ])
    }
}
