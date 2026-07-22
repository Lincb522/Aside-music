import CryptoKit
@preconcurrency import Combine
import Foundation

@MainActor
final class MonoSessionManager: ObservableObject {
    static let shared = MonoSessionManager()

    @Published private(set) var connectionState: MonoSessionConnectionState = .disconnected
    @Published private(set) var room: MonoSessionRoom?
    @Published private(set) var role: MonoSessionRole?
    @Published private(set) var lastRoundTripTime: TimeInterval?
    @Published private(set) var chatMessages: [MonoSessionChatMessage] = []
    @Published private(set) var chatErrorText: String?
    @Published private(set) var controlErrorText: String?
    @Published private(set) var sharedQueue: [Song] = []
    @Published private(set) var pendingTrackRequest: Song?
    @Published private(set) var isPlaybackControlPending = false
    @Published private(set) var pendingSeekPosition: Double?

    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var isApplyingRemotePlayback = false
    private var lastHostBroadcastAt = Date.distantPast
    private var lastHostSignature = ""
    private var lastQueueSignature = ""
    private var pendingHeartbeat: [UUID: Date] = [:]
    private var reconnectAttempt = 0
    private var remotePlaybackSuppressionUntil = Date.distantPast
    private var playbackConvergenceTarget: MonoSessionPlaybackState?
    private var playbackConvergenceDeadline = Date.distantPast
    private var intendedInviteCode: String?
    private var intendedRoomID: String?
    private var intendedRole: MonoSessionRole?

    private init() {
        observePlayback()
    }

    func createRoom(displayName: String? = nil) async {
        guard MonoNextSuiteManager.shared.isEnabled(.session) else { return }
        intendedRole = .host
        do {
            try await connectIfNeeded()
            role = .host
            let participant = makeLocalParticipant(role: .host, displayName: displayName)
            try await send(
                MonoSessionWireMessage(
                    command: .create,
                    requestID: UUID(),
                    participant: participant,
                    playback: currentPlaybackState(sequence: 0),
                    queue: currentQueueState(revision: 0),
                    permissions: .hostOnly,
                    sentAt: Date()
                )
            )
        } catch {
            fail(error)
        }
    }

    func joinRoom(inviteCode: String, displayName: String? = nil) async {
        guard MonoNextSuiteManager.shared.isEnabled(.session) else { return }
        let normalizedCode = inviteCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalizedCode.isEmpty else { return }
        intendedInviteCode = normalizedCode
        intendedRole = .listener
        do {
            try await connectIfNeeded()
            role = .listener
            try await send(
                MonoSessionWireMessage(
                    command: .join,
                    requestID: UUID(),
                    inviteCode: normalizedCode,
                    participant: makeLocalParticipant(role: .listener, displayName: displayName),
                    sentAt: Date()
                )
            )
        } catch {
            fail(error)
        }
    }

    func leaveRoom() {
        if let roomID = room?.id {
            let message = MonoSessionWireMessage(
                command: .leave,
                requestID: UUID(),
                roomID: roomID,
                sentAt: Date()
            )
            Task { [weak self] in try? await self?.send(message) }
        }
        disconnect(clearIntent: true)
    }

    func broadcastHostPlaybackImmediately() {
        guard role == .host, room != nil, !isApplyingRemotePlayback else { return }
        Task { [weak self] in
            await self?.broadcastHostPlayback(force: true)
        }
    }

    @discardableResult
    func sendChat(_ text: String) async -> Bool {
        let normalized = MonoSessionChatPolicy.normalized(text)
        guard !normalized.isEmpty, let room else { return false }

        if let violation = MonoSessionChatPolicy.violation(in: normalized) {
            chatErrorText = chatPolicyErrorText(violation)
            return false
        }

        chatErrorText = nil
        let participant = room.participants.first { $0.id == DeviceIdentifier.uuid }
            ?? makeLocalParticipant(role: role ?? .listener, displayName: nil)
        do {
            try await send(
                MonoSessionWireMessage(
                    command: .chat,
                    requestID: UUID(),
                    roomID: room.id,
                    chat: MonoSessionChatMessage(
                        id: UUID(),
                        senderID: participant.id,
                        senderName: participant.displayName,
                        senderAvatarURL: participant.avatarURL,
                        text: normalized,
                        sentAt: Date()
                    ),
                    sentAt: Date()
                )
            )
            return true
        } catch {
            handleSocketFailure(error)
            return false
        }
    }

