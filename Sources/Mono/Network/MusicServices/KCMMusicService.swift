import Foundation

extension Notification.Name {
    static let kcmSessionDidChange = Notification.Name("KCMMusicServiceSessionDidChange")
}

actor KCMAuthenticationRefreshCoordinator {
    private var inFlight: [KCMMusicService.SessionCredentialContext: Task<Void, Error>] = [:]

    func run(
        for context: KCMMusicService.SessionCredentialContext,
        _ operation: @escaping @Sendable () async throws -> Void
    ) async throws {
        if let task = inFlight[context] {
            return try await task.value
        }

        let task = Task { try await operation() }
        inFlight[context] = task
        defer { inFlight[context] = nil }
        try await task.value
    }
}

final class KCMMusicService: @unchecked Sendable {
    static let shared = KCMMusicService()

    struct SessionSnapshot: Sendable, Hashable {
        let revision: UInt64
        let userID: Int?
        let isAuthenticated: Bool
    }

    struct SessionRequestContext: Sendable {
        let snapshot: SessionSnapshot
        let cookieHeader: String?
        let credentialRevision: UInt64

        var credentialContext: SessionCredentialContext {
            SessionCredentialContext(
                snapshot: snapshot,
                credentialRevision: credentialRevision
            )
        }
    }

    struct SessionCredentialContext: Sendable, Hashable {
        let snapshot: SessionSnapshot
        let credentialRevision: UInt64
    }

    struct LoginAttempt: Sendable, Equatable {
        let id: UUID
        let startingRevision: UInt64
    }

    let session: URLSession
    let cookieKey = "mono_kugou_cookie"
    let membershipLevelKey = "mono_kcm_membership_level"
    let membershipUserIDKey = "mono_kcm_membership_user_id"
    let authenticationRefreshCoordinator = KCMAuthenticationRefreshCoordinator()
    private let sessionStateLock = NSLock()
    private var storedSessionRevision: UInt64 = 0
    private var storedCredentialRevision: UInt64 = 0
    private var activeLoginAttemptID: UUID?

    init(session: URLSession? = nil) {
        let configuration = session?.configuration ?? URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        self.session = URLSession(
            configuration: configuration,
            delegate: session?.delegate,
            delegateQueue: session?.delegateQueue
        )
    }

    var baseURL: URL {
        URL(string: AppConfig.API.kugouBaseURL)!
    }

    var serviceEndpoints: [(line: ServerLine, url: URL)] {
        var lines = [ServerLineManager.currentLine]
        if !lines.contains(.primary) {
            lines.append(.primary)
        }
        if ServerLineManager.isFirstBackupConfigured, !lines.contains(.backup) {
            lines.append(.backup)
        }
        if ServerLineManager.isSecondBackupConfigured, !lines.contains(.backup2) {
            lines.append(.backup2)
        }
        return lines.compactMap { line in
            URL(string: SecureConfig.kugouBaseURL(for: line)).map { (line, $0) }
        }
    }

    var currentCookie: String? {
        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        return currentCookieLocked()
    }

    var sessionRevision: UInt64 {
        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        return storedSessionRevision
    }

    var sessionSnapshot: SessionSnapshot {
        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        return makeSessionSnapshotLocked()
    }

    var sessionCredentialContext: SessionCredentialContext {
        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        return SessionCredentialContext(
            snapshot: makeSessionSnapshotLocked(),
            credentialRevision: storedCredentialRevision
        )
    }

    func isCurrentSession(_ snapshot: SessionSnapshot) -> Bool {
        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        return makeSessionSnapshotLocked() == snapshot
    }

    func isCurrentRequestContext(_ context: SessionRequestContext) -> Bool {
        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        return makeSessionSnapshotLocked() == context.snapshot
            && storedCredentialRevision == context.credentialRevision
            && currentCookieLocked() == context.cookieHeader
    }

    func isCurrentCredentialContext(_ context: SessionCredentialContext) -> Bool {
        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        return makeSessionSnapshotLocked() == context.snapshot
            && storedCredentialRevision == context.credentialRevision
    }

    func sessionRequestContext(
        ifCurrent expectedSession: SessionSnapshot? = nil
    ) -> SessionRequestContext? {
        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        let snapshot = makeSessionSnapshotLocked()
        if let expectedSession, snapshot != expectedSession {
            return nil
        }
        return SessionRequestContext(
            snapshot: snapshot,
            cookieHeader: currentCookieLocked(),
            credentialRevision: storedCredentialRevision
        )
    }

    func cookieHeader(ifCurrent expectedSession: SessionSnapshot) -> String? {
        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        guard makeSessionSnapshotLocked() == expectedSession else { return nil }
        return currentCookieLocked()
    }

    func beginLoginAttempt() -> LoginAttempt {
        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        let attempt = LoginAttempt(id: UUID(), startingRevision: storedSessionRevision)
        activeLoginAttemptID = attempt.id
        return attempt
    }

