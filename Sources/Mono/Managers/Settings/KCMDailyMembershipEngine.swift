import Foundation

@MainActor
final class KCMDailyMembershipEngine {
    static let shared = KCMDailyMembershipEngine()

    private let lastCheckKey = "mono_kcm_daily_membership_last_check"
    private var task: Task<Void, Never>?
    private var blockedCredentialContext: KCMMusicService.SessionCredentialContext?

    func hasCompletedToday(
        date: Date = Date(),
        ifCurrentSession expectedSession: KCMMusicService.SessionSnapshot? = nil
    ) -> Bool {
        let service = KCMMusicService.shared
        let requestedSession = expectedSession ?? service.sessionSnapshot
        guard service.isCurrentSession(requestedSession),
              let marker = completionMarker(for: date, session: requestedSession) else {
            return false
        }
        return UserDefaults.standard.string(forKey: lastCheckKey) == marker
    }

    func recordCompletion(
        date: Date = Date(),
        ifCurrentSession expectedSession: KCMMusicService.SessionSnapshot? = nil
    ) {
        let service = KCMMusicService.shared
        let requestedSession = expectedSession ?? service.sessionSnapshot
        guard service.isCurrentSession(requestedSession),
              let marker = completionMarker(for: date, session: requestedSession) else { return }
        blockedCredentialContext = nil
        UserDefaults.standard.set(marker, forKey: lastCheckKey)
    }

    func resumeAfterLogin() {
        blockedCredentialContext = nil
        checkIfNeeded()
    }

    func checkIfNeeded(force: Bool = false, date: Date = Date()) {
        let service = KCMMusicService.shared
        let requestedCredentialContext = service.sessionCredentialContext
        let requestedSession = requestedCredentialContext.snapshot
        guard let marker = completionMarker(for: date, session: requestedSession),
              service.isCurrentCredentialContext(requestedCredentialContext) else { return }
        if !force, UserDefaults.standard.string(forKey: lastCheckKey) == marker {
            return
        }
        if !force, blockedCredentialContext == requestedCredentialContext {
            return
        }

        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await service.claimDailyLiteVIP(
                    date: date,
                    ifCurrentSession: requestedSession
                )
                let upgradeResult = try? await service.upgradeDailyLiteVIP(
                    ifCurrentSession: requestedSession
                )
                guard service.isCurrentSession(requestedSession) else { return }
                UserDefaults.standard.set(marker, forKey: self.lastCheckKey)

                let claimText: String
                switch result {
                case .claimed: claimText = "领取成功"
                case .alreadyClaimed: claimText = "今日已领取"
                }
                let upgradeText = upgradeResult.map { String($0) } ?? "unknown"
                AppLogger.info("[KCM] 每日会员检查完成: \(claimText), upgrade=\(upgradeText)")
            } catch is CancellationError {
                return
            } catch KCMMusicError.sessionExpired(let failureContext) {
                guard let failureContext,
                      service.isCurrentCredentialContext(failureContext) else { return }
                self.blockedCredentialContext = failureContext
                AppLogger.warning("[KCM] 登录状态已失效，重新扫码登录后再检查每日会员")
            } catch {
                guard service.isCurrentSession(requestedSession) else { return }
                AppLogger.warning("[KCM] 每日会员检查失败，将在下次前台继续重试: \(error.localizedDescription)")
            }
        }
    }

    private func completionMarker(
        for date: Date,
        session: KCMMusicService.SessionSnapshot
    ) -> String? {
        guard session.isAuthenticated, let userID = session.userID else { return nil }
        return "\(userID):\(session.revision):\(Self.dayKey(for: date))"
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
