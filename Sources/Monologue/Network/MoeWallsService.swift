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

private final class MoeWallsDownloadOperation: @unchecked Sendable {
    private let session: URLSession
    private let destinationURL: URL
    private let progressHandler: @Sendable (Double) -> Void
    private let lock = NSLock()

    private var continuation: CheckedContinuation<URLResponse, Error>?
    private var downloadTask: URLSessionDownloadTask?
    private var progressTask: Task<Void, Never>?

    init(
        session: URLSession,
        destinationURL: URL,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) {
        self.session = session
        self.destinationURL = destinationURL
        self.progressHandler = progressHandler
    }

    func start(request: URLRequest) async throws -> URLResponse {
        try Task.checkCancellation()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                let task = session.downloadTask(with: request) { [weak self] location, response, error in
                    self?.finish(location: location, response: response, error: error)
                }

                lock.lock()
                self.continuation = continuation
                downloadTask = task
                lock.unlock()

                progressHandler(0)
                startProgressPolling(for: task)
                task.resume()
            }
        } onCancel: {
            cancel()
        }
    }

    private func startProgressPolling(for task: URLSessionDownloadTask) {
        let progressHandler = progressHandler
        let pollingTask = Task.detached(priority: .utility) {
            var lastReportedProgress = -1.0

            while !Task.isCancelled {
                let state = task.state
                if state == .completed || state == .canceling { return }

                let expected = task.countOfBytesExpectedToReceive
                if expected > 0 {
                    let received = max(task.countOfBytesReceived, 0)
                    let fraction = min(max(Double(received) / Double(expected), 0), 1)
                    if fraction >= 1 || fraction - lastReportedProgress >= 0.005 {
                        lastReportedProgress = fraction
                        progressHandler(fraction)
                    }
                }

                do {
                    try await Task.sleep(nanoseconds: 100_000_000)
                } catch {
                    return
                }
            }
        }

        lock.lock()
        progressTask = pollingTask
        lock.unlock()
    }

    private func finish(location: URL?, response: URLResponse?, error: Error?) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        downloadTask = nil
        let progressTask = progressTask
        self.progressTask = nil
        lock.unlock()

        progressTask?.cancel()

        do {
            if let error {
                if (error as? URLError)?.code == .cancelled {
                    throw CancellationError()
                }
                throw error
            }
            guard let location, let response else {
                throw MoeWallsServiceError.downloadUnavailable
            }

            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: location, to: destinationURL)
            progressHandler(1)
            continuation.resume(returning: response)
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            continuation.resume(throwing: error)
        }
    }

    private func cancel() {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        let downloadTask = downloadTask
        self.downloadTask = nil
        let progressTask = progressTask
        self.progressTask = nil
        lock.unlock()

        progressTask?.cancel()
        downloadTask?.cancel()
        try? FileManager.default.removeItem(at: destinationURL)
        continuation?.resume(throwing: CancellationError())
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

    func search(
        query: String,
        translatedQuery: String? = nil
    ) async throws -> [MoeWallsWallpaper] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try await dailyRecommendations() }

        var receivedValidResponse = false
        var candidates = Self.searchCandidates(for: trimmed)
        if let translated = translatedQuery?.trimmingCharacters(in: .whitespacesAndNewlines),
           !translated.isEmpty {
            candidates.insert(translated, at: 0)
        }
        var seenCandidates = Set<String>()
        candidates = candidates.filter { seenCandidates.insert($0.lowercased()).inserted }

        for candidate in candidates {
            try Task.checkCancellation()

            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.path = "/search"
            components?.queryItems = [URLQueryItem(name: "q", value: candidate)]
            guard let url = components?.url else { continue }

            do {
                // 搜索结果和首页内容变化频繁，不能复用 URLCache 中的旧 HTML。
                let html = try await loadHTML(
                    from: url,
                    cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
                )
                receivedValidResponse = true
                let wallpapers = Array(Self.parseWallpaperList(html, baseURL: baseURL).prefix(60))
                if !wallpapers.isEmpty { return wallpapers }
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError where error.code == .cancelled {
                throw CancellationError()
            } catch {
                continue
            }
        }

        if receivedValidResponse { throw MoeWallsServiceError.emptyResults }
        throw MoeWallsServiceError.invalidResponse
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
        quality: MoeWallsDownloadQuality,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
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

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("moewalls-\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        let operation = MoeWallsDownloadOperation(
            session: session,
            destinationURL: destination,
            progressHandler: progress
        )
        let response = try await operation.start(request: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              http.mimeType?.lowercased().contains("video") == true else {
            try? FileManager.default.removeItem(at: destination)
            throw MoeWallsServiceError.downloadUnavailable
        }

        return destination
    }

    private func loadHTML(
        from url: URL,
        cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = cachePolicy
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.7", forHTTPHeaderField: "Accept-Language")
        if cachePolicy != .returnCacheDataElseLoad {
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        }

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
        let strictResults = parseStrictWallpaperList(html, baseURL: baseURL)
        if !strictResults.isEmpty { return strictResults }
        return parseFlexibleWallpaperList(html, baseURL: baseURL)
    }

    private static func parseStrictWallpaperList(_ html: String, baseURL: URL) -> [MoeWallsWallpaper] {
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

    /// 兼容站点调整属性顺序、单双引号和 class 写法后的卡片结构。
    private static func parseFlexibleWallpaperList(_ html: String, baseURL: URL) -> [MoeWallsWallpaper] {
        guard let expression = try? NSRegularExpression(
            pattern: #"<a\b([^>]*)>(.*?)</a>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var seen = Set<String>()
        var wallpapers: [MoeWallsWallpaper] = []

        for match in expression.matches(in: html, range: range) {
            let attributes = capture(match, group: 1, in: html) ?? ""
            let body = capture(match, group: 2, in: html) ?? ""
            let titleAttribute = firstAttribute(named: "title", in: attributes) ?? ""
            let cardTitle = firstTextCapture(
                in: body,
                pattern: #"<span\b[^>]*\bclass\s*=\s*(?:[\"'][^\"']*\bttl\b[^\"']*[\"']|ttl)[^>]*>(.*?)</span>"#
            )

            guard cardTitle != nil || titleAttribute.range(
                of: #"(?:live|animated)\s+wallpaper"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil,
            let href = firstAttribute(named: "href", in: attributes),
            let detailURL = absoluteURL(href, baseURL: baseURL),
            detailURL.host == baseURL.host else { continue }

            let slug = detailURL.lastPathComponent
            guard !slug.isEmpty, !seen.contains(slug) else { continue }

            let thumbnailPath = firstURLCapture(
                in: body,
                pattern: #"<source\b[^>]*\bsrcset\s*=\s*(?:\"([^\"]+)\"|'([^']+)'|([^\s>]+))"#
            ) ?? firstURLCapture(
                in: body,
                pattern: #"<img\b[^>]*\bsrc\s*=\s*(?:\"([^\"]+)\"|'([^']+)'|([^\s>]+))"#
            )
            guard let thumbnailPath,
                  let thumbnailURL = absoluteURL(thumbnailPath, baseURL: baseURL) else { continue }

            let title = cardTitle ?? titleAttribute.replacingOccurrences(
                of: #"\s+(?:live|animated)\s+wallpaper$"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            let quality = firstTextCapture(
                in: body,
                pattern: #"<span\b[^>]*\bclass\s*=\s*(?:[\"'][^\"']*\bfrm\b[^\"']*[\"']|frm)[^>]*>(.*?)</span>"#
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
        for group in 1..<match.numberOfRanges {
            if let result = capture(match, group: group, in: value) { return result }
        }
        return nil
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

    private static func firstAttribute(named name: String, in attributes: String) -> String? {
        firstURLCapture(
            in: attributes,
            pattern: #"\b\#(name)\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>]+))"#
        )
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

    private static let searchAliases: [(String, String)] = [
            ("崩坏星穹铁道", "honkai star rail"), ("星穹铁道", "honkai star rail"),
            ("进击的巨人", "attack on titan"), ("进击巨人", "attack on titan"),
            ("鬼灭之刃", "demon slayer"), ("咒术回战", "jujutsu kaisen"),
            ("初音未来", "hatsune miku"), ("英雄联盟", "league of legends"),
            ("赛博朋克", "cyberpunk"), ("绝区零", "zenless zone zero"),
            ("原神", "genshin impact"), ("鸣潮", "wuthering waves"),
            ("火影忍者", "naruto"), ("海贼王", "one piece"),
            ("宝可梦", "pokemon"), ("动漫", "anime"), ("二次元", "anime"),
            ("动画", "anime"), ("游戏", "games"), ("自然", "nature"),
            ("风景", "landscape"), ("汽车", "car"), ("电影", "tv"),
            ("影视", "tv"), ("宇宙", "space"), ("太空", "space"),
            ("科技", "technology"), ("恐怖", "horror"), ("足球", "football"),
            ("日本", "japan"), ("少女", "anime girl"), ("女孩", "anime girl"),
            ("森林", "forest"), ("冬季", "winter"), ("冬天", "winter"),
            ("山脉", "mountain"), ("圣诞", "christmas"), ("万圣节", "halloween"),
            ("动物", "animal"), ("幻想", "fantasy"), ("奇幻", "fantasy"),
            ("星空", "starry sky"), ("夜空", "night sky"), ("银河", "galaxy"),
            ("极光", "aurora"), ("月亮", "moon"), ("海洋", "ocean"),
            ("沙滩", "beach"), ("日落", "sunset"), ("夜景", "night"),
            ("雨天", "rain"), ("城市", "city"), ("天空", "sky"),
            ("云朵", "clouds")
        ]

    static func localEnglishTranslation(for query: String) -> String? {
        var translated = query
        for (source, target) in searchAliases {
            translated = translated.replacingOccurrences(of: source, with: target)
        }
        return translated == query ? nil : translated
    }

    private static func searchCandidates(for query: String) -> [String] {

        var results = [query]
        if let translated = localEnglishTranslation(for: query) { results.append(translated) }

        if let latin = query.applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !latin.isEmpty,
           latin.caseInsensitiveCompare(query) != .orderedSame {
            results.append(latin)
        }

        var seen = Set<String>()
        return results.filter { seen.insert($0.lowercased()).inserted }
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
