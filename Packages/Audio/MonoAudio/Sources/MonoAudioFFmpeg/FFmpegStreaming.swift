import Foundation
import MonoAudioCore
import MonoAudioStreaming

public enum FFmpegStreamingAudioCodec: String, Codable, CaseIterable, Sendable {
    case streamCopy
    case aac
    case mp3
    case opus
    case flac
    case pcmS16LE

    var ffmpegName: String {
        switch self {
        case .streamCopy: "copy"
        case .aac: "aac"
        case .mp3: "libmp3lame"
        case .opus: "libopus"
        case .flac: "flac"
        case .pcmS16LE: "pcm_s16le"
        }
    }
}

public struct FFmpegStreamingRelayConfiguration: Codable, Equatable, Sendable {
    public var source: MonoAudioStreamSource
    public var destination: MonoAudioStreamEndpoint
    public var tuningPlan: MonoAudioPlan?
    public var audioCodec: FFmpegStreamingAudioCodec
    public var audioBitrateKilobitsPerSecond: Int?
    public var sampleRateHz: Int?
    public var channelCount: Int?
    public var maximumDurationSeconds: Double?

    public init(
        source: MonoAudioStreamSource,
        destination: MonoAudioStreamEndpoint,
        tuningPlan: MonoAudioPlan? = nil,
        audioCodec: FFmpegStreamingAudioCodec = .aac,
        audioBitrateKilobitsPerSecond: Int? = 192,
        sampleRateHz: Int? = nil,
        channelCount: Int? = nil,
        maximumDurationSeconds: Double? = nil
    ) {
        self.source = source
        self.destination = destination
        self.tuningPlan = tuningPlan
        self.audioCodec = audioCodec
        self.audioBitrateKilobitsPerSecond = audioBitrateKilobitsPerSecond
        self.sampleRateHz = sampleRateHz
        self.channelCount = channelCount
        self.maximumDurationSeconds = maximumDurationSeconds
    }
}

public struct FFmpegStreamingCommand: Codable, Equatable, Sendable {
    public var executable: String
    public var arguments: [String]

    public var argv: [String] { [executable] + arguments }

    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }
}

public enum FFmpegStreamingCapabilityDirection: String, Codable, Equatable, Sendable {
    case input
    case output
}

public enum FFmpegStreamingCapabilityKind: String, Codable, Equatable, Sendable {
    case urlProtocol
    case demuxer
    case muxer
    case encoder
}

public struct FFmpegStreamingCapabilityIssue: Codable, Equatable, Sendable {
    public var direction: FFmpegStreamingCapabilityDirection
    public var kind: FFmpegStreamingCapabilityKind
    public var name: String

    public init(
        direction: FFmpegStreamingCapabilityDirection,
        kind: FFmpegStreamingCapabilityKind,
        name: String
    ) {
        self.direction = direction
        self.kind = kind
        self.name = name
    }
}

/// Capabilities observed from one concrete FFmpeg executable. Protocol models
/// remain portable even when a build omits an implementation such as SRT.
public struct FFmpegStreamingCapabilities: Codable, Equatable, Sendable {
    public var inputProtocols: Set<String>
    public var outputProtocols: Set<String>
    public var demuxers: Set<String>
    public var muxers: Set<String>
    public var encoders: Set<String>

    public init(
        inputProtocols: Set<String> = [],
        outputProtocols: Set<String> = [],
        demuxers: Set<String> = [],
        muxers: Set<String> = [],
        encoders: Set<String> = []
    ) {
        self.inputProtocols = Set(inputProtocols.map { $0.lowercased() })
        self.outputProtocols = Set(outputProtocols.map { $0.lowercased() })
        self.demuxers = Set(demuxers.map { $0.lowercased() })
        self.muxers = Set(muxers.map { $0.lowercased() })
        self.encoders = Set(encoders.map { $0.lowercased() })
    }

