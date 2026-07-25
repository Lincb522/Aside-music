import Foundation
import SwiftUI

// MARK: - 在线字体数据

enum OnlineFontSource: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all
    case fontTianxia
    case zeoSeven
    case googleFonts
    case fontsource
    case maoken
    case hundredFont

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return String(localized: "全部来源")
        case .fontTianxia:
            return String(localized: "字体天下")
        case .zeoSeven:
            return "ZeoSeven"
        case .googleFonts:
            return "Google Fonts"
        case .fontsource:
            return "Fontsource"
        case .maoken:
            return String(localized: "猫啃网")
        case .hundredFont:
            return "100font"
        }
    }

    var siteURL: URL {
        switch self {
        case .all:
            return URL(string: "https://fonts.zeoseven.com/")!
        case .fontTianxia:
            return URL(string: "https://www.fonts.net.cn/")!
        case .zeoSeven:
            return URL(string: "https://fonts.zeoseven.com/")!
        case .googleFonts:
            return URL(string: "https://fonts.google.com/")!
        case .fontsource:
            return URL(string: "https://fontsource.org/")!
        case .maoken:
            return URL(string: "https://www.maoken.com/all-fonts")!
        case .hundredFont:
            return URL(string: "https://www.100font.com/")!
        }
    }
}

struct OnlineFontCategory: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let sample: String
    let pathTemplate: String

    func path(page: Int) -> String {
        pathTemplate.replacingOccurrences(of: "{page}", with: String(max(1, page)))
    }

    static let all = OnlineFontCategory(
        id: "all",
        title: String(localized: "全部字体"),
        sample: "字",
        pathTemplate: "/fonts-zh-{page}.html"
    )

    static let library: [OnlineFontCategory] = [
        .all,
        OnlineFontCategory(id: "english", title: String(localized: "英文字体"), sample: "Aa", pathTemplate: "/fonts-en-{page}.html"),
        OnlineFontCategory(id: "handwriting", title: String(localized: "手写"), sample: "写", pathTemplate: "/fonts-zh/tag-shouxie2-{page}.html"),
        OnlineFontCategory(id: "poster", title: String(localized: "标题"), sample: "题", pathTemplate: "/fonts-zh/tag-haibao-{page}.html"),
        OnlineFontCategory(id: "song", title: String(localized: "宋体"), sample: "宋", pathTemplate: "/fonts-zh/tag-songti-{page}.html"),
        OnlineFontCategory(id: "sans", title: String(localized: "黑体"), sample: "黑", pathTemplate: "/fonts-zh/tag-heiti-{page}.html"),
        OnlineFontCategory(id: "calligraphy", title: String(localized: "书法"), sample: "墨", pathTemplate: "/fonts-zh/tag-shufa2-{page}.html"),
        OnlineFontCategory(id: "pixel", title: String(localized: "像素"), sample: "像", pathTemplate: "/fonts-zh/tag-xiangsu-{page}.html")
    ]
}

struct OnlineFontItem: Identifiable, Hashable, Sendable {
    let id: String
    let providerID: String
    let source: OnlineFontSource
    let name: String
    let detailURL: URL
    let canDirectDownload: Bool
    let requiresCommercialLicense: Bool
    let downloadURL: URL?

    init(
        providerID: String,
        source: OnlineFontSource,
        name: String,
        detailURL: URL,
        canDirectDownload: Bool,
        requiresCommercialLicense: Bool,
        downloadURL: URL? = nil
    ) {
        self.providerID = providerID
        self.source = source
        self.name = name
        self.detailURL = detailURL
        self.canDirectDownload = canDirectDownload
        self.requiresCommercialLicense = requiresCommercialLicense
        self.downloadURL = downloadURL
        self.id = "\(source.rawValue):\(providerID)"
    }
}

enum OnlineFontLibraryError: LocalizedError {
    case invalidResponse
    case emptyResult
    case downloadUnavailable
    case purchaseRequired

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return String(localized: "字体列表暂时无法加载")
        case .emptyResult:
            return String(localized: "没有找到相关字体")
        case .downloadUnavailable:
            return String(localized: "该字体暂时无法直接下载")
        case .purchaseRequired:
            return String(localized: "该字体需要先完成购买或授权")
        }
    }
}

