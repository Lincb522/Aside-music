// Enums.swift
// 枚举和参数类型定义
// 定义搜索类型、评论类型、订阅操作等枚举
// 所有枚举的 rawValue 与 TypeScript interface.d.ts 中的定义完全匹配

import Foundation

// MARK: - 搜索类型

/// 搜索资源类型枚举
/// 对应 TypeScript 中的 SearchType
public enum SearchType: Int, Codable, CaseIterable, Sendable {
    /// 单曲
    case single = 1
    /// 专辑
    case album = 10
    /// 歌手
    case artist = 100
    /// 歌单
    case playlist = 1000
    /// 用户
    case user = 1002
    /// MV
    case mv = 1004
    /// 歌词
    case lyric = 1006
    /// 电台
    case dj = 1009
    /// 视频
    case video = 1014
    /// 综合搜索
    case complex = 1018
}

// MARK: - 评论类型

/// 评论资源类型枚举
/// 对应 TypeScript 中的 CommentType
public enum CommentType: Int, Codable, CaseIterable, Sendable {
    /// 歌曲评论
    case song = 0
    /// MV 评论
    case mv = 1
    /// 歌单评论
    case playlist = 2
    /// 专辑评论
    case album = 3
    /// 电台评论
    case dj = 4
    /// 视频评论
    case video = 5
    /// 动态评论
    case event = 6
}

// MARK: - 订阅操作

/// 订阅/取消订阅操作枚举
/// 对应 TypeScript 中的 SubAction
public enum SubAction: Int, Codable, CaseIterable, Sendable {
    /// 取消订阅
    case unsub = 0
    /// 订阅
    case sub = 1
}

// MARK: - 评论操作

/// 评论操作类型枚举
/// 对应 TypeScript 中的 CommentAction
public enum CommentAction: Int, Codable, CaseIterable, Sendable {
    /// 删除评论
    case delete = 0
    /// 发表评论
    case add = 1
    /// 回复评论
    case reply = 2
}

// MARK: - Banner 类型

/// Banner 客户端类型枚举
/// 对应 TypeScript 中的 BannerType
public enum BannerType: Int, Codable, CaseIterable, Sendable {
    /// PC 端
    case pc = 0
    /// Android 端
    case android = 1
    /// iPhone 端
    case iphone = 2
    /// iPad 端
    case ipad = 3
}

// MARK: - 歌手区域

/// 歌手区域枚举
/// 对应 TypeScript 中的 ArtistArea
/// 注意：rawValue 为字符串类型，匹配 API 参数值
public enum ArtistArea: String, Codable, CaseIterable, Sendable {
    /// 全部
    case all = "-1"
    /// 华语
    case zh = "7"
    /// 欧美
    case ea = "96"
    /// 日本
    case ja = "8"
    /// 韩国
    case kr = "16"
    /// 其他
    case other = "0"
}

// MARK: - 歌手类型

/// 歌手类型枚举
/// 对应 TypeScript 中的 ArtistType
/// 注意：rawValue 为字符串类型，匹配 API 参数值
public enum ArtistType: String, Codable, CaseIterable, Sendable {
    /// 男歌手
    case male = "1"
    /// 女歌手
    case female = "2"
    /// 乐队/组合
    case band = "3"
}

// MARK: - 专辑列表区域

/// 专辑列表区域枚举
/// 对应 TypeScript 中的 AlbumListArea
public enum AlbumListArea: String, Codable, CaseIterable, Sendable {
    /// 全部
    case all = "ALL"
    /// 华语
    case zh = "ZH"
    /// 欧美
    case ea = "EA"
    /// 韩国
    case kr = "KR"
    /// 日本
    case jp = "JP"
}

// MARK: - 列表排序

/// 列表排序方式枚举
/// 对应 TypeScript 中的 ListOrder
public enum ListOrder: String, Codable, CaseIterable, Sendable {
    /// 热门
    case hot = "hot"
    /// 最新
    case new = "new"
}

// MARK: - 专辑风格列表区域

/// 专辑风格列表区域枚举
/// 对应 TypeScript 中的 AlbumListStyleArea
public enum AlbumListStyleArea: String, Codable, CaseIterable, Sendable {
    /// 华语
    case zh = "Z_H"
    /// 欧美
    case ea = "E_A"
    /// 韩国
    case kr = "KR"
    /// 日本
    case jp = "JP"
}

// MARK: - 专辑销量榜类型

/// 专辑销量榜时间类型枚举
/// 对应 TypeScript 中的 AlbumSongsaleboardType
public enum AlbumSongsaleboardType: String, Codable, CaseIterable, Sendable {
    /// 日榜
    case daily = "daily"
    /// 周榜
    case week = "week"
    /// 年榜
    case year = "year"
    /// 总榜
    case total = "total"
}

// MARK: - 专辑销量榜专辑类型

/// 专辑销量榜专辑类型枚举
/// 对应 TypeScript 中的 AlbumSongsaleboardAlbumType
public enum AlbumSongsaleboardAlbumType: Int, Codable, CaseIterable, Sendable {
    /// 数字专辑
    case album = 0
    /// 数字单曲
    case single = 1
}

// MARK: - 歌手列表区域

