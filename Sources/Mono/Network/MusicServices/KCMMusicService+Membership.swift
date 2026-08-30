import Foundation

extension KCMMusicService {
    func claimDailyLiteVIP(
        date: Date = Date(),
        ifCurrentSession expectedSession: SessionSnapshot? = nil
    ) async throws -> KCMDailyVIPClaimResult {
        let requestedSession = expectedSession ?? sessionSnapshot
        guard requestedSession.isAuthenticated,
              isCurrentSession(requestedSession) else {
            throw KCMMusicError.authenticationRequired
        }

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
                ],
                ifCurrentSession: requestedSession
            )
            guard isCurrentSession(requestedSession) else { throw CancellationError() }
            guard Self.isSuccess(json) else { throw KCMMusicError.unavailable }
            Task { [weak self] in
                await self?.synchronizeCurrentAccount(
                    ifCurrentSession: requestedSession
                )
            }
            return .claimed
        } catch KCMMusicError.server(let code, _) where code == 131001 || code == 297002 {
            guard isCurrentSession(requestedSession) else { throw CancellationError() }
            return .alreadyClaimed
        } catch let error as KCMMusicError {
            guard isCurrentSession(requestedSession) else { throw CancellationError() }
            guard case .server(let code, _) = error, code == 51002 else {
                throw error
            }
            do {
                if try await fetchAccountProfile(
                    ifCurrentSession: requestedSession
                )?.isVIP == true {
                    return .alreadyClaimed
                }
            } catch KCMMusicError.sessionExpired(let failureContext) {
                throw KCMMusicError.sessionExpired(failureContext)
            } catch {
                throw error
            }
            throw error
        }
    }

    func upgradeDailyLiteVIP(
        ifCurrentSession expectedSession: SessionSnapshot? = nil
    ) async throws -> Bool {
        let requestedSession = expectedSession ?? sessionSnapshot
        guard requestedSession.isAuthenticated,
              isCurrentSession(requestedSession) else {
            throw KCMMusicError.authenticationRequired
        }
        let succeeded = Self.isSuccess(
            try await request(
                path: "/youth/day/vip/upgrade",
                method: "POST",
                query: [URLQueryItem(name: "timestamp", value: Self.requestTimestamp)],
                ifCurrentSession: requestedSession
            )
        )
        guard isCurrentSession(requestedSession) else { throw CancellationError() }
        if succeeded {
            Task { [weak self] in
                await self?.synchronizeCurrentAccount(
                    ifCurrentSession: requestedSession
                )
            }
        }
        return succeeded
    }
}
