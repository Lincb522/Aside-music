import Foundation

/// The delivery protocol used by a stream endpoint. This describes intent; it
/// does not claim that a particular decoder or FFmpeg build supports it.
public enum MonoAudioStreamProtocol: String, Codable, CaseIterable, Sendable {
    case http
    case https
    case hls
    case rtsp
    case rtmp
    case srt
    case icecast

    public var allowedURLSchemes: Set<String> {
        switch self {
        case .http: ["http"]
        case .https: ["https"]
        case .hls: ["http", "https"]
        case .rtsp: ["rtsp", "rtsps"]
        case .rtmp: ["rtmp", "rtmps"]
        case .srt: ["srt"]
        case .icecast: ["http", "https", "icecast"]
        }
    }
}

/// Container or elementary-stream format at an endpoint.
public enum MonoAudioStreamFormat: String, Codable, CaseIterable, Sendable {
    case automatic
    case hls
    case rtsp
    case mpegTS
    case flv
    case fragmentedMP4
    case matroska
    case mp3
    case aac
    case ogg
    case opus
    case wav
    case flac
}

public struct MonoAudioStreamEndpoint: Codable, Equatable, Sendable {
    public var url: URL
    public var streamProtocol: MonoAudioStreamProtocol
    public var format: MonoAudioStreamFormat

    public init(
        url: URL,
        streamProtocol: MonoAudioStreamProtocol,
        format: MonoAudioStreamFormat = .automatic
    ) {
        self.url = url
        self.streamProtocol = streamProtocol
        self.format = format
    }

    public func validate() throws {
        guard let scheme = url.scheme?.lowercased(), !scheme.isEmpty else {
            throw MonoAudioStreamValidationError.missingURLScheme
        }
        guard streamProtocol.allowedURLSchemes.contains(scheme) else {
            throw MonoAudioStreamValidationError.schemeMismatch(
                streamProtocol: streamProtocol,
                actualScheme: scheme
            )
        }
        guard let host = url.host, !host.isEmpty else {
            throw MonoAudioStreamValidationError.missingHost
        }

        let compatibleFormats: Set<MonoAudioStreamFormat>
        switch streamProtocol {
        case .hls:
            compatibleFormats = [.automatic, .hls]
        case .rtsp:
            compatibleFormats = [.automatic, .rtsp]
        case .rtmp:
            compatibleFormats = [.automatic, .flv]
        case .srt:
            compatibleFormats = [.automatic, .mpegTS]
        case .icecast:
            compatibleFormats = [.automatic, .mp3, .aac, .ogg, .opus]
        case .http, .https:
            compatibleFormats = Set(MonoAudioStreamFormat.allCases)
        }
        guard compatibleFormats.contains(format) else {
            throw MonoAudioStreamValidationError.incompatibleFormat(
                streamProtocol: streamProtocol,
                format: format
            )
        }
    }
}

public enum MonoAudioRTSPTransport: String, Codable, CaseIterable, Sendable {
    case automatic
    case tcp
    case udp
    case http
    case https
}

public struct MonoAudioStreamReconnectPolicy: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var reconnectAtEndOfFile: Bool
    public var reconnectOnNetworkError: Bool
    public var maximumDelaySeconds: Int

    public init(
        isEnabled: Bool = true,
        reconnectAtEndOfFile: Bool = false,
        reconnectOnNetworkError: Bool = true,
        maximumDelaySeconds: Int = 5
    ) {
        self.isEnabled = isEnabled
        self.reconnectAtEndOfFile = reconnectAtEndOfFile
        self.reconnectOnNetworkError = reconnectOnNetworkError
        self.maximumDelaySeconds = maximumDelaySeconds
    }
}

public struct MonoAudioStreamRequestOptions: Codable, Equatable, Sendable {
    public var headers: [String: String]
    public var userAgent: String?
    public var connectionTimeoutMilliseconds: Int
    public var readTimeoutMilliseconds: Int
    public var reconnect: MonoAudioStreamReconnectPolicy
    public var rtspTransport: MonoAudioRTSPTransport

