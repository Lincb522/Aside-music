import Foundation
@preconcurrency import FFmpegSwiftSDK
import MonoAudioStreaming

/// Adapts an iOS `StreamPlayer` to MonoAudio's platform-independent streaming
/// session. The SDK continues to own FFmpeg decoding and the native audio path;
/// this type only translates lifecycle calls and prepared delegate events.
///
/// `StreamPlayer.delegate` is weak. The transport therefore retains a proxy for
/// as long as the session is alive and forwards callbacks to the delegate that
/// was installed before the transport. SDK callbacks keep their original
/// delivery thread; MonoAudio events are moved onto the main actor before they
/// enter the asynchronous event stream.
///
/// ```swift
/// let player = StreamPlayer()
/// let transport = FFmpegSwiftSDKStreamingTransport(player: player)
/// let session = MonoAudioStreamingSession(transport: transport)
/// ```
@MainActor
public final class FFmpegSwiftSDKStreamingTransport: MonoAudioStreamingTransport {
    private let player: StreamPlayer
    private var eventContinuations: [
        UUID: AsyncStream<MonoAudioStreamingTransportEvent>.Continuation
    ] = [:]
    private var pendingOpen: CheckedContinuation<Void, any Error>?
    private var currentSource: MonoAudioStreamSource?
    private var lastPublishedVariant: MonoAudioStreamVariant?

    private let delegateProxy: StreamPlayerDelegateProxy

    public init(player: StreamPlayer) {
        let proxy = StreamPlayerDelegateProxy(forwardingTo: player.delegate)
        self.player = player
        self.delegateProxy = proxy
        proxy.setEventSink { [weak self] event in
            Task { @MainActor [weak self] in
                self?.receive(event)
            }
        }
        player.delegate = proxy
    }

    deinit {
        if player.delegate === delegateProxy {
            player.delegate = delegateProxy.forwardingDelegate
        }
        for continuation in eventContinuations.values {
            continuation.finish()
        }
    }