    func addSongToQueue(_ song: Song) {
        guard room != nil else { return }
        var queue = sharedQueue
        guard !queue.contains(where: { sameSong($0, song) }) else { return }
        queue.append(song)
        submitQueue(queue)
    }

    func removeSongFromQueue(_ song: Song) {
        guard role == .host,
              !sameSong(PlayerManager.shared.currentSong, song) else { return }
        submitQueue(sharedQueue.filter { !sameSong($0, song) })
    }

    func playSongFromQueue(_ song: Song) {
        guard canControlPlayback else {
            controlErrorText = String(localized: "mono_session_track_control_disabled")
            return
        }
        if role != .host {
            requestTrackChange(song)
            return
        }
        var queue = sharedQueue
        if !queue.contains(where: { sameSong($0, song) }) {
            queue.append(song)
            submitQueue(queue)
        }
        submitHostTrackIntent(song, queue: queue)
        PlayerManager.shared.playReplacingContext(song: song, in: queue)
    }

    var membersCanControlPlayback: Bool {
        room?.permissions?.membersCanControlPlayback ?? false
    }

    var canControlPlayback: Bool {
        role == .host || membersCanControlPlayback
    }

    func setMembersCanControlPlayback(_ enabled: Bool) {
        guard role == .host, var room else { return }
        let permissions = MonoSessionPermissions(membersCanControlPlayback: enabled)
        room.permissions = permissions
        self.room = room
        controlErrorText = nil
        let roomID = room.id
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.send(
                    MonoSessionWireMessage(
                        command: .permissions,
                        requestID: UUID(),
                        roomID: roomID,
                        permissions: permissions,
                        sentAt: Date()
                    )
                )
            } catch {
                self.handleSocketFailure(error)
            }
        }
    }

    func changeTrack(by offset: Int) {
        guard canControlPlayback, !sharedQueue.isEmpty else {
            if !canControlPlayback {
                controlErrorText = String(localized: "mono_session_track_control_disabled")
            }
            return
        }
        if role == .host {
            let reference = playbackConvergenceTarget?.song
                ?? PlayerManager.shared.currentSong
                ?? room?.playback.song
            let currentIndex = reference.flatMap { target in
                sharedQueue.firstIndex { sameSong($0, target) }
            } ?? 0
            let targetIndex = min(sharedQueue.count - 1, max(0, currentIndex + offset))
            guard targetIndex != currentIndex else { return }
            playSongFromQueue(sharedQueue[targetIndex])
            return
        }

        let reference = pendingTrackRequest ?? PlayerManager.shared.currentSong
        let currentIndex = reference.flatMap { target in
            sharedQueue.firstIndex { sameSong($0, target) }
        } ?? 0
        let targetIndex = min(sharedQueue.count - 1, max(0, currentIndex + offset))
        guard targetIndex != currentIndex else { return }
        requestTrackChange(sharedQueue[targetIndex])
    }

    func toggleRoomPlayback() {
        guard canControlPlayback else {
            controlErrorText = String(localized: "mono_session_track_control_disabled")
            return
        }
        if role == .host {
            PlayerManager.shared.togglePlayPause()
            broadcastHostPlaybackImmediately()
            return
        }
        requestPlaybackControl(
            position: max(0, PlayerManager.shared.currentTime),
            isPlaying: !PlayerManager.shared.isPlaying,
            isSeekRequest: false
        )
    }

    func seekRoom(to position: Double) {
        guard canControlPlayback else {
            controlErrorText = String(localized: "mono_session_track_control_disabled")
            return
        }
        let target = min(max(0, position), max(PlayerManager.shared.duration, 0))
        if role == .host {
            PlayerManager.shared.seek(to: target)
            broadcastHostPlaybackImmediately()
            return
        }
        requestPlaybackControl(
            position: target,
            isPlaying: PlayerManager.shared.isPlaying,
            isSeekRequest: true
        )
    }

    private func requestTrackChange(_ song: Song) {
        guard role != .host, membersCanControlPlayback, let room else { return }
        pendingTrackRequest = song
        controlErrorText = nil
        let state = MonoSessionPlaybackState(
            sequence: room.playback.sequence + 1,
            song: song,
            position: 0,
            isPlaying: true,
            hostTimestamp: Date(),
            queueRevision: queueRevision()
        )
        let roomID = room.id
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.send(
                    MonoSessionWireMessage(
                        command: .track,
                        requestID: UUID(),
                        roomID: roomID,
                        playback: state,
                        sentAt: Date()
                    )
                )
            } catch {
                self.pendingTrackRequest = nil
                self.handleSocketFailure(error)
            }
        }
    }

    private func submitHostTrackIntent(_ song: Song, queue: [Song]) {
        guard role == .host, let room else { return }
        let state = MonoSessionPlaybackState(
            sequence: room.playback.sequence + 1,
            song: song,
            position: 0,
            isPlaying: true,
            hostTimestamp: Date(),
            queueRevision: queueRevision()
        )
        beginPlaybackConvergence(to: state)
        var updatedRoom = room
        updatedRoom.playback = state
        self.room = updatedRoom
        lastHostSignature = playbackSignature(state)
        lastHostBroadcastAt = Date()
        let roomID = room.id
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.send(
                    MonoSessionWireMessage(
                        command: .playback,
                        requestID: UUID(),
                        roomID: roomID,
                        playback: state,
                        queue: MonoSessionQueueState(
                            revision: room.queue?.revision ?? 0,
                            songs: self.normalizedQueue(queue),
                            updatedAt: Date()
                        ),
                        sentAt: Date()
                    )
                )
            } catch {
                self.handleSocketFailure(error)
            }
        }
    }

    private func requestPlaybackControl(
        position: Double,
        isPlaying: Bool,
        isSeekRequest: Bool
    ) {
        guard role != .host,
              membersCanControlPlayback,
              let room,
              let song = PlayerManager.shared.currentSong else { return }
        isPlaybackControlPending = true
        pendingSeekPosition = isSeekRequest ? position : nil
        controlErrorText = nil
        let state = MonoSessionPlaybackState(
            sequence: room.playback.sequence + 1,
            song: song,
            position: position,
            isPlaying: isPlaying,
            hostTimestamp: Date(),
            queueRevision: queueRevision()
        )
        let roomID = room.id
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.send(
                    MonoSessionWireMessage(
                        command: .playback,
                        requestID: UUID(),
                        roomID: roomID,
                        playback: state,
                        sentAt: Date()
                    )
                )
            } catch {
                self.isPlaybackControlPending = false
                self.pendingSeekPosition = nil
                self.handleSocketFailure(error)
            }
        }
    }

    private func connectIfNeeded() async throws {
        if socket != nil { return }
        guard let request = makeWebSocketRequest() else {
            throw URLError(.badURL)
        }
        connectionState = .connecting
        let task = URLSession.shared.webSocketTask(with: request)
        socket = task
        task.resume()
        connectionState = .connected
        startReceiveLoop(task)
        startHeartbeat()
    }

    private func makeWebSocketRequest() -> URLRequest? {
        guard var components = URLComponents(string: SecureConfig.officialWebsiteBaseURL) else { return nil }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        let path = "/api/mono-session"
        components.path = components.path.hasSuffix("/")
            ? "\(components.path)\(path.dropFirst())"
            : "\(components.path)\(path)"
        components.queryItems = [
            URLQueryItem(name: "deviceId", value: DeviceIdentifier.uuid)
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        if let token = SecureConfig.apiToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func startReceiveLoop(_ task: URLSessionWebSocketTask) {
        receiveTask?.cancel()
        receiveTask = Task { [weak self, weak task] in
            guard let self, let task else { return }
            do {
                while !Task.isCancelled {
                    let message = try await task.receive()
                    let data: Data
                    switch message {
                    case .data(let value): data = value
                    case .string(let value): data = Data(value.utf8)
                    @unknown default: continue
                    }
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let payload = try decoder.decode(MonoSessionWireMessage.self, from: data)
                    handle(payload)
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                handleSocketFailure(error)
            }
        }
    }

    private func handle(_ message: MonoSessionWireMessage) {
        switch message.command {
        case .room:
            if let room = message.room {
                var normalizedRoom = room
                normalizedRoom.permissions = message.permissions
                    ?? room.permissions
                    ?? .hostOnly
                self.room = normalizedRoom
                chatMessages = (message.messages ?? []).map(sanitizedIncomingChat)
                applyQueue(message.queue ?? room.queue, toPlayer: true)
                connectionState = .inRoom
                reconnectAttempt = 0
                intendedInviteCode = room.inviteCode
                intendedRoomID = room.id
                intendedRole = role
                if room.playback.song != nil {
                    applyRemotePlayback(room.playback)
                }
            }
        case .playback:
            if let permissions = message.permissions, var room {
                room.permissions = permissions
                self.room = room
            }
            guard let playback = message.playback else { return }
            if let currentSequence = room?.playback.sequence,
               playback.sequence < currentSequence {
                return
            }
            if var room {
                room.playback = playback
                self.room = room
            }
            if let queue = message.queue {
                applyQueue(queue, toPlayer: true)
            }
            if let targetSong = playback.song,
               !sameSong(PlayerManager.shared.currentSong, targetSong) {
                pendingTrackRequest = targetSong
            }
            isPlaybackControlPending = false
            pendingSeekPosition = nil
            controlErrorText = nil
            applyRemotePlayback(playback)
        case .participants:
            guard let participants = message.participants, var room else { return }
            room.participants = participants
            if let permissions = message.permissions {
                room.permissions = permissions
            }
            self.room = room
        case .chat:
            guard let chat = message.chat,
                  message.roomID == room?.id,
                  !chatMessages.contains(where: { $0.id == chat.id }) else { return }
            chatErrorText = nil
            chatMessages.append(sanitizedIncomingChat(chat))
            if chatMessages.count > 200 {
                chatMessages.removeFirst(chatMessages.count - 200)
            }
        case .heartbeat:
            if let started = pendingHeartbeat.removeValue(forKey: message.requestID) {
                lastRoundTripTime = Date().timeIntervalSince(started)
            }
            if let permissions = message.permissions, var room {
                room.permissions = permissions
                self.room = room
            }
            if let queue = message.queue,
               queue.revision >= (room?.queue?.revision ?? -1) {
                applyQueue(queue, toPlayer: true)
            }
            if let playback = message.playback {
                let localSequence = room?.playback.sequence ?? -1
                let shouldApply = role == .host
                    ? playback.sequence > localSequence
                    : playback.sequence >= localSequence
                guard shouldApply else { return }
                if var room {
                    room.playback = playback
                    self.room = room
                }
                applyRemotePlayback(playback)
            }
        case .error:
            if let chatError = chatServerErrorText(
                code: message.errorCode,
                detail: message.errorMessage
            ) {
                chatErrorText = chatError
                return
            }
            if message.errorCode == "track_control_disabled"
                || message.errorCode == "playback_control_disabled"
                || message.errorCode == "invalid_track"
                || (message.errorCode == "unknown_command"
                    && (pendingTrackRequest != nil || isPlaybackControlPending)) {
                pendingTrackRequest = nil
                isPlaybackControlPending = false
                pendingSeekPosition = nil
                controlErrorText = message.errorCode == "track_control_disabled"
                    || message.errorCode == "playback_control_disabled"
                    ? String(localized: "mono_session_track_control_disabled")
                    : (message.errorCode == "invalid_track"
                        ? String(localized: "mono_session_track_change_failed")
                        : String(localized: "mono_session_playback_control_failed"))
                return
            }
            let text = sessionErrorText(code: message.errorCode)
            if message.errorCode == "room_ended" || message.errorCode == "resume_rejected" {
                disconnect(clearIntent: true)
            }
            connectionState = .failed(text)
        case .queue:
            if let queue = message.queue {
                applyQueue(queue, toPlayer: true)
            }
        case .permissions:
            if let permissions = message.permissions, var room {
                room.permissions = permissions
                self.room = room
            }
        case .track:
            break
        case .create, .join, .resume, .leave:
            break
        }
    }

    private func applyRemotePlayback(_ playback: MonoSessionPlaybackState) {
        guard room != nil else { return }
        let player = PlayerManager.shared
        let projectedPosition = playback.isPlaying
            ? playback.position + max(0, Date().timeIntervalSince(playback.hostTimestamp))
            : playback.position
        let targetDuration = playback.song?.dt.map { Double($0) / 1_000 }
            ?? (player.duration > 0 ? player.duration : nil)
        let targetPosition = min(
            max(0, projectedPosition),
            targetDuration.map { max(0, $0 - 0.15) } ?? .greatestFiniteMagnitude
        )
        isApplyingRemotePlayback = true
        remotePlaybackSuppressionUntil = Date().addingTimeInterval(2.2)
        beginPlaybackConvergence(to: playback)
        defer {
            DispatchQueue.main.async { [weak self] in
                self?.isApplyingRemotePlayback = false
            }
        }

        if let targetSong = playback.song,
           !sameSong(player.currentSong, targetSong) {
            player.loadAndPlay(
                song: targetSong,
                autoPlay: playback.isPlaying,
                startTime: max(0, targetPosition),
                fadeInDuration: playback.isPlaying ? 0.55 : nil,
                fadeInReason: "Mono Session remote track"
            )
            return
        }

        let drift = abs(player.currentTime - targetPosition)
        let tolerance = max(0.85, min(1.8, (lastRoundTripTime ?? 0.2) * 1.5))
        if drift > tolerance, !player.isLoading {
            player.seek(to: targetPosition)
        }
        if playback.isPlaying, !player.isPlaying {
            _ = player.playPlayback()
        } else if !playback.isPlaying, player.isPlaying || player.isLoading {
            player.pausePlayback()
        }
    }

    private func observePlayback() {
        let player = PlayerManager.shared
        Publishers.CombineLatest3(
            player.$currentSong,
            player.$isPlaying.removeDuplicates(),
            player.$isLoading.removeDuplicates()
        )
        .sink { [weak self] currentSong, _, isLoading in
            guard let self else { return }
            if let pendingTrackRequest = self.pendingTrackRequest,
               self.sameSong(currentSong, pendingTrackRequest),
               !isLoading {
                self.pendingTrackRequest = nil
            }
            guard
                  self.role == .host,
                  !self.isApplyingRemotePlayback,
                  Date() >= self.remotePlaybackSuppressionUntil else { return }
            Task { [weak self] in await self?.broadcastHostPlayback(force: true) }
        }
        .store(in: &cancellables)

        PlaybackTimePublisher.shared.$currentTime
            .sink { [weak self] _ in
                guard let self,
                      self.role == .host,
                      !self.isApplyingRemotePlayback,
                      Date() >= self.remotePlaybackSuppressionUntil else { return }
                Task { [weak self] in await self?.broadcastHostPlayback(force: false) }
            }
            .store(in: &cancellables)
    }

    private func broadcastHostPlayback(force: Bool) async {
        guard role == .host, let room else { return }
        guard !shouldSuppressHostBroadcastForConvergence() else { return }
        let now = Date()
        let state = currentPlaybackState(sequence: room.playback.sequence + 1)
        let signature = playbackSignature(state)
        guard force
                || signature != lastHostSignature
                || now.timeIntervalSince(lastHostBroadcastAt) >= 1 else { return }
        lastHostSignature = signature
        lastHostBroadcastAt = now
        var updatedRoom = room
        updatedRoom.playback = state
        self.room = updatedRoom
        do {
            try await send(
                MonoSessionWireMessage(
                    command: .playback,
                    requestID: UUID(),
                    roomID: room.id,
                    playback: state,
                    sentAt: now
                )
            )
        } catch {
            handleSocketFailure(error)
        }
    }

    private func currentPlaybackState(sequence: Int64) -> MonoSessionPlaybackState {
        let player = PlayerManager.shared
        return MonoSessionPlaybackState(
            sequence: sequence,
            song: player.currentSong,
            position: max(0, player.currentTime),
            isPlaying: player.isPlaying && !player.isLoading,
            hostTimestamp: Date(),
            queueRevision: queueRevision()
        )
    }

    private func currentQueueState(revision: Int64) -> MonoSessionQueueState {
        let source = sharedQueue.isEmpty
            ? PlayerManager.shared.currentContextList
            : sharedQueue
        return MonoSessionQueueState(
            revision: revision,
            songs: normalizedQueue(source),
            updatedAt: Date()
        )
    }

    private func submitQueue(_ songs: [Song]) {
        guard var room else { return }
        let normalized = normalizedQueue(songs)
        let signature = queueSignature(normalized)
        guard signature != lastQueueSignature else { return }
        lastQueueSignature = signature
        let nextRevision = (room.queue?.revision ?? 0) + 1
        let state = MonoSessionQueueState(
            revision: nextRevision,
            songs: normalized,
            updatedAt: Date()
        )
        room.queue = state
        self.room = room
        sharedQueue = normalized
        if role == .host {
            PlayerManager.shared.replaceMonoSessionQueue(with: normalized)
        }
        let roomID = room.id
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.send(
                    MonoSessionWireMessage(
                        command: .queue,
                        requestID: UUID(),
                        roomID: roomID,
                        queue: state,
                        sentAt: Date()
                    )
                )
            } catch {
                self.handleSocketFailure(error)
            }
        }
    }

    private func applyQueue(_ state: MonoSessionQueueState?, toPlayer: Bool) {
        guard let state else {
            if sharedQueue.isEmpty, let song = room?.playback.song {
                sharedQueue = [song]
            }
            return
        }
        let normalized = normalizedQueue(state.songs)
        sharedQueue = normalized
        lastQueueSignature = queueSignature(normalized)
        if var room {
            room.queue = MonoSessionQueueState(
                revision: state.revision,
                songs: normalized,
                updatedAt: state.updatedAt
            )
            self.room = room
        }
        if toPlayer, !normalized.isEmpty {
            PlayerManager.shared.replaceMonoSessionQueue(
                with: normalized,
                preferredCurrentSong: room?.playback.song
            )
        }
    }

    private func normalizedQueue(_ songs: [Song]) -> [Song] {
        var identities = Set<String>()
        return songs.prefix(100).filter { song in
            identities.insert("\(song.musicSource.rawValue):\(song.id)").inserted
        }
    }

    private func queueSignature(_ songs: [Song]) -> String {
        songs.map { "\($0.musicSource.rawValue):\($0.id)" }.joined(separator: "|")
    }

    private func playbackSignature(_ state: MonoSessionPlaybackState) -> String {
        let songIdentity = state.song.map {
            "\($0.musicSource.rawValue):\($0.id)"
        } ?? "none"
        return "\(songIdentity)#\(state.isPlaying ? 1 : 0)#\(state.queueRevision)"
    }

    private func beginPlaybackConvergence(to state: MonoSessionPlaybackState) {
        playbackConvergenceTarget = state
        playbackConvergenceDeadline = Date().addingTimeInterval(20)
    }

    private func shouldSuppressHostBroadcastForConvergence() -> Bool {
        guard let target = playbackConvergenceTarget else { return false }
        if Date() >= playbackConvergenceDeadline {
            // The room state remains authoritative if this device has not
            // converged. Never let an old local song overwrite the room merely
            // because loading/retry took longer than the usual window.
            playbackConvergenceDeadline = Date().addingTimeInterval(20)
            AppLogger.warning(
                "[MonoSession] Local playback has not converged to room state",
                step: "mono-session.playback-convergence-wait"
            )
            return true
        }

        let player = PlayerManager.shared
        let songMatches = target.song.map { sameSong(player.currentSong, $0) }
            ?? (player.currentSong == nil)
        let stateMatches = !player.isLoading
            && (target.isPlaying ? player.isPlaying : !player.isPlaying)
        guard songMatches, stateMatches else { return true }

        playbackConvergenceTarget = nil
        playbackConvergenceDeadline = .distantPast
        remotePlaybackSuppressionUntil = Date().addingTimeInterval(0.6)
        return true
    }

    private func queueRevision() -> String {
        let player = PlayerManager.shared
        let queue = sharedQueue.isEmpty ? player.currentContextList : sharedQueue
        let source = queue.map {
            "\($0.musicSource.rawValue):\($0.id)"
        }.joined(separator: "|") + "#\(player.contextIndex)"
        return SHA256.hash(data: Data(source.utf8)).prefix(8)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func makeLocalParticipant(
        role: MonoSessionRole,
        displayName: String?
    ) -> MonoSessionParticipant {
        let profile = HomeViewModel.shared.userProfile
            ?? OptimizedCacheManager.shared.getObject(
                forKey: AppConfig.CacheKeys.userProfile,
                type: UserProfile.self
            )
        let resolvedName = (displayName ?? profile?.nickname)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = resolvedName.flatMap { name -> String? in
            guard !name.isEmpty,
                  name.count <= 40,
                  MonoSessionChatPolicy.violation(in: name) == nil else { return nil }
            return name
        }
        let anonymousSuffix = DeviceIdentifier.uuid
            .replacingOccurrences(of: "-", with: "")
            .suffix(4)
            .uppercased()
        return MonoSessionParticipant(
            id: DeviceIdentifier.uuid,
            displayName: safeName ?? "Mono \(anonymousSuffix)",
            avatarURL: normalizedNeteaseAvatarURL(profile?.avatarUrl),
            role: role,
            joinedAt: Date(),
            isReady: true
        )
    }

    private func normalizedNeteaseAvatarURL(_ rawValue: String?) -> String? {
        guard let rawValue,
              let components = URLComponents(string: rawValue),
              components.scheme == "https" || components.scheme == "http",
              components.host != nil else { return nil }
        return String(rawValue.prefix(2_048))
    }

    private func send(_ message: MonoSessionWireMessage) async throws {
        guard let socket else { throw URLError(.notConnectedToInternet) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)
        try await socket.send(.data(data))
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(12)) } catch { return }
                guard let self, self.socket != nil else { return }
                let requestID = UUID()
                self.pendingHeartbeat[requestID] = Date()
                do {
                    try await self.send(
                        MonoSessionWireMessage(
                            command: .heartbeat,
                            requestID: requestID,
                            roomID: self.room?.id,
                            sentAt: Date()
                        )
                    )
                } catch {
                    self.handleSocketFailure(error)
                    return
                }
            }
        }
    }

    private func handleSocketFailure(_ error: Error) {
        let shouldReconnect = room != nil || intendedInviteCode != nil || intendedRole != nil
        disconnect(clearIntent: false)
        guard shouldReconnect, reconnectAttempt < 4 else {
            fail(error)
            return
        }
        reconnectAttempt += 1
        connectionState = .connecting
        let delay = min(8, pow(2, Double(reconnectAttempt - 1)))
        Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard let self else { return }
            if self.intendedRole == .host,
               let roomID = self.intendedRoomID,
               let inviteCode = self.intendedInviteCode {
                await self.resumeRoom(roomID: roomID, inviteCode: inviteCode)
            } else if self.intendedRole == .host {
                await self.createRoom()
            } else if let code = self.intendedInviteCode {
                await self.joinRoom(inviteCode: code)
            }
        }
    }

    private func disconnect(clearIntent: Bool) {
        receiveTask?.cancel()
        heartbeatTask?.cancel()
        receiveTask = nil
        heartbeatTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        pendingHeartbeat.removeAll()
        room = nil
        role = nil
        chatMessages = []
        chatErrorText = nil
        controlErrorText = nil
        sharedQueue = []
        pendingTrackRequest = nil
        isPlaybackControlPending = false
        pendingSeekPosition = nil
        lastQueueSignature = ""
        playbackConvergenceTarget = nil
        playbackConvergenceDeadline = .distantPast
        remotePlaybackSuppressionUntil = .distantPast
        connectionState = .disconnected
        if clearIntent {
            intendedInviteCode = nil
            intendedRoomID = nil
            intendedRole = nil
            reconnectAttempt = 0
        }
    }

    private func fail(_ error: Error) {
        connectionState = .failed(String(localized: "mono_session_error_network"))
        AppLogger.error(
            "[MonoSession] \(error.localizedDescription)",
            step: "mono-session.error"
        )
    }

    private func sameSong(_ lhs: Song?, _ rhs: Song) -> Bool {
        guard let lhs else { return false }
        return lhs.id == rhs.id && lhs.musicSource == rhs.musicSource
    }

    private func resumeRoom(roomID: String, inviteCode: String) async {
        do {
            try await connectIfNeeded()
            role = .host
            try await send(
                MonoSessionWireMessage(
                    command: .resume,
                    requestID: UUID(),
                    roomID: roomID,
                    inviteCode: inviteCode,
                    participant: makeLocalParticipant(role: .host, displayName: nil),
                    sentAt: Date()
                )
            )
        } catch {
            fail(error)
        }
    }

    private func sessionErrorText(code: String?) -> String {
        switch code {
        case "room_not_found": return String(localized: "mono_session_error_not_found")
        case "room_full": return String(localized: "mono_session_error_full")
        case "host_required": return String(localized: "mono_session_error_host")
        case "resume_rejected": return String(localized: "mono_session_error_resume")
        case "room_ended": return String(localized: "mono_session_error_ended")
        default: return String(localized: "mono_session_error_generic")
        }
    }

    private func chatServerErrorText(code: String?, detail: String?) -> String? {
        switch code {
        case "chat_too_fast":
            return String(localized: "mono_session_chat_send_failed")
        case "chat_sensitive":
            return String(localized: "mono_session_chat_sensitive")
        case "chat_privacy":
            return String(localized: "mono_session_chat_privacy")
        case "chat_too_long":
            return String(localized: "mono_session_chat_too_long")
        case "invalid_chat":
            switch detail {
            case "chat_sensitive":
                return String(localized: "mono_session_chat_sensitive")
            case "chat_privacy":
                return String(localized: "mono_session_chat_privacy")
            case "chat_too_long":
                return String(localized: "mono_session_chat_too_long")
            default:
                return String(localized: "mono_session_chat_invalid")
            }
        default:
            return nil
        }
    }

    private func chatPolicyErrorText(_ violation: MonoSessionChatPolicy.Violation) -> String {
        switch violation {
        case .privacy:
            return String(localized: "mono_session_chat_privacy")
        case .tooLong:
            return String(localized: "mono_session_chat_too_long")
        }
    }

    private func sanitizedIncomingChat(_ chat: MonoSessionChatMessage) -> MonoSessionChatMessage {
        let normalized = MonoSessionChatPolicy.normalized(chat.text)
        let normalizedName = String(MonoSessionChatPolicy.normalized(chat.senderName).prefix(40))
        let text: String
        if MonoSessionChatPolicy.violation(in: normalized) != nil {
            text = String(localized: "mono_session_chat_hidden")
        } else {
            text = normalized
        }
        return MonoSessionChatMessage(
            id: chat.id,
            senderID: chat.senderID,
            senderName: normalizedName.isEmpty || MonoSessionChatPolicy.violation(in: normalizedName) != nil
                ? "Mono"
                : normalizedName,
            senderAvatarURL: normalizedNeteaseAvatarURL(chat.senderAvatarURL),
            text: text,
            sentAt: chat.sentAt
        )
    }
}

