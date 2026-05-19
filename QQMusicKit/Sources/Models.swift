import Foundation

// MARK: - 统一响应

/// API 统一响应结构
public struct APIResponse<T: Decodable>: Decodable {
    /// 状态码（200 为成功）
    public let code: Int
    /// 消息
    public let message: String
    /// 数据
    public let data: T?
    /// 错误列表
    public let errors: [String]?
    /// 时间戳
    public let timestamp: Int?
}

/// 通用 API 路由的包装层（/{module}/{func} 返回 {"result": T, "source": "..."}）
public struct WrappedData<T: Decodable>: Decodable {
    /// 实际业务数据
    public let result: T
    /// 数据来源: "client" / "server" / "server_fallback"
    public let source: String
}

// MARK: - 错误

/// qcm API 错误
public enum QQMusicError: LocalizedError {
    /// URL 构造失败
    case invalidURL(String)
    /// 响应格式无效
    case invalidResponse
    /// 响应数据为空
    case emptyData
    /// API 返回错误
    case apiError(code: Int, message: String, errors: [String]?)
    /// 未登录
    case notLoggedIn

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let path):
            return "无效的URL: \(path)"
        case .invalidResponse:
            return "服务器响应格式无效"
        case .emptyData:
            return "响应数据为空"
        case .apiError(let code, let message, let errors):
            let detail = errors?.joined(separator: "; ") ?? ""
            return "[\(code)] \(message)\(detail.isEmpty ? "" : " - \(detail)")"
        case .notLoggedIn:
            return "未登录，请先扫码登录"
        }
    }
}

// MARK: - JSON 动态类型

/// 通用 JSON 值，用于处理动态结构的 API 响应
public enum JSON: Decodable, CustomStringConvertible, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSON])
    case object([String: JSON])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode([JSON].self) { self = .array(v) }
        else if let v = try? container.decode([String: JSON].self) { self = .object(v) }
        else { self = .null }
    }

    /// 获取字符串值
    public var stringValue: String? {
        if case .string(let v) = self { return v }
        if case .int(let v) = self { return String(v) }
        return nil
    }

    /// 获取整数值
    public var intValue: Int? {
        if case .int(let v) = self { return v }
        if case .double(let v) = self { return Int(v) }
        if case .string(let v) = self { return Int(v) }
        return nil
    }

    /// 获取浮点值
    public var doubleValue: Double? {
        if case .double(let v) = self { return v }
        if case .int(let v) = self { return Double(v) }
        return nil
    }

    /// 获取布尔值
    public var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    /// 获取数组
    public var arrayValue: [JSON]? {
        if case .array(let v) = self { return v }
        return nil
    }

    /// 获取字典
    public var objectValue: [String: JSON]? {
        if case .object(let v) = self { return v }
        return nil
    }

    /// 下标访问字典
    public subscript(key: String) -> JSON? {
        objectValue?[key]
    }

    /// 下标访问数组
    public subscript(index: Int) -> JSON? {
        guard let arr = arrayValue, index >= 0, index < arr.count else { return nil }
        return arr[index]
    }

    public var description: String {
        switch self {
        case .string(let v): return "\"\(v)\""
        case .int(let v): return "\(v)"
        case .double(let v): return "\(v)"
        case .bool(let v): return "\(v)"
        case .null: return "null"
        case .array(let v): return "[\(v.map(\.description).joined(separator: ", "))]"
        case .object(let v):
            let pairs = v.map { "\"\($0.key)\": \($0.value)" }
            return "{\(pairs.joined(separator: ", "))}"
        }
    }
}

// MARK: - 认证模型