private final class OnlineFontFileDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destinationURL: URL
    private let progressHandler: @Sendable (Double) -> Void
    private var continuation: CheckedContinuation<URL, Error>?
    private var session: URLSession?
    private var completedURL: URL?
    private var moveError: Error?

    private enum PayloadKind: String {
        case zip
        case ttf
        case otf
        case ttc

        static func detect(at url: URL) throws -> PayloadKind? {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            guard let data = try handle.read(upToCount: 4), data.count == 4 else {
                return nil
            }
            let bytes = [UInt8](data)
            if bytes == [0x50, 0x4B, 0x03, 0x04]
                || bytes == [0x50, 0x4B, 0x05, 0x06]
                || bytes == [0x50, 0x4B, 0x07, 0x08] {
                return .zip
            }
            if bytes == [0x00, 0x01, 0x00, 0x00]
                || bytes == Array("true".utf8)
                || bytes == Array("typ1".utf8) {
                return .ttf
            }
            if bytes == Array("OTTO".utf8) { return .otf }
            if bytes == Array("ttcf".utf8) { return .ttc }
            return nil
        }
    }

    init(destinationURL: URL, progress: @escaping @Sendable (Double) -> Void) {
        self.destinationURL = destinationURL
        self.progressHandler = progress
    }

    func start(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 180
            configuration.waitsForConnectivity = true
            configuration.httpAdditionalHeaders = [
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1",
                "Accept": "application/zip, font/ttf, font/otf, application/octet-stream, */*",
                "Referer": "https://www.fonts.net.cn/"
            ]
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            queue.qualityOfService = .utility
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
            self.session = session
            progressHandler(0)
            session.downloadTask(with: url).resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        progressHandler(
            min(1, max(0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            guard let response = downloadTask.response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode),
                  let kind = try PayloadKind.detect(at: location)
            else {
                throw OnlineFontLibraryError.downloadUnavailable
            }
            let resolvedURL = destinationURL
                .deletingPathExtension()
                .appendingPathExtension(kind.rawValue)
            if FileManager.default.fileExists(atPath: resolvedURL.path) {
                try FileManager.default.removeItem(at: resolvedURL)
            }
            try FileManager.default.moveItem(at: location, to: resolvedURL)
            completedURL = resolvedURL
            progressHandler(1)
        } catch {
            moveError = error
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        defer {
            self.session?.finishTasksAndInvalidate()
            self.session = nil
        }
        guard let continuation else { return }
        self.continuation = nil

        if let error {
            continuation.resume(throwing: error)
        } else if let moveError {
            continuation.resume(throwing: moveError)
        } else if let http = task.response as? HTTPURLResponse,
                  !(200..<300).contains(http.statusCode) {
            continuation.resume(throwing: OnlineFontLibraryError.downloadUnavailable)
        } else if let completedURL {
            continuation.resume(returning: completedURL)
        } else {
            continuation.resume(throwing: OnlineFontLibraryError.downloadUnavailable)
        }
    }
}

private actor FontTianxiaService {
    static let shared = FontTianxiaService()

    private static let origin = URL(string: "https://www.fonts.net.cn")!
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 24
        configuration.timeoutIntervalForResource = 90
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1",
            "Accept-Language": "zh-CN,zh-Hans;q=0.9"
        ]
        return URLSession(configuration: configuration)
    }()

    func fonts(in category: OnlineFontCategory, page: Int) async throws -> [OnlineFontItem] {
        let path = category.path(page: page)
        guard let url = URL(string: path, relativeTo: Self.origin) else {
            throw OnlineFontLibraryError.invalidResponse
        }
        return try await fetchList(url: url)
    }

    func search(keyword: String, page: Int) async throws -> [OnlineFontItem] {
        guard var components = URLComponents(url: Self.origin.appendingPathComponent("font-search-result.html"), resolvingAgainstBaseURL: false) else {
            throw OnlineFontLibraryError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: keyword),
            URLQueryItem(name: "page", value: String(max(1, page)))
        ]
        guard let url = components.url else {
            throw OnlineFontLibraryError.invalidResponse
        }
        return try await fetchList(url: url)
    }

    func downloadFont(
        id: String,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let endpoint = Self.origin.appendingPathComponent("api/font-download/url")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(Self.origin.absoluteString, forHTTPHeaderField: "Origin")
        request.setValue(Self.origin.appendingPathComponent("fonts-zh-1.html").absoluteString, forHTTPHeaderField: "Referer")
        request.httpBody = "fontId=\(Self.formEncode(id))".data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw OnlineFontLibraryError.invalidResponse
        }

        guard (object["success"] as? NSNumber)?.boolValue == true else {
            let code = object["code"] as? String ?? ""
            if code.localizedCaseInsensitiveContains("purchase")
                || code.localizedCaseInsensitiveContains("license")
                || code.localizedCaseInsensitiveContains("pay") {
                throw OnlineFontLibraryError.purchaseRequired
            }
            throw OnlineFontLibraryError.downloadUnavailable
        }

        guard let payload = object["data"] as? [String: Any],
              var rawURL = payload["url"] as? String
        else {
            throw OnlineFontLibraryError.downloadUnavailable
        }
        if rawURL.hasPrefix("//") { rawURL = "https:" + rawURL }
        guard let downloadURL = URL(string: rawURL) else {
            throw OnlineFontLibraryError.downloadUnavailable
        }

        let preparedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OnlineFont-\(UUID().uuidString)")
            .appendingPathExtension("download")
        let downloader = OnlineFontFileDownloader(
            destinationURL: preparedURL,
            progress: progress
        )
        return try await downloader.start(url: downloadURL)
    }

    private func fetchList(url: URL) async throws -> [OnlineFontItem] {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8)
        else {
            throw OnlineFontLibraryError.invalidResponse
        }
        return Self.parseList(html: html)
    }

    private static func parseList(html: String) -> [OnlineFontItem] {
        let blocks = captures(
            pattern: #"<li[^>]*>\s*<div class=\"site_font_list_item_head\">([\s\S]*?)</li>"#,
            in: html
        )

        return blocks.compactMap { block in
            guard let id = firstCapture(pattern: #"data-font-id=\"([0-9]+)\""#, in: block),
                  let name = firstCapture(pattern: #"class=\"site_font_name\"[^>]*title=\"([^\"]+)\""#, in: block),
                  let detailPath = firstCapture(pattern: #"href=\"(/font-[^\"]+\.html)\""#, in: block),
                  let detailURL = URL(string: detailPath, relativeTo: URL(string: "https://www.fonts.net.cn")!)?.absoluteURL
            else { return nil }

            return OnlineFontItem(
                providerID: id,
                source: .fontTianxia,
                name: decodeHTML(name),
                detailURL: detailURL,
                canDirectDownload: block.contains("data-app-button=\"font-download\""),
                requiresCommercialLicense: block.contains("商用须授权") || block.contains("data-app-button=\"font-license\""),
                downloadURL: nil
            )
        }
    }

    private static func captures(pattern: String, in value: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex..., in: value)
        return expression.matches(in: value, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: value)
            else { return nil }
            return String(value[range])
        }
    }

    private static func firstCapture(pattern: String, in value: String) -> String? {
        captures(pattern: pattern, in: value).first
    }

    private static func decodeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    private static func formEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
    }
}

