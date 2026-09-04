import Foundation

/// Non-sensitive metadata describing the input selected for silent video playback.
public struct SilentVideoInputInfo: Equatable, Sendable {
    public let sourceWasMasterPlaylist: Bool
    public let selectedWidth: Int?
    public let selectedHeight: Int?
    public let selectedCodec: String?

    public init(
        sourceWasMasterPlaylist: Bool,
        selectedWidth: Int?,
        selectedHeight: Int?,
        selectedCodec: String?
    ) {
        self.sourceWasMasterPlaylist = sourceWasMasterPlaylist
        self.selectedWidth = selectedWidth
        self.selectedHeight = selectedHeight
        self.selectedCodec = selectedCodec
    }
}

struct ResolvedSilentVideoInput: Sendable {
    let url: URL
    let info: SilentVideoInputInfo
}

/// Resolves an HLS master playlist to one practical square AVC rendition before
/// FFmpeg probes it. Apple Music master playlists contain dozens of 360–2160px
/// alternatives; passing the master directly makes `avformat_find_stream_info`
/// open every rendition before a first frame can be decoded.
actor SilentVideoInputResolver {
    static let shared = SilentVideoInputResolver()

    private var cache: [URL: ResolvedSilentVideoInput] = [:]
    private var inFlight: [URL: Task<ResolvedSilentVideoInput, Error>] = [:]
    private let maximumCacheEntries = 32

    func resolve(_ sourceURL: URL) async throws -> ResolvedSilentVideoInput {
        guard sourceURL.pathExtension.lowercased() == "m3u8" else {
            return Self.directInput(sourceURL)
        }
        if let cached = cache[sourceURL] { return cached }
        if let task = inFlight[sourceURL] { return try await task.value }

        let task = Task {
            try await Self.resolvePlaylist(sourceURL)
        }
        inFlight[sourceURL] = task

        do {
            let resolved = try await task.value
            inFlight[sourceURL] = nil
            cache[sourceURL] = resolved
            if cache.count > maximumCacheEntries, let oldestKey = cache.keys.first {
                cache.removeValue(forKey: oldestKey)
            }
            return resolved
        } catch {
            inFlight[sourceURL] = nil
            throw error
        }
    }

    private static func resolvePlaylist(_ sourceURL: URL) async throws -> ResolvedSilentVideoInput {
        var request = URLRequest(url: sourceURL)
        request.timeoutInterval = 12
        request.setValue(
            "application/vnd.apple.mpegurl, application/x-mpegURL, text/plain",
            forHTTPHeaderField: "Accept"
        )
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw SilentVideoInputResolverError.invalidHTTPResponse
        }
        guard data.count <= 2_000_000,
              let manifest = String(data: data, encoding: .utf8) else {
            throw SilentVideoInputResolverError.invalidManifest
        }

        let finalURL = httpResponse.url ?? sourceURL
        guard let selected = selectedVariant(in: manifest, baseURL: finalURL) else {
            return directInput(finalURL)
        }

        return ResolvedSilentVideoInput(
            url: selected.url,
            info: SilentVideoInputInfo(
                sourceWasMasterPlaylist: true,
                selectedWidth: selected.width,
                selectedHeight: selected.height,
                selectedCodec: selected.codec
            )
        )
    }

    static func selectedVariant(in manifest: String, baseURL: URL) -> HLSVideoVariant? {
        let lines = manifest
            .split(whereSeparator: \Character.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        var variants: [HLSVideoVariant] = []
        var lineIndex = 0
        while lineIndex < lines.count {
            let line = lines[lineIndex]
            guard line.hasPrefix("#EXT-X-STREAM-INF:") else {
                lineIndex += 1
                continue
            }

            let attributes = parseAttributeList(
                String(line.dropFirst("#EXT-X-STREAM-INF:".count))
            )
            var uriIndex = lineIndex + 1
            while uriIndex < lines.count, lines[uriIndex].hasPrefix("#") {
                uriIndex += 1
            }
            guard uriIndex < lines.count,
                  !lines[uriIndex].isEmpty,
                  let variantURL = URL(string: lines[uriIndex], relativeTo: baseURL)?.absoluteURL else {
                lineIndex += 1
                continue
            }

            let dimensions = parseResolution(attributes["RESOLUTION"])
            variants.append(
                HLSVideoVariant(
                    url: variantURL,
                    width: dimensions?.width,
                    height: dimensions?.height,
                    codec: attributes["CODECS"],
                    bandwidth: Int(attributes["AVERAGE-BANDWIDTH"] ?? attributes["BANDWIDTH"] ?? "")
                )
            )
            lineIndex = uriIndex + 1
        }

        return variants.min { variantScore($0) < variantScore($1) }
    }

    private static func parseAttributeList(_ value: String) -> [String: String] {
        var fields: [String] = []
        var current = ""
        var isInsideQuotes = false

        for character in value {
            if character == "\"" {
                isInsideQuotes.toggle()
                current.append(character)
            } else if character == ",", !isInsideQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { fields.append(current) }

        return fields.reduce(into: [:]) { result, field in
            guard let separator = field.firstIndex(of: "=") else { return }
            let key = field[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            var item = field[field.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if item.hasPrefix("\"") && item.hasSuffix("\"") && item.count >= 2 {
                item.removeFirst()
                item.removeLast()
            }
            result[key.uppercased()] = item
        }
    }

    private static func parseResolution(_ value: String?) -> (width: Int, height: Int)? {
        guard let value else { return nil }
        let components = value.lowercased().split(separator: "x", maxSplits: 1)
        guard components.count == 2,
              let width = Int(components[0]),
              let height = Int(components[1]),
              width > 0,
              height > 0 else {
            return nil
        }
        return (width, height)
    }

    private static func variantScore(_ variant: HLSVideoVariant) -> Double {
        guard let width = variant.width, let height = variant.height else {
            return 1_000_000
        }

        let aspectPenalty = abs(Double(width) / Double(height) - 1) * 100_000
        let targetResolutionPenalty = Double(abs(max(width, height) - 960)) * 10
        let oversizedPenalty = max(0, Double(max(width, height) - 1080)) * 100
        let normalizedCodec = variant.codec?.lowercased() ?? ""
        let codecPenalty: Double
        if normalizedCodec.contains("avc1") {
            codecPenalty = 0
        } else if normalizedCodec.contains("hvc1") || normalizedCodec.contains("hev1") {
            codecPenalty = 2_000
        } else {
            codecPenalty = 8_000
        }
        let bandwidthPenalty = Double(variant.bandwidth ?? 0) / 20_000

        return aspectPenalty
            + targetResolutionPenalty
            + oversizedPenalty
            + codecPenalty
            + bandwidthPenalty
    }

    private static func directInput(_ url: URL) -> ResolvedSilentVideoInput {
        ResolvedSilentVideoInput(
            url: url,
            info: SilentVideoInputInfo(
                sourceWasMasterPlaylist: false,
                selectedWidth: nil,
                selectedHeight: nil,
                selectedCodec: nil
            )
        )
    }
}

struct HLSVideoVariant: Equatable, Sendable {
    let url: URL
    let width: Int?
    let height: Int?
    let codec: String?
    let bandwidth: Int?
}

private enum SilentVideoInputResolverError: LocalizedError {
    case invalidHTTPResponse
    case invalidManifest

    var errorDescription: String? {
        switch self {
        case .invalidHTTPResponse:
            return "The HLS playlist request returned an invalid response"
        case .invalidManifest:
            return "The HLS playlist is invalid"
        }
    }
}