    public func events() async -> AsyncStream<MonoAudioStreamingTransportEvent> {
        let id = UUID()
        let pair = AsyncStream.makeStream(
            of: MonoAudioStreamingTransportEvent.self,
            bufferingPolicy: .bufferingNewest(64)
        )
        eventContinuations[id] = pair.continuation
        pair.continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.eventContinuations.removeValue(forKey: id)
            }
        }
        return pair.stream
    }

    public func open(_ source: MonoAudioStreamSource) async throws {
        try source.validate()
        try requireAttachedDelegate()
        try validateSupportedRequestOptions(source.request)
        guard pendingOpen == nil else {
            throw FFmpegSwiftSDKStreamingTransportError.openAlreadyInProgress
        }

        currentSource = source
        lastPublishedVariant = nil

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pendingOpen = continuation
                // autoPlay=false prepares the SDK pipeline without starting
                // audible output. `play()` later resumes the native renderer.
                player.play(url: source.endpoint.url.absoluteString, autoPlay: false)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelPendingOpen()
            }
        }
    }

    public func play() async throws {
        try requireAttachedDelegate()
        guard currentSource != nil, pendingOpen == nil else {
            throw FFmpegSwiftSDKStreamingTransportError.noPreparedStream
        }
        switch player.state {
        case .playing:
            return
        case .paused:
            guard player.resume() else {
                throw FFmpegSwiftSDKStreamingTransportError.unableToResume
            }
        case .idle, .connecting, .stopped, .error:
            throw FFmpegSwiftSDKStreamingTransportError.noPreparedStream
        }
    }

    public func pause() async throws {
        try requireAttachedDelegate()
        guard player.state == .playing else {
            throw FFmpegSwiftSDKStreamingTransportError.notPlaying
        }
        player.pause()
        guard player.state == .paused else {
            throw FFmpegSwiftSDKStreamingTransportError.unableToPause
        }
    }

    public func stop() async {
        let continuation = pendingOpen
        pendingOpen = nil
        currentSource = nil
        lastPublishedVariant = nil
        player.stop()
        continuation?.resume(throwing: CancellationError())
    }

    private func receive(_ event: StreamPlayerProxyEvent) {
        switch event {
        case .idle, .connecting:
            break
        case .playing:
            publishVariantIfAvailable()
        case .paused:
            publishVariantIfAvailable()
            if let continuation = pendingOpen {
                pendingOpen = nil
                continuation.resume()
            }
        case let .stopped(reachedEndOfStream):
            if let continuation = pendingOpen {
                pendingOpen = nil
                currentSource = nil
                continuation.resume(
                    throwing: FFmpegSwiftSDKStreamingTransportError.stoppedBeforeReady
                )
            } else if reachedEndOfStream {
                currentSource = nil
                lastPublishedVariant = nil
                publish(.ended)
            }
        case let .failed(failure):
            currentSource = nil
            lastPublishedVariant = nil
            if let continuation = pendingOpen {
                pendingOpen = nil
                continuation.resume(throwing: failure)
            } else {
                publish(.failure(failure))
            }
        case .discontinuity:
            publish(.discontinuity(sequence: nil))
        }
    }

    private func publishVariantIfAvailable() {
        guard let info = player.streamInfo else { return }
        let variant = MonoAudioStreamVariant(
            id: [
                currentSource?.id ?? "stream",
                info.audioCodec ?? "unknown",
                info.sampleRate.map(String.init) ?? "unknown",
                info.channelCount.map(String.init) ?? "unknown",
            ].joined(separator: ":"),
            sampleRateHz: info.sampleRate,
            channelCount: info.channelCount,
            codec: info.audioCodec
        )
        guard variant != lastPublishedVariant else { return }
        lastPublishedVariant = variant
        publish(.variantChanged(variant))
    }

    private func publish(_ event: MonoAudioStreamingTransportEvent) {
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    private func cancelPendingOpen() {
        guard let continuation = pendingOpen else { return }
        pendingOpen = nil
        currentSource = nil
        lastPublishedVariant = nil
        player.stop()
        continuation.resume(throwing: CancellationError())
    }

    private func requireAttachedDelegate() throws {
        guard player.delegate === delegateProxy else {
            throw FFmpegSwiftSDKStreamingTransportError.delegateWasReplaced
        }
    }

    /// The current StreamPlayer API owns its FFmpeg options internally. Reject
    /// non-default request options instead of pretending headers, timeouts, or
    /// RTSP transport preferences were applied.
    private func validateSupportedRequestOptions(
        _ options: MonoAudioStreamRequestOptions
    ) throws {
        let defaults = MonoAudioStreamRequestOptions()
        var unsupportedFields: [String] = []
        if !options.headers.isEmpty { unsupportedFields.append("headers") }
        if options.userAgent != nil { unsupportedFields.append("userAgent") }
        if options.connectionTimeoutMilliseconds != defaults.connectionTimeoutMilliseconds {
            unsupportedFields.append("connectionTimeoutMilliseconds")
        }
        if options.readTimeoutMilliseconds != defaults.readTimeoutMilliseconds {
            unsupportedFields.append("readTimeoutMilliseconds")
        }
        if options.reconnect != defaults.reconnect {
            unsupportedFields.append("reconnect")
        }
        if options.rtspTransport != .automatic {
            unsupportedFields.append("rtspTransport")
        }
        guard unsupportedFields.isEmpty else {
            throw FFmpegSwiftSDKStreamingTransportError.unsupportedRequestOptions(
                unsupportedFields
            )
        }
    }
}

public enum FFmpegSwiftSDKStreamingTransportError: Error, Equatable, Sendable {
    case delegateWasReplaced
    case openAlreadyInProgress
    case noPreparedStream
    case notPlaying
    case unableToResume
    case unableToPause
    case stoppedBeforeReady
    case unsupportedRequestOptions([String])
}

private enum StreamPlayerProxyEvent: Sendable {
    case idle
    case connecting
    case playing
    case paused
    case stopped(reachedEndOfStream: Bool)
    case failed(MonoAudioStreamFailure)
    case discontinuity
}