private actor OnlineFontDirectoryService {
    static let shared = OnlineFontDirectoryService()

    private let fontTianxia = FontTianxiaService.shared
    private let fontsource = FontsourceFontService()
    private let zeoSeven = ZeoSevenFontService()
    private let maoken = HTMLFontDirectoryService(
        source: .maoken,
        origin: URL(string: "https://www.maoken.com")!,
        listPath: "/all-fonts",
        searchPath: "/?s={query}",
        linkPattern: #"href=\"(https://www\.maoken\.com/(?:freefonts/)?[^\"]+?\.html|https://www\.maoken\.com/\?p=[0-9]+)\"[^>]*>([^<]{2,80})"#,
        canDirectDownload: false
    )
    private let hundredFont = HTMLFontDirectoryService(
        source: .hundredFont,
        origin: URL(string: "https://www.100font.com")!,
        listPath: "/forum-1-1.htm?tagids=0_4_0_0",
        searchPath: "/forum-1-1.htm?tagids=0_4_0_0",
        linkPattern: #"href=\"(thread-[0-9]+\.htm)\"[^>]*>(?:【([^】]{2,50})】)?([^<]{0,80})"#,
        canDirectDownload: false
    )

    func fonts(in category: OnlineFontCategory, source: OnlineFontSource, page: Int) async throws -> [OnlineFontItem] {
        switch source {
        case .all:
            async let tianxia = try? fontTianxia.fonts(in: category, page: page)
            async let zeo = try? zeoSeven.fonts(in: category, page: page)
            async let google = try? fontsource.fonts(in: category, source: .googleFonts, page: page)
            async let fontsourceItems = try? fontsource.fonts(in: category, source: .fontsource, page: page)
            async let mao = try? maoken.fonts(in: category, page: page)
            async let hundred = try? hundredFont.fonts(in: category, page: page)
            return Self.deduplicated(
                (await tianxia ?? [])
                + (await zeo ?? [])
                + (await google ?? [])
                + (await fontsourceItems ?? [])
                + (await mao ?? [])
                + (await hundred ?? [])
            )
        case .fontTianxia:
            return try await fontTianxia.fonts(in: category, page: page)
        case .zeoSeven:
            return try await zeoSeven.fonts(in: category, page: page)
        case .googleFonts:
            return try await fontsource.fonts(in: category, source: .googleFonts, page: page)
        case .fontsource:
            return try await fontsource.fonts(in: category, source: .fontsource, page: page)
        case .maoken:
            return try await maoken.fonts(in: category, page: page)
        case .hundredFont:
            return try await hundredFont.fonts(in: category, page: page)
        }
    }

    func search(keyword: String, source: OnlineFontSource, page: Int) async throws -> [OnlineFontItem] {
        switch source {
        case .all:
            async let tianxia = try? fontTianxia.search(keyword: keyword, page: page)
            async let zeo = try? zeoSeven.search(keyword: keyword, page: page)
            async let google = try? fontsource.search(keyword: keyword, source: .googleFonts, page: page)
            async let fontsourceItems = try? fontsource.search(keyword: keyword, source: .fontsource, page: page)
            async let mao = try? maoken.search(keyword: keyword, page: page)
            async let hundred = try? hundredFont.search(keyword: keyword, page: page)
            return Self.deduplicated(
                (await tianxia ?? [])
                + (await zeo ?? [])
                + (await google ?? [])
                + (await fontsourceItems ?? [])
                + (await mao ?? [])
                + (await hundred ?? [])
            )
        case .fontTianxia:
            return try await fontTianxia.search(keyword: keyword, page: page)
        case .zeoSeven:
            return try await zeoSeven.search(keyword: keyword, page: page)
        case .googleFonts:
            return try await fontsource.search(keyword: keyword, source: .googleFonts, page: page)
        case .fontsource:
            return try await fontsource.search(keyword: keyword, source: .fontsource, page: page)
        case .maoken:
            return try await maoken.search(keyword: keyword, page: page)
        case .hundredFont:
            return try await hundredFont.search(keyword: keyword, page: page)
        }
    }

    func downloadFont(
        item: OnlineFontItem,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        switch item.source {
        case .fontTianxia:
            return try await fontTianxia.downloadFont(id: item.providerID, progress: progress)
        case .googleFonts, .fontsource:
            return try await fontsource.downloadFont(item: item, progress: progress)
        case .all, .zeoSeven, .maoken, .hundredFont:
            guard let url = item.downloadURL else {
                throw OnlineFontLibraryError.downloadUnavailable
            }
            let preparedURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("OnlineFont-\(UUID().uuidString)")
                .appendingPathExtension("download")
            let downloader = OnlineFontFileDownloader(
                destinationURL: preparedURL,
                progress: progress
            )
            return try await downloader.start(url: url)
        }
    }

    private static func deduplicated(_ items: [OnlineFontItem]) -> [OnlineFontItem] {
        var seen = Set<String>()
        return items.filter { item in
            let key = "\(item.source.rawValue)-\(item.name.lowercased())"
            return seen.insert(key).inserted
        }
    }
}

