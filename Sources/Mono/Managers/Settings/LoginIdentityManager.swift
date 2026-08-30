import Combine
import Foundation

@MainActor
final class LoginIdentityManager: ObservableObject {
    static let shared = LoginIdentityManager()

    static let supportedSources: [MusicSource] = [.netease, .qqmusic, .kugou]

    @Published private(set) var activeSource: MusicSource?
    @Published private(set) var kcmProfile: KCMAccountProfile?
    @Published private(set) var profileRevision = 0

    private var cancellables = Set<AnyCancellable>()
    private var kcmProfileSession: KCMMusicService.SessionSnapshot?
    private var kcmProfileRefreshSessions = Set<KCMMusicService.SessionSnapshot>()
    /// During QCM validation, `activeSource` remains an authenticated effective
    /// identity while UserDefaults retains the pending QCM preference.
    private var isRestoringStoredQCMIdentity = false

    private init() {
        let storedSource = UserDefaults.standard
            .string(forKey: AppConfig.StorageKeys.activeLoginIdentity)
            .flatMap(MusicSource.init(rawValue:))
        activeSource = storedSource

        isRestoringStoredQCMIdentity = storedSource == .qqmusic
            && !QQUserSession.shared.isLoggedIn
            && QQUserSession.shared.hasStoredCredentials
        if isRestoringStoredQCMIdentity {
            reconcileActiveSource(persistSelection: false)
        } else {
            reconcileActiveSource()
        }

        QQUserSession.shared.$isLoggedIn
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoggedIn in
                guard isLoggedIn == QQUserSession.shared.isLoggedIn else { return }
                if isLoggedIn {
                    _ = self?.resolveStoredQCMIdentity(after: .authenticated)
                    self?.accountAvailabilityDidChange()
                } else {
                    self?.accountDidLogOut(.qqmusic)
                }
            }
            .store(in: &cancellables)