    public static func parse(
        protocolsOutput: String,
        demuxersOutput: String,
        muxersOutput: String,
        encodersOutput: String = ""
    ) -> Self {
        let protocols = parseProtocols(protocolsOutput)
        return .init(
            inputProtocols: protocols.input,
            outputProtocols: protocols.output,
            demuxers: parseFormats(demuxersOutput),
            muxers: parseFormats(muxersOutput),
            encoders: parseAudioEncoders(encodersOutput)
        )
    }

    public func missingCapabilities(
        for configuration: FFmpegStreamingRelayConfiguration
    ) -> [FFmpegStreamingCapabilityIssue] {
        var issues: [FFmpegStreamingCapabilityIssue] = []
        appendURLProtocolRequirement(
            for: configuration.source.endpoint,
            direction: .input,
            available: inputProtocols,
            issues: &issues
        )
        appendURLProtocolRequirement(
            for: configuration.destination,
            direction: .output,
            available: outputProtocols,
            issues: &issues
        )

        if let demuxer = Self.inputFormatName(for: configuration.source.endpoint),
           !demuxers.contains(demuxer) {
            issues.append(.init(direction: .input, kind: .demuxer, name: demuxer))
        }
        let muxer = Self.outputFormatName(
            for: configuration.destination,
            codec: configuration.audioCodec
        )
        if !muxers.contains(muxer) {
            issues.append(.init(direction: .output, kind: .muxer, name: muxer))
        }
        if configuration.audioCodec != .streamCopy {
            let encoder = configuration.audioCodec.ffmpegName.lowercased()
            if !encoders.contains(encoder) {
                issues.append(.init(direction: .output, kind: .encoder, name: encoder))
            }
        }
        return issues
    }

    private func appendURLProtocolRequirement(
        for endpoint: MonoAudioStreamEndpoint,
        direction: FFmpegStreamingCapabilityDirection,
        available: Set<String>,
        issues: inout [FFmpegStreamingCapabilityIssue]
    ) {
        guard let scheme = endpoint.url.scheme?.lowercased(), !scheme.hasPrefix("rtsp") else {
            return
        }
        guard !available.contains(scheme) else { return }
        issues.append(.init(direction: direction, kind: .urlProtocol, name: scheme))
    }

    private static func inputFormatName(for endpoint: MonoAudioStreamEndpoint) -> String? {
        if endpoint.format != .automatic {
            return demuxerName(for: endpoint.format)
        }
        return switch endpoint.streamProtocol {
        case .hls: "hls"
        case .rtsp: "rtsp"
        case .http, .https, .rtmp, .srt, .icecast: nil
        }
    }

    fileprivate static func outputFormatName(
        for endpoint: MonoAudioStreamEndpoint,
        codec: FFmpegStreamingAudioCodec
    ) -> String {
        if endpoint.format != .automatic {
            return muxerName(for: endpoint.format)
        }
        return switch endpoint.streamProtocol {
        case .hls: "hls"
        case .rtsp: "rtsp"
        case .rtmp: "flv"
        case .srt, .http, .https: "mpegts"
        case .icecast:
            switch codec {
            case .mp3: "mp3"
            case .opus: "ogg"
            case .aac, .streamCopy: "adts"
            case .flac: "flac"
            case .pcmS16LE: "wav"
            }
        }
    }

    fileprivate static func demuxerName(for format: MonoAudioStreamFormat) -> String? {
        switch format {
        case .automatic: nil
        case .hls: "hls"
        case .rtsp: "rtsp"
        case .mpegTS: "mpegts"
        case .flv: "flv"
        case .fragmentedMP4: "mov"
        case .matroska: "matroska"
        case .mp3: "mp3"
        case .aac: "aac"
        case .ogg, .opus: "ogg"
        case .wav: "wav"
        case .flac: "flac"
        }
    }

    fileprivate static func muxerName(for format: MonoAudioStreamFormat) -> String {
        switch format {
        case .automatic: "mpegts"
        case .hls: "hls"
        case .rtsp: "rtsp"
        case .mpegTS: "mpegts"
        case .flv: "flv"
        case .fragmentedMP4: "mp4"
        case .matroska: "matroska"
        case .mp3: "mp3"
        case .aac: "adts"
        case .ogg: "ogg"
        case .opus: "opus"
        case .wav: "wav"
        case .flac: "flac"
        }
    }

