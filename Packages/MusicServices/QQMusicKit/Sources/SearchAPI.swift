import Foundation

// MARK: - 搜索相关 API

public extension QQMusicClient {

    /// 获取热搜词
    func hotkey() async throws -> JSON {
        try await requestWrapped("/search/get_hotkey")
    }

    /// 搜索补全
    /// - Parameter keyword: 关键词
    func searchComplete(keyword: String) async throws -> JSON {
        try await requestWrapped("/search/complete", params: ["keyword": keyword])
    }

    /// 快速搜索
    /// - Parameter keyword: 关键词
    func quickSearch(keyword: String) async throws -> JSON {
        try await requestWrapped("/search/quick_search", params: ["keyword": keyword])
    }

    /// 综合搜索
    /// - Parameters:
    ///   - keyword: 关键词
    ///   - page: 页码，默认 1
    ///   - num: 返回数量，默认 15
    ///   - searchID: 延续搜索会话时使用的 ID
    ///   - pageStart: 指定结果起始位置
    ///   - highlight: 是否高亮关键词
    func generalSearch(
        keyword: String,
        page: Int = 1,
        num: Int = 15,
        searchID: String? = nil,
        pageStart: Int? = nil,
        highlight: Bool = true
    ) async throws -> JSON {
        var params = [
            "keyword": keyword,
            "page": String(page),
            "num": String(num),
            "highlight": String(highlight),
        ]
        if let searchID { params["searchid"] = searchID }
        if let pageStart { params["page_start"] = String(pageStart) }
        return try await requestWrapped("/search/general_search", params: params)
    }

    /// 分类搜索
    ///
    /// ```swift
    /// let songs = try await client.search(keyword: "周杰伦", type: .song, num: 20)
    /// ```
    ///
    /// - Parameters:
    ///   - keyword: 关键词
    ///   - type: 搜索类型
    ///   - num: 返回数量，默认 10
    ///   - page: 页码，默认 1
    ///   - selectors: 搜索筛选器
    ///   - searchID: 延续搜索会话时使用的 ID
    ///   - highlight: 是否高亮关键词
    func search(
        keyword: String,
        type: SearchType = .song,
        num: Int = 10,
        page: Int = 1,
        selectors: [QQMusicSearchSelector]? = nil,
        searchID: String? = nil,
        highlight: Bool = true
    ) async throws -> JSON {
        var parameters: [String: Any] = [
            "keyword": keyword,
            "search_type": type.rawValue,
            "num": num,
            "page": page,
            "highlight": highlight,
        ]
        if let selectors {
            parameters["selectors"] = selectors.map(\.parameters)
        }
        if let searchID {
            parameters["searchid"] = searchID
        }
        return try await requestWrapped("/search/search_by_type", parameters: parameters)
    }
}
