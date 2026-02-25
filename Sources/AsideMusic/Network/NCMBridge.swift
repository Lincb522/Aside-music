// NCMBridge.swift
// NCMClient 与 APIService 的桥接层
// 将 NCMClient 的 async/await + APIResponse 转换为 Combine Publisher + Codable 模型

import Foundation
@preconcurrency import Combine
import NeteaseCloudMusicAPI

// MARK: - APIResponse 扩展：支持 Codable 解码

extension APIResponse {

    /// 将 APIResponse.body 字典解码为指定的 Codable 类型
    /// - Returns: 解码后的模型对象
    /// - Throws: 解码失败时抛出错误
    func decode<T: Codable>(_ type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: body)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    /// 从 body 中提取指定 key 的值并解码
    /// - Parameters:
    ///   - type: 目标类型
    ///   - key: body 字典中的 key
    /// - Returns: 解码后的模型对象
    func decode<T: Codable>(_ type: T.Type, forKey key: String) throws -> T {
        guard let value = body[key] else {
            throw NCMBridgeError.missingKey(key)
        }
        let data = try JSONSerialization.data(withJSONObject: value)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    /// 从 body 中按路径提取嵌套值并解码
    /// 例如 keyPath: "data.dailySongs" 会先取 body["data"]，再取其中的 "dailySongs"
    func decode<T: Codable>(_ type: T.Type, keyPath: String) throws -> T {
        let keys = keyPath.split(separator: ".").map(String.init)
        var current: Any = body

        for key in keys {
            guard let dict = current as? [String: Any],
                  let next = dict[key] else {
                throw NCMBridgeError.missingKey(keyPath)
            }
            current = next
        }

        let data = try JSONSerialization.data(withJSONObject: current)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - 桥接错误类型

enum NCMBridgeError: LocalizedError {
    case missingKey(String)
    case apiError(Int, String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingKey(let key):
            return "响应中缺少字段: \(key)"
        case .apiError(let code, let msg):
            return "API 错误 [\(code)]: \(msg)"
        case .invalidResponse:
            return "无效的 API 响应"
        }
    }
}

// MARK: - NCMClient async -> Combine 桥接

extension NCMClient {

    /// 将 NCMClient 的 async 方法转换为 Combine Publisher
    /// 用法: ncm.publisher { try await ncm.recommendSongs() }
    func publisher<T>(
        _ operation: @escaping () async throws -> T
    ) -> AnyPublisher<T, Error> {
        asyncToPublisher(operation)
    }

    /// 执行 API 请求并自动解码为 Codable 类型
    /// 返回 Combine Publisher
    func fetch<T: Codable>(
        _ type: T.Type,
        operation: @escaping () async throws -> APIResponse
    ) -> AnyPublisher<T, Error> {
        publisher {
            let response = try await operation()
            // 检查业务错误码
            if let code = response.body["code"] as? Int, code != 200 {
                let msg = response.body["msg"] as? String
                    ?? response.body["message"] as? String
                    ?? "未知错误"
                throw NCMBridgeError.apiError(code, msg)
            }
            return try response.decode(T.self)
        }
    }

    /// 执行 API 请求，从指定 keyPath 解码
    func fetch<T: Codable>(
        _ type: T.Type,
        keyPath: String,
        operation: @escaping () async throws -> APIResponse
    ) -> AnyPublisher<T, Error> {
        publisher {
            let response = try await operation()
            if let code = response.body["code"] as? Int, code != 200 {
                let msg = response.body["msg"] as? String
                    ?? response.body["message"] as? String
                    ?? "未知错误"
                throw NCMBridgeError.apiError(code, msg)
            }
            return try response.decode(T.self, keyPath: keyPath)
        }
    }
}


// MARK: - async → Combine 通用桥接

/// 将 async 闭包转换为 Combine Publisher，避免 Future + Task + promise 的 Sendable 问题
func asyncToPublisher<T>(
    _ operation: @escaping () async throws -> T
) -> AnyPublisher<T, Error> {
    let sendableOp = UnsafeSendableBox(operation)
    return Deferred {
        Future<T, Error> { promise in
            let sendablePromise = UnsafeSendableBox(promise)
            Task {
                do {
                    let result = try await sendableOp.value()
                    sendablePromise.value(.success(result))
                } catch {
                    sendablePromise.value(.failure(error))
                }
            }
        }
    }
    .receive(on: DispatchQueue.main)
    .eraseToAnyPublisher()
}

/// 包装非 Sendable 值使其可跨 Task 边界传递
/// 仅用于 Future promise 和已知安全的 async 桥接场景
struct UnsafeSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

// MARK: - Publisher → async/await 桥接

extension Publisher where Failure == Error {
    /// 将 Combine Publisher 转换为 async/await 调用
    /// 等待第一个值或抛出错误
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            let state = ContinuationState(continuation: continuation)
            var cancellable: AnyCancellable?
            
            cancellable = self.first()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            if state.tryMarkResumed() {
                                state.continuation.resume(throwing: NCMBridgeError.invalidResponse)
                            }
                        case .failure(let error):
                            if state.tryMarkResumed() {
                                state.continuation.resume(throwing: error)
                            }
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        if state.tryMarkResumed() {
                            let sendableValue = UnsafeSendableBox(value)
                            state.continuation.resume(returning: sendableValue.value)
                        }
                        cancellable?.cancel()
                    }
                )
        }
    }
}

/// 线程安全的 continuation 状态容器，使用 NSLock 保证 check-and-set 的原子性
private final class ContinuationState<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _resumed = false
    let continuation: CheckedContinuation<T, Error>
    
    init(continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }
    
    /// 原子性地标记为已恢复。仅首次调用返回 true，后续返回 false。
    func tryMarkResumed() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _resumed { return false }
        _resumed = true
        return true
    }
}
