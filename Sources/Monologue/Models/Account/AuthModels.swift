import Foundation

// MARK: - 登录与认证模型

/// 二维码登录密钥响应。
struct QRKeyResponse: Codable {
    let data: QRKeyData
}

struct QRKeyData: Codable {
    let unikey: String
}

/// 二维码内容创建响应。
struct QRCreateResponse: Codable {
    let data: QRCreateData
}

struct QRCreateData: Codable {
    let qrimg: String
    let qrurl: String
}

/// 二维码登录轮询结果。
struct QRCheckResponse: Codable {
    let code: Int
    let message: String?
    let cookie: String?
}

/// 仅包含状态码与可选消息的通用响应。
struct SimpleResponse: Codable {
    let code: Int
    let message: String?
}

/// 账号登录响应。
struct LoginResponse: Codable {
    let code: Int
    let cookie: String?
    let profile: UserProfile?
}

/// 当前登录状态响应。
struct LoginStatusResponse: Codable {
    let data: LoginStatusData
}

struct LoginStatusData: Codable {
    let profile: UserProfile?
}

/// 登录用户的基础资料与社交统计。
struct UserProfile: Codable, Equatable {
    let userId: Int
    let nickname: String
    let avatarUrl: String?
    let eventCount: Int?
    let follows: Int?
    let followeds: Int?
    let signature: String?
    let vipType: Int?
    
    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        lhs.userId == rhs.userId
    }
}
