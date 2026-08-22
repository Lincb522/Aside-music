import Foundation
import Testing
import MonoAudioCore
import MonoAudioStreaming
@testable import MonoAudioFFmpeg

@Test func compilesFiltersInOwnedStageOrder() throws {
    var baseline = GraphicEQCurve.flat()
    baseline.gainsDB[0] = -1
    var graphic = GraphicEQCurve.flat()
    graphic.gainsDB[4] = 2
    let plan = MonoAudioPlan(
        name: "FFmpeg",
        deviceBaseline: baseline,
        graphicEQ: graphic,
        parametricEQ: [.init(kind: .peak, frequencyHz: 2_800, gainDB: -1, q: 1.5)],
        compressor: .init(isEnabled: true, thresholdDB: -18, ratio: 1.5, attackMS: 20, releaseMS: 180),
        spatial: .init(stereoWidth: 1.1),
        outputSafety: .init(preampDB: -3.7, limiterEnabled: true, limiterCeilingDBFS: -1)
    )
    let graph = try FFmpegFilterGraphCompiler().compile(plan)
    #expect(graph.filters.count == 7)
    #expect(graph.filters[0].contains("f=31"))
    #expect(graph.filters[1].contains("f=500"))
    #expect(graph.filters[2].contains("f=2800"))
    #expect(graph.filters[3].hasPrefix("acompressor="))
    #expect(graph.filters[4].hasPrefix("extrastereo="))
    #expect(graph.filters[5].hasPrefix("volume="))
    #expect(graph.filters[6].hasPrefix("alimiter="))
}

@Test func flatPlanStillHasSafetyStages() throws {
    let graph = try FFmpegFilterGraphCompiler().compile(.init(name: "Flat"))
    #expect(graph.filters.count == 2)
    #expect(graph.filters[0].hasPrefix("volume="))
    #expect(graph.filters[1].hasPrefix("alimiter="))
}

@Test func relayBuilderProducesDeterministicShellFreeArgv() throws {
    let source = MonoAudioStreamSource(
        id: "live",
        endpoint: .init(
            url: URL(string: "https://cdn.example/live/index.m3u8?token=a%26b")!,
            streamProtocol: .hls,
            format: .hls
        ),
        request: .init(
            headers: ["X-Zone": "east", "Authorization": "Bearer test"],
            userAgent: "MonoAudio/1"
        )
    )
    let destination = MonoAudioStreamEndpoint(
        url: URL(string: "rtmps://publish.example/app/stream-key")!,
        streamProtocol: .rtmp,
        format: .flv
    )
    let configuration = FFmpegStreamingRelayConfiguration(
        source: source,
        destination: destination,
        audioCodec: .aac,
        audioBitrateKilobitsPerSecond: 160,
        sampleRateHz: 48_000,
        channelCount: 2,
        maximumDurationSeconds: 12.5
    )

    let builder = FFmpegStreamingCommandBuilder(ffmpegExecutable: "/opt/ffmpeg/bin/ffmpeg")
    let first = try builder.buildRelay(configuration)
    let second = try builder.buildRelay(configuration)
    #expect(first == second)
    #expect(first.argv.first == "/opt/ffmpeg/bin/ffmpeg")
    #expect(first.arguments.contains("https://cdn.example/live/index.m3u8?token=a%26b"))
    #expect(first.arguments.contains("rtmps://publish.example/app/stream-key"))
    #expect(first.arguments.contains("Authorization: Bearer test\r\nX-Zone: east\r\n"))
    #expect(first.arguments.contains("12.5"))
    #expect(!first.arguments.contains("sh"))
    #expect(!first.arguments.contains("-c"))
}