private actor FontsourceFontService {
    private struct FontRecord: Decodable {
        let id: String
        let family: String
        let subsets: [String]
        let weights: [Int]
        let category: String?
        let license: String?
        let type: String?
    }

    private static let pageSize = 24
    private let origin = URL(string: "https://api.fontsource.org")!
    private var cachedRecords: [FontRecord]?

    func fonts(in category: OnlineFontCategory, source: OnlineFontSource, page: Int) async throws -> [OnlineFontItem] {
        let records = try await records()
            .filter { record in
                source == .googleFonts ? record.type == "google" : record.type != "google"
            }
            .filter { Self.matches(category: category, record: $0) }
        return Self.page(records, page: page).map { Self.item(from: $0, source: source) }
    }

    func search(keyword: String, source: OnlineFontSource, page: Int) async throws -> [OnlineFontItem] {
        let token = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let records = try await records()
            .filter { record in
                source == .googleFonts ? record.type == "google" : record.type != "google"
            }
            .filter { token.isEmpty || $0.family.lowercased().contains(token) || $0.id.contains(token) }
        return Self.page(records, page: page).map { Self.item(from: $0, source: source) }
    }

    func downloadFont(
        item: OnlineFontItem,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let endpoint = origin
            .appendingPathComponent("v1")
            .appendingPathComponent("fonts")
            .appendingPathComponent(item.providerID)
        let (data, response) = try await URLSession.shared.data(from: endpoint)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let downloadURL = Self.preferredDownloadURL(from: object)
        else {
            throw OnlineFontLibraryError.downloadUnavailable
        }
        let preparedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OnlineFont-\(UUID().uuidString)")
            .appendingPathExtension("download")
        let downloader = OnlineFontFileDownloader(destinationURL: preparedURL, progress: progress)
        return try await downloader.start(url: downloadURL)
    }

    private func records() async throws -> [FontRecord] {
        if let cachedRecords { return cachedRecords }
        let endpoint = origin.appendingPathComponent("v1/fonts")
        let (data, response) = try await URLSession.shared.data(from: endpoint)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else {
            throw OnlineFontLibraryError.invalidResponse
        }
        let records = try JSONDecoder().decode([FontRecord].self, from: data)
        cachedRecords = records
        return records
    }

    private static func item(from record: FontRecord, source: OnlineFontSource) -> OnlineFontItem {
        let detailBase = source == .googleFonts
            ? URL(string: "https://fonts.google.com/specimen/")!
            : URL(string: "https://fontsource.org/fonts/")!
        return OnlineFontItem(
            providerID: record.id,
            source: source,
            name: record.family,
            detailURL: detailBase.appendingPathComponent(record.id),
            canDirectDownload: true,
            requiresCommercialLicense: false,
            downloadURL: nil
        )
    }

    private static func matches(category: OnlineFontCategory, record: FontRecord) -> Bool {
        guard category.id != OnlineFontCategory.all.id else { return true }
        let categoryName = (record.category ?? "").lowercased()
        let subsets = record.subsets.map { $0.lowercased() }
        switch category.id {
        case "english":
            return subsets.contains("latin")
        case "sans":
            return categoryName.contains("sans")
        case "song":
            return categoryName.contains("serif")
        case "handwriting", "calligraphy":
            return categoryName.contains("handwriting") || categoryName.contains("script")
        case "poster":
            return categoryName.contains("display")
        default:
            return true
        }
    }

    private static func page(_ records: [FontRecord], page: Int) -> [FontRecord] {
        let start = max(0, (max(1, page) - 1) * pageSize)
        guard start < records.count else { return [] }
        return Array(records[start..<min(records.count, start + pageSize)])
    }

    private static func preferredDownloadURL(from object: [String: Any]) -> URL? {
        guard let variants = object["variants"] as? [String: Any] else { return nil }
        let preferredWeights = ["400", "500", "300", "700"]
        for weight in preferredWeights + variants.keys.sorted() {
            guard let weightValue = variants[weight] as? [String: Any],
                  let normal = weightValue["normal"] as? [String: Any]
            else { continue }
            let preferredSubsets = ["chinese-simplified", "latin", "latin-ext"]
            for subset in preferredSubsets + normal.keys.sorted() {
                guard let subsetValue = normal[subset] as? [String: Any],
                      let urlObject = subsetValue["url"] as? [String: Any],
                      let raw = (urlObject["ttf"] ?? urlObject["otf"]) as? String,
                      let url = URL(string: raw)
                else { continue }
                return url
            }
        }
        return nil
    }
}