    public init(
        headers: [String: String] = [:],
        userAgent: String? = nil,
        connectionTimeoutMilliseconds: Int = 10_000,
        readTimeoutMilliseconds: Int = 30_000,
        reconnect: MonoAudioStreamReconnectPolicy = .init(),
        rtspTransport: MonoAudioRTSPTransport = .automatic
    ) {
        self.headers = headers
        self.userAgent = userAgent
        self.connectionTimeoutMilliseconds = connectionTimeoutMilliseconds
        self.readTimeoutMilliseconds = readTimeoutMilliseconds
        self.reconnect = reconnect
        self.rtspTransport = rtspTransport
    }

    public func validate() throws {
        guard (1 ... 300_000).contains(connectionTimeoutMilliseconds) else {
            throw MonoAudioStreamValidationError.invalidTimeout(
                name: "connectionTimeoutMilliseconds",
                value: connectionTimeoutMilliseconds
            )
        }
        guard (1 ... 3_600_000).contains(readTimeoutMilliseconds) else {
            throw MonoAudioStreamValidationError.invalidTimeout(
                name: "readTimeoutMilliseconds",
                value: readTimeoutMilliseconds
            )
        }
        guard (0 ... 300).contains(reconnect.maximumDelaySeconds) else {
            throw MonoAudioStreamValidationError.invalidReconnectDelay(reconnect.maximumDelaySeconds)
        }
        if let userAgent, containsLineBreak(userAgent) {
            throw MonoAudioStreamValidationError.invalidUserAgent
        }
        for (name, value) in headers {
            guard !name.isEmpty, name.unicodeScalars.allSatisfy({ Self.headerTokenCharacters.contains($0) }) else {
                throw MonoAudioStreamValidationError.invalidHeaderName(name)
            }
            guard !containsLineBreak(value) else {
                throw MonoAudioStreamValidationError.invalidHeaderValue(name)
            }
        }
    }

    private static let headerTokenCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%&'*+-.^_`|~"
    )

    private func containsLineBreak(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            scalar.value == 0x0A || scalar.value == 0x0D
        }
    }
}

public struct MonoAudioStreamSource: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var endpoint: MonoAudioStreamEndpoint
    public var displayName: String?
    public var request: MonoAudioStreamRequestOptions

    public init(
        id: String = UUID().uuidString,
        endpoint: MonoAudioStreamEndpoint,
        displayName: String? = nil,
        request: MonoAudioStreamRequestOptions = .init()
    ) {
        self.id = id
        self.endpoint = endpoint
        self.displayName = displayName
        self.request = request
    }

    public func validate() throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MonoAudioStreamValidationError.emptySourceID
        }
        try endpoint.validate()
        try request.validate()
        if endpoint.streamProtocol != .rtsp, request.rtspTransport != .automatic {
            throw MonoAudioStreamValidationError.rtspOptionOnNonRTSPSource
        }
    }
}

public struct MonoAudioStreamMetadata: Codable, Equatable, Sendable {
    public var title: String?
    public var artist: String?
    public var album: String?
    public var station: String?
    public var additionalFields: [String: String]

    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        station: String? = nil,
        additionalFields: [String: String] = [:]
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.station = station
        self.additionalFields = additionalFields
    }
}

public struct MonoAudioStreamVariant: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var bitrateBitsPerSecond: Int?
    public var sampleRateHz: Int?
    public var channelCount: Int?
    public var codec: String?

    public init(
        id: String,
        bitrateBitsPerSecond: Int? = nil,
        sampleRateHz: Int? = nil,
        channelCount: Int? = nil,
        codec: String? = nil
    ) {
        self.id = id
        self.bitrateBitsPerSecond = bitrateBitsPerSecond
        self.sampleRateHz = sampleRateHz
        self.channelCount = channelCount
        self.codec = codec
    }
}

public enum MonoAudioStreamValidationError: Error, Equatable, Sendable {
    case emptySourceID
    case missingURLScheme
    case missingHost
    case schemeMismatch(streamProtocol: MonoAudioStreamProtocol, actualScheme: String)
    case incompatibleFormat(streamProtocol: MonoAudioStreamProtocol, format: MonoAudioStreamFormat)
    case invalidHeaderName(String)
    case invalidHeaderValue(String)
    case invalidUserAgent
    case invalidTimeout(name: String, value: Int)
    case invalidReconnectDelay(Int)
    case rtspOptionOnNonRTSPSource
}
