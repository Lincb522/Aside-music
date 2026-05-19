// NCMError.swift
// 错误类型定义
// 定义ncm API 的各类错误枚举
// 遵循 LocalizedError 协议，提供中文错误描述

import Foundation

// MARK: - 错误类型

/// ncm API 错误枚举
/// 覆盖加密错误、解密错误、网络错误、API 业务错误、无效响应和序列化错误
public enum NCMError: Error, LocalizedError {

    /// 加密失败
    /// - Parameters:
    ///   - mode: 使用的加密模式（weapi、linuxapi、eapi、api）
    ///   - detail: 详细错误描述
    case encryptionFailed(mode: CryptoMode, detail: String)

    /// 解密失败
    /// - Parameters:
    ///   - mode: 使用的加密模式
    ///   - detail: 详细错误描述
    case decryptionFailed(mode: CryptoMode, detail: String)

    /// 网络错误
    /// - Parameters:
    ///   - statusCode: HTTP 状态码
    ///   - message: 错误消息
    case networkError(statusCode: Int, message: String)

    /// API 业务错误（归一化后状态码非 200）
    /// - Parameters:
    ///   - code: API 返回的业务错误码
    ///   - body: 完整的响应体
    case apiError(code: Int, body: [String: Any])

    /// 无效响应（响应格式异常）
    /// - Parameter detail: 详细错误描述
    case invalidResponse(detail: String)

    /// 序列化/反序列化失败
    /// - Parameter detail: 详细错误描述
    case serializationFailed(detail: String)

    /// 无效的 URL
    case invalidURL

    // MARK: - LocalizedError 协议实现

    /// 本地化的错误描述（中文）
    public var errorDescription: String? {
        switch self {
        case .encryptionFailed(let mode, let detail):
            return "加密失败 [\(mode)]: \(detail)"
        case .decryptionFailed(let mode, let detail):
            return "解密失败 [\(mode)]: \(detail)"
        case .networkError(let code, let msg):
            return "网络错误 [\(code)]: \(msg)"
        case .apiError(let code, _):
            return "API 错误 [\(code)]"
        case .invalidResponse(let detail):
            return "无效响应: \(detail)"
        case .serializationFailed(let detail):
            return "序列化失败: \(detail)"
        case .invalidURL:
            return "无效的 URL 地址"
        }
    }
}