private actor ZeoSevenFontService {
    private static let fallbackFonts: [OnlineFontItem] = [
        OnlineFontItem(providerID: "en", source: .zeoSeven, name: "Actor", detailURL: URL(string: "https://fonts.zeoseven.com/items/en/")!, canDirectDownload: false, requiresCommercialLicense: false),
        OnlineFontItem(providerID: "zh-cn", source: .zeoSeven, name: "中文字体精选", detailURL: URL(string: "https://fonts.zeoseven.com/items/zh-cn/")!, canDirectDownload: false, requiresCommercialLicense: false),
        OnlineFontItem(providerID: "tree", source: .zeoSeven, name: "开源字体关系树", detailURL: URL(string: "https://fonts.zeoseven.com/tree/")!, canDirectDownload: false, requiresCommercialLicense: false)
    ]

    func fonts(in category: OnlineFontCategory, page: Int) async throws -> [OnlineFontItem] {
        guard page == 1 else { return [] }
        return Self.fallbackFonts
    }

    func search(keyword: String, page: Int) async throws -> [OnlineFontItem] {
        guard page == 1 else { return [] }
        let token = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return Self.fallbackFonts }
        let matched = Self.fallbackFonts.filter { $0.name.localizedCaseInsensitiveContains(token) }
        return matched.isEmpty ? Self.fallbackFonts : matched
    }
}

