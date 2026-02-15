import Foundation

// MARK: - 认证相关模型

struct LoginStatusResponse: Codable {
    let data: LoginStatusData
}

struct LoginStatusData: Codable {
    let profile: UserProfile?
}

struct LoginResponse: Codable {
    let code: Int
    let cookie: String?
    let profile: UserProfile?
}

struct QRKeyResponse: Codable {
    let data: QRKeyData
}

struct QRKeyData: Codable {
    let unikey: String
}

struct QRCreateResponse: Codable {
    let data: QRCreateData
}

struct QRCreateData: Codable {
    let qrimg: String
    let qrurl: String
}

struct QRCheckResponse: Codable {
    let code: Int
    let message: String
    let cookie: String?
}

struct SimpleResponse: Codable {
    let code: Int
    let message: String?
}

struct UserProfile: Codable {
    let userId: Int
    let nickname: String
    let avatarUrl: String
    let eventCount: Int?
    let follows: Int?
    let followeds: Int?
    let signature: String?
}