/// 登录状态
public struct AuthStatus: Decodable, Sendable {
    /// 是否已登录
    public let loggedIn: Bool
    /// 音乐 ID
    public let musicid: Int?
    /// 音乐密钥（客户端凭证验证时返回）
    public let musickey: String?
    /// 登录类型
    public let loginType: Int?
    /// 当前活跃账号名
    public let account: String?
    /// 用户昵称
    public let nickname: String?
    /// 用户头像 URL
    public let avatar: String?
    /// encrypt_uin
    public let euin: String?
    /// 是否 VIP
    public let isVip: Int?
    /// 是否 SVIP
    public let isSvip: Int?

    enum CodingKeys: String, CodingKey {
        case loggedIn = "logged_in"
        case musicid
        case musickey
        case loginType = "login_type"
        case account
        case nickname
        case avatar
        case euin
        case isVip = "is_vip"
        case isSvip = "is_svip"
    }
}

/// 二维码信息
public struct QRCode: Decodable, Sendable {
    /// 二维码 ID（用于轮询状态）
    public let qrId: String
    /// Base64 图片（data:image/png;base64,...）
    public let image: String

    enum CodingKeys: String, CodingKey {
        case qrId = "qr_id"
        case image
    }

    /// 获取图片二进制数据
    public var imageData: Data? {
        guard let base64 = image.components(separatedBy: ",").last else { return nil }
        return Data(base64Encoded: base64)
    }
}

/// 二维码扫码状态
public struct QRCodeStatus: Decodable, Sendable {
    public let status: String
    public let musicid: Int?
    public let musickey: String?
    public let account: String?
    public let nickname: String?
    public let avatar: String?
    public let is_vip: Int?
    public let is_svip: Int?
    public let euin: String?
    public let loginType: Int?

    enum CodingKeys: String, CodingKey {
        case status, musicid, musickey, account, nickname, avatar
        case is_vip, is_svip, euin
        case loginType = "login_type"
    }

    /// 等待扫码
    public var isScan: Bool { status == "SCAN" }
    /// 已扫码，等待确认
    public var isConfirm: Bool { status == "CONF" }
    /// 登录成功
    public var isDone: Bool { status == "DONE" }
    /// 二维码过期
    public var isTimeout: Bool { status == "TIMEOUT" }
    /// 用户拒绝
    public var isRefused: Bool { status == "REFUSE" }
    /// 是否为终态（不需要继续轮询）
    public var isFinal: Bool { isDone || isTimeout || isRefused }
}

/// 手机验证码发送状态
public struct PhoneSendStatus: Decodable, Sendable {
    /// 状态：SEND / CAPTCHA
    public let status: String
    /// 验证链接（需要滑块验证时返回）
    public let url: String?

    /// 是否发送成功
    public var isSent: Bool { status == "SEND" }
    /// 是否需要验证
    public var needCaptcha: Bool { status == "CAPTCHA" }
}

// MARK: - 歌词模型

/// 歌词结果
public struct LyricResult: Sendable {
    /// 原文歌词
    public let lyric: String?
    /// QRC 逐字歌词
    public let qrc: String?
    /// 翻译歌词
    public let trans: String?
    /// 罗马音歌词
    public let roma: String?

    /// 是否有歌词
    public var hasLyric: Bool { lyric != nil && !(lyric?.isEmpty ?? true) }
    /// 是否有翻译
    public var hasTranslation: Bool { trans != nil && !(trans?.isEmpty ?? true) }
    /// 是否有逐字歌词
    public var hasQRC: Bool { qrc != nil && !(qrc?.isEmpty ?? true) }
}

extension LyricResult: Decodable {
    enum CodingKeys: String, CodingKey {
        case lyric, qrc, trans, roma
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lyric = Self.decodeStringOrNil(container: container, key: .lyric)
        qrc = Self.decodeStringOrNil(container: container, key: .qrc)
        trans = Self.decodeStringOrNil(container: container, key: .trans)
        roma = Self.decodeStringOrNil(container: container, key: .roma)
    }

