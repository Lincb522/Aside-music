import Foundation

extension KCMMusicService {
    func claimDailyLiteVIP(date: Date = Date()) async throws -> KCMDailyVIPClaimResult {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        do {
            let json = try await request(
                path: "/youth/day/vip",
                method: "POST",
                query: [
                    URLQueryItem(name: "receive_day", value: formatter.string(from: date)),
                    URLQueryItem(name: "timestamp", value: Self.requestTimestamp),
                ]
            )
            guard Self.isSuccess(json) else { throw KCMMusicError.unavailable }
            Task { [weak self] in await self?.synchronizeCurrentAccount() }
            return .claimed
        } catch KCMMusicError.server(let code, _) where code == 131001 || code == 297002 {
            return .alreadyClaimed
        } catch let error as KCMMusicError {
            guard case .server(let code, _) = error, code == 51002 else {
                throw error
            }
            do {
                if try await fetchAccountProfile()?.isVIP == true {
                    return .alreadyClaimed
                }
            } catch KCMMusicError.sessionExpired {
                throw KCMMusicError.sessionExpired
            } catch {
                throw error
            }
            throw error
        }
    }

    func upgradeDailyLiteVIP() async throws -> Bool {
        let succeeded = Self.isSuccess(
            try await request(
                path: "/youth/day/vip/upgrade",
                method: "POST",
                query: [URLQueryItem(name: "timestamp", value: Self.requestTimestamp)]
            )
        )
        if succeeded { Task { [weak self] in await self?.synchronizeCurrentAccount() } }
        return succeeded
    }

}