/// 歌手列表区域枚举
/// 对应 TypeScript 中的 ArtistListArea
public enum ArtistListArea: String, Codable, CaseIterable, Sendable {
    /// 华语
    case zh = "Z_H"
    /// 欧美
    case ea = "E_A"
    /// 韩国
    case kr = "KR"
    /// 日本
    case jp = "JP"
}

// MARK: - 歌手歌曲排序

/// 歌手歌曲排序方式枚举
/// 对应 TypeScript 中的 ArtistSongsOrder
public enum ArtistSongsOrder: String, Codable, CaseIterable, Sendable {
    /// 热门排序
    case hot = "hot"
    /// 时间排序
    case time = "time"
}

// MARK: - 每日签到类型

/// 每日签到类型枚举
/// 对应 TypeScript 中的 DailySigninType
public enum DailySigninType: Int, Codable, CaseIterable, Sendable {
    /// Android 端签到
    case android = 0
    /// PC 端签到
    case pc = 1
}

// MARK: - MV 区域

/// MV 区域枚举
/// 对应 TypeScript 中的 MvArea
/// 注意：rawValue 为中文字符串，匹配 API 参数值
public enum MvArea: String, Codable, CaseIterable, Sendable {
    /// 全部
    case all = "全部"
    /// 内地
    case zh = "内地"
    /// 港台
    case hk = "港台"
    /// 欧美
    case ea = "欧美"
    /// 韩国
    case kr = "韩国"
    /// 日本
    case jp = "日本"
}

// MARK: - MV 类型

/// MV 类型枚举
/// 对应 TypeScript 中的 MvType
/// 注意：rawValue 为中文字符串，匹配 API 参数值
public enum MvType: String, Codable, CaseIterable, Sendable {
    /// 全部
    case all = "全部"
    /// 官方版
    case offical = "官方版"
    /// 原生
    case raw = "原生"
    /// 现场版
    case live = "现场版"
    /// 网易出品
    case netease = "网易出品"
}

// MARK: - MV 排序

/// MV 排序方式枚举
/// 对应 TypeScript 中的 MvOrder
/// 注意：rawValue 为中文字符串，匹配 API 参数值
public enum MvOrder: String, Codable, CaseIterable, Sendable {
    /// 上升最快
    case trend = "上升最快"
    /// 最热
    case hot = "最热"
    /// 最新
    case new = "最新"
}

// MARK: - 资源类型

/// 资源类型枚举（用于点赞等操作）
/// 对应 TypeScript 中的 ResourceType
public enum ResourceType: Int, Codable, CaseIterable, Sendable {
    /// MV
    case mv = 1
    /// 电台
    case dj = 4
    /// 视频
    case video = 5
    /// 动态
    case event = 6
}

// MARK: - 搜索建议类型

/// 搜索建议类型枚举
/// 对应 TypeScript 中的 SearchSuggestType
public enum SearchSuggestType: String, Codable, CaseIterable, Sendable {
    /// 移动端
    case mobile = "mobile"
    /// 网页端
    case web = "web"
}

// MARK: - 分享资源类型

/// 分享资源类型枚举
/// 对应 TypeScript 中的 ShareResourceType
public enum ShareResourceType: String, Codable, CaseIterable, Sendable {
    /// 歌曲
    case song = "song"
    /// 歌单
    case playlist = "playlist"
    /// MV
    case mv = "mv"
    /// 电台节目
    case djprogram = "djprogram"
    /// 电台
    case djradio = "djradio"
}

// MARK: - 音质类型

/// 音质类型枚举
/// 对应 TypeScript 中的 SoundQualityType
public enum SoundQualityType: String, Codable, CaseIterable, Sendable {
    /// 标准音质
    case standard = "standard"
    /// 极高音质
    case exhigh = "exhigh"
    /// 无损音质
    case lossless = "lossless"
    /// Hi-Res 音质
    case hires = "hires"
    /// 鲸云臻品音效
    case jyeffect = "jyeffect"
    /// 鲸云母带
    case jymaster = "jymaster"
    /// 沉浸环绕声
    case sky = "sky"
}

// MARK: - 新歌榜类型

/// 新歌榜区域类型枚举
/// 对应 TypeScript 中的 TopSongType
public enum TopSongType: Int, Codable, CaseIterable, Sendable {
    /// 全部
    case all = 0
    /// 华语
    case zh = 7
    /// 欧美
    case ea = 96
    /// 韩国
    case kr = 16
    /// 日本
    case ja = 8
}

// MARK: - 歌手排行榜类型

/// 歌手排行榜区域类型枚举
/// 对应 TypeScript 中的 ToplistArtistType
public enum ToplistArtistType: Int, Codable, CaseIterable, Sendable {
    /// 华语
    case zh = 1
    /// 欧美
    case ea = 2
    /// 韩国
    case kr = 3
    /// 日本
    case ja = 4
}

// MARK: - 用户听歌记录类型

/// 用户听歌记录类型枚举
/// 对应 TypeScript 中的 UserRecordType
public enum UserRecordType: Int, Codable, CaseIterable, Sendable {
    /// 所有时间
    case all = 0
    /// 最近一周
    case weekly = 1
}
