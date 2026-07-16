import Foundation

struct MoeWallsWallpaper: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detailURL: URL
    let thumbnailURL: URL
    let quality: String
}

struct MoeWallsWallpaperDetail: Equatable, Sendable {
    let wallpaper: MoeWallsWallpaper
    let previewURL: URL
    let hdDownloadURL: URL
    let fourKDownloadURL: URL?
}

enum MoeWallsDownloadQuality: String, Sendable {
    case hd
    case fourK
}

enum MoeWallsServiceError: LocalizedError, Sendable {
    case invalidResponse
    case emptyResults
    case detailUnavailable
    case downloadUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return String(localized: "moewalls_error_network")
        case .emptyResults:
            return String(localized: "moewalls_empty")
        case .detailUnavailable:
            return String(localized: "moewalls_error_detail")
        case .downloadUnavailable:
            return String(localized: "moewalls_error_download")
        }
    }
}

/// MoeWalls 现已跳转到 MotionBGS。网络层仍以 MoeWalls 为产品来源名，
/// 把站点 HTML 变化隔离在单一解析服务内。
actor MoeWallsService {
    static let shared = MoeWallsService()

    private let baseURL = URL(string: "https://motionbgs.com")!
    private let session: URLSession
    private var dailyCache: (day: String, wallpapers: [MoeWallsWallpaper])?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func dailyRecommendations(forceRefresh: Bool = false) async throws -> [MoeWallsWallpaper] {
        let day = Self.dayIdentifier()
        if !forceRefresh, let dailyCache, dailyCache.day == day {
            return dailyCache.wallpapers
        }

        let html = try await loadHTML(from: baseURL)
        let parsed = Self.parseWallpaperList(html, baseURL: baseURL)
        guard !parsed.isEmpty else { throw MoeWallsServiceError.emptyResults }

        let candidates = Array(parsed.prefix(48))
        let selected = candidates
            .sorted {
                Self.stableRank(day: day, identifier: $0.id)
                    < Self.stableRank(day: day, identifier: $1.id)
            }
            .prefix(12)
        let wallpapers = Array(selected)
        dailyCache = (day, wallpapers)
        return wallpapers
    }

    func search(query: String) async throws -> [MoeWallsWallpaper] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try await dailyRecommendations() }

        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "q", value: trimmed)]
        guard let url = components?.url else { throw MoeWallsServiceError.invalidResponse }

        let html = try await loadHTML(from: url)
        let wallpapers = Array(Self.parseWallpaperList(html, baseURL: baseURL).prefix(60))
        guard !wallpapers.isEmpty else { throw MoeWallsServiceError.emptyResults }
        return wallpapers
    }

    func detail(for wallpaper: MoeWallsWallpaper) async throws -> MoeWallsWallpaperDetail {
        let html = try await loadHTML(from: wallpaper.detailURL)

        guard let previewPath = Self.firstURLCapture(
            in: html,
            pattern: #"<source\s+src=(?:\"([^\"]+\.mp4)\"|([^\s>]+\.mp4))\s+type=video/mp4"#
        ),
        let previewURL = Self.absoluteURL(previewPath, baseURL: baseURL),
        let hdPath = Self.firstURLCapture(
            in: html,
            pattern: #"href=(?:\"([^\"]*/dl/hd/\d+/?)[\"]|([^\s>]*?/dl/hd/\d+/?))"#
        ),
        let hdURL = Self.absoluteURL(hdPath, baseURL: baseURL) else {
            throw MoeWallsServiceError.detailUnavailable
        }

        let fourKURL = Self.firstURLCapture(
            in: html,
            pattern: #"href=(?:\"([^\"]*/dl/4k/\d+/?)[\"]|([^\s>]*?/dl/4k/\d+/?))"#
        ).flatMap { Self.absoluteURL($0, baseURL: baseURL) }

        return MoeWallsWallpaperDetail(
            wallpaper: wallpaper,
            previewURL: previewURL,
            hdDownloadURL: hdURL,
            fourKDownloadURL: fourKURL
        )
    }

    func download(
        detail: MoeWallsWallpaperDetail,
        quality: MoeWallsDownloadQuality
    ) async throws -> URL {
        let remoteURL: URL
        switch quality {
        case .hd:
            remoteURL = detail.hdDownloadURL
        case .fourK:
            guard let fourKDownloadURL = detail.fourKDownloadURL else {
                throw MoeWallsServiceError.downloadUnavailable
            }
            remoteURL = fourKDownloadURL
        }

        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 180
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(detail.wallpaper.detailURL.absoluteString, forHTTPHeaderField: "Referer")

        let (downloadedURL, response) = try await session.download(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              http.mimeType?.lowercased().contains("video") == true else {
            throw MoeWallsServiceError.downloadUnavailable
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("moewalls-\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: downloadedURL, to: destination)
        return destination
    }

    private func loadHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.7", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8),
              !html.isEmpty else {
            throw MoeWallsServiceError.invalidResponse
        }
        return html
    }

    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Monologue/1.0"

    private static func parseWallpaperList(_ html: String, baseURL: URL) -> [MoeWallsWallpaper] {
        let pattern = #"<a\s+title=\"([^\"]*(?:live|animated)\s+wallpaper)\"\s+href=(?:\"([^\"]+)\"|([^\s>]+))[^>]*>(.*?)</a>"#
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var seen = Set<String>()
        var wallpapers: [MoeWallsWallpaper] = []

        for match in expression.matches(in: html, range: range) {
            let titleAttribute = capture(match, group: 1, in: html) ?? ""
            let href = capture(match, group: 2, in: html)
                ?? capture(match, group: 3, in: html)
                ?? ""
            let body = capture(match, group: 4, in: html) ?? ""
            guard let detailURL = absoluteURL(href, baseURL: baseURL) else { continue }

            let slug = detailURL.lastPathComponent
            guard !slug.isEmpty, !seen.contains(slug) else { continue }

            guard let thumbnailPath = firstURLCapture(
                in: body,
                pattern: #"<img\b[^>]*\bsrc=(?:\"([^\"]+)\"|([^\s>]+))"#
            ),
            let thumbnailURL = absoluteURL(thumbnailPath, baseURL: baseURL) else { continue }

            let title = firstTextCapture(
                in: body,
                pattern: #"<span\s+class=ttl>(.*?)</span>"#
            ) ?? titleAttribute.replacingOccurrences(
                of: #"\s+(?:live|animated)\s+wallpaper$"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            let quality = firstTextCapture(
                in: body,
                pattern: #"<span\s+class=frm>\s*([^<]+?)\s*</span>"#
            ) ?? "HD"

            seen.insert(slug)
            wallpapers.append(
                MoeWallsWallpaper(
                    id: slug,
                    title: decodeHTML(title),
                    detailURL: detailURL,
                    thumbnailURL: thumbnailURL,
                    quality: decodeHTML(quality).trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }
        return wallpapers
    }

    private static func firstURLCapture(in value: String, pattern: String) -> String? {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ),
        let match = expression.firstMatch(
            in: value,
            range: NSRange(value.startIndex..<value.endIndex, in: value)
        ) else { return nil }
        return capture(match, group: 1, in: value) ?? capture(match, group: 2, in: value)
    }

    private static func firstTextCapture(in value: String, pattern: String) -> String? {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ),
        let match = expression.firstMatch(
            in: value,
            range: NSRange(value.startIndex..<value.endIndex, in: value)
        ) else { return nil }
        return capture(match, group: 1, in: value)
    }

    private static func capture(_ match: NSTextCheckingResult, group: Int, in value: String) -> String? {
        guard group < match.numberOfRanges,
              let range = Range(match.range(at: group), in: value) else { return nil }
        return String(value[range])
    }

    private static func absoluteURL(_ value: String, baseURL: URL) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed, relativeTo: baseURL)?.absoluteURL
    }

    private static func decodeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func dayIdentifier() -> String {
        let components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day],
            from: Date()
        )
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private static func stableRank(day: String, identifier: String) -> UInt64 {
        "\(day)|\(identifier)".utf8.reduce(14_695_981_039_346_656_037) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}