/// Receives SDK callbacks on whichever queue produced them. It snapshots only
/// Sendable values for the transport and directly forwards the original callback
/// to the previous delegate, preserving the SDK's delegate threading contract.
private final class StreamPlayerDelegateProxy: StreamPlayerDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private weak var storedForwardingDelegate: StreamPlayerDelegate?
    private var storedEventSink: (@Sendable (StreamPlayerProxyEvent) -> Void)?

    init(forwardingTo delegate: StreamPlayerDelegate?) {
        storedForwardingDelegate = delegate
    }

    var forwardingDelegate: StreamPlayerDelegate? {
        lock.lock()
        defer { lock.unlock() }
        return storedForwardingDelegate
    }

    func setEventSink(
        _ eventSink: @escaping @Sendable (StreamPlayerProxyEvent) -> Void
    ) {
        lock.lock()
        storedEventSink = eventSink
        lock.unlock()
    }

    func player(_ player: StreamPlayer, didChangeState state: PlaybackState) {
        switch state {
        case .idle:
            emit(.idle)
        case .connecting:
            emit(.connecting)
        case .playing:
            emit(.playing)
        case .paused:
            emit(.paused)
        case .stopped:
            emit(.stopped(reachedEndOfStream: player.lastStopReason == .endOfStream))
        case let .error(error):
            emit(.failed(makeFailure(error)))
        }
        forwardingDelegate?.player(player, didChangeState: state)
    }

    func player(_ player: StreamPlayer, didEncounterError error: FFmpegError) {
        // `.error` state carries the same failure and is emitted first. Forward
        // this callback without publishing a duplicate transport failure.
        forwardingDelegate?.player(player, didEncounterError: error)
    }

    func player(_ player: StreamPlayer, didUpdateDuration duration: TimeInterval) {
        forwardingDelegate?.player(player, didUpdateDuration: duration)
    }

    func player(
        _ player: StreamPlayer,
        didUpdateDuration duration: TimeInterval,
        forPlaybackInput playbackInput: String
    ) {
        forwardingDelegate?.player(
            player,
            didUpdateDuration: duration,
            forPlaybackInput: playbackInput
        )
    }

    func playerDidTransitionToNextTrack(_ player: StreamPlayer) {
        emit(.discontinuity)
        forwardingDelegate?.playerDidTransitionToNextTrack(player)
    }

    private func emit(_ event: StreamPlayerProxyEvent) {
        lock.lock()
        let eventSink = storedEventSink
        lock.unlock()
        eventSink?(event)
    }

    private func makeFailure(_ error: FFmpegError) -> MonoAudioStreamFailure {
        switch error {
        case let .connectionFailed(code, _):
            .init(
                code: "ffmpeg.connectionFailed.\(code)",
                message: "FFmpeg could not open the stream.",
                isRecoverable: true
            )
        case .connectionTimeout:
            .init(
                code: "ffmpeg.connectionTimeout",
                message: "The stream connection timed out.",
                isRecoverable: true
            )
        case let .unsupportedFormat(codecName):
            .init(
                code: "ffmpeg.unsupportedFormat",
                message: "The stream format or codec is not supported: \(codecName).",
                isRecoverable: false
            )
        case let .decodingFailed(code, _):
            .init(
                code: "ffmpeg.decodingFailed.\(code)",
                message: "FFmpeg could not decode the stream.",
                isRecoverable: true
            )
        case .resourceAllocationFailed:
            .init(
                code: "ffmpeg.resourceAllocationFailed",
                message: "The stream decoder could not allocate a required resource.",
                isRecoverable: false
            )
        case .networkDisconnected:
            .init(
                code: "ffmpeg.networkDisconnected",
                message: "The stream connection was interrupted.",
                isRecoverable: true
            )
        case .operationInterrupted:
            .init(
                code: "ffmpeg.operationInterrupted",
                message: "The stream operation was interrupted.",
                isRecoverable: true
            )
        case let .unknown(code):
            .init(
                code: "ffmpeg.unknown.\(code)",
                message: "FFmpeg reported an unknown stream error.",
                isRecoverable: false
            )
        }
    }
}