@Test func capabilityEvidenceIsSeparateFromProtocolModel() throws {
    let capabilities = FFmpegStreamingCapabilities.parse(
        protocolsOutput: """
        Supported file protocols:
        Input:
          file
          hls
          http
          https
          rtmp
        Output:
          file
          http
          https
          icecast
          rtmp
        """,
        demuxersOutput: """
         D  hls             Apple HTTP Live Streaming
         D  rtsp            RTSP input
        """,
        muxersOutput: """
         E  adts            ADTS AAC
         E  flv             FLV
         E  mpegts          MPEG-TS
        """,
        encodersOutput: """
         A..... aac          AAC
        """
    )
    #expect(capabilities.inputProtocols.contains("https"))
    #expect(capabilities.demuxers.contains("rtsp"))
    #expect(capabilities.encoders.contains("aac"))
    #expect(!capabilities.inputProtocols.contains("srt"))

    let configuration = FFmpegStreamingRelayConfiguration(
        source: .init(
            endpoint: .init(
                url: URL(string: "srt://relay.example:9000")!,
                streamProtocol: .srt,
                format: .mpegTS
            )
        ),
        destination: .init(
            url: URL(string: "icecast://radio.example:8000/live")!,
            streamProtocol: .icecast,
            format: .aac
        )
    )
    let issues = capabilities.missingCapabilities(for: configuration)
    #expect(issues.contains {
        $0.direction == .input && $0.kind == .urlProtocol && $0.name == "srt"
    })
    #expect(throws: FFmpegStreamingError.self) {
        try FFmpegStreamingCommandBuilder().buildRelay(configuration, capabilities: capabilities)
    }
}

@Test func rtspUsesDemuxerCapabilityRatherThanAProtocolEntry() {
    let capabilities = FFmpegStreamingCapabilities(
        inputProtocols: ["tcp", "udp"],
        outputProtocols: ["rtmp"],
        demuxers: ["rtsp"],
        muxers: ["flv"],
        encoders: ["aac"]
    )
    let configuration = FFmpegStreamingRelayConfiguration(
        source: .init(
            endpoint: .init(
                url: URL(string: "rtsp://camera.example/audio")!,
                streamProtocol: .rtsp,
                format: .automatic
            ),
            request: .init(rtspTransport: .tcp)
        ),
        destination: .init(
            url: URL(string: "rtmp://publish.example/live/key")!,
            streamProtocol: .rtmp,
            format: .flv
        )
    )
    #expect(capabilities.missingCapabilities(for: configuration).isEmpty)
}

@Test func streamCopyCannotBeCombinedWithTuningFilters() {
    let configuration = FFmpegStreamingRelayConfiguration(
        source: .init(
            endpoint: .init(
                url: URL(string: "https://radio.example/live.mp3")!,
                streamProtocol: .https,
                format: .mp3
            )
        ),
        destination: .init(
            url: URL(string: "icecast://radio.example:8000/live")!,
            streamProtocol: .icecast,
            format: .mp3
        ),
        tuningPlan: .init(name: "Relay"),
        audioCodec: .streamCopy
    )
    #expect(throws: FFmpegStreamingError.self) {
        try FFmpegStreamingCommandBuilder().buildRelay(configuration)
    }
}

@Test func remoteProbeInputUsesAbsoluteStringInsteadOfAFilePath() {
    let remote = URL(string: "https://cdn.example/live/index.m3u8?token=a%26b")!
    #expect(FFmpegCommandLine.inputArgument(for: remote) == remote.absoluteString)

    let local = URL(fileURLWithPath: "/tmp/mono audio/input.flac")
    #expect(FFmpegCommandLine.inputArgument(for: local) == local.path)
}

@Test func relayRejectsAnUnboundedNumericDurationValue() {
    let configuration = FFmpegStreamingRelayConfiguration(
        source: .init(
            endpoint: .init(
                url: URL(string: "https://radio.example/live.mp3")!,
                streamProtocol: .https,
                format: .mp3
            )
        ),
        destination: .init(
            url: URL(string: "icecast://radio.example:8000/live")!,
            streamProtocol: .icecast,
            format: .mp3
        ),
        audioCodec: .mp3,
        maximumDurationSeconds: .infinity
    )
    #expect(throws: FFmpegStreamingError.self) {
        try FFmpegStreamingCommandBuilder().buildRelay(configuration)
    }
}
