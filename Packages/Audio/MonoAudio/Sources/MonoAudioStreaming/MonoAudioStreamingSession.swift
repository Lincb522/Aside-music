import Foundation

public struct MonoAudioStreamFailure: Error, Codable, Equatable, Sendable {
    public var code: String
    public var message: String
    public var isRecoverable: Bool

    public init(code: String, message: String, isRecoverable: Bool) {
        self.code = code
        self.message = message
        self.isRecoverable = isRecoverable
    }
}

public enum MonoAudioStreamingState: Codable, Equatable, Sendable {
    case idle
    case preparing
    case connecting
    case ready
    case playing
    case paused
    case buffering
    case stopping
    case stopped
    case failed(MonoAudioStreamFailure)
}

public enum MonoAudioStreamingEvent: Equatable, Sendable {
    case stateChanged(from: MonoAudioStreamingState, to: MonoAudioStreamingState)
    case bufferingProgress(Double?)
    case metadata(MonoAudioStreamMetadata)
    case variantChanged(MonoAudioStreamVariant)
    case discontinuity(sequence: Int?)
    case ended
    case failure(MonoAudioStreamFailure)
}

/// Events produced by a platform transport. A transport can be backed by a
/// native player, FFmpeg, a browser AudioWorklet, or another runtime.
public enum MonoAudioStreamingTransportEvent: Equatable, Sendable {
    case bufferingStarted(progress: Double?)
    case bufferingProgress(Double?)
    case bufferingEnded
    case metadata(MonoAudioStreamMetadata)
    case variantChanged(MonoAudioStreamVariant)
    case discontinuity(sequence: Int?)
    case ended
    case failure(MonoAudioStreamFailure)
}

/// Platform transports own network and decoder work. Implementations must keep
/// that work off realtime audio/render callbacks and deliver only prepared
/// state through this asynchronous boundary. `events()` must return its stream
/// immediately and must not wait for `open(_:)` or perform network work.
public protocol MonoAudioStreamingTransport: Sendable {
    func events() async -> AsyncStream<MonoAudioStreamingTransportEvent>
    func open(_ source: MonoAudioStreamSource) async throws
    func play() async throws
    func pause() async throws
    func stop() async
}

public enum MonoAudioStreamingOperation: String, Codable, Equatable, Sendable {
    case open
    case play
    case pause
}

public enum MonoAudioStreamingSessionError: Error, Equatable, Sendable {
    case invalidTransition(state: MonoAudioStreamingState, operation: MonoAudioStreamingOperation)
}

/// Platform-independent stream lifecycle and event fan-out. This actor does
/// not own an audio session, UI, decoder, or realtime audio callback.
public actor MonoAudioStreamingSession {
    public private(set) var state: MonoAudioStreamingState = .idle
    public private(set) var source: MonoAudioStreamSource?

    private let transport: any MonoAudioStreamingTransport
    private var eventContinuations: [UUID: AsyncStream<MonoAudioStreamingEvent>.Continuation] = [:]
    private var transportEventTask: Task<Void, Never>?
    private var generation = UUID()
    private var stateBeforeBuffering: MonoAudioStreamingState = .ready

    public init(transport: any MonoAudioStreamingTransport) {
        self.transport = transport
    }

    public func events(
        bufferingPolicy: AsyncStream<MonoAudioStreamingEvent>.Continuation.BufferingPolicy = .bufferingNewest(64)
    ) -> AsyncStream<MonoAudioStreamingEvent> {
        let id = UUID()
        let pair = AsyncStream.makeStream(of: MonoAudioStreamingEvent.self, bufferingPolicy: bufferingPolicy)
        eventContinuations[id] = pair.continuation
        pair.continuation.onTermination = { [weak self] _ in
            Task { await self?.removeEventContinuation(id) }
        }
        return pair.stream
    }

    public func open(_ source: MonoAudioStreamSource) async throws {
        guard canOpen(from: state) else {
            throw MonoAudioStreamingSessionError.invalidTransition(state: state, operation: .open)
        }
        try source.validate()

        transportEventTask?.cancel()
        generation = UUID()
        let activeGeneration = generation
        self.source = source
        transition(to: .preparing)
        await startTransportEventPump(generation: activeGeneration)
        transition(to: .connecting)

        do {
            try await transport.open(source)
            guard generation == activeGeneration else { return }
            if state == .connecting || state == .preparing {
                transition(to: .ready)
            }
        } catch {
            guard generation == activeGeneration else { throw error }
            recordFailure(
                .init(code: "transport.open", message: String(describing: error), isRecoverable: true)
            )
            throw error
        }
    }

    public func play() async throws {
        guard state == .ready || state == .paused else {
            throw MonoAudioStreamingSessionError.invalidTransition(state: state, operation: .play)
        }
        do {
            try await transport.play()
            transition(to: .playing)
        } catch {
            let failure = MonoAudioStreamFailure(
                code: "transport.play",
                message: String(describing: error),
                isRecoverable: true
            )
            recordFailure(failure)
            throw error
        }
    }

    public func pause() async throws {
        guard state == .playing || state == .buffering else {
            throw MonoAudioStreamingSessionError.invalidTransition(state: state, operation: .pause)
        }
        do {
            try await transport.pause()
            transition(to: .paused)
        } catch {
            let failure = MonoAudioStreamFailure(
                code: "transport.pause",
                message: String(describing: error),
                isRecoverable: true
            )
            recordFailure(failure)
            throw error
        }
    }

    public func stop() async {
        guard state != .idle, state != .stopped, state != .stopping else { return }
        generation = UUID()
        transition(to: .stopping)
        transportEventTask?.cancel()
        transportEventTask = nil
        await transport.stop()
        source = nil
        transition(to: .stopped)
    }

    private func canOpen(from state: MonoAudioStreamingState) -> Bool {
        switch state {
        case .idle, .stopped, .failed:
            true
        case .preparing, .connecting, .ready, .playing, .paused, .buffering, .stopping:
            false
        }
    }

    private func startTransportEventPump(generation: UUID) async {
        let stream = await transport.events()
        transportEventTask = Task { [weak self] in
            for await event in stream {
                guard !Task.isCancelled else { break }
                await self?.receive(event, generation: generation)
            }
        }
    }

    private func receive(_ event: MonoAudioStreamingTransportEvent, generation: UUID) {
        guard self.generation == generation else { return }
        switch event {
        case let .bufferingStarted(progress):
            if state == .playing || state == .ready {
                stateBeforeBuffering = state
                transition(to: .buffering)
            }
            publish(.bufferingProgress(progress))
        case let .bufferingProgress(progress):
            publish(.bufferingProgress(progress))
        case .bufferingEnded:
            if state == .buffering {
                transition(to: stateBeforeBuffering)
            }
        case let .metadata(metadata):
            publish(.metadata(metadata))
        case let .variantChanged(variant):
            publish(.variantChanged(variant))
        case let .discontinuity(sequence):
            publish(.discontinuity(sequence: sequence))
        case .ended:
            source = nil
            transition(to: .stopped)
            publish(.ended)
        case let .failure(failure):
            recordFailure(failure)
        }
    }

    private func transition(to newState: MonoAudioStreamingState) {
        guard state != newState else { return }
        let previous = state
        state = newState
        publish(.stateChanged(from: previous, to: newState))
    }

    private func recordFailure(_ failure: MonoAudioStreamFailure) {
        transition(to: .failed(failure))
        publish(.failure(failure))
    }

    private func publish(_ event: MonoAudioStreamingEvent) {
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    private func removeEventContinuation(_ id: UUID) {
        eventContinuations.removeValue(forKey: id)
    }
}
