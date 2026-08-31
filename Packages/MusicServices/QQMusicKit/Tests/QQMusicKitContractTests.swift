import Foundation
import XCTest
@testable import QQMusicKit

private final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var value: URLRequest?

    func record(_ request: URLRequest) {
        lock.lock()
        value = request
        lock.unlock()
    }

    func request() -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    static let recorder = RequestRecorder()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.recorder.record(request)
        let path = request.url?.path ?? ""
        let result: String
        switch path {
        case "/song/query_song":
            result = "{\"tracks\":[]}"
        case "/song/get_labels":
            result = "{\"labels\":[]}"
        case "/song/get_related_songlist":
            result = "[]"
        default:
            result = "{}"
        }
        let body = "{\"code\":200,\"message\":\"Success\",\"data\":{\"result\":\(result),\"source\":\"server\"},\"timestamp\":1}".data(using: .utf8)!
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class QQMusicKitContractTests: XCTestCase {
    private func makeClient() -> QQMusicClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return QQMusicClient(
            baseURL: URL(string: "https://qcm.invalid")!,
            maxRetries: 0,
            session: URLSession(configuration: configuration)
        )
    }

    private func queryItems() throws -> [String: String] {
        let request = try XCTUnwrap(URLProtocolStub.recorder.request())
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }

    private func path() throws -> String {
        try XCTUnwrap(URLProtocolStub.recorder.request()?.url?.path)
    }

    func testBackendVersion() {
        XCTAssertEqual(QQMusicAPIVersion.backend, "0.7.2")
    }

    func testSongQueryUsesVersion072Payload() async throws {
        let client = makeClient()
        _ = try await client.querySongs([QQMusicSongQuery(mid: "003w2xz20QlUZt")])

        let encoded = try XCTUnwrap(try queryItems()["song_info"]?.data(using: .utf8))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [[String: Any]])
        XCTAssertEqual(payload.first?["mid"] as? String, "003w2xz20QlUZt")
        XCTAssertEqual(payload.first?["song_type"] as? Int, 0)
    }

    func testSearchSelectorsAreSerializedAsJSON() async throws {
        let client = makeClient()
        let _: JSON = try await client.search(
            keyword: "周杰伦",
            selectors: [QQMusicSearchSelector(id: 1, name: "华语", type: 2)],
            searchID: "search-session"
        )

        let items = try queryItems()
        XCTAssertEqual(items["searchid"], "search-session")
        let encoded = try XCTUnwrap(items["selectors"]?.data(using: .utf8))
        let selectors = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [[String: Any]])
        XCTAssertEqual(selectors.first?["name"] as? String, "华语")
    }

    func testLyricUsesVersion072Options() async throws {
        let client = makeClient()
        _ = try await client.lyric(
            value: "003w2xz20QlUZt",
            songType: 2,
            qrc: true,
            singingAnnotations: true
        )

        let items = try queryItems()
        XCTAssertEqual(items["song_type"], "2")
        XCTAssertEqual(items["qrc"], "true")
        XCTAssertEqual(items["singing_annotations"], "true")
    }

    func testVersion072LyricRoutesAreExposed() async throws {
        let client = makeClient()

        _ = try await client.singingAnnotationsInfo(songId: 42)
        XCTAssertEqual(try path(), "/lyric/get_singing_annotations_info")
        XCTAssertEqual(try queryItems()["songid"], "42")

        _ = try await client.multiStyleTranslatedLyric(songId: 43)
        XCTAssertEqual(try path(), "/lyric/get_multi_style_trans_lyric")

        _ = try await client.hasAILyricDictionary(songId: 44)
        XCTAssertEqual(try path(), "/lyric/is_ai_dict_exists")

        _ = try await client.aiLyricDictionary(songId: 45)
        XCTAssertEqual(try path(), "/lyric/get_ai_dict")
    }

    func testRemainingPublicAndCustomRoutesAreExposed() async throws {
        let client = makeClient()

        _ = try await client.songCDNDispatch()
        XCTAssertEqual(try path(), "/song/get_cdn_dispatch")

        _ = try await client.songlistCategories()
        XCTAssertEqual(try path(), "/recommend/get_songlist_categories")

        _ = try await client.songlistsByCategory(categoryID: 100, sortID: 2, page: 3, size: 40)
        XCTAssertEqual(try path(), "/recommend/get_songlist_by_category")
        let items = try queryItems()
        XCTAssertEqual(items["category_id"], "100")
        XCTAssertEqual(items["sort_id"], "2")
        XCTAssertEqual(items["page"], "3")
        XCTAssertEqual(items["size"], "40")
    }

    func testExpandedUpstreamParametersAreSerialized() async throws {
        let client = makeClient()

        _ = try await client.homeFeed(page: 2, direction: 1, songCount: 8, cache: ["11", "12"])
        var items = try queryItems()
        XCTAssertEqual(items["page"], "2")
        XCTAssertEqual(items["direction"], "1")
        let cacheData = try XCTUnwrap(items["v_cache"]?.data(using: .utf8))
        XCTAssertEqual(try JSONSerialization.jsonObject(with: cacheData) as? [String], ["11", "12"])

        _ = try await client.generalSearch(
            keyword: "Mono",
            page: 2,
            num: 30,
            searchID: "session",
            pageStart: 15,
            highlight: false
        )
        items = try queryItems()
        XCTAssertEqual(items["num"], "30")
        XCTAssertEqual(items["searchid"], "session")
        XCTAssertEqual(items["page_start"], "15")

        _ = try await client.relatedSonglist(songId: 42, last: [7, 8])
        items = try queryItems()
        let lastData = try XCTUnwrap(items["last"]?.data(using: .utf8))
        XCTAssertEqual(try JSONSerialization.jsonObject(with: lastData) as? [Int], [7, 8])
    }

    func testSongLabelsUsesCurrentBackendRoute() async throws {
        let client = makeClient()
        _ = try await client.songLabels(songId: 42)

        let request = try XCTUnwrap(URLProtocolStub.recorder.request())
        XCTAssertEqual(request.url?.path, "/song/get_labels")
        XCTAssertEqual(try queryItems()["songid"], "42")
    }

    func testSonglistMutationUsesSongInfoTuples() async throws {
        let client = makeClient()
        _ = try await client.addSongsToSonglist(dirid: 7, songIds: "11,12", tid: 99)

        let items = try queryItems()
        let encoded = try XCTUnwrap(items["song_info"]?.data(using: .utf8))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [[Int]])
        XCTAssertEqual(payload, [[11, 0], [12, 0]])
        XCTAssertEqual(items["tid"], "99")
    }
}