private actor HTMLFontDirectoryService {
    private let source: OnlineFontSource
    private let origin: URL
    private let listPath: String
    private let searchPath: String
    private let linkPattern: String
    private let canDirectDownload: Bool

    init(
        source: OnlineFontSource,
        origin: URL,
        listPath: String,
        searchPath: String,
        linkPattern: String,
        canDirectDownload: Bool
    ) {
        self.source = source
        self.origin = origin
        self.listPath = listPath
        self.searchPath = searchPath
        self.linkPattern = linkPattern
        self.canDirectDownload = canDirectDownload
    }

    func fonts(in category: OnlineFontCategory, page: Int) async throws -> [OnlineFontItem] {
        guard page == 1 || source == .hundredFont else { return [] }
        return try await fetch(path: listPath.replacingOccurrences(of: "-1.", with: "-\(max(1, page))."), keyword: nil)
    }

    func search(keyword: String, page: Int) async throws -> [OnlineFontItem] {
        let token = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return try await fonts(in: .all, page: page) }
        let encoded = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
        let path = searchPath.replacingOccurrences(of: "{query}", with: encoded)
        let results = try await fetch(path: path, keyword: token)
        return results.isEmpty ? try await fetch(path: listPath, keyword: token) : results
    }

    private func fetch(path: String, keyword: String?) async throws -> [OnlineFontItem] {
        guard let url = URL(string: path, relativeTo: origin)?.absoluteURL else {
            throw OnlineFontLibraryError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 24
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("zh-CN,zh-Hans;q=0.9", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8)
        else {
            throw OnlineFontLibraryError.invalidResponse
        }
        return parse(html: html, keyword: keyword)
    }

    private func parse(html: String, keyword: String?) -> [OnlineFontItem] {
        guard let expression = try? NSRegularExpression(pattern: linkPattern) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        var seen = Set<String>()
        return expression.matches(in: html, range: range).compactMap { match in
            guard match.numberOfRanges >= 3,
                  let hrefRange = Range(match.range(at: 1), in: html)
            else { return nil }
            let href = String(html[hrefRange])
            let name = nameFromMatch(match, html: html)
            let cleanedName = cleanName(name)
            guard cleanedName.count >= 2 else { return nil }
            if let keyword,
               !keyword.isEmpty,
               !cleanedName.localizedCaseInsensitiveContains(keyword) {
                return nil
            }
            let key = cleanedName.lowercased()
            guard seen.insert(key).inserted,
                  let detailURL = URL(string: href, relativeTo: origin)?.absoluteURL
            else { return nil }
            return OnlineFontItem(
                providerID: detailURL.absoluteString,
                source: source,
                name: cleanedName,
                detailURL: detailURL,
                canDirectDownload: canDirectDownload,
                requiresCommercialLicense: true,
                downloadURL: nil
            )
        }
    }

    private func nameFromMatch(_ match: NSTextCheckingResult, html: String) -> String {
        for index in 2..<match.numberOfRanges {
            guard let range = Range(match.range(at: index), in: html) else { continue }
            let value = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { return value }
        }
        return ""
    }

    private func cleanName(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"^\s*【"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"】.*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\([0-9]{4}/[0-9]{2}/[0-9]{2}\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"&amp;"#, with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 状态

@MainActor
private final class OnlineFontLibraryViewModel: ObservableObject {
    enum OperationPhase: Equatable {
        case idle
        case downloading
        case importing
        case complete
    }

    @Published var category: OnlineFontCategory = .all
    @Published var source: OnlineFontSource = .all
    @Published var fonts: [OnlineFontItem] = []
    @Published var featured: [OnlineFontItem] = []
    @Published var query = ""
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var downloadingID: String?
    @Published var operationPhase: OperationPhase = .idle
    @Published var operationProgress: Double = 0
    @Published var installedIDs: Set<String> = []
    @Published var errorMessage: String?

    private var page = 1
    private var canLoadMore = true
    private var requestGeneration = 0
    private var lastPublishedDownloadProgress: Double = -1

    func loadInitial() async {
        guard fonts.isEmpty, !isLoading else { return }
        await load(category: .all)
    }

    func load(category: OnlineFontCategory) async {
        self.category = category
        query = ""
        page = 1
        canLoadMore = true
        requestGeneration += 1
        let generation = requestGeneration
        isLoading = true
        errorMessage = nil
        do {
            let result = try await OnlineFontDirectoryService.shared.fonts(in: category, source: source, page: 1)
            guard generation == requestGeneration else { return }
            fonts = result
            if category.id == OnlineFontCategory.all.id, featured.isEmpty {
                featured = Array(result.prefix(8))
            }
            canLoadMore = !result.isEmpty
        } catch {
            guard generation == requestGeneration else { return }
            fonts = []
            errorMessage = error.localizedDescription
        }
        if generation == requestGeneration { isLoading = false }
    }

    func load(source: OnlineFontSource) async {
        self.source = source
        await load(category: category)
    }

    func performSearch() async {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            await load(category: category)
            return
        }
        page = 1
        canLoadMore = true
        requestGeneration += 1
        let generation = requestGeneration
        isLoading = true
        errorMessage = nil
        do {
            let result = try await OnlineFontDirectoryService.shared.search(keyword: keyword, source: source, page: 1)
            guard generation == requestGeneration else { return }
            fonts = result
            canLoadMore = !result.isEmpty
            if result.isEmpty { errorMessage = OnlineFontLibraryError.emptyResult.localizedDescription }
        } catch {
            guard generation == requestGeneration else { return }
            fonts = []
            errorMessage = error.localizedDescription
        }
        if generation == requestGeneration { isLoading = false }
    }

    func loadMoreIfNeeded(current item: OnlineFontItem) async {
        guard item.id == fonts.last?.id, canLoadMore, !isLoading, !isLoadingMore else { return }

        // LazyVGrid 的末项 task 可能在 SwiftUI 正在提交视图树时启动；
        // 先跨过当前更新周期，再发布分页状态。
        try? await Task.sleep(for: .milliseconds(24))
        guard !Task.isCancelled,
              item.id == fonts.last?.id,
              canLoadMore,
              !isLoading,
              !isLoadingMore
        else { return }

        isLoadingMore = true
        let nextPage = page + 1
        do {
            let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = keyword.isEmpty
                ? try await OnlineFontDirectoryService.shared.fonts(in: category, source: source, page: nextPage)
                : try await OnlineFontDirectoryService.shared.search(keyword: keyword, source: source, page: nextPage)
            let existing = Set(fonts.map(\.id))
            fonts.append(contentsOf: result.filter { !existing.contains($0.id) })
            page = nextPage
            canLoadMore = !result.isEmpty
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingMore = false
    }

    func install(_ item: OnlineFontItem) async -> ImportedFontRecord? {
        guard downloadingID == nil else { return nil }
        downloadingID = item.id
        operationPhase = .downloading
        operationProgress = 0
        lastPublishedDownloadProgress = -1
        errorMessage = nil
        var temporaryURL: URL?
        defer {
            if let temporaryURL { try? FileManager.default.removeItem(at: temporaryURL) }
            downloadingID = nil
        }
        do {
            let url = try await OnlineFontDirectoryService.shared.downloadFont(item: item) { [weak self] fraction in
                Task { @MainActor [weak self] in
                    guard let self, self.downloadingID == item.id,
                          self.operationPhase == .downloading
                    else { return }
                    self.publishDownloadProgress(fraction)
                }
            }
            temporaryURL = url
            operationPhase = .importing
            operationProgress = 0
            await Task.yield()
            let records = try await CustomFontManager.shared.importFonts(from: [url]) { [weak self] fraction in
                guard let self, self.downloadingID == item.id else { return }
                self.operationProgress = fraction
            }
            guard let first = records.first else {
                throw OnlineFontLibraryError.downloadUnavailable
            }
            installedIDs.insert(item.id)
            operationPhase = .complete
            operationProgress = 1
            return first
        } catch {
            AppLogger.error(
                "[OnlineFont] Install failed id=\(item.id) phase=\(String(describing: operationPhase)) error=\(error.localizedDescription)",
                step: "online-font.install"
            )
            operationPhase = .idle
            operationProgress = 0
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func publishDownloadProgress(_ fraction: Double) {
        let normalized = min(1, max(0, fraction))
        guard normalized >= 1
                || lastPublishedDownloadProgress < 0
                || normalized - lastPublishedDownloadProgress >= 0.01
        else { return }
        lastPublishedDownloadProgress = normalized
        operationProgress = normalized
    }

    var operationTitle: String {
        switch operationPhase {
        case .idle:
            return ""
        case .downloading:
            return String(format: String(localized: "正在下载 %d%%"), Int(operationProgress * 100))
        case .importing:
            switch operationProgress {
            case ..<0.42:
                return String(localized: "正在解压字体")
            case ..<0.56:
                return String(localized: "正在校验字体")
            case ..<0.94:
                return String(localized: "正在注册字体")
            default:
                return String(localized: "正在加入字体列表")
            }
        case .complete:
            return String(localized: "已导入")
        }
    }
}

// MARK: - 页面

struct OnlineFontLibraryView: View {
    let accent: Color
    let onImported: (ImportedFontRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = OnlineFontLibraryViewModel()
    @ObservedObject private var fontManager = CustomFontManager.shared
    @State private var pendingLicensedFont: OnlineFontItem?
    @State private var sourceURL: URL?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                fontSettingsBackground

                if proxy.size.width > proxy.size.height {
                    landscapeLayout(size: proxy.size)
                } else {
                    portraitLayout
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await viewModel.loadInitial() }
        .alert(
            String(localized: "商用需授权"),
            isPresented: Binding(
                get: { pendingLicensedFont != nil },
                set: { if !$0 { pendingLicensedFont = nil } }
            ),
            presenting: pendingLicensedFont
        ) { item in
            Button(String(localized: "个人使用下载")) {
                Task { await install(item) }
            }
            Button(String(localized: "查看授权")) {
                sourceURL = item.detailURL
            }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: { _ in
            Text(String(localized: "该字体标记为商用需授权，商业用途前需要购买相应授权"))
        }
        .alert(
            String(localized: "在线字体"),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(String(localized: "common_confirm"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .fullScreenCover(item: $sourceURL) { url in
            MonologueWebView(url: url, title: String(localized: "字体天下"))
        }
    }

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            pageHeader
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    searchField
                    sourceStrip
                    importedFontsSection
                    featuredSection
                    categoryGrid(columns: 4)
                    fontListSection(columns: 1)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 44)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
    }

    private func landscapeLayout(size: CGSize) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                pageHeader
                searchField
                sourceStrip
                ScrollView {
                    categoryGrid(columns: 2)
                        .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
            .frame(width: min(330, max(270, size.width * 0.31)))
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
            .background(Color.black.opacity(0.2))

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 1)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    importedFontsSection
                    featuredSection
                    fontListSection(columns: size.width > 1_100 ? 3 : 2)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var pageHeader: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                MonologueIcon(icon: .chevronLeft, size: 15, color: .white.opacity(0.9))
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "在线字体"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(viewModel.source.title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            MonologueIcon(icon: .search, size: 16, color: .white.opacity(0.48))
            TextField(String(localized: "搜索字体"), text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.performSearch() }
                }

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                    Task { await viewModel.load(category: viewModel.category) }
                } label: {
                    MonologueIcon(icon: .xmarkCircle, size: 15, color: .white.opacity(0.48))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var sourceStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(OnlineFontSource.allCases) { source in
                    sourceButton(source)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func sourceButton(_ source: OnlineFontSource) -> some View {
        let selected = viewModel.source == source
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            Task { await viewModel.load(source: source) }
        } label: {
            Text(source.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(selected ? Color.black.opacity(0.82) : Color.white.opacity(0.58))
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? accent.opacity(0.92) : Color.white.opacity(0.055))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(selected ? Color.white.opacity(0.15) : Color.white.opacity(0.07), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var importedFontsSection: some View {
        if !fontManager.fonts.isEmpty {
            VStack(alignment: .leading, spacing: 11) {
                sectionTitle(
                    String(localized: "已导入字体"),
                    trailing: String(fontManager.fonts.count)
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 9) {
                        ForEach(fontManager.fonts.sorted { $0.importedAt > $1.importedAt }) { record in
                            Button {
                                onImported(record)
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                VStack(spacing: 5) {
                                    Text("永 Aa")
                                        .font(.custom(record.postScriptName, size: 18))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .lineLimit(1)

                                    Text(record.displayName)
                                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .lineLimit(1)
                                }
                                .frame(width: 94, height: 58)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(accent.opacity(0.18), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var featuredSection: some View {
        if !viewModel.featured.isEmpty {
            VStack(alignment: .leading, spacing: 11) {
                sectionTitle(String(localized: "精选字体"), trailing: nil)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(viewModel.featured) { item in
                            featuredCard(item)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }

    private func categoryGrid(columns: Int) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle(String(localized: "字体分类"), trailing: nil)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns),
                spacing: 8
            ) {
                ForEach(OnlineFontCategory.library) { category in
                    categoryButton(category)
                }
            }
        }
    }

    private func fontListSection(columns: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? viewModel.category.title
                    : String(localized: "搜索结果"),
                trailing: viewModel.fonts.isEmpty ? nil : String(viewModel.fonts.count)
            )

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(accent)
                    Spacer()
                }
                .frame(height: 180)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns),
                    spacing: 10
                ) {
                    ForEach(viewModel.fonts) { item in
                        fontCard(item)
                            .task { await viewModel.loadMoreIfNeeded(current: item) }
                    }
                }

                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView().tint(accent)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                }
            }
        }
    }

    private func sectionTitle(_ title: String, trailing: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.38))
            }
        }
    }

    private func categoryButton(_ category: OnlineFontCategory) -> some View {
        let selected = viewModel.category.id == category.id && viewModel.query.isEmpty
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            Task { await viewModel.load(category: category) }
        } label: {
            VStack(spacing: 6) {
                Text(category.sample)
                    .font(.system(size: 22, weight: .bold, design: category.id == "song" ? .serif : .rounded))
                    .foregroundStyle(selected ? Color.black.opacity(0.84) : Color.white.opacity(0.86))
                Text(category.title)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(selected ? Color.black.opacity(0.7) : Color.white.opacity(0.48))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(selected ? accent.opacity(0.9) : Color.white.opacity(0.045))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(selected ? Color.white.opacity(0.14) : Color.white.opacity(0.07), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func featuredCard(_ item: OnlineFontItem) -> some View {
        Button {
            handleInstallTap(item)
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("永 Aa")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    Text(item.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        sourceLabel(item)
                        licenseLabel(item)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(10)

                if viewModel.downloadingID == item.id {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.7)
                        .padding(8)
                }
            }
            .frame(width: 124, height: 68)
            .background(
                LinearGradient(
                    colors: [accent.opacity(0.16), Color.white.opacity(0.035)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .bottom) {
                if viewModel.downloadingID == item.id {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(accent)
                            .frame(
                                width: proxy.size.width
                                    * min(1, max(0, viewModel.operationProgress))
                            )
                    }
                    .frame(height: 3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func fontCard(_ item: OnlineFontItem) -> some View {
        Button {
            handleInstallTap(item)
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 11) {
                    onlineFontTextPreview(fontSize: 14)
                        .frame(width: 42, height: 34)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 7) {
                        Text(item.name)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            sourceLabel(item)
                            licenseLabel(item)
                        }
                    }

                    Spacer(minLength: 4)
                    installIndicator(item)
                }
                .padding(9)

                if viewModel.downloadingID == item.id {
                    operationProgressStrip
                        .padding(.horizontal, 10)
                        .padding(.bottom, 9)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
        .accessibilityLabel("\(item.name)，\(licenseText(for: item))")
    }

    private func installIndicator(_ item: OnlineFontItem) -> some View {
        Group {
            if viewModel.downloadingID == item.id {
                ProgressView().tint(.black).scaleEffect(0.72)
            } else if viewModel.installedIDs.contains(item.id) {
                MonologueIcon(icon: .checkmark, size: 13, color: .black.opacity(0.78))
            } else if !item.canDirectDownload {
                MonologueIcon(icon: .chevronRight, size: 13, color: .black.opacity(0.78))
            } else {
                MonologueIcon(icon: .download, size: 13, color: .black.opacity(0.78))
            }
        }
        .frame(width: 30, height: 30)
        .background(accent.opacity(0.92), in: Circle())
    }

    private var operationProgressStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(viewModel.operationTitle)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(Int(viewModel.operationProgress * 100))%")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.46))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(accent)
                        .frame(width: proxy.size.width * min(1, max(0, viewModel.operationProgress)))
                }
            }
            .frame(height: 3)
        }
    }

    private func licenseLabel(_ item: OnlineFontItem) -> some View {
        Text(licenseText(for: item))
            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
            .foregroundStyle(
                item.requiresCommercialLicense
                    ? Color.orange.opacity(0.9)
                    : Color.white.opacity(0.48)
            )
            .lineLimit(1)
    }

    private func sourceLabel(_ item: OnlineFontItem) -> some View {
        Text(item.source.title)
            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
            .foregroundStyle(accent.opacity(0.88))
            .lineLimit(1)
    }

    private func licenseText(for item: OnlineFontItem) -> String {
        if !item.canDirectDownload { return String(localized: "前往获取") }
        if item.requiresCommercialLicense { return String(localized: "商用需授权") }
        return String(localized: "可下载")
    }

    private func onlineFontTextPreview(fontSize: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [accent.opacity(0.14), Color.white.opacity(0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text("永 Aa")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
        }
    }

    private var fontSettingsBackground: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [accent.opacity(0.16), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 520
            )
            LinearGradient(
                colors: [Color.white.opacity(0.025), .clear, accent.opacity(0.045)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private func handleInstallTap(_ item: OnlineFontItem) {
        guard viewModel.downloadingID == nil,
              !viewModel.installedIDs.contains(item.id)
        else { return }
        if !item.canDirectDownload {
            sourceURL = item.detailURL
        } else if item.requiresCommercialLicense {
            pendingLicensedFont = item
        } else {
            Task { await install(item) }
        }
    }

    private func install(_ item: OnlineFontItem) async {
        if let record = await viewModel.install(item) {
            onImported(record)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
