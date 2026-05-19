import Foundation

// MARK: - 歌手相关 API

public extension QQMusicClient {

    /// 获取歌手列表
    /// - Parameters:
    ///   - area: 地区筛选
    ///   - sex: 性别筛选
    ///   - genre: 风格筛选
    func singerList(
        area: AreaType = .all,
        sex: SexType = .all,
        genre: GenreType = .all
    ) async throws -> [JSON] {
        try await requestWrapped("/singer/get_singer_list", params: [
            "area": area.rawValue,
            "sex": sex.rawValue,
            "genre": genre.rawValue,
        ])
    }

    /// 获取歌手基本信息
    /// - Parameter mid: 歌手 mid
    func singerInfo(mid: String) async throws -> JSON {
        try await requestWrapped("/singer/get_info", params: ["mid": mid])
    }

    /// 获取歌手简介
    /// - Parameter mids: 歌手 mid 列表，逗号分隔
    func singerDesc(mids: String) async throws -> [JSON] {
        try await requestWrapped("/singer/get_desc", params: ["mids": mids])
    }

    /// 获取歌手歌曲列表
    /// - Parameters:
    ///   - mid: 歌手 mid
    ///   - number: 每次获取数量
    ///   - begin: 起始位置
    func singerSongsList(mid: String, number: Int = 10, begin: Int = 0) async throws -> JSON {
        try await requestWrapped("/singer/get_songs_list", params: [
            "mid": mid,
            "number": String(number),
            "begin": String(begin),
        ])
    }

    /// 获取歌手专辑列表
    /// - Parameters:
    ///   - mid: 歌手 mid
    ///   - number: 返回数量
    ///   - begin: 起始位置
    func singerAlbums(mid: String, number: Int = 10, begin: Int = 0) async throws -> JSON {
        try await requestWrapped("/singer/get_album_list", params: [
            "mid": mid,
            "number": String(number),
            "begin": String(begin),
        ])
    }

    /// 获取歌手 MV 列表
    /// - Parameters:
    ///   - mid: 歌手 mid
    ///   - number: 返回数量
    ///   - begin: 起始位置
    func singerMVs(mid: String, number: Int = 10, begin: Int = 0) async throws -> JSON {
        try await requestWrapped("/singer/get_mv_list", params: [
            "mid": mid,
            "number": String(number),
            "begin": String(begin),
        ])
    }

    /// 获取相似歌手
    /// - Parameters:
    ///   - mid: 歌手 mid
    ///   - number: 返回数量
    func similarSingers(mid: String, number: Int = 10) async throws -> [JSON] {
        try await requestWrapped("/singer/get_similar", params: [
            "mid": mid,
            "number": String(number),
        ])
    }

    /// 获取歌手列表（按索引筛选）
    /// - Parameters:
    ///   - area: 地区筛选
    ///   - sex: 性别筛选
    ///   - genre: 风格筛选
    ///   - index: 首字母索引（1-26 对应 A-Z，-100 全部，27 #号）
    ///   - sin: 跳过数量
    ///   - curPage: 当前页码
    func singerListIndex(
        area: AreaType = .all,
        sex: SexType = .all,
        genre: GenreType = .all,
        index: Int = -100,
        sin: Int = 0,
        curPage: Int = 1
    ) async throws -> JSON {
        try await requestWrapped("/singer/get_singer_list_index", params: [
            "area": area.rawValue,
            "sex": sex.rawValue,
            "genre": genre.rawValue,
            "index": String(index),
            "sin": String(sin),
            "cur_page": String(curPage),
        ])
    }

    /// 获取歌手 Tab 详情（Wiki/歌曲/专辑/视频等）
    /// - Parameters:
    ///   - mid: 歌手 mid
    ///   - tabType: Tab 类型
    ///   - page: 页码
    ///   - num: 返回数量
    func singerTabDetail(
        mid: String,
        tabType: SingerTabType,
        page: Int = 1,
        num: Int = 10
    ) async throws -> [JSON] {
        try await requestWrapped("/singer/get_tab_detail", params: [
            "mid": mid,
            "tab_type": tabType.rawValue,
            "page": String(page),
            "num": String(num),
        ])
    }
}