    private static func decodeStringOrNil(container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> String? {
        if let str = try? container.decode(String.self, forKey: key), !str.isEmpty {
            return str
        }
        return nil
    }
}

// MARK: - 枚举

/// 二维码登录类型
public enum QRLoginType: String, Sendable {
    case qq = "qq"
    case wx = "wx"
    case mobile = "mobile"
}

/// 搜索类型（rawValue 为枚举名称，服务端 parser 按名称匹配到整数值）
public enum SearchType: String, Sendable {
    /// 歌曲 (0)
    case song = "SONG"
    /// 歌手 (1)
    case singer = "SINGER"
    /// 专辑 (2)
    case album = "ALBUM"
    /// 歌单 (3)
    case songlist = "SONGLIST"
    /// MV (4)
    case mv = "MV"
    /// 歌词 (7)
    case lyric = "LYRIC"
    /// 用户 (8)
    case user = "USER"
    /// 节目专辑 (15)
    case audioAlbum = "AUDIO_ALBUM"
    /// 节目 (18)
    case audio = "AUDIO"
}

/// 歌曲文件类型
public enum SongFileType: String, Sendable, CaseIterable {
    /// 臻品母带 24Bit 192kHz
    case master = "MASTER"
    /// DTS:X 臻品音效
    case dtsx = "DTS_X"
    /// 臻品全景声 7.1
    case atmos71 = "ATMOS_71"
    /// 臻品全景声 16Bit 44.1kHz
    case atmos2 = "ATMOS_2"
    /// 臻品音质 16Bit 44.1kHz
    case atmos51 = "ATMOS_51"
    /// 腾讯 AICodec
    case nac = "NAC"
    /// 杜比全景声
    case dolby = "DOLBY"
    /// 黑胶
    case vinyl = "VINYL"
    /// FLAC 无损 16Bit~24Bit
    case flac = "FLAC"
    /// OGG 640kbps
    case ogg640 = "OGG_640"
    /// OGG 320kbps
    case ogg320 = "OGG_320"
    /// OGG 192kbps
    case ogg192 = "OGG_192"
    /// OGG 96kbps
    case ogg96 = "OGG_96"
    /// MP3 320kbps
    case mp3_320 = "MP3_320"
    /// MP3 128kbps
    case mp3_128 = "MP3_128"
    /// AAC 192kbps
    case aac192 = "ACC_192"
    /// AAC 96kbps
    case aac96 = "ACC_96"
    /// AAC 48kbps
    case aac48 = "ACC_48"

    /// 显示名称
    public var displayName: String {
        switch self {
        case .master:  return "臻品母带 (24Bit 192kHz)"
        case .dtsx:    return "DTS:X 臻品音效"
        case .atmos71: return "臻品全景声 7.1"
        case .atmos2:  return "臻品全景声 2.0"
        case .atmos51: return "臻品全景声 5.1"
        case .nac:     return "腾讯 AICodec"
        case .dolby:   return "杜比全景声"
        case .vinyl:   return "黑胶"
        case .flac:    return "FLAC 无损"
        case .ogg640:  return "OGG 640kbps"
        case .ogg320:  return "OGG 320kbps"
        case .ogg192:  return "OGG 192kbps"
        case .ogg96:   return "OGG 96kbps"
        case .mp3_320: return "MP3 320kbps"
        case .mp3_128: return "MP3 128kbps"
        case .aac192:  return "AAC 192kbps"
        case .aac96:   return "AAC 96kbps"
        case .aac48:   return "AAC 48kbps"
        }
    }

