import Foundation

/// 所有 App Agent 共用的失败分类与退避规则。
enum AIAgentRuntimePolicy {
    static func shouldRetry(_ error: Error) -> Bool {
        if let aiError = error as? AIEqualizerError {
            switch aiError {
            case .invalidResponse:
                return true
            case let .httpStatus(code, _):
                return code == 408 || code == 425 || code == 429 || (500...599).contains(code)
            case .noSong, .playbackRequired, .sampleUnavailable,
                 .protectedAudioUnsupported, .invalidEndpoint, .missingAPIKey,
                 .modelUnavailable, .dailyLimitReached, .hourlyLimitReached,
                 .requestFrequencyLimited:
                return false
            }
        }

        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .cannotFindHost, .cannotConnectToHost,
             .networkConnectionLost, .notConnectedToInternet,
             .dnsLookupFailed, .secureConnectionFailed, .resourceUnavailable:
            return true
        default:
            return false
        }
    }

    static func retryDelay(
        after attempt: Int,
        minimumRequestInterval: TimeInterval
    ) -> TimeInterval {
        let exponential = min(8, pow(2, Double(max(0, attempt - 1))))
        return max(exponential, max(0, minimumRequestInterval) + 0.2)
    }
}
