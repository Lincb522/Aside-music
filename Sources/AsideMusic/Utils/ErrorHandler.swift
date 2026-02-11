import Foundation
import Combine

/// 应用错误类型
enum AppError: LocalizedError {
    case network(underlying: Error)
    case api(code: Int, message: String)
    case playback(reason: String)
    case cache(reason: String)
    case authentication
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .network(let error):
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    return NSLocalizedString("error_no_internet", comment: "无网络连接")
                case .timedOut:
                    return NSLocalizedString("error_timeout", comment: "请求超时")
                case .cannotFindHost, .cannotConnectToHost:
                    return NSLocalizedString("error_server_unreachable", comment: "无法连接服务器")
                default:
                    return NSLocalizedString("error_network_generic", comment: "网络连接失败")
                }
            }
            return NSLocalizedString("error_network_generic", comment: "网络连接失败，请检查网络设置")
            
        case .api(let code, let message):
            if code == 301 || code == 302 {
                return NSLocalizedString("error_need_login", comment: "请先登录")
            }
            return message.isEmpty ? NSLocalizedString("error_server_generic", comment: "服务器错误") : message
            
        case .playback(let reason):
            return String(format: NSLocalizedString("error_playback", comment: "播放失败"), reason)
            
        case .cache(let reason):
            return String(format: NSLocalizedString("error_cache", comment: "缓存错误"), reason)
            
        case .authentication:
            return NSLocalizedString("error_auth", comment: "登录已过期，请重新登录")
            
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    /// 用户友好的简短描述
    var shortDescription: String {
        switch self {
        case .network: return "网络错误"
        case .api: return "服务器错误"
        case .playback: return "播放失败"
        case .cache: return "缓存错误"
        case .authentication: return "登录过期"
        case .unknown: return "未知错误"
        }
    }
}

/// 统一错误处理器
class ErrorHandler {
    static let shared = ErrorHandler()
    
    private init() {}
    
    /// 处理错误
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 错误发生的上下文（用于日志）
    ///   - showAlert: 是否显示 Alert
    ///   - retryAction: 重试操作（可选）
    func handle(
        _ error: Error,
        context: String,
        showAlert: Bool = true,
        retryAction: (() -> Void)? = nil
    ) {
        // 转换为 AppError
        let appError = convertToAppError(error)
        
        // 日志记录
        logError(appError, context: context)
        
        // UI 反馈
        if showAlert {
            DispatchQueue.main.async {
                if let retry = retryAction {
                    AlertManager.shared.show(
                        title: appError.shortDescription,
                        message: appError.errorDescription ?? "发生未知错误",
                        primaryButtonTitle: "重试",
                        secondaryButtonTitle: "取消",
                        primaryAction: retry
                    )
                } else {
                    AlertManager.shared.show(
                        title: appError.shortDescription,
                        message: appError.errorDescription ?? "发生未知错误",
                        primaryButtonTitle: "确定",
                        primaryAction: {}
                    )
                }
            }
        }
    }
    
    /// 静默处理错误（只记录日志，不显示 UI）
    func handleSilently(_ error: Error, context: String) {
        let appError = convertToAppError(error)
        logError(appError, context: context)
    }
    
    /// 转换为 AppError
    private func convertToAppError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .userAuthenticationRequired:
                return .authentication
            default:
                return .network(underlying: urlError)
            }
        }
        
        return .unknown(error)
    }
    
    /// 记录错误日志
    private func logError(_ error: AppError, context: String) {
        AppLogger.error("[\(context)] \(error.shortDescription): \(error.errorDescription ?? "Unknown")")
        
        #if DEBUG
        if case .unknown(let underlying) = error {
            AppLogger.debug("  └─ Underlying: \(underlying)")
        }
        #endif
    }
}

// MARK: - Combine 扩展

extension Publisher {
    /// 统一错误处理的便捷方法
    func handleError(
        context: String,
        showAlert: Bool = false,
        retryAction: (() -> Void)? = nil
    ) -> AnyPublisher<Output, Failure> {
        self.handleEvents(receiveCompletion: { completion in
            if case .failure(let error) = completion {
                if showAlert {
                    ErrorHandler.shared.handle(error, context: context, showAlert: true, retryAction: retryAction)
                } else {
                    ErrorHandler.shared.handleSilently(error, context: context)
                }
            }
        })
        .eraseToAnyPublisher()
    }
}
