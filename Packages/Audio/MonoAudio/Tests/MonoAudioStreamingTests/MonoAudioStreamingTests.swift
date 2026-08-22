import Foundation
import Testing
@testable import MonoAudioStreaming

@Test func validatesSupportedStreamEndpointSchemes() throws {
    let endpoints: [MonoAudioStreamEndpoint] = [
        .init(url: URL(string: "http://radio.example/live.mp3")!, streamProtocol: .http, format: .mp3),
        .init(url: URL(string: "https://radio.example/live.aac")!, streamProtocol: .https, format: .aac),
        .init(url: URL(string: "https://cdn.example/live/index.m3u8")!, streamProtocol: .hls, format: .hls),
        .init(url: URL(string: "rtsp://camera.example/audio")!, streamProtocol: .rtsp, format: .rtsp),
        .init(url: URL(string: "rtmps://publish.example/app/key")!, streamProtocol: .rtmp, format: .flv),
        .init(url: URL(string: "srt://relay.example:9000")!, streamProtocol: .srt, format: .mpegTS),
        .init(url: URL(string: "icecast://radio.example:8000/live")!, streamProtocol: .icecast, format: .opus),
    ]

    for endpoint in endpoints {
        try endpoint.validate()
    }
}

@Test func rejectsSchemeMismatchAndHeaderInjection() {
    let mismatched = MonoAudioStreamEndpoint(
        url: URL(string: "https://cdn.example/live.m3u8")!,
        streamProtocol: .srt,
        format: .mpegTS
    )
    #expect(throws: MonoAudioStreamValidationError.self) {
        try mismatched.validate()
    }

    let request = MonoAudioStreamRequestOptions(headers: ["X-Station": "safe\r\nX-Injected: yes"])
    #expect(throws: MonoAudioStreamValidationError.self) {
        try request.validate()
    }
}

@Test func sessionOwnsLifecycleWithoutAPlatformFramework() async throws {
    let transport = TestStreamingTransport()
    let session = MonoAudioStreamingSession(transport: transport)
    let source = makeSource()

    try await session.open(source)
    #expect(await session.state == .ready)
    try await session.play()
    #expect(await session.state == .playing)

    await transport.emit(.bufferingStarted(progress: 0.25))
    await waitForState(.buffering, session: session)
    #expect(await session.state == .buffering)

    await transport.emit(.bufferingEnded)
    await waitForState(.playing, session: session)
    #expect(await session.state == .playing)

    try await session.pause()
    #expect(await session.state == .paused)
    await session.stop()
    #expect(await session.state == .stopped)
    #expect(await transport.recordedCalls() == [.open, .play, .pause, .stop])
}

@Test func sessionForwardsMetadataAndRejectsInvalidTransitions() async throws {
    let transport = TestStreamingTransport()
    let session = MonoAudioStreamingSession(transport: transport)

    do {
        try await session.play()
        Issue.record("play should fail before a source is ready")
    } catch let error as MonoAudioStreamingSessionError {
        #expect(error == .invalidTransition(state: .idle, operation: .play))
    }

    let events = await session.events()
    try await session.open(makeSource())
    let metadataTask = Task<MonoAudioStreamingEvent?, Never> {
        for await event in events {
            if case .metadata = event { return event }
        }
        return nil
    }
    let metadata = MonoAudioStreamMetadata(title: "Signal", station: "Test Radio")
    await transport.emit(.metadata(metadata))
    #expect(await metadataTask.value == .metadata(metadata))
    await session.stop()
}

private func makeSource() -> MonoAudioStreamSource {
    .init(
        id: "test-stream",
        endpoint: .init(
            url: URL(string: "https://cdn.example/live/index.m3u8")!,
            streamProtocol: .hls,
            format: .hls
        )
    )
}

private func waitForState(
    _ expected: MonoAudioStreamingState,
    session: MonoAudioStreamingSession
) async {
    for _ in 0 ..< 100 {
        if await session.state == expected { return }
        await Task.yield()
    }
}

private actor TestStreamingTransport: MonoAudioStreamingTransport {
    enum Call: Equatable, Sendable { case open, play, pause, stop }

    private let eventStream: AsyncStream<MonoAudioStreamingTransportEvent>
    private let eventContinuation: AsyncStream<MonoAudioStreamingTransportEvent>.Continuation
    private var calls: [Call] = []

    init() {
        let pair = AsyncStream.makeStream(of: MonoAudioStreamingTransportEvent.self)
        eventStream = pair.stream
        eventContinuation = pair.continuation
    }

    func events() async -> AsyncStream<MonoAudioStreamingTransportEvent> {
        eventStream
    }

    func open(_: MonoAudioStreamSource) async throws {
        calls.append(.open)
    }

    func play() async throws {
        calls.append(.play)
    }

    func pause() async throws {
        calls.append(.pause)
    }

    func stop() async {
        calls.append(.stop)
    }

    func emit(_ event: MonoAudioStreamingTransportEvent) {
        eventContinuation.yield(event)
    }

    func recordedCalls() -> [Call] {
        calls
    }
}