    func cancelLoginAttempt(_ attempt: LoginAttempt) {
        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        if activeLoginAttemptID == attempt.id {
            activeLoginAttemptID = nil
        }
    }

    func isCurrentLoginAttempt(_ attempt: LoginAttempt) -> Bool {
        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        return activeLoginAttemptID == attempt.id
            && storedSessionRevision == attempt.startingRevision
    }

    private func currentCookieLocked() -> String? {
        let value = KeychainHelper.loadString(key: cookieKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    private func makeSessionSnapshotLocked() -> SessionSnapshot {
        let values = currentCookieLocked().map(Self.cookieValues(in:)) ?? [:]
        let userID = values["userid"].flatMap(Int.init)
        return SessionSnapshot(
            revision: storedSessionRevision,
            userID: userID,
            isAuthenticated: values["token"]?.isEmpty == false && userID != nil && userID != 0
        )
    }

    var isAuthenticated: Bool {
        sessionSnapshot.isAuthenticated
    }

    var currentUserID: Int? {
        sessionSnapshot.userID
    }

    var currentMembershipLevel: KCMMembershipLevel? {
        guard let userID = currentUserID,
              UserDefaults.standard.integer(forKey: membershipUserIDKey) == userID,
              let rawValue = UserDefaults.standard.string(forKey: membershipLevelKey) else {
            return nil
        }
        return KCMMembershipLevel(rawValue: rawValue)
    }

    @discardableResult
    func cacheMembershipLevel(
        _ level: KCMMembershipLevel,
        userID: Int,
        ifCurrentSession expectedSession: SessionSnapshot
    ) -> Bool {
        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        guard makeSessionSnapshotLocked() == expectedSession,
              expectedSession.userID == userID else { return false }
        UserDefaults.standard.set(level.rawValue, forKey: membershipLevelKey)
        UserDefaults.standard.set(userID, forKey: membershipUserIDKey)
        return true
    }

    func applyCookie(_ cookie: String) {
        _ = applyCookie(cookie, expectedSession: nil)
    }

    func applyCookie(
        _ cookie: String,
        forLoginAttempt attempt: LoginAttempt
    ) -> SessionSnapshot? {
        guard let normalized = normalizedCookie(cookie) else { return nil }
        let nextCookieValues = Self.cookieValues(in: normalized)

        sessionStateLock.lock()
        guard activeLoginAttemptID == attempt.id,
              storedSessionRevision == attempt.startingRevision else {
            sessionStateLock.unlock()
            return nil
        }

        guard Self.isAuthenticatedCookieValues(nextCookieValues) else {
            sessionStateLock.unlock()
            return nil
        }
        let didChangeSession = applyCookieLocked(
            normalized,
            values: nextCookieValues,
            advancesRevision: true,
            forceRevisionAdvance: true
        )
        activeLoginAttemptID = nil
        let snapshot = makeSessionSnapshotLocked()
        sessionStateLock.unlock()
        if didChangeSession {
            postSessionDidChange()
        }
        return snapshot
    }

    @discardableResult
    func applyCookie(_ cookie: String, ifCurrentSession expectedSession: SessionSnapshot) -> Bool {
        updateCookie(cookie, ifCurrentSession: expectedSession) != nil
    }

    func updateCookie(
        _ cookie: String,
        ifCurrentSession expectedSession: SessionSnapshot
    ) -> SessionSnapshot? {
        guard let normalized = normalizedCookie(cookie) else { return nil }
        let nextCookieValues = Self.cookieValues(in: normalized)

        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        guard makeSessionSnapshotLocked() == expectedSession,
              Self.isAuthenticatedCookieValues(nextCookieValues),
              nextCookieValues["userid"].flatMap(Int.init) == expectedSession.userID else {
            return nil
        }
        applyCookieLocked(
            normalized,
            values: nextCookieValues,
            advancesRevision: false,
            forceRevisionAdvance: false
        )
        return makeSessionSnapshotLocked()
    }

    func updateCookie(
        _ cookie: String,
        ifCurrentRequestContext context: SessionRequestContext
    ) -> SessionSnapshot? {
        guard let normalized = normalizedCookie(cookie) else { return nil }
        let nextCookieValues = Self.cookieValues(in: normalized)

        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        guard makeSessionSnapshotLocked() == context.snapshot,
              storedCredentialRevision == context.credentialRevision,
              currentCookieLocked() == context.cookieHeader,
              Self.isAuthenticatedCookieValues(nextCookieValues),
              nextCookieValues["userid"].flatMap(Int.init) == context.snapshot.userID else {
            return nil
        }
        applyCookieLocked(
            normalized,
            values: nextCookieValues,
            advancesRevision: false,
            forceRevisionAdvance: false
        )
        return makeSessionSnapshotLocked()
    }

    private func applyCookie(
        _ cookie: String,
        expectedSession: SessionSnapshot?
    ) -> Bool {
        guard let normalized = normalizedCookie(cookie) else {
            if let expectedSession {
                return clearSession(
                    ifSessionRevision: expectedSession.revision,
                    userID: expectedSession.userID
                )
            }
            logout()
            return true
        }

        let nextCookieValues = Self.cookieValues(in: normalized)

        sessionStateLock.lock()
        if let expectedSession,
           makeSessionSnapshotLocked() != expectedSession {
            sessionStateLock.unlock()
            return false
        }
        let didChangeSession = applyCookieLocked(
            normalized,
            values: nextCookieValues,
            advancesRevision: true,
            forceRevisionAdvance: false
        )
        sessionStateLock.unlock()
        if didChangeSession {
            postSessionDidChange()
        }
        return true
    }

    private func normalizedCookie(_ cookie: String) -> String? {
        let ignoredAttributes = Set(["path", "domain", "expires", "max-age", "samesite", "secure", "httponly"])
        let normalized = cookie
            .replacingOccurrences(of: "Set-Cookie:", with: "", options: .caseInsensitive)
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { component in
                guard !component.isEmpty else { return false }
                let name = component.split(separator: "=", maxSplits: 1).first?.lowercased() ?? ""
                return !ignoredAttributes.contains(name)
            }
            .joined(separator: "; ")
        return normalized.isEmpty ? nil : normalized
    }

    private static func isAuthenticatedCookieValues(_ values: [String: String]) -> Bool {
        values["token"]?.isEmpty == false
            && values["userid"].flatMap(Int.init).map { $0 != 0 } == true
    }

    @discardableResult
    private func applyCookieLocked(
        _ normalized: String,
        values nextCookieValues: [String: String],
        advancesRevision: Bool,
        forceRevisionAdvance: Bool
    ) -> Bool {
        let nextUserID = nextCookieValues["userid"].flatMap(Int.init)
        let previousCookieValues = currentCookieLocked().map(Self.cookieValues(in:)) ?? [:]
        let previousUserID = previousCookieValues["userid"].flatMap(Int.init)
        if previousCookieValues != nextCookieValues {
            storedCredentialRevision &+= 1
        }
        let didChangeSession = advancesRevision
            && (forceRevisionAdvance || previousCookieValues != nextCookieValues)
        if didChangeSession {
            storedSessionRevision &+= 1
            activeLoginAttemptID = nil
        }
        if previousUserID != nextUserID {
            clearMembershipCache()
        }
        KeychainHelper.save(key: cookieKey, value: normalized)
        return didChangeSession
    }

    func logout() {
        _ = clearSession(ifSessionRevision: nil, userID: nil)
    }

    func logout(onLogout: () -> Void) {
        sessionStateLock.lock()
        clearSessionLocked()
        onLogout()
        sessionStateLock.unlock()
        postSessionDidChange()
    }

    @discardableResult
    func logout(ifSessionRevision expectedRevision: UInt64, userID expectedUserID: Int) -> Bool {
        clearSession(ifSessionRevision: expectedRevision, userID: expectedUserID)
    }

    @discardableResult
    func logout(
        ifCurrentCredentialContext context: SessionCredentialContext,
        onLogout: () -> Void
    ) -> Bool {
        sessionStateLock.lock()
        guard makeSessionSnapshotLocked() == context.snapshot,
              storedCredentialRevision == context.credentialRevision else {
            sessionStateLock.unlock()
            return false
        }
        clearSessionLocked()
        sessionStateLock.unlock()
        onLogout()
        postSessionDidChange()
        return true
    }

    @discardableResult
    func logout(
        ifSessionRevision expectedRevision: UInt64,
        userID expectedUserID: Int,
        onLogout: () -> Void
    ) -> Bool {
        sessionStateLock.lock()
        let snapshot = makeSessionSnapshotLocked()
        guard snapshot.revision == expectedRevision,
              snapshot.userID == expectedUserID else {
            sessionStateLock.unlock()
            return false
        }
        clearSessionLocked()
        onLogout()
        sessionStateLock.unlock()
        postSessionDidChange()
        return true
    }

    private func clearSession(
        ifSessionRevision expectedRevision: UInt64?,
        userID expectedUserID: Int?
    ) -> Bool {
        sessionStateLock.lock()

        let snapshot = makeSessionSnapshotLocked()
        if let expectedRevision, snapshot.revision != expectedRevision {
            sessionStateLock.unlock()
            return false
        }
        if let expectedUserID, snapshot.userID != expectedUserID {
            sessionStateLock.unlock()
            return false
        }

        clearSessionLocked()
        sessionStateLock.unlock()
        postSessionDidChange()
        return true
    }

    private func clearSessionLocked() {
        storedSessionRevision &+= 1
        storedCredentialRevision &+= 1
        activeLoginAttemptID = nil
        KeychainHelper.delete(key: cookieKey)
        clearMembershipCache()
    }

    private func postSessionDidChange() {
        NotificationCenter.default.post(name: .kcmSessionDidChange, object: self)
    }


    static let kcmQualityOrder: [SoundQuality] = [
        .multitrack, .jymaster, .sky, .jyeffect,
        .hires, .lossless, .exhigh, .standard,
    ]
}