    private static func parseProtocols(_ output: String) -> (input: Set<String>, output: Set<String>) {
        enum Section { case none, input, output }
        var section = Section.none
        var input: Set<String> = []
        var outputProtocols: Set<String> = []
        for line in output.split(whereSeparator: \.isNewline) {
            let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if value == "Input:" {
                section = .input
                continue
            }
            if value == "Output:" {
                section = .output
                continue
            }
            guard section != .none, !value.isEmpty else { continue }
            for name in value.split(whereSeparator: \.isWhitespace).map({ $0.lowercased() }) {
                switch section {
                case .input: input.insert(name)
                case .output: outputProtocols.insert(name)
                case .none: break
                }
            }
        }
        return (input, outputProtocols)
    }

    private static func parseFormats(_ output: String) -> Set<String> {
        var formats: Set<String> = []
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 2 else { continue }
            let flags = fields[0]
            guard flags.contains("D") || flags.contains("E") else { continue }
            guard fields[1] != "=" else { continue }
            for name in fields[1].split(separator: ",") {
                formats.insert(name.lowercased())
            }
        }
        return formats
    }

    private static func parseAudioEncoders(_ output: String) -> Set<String> {
        var encoders: Set<String> = []
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 2, fields[1] != "=" else { continue }
            guard fields[0].first == "A" else { continue }
            encoders.insert(fields[1].lowercased())
        }
        return encoders
    }
}

public enum FFmpegStreamingError: Error, Equatable, Sendable {
    case invalidAudioBitrate(Int)
    case invalidSampleRate(Int)
    case invalidChannelCount(Int)
    case invalidMaximumDuration(Double)
    case streamCopyCannotFilter
    case requestHeadersUnsupported(MonoAudioStreamProtocol)
    case missingCapabilities([FFmpegStreamingCapabilityIssue])
}

/// Builds a deterministic FFmpeg argv array. It never creates a shell command
/// string and never performs network work.
public struct FFmpegStreamingCommandBuilder: Sendable {
    public var ffmpegExecutable: String

    public init(ffmpegExecutable: String = "ffmpeg") {
        self.ffmpegExecutable = ffmpegExecutable
    }

    public func buildRelay(
        _ configuration: FFmpegStreamingRelayConfiguration,
        capabilities: FFmpegStreamingCapabilities? = nil
    ) throws -> FFmpegStreamingCommand {
        try configuration.source.validate()
        try configuration.destination.validate()
        if let bitrate = configuration.audioBitrateKilobitsPerSecond, !(8 ... 1_536).contains(bitrate) {
            throw FFmpegStreamingError.invalidAudioBitrate(bitrate)
        }
        if let sampleRate = configuration.sampleRateHz, !(8_000 ... 384_000).contains(sampleRate) {
            throw FFmpegStreamingError.invalidSampleRate(sampleRate)
        }
        if let channelCount = configuration.channelCount, !(1 ... 32).contains(channelCount) {
            throw FFmpegStreamingError.invalidChannelCount(channelCount)
        }
        if let duration = configuration.maximumDurationSeconds,
           !duration.isFinite || !(0.001 ... 86_400).contains(duration) {
            throw FFmpegStreamingError.invalidMaximumDuration(duration)
        }
        if configuration.tuningPlan != nil, configuration.audioCodec == .streamCopy {
            throw FFmpegStreamingError.streamCopyCannotFilter
        }
        if !configuration.source.request.headers.isEmpty,
           !Self.supportsHeaders(configuration.source.endpoint.streamProtocol) {
            throw FFmpegStreamingError.requestHeadersUnsupported(
                configuration.source.endpoint.streamProtocol
            )
        }
        if let capabilities {
            let missing = capabilities.missingCapabilities(for: configuration)
            guard missing.isEmpty else {
                throw FFmpegStreamingError.missingCapabilities(missing)
            }
        }

        var arguments = ["-nostdin", "-hide_banner", "-loglevel", "warning"]
        arguments += inputArguments(for: configuration.source)
        arguments += ["-i", configuration.source.endpoint.url.absoluteString]
        arguments += ["-map", "0:a:0", "-vn", "-sn", "-dn"]

        if let plan = configuration.tuningPlan {
            let filterGraph = try FFmpegFilterGraphCompiler().compile(plan)
            arguments += ["-af", filterGraph.expression]
        }
        arguments += ["-c:a", configuration.audioCodec.ffmpegName]
        if configuration.audioCodec != .streamCopy,
           let bitrate = configuration.audioBitrateKilobitsPerSecond {
            arguments += ["-b:a", "\(bitrate)k"]
        }
        if let sampleRate = configuration.sampleRateHz {
            arguments += ["-ar", String(sampleRate)]
        }
        if let channelCount = configuration.channelCount {
            arguments += ["-ac", String(channelCount)]
        }
        if let duration = configuration.maximumDurationSeconds {
            arguments += ["-t", number(duration)]
        }

        let muxer = FFmpegStreamingCapabilities.outputFormatName(
            for: configuration.destination,
            codec: configuration.audioCodec
        )
        if configuration.destination.format == .fragmentedMP4 {
            arguments += ["-movflags", "+frag_keyframe+empty_moov"]
        }
        if configuration.destination.streamProtocol == .icecast {
            arguments += ["-content_type", contentType(for: muxer)]
        }
        arguments += ["-f", muxer, configuration.destination.url.absoluteString]
        return .init(executable: ffmpegExecutable, arguments: arguments)
    }

