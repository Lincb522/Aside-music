import Foundation

/// 酷狗每日会员领取引擎。
///
/// 每个账号每天只尝试一次；成功或“今日已领取”都会落本地日期标记，失败则不标记，
/// 便于下次回到前台自动重试。领取与升级均复用现有 KCM API，不新增账号凭证存储。
@MainActor
final class KCMDailyMembershipEngine {
    static let shared = KCMDailyMembershipEngine()

    private let lastCheckKey = "mono_kcm_daily_membership_last_check"
    private var task: Task<Void, Never>?

    func checkIfNeeded(force: Bool = false, date: Date = Date()) {
        guard KCMMusicService.shared.isAuthenticated,
              let userID = KCMMusicService.shared.currentUserID else {
            return
        }

        let day = Self.dayKey(for: date)
        let marker = "\(userID):\(day)"
        if !force, UserDefaults.standard.string(forKey: lastCheckKey) == marker {
            return
        }

        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await KCMMusicService.shared.claimDailyLiteVIP(date: date)
                let upgradeResult = try? await KCMMusicService.shared.upgradeDailyLiteVIP()
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
            } catch {
                AppLogger.warning("[KCM] 每日会员检查失败，将在下次前台继续重试: \(error)")
            }
        }
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