private enum MonoSessionChatPolicy {
    enum Violation {
        case privacy
        case tooLong
    }

    private static let privacyExpressions: [NSRegularExpression] = [
        #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
        #"(?:https?://|www\.)\S+"#,
        #"(?<!\d)1[3-9]\d{9}(?!\d)"#,
        #"(?<!\d)\d{16,19}(?!\d)"#,
        #"(?:微信|微\s*信|vx|v信|qq|扣扣|telegram|tg)\s*[:：号]?\s*[A-Z0-9_-]{5,}"#
    ].compactMap {
        try? NSRegularExpression(pattern: $0, options: [.caseInsensitive])
    }

    static func normalized(_ text: String) -> String {
        let compatible = text.precomposedStringWithCompatibilityMapping
        let cleaned = compatible.unicodeScalars.reduce(into: "") { result, scalar in
            guard scalar.value == 10
                    || scalar.value == 9
                    || !CharacterSet.controlCharacters.contains(scalar) else { return }
            result.unicodeScalars.append(scalar)
        }
        return cleaned
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{200C}", with: "")
            .replacingOccurrences(of: "\u{200D}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func violation(in text: String) -> Violation? {
        guard text.count <= 300 else { return .tooLong }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if privacyExpressions.contains(where: { $0.firstMatch(in: text, range: range) != nil }) {
            return .privacy
        }
        return nil
    }
}