    private func inputArguments(for source: MonoAudioStreamSource) -> [String] {
        var arguments: [String] = []
        let request = source.request
        arguments += ["-rw_timeout", String(Int64(request.readTimeoutMilliseconds) * 1_000)]

        if let demuxer = FFmpegStreamingCapabilities.demuxerName(for: source.endpoint.format) {
            arguments += ["-f", demuxer]
        }
        if let userAgent = request.userAgent, !userAgent.isEmpty {
            arguments += ["-user_agent", userAgent]
        }
        if !request.headers.isEmpty {
            let headerBlock = request.headers.keys.sorted().map { key in
                "\(key): \(request.headers[key]!)\r\n"
            }.joined()
            arguments += ["-headers", headerBlock]
        }
        if source.endpoint.streamProtocol == .rtsp, request.rtspTransport != .automatic {
            arguments += ["-rtsp_transport", request.rtspTransport.rawValue]
        }
        if request.reconnect.isEnabled, Self.supportsReconnect(source.endpoint.streamProtocol) {
            arguments += [
                "-reconnect", "1",
                "-reconnect_streamed", "1",
                "-reconnect_at_eof", request.reconnect.reconnectAtEndOfFile ? "1" : "0",
                "-reconnect_on_network_error", request.reconnect.reconnectOnNetworkError ? "1" : "0",
                "-reconnect_delay_max", String(request.reconnect.maximumDelaySeconds),
            ]
        }
        return arguments
    }

    private static func supportsHeaders(_ streamProtocol: MonoAudioStreamProtocol) -> Bool {
        switch streamProtocol {
        case .http, .https, .hls, .icecast: true
        case .rtsp, .rtmp, .srt: false
        }
    }

    private static func supportsReconnect(_ streamProtocol: MonoAudioStreamProtocol) -> Bool {
        switch streamProtocol {
        case .http, .https, .hls, .icecast: true
        case .rtsp, .rtmp, .srt: false
        }
    }

    private func contentType(for muxer: String) -> String {
        switch muxer {
        case "mp3": "audio/mpeg"
        case "adts": "audio/aac"
        case "ogg", "opus": "audio/ogg"
        case "flac": "audio/flac"
        case "wav": "audio/wav"
        default: "application/octet-stream"
        }
    }

    private func number(_ value: Double) -> String {
        var output = String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
        while output.contains("."), output.last == "0" { output.removeLast() }
        if output.last == "." { output.removeLast() }
        return output
    }
}
