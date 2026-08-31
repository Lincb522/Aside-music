import Foundation

// MARK: - 歌手相关 API

public extension QQMusicClient {

    /// 获取歌手列表
    ///
    /// 新版 API 返回 `{ singerlist: [...], hotlist: [...], tags: {...} }` 字典。
    /// - Parameters:
    ///   - area: 地区筛选
    ///   - sex: 性别筛选
    ///   - genre: 风格筛选
    func singerList(
        area: AreaType = .all,
        sex: SexType = .all,
        genre: GenreType = .all
    ) async throws -> JSON {
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
    ///
    /// 新版 API 返回 `{ singer_list: [...] }` 字典。
    /// - Parameters:
    ///   - mids: 歌手 mid 列表，逗号分隔
    ///   - extendedSinger: 是否返回扩展简介
    ///   - wikiSinger: 是否返回百科内容
    ///   - groupSinger: 是否返回组合成员
    ///   - picture: 是否返回头像与立绘
    ///   - photos: 是否返回相册大图
    func singerDesc(
        mids: String,
        extendedSinger: Bool = true,
        wikiSinger: Bool = true,
        groupSinger: Bool = true,
        picture: Bool = true,
        photos: Bool = true
    ) async throws -> JSON {
        try await requestWrapped("/singer/get_desc", params: [
            "mids": mids,
            "ex_singer": String(extendedSinger),
            "wiki_singer": String(wikiSinger),
            "group_singer": String(groupSinger),
            "pic": String(picture),
            "photos": String(photos),
        ])
    }

    /// 获取歌手歌曲列表
    /// - Parameters:
    ///   - mid: 歌手 mid
    ///   - num: 每页数量
    ///   - page: 页码（从 1 开始）
    func singerSongsList(mid: String, num: Int = 10, page: Int = 1) async throws -> JSON {
        try await requestWrapped("/singer/get_songs_list", params: [
            "mid": mid,
            "num": String(num),
            "page": String(page),
        ])
    }

    /// 获取歌手专辑列表
    /// - Parameters:
    ///   - mid: 歌手 mid
    ///   - num: 每页数量
    ///   - page: 页码（从 1 开始）
    func singerAlbums(mid: String, num: Int = 10, page: Int = 1) async throws -> JSON {
        try await requestWrapped("/singer/get_album_list", params: [
            "mid": mid,
            "num": String(num),
            "page": String(page),
        ])
    }

    /// 获取歌手 MV 列表
    /// - Parameters:
    ///   - mid: 歌手 mid
    ///   - num: 每页数量
    ///   - page: 页码（从 1 开始）
    func singerMVs(mid: String, num: Int = 10, page: Int = 1) async throws -> JSON {
        try await requestWrapped("/singer/get_mv_list", params: [
            "mid": mid,
            "num": String(num),
            "page": String(page),
        ])
    }

    /// 获取相似歌手
    ///
    /// 新版 API 返回 `{ singerlist: [...] }` 字典。
    /// - Parameters:
    ///   - mid: 歌手 mid
    ///   - number: 返回数量
    func similarSingers(mid: String, number: Int = 10) async throws -> JSON {
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
    ///   - page: 页码（从 1 开始）
    ///   - num: 每页数量
    func singerListIndex(
        area: AreaType = .all,
        sex: SexType = .all,
        genre: GenreType = .all,
        index: Int = -100,
        page: Int = 1,
        num: Int = 80
    ) async throws -> JSON {
        try await requestWrapped("/singer/get_singer_list_index", params: [
            "area": area.rawValue,
            "sex": sex.rawValue,
            "genre": genre.rawValue,
            "index": String(index),
            "page": String(page),
            "num": String(num),
        ])
    }

    /// 获取歌手 Tab 详情（Wiki/歌曲/专辑/视频等）
    ///
    /// 新版 API 返回 `{ introduction_tab: [...], song_tab: [...], ... }` 字典。
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
    ) async throws -> JSON {
        try await requestWrapped("/singer/get_tab_detail", params: [
            "mid": mid,
            "tab_type": tabType.rawValue,
            "page": String(page),
            "num": String(num),
        ])
    }
}
