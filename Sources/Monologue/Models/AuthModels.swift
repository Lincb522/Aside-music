import Foundation

// MARK: - Authentication & Login Models

// QR 登录 - Key
struct QRKeyResponse: Codable {
    let data: QRKeyData
}

struct QRKeyData: Codable {
    let unikey: String
}

// QR 登录 - 创建二维码
struct QRCreateResponse: Codable {
    let data: QRCreateData
}

struct QRCreateData: Codable {
    let qrimg: String
    let qrurl: String
}

// QR 登录 - 检查状态
struct QRCheckResponse: Codable {
    let code: Int
    let message: String?
    let cookie: String?
}

// 通用简单响应
struct SimpleResponse: Codable {
    let code: Int
    let message: String?
}

// 手机号登录响应
struct LoginResponse: Codable {
    let code: Int
    let cookie: String?
    let profile: UserProfile?
}

// 登录状态
struct LoginStatusResponse: Codable {
    let data: LoginStatusData
}

struct LoginStatusData: Codable {
    let profile: UserProfile?
}

// 用户资料
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