        QQUserSession.shared.$sessionRevision
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.isRestoringStoredQCMIdentity,
                   !QQUserSession.shared.hasStoredCredentials {
                    _ = self.resolveStoredQCMIdentity(after: .unauthenticated)
                }
                self.accountAvailabilityDidChange()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(
            QQUserSession.shared.$nickname,
            QQUserSession.shared.$avatarURL,
            QQUserSession.shared.$isVIP
        )
        .dropFirst()
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            self?.profileRevision &+= 1
        }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .didLogin)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard APIService.shared.isLoggedIn else {
                    self?.accountAvailabilityDidChange()
                    return
                }
                _ = self?.select(.netease)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .didLogout)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.accountDidLogOut(.netease)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .kcmSessionDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let session = KCMMusicService.shared.sessionSnapshot
                self.invalidateKCMProfile(ifNotMatching: session)
                self.accountAvailabilityDidChange()
                self.scheduleKCMProfileRefreshIfActive()
            }
            .store(in: &cancellables)

        if isRestoringStoredQCMIdentity {
            Task { [weak self] in
                let result = await QQUserSession.shared.refresh()
                guard let self, self.isRestoringStoredQCMIdentity else { return }
                if self.resolveStoredQCMIdentity(after: result) {
                    self.accountAvailabilityDidChange()
                }
            }
        } else if activeSource == .kugou,
                  KCMMusicService.shared.isAuthenticated {
            scheduleKCMProfileRefreshIfActive()
        }
    }

    var hasActiveIdentity: Bool {
        guard let activeSource else { return false }
        return isLoggedIn(to: activeSource)
    }

    var availableSources: [MusicSource] {
        Self.supportedSources.filter(isLoggedIn(to:))
    }

    func isLoggedIn(to source: MusicSource) -> Bool {
        switch source {
        case .netease:
            return APIService.shared.isLoggedIn
        case .qqmusic:
            return QQUserSession.shared.isLoggedIn
        case .kugou:
            return KCMMusicService.shared.isAuthenticated
        case .qishui, .appleMusic, .local:
            return false
        }
    }

    @discardableResult
    func select(_ source: MusicSource) -> Bool {
        guard Self.supportedSources.contains(source), isLoggedIn(to: source) else {
            return false
        }
        let wasRestoringStoredQCMIdentity = isRestoringStoredQCMIdentity
        isRestoringStoredQCMIdentity = false
        guard activeSource != source else {
            UserDefaults.standard.set(
                source.rawValue,
                forKey: AppConfig.StorageKeys.activeLoginIdentity
            )
            if wasRestoringStoredQCMIdentity {
                profileRevision &+= 1
            }
            if source == .kugou {
                invalidateKCMProfile(
                    ifNotMatching: KCMMusicService.shared.sessionSnapshot
                )
                scheduleKCMProfileRefreshIfActive()
            }
            return true
        }

        activeSource = source
        UserDefaults.standard.set(source.rawValue, forKey: AppConfig.StorageKeys.activeLoginIdentity)
        profileRevision &+= 1
        AppLogger.info("[LoginIdentity] activeSource=\(source.rawValue)")

        if source == .kugou {
            invalidateKCMProfile(
                ifNotMatching: KCMMusicService.shared.sessionSnapshot
            )
            scheduleKCMProfileRefreshIfActive()
        }
        return true
    }

    func accountDidLogOut(_ source: MusicSource) {
        let previousActiveSource = activeSource
        let endedStoredQCMRestore = source == .qqmusic
            && isRestoringStoredQCMIdentity
        if source == .qqmusic {
            isRestoringStoredQCMIdentity = false
        }
        if source == .kugou {
            kcmProfile = nil
            kcmProfileSession = nil
        }
        if activeSource == source {
            activeSource = Self.supportedSources.first {
                $0 != source && isLoggedIn(to: $0)
            }
            if !isRestoringStoredQCMIdentity {
                persistActiveSource()
            }
        } else if endedStoredQCMRestore {
            persistActiveSource()
        }
        if previousActiveSource != activeSource, activeSource == .kugou {
            scheduleKCMProfileRefreshIfActive()
        }
        profileRevision &+= 1
    }

    func refreshAvailableIdentities() async {
        var canReconcile = true
        if QQUserSession.shared.isLoggedIn || QQUserSession.shared.hasStoredCredentials {
            let result = await QQUserSession.shared.refresh()
            canReconcile = resolveStoredQCMIdentity(after: result)
        }
        await refreshKCMProfileCoalesced(
            for: KCMMusicService.shared.sessionSnapshot
        )
        if canReconcile {
            accountAvailabilityDidChange()
        }
    }

    func displayedProfile(ncmProfile: UserProfile?) -> UserProfile? {
        guard let activeSource, isLoggedIn(to: activeSource) else { return nil }

        switch activeSource {
        case .netease:
            let session = APIService.shared.ncmSessionSnapshot
            guard APIService.shared.isCurrentNCMSession(session),
                  let userID = session.userID,
                  ncmProfile?.userId == userID else { return nil }
            return ncmProfile
        case .qqmusic:
            guard let userID = QQUserSession.shared.musicId else { return nil }
            return UserProfile(
                userId: userID,
                nickname: nonempty(QQUserSession.shared.nickname) ?? "QCM",
                avatarUrl: QQUserSession.shared.avatarURL?.absoluteString,
                eventCount: nil,
                follows: nil,
                followeds: nil,
                signature: String(localized: "login_identity_qcm_profile"),
                vipType: QQUserSession.shared.isVIP ? 1 : 0
            )
        case .kugou:
            let service = KCMMusicService.shared
            let currentSession = service.sessionSnapshot
            guard currentSession.isAuthenticated,
                  let userID = currentSession.userID else {
                return nil
            }
            let currentProfile = kcmProfileSession == currentSession
                && kcmProfile?.userID == userID
                ? kcmProfile
                : nil
            return UserProfile(
                userId: userID,
                nickname: nonempty(currentProfile?.nickname) ?? "KCM",
                avatarUrl: currentProfile?.avatarURL?.absoluteString,
                eventCount: nil,
                follows: nil,
                followeds: nil,
                signature: String(localized: "login_identity_kcm_profile"),
                vipType: currentProfile?.isVIP == true ? 1 : 0
            )
        case .qishui, .appleMusic, .local:
            return nil
        }
    }

    private func accountAvailabilityDidChange() {
        if isRestoringStoredQCMIdentity {
            reconcileActiveSource(persistSelection: false)
        } else {
            reconcileActiveSource()
        }
        profileRevision &+= 1
    }

    private func resolveStoredQCMIdentity(
        after result: QQUserSession.RefreshResult
    ) -> Bool {
        guard isRestoringStoredQCMIdentity else { return true }
        switch result {
        case .authenticated:
            isRestoringStoredQCMIdentity = false
            _ = select(.qqmusic)
            return true
        case .unauthenticated:
            isRestoringStoredQCMIdentity = false
            return true
        case .unavailable:
            reconcileActiveSource(persistSelection: false)
            profileRevision &+= 1
            return false
        }
    }

    private func reconcileActiveSource(persistSelection: Bool = true) {
        let previousActiveSource = activeSource
        if let activeSource, isLoggedIn(to: activeSource) {
            if persistSelection {
                self.persistActiveSource()
            }
            return
        }

        activeSource = availableSources.first
        if persistSelection {
            persistActiveSource()
        }
        if previousActiveSource != activeSource, activeSource == .kugou {
            scheduleKCMProfileRefreshIfActive()
        }
    }

    private func persistActiveSource() {
        if let activeSource {
            UserDefaults.standard.set(
                activeSource.rawValue,
                forKey: AppConfig.StorageKeys.activeLoginIdentity
            )
        } else {
            UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.activeLoginIdentity)
        }
    }

    private func scheduleKCMProfileRefreshIfActive() {
        guard activeSource == .kugou else { return }
        let requestedSession = KCMMusicService.shared.sessionSnapshot
        guard requestedSession.isAuthenticated else { return }

        Task { [weak self] in
            guard let self, self.activeSource == .kugou else { return }
            await self.refreshKCMProfileCoalesced(for: requestedSession)
        }
    }

    private func refreshKCMProfileCoalesced(
        for requestedSession: KCMMusicService.SessionSnapshot
    ) async {
        let service = KCMMusicService.shared
        guard service.isCurrentSession(requestedSession),
              kcmProfileRefreshSessions.insert(requestedSession).inserted else { return }
        defer { kcmProfileRefreshSessions.remove(requestedSession) }
        await refreshKCMProfile(for: requestedSession)
    }

    private func refreshKCMProfile(
        for requestedSession: KCMMusicService.SessionSnapshot
    ) async {
        let service = KCMMusicService.shared
        guard service.isCurrentSession(requestedSession) else { return }
        invalidateKCMProfile(ifNotMatching: requestedSession)
        guard requestedSession.isAuthenticated,
              let requestedUserID = requestedSession.userID else {
            if kcmProfile != nil {
                kcmProfile = nil
                profileRevision &+= 1
            }
            return
        }

        do {
            guard let profile = try await service.fetchAccountProfile(
                ifCurrentSession: requestedSession
            ),
                  profile.userID == requestedUserID,
                  service.isCurrentSession(requestedSession) else { return }

            await service.synchronizeCurrentAccount(
                profile: profile,
                ifCurrentSession: requestedSession
            )

            guard service.isCurrentSession(requestedSession) else { return }

            kcmProfile = profile
            kcmProfileSession = requestedSession
            guard service.isCurrentSession(requestedSession) else {
                kcmProfile = nil
                kcmProfileSession = nil
                profileRevision &+= 1
                return
            }
            profileRevision &+= 1
        } catch is CancellationError {
            return
        } catch let error as KCMMusicError {
            switch error {
            case .sessionExpired(let failureContext):
                guard let failureContext else {
                    AppLogger.warning("[LoginIdentity] KCM 资料刷新失败: \(error.localizedDescription)")
                    return
                }
                guard service.logout(
                    ifCurrentCredentialContext: failureContext,
                    onLogout: { accountDidLogOut(.kugou) }
                ) else { return }
                AppLogger.warning("[LoginIdentity] KCM 会话已失效")
            case .authenticationRequired, .verificationRequired, .invalidResponse, .server, .unavailable:
                AppLogger.warning("[LoginIdentity] KCM 资料刷新失败: \(error.localizedDescription)")
            }
        } catch {
            AppLogger.warning("[LoginIdentity] KCM 资料刷新失败: \(error.localizedDescription)")
        }
    }

    private func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private func invalidateKCMProfile(
        ifNotMatching session: KCMMusicService.SessionSnapshot
    ) {
        guard kcmProfileSession != session
                || kcmProfile?.userID != session.userID else { return }
        guard kcmProfile != nil || kcmProfileSession != nil else { return }
        kcmProfile = nil
        kcmProfileSession = nil
        profileRevision &+= 1
    }
}