    /// 常用音质选项（供 UI 选择器使用）
    public static var commonOptions: [SongFileType] {
        [.dtsx, .master, .atmos71, .dolby, .vinyl, .flac, .ogg320, .mp3_320, .mp3_128, .aac96]
    }
}

/// 加密歌曲文件类型（返回 url + ekey，需解密后播放）
public enum EncryptedSongFileType: String, Sendable, CaseIterable {
    /// 臻品母带 24Bit 192kHz (.mflac)
    case master = "MASTER"
    /// DTS:X 臻品音效 (.mflac)
    case dtsx = "DTS_X"
    /// 臻品全景声 7.1 (.mflac)
    case atmos71 = "ATMOS_71"
    /// 臻品全景声 16Bit 44.1kHz (.mflac)
    case atmos2 = "ATMOS_2"
    /// 臻品音质 16Bit 44.1kHz (.mflac)
    case atmos51 = "ATMOS_51"
    /// 腾讯 AICodec (.mflac)
    case nac = "NAC"
    /// 黑胶数字母带 (.mflac)
    case vinyl = "VINYL"
    /// FLAC 无损 (.mflac)
    case flac = "FLAC"
    /// OGG 640kbps (.mgg)
    case ogg640 = "OGG_640"
    /// OGG 320kbps (.mgg)
    case ogg320 = "OGG_320"
    /// OGG 192kbps (.mgg)
    case ogg192 = "OGG_192"
    /// OGG 96kbps (.mgg)
    case ogg96 = "OGG_96"

    /// 显示名称
    public var displayName: String {
        switch self {
        case .master:  return "臻品母带 加密 (.mflac)"
        case .dtsx:    return "DTS:X 臻品音效 加密 (.mflac)"
        case .atmos71: return "臻品全景声 7.1 加密 (.mflac)"
        case .atmos2:  return "臻品全景声 加密 (.mflac)"
        case .atmos51: return "臻品音质 加密 (.mflac)"
        case .nac:     return "腾讯 AICodec 加密 (.mflac)"
        case .vinyl:   return "黑胶数字母带 加密 (.mflac)"
        case .flac:    return "FLAC 无损 加密 (.mflac)"
        case .ogg640:  return "OGG 640kbps 加密 (.mgg)"
        case .ogg320:  return "OGG 320kbps 加密 (.mgg)"
        case .ogg192:  return "OGG 192kbps 加密 (.mgg)"
        case .ogg96:   return "OGG 96kbps 加密 (.mgg)"
        }
    }
}

/// 加密歌曲 URL 结果
public struct EncryptedSongURL: Sendable {
    /// 下载链接
    public let url: String
    /// 解密密钥
    public let ekey: String
}

/// 歌手地区
public enum AreaType: String, Sendable {
    case all = "ALL"
    case china = "CHINA"
    case taiwan = "TAIWAN"
    case america = "AMERICA"
    case japan = "JAPAN"
    case korea = "KOREA"
}

/// 歌手性别/组合
public enum SexType: String, Sendable {
    case all = "ALL"
    case male = "MALE"
    case female = "FEMALE"
    case group = "GROUP"
}

/// 歌手 Tab 类型（rawValue 为服务端 TabType 枚举名称）
public enum SingerTabType: String, Sendable {
    /// 百科
    case wiki = "WIKI"
    /// 演唱歌曲
    case song = "SONG"
    /// 专辑
    case album = "ALBUM"
    /// 作曲
    case composer = "COMPOSER"
    /// 作词
    case lyricist = "LYRICIST"
    /// 制作人
    case producer = "PRODUCER"
    /// 编曲
    case arranger = "ARRANGER"
    /// 乐手
    case musician = "MUSICIAN"
    /// 视频
    case video = "VIDEO"
}

/// 歌手风格
public enum GenreType: String, Sendable {
    case all = "ALL"
    case pop = "POP"
    case rap = "RAP"
    case chineseStyle = "CHINESE_STYLE"
    case rock = "ROCK"
    case electronic = "ELECTRONIC"
    case folk = "FOLK"
    case rnb = "R_AND_B"
    case ethnic = "ETHNIC"
    case lightMusic = "LIGHT_MUSIC"
    case jazz = "JAZZ"
    case classical = "CLASSICAL"
    case country = "COUNTRY"
    case blues = "BLUES"
}
